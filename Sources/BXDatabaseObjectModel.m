//
// BXDatabaseObjectModel.m
// BaseTen
//
// Copyright (C) 2009 Marko Karppinen & Co. LLC.
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

#import "BXDatabaseObjectModel.h"
#import "BXDatabaseObjectModelStorage.h"
#import "BXDatabaseObjectModelStoragePrivate.h"
#import "BXEnumerate.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXInterface.h"
#import "BXLogger.h"


/** 
 * \brief The database object model. 
 * 
 * A database object model stores the entity descriptions for a database at a certain URI.
 *
 * \note This class is thread-safe.
 * \ingroup baseten
 */
@implementation BXDatabaseObjectModel
- (id) init
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (void) dealloc
{	
	[mEntitiesBySchemaAndName release];
	[mStorage objectModelWillDeallocate: mStorageKey];
	[super dealloc];
}


/** 
 * \brief Entity for a table in the schema \em public
 */
- (BXEntityDescription *) entityForTable: (NSString *) name error: (NSError **) outError
{
	return [self entityForTable: name inSchema: @"public" error: outError];
}


/** 
 * \brief Entity for a table in the given schema.
 * \note Unlike PostgreSQL, leaving \em schemaName unspecified does not cause the search path to be used but 
 *       instead will search the \em public schema.
 */
- (BXEntityDescription *) entityForTable: (NSString *) name inSchema: (NSString *) schemaName error: (NSError **) outError
{
	NSMutableDictionary* schemaDict = nil;
	BXEntityDescription* retval = nil;
	BOOL canCreateEntityDesc = NO;
	@synchronized (mEntitiesBySchemaAndName)
	{
		//We need the lock for this.
		canCreateEntityDesc = mCanCreateEntities;
		
		schemaDict = [[[mEntitiesBySchemaAndName objectForKey: schemaName] retain] autorelease];
		if (! schemaDict)
		{
			schemaDict = [NSMutableDictionary dictionary];
			[mEntitiesBySchemaAndName setObject: schemaDict forKey: schemaName];
		}
	}
	
	@synchronized (schemaDict)
	{
		retval = [[[schemaDict objectForKey: name] retain] autorelease];
		if (! retval && canCreateEntityDesc)
		{
			retval = [[[BXEntityDescription alloc] initWithDatabaseURI: mStorageKey table: name inSchema: schemaName] autorelease];
			[schemaDict setObject: retval forKey: name];
		}
	}
	
	return retval;
}


/**
 * \brief All entities found in the database.
 *
 * Entities in private and metadata schemata won't be included.
 * \param outError If an error occurs, this pointer is set to an NSError instance. May be NULL.
 * \return An NSArray containing BXEntityDescriptions.
 */
- (NSArray *) entities: (NSError **) outError
{
	NSMutableArray* retval = [NSMutableArray array];
	NSDictionary* schemas = nil;
	@synchronized (mEntitiesBySchemaAndName)
	{
		schemas = [[mEntitiesBySchemaAndName copy] autorelease];
	}
	
	BXEnumerate (currentSchema, e, [schemas objectEnumerator])
	{
		@synchronized (currentSchema)
		{
			[retval addObjectsFromArray: currentSchema];
		}
	}
	
	return retval;
}


/**
 * \brief All entities found in the database.
 *
 * Entities in private and metadata schemata won't be included.
 * \param reload Whether the entity list should be reloaded.
 * \param outError If an error occurs, this pointer is set to an NSError instance. May be NULL.
 * \return An NSDictionary with NSStrings corresponding to schema names as keys and NSDictionarys as objects. 
 *         Each of them will have NSStrings corresponding to relation names as keys and BXEntityDescriptions
 *         as objects.
 */
- (NSDictionary *) entitiesBySchemaAndName: (id <BXInterface>) interface reload: (BOOL) shouldReload error: (NSError **) outError
{
	id retval = nil;
	if (shouldReload)
	{
		[interface reloadDatabaseMetadata];
		@synchronized (mEntitiesBySchemaAndName)
		{			
			mCanCreateEntities = YES;
			[interface prepareForEntityValidation];
			NSArray* entities = [self entities: outError];
			if (entities)
			{
				BXEnumerate (currentEntity, e, [entities objectEnumerator])
					[currentEntity removeValidation];
				
				if ([interface validateEntities: entities error: outError])
					retval = [[mEntitiesBySchemaAndName copy] autorelease];
			}
		}
	}
	else
	{
		@synchronized (mEntitiesBySchemaAndName)
		{
			retval = [[mEntitiesBySchemaAndName copy] autorelease];
		}
	}
	return retval;
}
@end



@implementation BXDatabaseObjectModel (PrivateMethods)
- (id) initWithStorage: (BXDatabaseObjectModelStorage *) storage key: (NSURL *) key
{
	if ((self = [super init]))
	{
		mStorage = [storage retain];
		mStorageKey = [key retain];
		mEntitiesBySchemaAndName = [[NSMutableDictionary alloc] init];
		mCanCreateEntities = YES;
	}
	return self;
}


- (BOOL) contextConnectedUsingDatabaseInterface: (id <BXInterface>) interface error: (NSError **) outError
{
	ExpectR (outError, NO);
	
	BOOL retval = NO;
	[interface prepareForEntityValidation];
	
	NSArray* entities = [self entities: outError];
	if (entities)
		retval = [interface validateEntities: entities error: outError];
	return retval;
}


- (void) setCanCreateEntityDescriptions: (BOOL) aBool
{
	@synchronized (mEntitiesBySchemaAndName)
	{
		mCanCreateEntities = aBool;
	}
}
@end
