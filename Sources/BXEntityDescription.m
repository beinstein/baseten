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
	[mInverseRelationships release];
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
		
		retval = ([mSchemaName isEqualToString: aDesc->mSchemaName] &&
				  [mDatabaseURI isEqual: aDesc->mDatabaseURI]);
	}
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
 * have to be set manually before using the entity in a query.
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

/**
 * Mark the entity as a view.
 * The database contect cannot determine this information by itself. Also the primary key needs
 * to be set manually.
 * \see             - setPrimaryKeyFields:
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
 * \see             - setPrimaryKeyFields:
 * \param           entities          NSSet containing the entities.
 * \return                              Whether the operation was succcessful or not.
 */
- (BOOL) viewIsBasedOnEntities: (NSSet *) entities
{
    BOOL rval = NO;
    if (nil == mViewEntities)
    {
        log4AssertValueReturn (NO == [entities containsObject: self], NO, @"A view cannot be based on itself.");
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
    log4AssertVoidReturn (nil == viewEntity || [viewEntity isView], 
					@"Expected to receive a view entity or nil (%@)", viewEntity);
    
    if (nil == viewEntity)
        [mTargetViews removeObjectForKey: relationshipName];
    else
        [mTargetViews setObject: viewEntity forKey: relationshipName];
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
	return mRelationships;
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
        log4AssertValueReturn (nil != anURI, nil, @"Expected anURI to be set.");
        mDatabaseURI = [anURI copy];
        mSchemaName = [sName copy];
        
        id anObject = [gEntities member: self];
        log4AssertValueReturn ([gEntities containsObject: self] ? nil != anObject : YES, nil, 
							   @"gEntities contains the current entity but it could not be found."
							   " \n\tself: \t%@ \n\tgEntities: \t%@",
							   self, gEntities);
        if (nil == anObject)
        {
            [gEntities addObject: self];
            mRelationships = [[NSMutableDictionary alloc] init];
			mInverseRelationships = [[NSMutableDictionary alloc] init];
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
    log4AssertLog ([viewEntity isView], 
				   @"Attempted to add a view dependency to an entity that is not a view.\n\t self:\t%@ \n\t entity:\t%@",
				   self, viewEntity);
    if ([viewEntity isView])
        [mDependentViewEntities addObject: viewEntity];
}

- (id <BXRelationshipDescription>) relationshipNamed: (NSString *) aName
                                             context: (BXDatabaseContext *) context
                                               error: (NSError **) error
{
	//FIXME: this needs to be rewritten.
	return nil;
#if 0
	//FIXME: Consider moving the recursion to -[BXDatabaseContext relationshipsByNameWithEntity:entity:]
    id rval = nil;
	if (nil == mViewEntities)
	{
		//FIXME: this might cause cached some objects to be ignored.
		[self fetchRelationshipsIfNeeded: context error: error];
		rval = [mRelationships objectForKey: aName];
	}
	else if (nil == (rval = [mRelationships objectForKey: aName]))
	{
		//If there is a view named like the sought relationship, try to find a path between this entity and the view.
		//FIXME: if aName is formatted like schema.table, we needn't make the assumption below.
		NSError* localError = nil;
		BXEntityDescription* target = [context entityForTable: aName inSchema: [self schemaName] error: &localError];
		if (nil != target && [target isView])
		{
			rval = [self findPathToEntity: target 
					 usingPropertiesNamed: [[self attributesByName] allKeys]
					targetPropertiesNamed: [[target attributesByName] allKeys]
								  context: context
									error: error];
			if (nil != rval)
			{
				[mRelationships setObject: rval forKey: aName];
				//FIXME: this shouldn't be set here but rather in the relationship.
				[self setTargetView: target forRelationshipNamed: aName];
			}
		}
		else
		{
			//Enumerate the tables the view is based on and
			//try to find the correct relationship.
			TSEnumerate (currentViewEntity, e, [mViewEntities objectEnumerator])
		{
				rval = [currentViewEntity relationshipNamed: aName context: context error: error];
				if (nil != rval || (NULL != error && nil != *error))
				{
					[mRelationships setObject: rval forKey: aName];
					break;
				}
		}		
		}		
	}
	return rval;
#endif
}

- (id <BXRelationshipDescription>) findPathToEntity: (BXEntityDescription *) anEntity 
							   usingPropertiesNamed: (NSArray *) srcNames
							  targetPropertiesNamed: (NSArray *) dstNames
											context: (BXDatabaseContext *) context
											  error: (NSError **) error
{
	//FIXME: performance is something like O (n * m) instead of O (n + m).
	log4AssertValueReturn (NULL != error, nil , @"Expected error not to be NULL.");
	id <BXRelationshipDescription> retval = nil;
	if ([self isView])
	{
		TSEnumerate (currentViewEntity, e, [mViewEntities objectEnumerator])
		{
			retval = [currentViewEntity findPathToEntity: anEntity 
								 usingPropertiesNamed: srcNames
								targetPropertiesNamed: dstNames
											  context: context
												error: error];
			if (nil != retval || nil != *error)
				break;
		}
	}
	else if ([anEntity isView])
	{
		TSEnumerate (currentEntity, e, [[anEntity entitiesBasedOn] objectEnumerator])
		{
			retval = [self findPathToEntity: currentEntity 
					usingPropertiesNamed: srcNames
				   targetPropertiesNamed: dstNames
								 context: context
								   error: error];
			if (nil != retval || nil != *error)
				break;
		}
	}
	else
	{
		id <BXRelationshipDescription> rel = [self relationshipNamed: [anEntity name] context: context error: error];
		if (nil != rel)
		{
			NSArray* currentSrcNames = [[rel propertiesForEntity: self] valueForKey: @"name"];
			NSArray* currentDstNames = [[rel propertiesForEntity: anEntity] valueForKey: @"name"];
			if ([srcNames BXContainsObjectsInArray: currentSrcNames] && 
				[dstNames BXContainsObjectsInArray: currentDstNames])
				retval = rel;
		}
	}
	
	return retval;
}

- (void) registerObjectID: (BXDatabaseObjectID *) anID
{
    log4AssertVoidReturn ([anID entity] == self, 
						  @"Attempted to register an object ID the entity of which is other than self.\n"
						  "\tanID:\t%@ \n\tself:\t%@", anID, self);
    if (self == [anID entity])
        [mObjectIDs addObject: anID];
}

- (void) unregisterObjectID: (BXDatabaseObjectID *) anID
{
    [mObjectIDs removeObject: anID];
}

- (BXEntityDescription *) targetForRelationship: (NSString *) name
{
    return [mTargetViews objectForKey: name];
}

//FIXME: this method could be going away soon.
/**
 * \internal
 * Property descriptions for table columns that correspond to view columns.
 * Retrieving attribute descriptions is done by comparing attribute or column names; 
 * columns in views need to have the same names as in tables. We iterate through 
 * the given attributes and compare their names first to primary key field names, 
 * then others.
 * \param properties Attributes in a view that is based on this table.
 */
- (NSArray *) correspondingAttributes: (NSArray *) properties
{
    id rval = nil;
    
    if (0 < [properties count])
    {
        //First check if we are eligible
        if ([[[properties objectAtIndex: 0] entity] isEqual: self])
        {
            rval = properties;            
#ifndef L4_BLOCK_ASSERTIONS
            TSEnumerate (currentField, e, [properties objectEnumerator])
            {
				if ([currentField entity] != self || 
					nil == [mAttributes objectForKey: [currentField name]])
					log4AssertValueReturn (NO, nil, @"Expected given properties to have self as entity (self: %@ properties: %@).", self, properties);
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
                BXAttributeDescription* attr = [mAttributes objectForKey: propertyName];
				if (nil == attr)
				{
					[[NSException exceptionWithName: NSInternalInconsistencyException 
											 reason: [NSString stringWithFormat: @"Nonexistent attribute %@ given", currentProperty]
										   userInfo: nil] raise];
				}
                [rval addObject: attr];
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

- (BXRelationshipDescription *) inverseRelationshipFor: (BXRelationshipDescription *) aRel
{
	return [mInverseRelationships objectForKey: aRel];
}

@end
