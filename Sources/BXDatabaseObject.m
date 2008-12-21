//
// BXDatabaseObject.m
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
// us at sales@karppinen.fi. Without an additional license, this software
// may be distributed only in compliance with the GNU General Public License.
//
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License, version 2.0,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
// $Id$
//

#import <objc/objc.h>
#import <string.h>
#import <ctype.h>

#import <sys/types.h>
#import <unistd.h>

#import "BXDatabaseObject.h"
#import "BXDatabaseObjectPrivate.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseContextPrivate.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXDatabaseAdditions.h"
#import "BXEntityDescription.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXConstants.h"
#import "BXAttributeDescription.h"
#import "BXObjectStatusInfo.h"
#import "BXRelationshipDescription.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXAttributeDescriptionPrivate.h"
#import "BXLogger.h"
#import "PGTSHOM.h"
#import "BXEnumerate.h"
#import "BXKeyPathParser.h"


static NSString* 
MakeKey (const char* start, const int length)
{
    size_t size = length + 1;
    char* copy = malloc (size * sizeof (char));
    strlcpy (copy, start, size);
	int initial = tolower (copy [0]);
	Expect (0 <= initial && initial <= UCHAR_MAX);
    copy [0] = initial;
    return [[[NSString alloc] initWithBytesNoCopy: copy
                                           length: length
                                         encoding: NSASCIIStringEncoding
                                     freeWhenDone: YES] autorelease];
}

static int
ColonCount (const char* start)
{
    int cCount = 0;
    for (int i = 0; '\0' != start [i]; i++)
    {
        if (':' == start [i])
            cCount++;
    }
    return cCount;
}

/**
 * \brief Is the given selector a setter or a getter?
 * \return 2 if setter, 1 if getter, 0 if neither
 */
static int 
ParseSelector (SEL aSelector, NSString** key)
{
    int rval = 0;
    const char* name = sel_getName (aSelector);
    if (0 == memcmp ("set", name, 3 * sizeof (char)) && !islower (name [3]))
    {
        //This might be a setter and definitely is not a getter
        //See that there is only one colon in the name
        int length = strlen (name);
        int cCount = ColonCount (&name [3]);
        //There should be only one at the end
        if (1 == cCount)
        {
            rval = 2;
            
            //See if the user wants the key
            if (NULL != key)
                *key = MakeKey (&name [3], length - 4); //Remove set and colon from the end
        }
    }
    else if (islower (name [0]))
    {
        //Count colons. There should be none in the getter.
        if (0 == ColonCount (name))
        {
            rval = 1;
            
            //See if the user wants the key
            if (NULL != key)
                *key = MakeKey (name, strlen (name));
        }
    }
    return rval;
}    

/** 
 * \brief A class that represents a single row in a database table.
 *
 * The objects returned by the database context are instances of this class 
 * or its subclasses. The class is KVC-compliant. It is not thread-safe
 * for the most part, i.e. if methods of an BXDatabaseObject instance will 
 * be called from different threads the result is undefined and deadlocks are possible.
 *
 * Retrieving cached values is thread safe. This could be useful in situations, where 
 * worker threads need access to the object's contents but the contents have been 
 * fetched earlier.
 *
 * \ingroup baseten
 */
@implementation BXDatabaseObject

+ (void) initialize
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES; 
    }
}

- (NSString *) description
{
    NSString* rval = nil;
    @synchronized (mValues)
    {
        rval = [NSString stringWithFormat: @"%@ (%p) \n\t\tURI: %@ \n\t\tisFault: %d \n\t\tentity: %@", 
            [self class], self, [[self objectID] URIRepresentation], [self isFaultKey: nil], [[mObjectID entity] name]];
    }
    return rval;
}

/** 
 * \brief The database context to which this object is registered. 
 *
 * This method doesn't cause a fault to fire.
 */
- (BXDatabaseContext *) databaseContext
{
    return mContext;
}

/**
 * \brief Test object equality.
 *
 * Currently objects are considered equal if they are managed by the same database context and
 * their object IDs are equal.
 * This method doesn't cause a fault to fire.
 */
- (BOOL) isEqual: (BXDatabaseObject *) anObject
{
    BOOL rval = NO;
    if (YES == [anObject isKindOfClass: [BXDatabaseObject class]])
    {
        BXAssertValueReturn (nil != mObjectID, NO, @"isEqual: invoked when mObjectID is nil.");
        if (mContext == [anObject databaseContext] && [mObjectID isEqual: [anObject objectID]])
            rval = YES;
    }
    return rval;
}

/** 
 * \brief A convenience method for retrieving values for multiple keys. 
 * \param   keys    An NSArray of NSStrings.
 * \return          The requested values.
 */
- (NSArray *) valuesForKeys: (NSArray *) keys
{
    NSMutableArray* rval = [NSMutableArray arrayWithCapacity: [keys count]];
    BXEnumerate (currentKey, e, [keys objectEnumerator])
    {
        id value = [self valueForKey: currentKey];
        [rval addObject: value ? value : [NSNull null]];
    }
    return rval;
}

