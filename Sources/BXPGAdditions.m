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

#import "PGTSAdditions.h"
#import "BXPGAdditions.h"
#import "BXDatabaseAdditions.h"
#import "BXPropertyDescriptionPrivate.h"
#import "BXAttributeDescriptionPrivate.h"
#import "BXDatabaseObjectPrivate.h"
#import "BXPGExpressionVisitor.h"
#import "BXLogger.h"


@implementation NSObject (BXPGAdditions)
- (NSString *) BXPGEscapedName: (PGTSConnection *) connection
{
	return [self PGTSEscapedName: connection];
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


@implementation BXPropertyDescription (BXPGInterfaceAdditions)
- (void) BXPGVisitKeyPathComponent: (id <BXPGExpressionVisitor>) visitor
{
	[self doesNotRecognizeSelector: _cmd];
}
@end



@implementation BXAttributeDescription (BXPGInterfaceAdditions)
- (NSString *) BXPGQualifiedName: (PGTSConnection *) connection
{    
	return [NSString stringWithFormat: @"%@.%@", 
			[[self entity] BXPGQualifiedName: connection], [[self name] BXPGEscapedName: connection]];
}

- (NSString *) BXPGEscapedName: (PGTSConnection *) connection
{
	return [[self name] BXPGEscapedName: connection];
}

- (id) PGTSConstantExpressionValue: (NSMutableDictionary *) ctx
{
	BXEntityDescription* myEntity = [self entity];
	BXEntityDescription* primaryRelation = [ctx objectForKey: kBXEntityDescriptionKey];
	Expect (primaryRelation);
	BXAssertValueReturn ([myEntity isEqual: primaryRelation], nil, 
						 @"BXAttributeDescription as expression value is required to be one of the primary relation's attributes.");
	NSString* key = [self name];
	return [NSExpression expressionForKeyPath: key];
}

- (void) BXPGVisitKeyPathComponent: (id <BXPGExpressionVisitor>) visitor
{
	[visitor visitAttribute: self];
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


@implementation BXRelationshipDescription (BXPGInterfaceAdditions)
- (void) BXPGVisitKeyPathComponent: (id <BXPGExpressionVisitor>) visitor
{
	[visitor visitRelationship: self];
}
@end
