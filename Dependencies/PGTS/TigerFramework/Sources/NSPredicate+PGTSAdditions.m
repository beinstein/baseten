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
#import "PGTSTigerConstants.h"

#import <PGTS/PGTSFunctions.h>
#import <PGTS/PGTSConstants.h>

@implementation NSPredicate (PGTSAdditions)

- (NSString *) PGTSWhereClauseWithContext: (NSMutableDictionary *) context
{
    NSString* rval = nil;
    Class tpClass = NSClassFromString (@"NSTruePredicate");
    Class fpClass = NSClassFromString (@"NSFalsePredicate");
    if (nil != tpClass && [self isKindOfClass: tpClass])
        rval = @"(true)";
    else if (nil != fpClass && [self isKindOfClass: fpClass])
        rval = @"(false)";
    //Otherwise return nil since we override this method anyway
    return rval;
}
@end

@implementation NSCompoundPredicate (PGTSAdditions)
- (NSString *) PGTSWhereClauseWithContext: (NSMutableDictionary *) context
{
    NSAssert (nil != [context objectForKey: kPGTSConnectionKey], @"Did you remember to set connection to kPGTSConnectionKey in context?");
    NSString* rval = nil;
    NSArray* subpredicates = [self subpredicates];
    NSMutableArray* parts = [NSMutableArray arrayWithCapacity: [subpredicates count]];
    TSEnumerate (currentPredicate, e, [subpredicates objectEnumerator])
        [parts addObject: [currentPredicate PGTSWhereClauseWithContext: context]];
    
    NSString* glue = nil;
    NSCompoundPredicateType type = [self compoundPredicateType];
    if (NSNotPredicateType == type)
        rval = [NSString stringWithFormat: @"(NOT (%@))", [parts objectAtIndex: 0]];
    else
    {
        switch (type)
        {
            case NSAndPredicateType:
                glue = @") AND (";
                break;
            case NSOrPredicateType:
                glue = @") OR (";
                break;
            default:
                //FIXME: exception
                break;
        }
        rval = [NSString stringWithFormat: @"(%@)", [parts componentsJoinedByString: glue]];
    }
    return rval;
}
@end

@implementation NSComparisonPredicate (PGTSAdditions)
- (NSString *) PGTSWhereClauseWithContext: (NSMutableDictionary *) context
{
    NSString* rval = [NSString stringWithFormat: @"(%@) %@ (%@)",
        [[self leftExpression] PGTSValueWithObject: nil context: context], 
        [self PGTSOperator], 
        [[self rightExpression] PGTSValueWithObject: nil context: context]];
    return rval;
}

- (NSString *) PGTSOperator
{
    NSString* operator = nil;
    NSPredicateOperatorType type = [self predicateOperatorType];
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
            
        //FIXME: These might need custom comparison functions 
        //CREATE OPERATOR might be useful for this
        case NSInPredicateOperatorType:
        case NSBeginsWithPredicateOperatorType:
        case NSEndsWithPredicateOperatorType:
        case NSCustomSelectorPredicateOperatorType:
        default:
            [[NSException exceptionWithName: kPGTSUnsupportedPredicateOperatorTypeException
                                     reason: nil userInfo: nil] raise];
    }
    
    switch (type)
    {
        case NSMatchesPredicateOperatorType:
        case NSLikePredicateOperatorType:
        {
            unsigned int options = [self options];
            if (NSCaseInsensitivePredicateOption & options)
                operator = [operator stringByAppendingString: @"*"];
            if (NSDiacriticInsensitivePredicateOption & options)
                ; //FIXME: exception
            break;
        }
        default:
            break;
    }
    
    NSComparisonPredicateModifier modifier = [self comparisonPredicateModifier];
    if (NSDirectPredicateModifier != modifier)
    {
        if (NSInPredicateOperatorType == type)
            ; //FIXME: exception
        switch (modifier)
        {
            case NSAllPredicateModifier:
                operator = [operator stringByAppendingString: @" ALL"];
                break;
            case NSAnyPredicateModifier:
                operator = [operator stringByAppendingString: @" ANY"];
                break;
            default:
                break;
        }
    }
    
    return operator;
}
@end
