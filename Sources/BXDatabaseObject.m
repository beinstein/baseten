//
// BXDatabaseObject.m
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://www.karppinen.fi/baseten/licensing/ or by contacting
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

#import "BXDatabaseObject.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseContextPrivate.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXDatabaseAdditions.h"
#import "BXEntityDescription.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXConstants.h"
#import "BXRelationshipDescriptionProtocol.h"
#import "BXPropertyDescription.h"
#import "BXObjectStatusInfo.h"


static NSString* 
MakeKey (const char* start, const int length)
{
    size_t size = length + 1;
    char* copy = malloc (size * sizeof (char));
    strlcpy (copy, start, size);
    copy [0] = tolower (copy [0]);
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
* Is the given selector a setter or a getter?
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
 * A class that represents a single row in a database table.
 * The objects returned by the database context are instances of this class 
 * or its subclasses. The class is KVC-compliant. It class is not 
 * thread-safe, i.e. if methods of an BXDatabaseObject instance will be called from 
 * different threads the result is undefined and deadlocks are possible.
 */
@implementation BXDatabaseObject

+ (BOOL) accessInstanceVariablesDirectly
{
    return NO;
}

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
        rval = [NSString stringWithFormat: @"%@ (%p) \n\t\tURI: %@ \n\t\tisFault: %d \n\t\tentity: %@ \n\t\tvalues: %@", 
            [self class], self, [[self objectID] URIRepresentation], [self isFaultKey: nil], [[mObjectID entity] name], mValues];
    }
    return rval;
}

/** The database context to which this object is registered. */
- (BXDatabaseContext *) databaseContext
{
    return mContext;
}

/**
 * Test object equality.
 * Currently objects are considered equal if they are managed by the same database context and
 * their object IDs are equal.
 */
- (BOOL) isEqual: (BXDatabaseObject *) anObject
{
    BOOL rval = NO;
    if (YES == [anObject isKindOfClass: [BXDatabaseObject class]])
    {
        if (mContext == [anObject databaseContext] && [mObjectID isEqual: [anObject objectID]])
            rval = YES;
    }
    return rval;
}

- (void) queryFailed: (NSError *) error
{
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        mContext,    kBXContextKey,
        error,       kBXErrorKey,
        nil];
    @throw [NSException exceptionWithName: kBXFailedToExecuteQueryException
                                   reason: [error localizedDescription]
                                 userInfo: userInfo];
}

/** 
 * A convenience method for retrieving values for multiple keys. 
 * \param   keys    An NSArray of NSStrings
 * \return          The requested values.
 */
- (NSArray *) valuesForKeys: (NSArray *) keys
{
    NSMutableArray* rval = [NSMutableArray arrayWithCapacity: [keys count]];
    TSEnumerate (currentKey, e, [keys objectEnumerator])
    {
        id value = [self valueForKey: currentKey];
        [rval addObject: value ? value : [NSNull null]];
    }
    return rval;
}

/**
 * Value or objects from the database.
 * Look up the value from the cache or ask the database context to fetch it.
 * Currently this method calls -primitiveValueForKey:.
 * \param   aKey    A BXPropertyDescription.
 * \return          An object or an NSArray of BXDatabaseObjects.
 */
- (id) objectForKey: (BXPropertyDescription *) aKey
{
    return [self valueForKey: [aKey name]];
}

/** 
 * A convenience method for retrieving values for multiple keys. 
 * \param   keys    An NSArray of BXPropertyDescriptions 
 * \return          The requested values.
 */
- (NSArray *) objectsForKeys: (NSArray *) keys
{
    return [self valuesForKeys: [keys valueForKey: @"name"]];
}

- (id) valueForUndefinedKey: (NSString *) aKey
{
    return [self primitiveValueForKey: aKey];
}

- (void) setValue: (id) aValue forUndefinedKey: (NSString *) aKey
{
    [self setPrimitiveValue: aValue forKey: aKey];
}

- (BOOL) validateValue: (id *) ioValue forKey: (NSString *) key error: (NSError **) outError
{
	BOOL rval = YES;
	rval = [self checkNullConstraintForValue: ioValue key: key error: outError];
	if (YES == rval)
		rval = [super validateValue: ioValue forKey: key error: outError];
	return rval;
}

/** The object's ID */
- (BXDatabaseObjectID *) objectID
{
    return mObjectID;
}

/**
* \internal
 * Register the object with a context.
 * In order to function properly, the database object needs to know about its context and its entity.
 * Registration is possible only if the object has not already been assigned a context. 
 * \return A boolean indicating whether the operation was successful or not.
 */
