//
// BXPredicateVisitor.m
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

#import "BXPredicateVisitor.h"
#import "PGTSAdditions.h"
#import "BXDatabaseAdditions.h"
#import "NSPredicate+PGTSAdditions.h"
#import "NSExpression+PGTSAdditions.h"
#import "BXKeyPathParser.h"
#import "BXPGSQLFunction.h"
#import "PGTSFoundationObjects.h"
#import "BXPGExpressionVisitor.h"
#import "BXPGConstantParameterMapper.h"
#import "PGTSConstants.h"
#import "PGTSHOM.h"
#import "BXPGFunctionExpressionEvaluator.h"
#import "BXPGKeypathExpressionValueType.h"
#import "BXPGAggregateExpressionValueType.h"
#import "BXPGFromItem.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXPGQueryHandler.h"
#import "BXPGIdentityExpressionValueType.h"


enum ComparisonType
{
	kComparisonTypeUndefined = 0,
	kComparisonTypeAscendingCardinality,
	kComparisonTypeDescendingCardinality,
	kComparisonTypeBothScalar,
	kComparisonTypeBothCollections
};


struct RelationshipContext
{
	BXDatabaseObject* rc_object;
	BXPGConstantParameterMapper* rc_mapper;
	NSString* rc_fi_alias;
	NSMutableArray* rc_components;
};


static enum ComparisonType
ScalarComparisonType (BXPGExpressionValueType* lval, BXPGExpressionValueType* rval)
{
	enum ComparisonType retval = kComparisonTypeUndefined;
	if (rval && lval)
	{
		NSInteger leftCardinality = [lval arrayCardinality];
		NSInteger rightCardinality = [rval arrayCardinality];

		if (0 == leftCardinality && 1 == rightCardinality)
			retval = kComparisonTypeAscendingCardinality;
		else if (1 == leftCardinality && 0 == rightCardinality)
			retval = kComparisonTypeDescendingCardinality;
		else if (0 == leftCardinality && 0 == rightCardinality)
			retval = kComparisonTypeBothScalar;
	}
	return (enum ComparisonType) retval;
}


static enum ComparisonType
ComparisonType (NSComparisonPredicate* predicate, BXPGExpressionValueType* lval, BXPGExpressionValueType* rval)
{
	enum ComparisonType retval = kComparisonTypeUndefined;
	if (rval && lval)
	{
		NSInteger leftCardinality = [lval arrayCardinality];
		NSInteger rightCardinality = [rval arrayCardinality];
		if (leftCardinality == rightCardinality)
		{
			if (0 == leftCardinality)
				retval = kComparisonTypeBothScalar;
			else
				retval = kComparisonTypeBothCollections;
		}
		else if (leftCardinality == 1 + rightCardinality)
		{
			retval = kComparisonTypeAscendingCardinality;
		}
	}
	return retval;
}


#define Comparison( LVAL, OP, RVAL, MODIFIER ) ([self addToFrame: Comparison1( LVAL, OP, RVAL, MODIFIER )])


static NSString*
Comparison1 (NSString* lval, NSString* operatorString, NSString* rval, NSComparisonPredicateModifier modifier)
{
	NSString* format = @"%@ %@ %@";
	if (NSDirectPredicateModifier != modifier)
		format = @"%@ %@ (%@)";
	NSString* retval = [NSString stringWithFormat: format, lval, operatorString, rval];
	return retval;
}


static NSString*
AppendModifier (NSString* operatorString, NSComparisonPredicateModifier modifier)
{
	switch (modifier) 
	{			
		case NSAllPredicateModifier:
			operatorString = [operatorString stringByAppendingString: @" ALL"];
			break;
			
		case NSAnyPredicateModifier:
			operatorString = [operatorString stringByAppendingString: @" ANY"];
			break;
			
		case NSDirectPredicateModifier:
		default:
			break;			
	}
	return operatorString;
}


