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

#import "BXDatabaseContextPrivate.h"
#import "BXDatabaseObjectModel.h"
#import "BXDatabaseObjectModelStorage.h"
#import "BXDatabaseObjectModelStoragePrivate.h"
#import "BXEnumerate.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXInterface.h"
#import "BXLogger.h"
#import "BXLocalizedString.h"
#import "BXError.h"
#import "NSDictionary+BaseTenAdditions.h"


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


+ (NSError *) errorForMissingEntity: (NSString *) name inSchema: (NSString *) schemaName
{
	NSString* title = BXLocalizedString (@"databaseError", @"Database error", @"Title for a sheet");
	NSString* errorFormat = BXLocalizedString (@"relationNotFound", @"Relation %@ was not found in schema %@.", @"Error message for getting or using an entity description.");
	NSString* reason = [NSString stringWithFormat: errorFormat, name, schemaName];
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  title, NSLocalizedDescriptionKey,
							  title, NSLocalizedFailureReasonErrorKey, 
							  reason, NSLocalizedRecoverySuggestionErrorKey, 
							  self, kBXDatabaseContextKey,
							  nil];
	NSError *retval = [BXError errorWithDomain: kBXErrorDomain code: kBXErrorNoTableForEntity userInfo: userInfo];
	return retval;
}


- (BOOL) canCreateEntityDescriptions
{
	BOOL retval = NO;
	@synchronized (mEntitiesBySchemaAndName)
	{
		retval = ((0 == mConnectionCount) || mReloading ? YES : NO);
	}
	return retval;
}


/** 
 * \brief Entity for a table in the schema \em public
 */
- (BXEntityDescription *) entityForTable: (NSString *) name
{
	return [self entityForTable: name inSchema: @"public"];
}


/** 
 * \brief Entity for a table in the given schema.
 * \note Unlike PostgreSQL, leaving \em schemaName unspecified does not cause the search path to be used but 
 *       instead will search the \em public schema.
 */
- (BXEntityDescription *) entityForTable: (NSString *) name inSchema: (NSString *) schemaName
{
	if (! [schemaName length])
		schemaName = @"public";
	
	BXEntityDescription* retval = nil;
	@synchronized (mEntitiesBySchemaAndName)
	{
		NSMutableDictionary *schemaDict = [mEntitiesBySchemaAndName objectForKey: schemaName];
		if (! schemaDict)
		{
			schemaDict = [NSMutableDictionary dictionary];
			[mEntitiesBySchemaAndName setObject: schemaDict forKey: schemaName];
		}
		
		retval = [[[schemaDict objectForKey: name] retain] autorelease];
		if (! retval && [self canCreateEntityDescriptions])
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
- (NSArray *) entities
{
	NSMutableArray* retval = [NSMutableArray array];
	@synchronized (mEntitiesBySchemaAndName)
	{
		BXEnumerate (currentSchema, e, [mEntitiesBySchemaAndName objectEnumerator])
			[retval addObjectsFromArray: currentSchema];
	}
	return [[retval copy] autorelease];
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
- (NSDictionary *) entitiesBySchemaAndName: (BXDatabaseContext *) context reload: (BOOL) shouldReload error: (NSError **) outError
{
	id retval = nil;
	NSError *localError = nil;
	if (shouldReload)
	{
		id <BXInterface> interface = [context databaseInterface];
		[interface reloadDatabaseMetadata];
		@synchronized (mEntitiesBySchemaAndName)
		{
			mReloading = YES;

			[interface prepareForEntityValidation];
			NSArray* entities = [self entities];
			if (entities)
			{
				BXEnumerate (currentEntity, e, [entities objectEnumerator])
					[currentEntity removeValidation];
				
				if ([interface validateEntities: entities error: &localError])
					retval = [[mEntitiesBySchemaAndName BXDeepCopy] autorelease];
				else
					[context handleError: localError outError: outError];
			}
			
			mReloading = NO;
		}
	}
	else
	{
		@synchronized (mEntitiesBySchemaAndName)
		{
			retval = [[mEntitiesBySchemaAndName BXDeepCopy] autorelease];
		}
	}
	return retval;
}


- (BOOL) entity: (NSEntityDescription *) entity existsInSchema: (NSString *) schemaName
{
	return ([self matchingEntity: entity inSchema: schemaName] ? YES : NO);
}


- (BXEntityDescription *) matchingEntity: (NSEntityDescription *) entity inSchema: (NSString *) schemaName
{
	BXEntityDescription *retval = [self entityForTable: [entity name] inSchema: schemaName];
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
	}
	return self;
}


- (BOOL) contextConnectedUsingDatabaseInterface: (id <BXInterface>) interface error: (NSError **) outError
{
	ExpectR (outError, NO);
	
	BOOL retval = NO;
	[interface prepareForEntityValidation];
	
	NSArray* entities = [self entities];
	if (entities && [interface validateEntities: entities error: outError])
	{
		retval = YES;
		@synchronized (mEntitiesBySchemaAndName)
		{
			mConnectionCount++;
		}
	}
	return retval;
}
@end
