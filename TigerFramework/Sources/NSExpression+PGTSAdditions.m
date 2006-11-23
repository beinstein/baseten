//
// NSExpression+PGTSAdditions.m
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

#import <PGTS/PGTSConstants.h>

#import "NSExpression+PGTSAdditions.h"
#import "PGTSTigerConstants.h"


@interface NSObject (PGTSAdditions)
- (id) PGTSConstantExpressionValue: (NSMutableDictionary *) context;
@end


static NSString*
AddParameter (id parameter, NSMutableDictionary* context)
{
    NSCAssert (nil != context, @"Expected context not to be nil");
    
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
    return [NSString stringWithFormat: @"$%d", count];
}


@implementation NSExpression (PGTSAdditions)

+ (NSMutableDictionary *) PGTSFunctionNameConversionDictionary
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
            //default behavior
            rval = AddParameter ([self expressionValueWithObject: anObject context: context], context);
            break;
            
        case NSKeyPathExpressionType:
        {
            //database.table.field
            //Simple dividing into components for now
            NSArray* components = [[[self keyPath] componentsSeparatedByString: @"."] valueForKey: @"PGTSQuotedString"];
            rval = [components componentsJoinedByString: @"."];
            break;
        }   
        case NSFunctionExpressionType:
            //Convert to a function usable with PostgreSQL
            //Throw an exception if unknown
            rval = [NSString stringWithFormat: @"%@ (%@)",
                [[[self class] PGTSFunctionNameConversionDictionary] valueForKey: [self function]],
                AddParameter ([[self operand] PGTSValueWithObject: anObject context: context], context)];
            break;
            
        default:
            //FIXME: throw an exception
            break;
    }
    return rval;
}

@end
