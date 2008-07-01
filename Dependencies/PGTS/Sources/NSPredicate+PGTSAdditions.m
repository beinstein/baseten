//
// NSPredicate+PGTSAdditions.m
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
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
#import "NSExpression+PGTSAdditions.h"
#import "BXLogger.h"

#import <PGTS/PGTSFunctions.h>
#import <PGTS/PGTSConstants.h>


static void
RequireClass (id object, Class aClass)
{
	if (! [object isKindOfClass: aClass])
	{
		[NSException raise: NSInvalidArgumentException
					format: @"Expected %@ to be an instance of %@.", object, aClass];
	}
}


@interface NSObject (NSPredicate_PGTSAdditions)
- (BOOL) PGTSIsCollection;
@end


@implementation NSObject (NSPredicate_PGTSAdditions)
- (BOOL) PGTSIsCollection
{
	return NO;
}
@end


@implementation NSArray (NSPredicate_PGTSAdditions)
- (BOOL) PGTSIsCollection
{
	return YES;
}
@end


//FIXME: other collection types, too?
//FIXME: NSSet doesn't implement -PGTSParameterType.
@implementation NSSet (NSPredicate_PGTSAdditions)
- (BOOL) PGTSIsCollection
{
	return YES;
}
@end


@implementation NSPredicate (PGTSAdditions)

- (NSString *) PGTSWhereClauseWithContext: (NSMutableDictionary *) context
{
	return [self PGTSExpressionWithObject: nil context: context];
}

- (NSString *) PGTSExpressionWithObject: (id) anObject context: (NSMutableDictionary *) context
{
    NSString* retval = nil;
    Class tpClass = NSClassFromString (@"NSTruePredicate");
    Class fpClass = NSClassFromString (@"NSFalsePredicate");
    if (nil != tpClass && [self isKindOfClass: tpClass])
        retval = @"(true)";
    else if (nil != fpClass && [self isKindOfClass: fpClass])
        retval = @"(false)";
	//Otherwise we return nil since this method gets overridden anyway.
    return retval;
}
@end

@implementation NSCompoundPredicate (PGTSAdditions)
- (NSString *) PGTSWhereClauseWithContext: (NSMutableDictionary *) context
{
	return [self PGTSExpressionWithObject: nil context: context];
}

- (NSString *) PGTSExpressionWithObject: (id) anObject context: (NSMutableDictionary *) context
{
    BXAssertValueReturn (nil != [context objectForKey: kPGTSConnectionKey], nil, 
						   @"Did you remember to set connection to %@ in context?", kPGTSConnectionKey);
    NSString* retval = nil;
    NSArray* subpredicates = [self subpredicates];
    NSMutableArray* parts = [NSMutableArray arrayWithCapacity: [subpredicates count]];
    TSEnumerate (currentPredicate, e, [subpredicates objectEnumerator])
        [parts addObject: [currentPredicate PGTSExpressionWithObject: anObject context: context]];
    
    NSString* glue = nil;
    NSCompoundPredicateType type = [self compoundPredicateType];
	if (0 < [parts count])
	{
		if (NSNotPredicateType == type)
			retval = [NSString stringWithFormat: @"(NOT %@)", [parts objectAtIndex: 0]];
		else
		{
			switch (type)
			{
				case NSAndPredicateType:
					glue = @" AND ";
					break;
				case NSOrPredicateType:
					glue = @" OR ";
					break;
				default:
					[NSException raise: NSInvalidArgumentException 
								format: @"Unexpected compound predicate type: %d.", type];
					break;
			}
			retval = [NSString stringWithFormat: @"(%@)", [parts componentsJoinedByString: glue]];
		}
    }
    return retval;
}
@end

@implementation NSComparisonPredicate (PGTSAdditions)
- (NSString *) PGTSWhereClauseWithContext: (NSMutableDictionary *) context
{
	return [self PGTSExpressionWithObject: nil context: context];
}

