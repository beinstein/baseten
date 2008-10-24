//
// BXPGQueryBuilder.m
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

#import "BXPGQueryBuilder.h"
#import "BXPredicateVisitor.h"
#import "BXPGConstantParameterMapper.h"
#import "BXPGRelationAliasMapper.h"
#import "BXPGInterface.h"
#import "BXDatabaseContextPrivate.h"
#import "BXPGTransactionHandler.h"
#import "BXLogger.h"
#import "BXPGFromItem.h"


@implementation BXPGQueryBuilder
- (id) init
{
	if ((self = [super init]))
	{
		mPredicateVisitor = [[BXPGPredicateVisitor alloc] init];
		mRelationMapper = [[BXPGRelationAliasMapper alloc] init];
		
		[mPredicateVisitor setRelationAliasMapper: mRelationMapper];
	}
	return self;
}

- (void) dealloc
{
	[mPredicateVisitor release];
	[mRelationMapper release];
	[super dealloc];
}

- (BXPGFromItem *) primaryRelation
{
	return mPrimaryRelation;
}

- (void) setPrimaryRelation: (BXPGFromItem *) fromItem
{
	if (mPrimaryRelation != fromItem)
	{
		[mPrimaryRelation release];
		mPrimaryRelation = [fromItem retain];
	}
}

- (void) addPrimaryRelationForEntity: (BXEntityDescription *) entity
{
	ExpectV (entity);
	ExpectV (mRelationMapper);
	BXPGFromItem* fromItem = [mRelationMapper addPrimaryRelationForEntity: entity];
	[self setPrimaryRelation: fromItem];
}

- (NSString *) addParameter: (id) value
{
	return [[mPredicateVisitor constantParameterMapper] addParameter: value];
}

- (NSArray *) parameters
{
	return [[mPredicateVisitor constantParameterMapper] parameters];
}

- (NSString *) fromClause
{
	Expect (mQueryType);
	NSString* retval = nil;
	
	switch (mQueryType) 
	{
		case kBXPGQueryTypeSelect:
			retval = [mRelationMapper fromClauseForSelect];
			break;
			
		case kBXPGQueryTypeUpdate:
		case kBXPGQueryTypeDelete:
			retval = [mRelationMapper fromOrUsingClause];
			break;
			
		case kBXPGQueryTypeNone:
		default:
			break;
	}
	return retval;
}

- (NSString *) fromClauseForSelect
{
	return [mRelationMapper fromClauseForSelect];
}

- (NSString *) target
{
	return [mRelationMapper target];
}

- (struct bx_predicate_st) whereClauseForPredicate: (NSPredicate *) predicate 
													object: (BXDatabaseObject *) object 
{
	BXDatabaseContext* ctx = [object databaseContext];
	BXPGInterface* interface = (id) [ctx databaseInterface];
	BXPGTransactionHandler* transactionHandler = [interface transactionHandler];
	PGTSConnection* connection = [transactionHandler connection];
	
	[mPredicateVisitor setObject: object];
	[mPredicateVisitor setEntity: [object entity]];
	[mPredicateVisitor setConnection: connection];
	[mPredicateVisitor setQueryType: mQueryType];
	return [mPredicateVisitor beginWithPredicate: predicate];
}

- (struct bx_predicate_st) whereClauseForPredicate: (NSPredicate *) predicate 
													entity: (BXEntityDescription *) entity 
												connection: (PGTSConnection *) connection
{
	[mPredicateVisitor setObject: nil];
	[mPredicateVisitor setEntity: entity];
	[mPredicateVisitor setConnection: connection];
	[mPredicateVisitor setQueryType: mQueryType];
	return [mPredicateVisitor beginWithPredicate: predicate];
}

- (void) reset
{
	mQueryType = kBXPGQueryTypeNone;
	[mRelationMapper resetAll];
	[[mPredicateVisitor constantParameterMapper] reset];
}

- (void) setQueryType: (enum BXPGQueryType) queryType
{
	mQueryType = queryType;
}
@end
