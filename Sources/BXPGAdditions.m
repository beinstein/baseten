//
// BXPGAdditions.m
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

#import <PGTS/PGTSAdditions.h>
#import "BXPGAdditions.h"
#import "BXDatabaseAdditions.h"
#import "BXPropertyDescriptionPrivate.h"
#import "BXAttributeDescriptionPrivate.h"
#import "BXDatabaseObjectPrivate.h"


@implementation NSObject (BXPGAdditions)
- (NSString *) BXPGEscapedName: (PGTSConnection *) connection
{
	NSString* name = [[self description] PGTSEscapedString: connection];
	return [NSString stringWithFormat: @"\"%@\"", name];
}

- (NSString *) BXPGQualifiedName: (PGTSConnection *) connection
{
	return [self BXPGEscapedName: connection];
}
@end


@implementation BXEntityDescription (BXPGInterfaceAdditions)
- (NSString *) BXPGQualifiedName: (PGTSConnection *) connection
{
	NSString* schemaName = [[self schemaName] BXPGEscapedName: connection];
	NSString* name = [[self name] BXPGEscapedName: connection];
    return [NSString stringWithFormat: @"%@.%@", schemaName, name];
}
@end


@implementation BXAttributeDescription (BXPGInterfaceAdditions)
- (NSString *) BXPGQualifiedName: (PGTSConnection *) connection
{    
	return [NSString stringWithFormat: @"%@.%@", 
			[[self entity] BXPGQualifiedName: connection], [[self name] BXPGEscapedName: connection]];
}
@end


@implementation PGTSFieldDescriptionProxy (BXPGAttributeDescription)
- (NSString *) BXPGEscapedName: (PGTSConnection *) connection
{
	return [[(id) self name] BXPGEscapedName: connection];
}
@end


@implementation NSURL (BXPGInterfaceAdditions)
#define SetIf( VALUE, KEY ) if ((VALUE)) [connectionDict setObject: VALUE forKey: KEY];
- (NSMutableDictionary *) BXPGConnectionDictionary
{
	NSMutableDictionary* connectionDict = nil;
	if (0 == [@"pgsql" caseInsensitiveCompare: [self scheme]])
	{
		connectionDict = [NSMutableDictionary dictionary];    
		
		NSString* relativePath = [self relativePath];
		if (1 <= [relativePath length])
			SetIf ([relativePath substringFromIndex: 1], kPGTSDatabaseNameKey);
		
		SetIf ([self host], kPGTSHostKey);
		SetIf ([[self user] BXURLDecodedString], kPGTSUserNameKey);
		SetIf ([[self password] BXURLDecodedString], kPGTSPasswordKey);
		SetIf ([self port], kPGTSPortKey);
	}
	return connectionDict;
}
@end


@implementation BXDatabaseObject (BXPGInterfaceAdditions)
- (void) PGTSSetRow: (int) row resultSet: (PGTSResultSet *) res
{
    [res goToRow: row];
    [self setCachedValuesForKeysWithDictionary: [res currentRowAsDictionary]];
}
@end