/**
 * \brief Value or objects from the database.
 *
 * Look up the value from cache or ask the database context to fetch it.
 * Currently this method calls #primitiveValueForKey:.
 * \param   aKey    A BXAttributeDescription.
 * \return          An object or an NSArray of BXDatabaseObjects.
 */
- (id) objectForKey: (BXAttributeDescription *) aKey
{
    return [self valueForKey: [aKey name]];
}

/** 
 * \brief A convenience method for retrieving values for multiple keys. 
 * \param   keys    An NSArray of BXAttributeDescriptions.
 * \return          The requested values.
 */
- (NSArray *) objectsForKeys: (NSArray *) keys
{
    return [self valuesForKeys: [keys valueForKey: @"name"]];
}

/**
 * \brief Validate a value.
 *
 * Currently, only null constraints are checked.
 * This method doesn't cause a fault to fire.
 */
- (BOOL) validateValue: (id *) ioValue forKey: (NSString *) key error: (NSError **) outError
{
	BOOL rval = YES;
	rval = [self checkNullConstraintForValue: ioValue key: key error: outError];
	if (YES == rval)
		rval = [super validateValue: ioValue forKey: key error: outError];
	return rval;
}

/**
 * \brief Determines whether the receiver can be deleted in its current state.
 *
 * Currently, only inverse relationships' delete rules are checked.
 * This method could cause a fault to fire.
 */
- (BOOL) validateForDelete: (NSError **) outError
{
	BOOL retval = NO;
	if ([self isDeleted])
	{
		//Already deleted.
		//FIXME: set outError.
	}
	else if ([[self entity] hasCapability: kBXEntityCapabilityRelationships])
	{
		retval = YES;
		BXEnumerate (currentRel, e, [[[self entity] relationshipsByName] objectEnumerator])
		{
			BXRelationshipDescription* inverse = [(BXRelationshipDescription *) currentRel inverseRelationship];
			if (NSDenyDeleteRule == [inverse deleteRule] && 
				nil != [self primitiveValueForKey: [currentRel name]])
			{
				//Deletion denied.
				//FIXME: set outError.
				retval = NO;
				break;
			}
		}
	}
	return retval;
}

/** 
 * \brief The object ID. 
 *
 * This method doesn't cause a fault to fire.
 */
- (BXDatabaseObjectID *) objectID
{
    return mObjectID;
}

/**
 * \brief Predicate for this object.
 *
 * This method might cause a fault to fire.
 */
- (NSPredicate *) predicate
{
    NSMutableArray* predicates = [NSMutableArray array];
    NSDictionary* attrs = [[[self objectID] entity] attributesByName];
    BXEnumerate (currentAttr, e, [attrs objectEnumerator])
    {
        if ([currentAttr isPrimaryKey])
        {
            NSExpression* lhs = [NSExpression expressionForConstantValue: currentAttr];
            NSExpression* rhs = [NSExpression expressionForConstantValue: 
                [self primitiveValueForKey: [currentAttr name]]];
            [predicates addObject: [NSComparisonPredicate predicateWithLeftExpression: lhs 
                                                                      rightExpression: rhs
                                                                             modifier: NSDirectPredicateModifier
                                                                                 type: NSEqualToPredicateOperatorType
                                                                              options: 0]];
        }
    }
    return [NSCompoundPredicate andPredicateWithSubpredicates: predicates];
}

- (id) valueForKeyPath: (NSString *) keyPath
{
    id rval = nil;
	NSArray* components = BXKeyPathComponents (keyPath);
    unsigned int count = [components count];
    BXEntityDescription* entity = [mObjectID entity];
    
    if (1 == count)
        rval = [self valueForKey: [components objectAtIndex: 0]];
    else if (3 == count &&
             [[components objectAtIndex: 0] isEqual: [entity schemaName]] &&
             [[components objectAtIndex: 1] isEqual: [entity name]])
    {
        rval = [self valueForKey: [components objectAtIndex: 2]];
    }
    else
    {
        rval = [super valueForKeyPath: keyPath];
    }
    return rval;
}

/**
 * \internal
 * \brief Returns cached objects.
 */
- (NSDictionary *) cachedObjects
{
    NSDictionary* cachedValues = [self cachedValues];
    NSMutableDictionary* rval = nil;
	if (0 < [cachedValues count])
	{
		BXEntityDescription* entity = [[self objectID] entity];
		BXAssertValueReturn ([entity isValidated], nil, @"Expected entity %@ to have been validated earlier.", entity);
		rval = [NSMutableDictionary dictionaryWithCapacity: [cachedValues count]];
		
		BXEnumerate (currentFName, e, [cachedValues keyEnumerator])
		{
			BXAttributeDescription* desc = [[entity attributesByName] objectForKey: currentFName]; 
            if (nil != desc)
                [rval setObject: [cachedValues objectForKey: currentFName] forKey: desc];
		}
	}
    return rval;
}

