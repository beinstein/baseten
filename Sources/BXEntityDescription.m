//
// BXEntityDescription.m
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

#import "BXEntityDescription.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseContext.h"
#import "BXRelationshipDescriptionProtocol.h"
#import "BXPropertyDescription.h"

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

/**
 * \name Retrieving an entity description
 */
//@{
/**
 * Create the entity.
 * \param       anURI   The database URI
 * \param       tName   Table name
 * \param       sName   Schema name
 */
+ (id) entityWithURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName
{
    return [[[self alloc] initWithURI: anURI table: tName inSchema: sName] autorelease];
}

/**
 * Create the entity using the default schema.
 * \param       anURI   The database URI
 * \param       tName   Table name
 */
+ (id) entityWithURI: (NSURL *) anURI table: (NSString *) tName
{
    return [self entityWithURI: anURI table: tName inSchema: nil];
}

/**
 * The designated initializer.
 * Create the entity.
 * \param       anURI   The database URI
 * \param       tName   Table name
 * \param       sName   Schema name
 */
- (id) initWithURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName
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
            mHasAllRelationships = NO;
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
    [mPkeyFields release];
    [mFields release];
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
    NSString* eName = [decoder decodeObjectForKey: @"name"];
    NSString* sName = [decoder decodeObjectForKey: @"schemaName"];
    NSURL* uri = [decoder decodeObjectForKey: @"databaseURI"];
    id rval = [[[self class] alloc] initWithURI: uri table: eName inSchema: sName];
    
    Class cls = NSClassFromString ([decoder decodeObjectForKey: @"databaseObjectClassName"]);
    if (Nil != cls)
        [rval setDatabaseObjectClass: cls];
 
	NSString *IBDatabaseObjectClassName = [decoder decodeObjectForKey: @"IBDatabaseObjectClassName"];
    if(nil != IBDatabaseObjectClassName)
	{
		[rval setIBDatabaseObjectClassName: IBDatabaseObjectClassName];
		
		if (Nil == cls)
		{
			cls = NSClassFromString(IBDatabaseObjectClassName);
			
			if (Nil != cls)
				[rval setDatabaseObjectClass:cls];
		}
	}
	
#if 0
    NSArray* pkey = [decoder decodeObjectForKey: @"pkeyFields"];
    if (nil != pkey)
        [rval setPrimaryKeyFields: pkey];
    
    NSSet* vEntities = [decoder decodeObjectForKey: @"viewEntities"];
    if (nil != vEntities)
        [rval viewIsBasedOnEntities: vEntities];
#endif
        
    return rval;
}

- (void) encodeWithCoder: (NSCoder *) encoder
{
    [encoder encodeObject: mName forKey: @"name"];
    [encoder encodeObject: mSchemaName forKey: @"schemaName"];
    [encoder encodeObject: mDatabaseURI forKey: @"databaseURI"];
    [encoder encodeObject: NSStringFromClass (mDatabaseObjectClass) forKey: @"databaseObjectClassName"];
    [encoder encodeObject: mIBDatabaseObjectClassName forKey: @"IBDatabaseObjectClassName"];
#if 0
    [encoder encodeObject: mPkeyFields forKey: @"pkeyFields"];
    [encoder encodeObject: mViewEntities forKey: @"viewEntities"];
#endif
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
    return [NSString stringWithFormat: @"<%@ %@ hpkey: %d (%p)>", mDatabaseURI, [self name], nil != mPkeyFields, self];
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
		
		[self setIBDatabaseObjectClassName: NSStringFromClass(cls)];
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
 * The class name for the entity. Used in Interface Builder.
 * \return          Class name
 */
-(NSString *) IBDatabaseObjectClassName
{
	return [[mIBDatabaseObjectClassName retain] autorelease];
}

-(void) setIBDatabaseObjectClassName:(NSString *)IBDatabaseObjectClassName
{
	if(mIBDatabaseObjectClassName == IBDatabaseObjectClassName)
		return;
	
	[mIBDatabaseObjectClassName release];
	mIBDatabaseObjectClassName = [IBDatabaseObjectClassName retain];
}

/**
 * Set the primary key fields for this entity.
 * Normally the database context determines the primary key, when
 * an entity is used in a database query. However, when an entity is a view, the fields
 * have to be set manually before using the entity in a query.
 * \param   anArray     An NSArray of NSStrings or BXPropertyDescriptions.
 */
- (void) setPrimaryKeyFields: (NSArray *) anArray
{
    if (mPkeyFields != anArray && nil != anArray)
    {
        NSMutableArray* descs = [NSMutableArray arrayWithCapacity: [anArray count]];
        TSEnumerate (currentField, e, [anArray objectEnumerator])
        {
            if ([currentField isKindOfClass: [BXPropertyDescription class]])
            {
                NSAssert ([currentField entity] == self, nil);
                [descs addObject: currentField];
            }
            else if ([currentField isKindOfClass: [NSString class]])
            {
                [descs addObject: [BXPropertyDescription propertyWithName: currentField entity: self]];
            }
        }
        
        [mPkeyFields release];
        mPkeyFields = [[descs sortedArrayUsingSelector: @selector (caseInsensitiveCompare:)] retain];
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
    return mPkeyFields;
}

/** 
 * Fields for this entity
 * \return          A set of BXPropertyDescriptions
 */
- (NSArray *) fields
{
    return mFields; 
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
            [entities addObject: [BXEntityDescription entityWithURI: mDatabaseURI table: currentName
                                                              inSchema: mSchemaName]];
        }
        rval = [self viewIsBasedOnEntities: entities];
    }
    return rval;
}

