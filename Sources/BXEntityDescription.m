//
// BXEntityDescription.m
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

#import "BXEntityDescription.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseContext.h"
#import "BXAttributeDescription.h"
#import "BXRelationshipDescription.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXAttributeDescriptionPrivate.h"
#import "BXPropertyDescriptionPrivate.h"
#import "BXDatabaseObject.h"
#import "BXConstantsPrivate.h"
#import "BXLogger.h"
#import "BXWeakNotification.h"
#import "PGTSHOM.h"
#import "PGTSCollections.h"
#import "BXEnumerate.h"
#import "NSURL+BaseTenAdditions.h"


/**
 * An entity description contains information about a specific table
 * in a given database.
 * Only one entity description instance is created for a combination of a database
 * URI, a schema and a table.
 *
 * \note This class is thread-safe.
 * \ingroup descriptions
 */
@implementation BXEntityDescription
- (void) dealloc
{
	[mDatabaseURI release];
	[mSchemaName release];
	[mAttributes release];
	[mValidationLock release];
	[mObjectIDs release];
	[mRelationships release];
	
	[super dealloc];
}

/** 
 * \brief The schema name. 
 */
- (NSString *) schemaName
{
    return [[mSchemaName retain] autorelease];
}

/** 
 * \brief The database URI. 
 */
- (NSURL *) databaseURI
{
    return [[mDatabaseURI retain] autorelease];
}

- (id) initWithCoder: (NSCoder *) decoder
{
    NSString* name = [decoder decodeObjectForKey: @"name"];
	NSString* schemaName = [decoder decodeObjectForKey: @"schemaName"];
	NSURL* databaseURI = [decoder decodeObjectForKey: @"databaseURI"];

	if ((self = [self initWithDatabaseURI: databaseURI table: name inSchema: schemaName]))
	{
		Class cls = NSClassFromString ([decoder decodeObjectForKey: @"databaseObjectClassName"]);
		if (Nil != cls)
			[self setDatabaseObjectClass: cls];
		[self setAttributes: [decoder decodeObjectForKey: @"attributes"]];
	}
	return self;
}

- (void) encodeWithCoder: (NSCoder *) encoder
{
    [encoder encodeObject: mName forKey: @"name"];
    [encoder encodeObject: mSchemaName forKey: @"schemaName"];
    [encoder encodeObject: mDatabaseURI forKey: @"databaseURI"];
    [encoder encodeObject: NSStringFromClass (mDatabaseObjectClass) forKey: @"databaseObjectClassName"];
	[encoder encodeObject: mAttributes forKey: @"attributes"];
	//FIXME: relationships as well?
	[super encodeWithCoder: encoder];
}

/** 
 * \brief Retain on copy. 
 */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}

- (BOOL) isEqual: (BXEntityDescription *) desc
{
    BOOL retval = NO;
    
    if (self == desc)
        retval = YES;
    else if ([super isEqual: desc])
	{		
		NSString* s1 = [self schemaName];
		NSString* s2 = [desc schemaName];
		
		if (! [s1 isEqualToString: s2])
			goto bail;
		
		NSURL* u1 = [self databaseURI];
		NSURL* u2 = [self databaseURI];
		
		if (! [u1 isEqual: u2])
			goto bail;
			
		retval = YES;
	}
bail:
    return retval;
}

- (unsigned int) hash
{
    return mHash;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<%@ %@ (%p) validated: %d enabled: %d>", 
			mDatabaseURI, [self name], self, [self isValidated], [self isEnabled]];
}

/**
 * \brief Set the class for this entity.
 *
 * Objects fetched using this entity will be instances of
 * the given class, which needs to be a subclass of BXDatabaseObject.
 * \param   cls     The object class.
 * \note	If objects have been fetched from this entity before setting
 *          a class, those objects might be returned by subsequent
 *          fetches. It is best to set the class before connecting to the
 *          database.
 */
- (void) setDatabaseObjectClass: (Class) cls
{
	if (YES == [cls isSubclassOfClass: [BXDatabaseObject class]])
	{
		@synchronized (self)
		{
			mDatabaseObjectClass = cls;
		}
	}
	else
	{
		NSString* reason = [NSString stringWithFormat: @"Expected %@ to be a subclass of BXDatabaseObject.", cls];
		[NSException exceptionWithName: NSInternalInconsistencyException
								reason: reason userInfo: nil];
	}
}

/**
 * \brief The class for this entity.
 * \return          The default class is BXDatabaseObject.
 */
- (Class) databaseObjectClass
{
	id retval = nil;
	@synchronized (self)
	{
	    retval = mDatabaseObjectClass;
	}
	return retval;
}

/**
 * \brief Registered object IDs for this entity.
 */
- (NSArray *) objectIDs
{
	return [mObjectIDs allObjects];
}

