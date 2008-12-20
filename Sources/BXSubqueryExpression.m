//
// BXSubqueryExpression.m
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

#import "BXSubqueryExpression.h"
#import "BXDatabaseAdditions.h"


@implementation BXSubqueryExpression
- (id) initWithSubquery: (NSExpression *) expression 
  usingIteratorVariable: (NSString *) variable 
			  predicate: (NSPredicate *) predicate
{
	if ((self = [super init]))
	{
		mCollection = [expression copy];
		mVariable = [NSExpression expressionForVariable: variable];
		mPredicate = [predicate copy];
	}
	return self;
}

+ (id) expressionForSubquery: (NSExpression *) expression 
	   usingIteratorVariable: (NSString *) variable 
				   predicate: (NSPredicate *) predicate
{
	id retval = [[[self alloc] initWithSubquery: expression usingIteratorVariable: variable predicate: predicate] autorelease];
	return retval;
}

- (void) dealloc
{
	[mCollection release];
	[mVariable release];
	[mPredicate release];
	[super dealloc];
}

- (NSExpression *) collection
{
	return mCollection;
}

- (NSExpression *) variableExpression
{
	return mVariable;
}

- (NSString *) variable
{
	return [mVariable variable];
}

- (NSPredicate *) predicate
{
	return mPredicate;
}

- (id) expressionValueWithObject: (id) object context: (NSMutableDictionary *) ctx
{
	NSString* variableName = [self variable];
	id oldValue = [ctx objectForKey: variableName];
	id collection = [mCollection expressionValueWithObject: object context: ctx];
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [collection count]];
		
	BXEnumerate (currentObject, e, [collection objectEnumerator])
	{
		[ctx setObject: currentObject forKey: variableName];
		if ([mPredicate BXEvaluateWithObject: currentObject substitutionVariables: ctx])
			[retval addObject: currentObject];
	}
	
	[ctx setObject: oldValue forKey: variableName];
	return retval;
}
@end
