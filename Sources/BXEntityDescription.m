//
// BXEntityDescription.m
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
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

#import "BXEntityDescription.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseContext.h"
#import "BXAttributeDescription.h"
#import "BXRelationshipDescription.h"
#import "BXAttributeDescriptionPrivate.h"
#import "BXPropertyDescriptionPrivate.h"
#import "BXDatabaseObject.h"

#import <TSDataTypes/TSDataTypes.h>
#import <Log4Cocoa/Log4Cocoa.h>


static TSNonRetainedObjectDictionary* gEntities;


/**
 * An entity description contains information about a specific table
 * in a given database.
 * Only one entity description instance is created for a combination of a database,
 * a schema and a table.
 *
 * This class is not thread-safe, i.e. 
 * if methods of an BXEntityDescription instance will be called from 
 * different threads the result is undefined.
 */
@implementation BXEntityDescription

+ (void) initialize
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        gEntities = [[TSNonRetainedObjectDictionary alloc] init];
    }
}

- (id) init
{
	log4Error (@"This initializer should not have been called.");
    [self release];
    return nil;
}

- (id) initWithName: (NSString *) aName
{
	log4Error (@"This initializer should not have been called (name: %@).", aName);
    [self release];
    return nil;
}

/** \note Override dealloc2 in subclasses instead! */
- (void) dealloc
{
	@synchronized (gEntities)
	{
		[gEntities removeObjectForKey: [self entityKey]];
	}
    
    @synchronized (mRelationships)
    {
        TSEnumerate (currentRel, e, [mRelationships objectEnumerator])
        {
            [currentRel setEntity: nil];
            [[currentRel inverseRelationship] setDestinationEntity: nil];
        }
    }
    
	[self dealloc2];
	
	//Suppress a compiler warning.
	if (0) [super dealloc];
}

- (void) dealloc2
{
	[mRelationships release];
	mRelationships = nil;
	
	[mAttributes release];
	mAttributes = nil;
	
	[mDatabaseURI release];
	mDatabaseURI = nil;
	
	[mSchemaName release];
	mSchemaName = nil;
	
	[mValidationLock release];
	mValidationLock = nil;
	
    [super dealloc];
}

/** The schema name. */
- (NSString *) schemaName
{
    return [[mSchemaName retain] autorelease];
}

/** The database URI. */
- (NSURL *) databaseURI
{
    return mDatabaseURI;
}

- (id) initWithCoder: (NSCoder *) decoder
{
    NSURL* databaseURI = [decoder decodeObjectForKey: @"databaseURI"];
    NSString* schemaName = [decoder decodeObjectForKey: @"schemaName"];
    NSString* name = [decoder decodeObjectForKey: @"name"];
    id rval = [[[self class] entityWithDatabaseURI: databaseURI table: name inSchema: schemaName] retain];
    
    Class cls = NSClassFromString ([decoder decodeObjectForKey: @"databaseObjectClassName"]);
    if (Nil != cls)
        [rval setDatabaseObjectClass: cls];
		
	[self setAttributes: [decoder decodeObjectForKey: @"attributes"]];
	//FIXME: relationships as well?
 	        
    return rval;
}

- (void) encodeWithCoder: (NSCoder *) encoder
{
    [encoder encodeObject: mName forKey: @"name"];
    [encoder encodeObject: mSchemaName forKey: @"schemaName"];
    [encoder encodeObject: mDatabaseURI forKey: @"databaseURI"];
    [encoder encodeObject: NSStringFromClass (mDatabaseObjectClass) forKey: @"databaseObjectClassName"];
	[encoder encodeObject: mAttributes forKey: @"attributes"];
	//FIXME: relationships as well?
}

/** Retain on copy. */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}

- (BOOL) isEqual: (id) anObject
{
    BOOL retval = NO;
    
    if (self == anObject)
        retval = YES;
    else if ([anObject isKindOfClass: [self class]] && [super isEqual: anObject])
	{
		
		BXEntityDescription* aDesc = (BXEntityDescription *) anObject;
        
		log4AssertValueReturn (nil != mName && nil != mSchemaName && nil != mDatabaseURI, NO, 
							   @"Properties should not be nil in -isEqual:.");
		log4AssertValueReturn (nil != aDesc->mName && nil != aDesc->mSchemaName && nil != aDesc->mDatabaseURI, NO, 
							   @"Properties should not be nil in -isEqual:.");
		
		
		if (![mSchemaName isEqualToString: aDesc->mSchemaName])
			goto bail;
		
		if (![mDatabaseURI isEqual: aDesc->mDatabaseURI])
			goto bail;
			
		retval = YES;
	}
bail:
    return retval;
}