static int
FilterPkeyAttributes (id attribute, void* arg)
{
	int retval = 0;
	long shouldBePkey = (long) arg;
	if ([attribute isPrimaryKey] == shouldBePkey)
		retval = 1;
	return retval;
}

/**
 * \brief Primary key fields for this entity.
 *
 * The fields get determined automatically after database connection has been made.
 * \return          An array of BXAttributeDescriptions
 * \see #isValidated
 */
- (NSArray *) primaryKeyFields
{
	return [mAttributes PGTSValueSelectFunction: &FilterPkeyAttributes argument: (void *) 1L] ?: nil;
}
	
+ (NSSet *) keyPathsForValuesAffectingFields
{
	return [NSSet setWithObject: @"primaryKeyFields"];
}

/** 
 * \brief Non-primary key fields for this entity.
 * \return          An array of BXAttributeDescriptions
 * \see #isValidated
 */
- (NSArray *) fields
{
	return [mAttributes PGTSValueSelectFunction: &FilterPkeyAttributes argument: (void *) 0L] ?: nil;
}

/** 
 * \brief Whether this entity is marked as a view or not. 
 */
- (BOOL) isView
{
    return (mFlags & kBXEntityIsView) ? YES : NO;
}

- (NSComparisonResult) caseInsensitiveCompare: (BXEntityDescription *) anotherEntity
{
    NSComparisonResult retval = NSOrderedSame;
    if (self != anotherEntity)
    {
        retval = [[self schemaName] caseInsensitiveCompare: [anotherEntity schemaName]];
        if (NSOrderedSame == retval)
        {
            retval = [[self name] caseInsensitiveCompare: [anotherEntity name]];
        }
    }
    return retval;
}

/** 
 * \brief Attributes for this entity.
 *
 * Primary key fields and other fields for this entity.
 * \return          An NSDictionary with NSStrings as keys and BXAttributeDescriptions as objects.
 * \see #isValidated
 */
- (NSDictionary *) attributesByName
{
	return [[mAttributes retain] autorelease];
}

/**
 * \brief Entity validation.
 *
 * The entity will be validated after a database connection has been made. Afterwards, 
 * #fields, #primaryKeyFields, #attributesByName and #relationshipsByName return meaningful values.
 *
 * \note To call this safely, mValidationLock should be acquired first. Our validation methods do this, though.
 */
- (BOOL) isValidated
{
	return (mFlags & kBXEntityIsValidated) ? YES : NO;
}

/**
 * \brief Relationships for this entity.
 * \return An NSDictionary with NSStrings as keys and BXRelationshipDescriptions as objects.
 */
- (NSDictionary *) relationshipsByName
{
	if (! [self hasCapability: kBXEntityCapabilityRelationships])
		[NSException raise: NSInvalidArgumentException format: @"Entity %@ doesn't have relationship capability. (BaseTen enabling is required for this.)", self];
	return [[mRelationships retain] autorelease];
}


- (BOOL) hasCapability: (enum BXEntityCapability) aCapability
{
	return (mCapabilities & aCapability ? YES : NO);
}

- (BOOL) isEnabled
{
	return (mFlags & kBXEntityIsEnabled) ? YES : NO;
}

- (void) viewGetsUpdatedWith: (NSArray *) entities
{
	BXAssertVoidReturn ([self isView], @"Expected entity %@ to be a view.", self);
	[self inherits: entities];
}

- (id) viewsUpdated
{
	BXAssertValueReturn ([self isView], nil, @"Expected entity %@ to be a view.", self);
	return [self inheritedEntities];
}

- (void) inherits: (NSArray *) entities
{
    @synchronized (mSuperEntities)
    {
        //FIXME: We only implement cascading notifications from "root tables" to 
        //inheriting tables and not vice-versa.
        //FIXME: only single entity supported for now.
        BXAssertVoidReturn (0 == [mSuperEntities count], @"Expected inheritance/dependant relations not to have been set.");
        BXAssertVoidReturn (1 == [entities count], @"Multiple inheritance/dependant relations is not supported.");
        BXEnumerate (currentEntity, e, [entities objectEnumerator])
        {
            [mSuperEntities addObject: currentEntity];
            [currentEntity addSubEntity: self];
        }
    }
}

- (void) addSubEntity: (BXEntityDescription *) entity
{
    @synchronized (mSubEntities)
    {
        //FIXME: We only implement cascading notifications from "root tables" to 
        //inheriting tables and not vice-versa.
        [mSubEntities addObject: entity];
    }
}

- (id) inheritedEntities
{
    id retval = nil;
    @synchronized (mSuperEntities)
    {
        retval = [mSuperEntities allObjects];
    }
    return retval;
}

- (id) subEntities
{
    id retval = nil;
    @synchronized (mSubEntities)
    {
        retval = [mSubEntities allObjects];
    }
    return retval;
}