/**
 * \brief A proxy for monitoring the object's status.
 *
 * Returns a proxy that can be used with BXObjectStatusToEditableTransformer and
 * BXObjectStatusToColorTransformer.
 * This method doesn't cause a fault to fire.
 */
- (id <BXObjectStatusInfo>) statusInfo
{
    return [BXObjectStatusInfo statusInfoWithTarget: self];
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) aSelector
{
	//Subclasses get broken if this is replaced with -[super methodSignatureForSelector:].
	Class cls = [self class];
    NSMethodSignature* retval = [cls instanceMethodSignatureForSelector: aSelector];
    if (! (retval && [self respondsToSelector: aSelector]))
    {
        switch (ParseSelector (aSelector, NULL))
        {
            case 2:
                retval = [cls instanceMethodSignatureForSelector: @selector (setPrimitiveValue:forKey:)];
                break;
            case 1:
                retval = [cls instanceMethodSignatureForSelector: @selector (primitiveValueForKey:)];
                break;
            case 0:
            default:
                break;
        }
    }
    return retval;
}

- (void) forwardInvocation: (NSInvocation *) invocation
{
    NSString* key = nil;
	NSMethodSignature* sig = [invocation methodSignature];
	NSUInteger argCount = [sig numberOfArguments];
	
	//Argument count has already been influenced by -methodSignatureForSelector:.
	switch (argCount) 
	{
		case 4:
			//Possibly setter.
			if (2 == ParseSelector ([invocation selector], &key))
			{
				//Argument 2 is already the value.
				[invocation setSelector: @selector (setPrimitiveValue:forKey:)];
				[invocation setArgument: &key atIndex: 3];
			}
			break;
			
		case 3:
			//Possibly getter.
			if (1 == ParseSelector ([invocation selector], &key))
			{
				[invocation setSelector: @selector (primitiveValueForKey:)];
				[invocation setArgument: &key atIndex: 2];
			}
			break;
			
		default:
			break;
	}
	
	if ([self respondsToSelector: [invocation selector]])
	    [invocation invokeWithTarget: self];
	else
		[self doesNotRecognizeSelector: [invocation selector]];
}

/**
 * \brief Value from the object's cache.
 *
 * This method is thread-safe and doesn't cause a fault to fire.
 * \return      The value in question or nil, if it has not been fetched from the database yet.
 *              NSNulls represent nil values.
 */
- (id) cachedValueForKey: (NSString *) aKey
{
    id retval = nil;
    @synchronized (mValues)
    {
        retval = [mValues valueForKey: aKey];
    }
    return retval;
}

/**
 * \brief Value or objects from the database.
 *
 * Look up the value from cache or ask the database context to fetch it.
 * Calls super's implementation of -valueForUndefinedKey: if the key isn't known.
 * \param   aKey    Name of the column or a relationship.
 * \return          nil for null values. Otherwise an object or a 
 *                  self-updating NSSet-style collection of BXDatabaseObjects.
 */
- (id) primitiveValueForKey: (NSString *) aKey
{
	NSError* error = nil;
	id retval = nil;
	
	BXAssertValueReturn (nil != mContext, nil, @"Expected mContext not to be nil.");
	
	//If we have an error condition, return anything we have in cache.
	if (! [mContext checkErrorHandling])
		retval = [self cachedValueForKey: aKey];
	else
	{
		enum BXDatabaseObjectKeyType keyType = [self keyType: aKey];
		BXAssertLog (kBXDatabaseObjectUnknownKey != keyType, 
					 @"Key %@ wasn't found in entity %@.%@.", 
					 aKey, [[self entity] schemaName], [[self entity] name]);
		switch (keyType)
		{
			case kBXDatabaseObjectPrimaryKey:
			case kBXDatabaseObjectKnownKey:
			{
				retval = [self cachedValueForKey: aKey];
				if (! retval)
				{
					BXEntityDescription* entity = [self entity];
					NSDictionary* attrs = [entity attributesByName];
					BXAttributeDescription* attr = [attrs objectForKey: aKey];					
					if ([mContext fireFault: self key: attr error: &error])
						retval = [self cachedValueForKey: aKey];					
				}
				break;
			}
				
			case kBXDatabaseObjectForeignKey:
			{
                BXRelationshipDescription* rel = [[[self entity] relationshipsByName] objectForKey: aKey];
				retval = [self cachedValueForKey: aKey];
                if (rel && ! retval)
                {
					retval = [rel targetForObject: self error: &error];
					if (! error && [NSNull null] != retval)
					{
						//Caching the result might cause a retain cycle.
						[self setCachedValue: retval forKey: aKey];
					}
                }
				break;
			}
				
			case kBXDatabaseObjectUnknownKey:
				break;
				
			case kBXDatabaseObjectNoKeyType:
			default:
				BXAssertValueReturn (NO, nil, @"keyType had a strange value (%d).", keyType);
				break;
		}
		
		if (nil != error)
			[[mContext internalDelegate] databaseContext: mContext hadError: error willBePassedOn: NO];
		else
		{
			if (nil == retval)
				retval = [self valueForUndefinedKey2: aKey];
			if ([NSNull null] == retval)
				retval = nil;
		}
	}
    
    return [[retval retain] autorelease];
}

