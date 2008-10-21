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
#import "BXDatabaseAdditions.h"
#import "BXPGFromItem.h"
#import "BXRelationshipDescription.h"
#import "PGTSHOM.h"
#import "BXManyToManyRelationshipDescription.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXForeignKey.h"


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


NSArray*
BXPGConditions (NSString* srcAlias, NSString* dstAlias, NSSet* fieldNamePairs)
{
	NSMutableArray* conditions = [NSMutableArray arrayWithCapacity: [fieldNamePairs count]];
	TSEnumerate (currentPair, e, [fieldNamePairs objectEnumerator])
	{
		NSString* condition = [NSString stringWithFormat: @"%@.\"%@\" = %@.\"%@\"",
							   srcAlias, [currentPair objectAtIndex: 0], dstAlias, [currentPair objectAtIndex: 1]];
		[conditions addObject: condition];
	}
	return conditions;
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
	TSEnumerate (currentItem, e, [mFromItems objectEnumerator])
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
	NSString* retval = base;
	NSNumber* idx = [mUsedAliases objectForKey: base];
	if (idx)
	{
		int i = 1 + [idx intValue];
		idx = [NSNumber numberWithInt: i];
		[mUsedAliases setObject: idx forKey: base];
		retval = [retval stringByAppendingString: [idx description]];
	}
	else
	{
		idx = [NSNumber numberWithInt: 1];
		[mUsedAliases setObject: idx forKey: base];
	}
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
LeftJoin (BXEntityDescription* dstEntity, NSString* srcAlias, NSString* dstAlias, NSSet* fieldNamePairs)
{
	NSArray* conditions = BXPGConditions (srcAlias, dstAlias, fieldNamePairs);
	NSString* retval =  [NSString stringWithFormat: @"LEFT JOIN \"%@\".\"%@\" %@ ON (%@)", 
						 [dstEntity schemaName], [dstEntity name], dstAlias, 
						 [conditions componentsJoinedByString: @", "]];
	return retval;
}

- (NSString *) visitSimpleRelationship: (BXPGRelationshipFromItem *) fromItem
{
	BXRelationshipDescription* relationship = [fromItem relationship];
	BXForeignKey* fkey = [relationship foreignKey];
	NSSet* fieldNames = [fkey fieldNames];
	if (! [relationship isInverse])
		fieldNames = (id) [[fieldNames PGTSCollect] PGTSReverse];
	
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
		retval = LeftJoin (dstEntity, src, dst, fieldNames);
	}
	return retval;
}

- (NSString *) visitManyToManyRelationship: (BXPGHelperTableRelationshipFromItem *) fromItem
{	
	BXManyToManyRelationshipDescription* relationship = [fromItem relationship];
	BXForeignKey* dstFkey = [relationship dstForeignKey];
	NSSet* dstFields = [dstFkey fieldNames];
	
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
		BXForeignKey* srcFkey = [relationship srcForeignKey];
		NSSet* srcFields = (id) [[[srcFkey fieldNames] PGTSCollect] PGTSReverse];
		NSString* srcAlias = [[fromItem previous] alias];
		
		join1 = LeftJoin (helperEntity, srcAlias, helperAlias, srcFields);
	}
	NSString* join2 = LeftJoin (dstEntity, helperAlias, dstAlias, dstFields);
	return [NSString stringWithFormat: @"%@ %@", join1, join2];
}
@end
