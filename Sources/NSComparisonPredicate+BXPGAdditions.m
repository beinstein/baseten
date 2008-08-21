//
// NSComparisonPredicate+BXPGAdditions.m
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

#import "NSPredicate+PGTSAdditions.h"
#import "NSComparisonPredicate+BXPGAdditions.h"
#import "NSExpression+PGTSAdditions.h"
#import "PGTSFoundationObjects.h"
#import "BXLogger.h"
#import "BXConstants.h"


#if defined (PREDICATE_VISITOR)
@implementation NSComparisonPredicate (BXAdditions)
- (void) BXVisit: (id <BXPredicateVisitor>) visitor
{
	[visitor visitComparisonPredicate: self];
}
@end
#else
static void
MarkUnused (NSComparisonPredicate* predicate, NSMutableDictionary* ctx)
{
	NSMutableSet* unused = [ctx objectForKey: kBXUnknownPredicatesKey];
	if (! unused)
	{
		unused = [NSMutableSet set];
		[ctx setObject: unused forKey: kBXUnknownPredicatesKey];
	}
	[unused addObject: predicate];
}


@implementation NSComparisonPredicate (PGTSAdditions)
- (NSString *) PGTSWhereClauseWithContext: (NSMutableDictionary *) context
{
	return [self PGTSExpressionWithObject: nil context: context];
}

- (NSString *) PGTSExpressionWithObject: (id) anObject context: (NSMutableDictionary *) context
{
	NSString* retval = nil;
    NSPredicateOperatorType type = [self predicateOperatorType];

	//See if we can handle the predicate.
	switch (type) 
	{
		case NSCustomSelectorPredicateOperatorType:
			//We don't understand the predicate.
			goto end;
			break;
			
		default:
			break;
	}
	
	NSExpression* lhs = [self leftExpression];
	NSExpression* rhs = [self rightExpression];
	if (! (lhs && rhs))
		goto end;
	
	//Get lval and rval; some predicate operators require special handling.
	id lval = nil;
	id rval = nil;
	switch (type) 
	{
#if MAC_OS_X_VERSION_10_5 <= MAC_OS_X_VERSION_MAX_ALLOWED
		case NSBetweenPredicateOperatorType:
			lval = [lhs PGTSValueWithObject: anObject context: context];
			if (NSAggregateExpressionType == [rhs expressionType])
			{
				NSArray* collection = [rhs collection];
				if (2 == [collection count])
				{
					//Fortunately, the collection is guaranteed to contain only expressions.
					id v1 = [collection objectAtIndex: 0];
					id v2 = [collection objectAtIndex: 1];
					v1 = [v1 PGTSValueWithObject: anObject context: context];
					v2 = [v2 PGTSValueWithObject: anObject context: context];
					rval = [NSString stringWithFormat: @"%@ AND %@", v1, v2];
				}
			}
			break;
#endif
			
		default:
			lval = [lhs PGTSValueWithObject: anObject context: context];
			rval = [rhs PGTSValueWithObject: anObject context: context];
			break;
	}
	
	if (! (lval && rval))
		goto end;
	
	unsigned int comparisonOptions = [self options];
	if (comparisonOptions & ~NSCaseInsensitivePredicateOption)
		goto end;

	NSComparisonPredicateModifier modifier = [self comparisonPredicateModifier];

	//Preprocess some other types.
	switch (type) 
	{
#if MAC_OS_X_VERSION_10_5 <= MAC_OS_X_VERSION_MAX_ALLOWED
		case NSContainsPredicateOperatorType:
		{
			BXAssertLog ([lval PGTSIsCollection], @"Expected %@ to be a collection.", lval);
			id tmp = lval;
			lval = rval;
			rval = tmp;
			//Fall through.
		}
#endif
			
		//NSInPredicateOperatorType may be used not only with collections but also with strings.
		case NSInPredicateOperatorType:
		{
			if ([rhs PGTSIsCollection])
			{
				type = NSEqualToPredicateOperatorType;
				modifier = NSAnyPredicateModifier;
			}
			else
			{
				id tmp = rval;
				rval = [NSString stringWithFormat: @"%%%@%%", lval];
				lval = tmp;
			}			
			break;
		}
			
		case NSBeginsWithPredicateOperatorType:
			type = NSLikePredicateOperatorType;
			rval = [rval stringByAppendingString: @"%"];
			break;
			
		case NSEndsWithPredicateOperatorType:
			type = NSLikePredicateOperatorType;
			rval = [@"%" stringByAppendingString: rval];
			break;
			
		default:
			break;
	}
	
	//Choose the operator.
	NSString* operator = nil;
	switch (type)
	{
		case NSLessThanPredicateOperatorType:
			operator = @"<";
			break;
		case NSLessThanOrEqualToPredicateOperatorType:
			operator = @"<=";
			break;
		case NSGreaterThanPredicateOperatorType:
			operator = @">";
			break;
		case NSGreaterThanOrEqualToPredicateOperatorType:
			operator = @">=";
			break;
		case NSEqualToPredicateOperatorType:
			operator = @"=";
			break;
		case NSNotEqualToPredicateOperatorType:
			operator = @"<>";
			break;
		case NSMatchesPredicateOperatorType:
			operator = @"~";
			break;
		case NSLikePredicateOperatorType:
			operator = @"~~";
			break;
			
#if MAC_OS_X_VERSION_10_5 <= MAC_OS_X_VERSION_MAX_ALLOWED
		case NSBetweenPredicateOperatorType:
			operator = @"BETWEEN";
			break;
#endif
			
		default:
			[NSException raise: NSInvalidArgumentException format: @"Unsupported predicate operator: %d.", type];
			break;
	}
	NSAssert (operator, @"Expected operator not to be nil.");
	
	//Case insensitivity.
	switch (type)
	{
		case NSMatchesPredicateOperatorType:
		case NSLikePredicateOperatorType:
		{
			if (comparisonOptions & NSCaseInsensitivePredicateOption)
				operator = [operator stringByAppendingString: @"*"];
			break;
		}
		default:
			break;
	}
	
	if (NSDirectPredicateModifier != modifier)
	{
		BXAssertValueReturn ([rhs PGTSIsCollection], nil, @"Expected %@ to be a collection.", rhs);
		switch (modifier)
		{
			case NSAllPredicateModifier:
				operator = [operator stringByAppendingString: @" ALL"];
				break;
			case NSAnyPredicateModifier:
				operator = [operator stringByAppendingString: @" ANY"];
				break;
			default:
				[NSException raise: NSInvalidArgumentException format: @"Unexpected predicate modifier: %d.", modifier];
				break;
		}
	}	
	
	//Unfortunately we need to surround the values with parentheses or else ANY = and ALL = will fail.
	retval = [NSString stringWithFormat: @"((%@) %@ (%@))", lval, operator, rval];
	
end:
	//If the predicate can't be converted to SQL, replace it with "true". Currently we don't analyze the
	//predicate tree and optimize it by removing unneeded predicates from each branch. This is bad for NOT
	//predicates, though.
	if (! retval)
	{
		MarkUnused (self, context);
		retval = @"(true)";
	}
	
	return retval;
}
@end
#endif