/** 
 * \brief Set value for a given key in the database.
 * \param   aVal    The new value. May be nil for ordinary columns.
 * \param   aKey    An NSString.
 */
- (void) setPrimitiveValue: (id) aVal forKey: (NSString *) aKey
{
    BXAssertVoidReturn (nil != mContext, @"Expected mContext not to be nil.");
    NSError* error = nil;
    
    //We only need the non-cached value when autocommitting.
    id oldValue = nil;
    if ([mContext autocommits] && nil != [mContext undoManager])
        oldValue = [self primitiveValueForKey: aKey];
    else
        oldValue = [self cachedValueForKey: aKey];
    
    if (nil == oldValue || NO == [oldValue isEqual: aVal])
    {
        enum BXDatabaseObjectKeyType keyType = [self keyType: aKey];
		switch (keyType)
		{
			case kBXDatabaseObjectPrimaryKey:
			case kBXDatabaseObjectKnownKey:
			{            
				if (nil == aVal)
					aVal = [NSNull null];

				BXEntityDescription* entity = [mObjectID entity];
				BXAttributeDescription* attr = [[entity attributesByName] objectForKey: aKey];
				
				NSSet* rels = [attr dependentRelationships];
				id oldTargets = nil;
				id newTargets = nil;
				if (0 < [rels count])
				{
					oldTargets = [[rels PGTSKeyCollect] registeredTargetFor: self fireFault: NO];
					[self setCachedValue: aVal forKey: aKey];
					newTargets = [[rels PGTSKeyCollect] registeredTargetFor: self fireFault: NO];
					[self willChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
				}
				
				[mContext executeUpdateObject: self entity: nil predicate: nil
							   withDictionary: [NSDictionary dictionaryWithObject: aVal forKey: attr]
										error: &error];
				
				if (0 < [rels count])
					[self didChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
				break;
			}
				
			case kBXDatabaseObjectForeignKey:
			{
				BXEntityDescription* entity = [mObjectID entity];
				BXRelationshipDescription* rel = [[entity relationshipsByName] objectForKey: aKey];
				[rel setTarget: aVal forObject: self error: &error];
				break;
			}
                    
			case kBXDatabaseObjectUnknownKey:
				[super setValue: aVal forUndefinedKey: aKey];
				break;
				
			case kBXDatabaseObjectNoKeyType:
			default:
			{
				BXAssertLog (NO, @"keyType had a strange value (%d).", keyType);
				break;
			}
        }
        
        if (nil == error)
        {
            //Undo in case of autocommit
            if ([mContext autocommits])
			{
				NSUndoManager* undoManager = [mContext undoManager];
                [[undoManager prepareWithInvocationTarget: self] setPrimitiveValue: oldValue forKey: aKey];
			}
        }
        else
        {
			[[mContext internalDelegate] databaseContext: mContext hadError: error willBePassedOn: NO];
        }
    }
}

/**
 * \brief Set multiple values.
 *
 * This is not merely a convenience method; invoking this is potentially much faster than 
 * repeatedly using #setPrimitiveValue:forKey:. However, for foreign keys, #setPrimitiveValue:forKey: 
 * should be used instead or the collection proxy be modified directly.
 */
- (void) setPrimitiveValuesForKeysWithDictionary: (NSDictionary *) aDict
{
    BXAssertVoidReturn (nil != mContext, @"Expected to have a database context.");
    NSError* error = nil;
	
	//Replace string keys with attributes and get dependent relationships.
	NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity: [aDict count]];
	NSDictionary* attributes = [[self entity] attributesByName];
	NSMutableSet* rels = [NSMutableSet set];
	BXEnumerate (currentKey, e, [aDict keyEnumerator])
	{
		id attr = [attributes objectForKey: currentKey];
		[rels unionSet: [attr dependentRelationships]]; //Patch by Todd Blanchard 2008-11-15
		[dict setObject: [aDict objectForKey: currentKey] forKey: attr];
	}

	id oldTargets = nil;
	id newTargets = nil;
	if (0 < [rels count])
	{
		oldTargets = [[rels PGTSKeyCollect] registeredTargetFor: self fireFault: NO];
		[self setCachedValuesForKeysWithDictionary: aDict];
		newTargets = [[rels PGTSKeyCollect] registeredTargetFor: self fireFault: NO];
		[self willChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
	}
		
    if (! [mContext executeUpdateObject: self entity: nil predicate: nil withDictionary: dict error: &error])
		[[mContext internalDelegate] databaseContext: mContext hadError: error willBePassedOn: NO];
	
	if (0 < [rels count])
		[self didChangeInverseToOneRelationships: rels from: oldTargets to: newTargets];
}

/** 
 * \brief Fault the given key. 
 *
 * The object's cached value or related object will be released.
 * A new fetch won't be performed until any of the object's values is requested.
 * \param aKey The key to fault. If nil, all values will be removed.
 */
- (void) faultKey: (NSString *) aKey
{
	//We probably shouldn't send the KVO change notifications here if we don't want the next fetch to happen immediately.
	[self removeFromCache: aKey postingKVONotifications: NO];
}

/** 
 * \brief Whether the given key is faulted or not.
 *
 * This method doesn't cause a fault to fire.
 * \param   aKey    An NSString. May be nil, in which case the object
 *                  is considered a fault if value for any of its keys is
 *                  not cached.
 * \note The database's internal fields, which are excluded by default,
 *       will be considered when determining whether an object is a fault.
 * \return  0 if the corresponding value is in cache, 1 if not, 
 *          -1 if the key is unknown.
 */
- (int) isFaultKey: (NSString *) aKey
{
    int rval = -1; //Unknown key
    if (nil == aKey)
    {
        rval = 0;
        NSArray* knownKeys = [[self cachedValues] allKeys];
        BXEnumerate (currentProp, e, [[[mObjectID entity] fields] objectEnumerator])
        {
            if (NO == [knownKeys containsObject: [currentProp name]])
            {
                rval = 1;
                break;
            }
        }
    }
    else if (nil != [self cachedValueForKey: aKey])
    {
        rval = 0;
    }
    else if ([[[[mObjectID entity] fields] valueForKey: @"name"] containsObject: aKey])
    {
        //Fault since the key is known but doensn't have a cached value
        rval = 1;
    }
    return rval;
}

/**
 * \brief Values from the object's cache.
 *
 * This method is thread-safe and doesn't cause a fault to fire.
 * \return      An NSDictionary which contains the cached values.
 */
- (NSDictionary *) cachedValues
{
    id retval = nil;
    @synchronized (mValues)
    {
        retval = [mValues copy];
    }
    return [retval autorelease];
}

/**
 * \brief Whether the given key is locked locked or not.
 *
 * Returns YES if modifying the given key would block.
 * Current implementation locks the whole object
 * when any key gets locked.
 * This method doesn't cause a fault to fire.
 */
- (BOOL) isLockedForKey: (NSString *) aKey
{
    return (kBXObjectNoLockStatus != mLocked);
}

/**
 * \brief Whether the object has beed deleted or is going to be deleted in the next commit.
 *
 * This method doesn't cause a fault to fire.
 */
- (BOOL) isDeleted
{
    return (kBXObjectExists != mDeleted);
}

//FIXME: documentation bug? This method's behaviour should be checked with Core Data.
/**
 * \brief Whether the object has been inserted to the database in a previous transaction.
 *
 * If the object has been deleted, this method returns YES.
 * This method doesn't cause a fault to fire.
 */
- (BOOL) isInserted
{
	return (kBXObjectExists != mDeleted || mCreatedInCurrentTransaction);
}

/** \brief Retain on copy. */
- (id) copyWithZone: (NSZone *) zone
{
	return [self retain];
}

/** \brief Returns the entity of the receiver. */
- (BXEntityDescription *) entity
{
	return [[self objectID] entity];
}

@end


@implementation BXDatabaseObject (Subclassing)
/**
 * \name Methods that subclasses might override
 * \note When fetching values, #primitiveValueForKey: will always be used.
 */
//@{
//
/**
 * \brief Callback for deserializing the row.
 *
 * Called once after a fetch or firing a fault.
 */
- (void) awakeFromFetch
{
}

/**
 * \brief Callback for inserting the row into the database.
 * \note This method will be called before posting insert notifications
 *       and adding the object to self-updating collections.
 * \note BXDatabaseContext may create new objects during redo causing their 
 *       -awakeFromInsert method to be invoked. This could be checked by 
 *       sending -isRedoing to the context's undo manager.
 */
- (void) awakeFromInsert
{
}

/**
 * \brief Callback for turning into a fault.
 *
 * This method will be called if any of the object's fields is faulted.
 */
- (void) didTurnIntoFault
{
}

/** \brief The designated initializer */
- (id) init
{
    if ((self = [super init]))
    {
        @synchronized (mValues)
        {
            mValues = [[NSMutableDictionary alloc] init];
        }
		mCreatedInCurrentTransaction = NO;
		mDeleted = kBXObjectExists;
        mLocked = kBXObjectNoLockStatus;
		mNeedsToAwake = YES;
    }
    return self;
}

- (void) dealloc
{
    [mContext BXDatabaseObjectWillDealloc: self];
    @synchronized (mValues)
    {
        [mValues release];
    }
    [mObjectID release];
    [super dealloc];
}
//@}

/** \brief Returns NO. */
+ (BOOL) accessInstanceVariablesDirectly
{
    return NO;
}

/** \brief Returns NO. */
+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *) aKey
{
	return NO;
}
@end


@implementation BXDatabaseObject (PrivateMethods)

- (NSDictionary *) allValues
{
	return [self cachedValues];
}

/**
 * \internal
 * \brief Register the object with a context.
 *
 * In order to function properly, the database object needs to know about its context and its entity.
 * Registration is possible only if the object has not already been assigned a context. 
 * \return A boolean indicating whether the operation was successful or not.
 */
- (BOOL) registerWithContext: (BXDatabaseContext *) ctx entity: (BXEntityDescription *) entity
{
    BOOL retval = NO;
    BXAssertValueReturn (nil != ctx, NO, @"Expected ctx not to be nil.");
    BXAssertValueReturn ((nil == mContext && nil != entity) || (ctx == mContext && nil == entity),
                           NO, @"Attempted to re-register: %@ ctx: %@ entity: %@", self, ctx, entity);
    if (nil == entity)
        entity = [mObjectID entity];
	
    //Object ID
    NSArray* pkeyFNames = [[entity primaryKeyFields] valueForKey: @"name"];
    NSArray* pkeyFValues = nil;
    
    @synchronized (mValues)
    {
        pkeyFValues = [mValues objectsForKeys: pkeyFNames notFoundMarker: [NSNull null]];
		//FIXME: check for NSNulls.
    }
    
    NSDictionary* pkeyDict = [NSDictionary dictionaryWithObjects: pkeyFValues forKeys: pkeyFNames];
    
    BXDatabaseObjectID* objectID = [BXDatabaseObjectID IDWithEntity: entity primaryKeyFields: pkeyDict];
    retval = [self registerWithContext: ctx objectID: objectID];
    
    return retval;
}

/**
 * \internal
 * \brief Register the object with a context.
 *
 * Register with a pre-defined object ID
 * \return A boolean indicating whether the operation was successful or not.
 */
- (BOOL) registerWithContext: (BXDatabaseContext *) ctx objectID: (BXDatabaseObjectID *) anID
{
    BXAssertValueReturn (nil != ctx,  NO, @"Expected ctx not to be nil.");
    BXAssertValueReturn (nil != anID, NO, @"Expected anID not to be nil.");
    BXAssertValueReturn (nil == mContext || ctx == mContext, 
                           NO, @"Attempted to re-register: %@ ctx: %@", self, ctx);
    BOOL retval = NO;

    [mObjectID release];
    mObjectID = [anID retain];
    if (YES == [ctx registerObject: self])
    {
        retval = YES;
        
		@synchronized (mValues)
		{
			//We make the assumption that if mValues has at least some objects, it has the pkey.
			if (! [mValues count])
			{
				NSDictionary* values = [mObjectID allValues];
				[self setCachedValuesForKeysWithDictionary: values];
			}
		}
		
        //Context
        mContext = ctx; //Weak
    }        

    return retval;
}

/**
 * \internal
 * \brief Set lock status for the given key.
 */
- (void) setLockedForKey: (NSString *) aKey
{
    if (kBXObjectLockedStatus != mLocked)
    {
        [self willChangeValueForKey: @"statusInfo"];
        mLocked = kBXObjectLockedStatus;
        [self didChangeValueForKey: @"statusInfo"];
    }
}

- (void) lockForDelete
{
	if (kBXObjectDeletedStatus != mLocked)
	{
		[self willChangeValueForKey: @"statusInfo"];
		mLocked = kBXObjectDeletedStatus;
		[self didChangeValueForKey: @"statusInfo"];
	}
}

- (BOOL) lockedForDelete
{
	return (kBXObjectDeletedStatus == mLocked);
}

- (void) clearStatus
{
    if (kBXObjectNoLockStatus != mLocked)
    {
        [self willChangeValueForKey: @"statusInfo"];
        mLocked = kBXObjectNoLockStatus;
        [self didChangeValueForKey: @"statusInfo"];
    }
}

- (void) setCachedValue: (id) aValue forKey: (NSString *) aKey
{
    @synchronized (mValues)
    {
		[self setCachedValue2: aValue forKey: aKey];
    }
}

/** 
 * \internal
 * \brief A convenience method for handling the object's cache.
 */
- (void) setCachedValuesForKeysWithDictionary: (NSDictionary *) aDict
{
    @synchronized (mValues)
    {
		BXEnumerate (currentKey, e, [aDict keyEnumerator])
			[self setCachedValue2: [aDict objectForKey: currentKey] forKey: currentKey];
    }
}

- (void) setCachedValue2: (id) aValue forKey: (id) givenKey
{
	NSString* key = [givenKey BXAttributeName];
	
	//Emptying the cache sends a KVO notification.
	BOOL changes = NO;
	id oldValue = [mValues objectForKey: givenKey];
	if (nil != oldValue && oldValue != aValue)
		changes = YES;
	
	if (changes) [self willChangeValueForKey: key];
	
	if (nil == aValue)
		[mValues removeObjectForKey: key];
	else
		[mValues setObject: aValue forKey: key];
	
	if (changes) [self didChangeValueForKey: key];
}

- (void) setCreatedInCurrentTransaction: (BOOL) aBool
{
	mCreatedInCurrentTransaction = aBool;
}

- (BOOL) isCreatedInCurrentTransaction
{
	return mCreatedInCurrentTransaction;
}

- (void) setDeleted: (enum BXObjectDeletionStatus) status
{
	if (status != mDeleted)
	{
		[self willChangeValueForKey: @"statusInfo"];
		mDeleted = status;
		[self didChangeValueForKey: @"statusInfo"];
	}
}

- (BOOL) checkNullConstraintForValue: (id *) ioValue key: (NSString *) key error: (NSError **) outError
{
	BOOL rval = YES;
	BXEntityDescription* entity = [mObjectID entity];
	BXAssertValueReturn (NULL != ioValue, NO, @"Expected ioValue not to be NULL.");
	BXAssertValueReturn ([entity isValidated], NO, @"Expected entity %@ to have been validated earlier.", entity);
	id value = *ioValue;
	BXAttributeDescription* attribute = [[entity attributesByName] objectForKey: key];
	if (NO == [attribute isOptional] && (nil == value || [NSNull null] == value))
	{
		rval = NO;
		if (NULL != outError)
		{
			NSString* message = BXLocalizedString (@"nullValueGivenForNonOptionalField", @"This field requires a non-null value.", @"Error description");
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                BXSafeObj (attribute), kBXAttributeKey,
                BXLocalizedString (@"databaseError", @"Database Error", @"Title for a sheet"), NSLocalizedDescriptionKey,
                BXSafeObj (message), NSLocalizedFailureReasonErrorKey,
                BXSafeObj (message), NSLocalizedRecoverySuggestionErrorKey,
                nil];
			NSError* error = [NSError errorWithDomain: kBXErrorDomain 
												 code: kBXErrorNullConstraintNotSatisfied
											 userInfo: userInfo];
			*outError = error;
		}
	}
	return rval;
}

