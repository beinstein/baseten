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
#import "BXRelationshipDescriptionProtocol.h"
#import "BXPropertyDescription.h"
#import "BXRelationshipDescription.h"
#import "BXPropertyDescriptionPrivate.h"

#import <TSDataTypes/TSDataTypes.h>


//This cannot be a non-retaining set, since the entities might have been used to
//subscribe notifications. If an entity for a table gets deallocated and created again,
//the notifications won't be received.
static NSMutableSet* gEntities;
static NSMutableSet* gViewEntities;


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
+ (NSSet *) views
{
    return gViewEntities;
}

+ (void) initialize
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        gEntities = [[NSMutableSet alloc] init];
        gViewEntities = [[NSMutableSet alloc] init];
    }
}

- (id) init
{
    //This initializer should not be used
    [self release];
    return nil;
}

- (id) initWithName: (NSString *) aName
{
    //This initializer should not be used
    [self release];
    return nil;
}

- (void) dealloc
{
    [mRelationships release];
	[mAttributes release];
    [mDatabaseURI release];
    [mSchemaName release];
    [mDependentViewEntities release];
    [mViewEntities release];
    [super dealloc];
}

- (void) release
{
    //Never released
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
    id rval = [self initWithDatabaseURI: databaseURI table: name inSchema: schemaName];
    
    Class cls = NSClassFromString ([decoder decodeObjectForKey: @"databaseObjectClassName"]);
    if (Nil != cls)
        [rval setDatabaseObjectClass: cls];
		
	[self setAttributes: [decoder decodeObjectForKey: @"attributes"]];
 	        
    return rval;
}

- (void) encodeWithCoder: (NSCoder *) encoder
{
    [encoder encodeObject: mName forKey: @"name"];
    [encoder encodeObject: mSchemaName forKey: @"schemaName"];
    [encoder encodeObject: mDatabaseURI forKey: @"databaseURI"];
    [encoder encodeObject: NSStringFromClass (mDatabaseObjectClass) forKey: @"databaseObjectClassName"];
	[encoder encodeObject: mAttributes forKey: @"attributes"];
}

- (id) copyWithZone: (NSZone *) zone
{
    //Retain on copy
    return [self retain];
}

- (BOOL) isEqual: (id) anObject
{
    BOOL rval = NO;
    
    if (self == anObject)
        rval = YES;
    else if (NO == [anObject isKindOfClass: [self class]])
        rval = [super isEqual: anObject];
    else
    {        
        BXEntityDescription* aDesc = (BXEntityDescription *) anObject;
        
        NSAssert (nil != mName && nil != mSchemaName && nil != mDatabaseURI, 
                  @"Properties should not be nil in isEqual:");
        NSAssert (nil != aDesc->mName && nil != aDesc->mSchemaName && nil != aDesc->mDatabaseURI, 
                  @"Properties should not be nil in isEqual:");

        rval = ([mName isEqualToString: aDesc->mName] && 
                [mSchemaName isEqualToString: aDesc->mSchemaName] &&
                [mDatabaseURI isEqual: aDesc->mDatabaseURI]);
    }
    return rval;
}

