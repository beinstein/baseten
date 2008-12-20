//
// BXPGFunctionExpressionEvaluator.m
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

#import "BXPGFunctionExpressionEvaluator.h"
#import "BXPGExpressionValueType.h"
#import "BXDatabaseAdditions.h"
#import "NSExpression+PGTSAdditions.h"
#import "PGTSHOM.h"
#import "BXPGPredefinedFunctionExpressionValueType.h"
#import "BXEnumerate.h"
#import <map>
#import <tr1/unordered_map>
#import <stdarg.h>


typedef std::map <NSInteger, NSInteger> ArgumentCardinalityMap;

struct bx_function_cardinality_st
{
public:
	NSInteger fc_retval_cardinality;
	ArgumentCardinalityMap* fc_arguments;
	BOOL fc_variable_argument_count;
	
	NSInteger argumentCardinality (NSInteger idx);
};

typedef std::tr1::unordered_map <SEL, bx_function_cardinality_st> SelectorCardinalityMap;

NSInteger 
bx_function_cardinality_st::argumentCardinality (NSInteger idx)
{
	NSInteger retval = -1;
	if (fc_variable_argument_count)
		idx = 0;
	
	ArgumentCardinalityMap::iterator it = fc_arguments->find (idx);
	if (fc_arguments->end () != it)
		retval = it->second;
	
	return retval;
}



@implementation BXPGFunctionExpressionEvaluator
static SelectorCardinalityMap* gSelectorCardinality = NULL;


static void
AddSelector (SEL selector, NSInteger cardinality, BOOL acceptsVariableArgs, ...)
{
	NSMethodSignature* sig = [BXPGFunctionExpressionEvaluator methodSignatureForSelector: selector];
	if (sig)
	{
		ArgumentCardinalityMap* argMap = NULL;
		
		va_list ap;
		NSUInteger count = [sig numberOfArguments] - 2;
		if (0 < count)
		{
			argMap = new ArgumentCardinalityMap ();
			va_start (ap, acceptsVariableArgs);
			for (NSUInteger i = 0; i < count; i++)
			{
				NSInteger cardinality = va_arg (ap, NSInteger);		
				(* argMap) [i] = cardinality;
			}
			va_end (ap);
		}
		
		struct bx_function_cardinality_st function = {cardinality, argMap, acceptsVariableArgs};
		(* gSelectorCardinality)[selector] = function;
	}
}

+ (void) initialize
{
	static BOOL tooLate = NO;
	if (! tooLate)
	{
		tooLate = YES;
		
		gSelectorCardinality = new SelectorCardinalityMap ();
		AddSelector (@selector (sum:),				0, YES, 0);
		AddSelector (@selector (count:),			0, YES, 0);
		AddSelector (@selector (min:), 				0, YES, 0);
		AddSelector (@selector (max:), 				0, YES, 0);
		AddSelector (@selector (average:), 			0, YES, 0);
		AddSelector (@selector (median:), 			0, YES, 0);
		AddSelector (@selector (mode:), 			1, YES, 0);
		AddSelector (@selector (stddev:), 			0, YES, 0);
		AddSelector (@selector (add:to:), 			0, NO, 	0, 0);
		AddSelector (@selector (from:subtract:), 	0, NO, 	0, 0);
		AddSelector (@selector (multiply:by:), 		0, NO, 	0, 0);
		AddSelector (@selector (divide:by:), 		0, NO, 	0, 0);
		AddSelector (@selector (modulus:by:), 		0, NO, 	0, 0);
		AddSelector (@selector (sqrt:), 			0, NO, 	0);
		AddSelector (@selector (log:), 				0, NO, 	0);
		AddSelector (@selector (ln:), 				0, NO, 	0);
		AddSelector (@selector (raise:toPower:), 	0, NO, 	0, 0);
		AddSelector (@selector (exp:), 				0, NO, 	0);
		AddSelector (@selector (floor:),			0, NO,	0);
		AddSelector (@selector (ceiling:), 			0, NO, 	0);
		AddSelector (@selector (abs:), 				0, NO, 	0);
		AddSelector (@selector (trunc:), 			0, NO, 	0);
		//What do we do with this? @selector (castObject:toType:)]
		AddSelector (@selector (random), 			0, NO);
		//What do we do with this? @selector (randomn:)]
		AddSelector (@selector (now), 				0, NO);
	}
}


+ (BXPGExpressionValueType *) valueTypeForExpression: (NSExpression *) expression visitor: (id <BXPGPredicateVisitor>) visitor
{
	BXPGExpressionValueType* retval = nil;
	NSString* functionName = [expression function];
	SEL selector = NSSelectorFromString (functionName);
	SelectorCardinalityMap::iterator it = gSelectorCardinality->find (selector);
	NSMethodSignature* sig = [self methodSignatureForSelector: selector];
	
	//See if we can handle the function call.
	if (sig && gSelectorCardinality->end () != it)
	{
		struct bx_function_cardinality_st* function = &(it->second);
		NSArray* arguments = [expression arguments];
		NSUInteger argumentCount = [arguments count];
		BOOL varargs = function->fc_variable_argument_count;
		NSMutableArray* argumentValueTypes = [NSMutableArray arrayWithCapacity: argumentCount];
		
		if ((varargs && 0 < argumentCount) ||
			(!varargs && function->fc_arguments->size () == argumentCount))
		{
			NSInteger i = 0;
			BXEnumerate (currentExpression, e, [arguments objectEnumerator])
			{
				BXPGExpressionValueType* valueType = [currentExpression BXPGVisitExpression: visitor];
				if (! valueType)
					goto end;
				
				if ([valueType arrayCardinality] != function->argumentCardinality (i))
					goto end;
				
				[argumentValueTypes addObject: valueType];
				i++;
			}
			retval = [BXPGPredefinedFunctionExpressionValueType 
					  typeWithFunctionName: functionName arguments: argumentValueTypes 
					  cardinality: function->fc_retval_cardinality];
		}
	}
end:
	return retval;
}


