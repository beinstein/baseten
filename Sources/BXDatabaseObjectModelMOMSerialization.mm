//
// BXDatabaseObjectModelMOMSerialization.mm
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

#import "BXDatabaseObjectModelMOMSerialization.h"
#import <CoreData/CoreData.h>
#import <tr1/unordered_map>
#import "BXDatabaseObjectModel.h"
#import "PGTSCollections.h"
#import "BXEnumerate.h"
#import "BXEntityDescription.h"
#import "BXAttributeDescription.h"
#import "BXRelationshipDescription.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXLogger.h"


typedef std::tr1::unordered_map <id, NSAttributeType,
	PGTS::ObjectHash, 
	PGTS::ObjectCompare <id>, 
	PGTS::scanned_memory_allocator <std::pair <const id, NSAttributeType> > > 
	IdentifierMap;


static IdentifierMap gTypeMapping;


@implementation BXDatabaseObjectModelMOMSerialization
+ (void) initialize
{
	static BOOL tooLate = NO;
	if (! tooLate)
	{
		tooLate = YES;
		
		gTypeMapping [@"bit"]         = NSStringAttributeType;
		gTypeMapping [@"bool"]        = NSBooleanAttributeType;
		gTypeMapping [@"bytea"]       = NSBinaryDataAttributeType;
		gTypeMapping [@"char"]        = NSStringAttributeType;
		gTypeMapping [@"date"]        = NSDateAttributeType;
		gTypeMapping [@"float4"]      = NSFloatAttributeType;
		gTypeMapping [@"float8"]      = NSDoubleAttributeType;
		gTypeMapping [@"int2"]        = NSInteger16AttributeType;
		gTypeMapping [@"int4"]        = NSInteger32AttributeType;
		gTypeMapping [@"int8"]        = NSInteger64AttributeType;
		gTypeMapping [@"name"]        = NSStringAttributeType;
		gTypeMapping [@"numeric"]     = NSDecimalAttributeType;
		gTypeMapping [@"oid"]         = NSInteger32AttributeType;
		gTypeMapping [@"text"]        = NSStringAttributeType;
		gTypeMapping [@"timestamp"]   = NSDateAttributeType;
		gTypeMapping [@"timestamptz"] = NSDateAttributeType;
		gTypeMapping [@"time"]        = NSDateAttributeType;
		gTypeMapping [@"timetz"]      = NSDateAttributeType;
		gTypeMapping [@"varbit"]      = NSStringAttributeType;
		gTypeMapping [@"varchar"]     = NSStringAttributeType;
		gTypeMapping [@"bpchar"]      = NSStringAttributeType;
		gTypeMapping [@"uuid"]        = NSStringAttributeType;
	}
}


+ (NSString *) managedObjectClassName
{
	return @"NSManagedObject";
}


