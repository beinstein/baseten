//
// BXPGEFMetadataContainer.m
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

#import "BXPGEFMetadataContainer.h"
#import "BXPGDatabaseDescription.h"
#import "BXPGTableDescription.h"
#import "PGTSIndexDescription.h"
#import "PGTSConnection.h"
#import "PGTSResultSet.h"
#import "BXLogger.h"
#import "BXEnumerate.h"
#import "BXPGInterface.h"
#import "BXPGForeignKeyDescription.h"
#import "PGTSDeleteRule.h"


@implementation BXPGEFMetadataContainer
- (Class) databaseDescriptionClass
{
	return [BXPGDatabaseDescription class];
}

- (Class) tableDescriptionClass
{
	return [BXPGTableDescription class];
}

- (void) fetchSchemaVersion: (PGTSConnection *) connection
{
	NSString* query =
	@"SELECT baseten.version () AS version "
	@" UNION ALL "
	@" SELECT baseten.compatibilityversion () AS version";
	PGTSResultSet* res = [connection executeQuery: query];
	ExpectV ([res querySucceeded]);
	
	[res advanceRow];
	[mDatabase setSchemaVersion: [res valueForKey: @"version"]];
	[res advanceRow];
	[mDatabase setSchemaCompatibilityVersion: [res valueForKey: @"version"]];	
}

- (void) fetchPreparedRelations: (PGTSConnection *) connection
{
	NSString* query = @"SELECT relid FROM baseten.enabled_relation";
	PGTSResultSet* res = [connection executeQuery: query];
	ExpectV ([res querySucceeded]);
	
	while ([res advanceRow])
	{
		id table = [mDatabase tableWithOid: [[res valueForKey: @"relid"] PGTSOidValue]];
		[table setEnabled: YES];
	}	
}

- (void) fetchViewPrimaryKeys: (PGTSConnection *) connection
{
	NSString* query = 
	@"SELECT oid, baseten.array_accum (attnum) AS attnum "
	@" FROM baseten.primary_key "
	@" WHERE relkind = 'v' "
	@" GROUP BY oid";
	PGTSResultSet* res = [connection executeQuery: query];
	ExpectV ([res querySucceeded]);
	
	while ([res advanceRow])
	{
		PGTSTableDescription* view = [mDatabase tableWithOid: [[res valueForKey: @"oid"] PGTSOidValue]];				
		PGTSIndexDescription* index = [[[PGTSIndexDescription alloc] init] autorelease];
		
		NSMutableSet* indexFields = [NSMutableSet set];
		BXEnumerate (currentColIndex, e, [[res valueForKey: @"attnum"] objectEnumerator])
		[indexFields addObject: [view columnAtIndex: [currentColIndex integerValue]]];
		
		[index setPrimaryKey: YES];
		[index setColumns: indexFields];
		[view addIndex: index];
	}
}

- (void) fetchForeignKeys: (PGTSConnection *) connection
{
	NSString* query = 
	@"SELECT conoid, name, srcfnames, dstfnames, deltype "
	@" FROM baseten.foreignkey ";
	PGTSResultSet* res = [connection executeQuery: query];
	ExpectV ([res querySucceeded]);
	
	while ([res advanceRow])
	{
		BXPGForeignKeyDescription* fkey = [[BXPGForeignKeyDescription alloc] init];
		[fkey setOid: [[res valueForKey: @"conoid"] PGTSOidValue]];
		[fkey setName: [res valueForKey: @"name"]];
		
		NSArray* srcfnames = [res valueForKey: @"srcfnames"];
		NSArray* dstfnames = [res valueForKey: @"dstfnames"];
		for (NSUInteger i = 0, count = [srcfnames count]; i < count; i++)
			[fkey addSrcFieldName: [srcfnames objectAtIndex: i] dstFieldName: [dstfnames objectAtIndex: i]];
		
		NSDeleteRule deleteRule = NSDenyDeleteRule;
		enum PGTSDeleteRule pgDeleteRule = PGTSDeleteRule ([[res valueForKey: @"deltype"] characterAtIndex: 0]);
		switch (pgDeleteRule)
		{
			case kPGTSDeleteRuleUnknown:
			case kPGTSDeleteRuleNone:
			case kPGTSDeleteRuleNoAction:
			case kPGTSDeleteRuleRestrict:
				deleteRule = NSDenyDeleteRule;
				break;
				
			case kPGTSDeleteRuleCascade:
				deleteRule = NSCascadeDeleteRule;
				break;
				
			case kPGTSDeleteRuleSetNull:
			case kPGTSDeleteRuleSetDefault:
				deleteRule = NSNullifyDeleteRule;
				break;
				
			default:
				break;
		}
		[fkey setDeleteRule: deleteRule];
		
		[mDatabase addForeignKey: fkey];
	}
}

- (void) fetchBXSpecific: (PGTSConnection *) connection
{
	NSString* query = @"SELECT EXISTS (SELECT n.oid FROM pg_namespace n WHERE nspname = 'baseten') AS exists";
	PGTSResultSet* res = [connection executeQuery: query];
	ExpectV ([res querySucceeded])
	
	[res advanceRow];
	BOOL hasSchema = [[res valueForKey: @"exists"] boolValue];
	[mDatabase setHasBaseTenSchema: hasSchema];
	
	if (hasSchema)
	{
		[self fetchSchemaVersion: connection];
		
		NSNumber* currentCompatVersion = [BXPGVersion currentCompatibilityVersionNumber];
		if ([currentCompatVersion isEqualToNumber: [mDatabase schemaCompatibilityVersion]])
		{
			[self fetchPreparedRelations: connection];
			[self fetchViewPrimaryKeys: connection];
			[self fetchForeignKeys: connection];
		}
	}
}

- (void) loadUsing: (PGTSConnection *) connection
{
	[super loadUsing: connection];
	[self fetchBXSpecific: connection];
}
@end
