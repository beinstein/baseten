//
// NSPredicate+PGTSAdditions.m
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
#import "NSExpression+PGTSAdditions.h"
#import "BXLogger.h"

#import "PGTSFunctions.h"
#import "PGTSConstants.h"


#if defined (PREDICATE_VISITOR)
@implementation NSPredicate (BXAdditions)
- (void) BXVisit: (id <BXPredicateVisitor>) visitor
{
    Class tpClass = NSClassFromString (@"NSTruePredicate");
    Class fpClass = NSClassFromString (@"NSFalsePredicate");
    if (nil != tpClass && [self isKindOfClass: tpClass])
		[visitor visitTruePredicate: self];
    else if (nil != fpClass && [self isKindOfClass: fpClass])
		[visitor visitFalsePredicate: self];
	else
		[visitor visitUnknownPredicate: self];
}
@end
#else
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
#endif