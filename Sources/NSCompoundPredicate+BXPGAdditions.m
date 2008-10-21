//
// NSCompoundPredicate+BXPGAdditions.m
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
#import "NSCompoundPredicate+BXPGAdditions.h"
#import "PGTSFunctions.h"
#import "BXLogger.h"


@implementation NSCompoundPredicate (BXPGAdditions)
- (void) BXPGVisit: (id <BXPGPredicateVisitor>) visitor
{
	switch ([self compoundPredicateType])
	{
		case NSNotPredicateType:
			[visitor visitNotPredicate: self];
			break;
			
		case NSAndPredicateType:
			[visitor visitAndPredicate: self];
			break;
			
		case NSOrPredicateType:
			[visitor visitOrPredicate: self];
			break;
			
		default:
			[visitor visitUnknownPredicate: self];
			break;
	}
}

//FIXME: This is only used with SQL schema generation. It should be removed in a future revision.
- (NSString *) PGTSExpressionWithObject: (id) anObject context: (NSMutableDictionary *) context
{
    BXAssertValueReturn (nil != [context objectForKey: kPGTSConnectionKey], nil, 
						 @"Did you remember to set connection to %@ in context?", kPGTSConnectionKey);
    NSString* retval = nil;
    NSArray* subpredicates = [self subpredicates];
    NSMutableArray* parts = [NSMutableArray arrayWithCapacity: [subpredicates count]];
    TSEnumerate (currentPredicate, e, [subpredicates objectEnumerator])
	{
		NSString* expression = [currentPredicate PGTSExpressionWithObject: anObject context: context];
		if (expression)
			[parts addObject: expression];
	}
    
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