- (unsigned int) hash
{
    if (0 == mHash)
    {
        //We use a real hash function with the URI.
        mHash = ([super hash] ^ [mSchemaName hash] ^ [mDatabaseURI BXHash]);
    }
    return mHash;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<%@ %@ (%p)>", mDatabaseURI, [self name], self];
}

/**
 * Set the class for the entity.
 * Objects fetched using this entity are instances of
 * the given class, which needs to be a subclass of BXDatabaseObject.
 * \param       cls         The object class
 */
- (void) setDatabaseObjectClass: (Class) cls
{
    if (YES == [cls isSubclassOfClass: [BXDatabaseObject class]])
	{
        mDatabaseObjectClass = cls;
	}
    else
    {
        NSString* reason = [NSString stringWithFormat: @"Expected %@ to be a subclass of BXDatabaseObject.", cls];
        [NSException exceptionWithName: NSInternalInconsistencyException
                                reason: reason userInfo: nil];
    }
}

/**
 * The class for the entity
 * \return          The default class is BXDatabaseObject
 */
- (Class) databaseObjectClass
{
    return mDatabaseObjectClass;
}

/**
 * Set the primary key fields for this entity.
 * Normally the database context determines the primary key, when
 * an entity is used in a database query. However, when an entity is a view, the fields
 * may need to be set manually before using the entity in a query.
 * \param   anArray     An NSArray of NSStrings.
 * \internal
 * \note BXAttributeDescriptions should only be created here and in -[BXInterface validateEntity:]
 */
- (void) setPrimaryKeyFields: (NSArray *) anArray
{
	if (nil != anArray)
	{
		NSMutableDictionary* attributes = [[mAttributes mutableCopy] autorelease];
		TSEnumerate (currentField, e, [anArray objectEnumerator])
		{
			BXAttributeDescription* attribute = nil;
			if ([currentField isKindOfClass: [BXAttributeDescription class]])
			{
				log4AssertVoidReturn ([currentField entity] == self, 
									  @"Expected to receive only attributes in which entity is self (self: %@ currentField: %@).",
									  self, currentField);
				attribute = currentField;
			}
			else if ([currentField isKindOfClass: [NSString class]])
			{
                attribute = [BXAttributeDescription attributeWithName: currentField entity: self];
			}
			[attribute setPrimaryKey: YES];
			[attribute setOptional: NO];
			[attributes setObject: attribute forKey: [attribute name]];
		}
		[self setAttributes: attributes];
	}
}

/**
 * Registered object IDs for this entity.
 */
- (NSArray *) objectIDs
{
	return [mObjectIDs allObjects];
}

/**
 * Primary key fields for this entity.
 * The fields get determined automatically after database connection has been made.
 * \return          An array of BXAttributeDescriptions
 */
- (NSArray *) primaryKeyFields
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"YES == isPrimaryKey"];
	NSArray* rval = [[[mAttributes allValues] filteredArrayUsingPredicate: predicate] 
			sortedArrayUsingSelector: @selector (caseInsensitiveCompare:)];
	if (0 == [rval count]) rval = nil;
	return rval;
}

/** 
 * Fields for this entity.
 * \return          An array of BXAttributeDescriptions
 */
- (NSArray *) fields
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"NO == isPrimaryKey"];
	NSArray* rval = [[[mAttributes allValues] filteredArrayUsingPredicate: predicate] 
			sortedArrayUsingSelector: @selector (caseInsensitiveCompare:)];
	if (0 == [rval count]) rval = nil;
	return rval;
}

/** Whether this entity is marked as a view or not. */
- (BOOL) isView
{
    return mFlags & kBXEntityIsView;
}

- (NSComparisonResult) caseInsensitiveCompare: (BXEntityDescription *) anotherEntity
{
    log4AssertValueReturn ([anotherEntity isKindOfClass: [BXEntityDescription class]], NSOrderedSame, 
					 @"Entity descriptions can only be compared with other similar objects for now.");
    NSComparisonResult rval = NSOrderedSame;
    if (self != anotherEntity)
    {
        rval = [mSchemaName caseInsensitiveCompare: [anotherEntity schemaName]];
        if (NSOrderedSame == rval)
        {
            rval = [mName caseInsensitiveCompare: [anotherEntity name]];
        }
    }
    return rval;
}

/** 
 * Attributes for this entity.
 * Primary key fields and other fields for this entity.
 * \return          An NSDictionary with NSStrings as keys and BXAttributeDescriptions as objects.
 */
- (NSDictionary *) attributesByName
{
	return mAttributes;
}

/**
 * Entity validation.
 * The entity will be validated after database connection has been made. Afterwards, 
 * -fields, -primaryKeyFields and -attributesByName return meaningful values.
 */
- (BOOL) isValidated
{
	return mFlags & kBXEntityIsValidated;
}