/**
 * Mark the entity as a view.
 * The database contect cannot read this information from the database. The primary key also needs
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
        mViewEntities = [entities retain];
        [gViewEntities addObject: self];
        [mViewEntities makeObjectsPerformSelector: @selector (addDependentView:) withObject: self];
    }
    return rval;
}

/** Whether this entity s marked as a view or not. */
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

- (void) setTargetView: (BXEntityDescription *) viewEntity 
  forRelationshipNamed: (NSString *) relationshipName
{
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

@end


@implementation BXEntityDescription (PrivateMethods)

- (void) addDependentView: (BXEntityDescription *) viewEntity
{
    NSAssert2 ([viewEntity isView], 
               @"Attempted to add a view dependency to an entity that is not a view.\n\t self:\t%@ \n\t entity:\t%@",
               self, viewEntity);
    if ([viewEntity isView])
        [mDependentViewEntities addObject: viewEntity];
}

- (id <BXRelationshipDescription>) relationshipNamed: (NSString *) aName
                                                context: (BXDatabaseContext *) context
{
    //FIXME: this might cause cached objects to be ignored.
    if (NO == mHasAllRelationships)
    {
        mHasAllRelationships = YES;
        [context relationshipsByNameWithEntity: self entity: nil];
    }
    return [mRelationships objectForKey: aName];
}

- (void) cacheRelationship: (id <BXRelationshipDescription>) relationship
{
    NSAssert2 ([[relationship entities] containsObject: self], 
               @"Attempt to cache a relationship which this entity is not part of. \n\tEntity: %@ \n\tRelationship: %@",
               self, relationship);
    
    NSString* relname = [relationship nameFromEntity: self];
    [mRelationships setObject: relationship forKey: relname];
}

- (void) setFields: (NSArray *) aFields
{
    if (mFields != aFields) {
        [mFields release];
        mFields = [aFields copy];
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

- (NSArray *) correspondingProperties: (NSArray *) properties
{
    //First check if we are eligible
    id rval = properties;
    
    if (0 < [properties count])
    {
        //First check if we are eligible
        if ([[[properties objectAtIndex: 0] entity] isEqual: self])
        {
#ifndef NS_BLOCK_ASSERTIONS
            TSEnumerate (currentField, e, [properties objectEnumerator])
            {
                if (! ([mPkeyFields containsObject: currentField] ||
                       [mFields containsObject: currentField]))
                {
                    rval = nil;
                    break;
                }
            }
#endif
            
            rval = properties;            
        }
        else
        {
            //If not, give the corresponding properties
            rval = [NSMutableArray arrayWithCapacity: [properties count]];
            NSArray* fNames = [mFields valueForKey: @"name"];
            NSArray* pkeyFNames = [mPkeyFields valueForKey: @"name"];
            TSEnumerate (currentProperty, e, [properties objectEnumerator])
            {
                unsigned int index = NSNotFound;
                NSString* propertyName = [currentProperty name];
                
                BXPropertyDescription* prop = nil;
                if (NSNotFound != (index = [pkeyFNames indexOfObject: propertyName]))
                    prop = [mPkeyFields objectAtIndex: index];
                else if (NSNotFound != (index = [fNames indexOfObject: propertyName]))
                    prop = [mFields  objectAtIndex: index];
                else if (nil == mFields) 
                {
                    //If fields haven't been received yet, we can risk making a nonexistent property
                    prop = [BXPropertyDescription propertyWithName: propertyName entity: self];
                }
                else
                {
                    [[NSException exceptionWithName: NSInternalInconsistencyException 
                                             reason: [NSString stringWithFormat: @"Nonexistent property %@ given", currentProperty]
                                           userInfo: nil] raise];
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
    if ([entity isView])
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

@end