- (BOOL) registerWithContext: (BXDatabaseContext *) ctx entity: (BXEntityDescription *) entity
{
    BOOL rval = NO;
    if (nil == mContext)
    {
        //Object ID
        NSArray* pkeyFields = [entity primaryKeyFields];
        NSArray* pkeyFValues = nil;

        @synchronized (mValues)
        {
            pkeyFValues = [mValues objectsForKeys: [pkeyFields valueForKey: @"name"] notFoundMarker: nil];
        }
        
        NSDictionary* pkeyDict = [NSDictionary dictionaryWithObjects: pkeyFValues forKeys: pkeyFields];
        
        mObjectID = [[BXDatabaseObjectID alloc] initWithEntity: entity
                                              primaryKeyFields: pkeyDict];
        
        if (YES == [ctx registerObject: self])
        {
            rval = YES;
            [self removePrimaryKeyValuesFromStore];
            
            //Context
            mContext = ctx; //Weak
        }
    }
    return rval;
}

/**
* \internal
 * Register the object with a context.
 * Register with a pre-defined object ID
 * \return A boolean indicating whether the operation was successful or not.
 */
- (BOOL) registerWithContext: (BXDatabaseContext *) ctx objectID: (BXDatabaseObjectID *) anID
{
    BOOL rval = NO;
    if (nil == mContext)
    {
        mObjectID = [anID retain];
        if (YES == [ctx registerObject: self])
        {
            rval = YES;
            [self removePrimaryKeyValuesFromStore];
            
            //Context
            mContext = ctx; //Weak
        }        
    }
    return rval;
}

/**
 * \internal
 * Remove the primary key values from store.
 * This should be done after setting the object ID, since
 * it will be used to fetch the values thereafter.
 */
- (void) removePrimaryKeyValuesFromStore
{
    NSAssert (nil != mObjectID, nil);
    TSEnumerate (currentKey, e, [[mObjectID primaryKeyFieldValues] keyEnumerator])
    {
        NSString* name = [currentKey name];
        [self setCachedValue: nil forKey: name];
    }
}

