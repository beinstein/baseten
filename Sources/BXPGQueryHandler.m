//
// BXPGQueryHandler.m
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

#import "BXPGQueryHandler.h"
#import "BXPredicateVisitor.h"
#import "BXPGFromItem.h"
#import "PGTSHOM.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXForeignKey.h"

NSString* kBXPGExceptionCollectAllNoneNotAllowed = @"kBXPGExceptionCollectAllNoneNotAllowed";
NSString* kBXPGExceptionInternalInconsistency = @"kBXPGExceptionInternalInconsistency";


@implementation BXPGExceptionCollectAllNoneNotAllowed
@end


@implementation BXPGExceptionInternalInconsistency
@end


@implementation BXPGQueryHandler
- (id) init
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

+ (void) willCollectAllNone
{
	[BXPGExceptionCollectAllNoneNotAllowed raise: kBXPGExceptionCollectAllNoneNotAllowed format: nil];
}

+ (void) beginQuerySpecific: (BXPGPredicateVisitor *) visitor predicate: (NSPredicate *) predicate
{
}

+ (void) endQuerySpecific: (BXPGPredicateVisitor *) visitor predicate: (NSPredicate *) predicate
{
}
@end


@implementation BXPGSelectQueryHandler
+ (void) willCollectAllNone
{
	//Don't raise the exception.
}
@end


@implementation BXPGUpdateDeleteQueryHandler
+ (void) beginQuerySpecific: (BXPGPredicateVisitor *) visitor predicate: (NSPredicate *) predicate
{
}

+ (void) endQuerySpecific: (BXPGPredicateVisitor *) visitor predicate: (NSPredicate *) predicate
{
	BXPGRelationAliasMapper* mapper = [visitor relationAliasMapper];
	BXPGRelationshipFromItem* fromItem = [mapper firstFromItem];
	
	BXRelationshipDescription* rel = [fromItem relationship];	
	NSArray* conditions = [rel BXPGVisitRelationship: self fromItem: fromItem];
	[[visitor currentFrame] addObjectsFromArray: conditions];
	NSString* joined = [[visitor currentFrame] componentsJoinedByString: @" AND "];
	[visitor removeFrame];
	[visitor addToFrame: [NSString stringWithFormat: @"(%@)", joined]];
}

+ (id) visitSimpleRelationship: (BXPGRelationshipFromItem *) fromItem
{
	BXRelationshipDescription* relationship = [fromItem relationship];
	NSString* src = [[fromItem previous] alias];
	NSString* dst = [fromItem alias];

	BXForeignKey* fkey = [relationship foreignKey];
	NSSet* fieldNames = [fkey fieldNames];
	if (! [relationship isInverse])
		fieldNames = (id) [[fieldNames PGTSCollect] PGTSReverse];

	id retval = BXPGConditions (src, dst, fieldNames);
	return retval;
}

+ (id) visitManyToManyRelationship: (BXPGHelperTableRelationshipFromItem *) fromItem
{	
	BXManyToManyRelationshipDescription* relationship = [fromItem relationship];
	NSString* srcAlias = [[fromItem previous] alias];
	NSString* dstAlias = [fromItem alias];
	BXForeignKey* fkey = [relationship foreignKey];
	NSSet* fieldNames = (id) [[[fkey fieldNames] PGTSCollect] PGTSReverse];
	id retval = BXPGConditions (srcAlias, dstAlias, fieldNames);
	return retval;
}
@end