+ (NSManagedObjectModel *) managedObjectModelFromDatabaseObjectModel: (BXDatabaseObjectModel *) objectModel 
															 options: (enum BXDatabaseObjectModelSerializationOptions) options
															   error: (NSError **) outError
{
	NSManagedObjectModel* retval = [[[NSManagedObjectModel alloc] init] autorelease];
	
	const BOOL exportFkeyRelationships    = options & kBXDatabaseObjectModelSerializationOptionRelationshipsUsingFkeyNames;
	const BOOL exportRelNameRelationships = options & kBXDatabaseObjectModelSerializationOptionRelationshipsUsingTargetRelationNames;
	
	NSArray* bxEntities = [objectModel entities: outError];
	NSMutableArray* entities = [NSMutableArray arrayWithCapacity: [bxEntities count]];
	NSMutableSet* entityNames = [NSMutableSet setWithCapacity: [bxEntities count]];
	NSMutableDictionary* entitiesBySchema = [NSMutableDictionary dictionary];

	// Create entity descriptions for all entities.
	BXEnumerate (bxEntity, e, [bxEntities objectEnumerator])
	{
		// Currently we just skip views.
		if (! [bxEntity isView])
		{
			NSEntityDescription* currentEntity = [[[NSEntityDescription alloc] init] autorelease];
			[currentEntity setName: [bxEntity name]];
			
			NSMutableArray* currentSchema = [entitiesBySchema objectForKey: [bxEntity schemaName]];
			if (! currentSchema)
			{
				currentSchema = [NSMutableArray array];
				[entitiesBySchema setObject: currentSchema forKey: [bxEntity schemaName]];
			}
			[currentSchema addObject: currentEntity];
			
			//FIXME: change this into an error.
			Expect (! [entityNames containsObject: [currentEntity name]]);
			[entityNames addObject: [currentEntity name]];
			
			[entities addObject: currentEntity];
			[currentEntity setManagedObjectClassName: [self managedObjectClassName]];
		}
	}
	
	[retval setEntities: entities];
	
	// Create configurations based on schema names.
	BXEnumerate (currentSchema, e, [entitiesBySchema keyEnumerator])
	{
		[retval setEntities: [entitiesBySchema objectForKey: currentSchema] 
		   forConfiguration: currentSchema];
	}
	
	// Create attributes and relationships.
	BXEnumerate (bxEntity, e, [bxEntities objectEnumerator])
	{
		NSEntityDescription* currentEntity = [[retval entitiesByName] objectForKey: [bxEntity name]];
		
		NSDictionary* attributesByName = [bxEntity attributesByName];
		NSDictionary* relationshipsByName = nil;
		if ([bxEntity hasCapability: kBXEntityCapabilityRelationships])
			relationshipsByName = [bxEntity relationshipsByName];
		NSMutableArray* properties = [NSMutableArray arrayWithCapacity: 
									  [attributesByName count] + [relationshipsByName count]];
		
		BXEnumerate (bxAttr, e, [attributesByName objectEnumerator])
		{
			if (! [bxAttr isExcluded])
			{
				NSAttributeDescription* attr = [[[NSAttributeDescription alloc] init] autorelease];
				[properties addObject: attr];
				
				[attr setName: [bxAttr name]];
				
				IdentifierMap::const_iterator it = gTypeMapping.find ([bxAttr databaseTypeName]);
				if (it != gTypeMapping.end ())
					[attr setAttributeType: it->second];
				else
					[attr setAttributeType: NSUndefinedAttributeType];
				
				NSDictionary* userInfo = [NSDictionary dictionaryWithObject: [bxAttr databaseTypeName] forKey: @"Database type"];
				[attr setUserInfo: userInfo];
			}
		}

		BXEnumerate (bxRel, e, [relationshipsByName objectEnumerator])
		{
			BOOL usesRelNames = [bxRel usesRelationNames];
			if (((usesRelNames && exportRelNameRelationships) ||
				 (!usesRelNames && exportFkeyRelationships)) && 
				! [bxRel isDeprecated])
			{
				BXEntityDescription* bxDst = [(BXRelationshipDescription *) bxRel destinationEntity];
				if (! ([bxEntity isView] || [bxDst isView]))
				{
					NSRelationshipDescription* rel = [[[NSRelationshipDescription alloc] init] autorelease];
					[properties addObject: rel];
					
					NSEntityDescription* dst = [[retval entitiesByName] objectForKey: [bxDst name]];

					[rel setName: [bxRel name]];
					[rel setDestinationEntity: dst];
					if (! [bxRel isToMany])
						[rel setMaxCount: 1];
					if (! [bxRel isOptional])
						[rel setMinCount: 1];
				}
			}
		}
		
		[currentEntity setProperties: properties];
	}
	
	// Set inverse relationships.
	BXEnumerate (bxEntity, e, [bxEntities objectEnumerator])
	{
		NSEntityDescription* entity = [[retval entitiesByName] objectForKey: [bxEntity name]];
		if (entity && [bxEntity hasCapability: kBXEntityCapabilityRelationships])
		{
			BXEnumerate (bxRel, e, [[bxEntity relationshipsByName] objectEnumerator])
			{
				NSRelationshipDescription* rel = [[entity relationshipsByName] objectForKey: [bxRel name]];
				if (rel && ! [rel inverseRelationship])
				{
					BXRelationshipDescription* bxDstRel = [(BXRelationshipDescription *) bxRel inverseRelationship];
					BXEntityDescription* bxDst = [bxDstRel entity];
					NSEntityDescription* dst = [[retval entitiesByName] objectForKey: [bxDst name]];
					NSString* inverseName = [[bxRel inverseRelationship] name];
					NSRelationshipDescription* inverse = [[dst relationshipsByName] objectForKey: inverseName];
					
					[rel setInverseRelationship: inverse];
					[inverse setInverseRelationship: rel];
				}
			}
		}
	}
	
	return retval;
}
@end