- (id) valueForUndefinedKey: (NSString *) aKey
{
    return [self primitiveValueForKey: aKey];
}

- (id) valueForUndefinedKey2: (NSString *) aKey
{
    return [super valueForUndefinedKey: aKey];
}

- (void) setValue: (id) aValue forUndefinedKey: (NSString *) aKey
{
    [self setPrimitiveValue: aValue forKey: aKey];
}

- (void) BXDatabaseContextWillDealloc
{
    mContext = nil;
}

/**
 * \internal
 * \brief Lock the object in an asynchronous manner.
 *
 * Ask the database to change the status of the key. The result is sent to the 
 * provided object.
 * \param   key             The key to be locked
 * \param   objectStatus    Status of the object after locking
 * \param   sender          An object that conforms to the BXObjectAsynchronousLocking
 *                          protocol.
 */
- (void) lockKey: (id) key status: (enum BXObjectLockStatus) objectStatus sender: (id <BXObjectAsynchronousLocking>) sender;
{
    [mContext lockObject: self key: key status: objectStatus sender: sender];
}

- (enum BXObjectDeletionStatus) deletionStatus
{
	return mDeleted;
}

- (void) awakeFromFetchIfNeeded
{
	if (YES == mNeedsToAwake)
	{
		mNeedsToAwake = NO;
		[self awakeFromFetch];
	}
}