@implementation BXPGPredicateVisitor
- (id) init
{
	if ((self = [super init]))
	{
		mStackIdx = -1;
		mCollectAllState = YES;
		mExpressionVisitor = [[BXPGExpressionVisitor alloc] init];
		mParameterMapper = [[BXPGConstantParameterMapper alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[mExpressionVisitor release];
	[mStack release];
	[mContext release];
	[mObject release];
	[mParameterMapper release];
	[super dealloc];
}

- (void) collectAll
{
	[mQueryHandler willCollectAllNone];
	NSString* collectionExpression = (mCollectAllState ? @"(true)" : @"(false)");
	[[self currentFrame] addObject: collectionExpression];
	[mAliasMapper resetCurrent];
	mWillCollectAll = YES;
}

- (void) collectNone
{
	[mQueryHandler willCollectAllNone];
	NSString* collectionExpression = (mCollectAllState ? @"(false)" : @"(true)");
	[[self currentFrame] addObject: collectionExpression];
	[mAliasMapper resetCurrent];
	mWillCollectAll = YES;
}

- (void) addToFrame: (id) value
{
	[[self currentFrame] addObject: value];
	[mAliasMapper accept];
}

- (void) setRelationAliasMapper: (BXPGRelationAliasMapper *) aMapper
{
	[super setRelationAliasMapper: aMapper];
	[mExpressionVisitor setRelationAliasMapper: aMapper];
}

- (BXPGConstantParameterMapper *) constantParameterMapper
{
	return mParameterMapper;
}

- (BXPGExpressionVisitor *) expressionVisitor
{
	return mExpressionVisitor;
}

- (void) addFrame
{
	if (! mStack)
		mStack = [[NSMutableArray alloc] init];
	
	NSInteger count = [mStack count];
	mStackIdx++;
	if (count <= mStackIdx)
		[mStack addObject: [NSMutableArray array]];
	else
		[[mStack objectAtIndex: mStackIdx] removeAllObjects];
}

- (void) removeFrame
{
	[[mStack objectAtIndex: mStackIdx] removeAllObjects];
	if (-1 < mStackIdx)
		mStackIdx--;
}

- (NSMutableArray *) currentFrame
{
	if (! mStack || mStackIdx < 0)
		[self addFrame];
	return [mStack objectAtIndex: mStackIdx];
}

- (void) setQueryType: (enum BXPGQueryType) queryType
{
	switch (queryType) 
	{
		case kBXPGQueryTypeSelect:
			mQueryHandler = [BXPGSelectQueryHandler class];
			break;
			
		case kBXPGQueryTypeUpdate:
		case kBXPGQueryTypeDelete:
			mQueryHandler = [BXPGUpdateDeleteQueryHandler class];
			break;
			
		default:
			mQueryHandler = [BXPGQueryHandler class];
			break;
	}
}

- (void) setObject: (BXDatabaseObject *) anObject
{
	if (anObject != mObject)
	{
		[mObject release];
		mObject = [anObject retain];
	}
}

- (void) setConnection: (PGTSConnection *) connection
{
	[mExpressionVisitor setConnection: connection];
}

- (void) setEntity: (BXEntityDescription *) entity
{
	if (entity != mEntity)
	{
		[mEntity release];
		mEntity = [entity retain];
	}
}

- (struct bx_predicate_st) beginWithPredicate: (NSPredicate *) predicate
{
	struct bx_predicate_st retval = {};
	if (predicate)
	{
		mWillCollectAll = NO;
		
		if (mContext)
			[mContext removeAllObjects];
		else
			mContext = [[NSMutableDictionary alloc] init];
		
		[mContext setObject: [mExpressionVisitor connection] forKey: kPGTSConnectionKey];
		[mContext setObject: [[mAliasMapper primaryRelation] entity] forKey: kBXEntityDescriptionKey];
				
		@try 
		{
			[self addFrame];
			[mQueryHandler beginQuerySpecific: self predicate: predicate];
			[predicate BXPGVisit: self];
			[mQueryHandler endQuerySpecific: self predicate: predicate];
			retval.p_where_clause = [[self currentFrame] lastObject];
			retval.p_results_require_filtering = mWillCollectAll;
			[self removeFrame];
			[mContext removeAllObjects];
			
			if (! [retval.p_where_clause length])
				retval.p_where_clause = @"(true)";
		}
		@catch (BXPGExceptionCollectAllNoneNotAllowed* e)
		{
			retval.p_where_clause = nil;
		}
	}
	else
	{
		retval.p_where_clause = @"(true)";
	}
	return retval;
}

//We call this 'glue' to differentiate from database joins.
- (void) glue: (NSCompoundPredicate *) predicate andOr: (NSString *) glue
{
	NSArray* subpredicates = [predicate subpredicates];
	if (0 < [subpredicates count])
	{
		[self addFrame];
		TSEnumerate (currentPredicate, e, [subpredicates objectEnumerator])
			[currentPredicate BXPGVisit: self];
	
		NSString* joined = [[self currentFrame] componentsJoinedByString: glue];
		[self removeFrame];
		[self addToFrame: [NSString stringWithFormat: @"(%@)", joined]];
	}
}

- (void) handleCustomPredicateComparison: (NSPredicate *) predicate 
									lval: (BXPGExpressionValueType *) lval 
									rval: (BXPGExpressionValueType *) rval
{
	//Here we could handle some custom selectors in a special way, 
	//like replace them with @@, @@@ etc.
	[self collectAll];
}

- (void) handleEqualityComparison: (NSComparisonPredicate *) predicate 
							 lval: (BXPGExpressionValueType *) rval 
							 rval: (BXPGExpressionValueType *) lval
{
	//Equality doesn't have options like case or diacritic insensitivity.
	//Choose the operator. We need to switch places to handle ANY and ALL since
	//NSExpressions are something like ANY x > y. This is done in parameter list.
	NSString* operatorString = nil;
	NSPredicateOperatorType operatorType = [predicate predicateOperatorType];
	switch (operatorType)
	{
		case NSEqualToPredicateOperatorType:
			operatorString = @"=";
			break;
		case NSNotEqualToPredicateOperatorType:
			operatorString = @"<>";
			break;
		default:
			break;
	}
	
	if (! operatorString)
		[self collectAll];
	else
	{
		NSComparisonPredicateModifier modifier = [predicate comparisonPredicateModifier];
		switch (ComparisonType (predicate, rval, lval)) //Flip again to get the correct result.
		{
			case kComparisonTypeAscendingCardinality:
				operatorString = AppendModifier (operatorString, modifier);
				//Fall through.
				
			case kComparisonTypeBothScalar:
			case kComparisonTypeBothCollections:
			{
				NSString* lSQL = [lval expressionSQL: self];
				NSString* rSQL = [rval expressionSQL: self];
				Comparison (lSQL, operatorString, rSQL, modifier);
				break;
			}
				
			default:
			{
				[self collectAll];
				break;
			}
		}
	}	
}

- (void) handleStringOperation: (NSComparisonPredicate *) predicate 
						  lval: (BXPGExpressionValueType *) lval
						  rval: (BXPGExpressionValueType *) rval
{
	//Don't switch argument places since ANY and ALL aren't allowed here.
	NSUInteger comparisonOptions = [predicate options];
	if (comparisonOptions & ~NSCaseInsensitivePredicateOption)
	{
		[self collectAll];
		goto end;
	}
	
	if (NSDirectPredicateModifier != [predicate comparisonPredicateModifier])
	{
		[self collectAll];
		goto end;
	}
	
	if (kComparisonTypeBothScalar != ScalarComparisonType (lval, rval))
	{
		[self collectAll];
		goto end;
	}
	
	NSString* lSQL = [lval expressionSQL: self];
	NSString* rSQL = [rval expressionSQL: self];

	//Choose the operator.
	NSString* operatorString = nil;
	NSPredicateOperatorType operatorType = [predicate predicateOperatorType];
	switch (operatorType)
	{
		case NSMatchesPredicateOperatorType:
			operatorString = @"~";
			break;
			
		case NSLikePredicateOperatorType:
			operatorString = @"~~";
			break;
			
		case NSBeginsWithPredicateOperatorType:
			rSQL = [NSString stringWithFormat: @"(regexp_replace (%@, '([%%_\\\\])', '\\\\\\1', 'g') || '%%')", rSQL];
			operatorString = @"~~";
			break;
			
		case NSEndsWithPredicateOperatorType:
			rSQL = [NSString stringWithFormat: @"('%%' || regexp_replace (%@, '([%%_\\\\])', '\\\\\\1', 'g'))", rSQL];
			operatorString = @"~~";
			break;
			
		case NSInPredicateOperatorType:
			rSQL = [NSString stringWithFormat: @"('%%' || regexp_replace (%@, '([%%_\\\\])', '\\\\\\1', 'g') || '%%')", rSQL];
			operatorString = @"~~";
			break;

		default:
			break;
	}
	
	if (! operatorString)
	{
		[self collectAll];
		goto end;
	}
	
	//Case insensitivity.
	if (comparisonOptions & NSCaseInsensitivePredicateOption)
		operatorString = [operatorString stringByAppendingString: @"*"];

	Comparison (lSQL, operatorString, rSQL, NSDirectPredicateModifier);

end: ;
}

- (void) handleBetweenComparison: (NSComparisonPredicate *) predicate 
							lval: (BXPGExpressionValueType *) rval
							rval: (BXPGExpressionValueType *) lval
{
	//Switch places in arguments, because we use our own comparison operator.
	if (lval && rval)
	{
		NSComparisonPredicateModifier modifier = [predicate comparisonPredicateModifier];
		NSString* operator = @"OPERATOR (\"baseten\".<<>>)";
		switch (modifier)
		{
			case NSAnyPredicateModifier:
			case NSAllPredicateModifier:
			{
				if (1 == [lval arrayCardinality] && 1 == [rval arrayCardinality])
				{
					NSString* lSQL = [lval expressionSQL: self];
					NSString* rSQL = [rval expressionSQL: self];
					operator = AppendModifier (operator, modifier);
					[self addToFrame: [NSString stringWithFormat: @"%@ %@ (%@)", lSQL, operator, rSQL]];
				}
				else
				{
					[self collectAll];
				}
				break;
			}
				
			case NSDirectPredicateModifier:
			{
				if (1 == [lval arrayCardinality] && 0 == [rval arrayCardinality])
				{
					NSString* lSQL = [lval expressionSQL: self];
					NSString* rSQL = [rval expressionSQL: self];
					[self addToFrame: [NSString stringWithFormat: @"%@ %@ %@", lSQL, operator, rSQL]];
				}
				else
				{
					[self collectAll];
				}
				break;
			}
				
			default:
				[self collectAll];
				break;
		}
	}
	else
	{
		[self collectAll];
	}
}

- (void) handleScalarComparison: (NSComparisonPredicate *) predicate 
						   lval: (BXPGExpressionValueType *) rval
						   rval: (BXPGExpressionValueType *) lval
{
	//Choose the operator. We need to switch places to handle ANY and ALL since
	//NSExpressions are something like ANY x > y. This is done in parameter list.
	NSString* operatorString = nil;
	NSPredicateOperatorType operatorType = [predicate predicateOperatorType];
	switch (operatorType)
	{
		case NSLessThanPredicateOperatorType:
			operatorString = @">";
			break;
		case NSLessThanOrEqualToPredicateOperatorType:
			operatorString = @">=";
			break;
		case NSGreaterThanPredicateOperatorType:
			operatorString = @"<";
			break;
		case NSGreaterThanOrEqualToPredicateOperatorType:
			operatorString = @"<=";
			break;
		default:
			break;
	}
	
	if (! operatorString)
		[self collectAll];
	else
	{
		NSComparisonPredicateModifier modifier = [predicate comparisonPredicateModifier];
		switch (ScalarComparisonType (lval, rval))
		{
			case kComparisonTypeAscendingCardinality:
				operatorString = AppendModifier (operatorString, modifier);
				//Fall through.

			case kComparisonTypeBothScalar:
			{
				NSString* lSQL = [lval expressionSQL: self];
				NSString* rSQL = [rval expressionSQL: self];
				Comparison (lSQL, operatorString, rSQL, modifier);
				break;
			}
				
			default:
			case kComparisonTypeUndefined:
			{
				[self collectAll];
				break;
			}
		}
	}	
}

- (void) handleContainsComparison: (NSComparisonPredicate *) predicate 
							 lval: (BXPGExpressionValueType *) rval
							 rval: (BXPGExpressionValueType *) lval
{
	//Switch argument places.
	//We don't currently allow expressions like "ANY {{1, 2}, {3}, {4}} CONTAINS 2".
	if (NSDirectPredicateModifier != [predicate comparisonPredicateModifier])
	{
		[self collectAll];
		goto end;
	}
	
	if (kComparisonTypeAscendingCardinality != ScalarComparisonType (lval, rval))
	{
		[self collectAll];
		goto end;
	}
	
	NSString* lSQL = [lval expressionSQL: self];
	NSString* rSQL = [rval expressionSQL: self];
	NSString* expressionSQL = [NSString stringWithFormat: @"%@ = ANY (%@)", lSQL, rSQL];
	[self addToFrame: expressionSQL];
	
end: 
	;
}

- (void) handleInComparison: (NSComparisonPredicate *) predicate 
					   lval: (BXPGExpressionValueType *) lval
					   rval: (BXPGExpressionValueType *) rval
{
	//Don't switch argument places initially since ANY and ALL aren't allowed here.
	NSUInteger comparisonOptions = [predicate options];
	if (comparisonOptions & ~NSCaseInsensitivePredicateOption)
	{
		[self collectAll];
		goto end;
	}
	
	if (NSDirectPredicateModifier != [predicate comparisonPredicateModifier])
	{
		[self collectAll];
		goto end;
	}
	
	if (comparisonOptions & NSCaseInsensitivePredicateOption)
	{
		//String operations have reversed argument order.
		[self handleStringOperation: predicate lval: rval rval: lval];
		goto end;
	}
	
	switch (ScalarComparisonType (lval, rval)) 
	{
		case kComparisonTypeAscendingCardinality:
			//Contains has reversed argument order.
			[self handleContainsComparison: predicate lval: rval rval: lval];
			break;
			
		case kComparisonTypeBothScalar:
		{
			NSString* lSQL = [lval expressionSQL: self];
			NSString* rSQL = [rval expressionSQL: self];
			NSString* expressionSQL = [NSString stringWithFormat: @"(0 != position (%@ in %@))", lSQL, rSQL];
			[self addToFrame: expressionSQL];
			break;
		}
			
		default:
			[self collectAll];
			break;
	}
	
end: 
	;
}

- (void) addConditionForObject: (BXDatabaseObject *) object
{
	if ([mEntity isEqual: [object entity]])
	{
		BXPGPrimaryRelationFromItem* fromItem = [mAliasMapper primaryRelation];
		NSString* alias = [fromItem alias];
		[self addFrame];
		
		TSEnumerate (currentAttr, e, [[mEntity primaryKeyFields] objectEnumerator])
		{
			NSString* name = [currentAttr name];
			id value = [object primitiveValueForKey: name];
			NSString* parameterName = [mParameterMapper addParameter: value];
			NSString* condition = [NSString stringWithFormat: @"%@.\"%@\" = %@", alias, name, parameterName];
			[self addToFrame: condition];
		}
		
		NSString* joined = [[self currentFrame] componentsJoinedByString: @" AND "];
		[self removeFrame];
		[self addToFrame: [NSString stringWithFormat: @"(%@)", joined]];
	}
	else
	{
		[self collectNone];
	}
}

static void
RelationshipCallback (NSString* srcKey, NSString* dstKey, void* contextPointer)
{
	struct RelationshipContext* ctx = (struct RelationshipContext *) contextPointer;
	id value = [ctx->rc_object primitiveValueForKey: dstKey];
	NSString* parameterName = [ctx->rc_mapper addParameter: value];
	//FIXME: check the operator, if we wanted to support others than equality. (Would we?)
	NSString* component = [NSString stringWithFormat: @"%@.\"%@\" = %@", ctx->rc_fi_alias, dstKey, parameterName];
	[ctx->rc_components addObject: component];
}

static void
NormalizeForIdentityTest (BXPGExpressionValueType** lval, BXPGExpressionValueType** rval)
{
	id tmp = nil;
	if ([*lval isIdentityExpression])
	{
		tmp = *lval;
		*lval = *rval;
		*rval = tmp;
	}
}

- (BOOL) handleObjectOrRelationshipComparison: (NSComparisonPredicate *) predicate
										 lval: (BXPGExpressionValueType *) lval 
										 rval: (BXPGExpressionValueType *) rval
{
	BOOL handled = NO;
	NSComparisonPredicateModifier modifier = [predicate comparisonPredicateModifier];
	
	if ([rval isDatabaseObject])
	{
		//FIXME: handle NSAllPredicateModifier.
		if ([lval hasRelationships])
		{
			handled = YES;
			NSInteger cardinality = [lval relationshipCardinality];
			
			if ((0 == cardinality && NSDirectPredicateModifier == modifier) ||
				(0 < cardinality && NSAnyPredicateModifier == modifier))
			{
				//The lval is a key path to the relationship, so start with it. The expression visitor will
				//add FROM items the last one of which we can use to set the where clause based on rval.
				//We don't need the SQL from the relationship.
				[lval expressionSQL: self];
				
				BXRelationshipDescription* relationship = [[lval value] lastObject];
				BXPGFromItem* fromItem = [mAliasMapper previousFromItem];
				NSMutableArray* components = [NSMutableArray array];
				struct RelationshipContext ctx = {[rval value], mParameterMapper, [fromItem alias], components};
				[relationship iterateForeignKey: &RelationshipCallback context: &ctx];	
				
				if (1 == [components count])
					[self addToFrame: [components lastObject]];
				else
				{
					NSString* joined = [components componentsJoinedByString: @" AND "];
					[self addToFrame: [NSString stringWithFormat: @"(%@)", joined]];
				}
			}
			else
			{
				[self collectAll];
			}
		}
		else
		{
			NormalizeForIdentityTest (&lval, &rval);
			if ([rval isIdentityExpression])
			{
				if (1 == [lval arrayCardinality] && NSAnyPredicateModifier == modifier)
				{
					handled = YES;
					id collection = [lval value];
				
					[self addFrame];
					TSEnumerate (currentObject, e, [collection objectEnumerator])
						[self addConditionForObject: currentObject];
										
					NSString* joined = [[self currentFrame] componentsJoinedByString: @" OR "];
					[self removeFrame];
					[self addToFrame: [NSString stringWithFormat: @"(%@)", joined]];
				}
				else if ([lval isDatabaseObject] && ! [lval isIdentityExpression] &&
						 NSDirectPredicateModifier == modifier)
				{
					handled = YES;
					BXDatabaseObject* object = [lval value];
					[self addConditionForObject: object];
				}
			}
			else
			{
				BXDatabaseObject* object = [rval value];
				if (1 == [lval arrayCardinality] && NSAnyPredicateModifier == modifier)
				{
					handled = YES;
					if ([[lval value] containsObject: object])
						[self collectAll];
					else
						[self collectNone];
				}
				else if ([lval isDatabaseObject] && NSDirectPredicateModifier == modifier)
				{
					handled = YES;
					if ([[lval value] isEqual: object])
						[self collectAll];
					else
						[self collectNone];
				}
			}
		}
	}
	return handled;
}

- (BXPGExpressionValueType *) evaluateExpression: (NSExpression *) expression
{
	BXPGExpressionValueType* retval = nil;
	id value = [expression expressionValueWithObject: mObject context: mContext];
	if (value)
	{
		if ([value isKindOfClass: [NSExpression class]])
			retval = [value BXPGVisitExpression: self];
		else
			retval = [BXPGExpressionValueType valueTypeForObject: value];
	}
	return retval;
}
@end


@implementation BXPGPredicateVisitor (BXPGPredicateVisitor)
#pragma mark Predicates
- (void) visitUnknownPredicate: (NSPredicate *) predicate
{
	[self collectAll];
}

- (void) visitTruePredicate: (NSPredicate *) predicate
{
	[self addToFrame: @"(true)"];
}

- (void) visitFalsePredicate: (NSPredicate *) predicate
{
	[self addToFrame: @"(false)"];
}

- (void) visitAndPredicate: (NSCompoundPredicate *) predicate
{
	[self glue: predicate andOr: @" AND "];
}

- (void) visitOrPredicate: (NSCompoundPredicate *) predicate
{
	[self glue: predicate andOr: @" OR "];
}

- (void) visitNotPredicate: (NSCompoundPredicate *) predicate
{
	mCollectAllState = ! mCollectAllState;
	NSPredicate* sub = [[predicate subpredicates] lastObject];
	if (sub)
	{
		[self addFrame];
		[sub BXPGVisit: self];
		NSString* clause = [[self currentFrame] lastObject];
		[self removeFrame];
		[self addToFrame: [NSString stringWithFormat: @"NOT (%@)", clause]];
	}
}

- (void) visitComparisonPredicate: (NSComparisonPredicate *) predicate
{
	NSExpression* lhs = [predicate leftExpression];
	NSExpression* rhs = [predicate rightExpression];
	if (lhs && rhs)
	{
		BXPGExpressionValueType* lval = [lhs BXPGVisitExpression: self];
		BXPGExpressionValueType* rval = [rhs BXPGVisitExpression: self];
		if (! (lval && rval))
			[self collectAll];
		else if (! [self handleObjectOrRelationshipComparison: predicate lval: lval rval: rval])
		{
			NSPredicateOperatorType type = [predicate predicateOperatorType];	
			switch (type) 
			{
				case NSCustomSelectorPredicateOperatorType:
					[self handleCustomPredicateComparison: predicate lval: lval rval: rval];
					break;
					
				case NSEqualToPredicateOperatorType:
				case NSNotEqualToPredicateOperatorType:
					[self handleEqualityComparison: predicate lval: lval rval: rval];
					break;
					
				case NSInPredicateOperatorType:
					[self handleInComparison: predicate lval: lval rval: rval];
					break;

				case NSContainsPredicateOperatorType:
					[self handleContainsComparison: predicate lval: lval rval: rval];
					break;
					
				case NSBeginsWithPredicateOperatorType:
				case NSEndsWithPredicateOperatorType:
				case NSMatchesPredicateOperatorType:
				case NSLikePredicateOperatorType:
					[self handleStringOperation: predicate lval: lval rval: rval];
					break;
					
				case NSBetweenPredicateOperatorType:
					[self handleBetweenComparison: predicate lval: lval rval: rval];
					break;
					
				case NSLessThanPredicateOperatorType:
				case NSLessThanOrEqualToPredicateOperatorType:
				case NSGreaterThanPredicateOperatorType:
				case NSGreaterThanOrEqualToPredicateOperatorType:			
					[self handleScalarComparison: predicate lval: lval rval: rval];
					
				default:
					break;
			}
		}
	}
}

#pragma mark Expressions
- (BXPGExpressionValueType *) visitConstantValueExpression: (NSExpression *) expression
{
	BXPGExpressionValueType* retval = nil;
	id constantValue = [expression constantValue];
    if (YES == [constantValue respondsToSelector: @selector (PGTSConstantExpressionValue:)])
    {
		//If we need some special behaviour, like translating boolean NSNumbers to true or false
		//instead of 1 or 0, this is the place to do it.
        id value = [constantValue PGTSConstantExpressionValue: mContext];
		if ([value isKindOfClass: [NSExpression class]])
			retval = [value BXPGVisitExpression: self];
		else
			retval = [BXPGExpressionValueType valueTypeForObject: value];
    }
	else
	{
		retval = [self evaluateExpression: expression];
	}
	return retval;
}

- (BXPGExpressionValueType *) visitEvaluatedObjectExpression: (NSExpression *) expression
{
	id retval = nil;
	if (mObject)
		retval = [self evaluateExpression: expression];
	else
		retval = [BXPGIdentityExpressionValueType type];
	
	return retval;
}

- (BXPGExpressionValueType *) visitVariableExpression: (NSExpression *) expression
{
	return [self evaluateExpression: expression];
}

- (BXPGExpressionValueType *) visitKeyPathExpression: (NSExpression *) expression
{
#pragma mark Initial key path validation
	BXPGExpressionValueType* retval = nil;
	NSString* keyPath = [expression keyPath];
	NSArray* components = BXKeyPathComponents (keyPath);
	BXEntityDescription* entity = mEntity;
	
	id property = nil;
	NSMutableArray* propertyStack = [NSMutableArray arrayWithCapacity: [components count]];
	NSEnumerator* e = [components objectEnumerator];
	NSString* currentKey = nil;
	NSInteger arrayCardinality = 0;
	NSInteger relationshipCardinality = 0;
	BOOL hasRelationships = NO;
	
	//The key path must be like one of the following:
	//attribute.function*
	//relationship.function*
	//relationship.attribute.function*
	
	//First we collect the relationships.
	while ((currentKey = [e nextObject]))
	{
		property = [[entity relationshipsByName] objectForKey: currentKey];
		if (! property)
			break;
		
		hasRelationships = YES;

		if ([property isToMany])
			relationshipCardinality++;

		[propertyStack addObject: property];
		entity = [(BXRelationshipDescription *) property destinationEntity];
	}
	
	//We have problems with properties the cardinality of which caused by relationships is greater than one.
	if (1 < relationshipCardinality)
		goto end;
		
	if (currentKey)
	{
		//Also collect an attribute. We don't allow PG's compound types at least yet.
		property = [[entity attributesByName] objectForKey: currentKey];
		if (property)
		{
			currentKey = nil;
			[propertyStack addObject: property];
			if ([property isArray])
				arrayCardinality++;
		}
	
		//FIXME: we should allow functions in the future.
#if 0
		//Also collect the functions.
		BXPGSQLFunction* function = nil;
		if (! currentKey)
			currentKey = [e nextObject];
		
		if (currentKey)
		{
			do
			{
				BXPGExpressionValueType* valueType = [propertyStack lastObject];
				function = [BXPGSQLFunction functionNamed: currentKey valueType: valueType];
				if (! function)
					goto end;
				
				arrayCardinality = [function arrayCardinality];
				relationshipCardinality = [function relationshipCardinality];
				[propertyStack addObject: function];
			}
			while ((currentKey = [e nextObject]));
		}
#endif
	}
		
	//FIXME: PostgreSQL doesn't allow array_accum in WHERE clause, so for now we just accept duplicate rows and the resulting problems.
#if 0
	//Check if we need an array_accum.
	if (0 < relationshipCardinality)
	{
		BXPGSQLFunction* function = [BXPGSQLArrayAccumFunction function];
		[propertyStack addObject: function];
	}
#endif
	
	//If we have a valid key path, set the return value.
	retval = [BXPGKeypathExpressionValueType typeWithValue: propertyStack 
										  arrayCardinality: arrayCardinality
								   relationshipCardinality: relationshipCardinality
										  hasRelationships: hasRelationships];
end:
	return retval;
}

- (BXPGExpressionValueType *) visitFunctionExpression: (NSExpression *) expression
{
	BXPGExpressionValueType* retval = nil;
	
	NSString* functionName = [expression function];
	NSExpression* operand = [expression operand];
	NSArray* arguments = [expression arguments];
	
	if ([@"valueForKeyPath:" isEqualToString: functionName])
	{
		//There should be one argument of type NSKeyPathSpecifierExpression.
		NSExpression* argument = [arguments lastObject];
		if (argument)
			retval = [argument BXPGVisitExpression: self];
	}
	else if (NSConstantValueExpressionType == [operand expressionType])
	{
		Class utilClass = NSClassFromString (@"_NSPredicateUtilities");
		if (utilClass && [operand constantValue] == utilClass)
			retval = [BXPGFunctionExpressionEvaluator valueTypeForExpression: expression visitor: self];
	}
	return retval;
}

- (BXPGExpressionValueType *) visitAggregateExpression: (NSExpression *) expression
{
	BXPGExpressionValueType* retval = nil;
	NSArray* subExpressions = [expression collection];
	NSMutableArray* subTypes = [NSMutableArray arrayWithCapacity: [subExpressions count]];
	TSEnumerate (currentExpression, e, [subExpressions objectEnumerator])
	{
		BXPGExpressionValueType* subType = [currentExpression BXPGVisitExpression: self];
		if (! subType)
			goto end;
		
		[subTypes addObject: subType];
	}
	
	//We require arrays to be non-empty.
	if (! [subTypes count])
		goto end;
	
	//See that the subtypes have the same cardinality.
	NSInteger cardinality = [[subTypes lastObject] arrayCardinality];
	TSEnumerate (currentSubType, e, [subTypes objectEnumerator])
	{
		if (0 < [currentSubType relationshipCardinality] || 
			[currentSubType arrayCardinality] != cardinality)
			goto end;
	}
	
	retval = [BXPGAggregateExpressionValueType typeWithValue: subTypes cardinality: 1 + cardinality];

end:
	return retval;
}

- (BXPGExpressionValueType *) visitSubqueryExpression: (NSExpression *) expression
{
	//FIXME: handle subqueries.
	BXPGExpressionValueType* retval = nil;
	return retval;
}

- (BXPGExpressionValueType *) visitUnionSetExpression: (NSExpression *) expression
{
	BXPGExpressionValueType* retval = nil;
	return retval;
}

- (BXPGExpressionValueType *) visitIntersectSetExpression: (NSExpression *) expression
{
	BXPGExpressionValueType* retval = nil;
	return retval;
}

- (BXPGExpressionValueType *) visitMinusSetExpression: (NSExpression *) expression
{
	BXPGExpressionValueType* retval = nil;
	return retval;
}

- (BXPGExpressionValueType *) visitUnknownExpression: (NSExpression *) expression
{
	BXPGExpressionValueType* retval = nil;
	return retval;
}
@end


@implementation BXPGPredicateVisitor (BXPGExpressionHandler)
- (NSString *) handlePGConstantExpressionValue: (id) value
{
	return [mParameterMapper addParameter: value];
}

- (NSString *) handlePGKeyPathExpressionValue: (NSArray *) keyPath
{
	NSString* retval = [mExpressionVisitor beginWithKeyPath: keyPath];
	return retval;
}

- (NSString *) handlePGAggregateExpressionValue: (NSArray *) valueTree
{
	NSArray* subValues = (id)[[valueTree PGTSCollect] expressionSQL: self];
	NSString* retval = [NSString stringWithFormat: @"ARRAY [%@]", [subValues componentsJoinedByString: @","]];
	return retval;
}

- (NSString *) handlePGPredefinedFunctionExpressionValue: (BXPGPredefinedFunctionExpressionValueType *) valueType
{
	NSString* retval = [BXPGFunctionExpressionEvaluator evaluateExpression: valueType visitor: self];
	return retval;
}
@end