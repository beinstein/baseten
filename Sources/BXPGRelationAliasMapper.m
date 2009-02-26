//
// BXPGRelationAliasMapper.m
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

#import "BXPGRelationAliasMapper.h"
#import "BXEntityDescription.h"
#import "BXPGFromItem.h"
#import "BXRelationshipDescription.h"
#import "PGTSHOM.h"
#import "BXManyToManyRelationshipDescription.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXForeignKey.h"
#import "BXEnumerate.h"


static NSString*
BaseAliasForEntity (BXEntityDescription* entity)
{
	NSString* retval = [entity name];
	if (2 < [retval length])
		retval = [retval substringToIndex: 2];
	retval = [retval lowercaseString];
	return retval;
}


static NSString*
PrimaryRelation (BXPGPrimaryRelationFromItem* fromItem)
{
	BXEntityDescription* entity = [fromItem entity];
	NSString* retval = [NSString stringWithFormat: @"\"%@\".\"%@\" %@",
						[entity schemaName], [entity name], [fromItem alias]];
	return retval;	
}


struct condition_st
{
	__strong NSString* c_src_alias;
	__strong NSString* c_dst_alias;
	__strong NSMutableArray* c_conditions;
};


static void
ConditionsCallback (NSString* srcName, NSString* dstName, void* ctx)
{
	struct condition_st* cst = (struct condition_st*) ctx;
	NSString* condition = [NSString stringWithFormat: @"%@.\"%@\" = %@.\"%@\"",
						   cst->c_src_alias, srcName, cst->c_dst_alias, dstName];
	[cst->c_conditions addObject: condition];
}


NSArray*
BXPGConditions (NSString* alias1, NSString* alias2, id <BXForeignKey> fkey, BOOL reverseNames)
{
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [fkey numberOfColumns]];
	struct condition_st cst = {alias1, alias2, retval};
	if (reverseNames)
		[fkey iterateReversedColumnNames: &ConditionsCallback context: &cst];
	else
		[fkey iterateColumnNames: &ConditionsCallback context: &cst];
	
	return retval;
}


@implementation BXPGRelationAliasMapper
- (id) init
{
	if ((self = [super init]))
	{
		mFromItems = [[NSMutableArray alloc] init];
		mUsedAliases = [[NSMutableDictionary alloc] init];
		mCurrentFromItems = [[NSMutableArray alloc] init];		
	}
	return self;
}

- (void) dealloc
{
	[mFromItems release];
	[mUsedAliases release];
	[mCurrentFromItems release];
	[mPrimaryRelation release];
	[super dealloc];
}

- (void) resetAll
{
	[mFromItems removeAllObjects];
	[mUsedAliases removeAllObjects];
	[mCurrentFromItems removeAllObjects];
}

- (void) resetCurrent
{
	[mCurrentFromItems removeAllObjects];
}

- (void) accept
{
	[mFromItems addObjectsFromArray: mCurrentFromItems];
	[self resetCurrent];
}

- (void) setPrimaryRelation: (BXPGFromItem *) item
{
	if (mPrimaryRelation != item)
	{
		[mPrimaryRelation release];
		mPrimaryRelation = [item retain];
	}
}

- (BXPGPrimaryRelationFromItem *) primaryRelation
{
	return mPrimaryRelation;
}

- (NSString *) target
{
	return PrimaryRelation (mPrimaryRelation);
}


- (NSString *) fromOrUsingClause
{
	NSString* retval = nil;

	mIsFirstInUpdate = YES;
	NSArray* components = (id) [[mFromItems PGTSCollect] BXPGVisitFromItem: self];
	if (0 < [components count])
		retval = [components componentsJoinedByString: @" "];
	mIsFirstInUpdate = NO;
	
	return retval;
}
	
- (NSString *) fromClauseForSelect
{
	NSMutableString* retval = [NSMutableString string];
	[retval appendString: [mPrimaryRelation BXPGVisitFromItem: self]];
	BXEnumerate (currentItem, e, [mFromItems objectEnumerator])
	{
		[retval appendString: @" "];
		[retval appendString: [currentItem BXPGVisitFromItem: self]];
	}
	return retval;
}

- (NSString *) addAliasForEntity: (BXEntityDescription *) entity
{
	Expect (entity);
	NSString* base = BaseAliasForEntity (entity);
	
	//Get an index and increment by one.
	NSNumber* idx = [mUsedAliases objectForKey: base];
	NSInteger i = 0;
	if (idx)
		i = [idx integerValue];
	i++;
	idx = [NSNumber numberWithInteger: i];
	[mUsedAliases setObject: idx forKey: base];
	
	//Append the index to our table alias.
	NSString* retval = [base stringByAppendingFormat: [idx description]];
	return retval;
}

- (BXPGPrimaryRelationFromItem *) addPrimaryRelationForEntity: (BXEntityDescription *) entity
{
	NSString* alias = [self addAliasForEntity: entity];
	BXPGPrimaryRelationFromItem* relation = [[[BXPGPrimaryRelationFromItem alloc] init] autorelease];
	[relation setAlias: alias];
	[relation setEntity: entity];
	
	[self setPrimaryRelation: relation];
	return relation;
}