+ (NSString *) evaluateExpression: (BXPGPredefinedFunctionExpressionValueType *) valueType 
						  visitor: (id <BXPGExpressionHandler>) visitor
{
	NSString* functionName = [valueType value];
	SEL selector = NSSelectorFromString (functionName);
	SelectorCardinalityMap::iterator it = gSelectorCardinality->find (selector);
	struct bx_function_cardinality_st* function = &(it->second);
	
	NSMethodSignature* sig = [self methodSignatureForSelector: selector];
	NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
	[invocation setSelector: selector];
	[invocation setTarget: self];
	
	if (function->fc_variable_argument_count)
	{
		NSArray* arguments = [valueType arguments];
		arguments = (id) [[arguments PGTSCollect] expressionSQL: visitor];
		[invocation setArgument: &arguments atIndex: 2];
	}
	else if (0 < function->fc_arguments)
	{
		NSArray* arguments = [valueType arguments]; 
		for (NSUInteger i = 0, count = [arguments count]; i < count; i++)
		{
			BXPGExpressionValueType* expressionValue = [arguments objectAtIndex: i];
			NSString* expressionSQL = [expressionValue expressionSQL: visitor];
			[invocation setArgument: &expressionSQL atIndex: i + 2];
		}
	}
	
	[invocation invoke];
	NSString* retval = nil;
	[invocation getReturnValue: &retval];
	return retval;
}

+ (NSString *) sum: (NSArray *) subExpressions
{
	NSString* retval = [subExpressions componentsJoinedByString: @" + "];
	retval = [NSString stringWithFormat: @"(%@)", retval];
	return retval;
}

+ (NSString *) count: (NSString *) value
{
	NSString* retval = [NSString stringWithFormat: @"array_upper (%@, 1)", value];
	return retval;
}

#if 0
+ (id) min: (id) fp8
{
}

+ (id) max: (id) fp8
{
}

+ (id) average: (id) fp8
{
}

+ (id) median: (id) fp8
{
}

+ (id) mode: (id) fp8
{
}

+ (id) stddev: (id) fp8
{
}
#endif

+ (NSString *) add: (NSString *) lval to: (NSString *) rval
{
	NSString* retval = [NSString stringWithFormat: @"(%@ + %@)", lval, rval];
	return retval;
}

+ (NSString *) from: (NSString *) lval subtract: (NSString *) rval
{
	NSString* retval = [NSString stringWithFormat: @"(%@ - %@)", lval, rval];
	return retval;
}

+ (NSString *) multiply: (NSString *) lval by: (NSString *) rval
{
	NSString* retval = [NSString stringWithFormat: @"(%@ * %@)", lval, rval];
	return retval;
}

+ (NSString *) divide: (NSString *) lval by: (NSString *) rval
{
	NSString* retval = [NSString stringWithFormat: @"(%@ / %@)", lval, rval];
	return retval;
}

+ (NSString *) modulus: (NSString *) lval by: (NSString *) rval
{
	NSString* retval = [NSString stringWithFormat: @"(%@ % %@)", lval, rval];
	return retval;
}

+ (NSString *) sqrt: (NSString *) value
{
	NSString* retval = [NSString stringWithFormat: @"sqrt (%@)", value];
	return retval;
}

+ (NSString *) log: (NSString *) value
{
	NSString* retval = [NSString stringWithFormat: @"log (%@)", value];
	return retval;
}

+ (NSString *) ln: (NSString *) value
{
	NSString* retval = [NSString stringWithFormat: @"ln (%@)", value];
	return retval;
}

+ (NSString *) raise: (NSString *) lval toPower: (NSString *) rval
{
	NSString* retval = [NSString stringWithFormat: @"(%@ ^ %@)", lval, rval];
	return retval;
}

+ (NSString *) exp: (NSString *) value
{
	NSString* retval = [NSString stringWithFormat: @"exp (%@)", value];
	return retval;
}

+ (NSString *) trunc: (NSString *) value
{
	NSString* retval = [NSString stringWithFormat: @"trunc (%@)", value];
	return retval;
}

//This isn't documented.
+ (NSString *) floor: (NSString *) value
{
	return [self trunc: value];
}

+ (NSString *) ceiling: (NSString *) value
{
	NSString* retval = [NSString stringWithFormat: @"ceiling (%@)", value];
	return retval;
}

+ (NSString *) abs: (NSString *) value
{
	NSString* retval = [NSString stringWithFormat: @"abs (%@)", value];
	return retval;
}

#if 0
+ (id) castObject: (id) fp8 toType: (id) fp12
{
}

+ (id) random
{
}

+ (id) randomn: (id) fp8 //FIXME: method name?
{
}
#endif

+ (NSString *) now
{
	NSString* retval = @"statement_timestamp ()";
	return retval;
}
@end