- (NSArray *) keysIncludedInQuery: (id) aKey
{
	BXEntityDescription* entity = [[self objectID] entity];
	BXAssertValueReturn ([entity isValidated], nil, @"Expected entity %@ to have been validated earlier.", entity);

	NSArray* rval = nil;
	BOOL shouldContinue = NO;
	if ([aKey isKindOfClass: [BXAttributeDescription class]])
		shouldContinue = YES;
	else if ([aKey isKindOfClass: [NSString class]])
	{
		shouldContinue = YES;
		aKey = [[entity attributesByName] objectForKey: aKey];
	}
	
	if (shouldContinue)
	{
		NSArray* cachedKeys = [[self cachedObjects] allKeys];
		NSMutableArray* queryKeys = [[[[entity attributesByName] allValues] mutableCopy] autorelease];
		[queryKeys removeObjectsInArray: cachedKeys];
		[queryKeys filterUsingPredicate: [NSPredicate predicateWithFormat: @"NO == isExcluded"]];
		if (YES == [aKey isExcluded])
			[queryKeys addObject: aKey];
		
		rval = queryKeys;
	}
	
	return rval;
}

- (void) awakeFromInsertIfNeeded
{
	if (YES == mNeedsToAwake)
	{
		mNeedsToAwake = NO;
		[self awakeFromInsert];
	}
}

