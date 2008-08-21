//
// BXPredicateVisitor.m
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

#if defined (PREDICATE_VISITOR)


#import "BXPredicateVisitor.h"


@implementation BXPredicateVisitor
- (id) init
{
	if ((self = [super init]))
	{
		mStackIdx = -1;
		mCollectAllState = YES;
	}
	return self;
}

- (void) dealloc
{
	[mStack release];
	[mContext release];
	[mObject release];
	[super dealloc];
}

- (void) addFrame
{
	if (! mStack)
		mStack = [[NSMutableArray alloc] init];
	
	NSUInteger count = [mStack count];
	mStackIdx++;
	if (count <= mStackIdx)
		[mStack addObject: [NSMutableArray array]];
	else
		[[mStack objectAtIndex: mStackIdx] removeAllObjects];
}

- (void) removeFrame
{
	[[mStack objectAtIndex: mStackIdx] removeAllObjects];
	if (-1 < mStackIdx)
		mStackIdx--;
}

- (NSMutableArray *) currentFrame
{
	if (! mStack)
		[self addFrame];
	return [mStack objectAtIndex: mStackIdx];
}

#if 0 //Change to setObject:
- (void) setEntity: (BXEntityDescription *) anEntity
{
	if (anEntity != mEntity)
	{
		[mEntity release];
		mEntity = [anEntity retain];
	}
}
#endif

- (NSString *) beginWithPredicate: (NSPredicate *) predicate object: (BXDatabaseObject *) object
{
	if (mContext)
		[mContext removeAllObjects];
	else
		mContext = [[NSMutableDictionary alloc] init];
	
	[self setObject: object];
	
	[predicate BXVisit: self];
#warning Collect the objects from stack.
	return nil;
}

- (void) checkKeyPath: (NSString *) keyPath
{
#warning Check for functions in the key path; if the key path evaluates into a collection and the function is like count, min, max, we needn't use array_accum.
}

- (void) evaluateExpression: (NSExpression *) expression
{
	id evaluated = [self expressionValueWithObject: mObject context: mContext];
	if ([evaluated isKindOfClass: [NSExpression class]])
		[evaluated BXVisit: self];
	else
	{
#warning Add the evaluated object as a $n style parameter.
	}
}
@end


@implementation BXPredicateVisitor (BXPredicateVisitor)
#pragma mark Predicates
- (void) visitUnknownPredicate: (NSPredicate *) predicate
{
}

- (void) visitTruePredicate: (NSPredicate *) predicate
{
	[[self currentFrame] addObject: @"(true)"];
}

- (void) visitFalsePredicate: (NSPredicate *) predicate
{
	[[self currentFrame] addObject: @"(false)"];
}

- (void) visitAndPredicate: (NSCompoundPredicate *) predicate
{
}

- (void) visitOrPredicate: (NSCompoundPredicate *) predicate
{
}

- (void) visitNotPredicate: (NSCompoundPredicate *) predicate
{
	mCollectAllState = ! mCollectAllState;
}

- (void) visitComparisonPredicate: (NSComparisonPredicate *) predicate
{
	//Check for custom comparison selector.
}

#pragma mark Expressions
- (void) visitConstantValueExpression: (NSExpression *) expression
{
	id constantValue = [expression constantValue];
    if (YES == [constantValue respondsToSelector: @selector (PGTSConstantExpressionValue:)])
    {
        id value = [constantValue PGTSConstantExpressionValue: context];
#warning Handle the constant value
    }
	else
	{
		[self evaluateExpression: expression];
	}
}

- (void) visitEvaluatedObjectExpression: (NSExpression *) expression
{
	[self evaluateExpression: expression];
}

- (void) visitVariableExpression: (NSExpression *) expression
{
	[self evaluateExpression: expression];
}

- (void) visitKeyPathExpression: (NSExpression *) expression
{
	NSString* keyPath = [expression keyPath];
	[self checkKeyPath: keyPath];
}

- (void) visitFunctionExpression: (NSExpression *) expression
{
	NSString* functionName = [expression function];
	NSExpression* operand = [expression operand];
	NSArray* arguments = [expression arguments];
	
	if ([@"valueForKeyPath:" isEqualToString: functionName])
	{
#warning Check the operand type (scalar or collection); it affects the function's behaviour.
		
		//There should be one argument of type NSKeyPathSpecifierExpression.
		NSExpression* argument = [arguments lastObject];
		NSString* keyPath = [argument keyPath];
	}
}

- (void) visitAggregateExpression: (NSExpression *) expression
{
}

- (void) visitSubqueryExpression: (NSExpression *) expression
{
}

- (void) visitUnionSetExpression: (NSExpression *) expression
{
}

- (void) visitIntersectSetExpression: (NSExpression *) expression
{
}

- (void) visitMinusSetExpression: (NSExpression *) expression
{
}

- (void) visitUnknownExpression: (NSExpression *) expression
{
}
@end

#endif