- (unsigned int) hash
{
    if (0 == mHash)
    {
        //We use a real hash function with the URI
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
 * have to be set manually before using the entity in a query.
 * \param   anArray     An NSArray of NSStrings.
 * \internal
 * \note BXPropertyDescriptions should only be created here and in -[BXInterface validateEntity:]
 */
- (void) setPrimaryKeyFields: (NSArray *) anArray
{
	if (nil != anArray)
	{
		NSMutableDictionary* attributes = [[mAttributes mutableCopy] autorelease];
		TSEnumerate (currentField, e, [anArray objectEnumerator])
		{
			BXPropertyDescription* property = nil;
			if ([currentField isKindOfClass: [BXPropertyDescription class]])
			{
				NSAssert ([currentField entity] == self, nil);
				property = currentField;
			}
			else if ([currentField isKindOfClass: [NSString class]])
			{
                property = [BXPropertyDescription propertyWithName: currentField entity: self];
			}
			[property setPrimaryKey: YES];
			[property setOptional: NO];
			[attributes setObject: property forKey: [property name]];
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
 * The fields get determined automatically after using the entity in a query.
 * \return          An array of BXPropertyDescriptions
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
 * Fields for this entity
 * \return          An array of BXPropertyDescriptions
 */
- (NSArray *) fields
{
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"NO == isPrimaryKey"];
	NSArray* rval = [[[mAttributes allValues] filteredArrayUsingPredicate: predicate] 
			sortedArrayUsingSelector: @selector (caseInsensitiveCompare:)];
	if (0 == [rval count]) rval = nil;
	return rval;
}

/**
 * Mark the entity as a view.
 * The database contect cannot determine this information by itself. Also the primary key needs
 * to be set manually.
 * \see -           setPrimaryKeyFields:
 * \param           tableNames          NSSet containing names of the tables that are in the same schema
 *                                      as the view.
 * \return                              A BOOL indicating whether the operation was succcessful or not.
 */
- (BOOL) viewIsBasedOnTablesInItsSchema: (NSSet *) tableNames
{
    BOOL rval = NO;
    if (nil == mViewEntities)
    {
        NSMutableSet* entities = [NSMutableSet setWithCapacity: [tableNames count]];
        TSEnumerate (currentName, e, [tableNames objectEnumerator])
        {
            [entities addObject: [BXEntityDescription entityWithDatabaseURI: mDatabaseURI 
																	  table: currentName
																   inSchema: mSchemaName]];
        }
        rval = [self viewIsBasedOnEntities: entities];
    }
    return rval;
}

/**
 * Mark the entity as a view.
 * The database context cannot read this information from the database. The primary key also needs
 * to be set manually.
 * \see -           setPrimaryKeyFields:
 * \param           entities          NSSet containing the entities.
 * \return                              Whether the operation was succcessful or not.
 */
- (BOOL) viewIsBasedOnEntities: (NSSet *) entities
{
    BOOL rval = NO;
    if (nil == mViewEntities)
    {
        NSAssert (NO == [entities containsObject: self], @"A view cannot be based on itself.");
        mViewEntities = [entities retain];
        [gViewEntities addObject: self];
        [mViewEntities makeObjectsPerformSelector: @selector (addDependentView:) withObject: self];
        rval = YES;
    }
    return rval;
}

/** Whether this entity is marked as a view or not. */
- (BOOL) isView
{
    return (nil != mViewEntities);
}

/** The entities this view is based on. */
- (NSSet *) entitiesBasedOn
{
    return mViewEntities;
}

/** The views that depend on this entity. */
- (NSSet *) dependentViews
{
    return mDependentViewEntities;
}

/** 
 * Make a relationship return objects from a view. 
 * \param viewEntity The target view or nil to reset.
 * \param relationshipName Name of the relationship.
 */
- (void) setTargetView: (BXEntityDescription *) viewEntity 
  forRelationshipNamed: (NSString *) relationshipName
{
    //FIXME: This should be an exception rather than assertion
    NSAssert1 (nil == viewEntity || [viewEntity isView], 
               @"Expected to receive a view entity or nil (%@)", viewEntity);
    
    if (nil == viewEntity)
        [mTargetViews removeObjectForKey: relationshipName];
    else
        [mTargetViews setObject: viewEntity forKey: relationshipName];
}

- (NSComparisonResult) caseInsensitiveCompare: (BXEntityDescription *) anotherEntity
{
    NSAssert ([anotherEntity isKindOfClass: [BXEntityDescription class]], 
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

- (NSDictionary *) attributesByName
{
	return mAttributes;
}

- (BOOL) isValidated
{
	return mFlags & kBXEntityIsValidated;
}

@end


@implementation BXEntityDescription (PrivateMethods)

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
    return [[[self alloc] initWithDatabaseURI: anURI table: tName inSchema: sName] autorelease];
}

/**
 * \internal
 * Create the entity using the default schema.
 * \param       anURI   The database URI
 * \param       tName   Table name
 */
+ (id) entityWithDatabaseURI: (NSURL *) anURI table: (NSString *) tName
{
    return [self entityWithDatabaseURI: anURI table: tName inSchema: nil];
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
    if ((self = [super initWithName: tName]))
    {
        mDatabaseObjectClass = [BXDatabaseObject class];
        if (nil == sName)
            sName = @"public";
        NSAssert (nil != anURI, nil);
        mDatabaseURI = [anURI copy];
        mSchemaName = [sName copy];
        
        id anObject = [gEntities member: self];
        NSAssert2 ([gEntities containsObject: self] ? nil != anObject : YES, 
                   @"gEntities contains the current entity but it could not be found."
                   " \n\tself: \t%@ \n\tgEntities: \t%@",
                   self, gEntities);
        if (nil == anObject)
        {
            [gEntities addObject: self];
            mRelationships = [[NSMutableDictionary alloc] init];
            mDependentViewEntities = [[NSMutableSet alloc] init];
            mObjectIDs = [[TSNonRetainedObjectSet alloc] init];
            mTargetViews = [[NSMutableDictionary alloc] init];
        }
        else
        {
            [self dealloc];
            self = [anObject retain];
        }
    }
    return self;
}
//@}

- (void) setViewEntities: (NSSet *) aSet
{
	if (aSet != mViewEntities)
	{
		[mViewEntities release];
		mViewEntities = [aSet retain];
	}
}

- (void) addDependentView: (BXEntityDescription *) viewEntity
{
    NSAssert2 ([viewEntity isView], 
               @"Attempted to add a view dependency to an entity that is not a view.\n\t self:\t%@ \n\t entity:\t%@",
               self, viewEntity);
    if ([viewEntity isView])
        [mDependentViewEntities addObject: viewEntity];
}

//FIXME: Consider moving the recursion to -[BXDatabaseContext relationshipsByNameWithEntity:entity:]
- (id <BXRelationshipDescription>) relationshipNamed: (NSString *) aName
                                             context: (BXDatabaseContext *) context
                                               error: (NSError **) error
{
    id rval = nil;
    if (nil == mViewEntities)
    {
        //FIXME: this might cause cached objects to be ignored.
        if (NO == [self hasAllRelationships])
        {
			[self setHasAllRelationships: YES];
            [context relationshipsByNameWithEntity: self entity: nil error: error];
        }
        rval = [mRelationships objectForKey: aName];
    }
    else
    {
        //If this entity is a view, enumerate the tables the view is based on and
        //try to find the correct relationship.
        TSEnumerate (currentViewEntity, e, [mViewEntities objectEnumerator])
        {
            rval = [currentViewEntity relationshipNamed: aName context: context error: error];
            if (nil != rval || (NULL != error && nil != *error))
                break;
        }
    }
    return rval;
}

- (void) cacheRelationship: (id <BXRelationshipDescription>) relationship
{
    NSAssert2 ([[relationship entities] containsObject: self], 
               @"Attempt to cache a relationship which this entity is not part of. \n\tEntity: %@ \n\tRelationship: %@",
               self, relationship);
    
    //One-to-one and many-to-many replace many-to-one
    NSString* relname = [relationship nameFromEntity: self];
    id oldRelationship = [mRelationships objectForKey: relname];
    if (nil == oldRelationship || [relationship isOneToOne] || [relationship isManyToMany])
	{
        [mRelationships setObject: relationship forKey: relname];
		
		//FIXME: this is a hack.
		if (NO == [relationship isOneToOne] && NO == [relationship isManyToMany])
			[mRelationships setObject: relationship forKey: [(BXRelationshipDescription *) relationship alternativeNameFromEntity: self]];
	}
}

- (void) registerObjectID: (BXDatabaseObjectID *) anID
{
    NSAssert2 ([anID entity] == self, 
               @"Attempted to register an object ID the entity of which is other than self.\n"
               "\tanID:\t%@ \n\tself:\t%@", anID, self);
    if (self == [anID entity])
        [mObjectIDs addObject: anID];
}

- (void) unregisterObjectID: (BXDatabaseObjectID *) anID
{
    [mObjectIDs removeObject: anID];
}

- (BXEntityDescription *) targetForRelationship: (id <BXRelationshipDescription>) rel
{
    return [mTargetViews objectForKey: [rel nameFromEntity: self]];
}

/**
 * \internal
 * Property descriptions for table columns that correspond to view columns.
 * Retrieving property descriptions is done by comparing property or column names; 
 * columns in views need to have the same names as in tables. We iterate through 
 * the given properties and compare their names first to primary key field names, 
 * then others.
 * \param properties Properties in a view that is based on this table.
 */
- (NSArray *) correspondingProperties: (NSArray *) properties
{
    id rval = nil;
    
    if (0 < [properties count])
    {
        //First check if we are eligible
        if ([[[properties objectAtIndex: 0] entity] isEqual: self])
        {
            rval = properties;            
#ifndef NS_BLOCK_ASSERTIONS
            TSEnumerate (currentField, e, [properties objectEnumerator])
            {
				if (nil == [mAttributes objectForKey: [currentField name]])
                {
                    rval = nil;
                    break;
                }
            }
#endif
        }
        else
        {
            //If not, give the corresponding properties.
            rval = [NSMutableArray arrayWithCapacity: [properties count]];
            TSEnumerate (currentProperty, e, [properties objectEnumerator])
            {
                NSString* propertyName = [currentProperty name];
                BXPropertyDescription* prop = [mAttributes objectForKey: propertyName];
				if (nil == prop)
				{
#if 0
					//If fields haven't been received yet, we can risk making a nonexistent property
					if (nil == mAttributes) 
						prop = [BXPropertyDescription propertyWithName: propertyName entity: self];
					else
					{
#endif
						[[NSException exceptionWithName: NSInternalInconsistencyException 
												 reason: [NSString stringWithFormat: @"Nonexistent property %@ given", currentProperty]
											   userInfo: nil] raise];
#if 0
					}
#endif
				}
                [rval addObject: prop];
            }
        }
    }
    return rval;
}

- (BOOL) hasAncestor: (BXEntityDescription *) entity
{
    BOOL rval = NO;
    if ([self isView])
    {
        NSSet* parents = [self entitiesBasedOn];
        if ([parents containsObject: entity])
            rval = YES;
        else
        {
            TSEnumerate (currentParent, e, [parents objectEnumerator])
            {
                if ([currentParent hasAncestor: entity])
                {
                    rval = YES;
                    break;
                }
            }
        }
    }
    return rval;
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
		[gEntities removeObject: self];
		[gViewEntities removeObject: self];
		mHash = 0;
		
		[mDatabaseURI release];
		mDatabaseURI = [anURI retain];
		
		[gEntities addObject: self];
		if ([self isView])
			[gViewEntities addObject: self];
	}
}

- (void) resetPropertyExclusion
{
	TSEnumerate (currentProp, e, [mAttributes objectEnumerator])
		[currentProp setExcluded: NO];
}

- (NSArray *) properties: (NSArray *) strings
{
	NSMutableArray* rval = nil;
	if (0 < [strings count])
	{
		rval = [NSMutableArray arrayWithCapacity: [strings count]];
		TSEnumerate (currentField, e, [strings objectEnumerator])
		{
			if ([currentField isKindOfClass: [NSString class]])
				currentField = [mAttributes objectForKey: currentField];
			NSAssert2 ([currentField isKindOfClass: [BXPropertyDescription class]], 
					   @"Expected to receive NSStrings or BXPropertyDescriptions (%@ was a %@).",
					   currentField, [currentField class]);
			
			[rval addObject: currentField];
		}
	}
	return rval;
}

- (BOOL) hasAllRelationships
{
	return mFlags & kBXEntityHasAllRelationships;
}

- (void) setHasAllRelationships: (BOOL) flag
{
	if (flag)
		mFlags |= kBXEntityHasAllRelationships;
	else
		mFlags &= ~kBXEntityHasAllRelationships;
}

- (void) setValidated: (BOOL) flag
{
	if (flag)
		mFlags |= kBXEntityIsValidated;
	else
		mFlags &= ~kBXEntityIsValidated;
}

@end