- (NSString *) PGTSExpressionWithObject: (id) anObject context: (NSMutableDictionary *) context
{
	NSString* retval = nil;
    NSPredicateOperatorType type = [self predicateOperatorType];
    NSComparisonPredicateModifier modifier = [self comparisonPredicateModifier];
	id lval = [[self leftExpression] PGTSValueWithObject: anObject context: context];
	id rval = [[self rightExpression] PGTSValueWithObject: anObject context: context];
	
	//In case of a custom selector operator, ignore the :'s at the end and call a function.
	//FIXME: we might need a type for function parameter list for more than 2 parameters. From what I understand, NSAggregateExpressionType is interchangeable with NSArray and therefore isn't suitable.
	if (NSCustomSelectorPredicateOperatorType == type)
	{
		char* selector = strdup ([NSStringFromSelector ([self customSelector]) UTF8String]);
		for (int i = strlen (selector); i > 0; i--)
		{
			if (':' == selector [i - 1])
				selector [i - 1] = '\0';
			else
				break;
		}
		
		//FIXME: does evaluation return an NSNull? We do need that.
		if (! lval)
		{
			lval = rval;
			rval = nil;
		}
		
		if (rval)
			retval = [NSString stringWithFormat: @"%s (%@, %@)", selector, lval, rval];
		else if (lval)
			retval = [NSString stringWithFormat: @"%s (%@)", selector, lval];
		else
			retval = [NSString stringWithFormat: @"%s ()", selector];
		
		free (selector);
	}
	else
	{
		//Preprocess some types.
		switch (type) 
		{
#if MAC_OS_X_VERSION_10_5 <= MAC_OS_X_VERSION_MAX_ALLOWED
			case NSContainsPredicateOperatorType:
			{
				NSAssert1 ([lval PGTSIsCollection], @"Expected %@ to be a collection.", lval);
				id tmp = lval;
				lval = rval;
				rval = tmp;
				//Fall through.
			}
#endif
				
			case NSInPredicateOperatorType:
			{
				if ([rval PGTSIsCollection])
				{
					type = NSEqualToPredicateOperatorType;
					modifier = NSAnyPredicateModifier;
				}
				else
				{
					RequireClass (lval, [NSString class]);
					RequireClass (rval, [NSString class]);
					id tmp = rval;
					rval = [NSString stringWithFormat: @"%%%@%%", lval];
					lval = tmp;
				}			
				break;
			}
				
			case NSBeginsWithPredicateOperatorType:
				type = NSLikePredicateOperatorType;
				RequireClass (lval, [NSString class]);
				RequireClass (rval, [NSString class]);
				rval = [rval stringByAppendingString: @"%"];
				break;
				
			case NSEndsWithPredicateOperatorType:
				type = NSLikePredicateOperatorType;
				RequireClass (lval, [NSString class]);
				RequireClass (rval, [NSString class]);
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
				
			case NSBeginsWithPredicateOperatorType:
			case NSEndsWithPredicateOperatorType:
			case NSInPredicateOperatorType:
			case NSCustomSelectorPredicateOperatorType:
				break;
				
#if MAC_OS_X_VERSION_10_5 <= MAC_OS_X_VERSION_MAX_ALLOWED
			case NSBetweenPredicateOperatorType:
#endif
			default:
				[NSException raise: NSInvalidArgumentException format: @"Unsupported predicate operator: %d.", type];
				break;
		}
		NSAssert (operator, @"Expected operator not to be nil.");
		
		//Case and diacritic insensitivity.
		switch (type)
		{
			case NSMatchesPredicateOperatorType:
			case NSLikePredicateOperatorType:
			{
				unsigned int options = [self options];
				if (NSCaseInsensitivePredicateOption & options)
					operator = [operator stringByAppendingString: @"*"];
				if (NSDiacriticInsensitivePredicateOption & options)
					[NSException raise: NSInvalidArgumentException format: @"Diacritic insensitivity not supported."];
				if (options & 
					~NSDiacriticInsensitivePredicateOption & 
					~NSCaseInsensitivePredicateOption)
					[NSException raise: NSInvalidArgumentException format: @"Unsupported options: %d.", options];
				break;
			}
			default:
				break;
		}
		
		if (NSDirectPredicateModifier != modifier)
		{
			NSAssert1 ([rval PGTSIsCollection], @"Expected %@ to be a collection.", rval);
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
		
		retval = [NSString stringWithFormat: @"(%@ %@ %@)", lval, operator, rval];
	}
    return retval;
}
@end
