//
// BXPredicateVisitor.h
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

#import <Foundation/Foundation.h>
#import <BaseTen/BaseTen.h>


@protocol BXPredicateVisitor <NSObject>
- (void) visitUnknownPredicate: (NSPredicate *) predicate;
- (void) visitTruePredicate: (NSPredicate *) predicate;
- (void) visitFalsePredicate: (NSPredicate *) predicate;
- (void) visitAndPredicate: (NSCompoundPredicate *) predicate;
- (void) visitOrPredicate: (NSCompoundPredicate *) predicate;
- (void) visitNotPredicate: (NSCompoundPredicate *) predicate;
- (void) visitComparisonPredicate: (NSComparisonPredicate *) predicate;

- (void) visitConstantValueExpression: (NSExpression *) expression;
- (void) visitEvaluatedObjectExpression: (NSExpression *) expression;
- (void) visitVariableExpression: (NSExpression *) expression;
- (void) visitKeyPathExpression: (NSExpression *) expression;
- (void) visitFunctionExpression: (NSExpression *) expression;
- (void) visitAggregateExpression: (NSExpression *) expression;
- (void) visitSubqueryExpression: (NSExpression *) expression;
- (void) visitUnionSetExpression: (NSExpression *) expression;
- (void) visitIntersectSetExpression: (NSExpression *) expression;
- (void) visitMinusSetExpression: (NSExpression *) expression;
- (void) visitUnknownExpression: (NSExpression *) expression;
@end


@interface BXPredicateVisitor : NSObject
{
	BXDatabaseObject* mObject;
	NSMutableDictionary* mContext; //For evaluating expressions.
	
	NSMutableArray* mStack; //Array of NSMutableArrays.
	NSInteger mStackIdx;
	BOOL mCollectAllState;
}
- (void) addFrame;
- (void) removeFrame;
- (NSMutableArray *) currentFrame;

- (NSString *) beginWithPredicate: (NSPredicate *) predicate;
@end


@interface BXPredicateVisitor (BXPredicateVisitor) <BXPredicateVisitor>
@end

#endif