- (NSDictionary *) relationshipsByName
{
	return [mRelationships dictionary];
}
@end


@implementation BXEntityDescription (PrivateMethods)

- (NSURL *) entityKey
{
	return [[self class] entityKeyForDatabaseURI: mDatabaseURI schema: mSchemaName table: mName];
}

+ (NSURL *) entityKeyForDatabaseURI: (NSURL *) databaseURI schema: (NSString *) schemaName table: (NSString *) tableName
{
	return [NSURL URLWithString: [NSString stringWithFormat: @"%@/%@", schemaName, tableName] relativeToURL: databaseURI];
}

/**
 * \internal
 * \name Retrieving an entity description
 */
//@{
/**
 * \internal
 * Create the entity.
 * \param       anURI   The database URI
 * \param       tName   Table name
 * \param       sName   Schema name
 */
+ (id) entityWithDatabaseURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName
{
	id retval = nil;
	@synchronized (gEntities)
	{
		if (nil == sName)
			sName = @"public";
		
		NSURL* uri = [self entityKeyForDatabaseURI: anURI schema: sName table: tName];
		
		retval = [gEntities objectForKey: uri];
		if (nil == retval)
		{
			retval = [[[self alloc] initWithDatabaseURI: anURI table: tName inSchema: sName] autorelease];
			[gEntities setObject: retval forKey: uri];
		}		
	}
	
	return retval;
}

/**
 * \internal
 * The designated initializer.
 * Create the entity.
 * \param       anURI   The database URI
 * \param       tName   Table name
 * \param       sName   Schema name
 */
- (id) initWithDatabaseURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName
{
	log4AssertValueReturn (nil != sName, nil, @"Expected sName not to be nil.");
	log4AssertValueReturn (nil != anURI, nil, @"Expected anURI to be set.");
	
    if ((self = [super initWithName: tName]))
    {
        mDatabaseObjectClass = [BXDatabaseObject class];
        mDatabaseURI = [anURI copy];
        mSchemaName = [sName copy];
		mRelationships = [[TSNonRetainedObjectDictionary alloc] init];
		mObjectIDs = [[TSNonRetainedObjectSet alloc] init];
		mValidationLock = [[NSRecursiveLock alloc] init];
    }
    return self;
}
//@}

- (void) registerObjectID: (BXDatabaseObjectID *) anID
{
	@synchronized (mObjectIDs)
	{
		log4AssertVoidReturn ([anID entity] == self, 
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

- (void) setAttributes: (NSDictionary *) attributes
{
	if (attributes != mAttributes)
	{
		[mAttributes release];
		mAttributes = [attributes copy];
	}
}

- (void) setDatabaseURI: (NSURL *) anURI
{
	//In case we really modify the URI, remove self from collections and have the hash calculated again.
	if (anURI != mDatabaseURI && NO == [anURI isEqual: mDatabaseURI])
	{
		@synchronized (gEntities)
		{
			[gEntities removeObjectForKey: [self entityKey]];
			mHash = 0;
			
			[mDatabaseURI release];
			mDatabaseURI = [anURI retain];
			
			[gEntities setObject: self forKey: [self entityKey]];
		}
	}
}

- (void) resetAttributeExclusion
{
	TSEnumerate (currentProp, e, [mAttributes objectEnumerator])
		[currentProp setExcluded: NO];
}

- (NSArray *) attributes: (NSArray *) strings
{
	NSMutableArray* rval = nil;
	if (0 < [strings count])
	{
		rval = [NSMutableArray arrayWithCapacity: [strings count]];
		TSEnumerate (currentField, e, [strings objectEnumerator])
		{
			if ([currentField isKindOfClass: [NSString class]])
				currentField = [mAttributes objectForKey: currentField];
			log4AssertValueReturn ([currentField isKindOfClass: [BXAttributeDescription class]], nil, 
								   @"Expected to receive NSStrings or BXAttributeDescriptions (%@ was a %@).",
								   currentField, [currentField class]);
			
			[rval addObject: currentField];
		}
	}
	return rval;
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

- (void) setRelationships: (NSDictionary *) aDict
{
	//FIXME: this is a bit bad.
    @synchronized (mRelationships)
    {
        TSEnumerate (currentKey, e, [mRelationships keyEnumerator])
            [mRelationships removeObjectForKey: currentKey];
	
        TSEnumerate (currentKey, e, [aDict keyEnumerator])
        {
            [mRelationships setObject: [aDict objectForKey: currentKey]
                               forKey: currentKey];
        }
    }
}

- (NSLock *) validationLock
{
	return mValidationLock;
}

- (void) removeRelationship: (BXRelationshipDescription *) aRelationship;
{
    @synchronized (mRelationships)
    {
        [mRelationships removeObjectForKey: [aRelationship name]];
    }
}

@end
