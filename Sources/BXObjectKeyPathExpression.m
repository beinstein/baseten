//
// BXObjectKeyPathExpression.m
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

#import "BXObjectKeyPathExpression.h"


@implementation BXObjectKeyPathExpression

+ (id) expressionForKeyPath: (NSString *) keyPath object: (id) anObject
{
	return [[[self alloc] initWithKeyPath: keyPath object: anObject] autorelease];
}

- (id) initWithKeyPath: (NSString *) keyPath object: (id) anObject
{
	//This probably resembles NSKeyPathExpression but it has a special meaning in PGTS.
	//Hence, we pretend to be an evaluated object.
	if ((self = [super initWithExpressionType: NSEvaluatedObjectExpressionType]))
	{
		mObject = anObject; //No retain.
		mKeyPath = [keyPath copy];
	}
	return self;
}

- (void) dealloc
{
	[mKeyPath release];
	[super dealloc];
}

- (NSString *) keyPath
{
	return mKeyPath;
}

- (id) operand
{
	return mObject;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"<%@ (%p): %@ - %@>", [self class], self, mKeyPath, mObject];
}

- (id) expressionValueWithObject: (id) object context: (NSMutableDictionary *) context
{
	return [mObject valueForKeyPath: mKeyPath];
}

@end
