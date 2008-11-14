//
// BXPGExpressionValueType.mm
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
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


#import "BXPGExpressionValueType.h"
#import "BXPredicateVisitor.h"
#import "BXPGDatabaseObjectExpressionValueType.h"
#import "BXPGConstantExpressionValueType.h"
#import "PGTSFoundationObjects.h"


@implementation BXPGExpressionValueType
+ (id) valueTypeForObject: (id) value
{
	id retval = nil;
	if ([value isKindOfClass: [BXDatabaseObject class]])
	{
		retval = [BXPGDatabaseObjectExpressionValueType typeWithValue: value];
	}
	else
	{
		NSInteger cardinality = 0;
		//FIXME: perhaps we should check for multi-dimensionality.
		if ([value PGTSIsCollection])
			cardinality = 1;
		retval = [BXPGConstantExpressionValueType typeWithValue: value cardinality: cardinality];
	}
	return retval;
}

+ (id) type
{
	id retval = [[[self alloc] init] autorelease];
	return retval;
}

- (id) init
{
	if ([self class] == [BXPGExpressionValueType class])
		[self doesNotRecognizeSelector: _cmd];

	if ((self = [super init]))
	{
	}
	return self;
}

- (id) value
{
	return nil;
}

- (BOOL) isDatabaseObject
{
	return NO;
}

- (BOOL) hasRelationships
{
	return NO;
}

- (BOOL) isIdentityExpression
{
	return NO;
}

- (NSInteger) arrayCardinality
{
	return 0;
}

- (NSInteger) relationshipCardinality
{
	return 0;
}

- (NSString *) expressionSQL: (id <BXPGExpressionHandler>) visitor
{
	BXLogError (@"Tried to call -expressionSQL: for class %@, value %@", [self class], [self value]);
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}
@end
