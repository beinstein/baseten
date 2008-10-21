//
// BXPGSQLFunction.m
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

#import "BXPGSQLFunction.h"
#import "BXPGExpressionValueType.h"


@interface BXPGCountAggregate : BXPGSQLFunction
{
}
@end


@implementation BXPGCountAggregate
- (NSInteger) cardinality
{
	return 0;
}

- (void) BXPGVisitKeyPathComponent: (id <BXPGExpressionVisitor>) visitor
{
	[visitor visitCountAggregate: self];
}
@end


@interface BXPGArrayCountFunction : BXPGSQLFunction
{
	NSInteger mCardinality;
}
- (id) initWithCardinality: (NSInteger) c;
@end


@implementation BXPGArrayCountFunction
- (id) initWithCardinality: (NSInteger) c
{
	if ((self = [super init]))
	{
		mCardinality = c;
	}
	return self;
}

- (NSInteger) cardinality
{
	return mCardinality - 1;
}

- (void) BXPGVisitKeyPathComponent: (id <BXPGExpressionVisitor>) visitor
{
	[visitor visitArrayCountFunction: self];
}
@end


@implementation BXPGSQLFunction
+ (id) function
{
	if (self == [BXPGSQLFunction class])
		[self doesNotRecognizeSelector: _cmd];
	
	id retval = [[[self alloc] init] autorelease];
	return retval;
}

+ (id) functionNamed: (NSString *) key valueType: (BXPGExpressionValueType *) valueType
{
	id retval = nil;
	if ([@"@count" isEqualToString: key])
	{
		if (1 == [valueType arrayCardinality])
			retval = [[[BXPGArrayCountFunction alloc] initWithCardinality: 1] autorelease];
		else if (0 < [valueType relationshipCardinality])
			retval = [[[BXPGCountAggregate alloc] init] autorelease];
	}
	return retval;
}

- (NSInteger) cardinality
{
	return 0;
}

- (void) BXPGVisitKeyPathComponent: (id <BXPGExpressionVisitor>) visitor
{
	[self doesNotRecognizeSelector: _cmd];
}
@end



@implementation BXPGSQLArrayAccumFunction
- (NSInteger) cardinality
{
	return 0;
}

- (void) BXPGVisitKeyPathComponent: (id <BXPGExpressionVisitor>) visitor
{
	[visitor visitArrayAccumFunction: self];
}
@end
