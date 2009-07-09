//
// BXDatabaseObjectModelXMLSerialization.m
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

#import "BXDatabaseObjectModelXMLSerialization.h"
#import "BXDatabaseObjectModel.h"
#import "BXEnumerate.h"
#import "BXEntityDescription.h"
#import "BXAttributeDescription.h"
#import "BXRelationshipDescription.h"
#import "BXRelationshipDescriptionPrivate.h"


@implementation BXDatabaseObjectModelXMLSerialization
+ (NSData *) dataFromObjectModel: (BXDatabaseObjectModel *) objectModel 
						 options: (enum BXDatabaseObjectModelSerializationOptions) options
						   error: (NSError **) outError
{
	return [[self documentFromObjectModel: objectModel options: options error: outError] XMLData];
}


+ (NSXMLDocument *) documentFromObjectModel: (BXDatabaseObjectModel *) objectModel 
									options: (enum BXDatabaseObjectModelSerializationOptions) options
									  error: (NSError **) outError
{
	const BOOL exportFkeyRelationships    = options & kBXDatabaseObjectModelSerializationOptionRelationshipsUsingFkeyNames;
	const BOOL exportRelNameRelationships = options & kBXDatabaseObjectModelSerializationOptionRelationshipsUsingTargetRelationNames;
	
	if (options & kBXDatabaseObjectModelSerializationOptionExcludeForeignKeyAttributes)
		BXLogWarning (@"kBXDatabaseObjectModelSerializationOptionExcludeForeignKeyAttributes is ignored for %@", self);
	if (options & kBXDatabaseObjectModelSerializationOptionCreateRelationshipsAsOptional)
		BXLogWarning (@"kBXDatabaseObjectModelSerializationOptionCreateRelationshipsAsOptional is ignored for %@", self);

	NSXMLElement* root = [NSXMLElement elementWithName: @"objectModel"];
	NSXMLDocument* retval = [NSXMLDocument documentWithRootElement: root];
	
	NSArray* entities = [objectModel entities: outError];
	BXEnumerate (currentEntity, e, [entities objectEnumerator])
	{
		NSXMLElement* entity = [NSXMLElement elementWithName: @"entity"];
		NSXMLElement* elID = [NSXMLElement attributeWithName: @"id" stringValue:
							  [NSString stringWithFormat: @"%@__%@", [currentEntity schemaName], [currentEntity name]]];
		[entity addAttribute: elID];
		NSXMLElement* isView = [NSXMLElement attributeWithName: @"isView" stringValue: ([currentEntity isView] ? @"true" : @"false")];
		[entity addAttribute: isView];

		NSXMLElement* schemaName = [NSXMLElement elementWithName: @"schemaName" stringValue: [currentEntity schemaName]];
		NSXMLElement* name = [NSXMLElement elementWithName: @"name" stringValue: [currentEntity name]];
		[entity addChild: schemaName];
		[entity addChild: name];
		
		NSXMLElement* attrs = [NSXMLElement elementWithName: @"attributes"];
		BXEnumerate (currentAttr, e, [[currentEntity attributesByName] objectEnumerator])
		{
			if (! [currentAttr isExcluded])
			{
				NSXMLElement* attr = [NSXMLElement elementWithName: @"attribute"];
				NSXMLElement* name = [NSXMLElement elementWithName: @"name" stringValue: [currentAttr name]];
				NSXMLElement* type = [NSXMLElement elementWithName: @"type" stringValue: [currentAttr databaseTypeName]];
				[attr addChild: name];
				[attr addChild: type];
				[attrs addChild: attr];
			}
		}
		[entity addChild: attrs];
		
		if ((exportFkeyRelationships || exportRelNameRelationships) && [currentEntity hasCapability: kBXEntityCapabilityRelationships])
		{
			NSXMLElement* rels = [NSXMLElement elementWithName: @"relationships"];
			BXEnumerate (currentRel, e, [[currentEntity relationshipsByName] objectEnumerator])
			{
				BOOL usesRelNames = [currentRel usesRelationNames];
				if (((usesRelNames && exportRelNameRelationships) ||
					 (!usesRelNames && exportFkeyRelationships)) && 
					! [currentRel isDeprecated])
				{
					NSXMLElement* rel = [NSXMLElement elementWithName: @"relationship"];
					
					NSString* targetID = [NSString stringWithFormat: @"%@__%@", 
										  [(BXEntityDescription *) [currentRel destinationEntity] schemaName], 
										  [(BXEntityDescription *) [currentRel destinationEntity] name]];
					NSXMLElement* target = [NSXMLElement elementWithName: @"target" stringValue: targetID];
					
					BXRelationshipDescription* inverse = [(BXRelationshipDescription *) currentRel inverseRelationship];
					NSXMLElement* inverseName = [NSXMLElement elementWithName: @"inverseRelationship" stringValue: [inverse name]];
					
					NSXMLElement* name = [NSXMLElement elementWithName: @"name" stringValue: [currentRel name]];
					
					NSXMLElement* targetType = [NSXMLElement elementWithName: @"targetType" stringValue:
												([currentRel isToMany] ? @"many" : @"one")];
					
					[rel addChild: name];
					[rel addChild: target];
					[rel addChild: inverseName];
					[rel addChild: targetType];
					
					[rels addChild: rel];
				}
			}
			[entity addChild: rels];
		}
		
		[root addChild: entity];
	}
	
	return retval;
}
@end