/**
 * \internal
 * \brief Whether this entity gets changed by triggers, rules etc.
 *
 * If the entity gets changed only directly, some queries may possibly be optimized.
 */
- (BOOL) getsChangedByTriggers
{
	return mFlags & kBXEntityGetsChangedByTriggers ? YES : NO;
}

- (void) setGetsChangedByTriggers: (BOOL) flag
{
	if (flag)
		mFlags |= kBXEntityGetsChangedByTriggers;
	else
		mFlags &= ~kBXEntityGetsChangedByTriggers;
}
@end


@implementation BXEntityDescription (PrivateMethods)
/**
 * \internal
 * \brief The designated initializer.
 *
 * Create the entity.
 * \param       anURI   The database URI
 * \param       tName   Table name
 * \param       sName   Schema name
 */
- (id) initWithDatabaseURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName
{
	BXAssertValueReturn (nil != sName, nil, @"Expected sName not to be nil.");
	BXAssertValueReturn (nil != anURI, nil, @"Expected anURI to be set.");
	
    if ((self = [super initWithName: tName]))
    {
        mDatabaseObjectClass = [BXDatabaseObject class];
        mDatabaseURI = [anURI copy];
        mSchemaName = [sName copy];
		
		mObjectIDs = PGTSSetCreateMutableWeakNonretaining ();
        mSuperEntities = PGTSSetCreateMutableWeakNonretaining ();
        mSubEntities = PGTSSetCreateMutableWeakNonretaining ();
		
		mValidationLock = [[NSLock alloc] init];
		mHash = ([super hash] ^ [mSchemaName hash] ^ [mDatabaseURI BXHash]);
    }
    return self;
}

- (id) init
{
	[self doesNotRecognizeSelector: _cmd];
    return nil;
}

- (id) initWithName: (NSString *) aName
{
	[self doesNotRecognizeSelector: _cmd];
    return nil;
}
//@}

- (void) registerObjectID: (BXDatabaseObjectID *) anID
{
	@synchronized (mObjectIDs)
	{
		BXAssertVoidReturn ([anID entity] == self, 
							  @"Attempted to register an object ID the entity of which is other than self.\n"
							  "\tanID:\t%@ \n\tself:\t%@", anID, self);
		if (self == [anID entity])
			[mObjectIDs addObject: anID];
	}
}

- (void) unregisterObjectID: (BXDatabaseObjectID *) anID
{
	@synchronized (mObjectIDs)
	{
		[mObjectIDs removeObject: anID];
	}
}

//Not thread-safe.
- (void) setAttributes: (NSDictionary *) attributes
{
	if (attributes != mAttributes)
	{
		[mAttributes release];
		mAttributes = [attributes copy];
	}
}

- (void) resetAttributeExclusion
{
	BXEnumerate (currentProp, e, [mAttributes objectEnumerator])
		[currentProp setExcluded: NO];
}

- (NSArray *) attributes: (NSArray *) strings
{
	return [mAttributes objectsForKeys: strings notFoundMarker: [NSNull null]];
}

- (void) setValidated: (BOOL) flag
{
	if (flag)
		mFlags |= kBXEntityIsValidated;
	else
		mFlags &= ~kBXEntityIsValidated;
}

- (void) setIsView: (BOOL) flag
{
	if (flag)
		mFlags |= kBXEntityIsView;
	else
		mFlags &= ~kBXEntityIsView;
}

//Not thread-safe.
- (void) setRelationships: (NSDictionary *) aDict
{
	if (mRelationships != aDict)
	{
		[mRelationships release];
		mRelationships = [aDict copy];
	}
}

- (void) setHasCapability: (enum BXEntityCapability) aCapability to: (BOOL) flag
{
	if (flag)
		mCapabilities |= aCapability;
	else
		mCapabilities &= ~aCapability;
}

- (void) setEnabled: (BOOL) flag
{
	if (flag)
		mFlags |= kBXEntityIsEnabled;
	else
		mFlags &= ~kBXEntityIsEnabled;
}

static int
InverseToOneRelationships (id arg)
{
	int retval = 0;
	BXRelationshipDescription* relationship = (BXRelationshipDescription *) arg;
	if ([relationship isInverse] && ! [relationship isToMany])
		retval = 1;
	return retval;
}


- (id) inverseToOneRelationships;
{
	return [mRelationships PGTSValueSelectFunction: &InverseToOneRelationships];
}

- (BOOL) beginValidation
{
	BOOL locked = [mValidationLock tryLock];
	if (locked && [self isValidated])
	{
		[mValidationLock unlock];
		locked = NO;
	}
	return locked;
}

- (void) endValidation
{
	if ([self hasCapability: kBXEntityCapabilityRelationships])
	{
		BXEnumerate (currentRelationship, e, [[self relationshipsByName] objectEnumerator])
			[currentRelationship makeAttributeDependency];
	}
	[mValidationLock unlock];
}
@end