- (enum BXDatabaseObjectKeyType) keyType: (NSString *) aKey
{
	enum BXDatabaseObjectKeyType retval = kBXDatabaseObjectUnknownKey;
	BXEntityDescription* entity = [self entity];
	
	BXAttributeDescription* attribute = [[entity attributesByName] objectForKey: aKey];
	if (nil != attribute)
	{
		if ([attribute isPrimaryKey])
			retval = kBXDatabaseObjectPrimaryKey;
		else
			retval = kBXDatabaseObjectKnownKey;
	}
	else if ([[self entity] hasCapability: kBXEntityCapabilityRelationships] && 
			 [[entity relationshipsByName] objectForKey: aKey])
	{
		retval = kBXDatabaseObjectForeignKey;
	}

    return retval;
}

- (NSDictionary *) primaryKeyFieldObjects
{
    NSArray* pkeyFields = [[self entity] primaryKeyFields];
    NSMutableDictionary* retval = [NSMutableDictionary dictionaryWithCapacity: [pkeyFields count]];
    BXEnumerate (currentKey, e, [pkeyFields objectEnumerator])
        [retval setObject: [self cachedValueForKey: [currentKey name]] forKey: currentKey];
    return retval;
}

- (NSDictionary *) primaryKeyFieldValues
{
	NSDictionary* attrs = [[self entity] attributesByName];
    NSMutableDictionary* retval = [NSMutableDictionary dictionaryWithCapacity: [attrs count]];
	BXEnumerate (currentKey, e, [attrs keyEnumerator])
	{
		if ([[attrs objectForKey: currentKey] isPrimaryKey])
			[retval setObject: [self cachedValueForKey: currentKey] forKey: currentKey];
	}
	return retval;
}