- (BXPGRelationshipFromItem *) addFromItemForRelationship: (BXRelationshipDescription *) rel
{
	id fromItem = nil;	
	if ([rel isToMany] && [[rel inverseRelationship] isToMany])
	{
		fromItem = [[[BXPGHelperTableRelationshipFromItem alloc] init] autorelease];
		
		BXEntityDescription* helperEntity = [(id) rel helperEntity];
		NSString* alias = [self addAliasForEntity: helperEntity];
		[fromItem setHelperAlias: alias];
	}
	else
	{
		fromItem = [[[BXPGRelationshipFromItem alloc] init] autorelease];
	}
	
	NSString* alias = [self addAliasForEntity: [rel destinationEntity]];
	[fromItem setAlias: alias];
	[fromItem setRelationship: rel];
	[fromItem setPrevious: [mCurrentFromItems lastObject] ?: mPrimaryRelation];
	
	[mCurrentFromItems addObject: fromItem];
	return fromItem;
}

- (BXPGRelationshipFromItem *) previousFromItem
{
	return [mCurrentFromItems lastObject];
}

- (BXPGRelationshipFromItem *) firstFromItem
{
	BXPGRelationshipFromItem* retval = nil;
	if (0 < [mFromItems count])
		retval = [mFromItems objectAtIndex: 0];
	return retval;
}
@end


@implementation BXPGRelationAliasMapper (BXPGFromItemVisitor)
- (NSString *) visitPrimaryRelation: (BXPGPrimaryRelationFromItem *) fromItem
{
	return PrimaryRelation (fromItem);
}

- (NSString *) visitRelationshipJoinItem: (BXPGRelationshipFromItem *) fromItem
{
	BXRelationshipDescription* rel = [fromItem relationship];	
	NSString* condition = [rel BXPGVisitRelationship: self fromItem: fromItem];
	return condition;
}
@end


@implementation BXPGRelationAliasMapper (BXPGRelationshipVisitor)
static NSString*
ImplicitInnerJoin (BXEntityDescription* dstEntity, NSString* dstAlias)
{
	NSString* retval = [NSString stringWithFormat: @"\"%@\".\"%@\" %@",
						[dstEntity schemaName], [dstEntity name], dstAlias];
	return retval;
}

static NSString*
LeftJoin (BXEntityDescription* dstEntity, NSString* srcAlias, NSString* dstAlias, id <BXForeignKey> fkey, BOOL reverseNames)
{
	NSArray* conditions = BXPGConditions (srcAlias, dstAlias, fkey, reverseNames);
	NSString* retval =  [NSString stringWithFormat: @"LEFT JOIN \"%@\".\"%@\" %@ ON (%@)", 
						 [dstEntity schemaName], [dstEntity name], dstAlias, 
						 [conditions componentsJoinedByString: @", "]];
	return retval;
}

- (NSString *) visitSimpleRelationship: (BXPGRelationshipFromItem *) fromItem
{
	BXRelationshipDescription* relationship = [fromItem relationship];
	id <BXForeignKey> fkey = [relationship foreignKey];	
	BXEntityDescription* dstEntity = [relationship destinationEntity];
	NSString* dst = [fromItem alias];
	NSString* retval = nil;	
	if (mIsFirstInUpdate)
	{
		mIsFirstInUpdate = NO;
		retval = ImplicitInnerJoin (dstEntity, dst);
	}
	else
	{
		NSString* src = [[fromItem previous] alias];
		retval = LeftJoin (dstEntity, src, dst, fkey, ! [relationship isInverse]);
	}
	return retval;
}

- (NSString *) visitManyToManyRelationship: (BXPGHelperTableRelationshipFromItem *) fromItem
{	
	BXManyToManyRelationshipDescription* relationship = [fromItem relationship];
	
	BXEntityDescription* helperEntity = [relationship helperEntity];
	BXEntityDescription* dstEntity = [relationship destinationEntity];
	NSString* helperAlias = [fromItem helperAlias];
	NSString* dstAlias = [fromItem alias];

	NSString* join1 = nil;
	if (mIsFirstInUpdate)
	{
		mIsFirstInUpdate = NO;
		join1 = ImplicitInnerJoin (helperEntity, helperAlias);
	}
	else
	{
		id <BXForeignKey> srcFkey = [relationship foreignKey];
		NSString* srcAlias = [[fromItem previous] alias];		
		join1 = LeftJoin (helperEntity, srcAlias, helperAlias, srcFkey, YES);
	}
	id <BXForeignKey> dstFkey = [relationship dstForeignKey];
	NSString* join2 = LeftJoin (dstEntity, helperAlias, dstAlias, dstFkey, NO);
	return [NSString stringWithFormat: @"%@ %@", join1, join2];
}
@end
