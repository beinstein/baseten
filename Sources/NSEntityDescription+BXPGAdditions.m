//
// NSEntityDescription+BXPGAdditions.m
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

#import "NSEntityDescription+BXPGAdditions.h"
#import "NSAttributeDescription+BXPGAdditions.h"
#import "BXLogger.h"
#import "PGTSFunctions.h"


@implementation NSEntityDescription (BXPGAdditions)
- (NSString *) BXPGCreateStatementsWithIDColumn: (BOOL) addSerialIDColumn inSchema: (NSString *) schemaName
{
	Expect (schemaName);

	NSString* name = [self name];
	NSEntityDescription* superentity = [self superentity];
	NSDictionary* attributes = [self attributesByName];
    NSMutableArray* attributeDefs = [NSMutableArray arrayWithCapacity: 1 + [attributes count]];    
    if (YES == addSerialIDColumn)
        [attributeDefs addObject: @"id SERIAL"];
	
	TSEnumerate (currentAttribute, e, [attributes objectEnumerator])
	{
		//Transient values are not stored
		if ([currentAttribute isTransient])
			continue;
		
		NSString* attrDef = [currentAttribute BXPGAttributeDefinition];
		if (attrDef)
			[attributeDefs addObject: attrDef];
	}
	
	NSString* addition = @"";
	if (superentity)
		addition = [NSString stringWithFormat: @"INHERITS (\"%@\".\"%@\")", schemaName, [superentity name]];
	
	NSString* statementFormat = @"CREATE TABLE \"%@\".\"%@\" (%@) %@;";
	NSString* retval = [NSString stringWithFormat: statementFormat, schemaName, name,
						[attributeDefs componentsJoinedByString: @", "], addition];
	
	return retval;
}
@end
