//
// NSExpression+PGTSAdditions.m
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

#import <PGTS/PGTS.h>
#import <PGTS/PGTSFunctions.h>

#import "NSExpression+PGTSAdditions.h"
#import "PGTSTigerConstants.h"


@interface NSObject (PGTSTigerAdditions)
- (id) PGTSConstantExpressionValue: (NSMutableDictionary *) context;
@end


static NSString*
AddParameter (id parameter, NSMutableDictionary* context)
{
    NSCAssert (nil != context, @"Expected context not to be nil");
    NSString* rval = nil;
	if (nil == parameter)
		parameter = [NSNull null];
	
	if (YES == [[context objectForKey: kPGTSExpressionParametersVerbatimKey] boolValue])
	{
		PGTSConnection* connection = [context objectForKey: kPGTSConnectionKey];
		rval = [NSString stringWithFormat: @"'%@'", [parameter PGTSEscapedObjectParameter: connection]];
	}
	else
	{
		//First increment the parameter index. We start from zero, since indexing in
		//NSArray is zero-based. The kPGTSParameterIndexKey will have the total count
		//of parameters, however.
		NSNumber* indexObject = [context objectForKey: kPGTSParameterIndexKey];
		if (nil == indexObject)
		{
			indexObject = [NSNumber numberWithInt: 0];
		}
		int index = [indexObject intValue];
		[context setObject: [NSNumber numberWithInt: index + 1] forKey: kPGTSParameterIndexKey];
		
		NSMutableArray* parameters = [context objectForKey: kPGTSParametersKey];
		if (nil == parameters)
		{
			parameters = [NSMutableArray array];
			[context setObject: parameters forKey: kPGTSParametersKey];
		}
		[parameters insertObject: parameter atIndex: index];
		
		//Return the index used in the query
		int count = index + 1;
		NSCAssert4 ([parameters count] == count, @"Expected count to be %d, was %d.\n\tparameter:\t%@ \n\tcontext:\t%@", 
					[parameters count], count, parameter, context);
		rval = [NSString stringWithFormat: @"$%d", count];
	}
	return rval;
}


static NSString*
EscapedKeyPath (NSString* keyPath, PGTSConnection* connection)
{
	NSMutableString* retval = [NSMutableString string];
	TSEnumerate (currentComponent, e, [[keyPath componentsSeparatedByString: @"."] objectEnumerator])
	{
		[retval appendString: [currentComponent PGTSEscapedName: connection]];
		[retval appendString: @"."];
	}
	unsigned int length = [retval length];
	if (0 < length)
	{
		NSRange lastCharacterRange = NSMakeRange (length - 1, 1);
		[retval deleteCharactersInRange: lastCharacterRange];
	}
	return retval;
}


@implementation NSExpression (PGTSAdditions)

+ (NSDictionary *) PGTSAggregateNameConversionDictionary
{
    static BOOL tooLate = NO;
    static NSMutableDictionary* conversionDictionary = nil;
    if (NO == tooLate)
    {
        conversionDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
            @"sum", @"sum",
            @"avg", @"avg",
            @"count", @"count",
            @"min", @"min",
            @"max", @"max",
            nil];
    }
    return conversionDictionary;
}

+ (NSDictionary *) PGTSFunctionNameConversionDictionary
{
    static BOOL tooLate = NO;
    static NSMutableDictionary* conversionDictionary = nil;
    if (NO == tooLate)
    {
        conversionDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
            @"char_length",     @"length",
            @"lower",           @"lowercaseString", 
            @"upper",           @"uppercaseString",
            nil];
    }
    return conversionDictionary;    
}

- (id) PGTSValueWithObject: (id) anObject context: (NSMutableDictionary *) context
{
    id rval = nil;
    switch ([self expressionType])
    {
        case NSConstantValueExpressionType:
        {
            id constantValue = [self constantValue];
            if (YES == [constantValue respondsToSelector: @selector (PGTSConstantExpressionValue:)])
            {
                rval = [constantValue PGTSConstantExpressionValue: context];
                break;
            }
            //Otherwise continue
        }
            
        case NSEvaluatedObjectExpressionType:
        case NSVariableExpressionType:
		{
            //default behaviour unless the expression evaluates into a key path expression
			id evaluated = [self expressionValueWithObject: anObject context: context];
			if ([evaluated isKindOfClass: [NSExpression class]] && [evaluated expressionType] == NSKeyPathExpressionType)
			{
                //Simple dividing into components for now
				PGTSConnection* connection = [context objectForKey: kPGTSConnectionKey];
				rval = EscapedKeyPath ([evaluated keyPath], connection);
                break;
			}
			else
			{
				rval = AddParameter (evaluated, context);
				break;
			}
		}
            
        case NSKeyPathExpressionType:
        {
			PGTSConnection* connection = [context objectForKey: kPGTSConnectionKey];
			rval = EscapedKeyPath ([self keyPath], connection);
            break;
            
            //FIXME: this is for functions, which we don't support.
#if 0
            NSString* format = @"%@ (%@)";
            
            //The first object is always the parameter
            NSEnumerator* e = [components objectEnumerator];
            
            NSString* parameter = [[anObject keyPath] PGTSEscapedString: connection];
            NSDictionary* conversionDict = [[self class] PGTSFunctionNameConversionDictionary];
            TSEnumerate (currentFunction, e, [components objectEnumerator])
            {
                NSString* pgFunctionName = [conversionDict objectForKey: currentFunction];
                if (nil != pgFunctionName)
                    currentFunction = pgFunctionName;
                
                parameter = [NSString stringWithFormat: format, currentFunction, parameter];
            }
            
            rval = parameter;
            break;
#endif
        }
            
        case NSFunctionExpressionType:
            //Convert to an aggregate function usable with PostgreSQL
            //Throw an exception if unknown
            rval = [NSString stringWithFormat: @"%@ (%@)",
                [[[self class] PGTSAggregateNameConversionDictionary] valueForKey: [self function]],
                AddParameter ([[self operand] PGTSValueWithObject: anObject context: context], context)];
            break;
            
        default:
            //FIXME: throw an exception
            break;
    }
    return rval;
}

- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
	id objectValue = nil;
	switch ([self expressionType])
	{
		case NSConstantValueExpressionType:
			objectValue = [self constantValue];
			break;
			
		case NSEvaluatedObjectExpressionType:
			objectValue = [self keyPath];
			break;
			
		case NSVariableExpressionType:
		case NSKeyPathExpressionType:
		case NSFunctionExpressionType:
		default:
			break;
	}
	
	return [objectValue PGTSParameterLength: length connection: connection];
}

@end
