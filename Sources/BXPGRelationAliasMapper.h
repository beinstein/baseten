//
// BXPGRelationAliasMapper.h
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
#import <BaseTen/BXLogger.h>


@class BXPGFromItem;
@class BXEntityDescription;
@class BXRelationshipDescription;
@class BXPGPrimaryRelationFromItem;
@class BXPGRelationshipFromItem;
@class BXPGHelperTableRelationshipFromItem;
@class BXManyToManyRelationshipDescription;
@protocol BXForeignKey;


BX_EXPORT NSArray* BXPGConditions (NSString* alias1, NSString* alias2, id <BXForeignKey> fkey, BOOL reverseNames);


@protocol BXPGFromItemVisitor <NSObject>
- (NSString *) visitPrimaryRelation: (BXPGPrimaryRelationFromItem *) fromItem;
- (NSString *) visitRelationshipJoinItem: (BXPGRelationshipFromItem *) fromItem;
@end


@protocol BXPGRelationshipVisitor <NSObject>
- (NSString *) visitSimpleRelationship: (BXPGRelationshipFromItem *) fromItem;
- (NSString *) visitManyToManyRelationship: (BXPGHelperTableRelationshipFromItem *) fromItem;
@end


@interface BXPGRelationAliasMapper : NSObject 
{
	BXPGPrimaryRelationFromItem* mPrimaryRelation;
	NSMutableArray* mFromItems;
	NSMutableDictionary* mUsedAliases;
	NSMutableArray* mCurrentFromItems;
	
	BOOL mIsFirstInUpdate;
}

- (BXPGPrimaryRelationFromItem *) primaryRelation;
- (void) accept;
- (void) resetCurrent;
- (void) resetAll;

- (NSString *) fromClauseForSelect;
- (NSString *) fromOrUsingClause;
- (NSString *) target;

- (NSString *) addAliasForEntity: (BXEntityDescription *) entity;
- (BXPGPrimaryRelationFromItem *) addPrimaryRelationForEntity: (BXEntityDescription *) entity;
- (BXPGRelationshipFromItem *) addFromItemForRelationship: (BXRelationshipDescription *) rel;
- (BXPGRelationshipFromItem *) previousFromItem;
- (BXPGRelationshipFromItem *) firstFromItem;
@end


@interface BXPGRelationAliasMapper (BXPGFromItemVisitor) <BXPGFromItemVisitor>
@end


@interface BXPGRelationAliasMapper (BXPGRelationshipVisitor) <BXPGRelationshipVisitor>
@end