- (void) removeFromCache: (NSString *) aKey postingKVONotifications: (BOOL) posting
{
	BOOL didBecomeFault = NO;
	NSArray* pkeyFNames = [[[[self objectID] entity] primaryKeyFields] valueForKey: @"name"];
	@synchronized (mValues)
	{
		if (nil == aKey)
		{
			BXEnumerate (currentKey, e, [[mValues allKeys] objectEnumerator])
			{
				if (! [pkeyFNames containsObject: currentKey])
				{
					didBecomeFault = YES;
					if (posting) [self willChangeValueForKey: currentKey];
					[mValues removeObjectForKey: currentKey];
					if (posting) [self didChangeValueForKey: currentKey];
				}
			}
		}
		else if (! [pkeyFNames containsObject: aKey] && [mValues objectForKey: aKey])
		{
			didBecomeFault = YES;
			if (posting) [self willChangeValueForKey: aKey];
			[mValues removeObjectForKey: aKey];
			if (posting) [self didChangeValueForKey: aKey];
		}
	}
	if (didBecomeFault)
		[self didTurnIntoFault];
}	

- (NSDictionary *) valuesForRelationships: (id) relationships fireFault: (BOOL) fireFault
{
	Expect (relationships);
	NSMutableDictionary* retval = [NSMutableDictionary dictionaryWithCapacity: [relationships count]];
	BXEnumerate (currentRelationship, e, [relationships objectEnumerator])
	{
		BXDatabaseObject* value = [currentRelationship registeredTargetFor: self fireFault: fireFault];
		if (value)
			[retval setObject: value forKey: currentRelationship];
	}
	return retval;
}

- (void) changeInverseToOneRelationships: (id) relationships 
									from: (NSDictionary *) oldTargets 
									  to: (NSDictionary *) newTargets 
								callback: (void (*)(id, NSString*)) callback
{
	//The given relationships respond to -isInverse with YES.
	ExpectV (relationships);
	BXEnumerate (currentRelationship, e, [relationships objectEnumerator])
	{
		callback (self, [currentRelationship name]);
		BXRelationshipDescription* inverse = (BXRelationshipDescription *) [currentRelationship inverseRelationship];
		if (inverse)
		{
			BXDatabaseObject* oldTarget = [oldTargets objectForKey: currentRelationship];
			BXDatabaseObject* newTarget = [newTargets objectForKey: currentRelationship];
			if (oldTarget && newTarget)
			{
				NSString* inverseName = [inverse name];
				callback (oldTarget, inverseName);
				callback (newTarget, inverseName);
			}
		}
	}	
}

static void
WillChange (id sender, NSString* key)
{
	[sender willChangeValueForKey: key];
}

static void
DidChange (id sender, NSString* key)
{
	[sender didChangeValueForKey: key];
}

- (void) willChangeInverseToOneRelationships: (id) relationships from: (NSDictionary *) oldTargets to: (NSDictionary *) newTargets
{
	[self changeInverseToOneRelationships: relationships from: oldTargets to: newTargets callback: &WillChange];
	@synchronized (mValues)
	{
		BXEnumerate (currentRel, e, [relationships objectEnumerator])
			[mValues removeObjectForKey: [currentRel name]];
	}
}

- (void) didChangeInverseToOneRelationships: (id) relationships from: (NSDictionary *) oldTargets to: (NSDictionary *) newTargets
{
	@synchronized (mValues)
	{
		BXEnumerate (currentRel, e, [relationships objectEnumerator])
		{
			id newValue = [newTargets objectForKey: currentRel];
			if (newValue)
				[mValues setObject: newValue forKey: [currentRel name]];
		}
	}
	[self changeInverseToOneRelationships: relationships from: oldTargets to: newTargets callback: &DidChange];
}
@end