- (id) valueForKeyPath: (NSString *) keyPath
{
    id rval = nil;
    NSArray* components = [mContext keyPathComponents: keyPath];
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

- (NSDictionary *) cachedObjects
{
    NSDictionary* cachedValues = [self cachedValues];
    BXEntityDescription* entity = [[self objectID] entity];
    NSMutableDictionary* rval = [NSMutableDictionary dictionaryWithCapacity: [cachedValues count]];
    TSEnumerate (currentFName, e, [cachedValues keyEnumerator])
    {
        BXPropertyDescription* desc = 
            [BXPropertyDescription propertyWithName: currentFName entity: entity];
        [rval setObject: [cachedValues objectForKey: currentFName] forKey: desc];
    }
    return rval;
}

- (void) BXDatabaseContextWillDealloc
{
    mContext = nil;
}

- (void) clearStatus
{
    if (kBXObjectNoLockStatus != mLockStatus)
    {
        [self willChangeValueForKey: @"statusInfo"];
        mLockStatus = kBXObjectNoLockStatus;
        [self didChangeValueForKey: @"statusInfo"];
    }
}

/**
 * \internal
 * Lock the object in an asynchronous manner.
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

/**
 * Whether the object has beed deleted or 
 * is going to be deleted after the next commit.
 */
- (BOOL) isDeleted
{
    return (kBXObjectDeletedStatus == mLockStatus);
}

- (void) setDeleted
{
    if (kBXObjectDeletedStatus != mLockStatus)
    {
        [self willChangeValueForKey: @"statusInfo"];
        mLockStatus = kBXObjectDeletedStatus;
        [self didChangeValueForKey: @"statusInfo"];
    }
}

/**
 * A proxy for monitoring the object status.
 */
- (id <BXObjectStatusInfo>) statusInfo
{
    return [BXObjectStatusInfo statusInfoWithTarget: self];
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) aSelector
{
    NSMethodSignature* rval = [super methodSignatureForSelector: aSelector];
    if (nil == rval)
    {
        switch (ParseSelector (aSelector, NULL))
        {
            case 2:
                rval = [super methodSignatureForSelector: @selector (setPrimitiveValue:forKey:)];
                break;
            case 1:
                rval = [super methodSignatureForSelector: @selector (primitiveValueForKey:)];
                break;
            case 0:
            default:
                break;
        }
    }
    return rval;
}

- (void) forwardInvocation: (NSInvocation *) invocation
{
    NSString* key = nil;
    switch (ParseSelector ([invocation selector], &key))
    {
        case 2:
            [invocation setSelector: @selector (setPrimitiveValue:forKey:)];
            [invocation setArgument: &key atIndex: 3];
            break;
        case 1:
            [invocation setSelector: @selector (primitiveValueForKey:)];
            [invocation setArgument: &key atIndex: 2];
            break;
        case 0:
        default:
            break;
    }
    [invocation invokeWithTarget: self];
}

/**
 * Value from the object's cache.
 * This method is thread-safe. Primary key values should be accessed using the object ID instead.
 * \return      The value in question or nil, if it has not been fetched from the database yet.
 */
- (id) cachedValueForKey: (NSString *) aKey
{
    id rval = nil;
    @synchronized (mValues)
    {
        rval = [mValues valueForKey: aKey];
    }
    return rval;
}

- (void) setCachedValue: (id) aValue forKey: (NSString *) aKey
{
    @synchronized (mValues)
    {
        [self willChangeValueForKey: aKey];
        if (nil == aValue)
            [mValues removeObjectForKey: aKey];
        else
            [mValues setValue: aValue forKey: aKey];
        [self didChangeValueForKey: aKey];
    }
}

/**
 * Value or objects from the database.
 * Look up the value from the cache or ask the database context to fetch it.
 * \param   aKey    Name of the column, a foreign key in the table,
 *                  a foreign key pointing to the object's table or a helper table.
 * \return          An object or an NSArray of BXDatabaseObjects.
 */
- (id) primitiveValueForKey: (NSString *) aKey
{
    id rval = [self cachedValueForKey: aKey];
    if (nil == rval)
        rval = [mObjectID valueForKey: aKey];
    
    if (nil == rval)
    {
        switch ([self isFaultKey: aKey])
        {
            case 1:
            {
                NSAssert (nil != mContext, nil);
                NSError* error = nil;
                if (NO == [mContext fireFault: self key: aKey error: &error])
                    [self queryFailed: error];
                rval = [self cachedValueForKey: aKey];
                break;
            }
            case -1: //Unknown key; try foreign keys
            {
                NSAssert (nil != mContext, nil);
                NSError* error = nil;
                BXEntityDescription* entity = [mObjectID entity];
                id <BXRelationshipDescription> rel = [entity relationshipNamed: aKey context: mContext error: &error];
                if (nil != error) [self queryFailed: error];
                //Don't cache the results to prevent a retain cycle.
                rval = [rel resolveFrom: self to: [entity targetForRelationship: rel] error: &error];
                if (nil != error) [self queryFailed: error];
                break;
            }
            default:
                NSAssert (NO, nil);
                break;
        }
    }
    
    if (nil == rval)
        rval = [super valueForUndefinedKey: aKey];
    if ([NSNull null] == rval)
        rval = nil;
    
    return [[rval retain] autorelease];
}

/** 
 * Set value for a given key in the database.
 * \param   aVal    The new value.
 * \param   aKey    An NSString.
 */
- (void) setPrimitiveValue: (id) aVal forKey: (NSString *) aKey
{    
    NSAssert (nil != mContext, nil);
    NSError* error = nil;
    
    //We only need the old value when autocommitting.
    id oldValue = nil;
    if ([mContext autocommits] && nil != [mContext undoManager])
        oldValue = [self valueForKey: aKey];
    
    switch ([self isFaultKey: aKey])
    {
        case 0:
        case 1:
        {            
            //Known key
            if (nil == aVal)
                aVal = [NSNull null];
            [mContext executeUpdateObject: self key: aKey value: aVal error: &error];            
            break;
        }
        case -1:
        {
            //Unknown key; try foreign keys
            BXEntityDescription* entity = [mObjectID entity];
            id <BXRelationshipDescription> rel = [entity relationshipNamed: aKey context: mContext error: &error];
            if (nil == rel)
            {
                //No such foreign key
                [super setValue: aVal forUndefinedKey: aKey];
            }
            [rel setTarget: aVal referenceFrom: self error: &error];
            break;
        }
        default:
        {
            NSAssert (NO, nil);
            break;
        }
    }
    
    if (nil == error)
    {
        //Undo in case of autocommit
        if ([mContext autocommits])
            [[[mContext undoManager] prepareWithInvocationTarget: self] setPrimitiveValue: oldValue forKey: aKey];
    }
    else
    {
        [self queryFailed: error];
    }
}

/**
 * Set multiple values.
 * This is not merely a convenience method; invoking this is potentially much faster than 
 * repeatedly using -setPrimitiveValue:forKey:. For foreign keys, -setPrimitiveValue:forKey: 
 * should be used instead.
 */
- (void) setPrimitiveValuesForKeysWithDictionary: (NSDictionary *) aDict
{
    NSAssert (nil != mContext, nil);
    NSError* error = nil;
    if (NO == [mContext executeUpdateObject: self withDictionary: aDict error: &error])
        [self queryFailed: error];
}

/** 
 * \internal
 * A convenience method for handling the object's cache.
 */
- (void) setCachedValuesForKeysWithDictionary: (NSDictionary *) aDict
{
    @synchronized (mValues)
    {
        [mValues addEntriesFromDictionary: aDict];
    }
}

/** Fault the given key. */
- (void) faultKey: (NSString *) aKey
{
    @synchronized (mValues)
    {
        if (nil == aKey)
        {
            NSArray* keys = [mValues allKeys];
            TSEnumerate (currentKey, e, [keys objectEnumerator])
                [self willChangeValueForKey: currentKey];
            [mValues removeAllObjects];
            TSEnumerate (currentKey, e, [keys objectEnumerator])
                [self didChangeValueForKey: currentKey];
        }
        else
        {
            [self willChangeValueForKey: aKey];
            [mValues removeObjectForKey: aKey];
            [self didChangeValueForKey: aKey];
        }
    }
}

/** 
 * Whether the given key s faulted or not.
 * \param   aKey    An NSString. May be nil, in which case the object
 *                  is considered a fault if value for any of its keys is
 *                  not cached.
 * \return  0 if the corresponding value is in cache, 1 if not, 
 *          -1 if the key is presently unknown.
 */
- (int) isFaultKey: (NSString *) aKey
{
    int rval = -1; //Unknown key
    if (nil == aKey)
    {
        rval = 0;
        NSArray* knownKeys = [[self cachedValues] allKeys];
        TSEnumerate (currentProp, e, [[[mObjectID entity] fields] objectEnumerator])
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
    else if (nil != [mObjectID propertyNamed: aKey])
    {
        //Primary key fields are never faults
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
 * Values from the object's cache.
 * This method is thread-safe.
 * \return      An NSDictionary which contains the cached values.
 */
- (NSDictionary *) cachedValues
{
    id rval = nil;
    @synchronized (mValues)
    {
        rval = [mValues copy];
    }
    return rval;
}

/**
 * Whether the given key is locked locked or not.
 * Returns YES if modifying the given key would block.
 * Current implementation locks the whole object
 * when any key gets locked.
 */
- (BOOL) isLockedForKey: (NSString *) aKey
{
    return (kBXObjectLockedStatus == mLockStatus);
}

/**
 * Set lock status for the given key.
 */
- (void) setLockedForKey: (NSString *) aKey
{
    if (kBXObjectLockedStatus != mLockStatus)
    {
        [self willChangeValueForKey: @"statusInfo"];
        mLockStatus = kBXObjectLockedStatus;
        [self didChangeValueForKey: @"statusInfo"];
    }
}

- (BOOL) checkNullConstraintForValue: (id *) ioValue key: (NSString *) key error: (NSError **) outError
{
	BOOL rval = YES;
	NSAssert (NULL != ioValue, @"Expected ioValue not to be NULL.");
	id value = *ioValue;
	BXPropertyDescription* property = [[[mObjectID entity] attributesByName] objectForKey: key];
	if (NO == [property isOptional] && (nil == value || [NSNull null] == value))
	{
		rval = NO;
		if (NULL != outError)
		{
			NSString* message = BXLocalizedString (@"nullValueGivenForNonOptionalField", @"This field requires a non-null value.", @"Error description");
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                BXSafeObj (property), kBXPropertyKey,
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

@end


@implementation BXDatabaseObject (Subclassing)
/**
 * \name Methods that subclasses might override
 * \note Subclasses should not assume that their accessors would be used
 *       when resolving relationships. Instead, -primitiveValueForKey: will be used.
 */
//@{
//
/**
 * Callback for deserializing the row.
 */
- (void) awakeFromFetch
{
}

/**
* Callback for creating the row.
 */
- (void) awakeFromInsert
{
}

/** The designated initializer */
- (id) init
{
    if ((self = [super init]))
    {
        @synchronized (mValues)
        {
            mValues = [[NSMutableDictionary alloc] init];
        }
        mLockStatus = kBXObjectNoLockStatus;
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

@end
