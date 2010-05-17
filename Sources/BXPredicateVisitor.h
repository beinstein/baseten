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


#import <Foundation/Foundation.h>
#import <BaseTen/BaseTen.h>
#import <BaseTen/PGTSConnection.h>
#import <BaseTen/BXPGVisitor.h>
#import <BaseTen/BXPGQueryBuilder.h>


@class BXPGExpressionVisitor;
@class BXPGConstantParameterMapper;
@class BXPGExpressionValueType;
@class BXPGPredefinedFunctionExpressionValueType;


@protocol BXPGPredicateVisitor <NSObject>
- (void) visitUnknownPredicate: (NSPredicate *) predicate;
- (void) visitTruePredicate: (NSPredicate *) predicate;
- (void) visitFalsePredicate: (NSPredicate *) predicate;
- (void) visitAndPredicate: (NSCompoundPredicate *) predicate;
- (void) visitOrPredicate: (NSCompoundPredicate *) predicate;
- (void) visitNotPredicate: (NSCompoundPredicate *) predicate;
- (void) visitComparisonPredicate: (NSComparisonPredicate *) predicate;

- (BXPGExpressionValueType *) visitConstantValueExpression: (NSExpression *) expression;
- (BXPGExpressionValueType *) visitEvaluatedObjectExpression: (NSExpression *) expression;
- (BXPGExpressionValueType *) visitVariableExpression: (NSExpression *) expression;
- (BXPGExpressionValueType *) visitKeyPathExpression: (NSExpression *) expression;
- (BXPGExpressionValueType *) visitFunctionExpression: (NSExpression *) expression;
- (BXPGExpressionValueType *) visitAggregateExpression: (NSExpression *) expression;
- (BXPGExpressionValueType *) visitSubqueryExpression: (NSExpression *) expression;
- (BXPGExpressionValueType *) visitUnionSetExpression: (NSExpression *) expression;
- (BXPGExpressionValueType *) visitIntersectSetExpression: (NSExpression *) expression;
- (BXPGExpressionValueType *) visitMinusSetExpression: (NSExpression *) expression;
- (BXPGExpressionValueType *) visitBlockExpression: (NSExpression *) expression;
- (BXPGExpressionValueType *) visitUnknownExpression: (NSExpression *) expression;
@end


@protocol BXPGExpressionHandler <NSObject>
- (NSString *) handlePGConstantExpressionValue: (id) value;
- (NSString *) handlePGKeyPathExpressionValue: (NSArray *) keyPath;
- (NSString *) handlePGAggregateExpressionValue: (NSArray *) valueTree;
- (NSString *) handlePGPredefinedFunctionExpressionValue: (BXPGPredefinedFunctionExpressionValueType *) valueType;
@end


struct bx_predicate_st 
{
	NSString* p_where_clause;
	BOOL p_results_require_filtering;
};


@interface BXPGPredicateVisitor : BXPGVisitor
{
	BXDatabaseObject* mObject;
	BXEntityDescription* mEntity;
	NSMutableDictionary* mContext; //For evaluating expressions.
	BXPGExpressionVisitor* mExpressionVisitor;
	BXPGConstantParameterMapper* mParameterMapper;
	Class mQueryHandler;
	
	NSMutableArray* mStack; //Array of NSMutableArrays.
	NSInteger mStackIdx;
	BOOL mCollectAllState;
	BOOL mWillCollectAll;
}

- (void) setEntity: (BXEntityDescription *) entity;
- (void) setObject: (BXDatabaseObject *) anObject;
- (void) setConnection: (PGTSConnection *) connection;
- (void) setQueryType: (enum BXPGQueryType) queryType;

- (void) addFrame;
- (void) removeFrame;
- (NSMutableArray *) currentFrame;
- (void) addToFrame: (id) value;

- (struct bx_predicate_st) beginWithPredicate: (NSPredicate *) predicate;

- (BXPGConstantParameterMapper *) constantParameterMapper;
- (BXPGExpressionVisitor *) expressionVisitor;
@end


@interface BXPGPredicateVisitor (BXPGPredicateVisitor) <BXPGPredicateVisitor>
@end


@interface BXPGPredicateVisitor (BXPGExpressionHandler) <BXPGExpressionHandler>
@end
