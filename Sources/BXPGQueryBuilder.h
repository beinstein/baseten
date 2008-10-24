//
// BXPGQueryBuilder.h
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
@class BXDatabaseObject;
@class BXPGPredicateVisitor;
@class BXPGConstantParameterMapper;
@class PGTSConnection;
@class BXPGRelationAliasMapper;
@class BXPGFromItem;
@class BXEntityDescription;


enum BXPGQueryType
{
	kBXPGQueryTypeNone = 0,
	kBXPGQueryTypeSelect,
	kBXPGQueryTypeUpdate,
	kBXPGQueryTypeInsert,
	kBXPGQueryTypeDelete
};


/**
 * \internal
 * A facade for the predicate etc. handling classes.
 */
@interface BXPGQueryBuilder : NSObject 
{
	BXPGPredicateVisitor* mPredicateVisitor;
	BXPGRelationAliasMapper* mRelationMapper;
	BXPGFromItem* mPrimaryRelation;
	enum BXPGQueryType mQueryType;
}
- (BXPGFromItem *) primaryRelation;
- (void) addPrimaryRelationForEntity: (BXEntityDescription *) entity;

- (NSString *) addParameter: (id) value;
- (NSArray *) parameters;

- (NSString *) fromClause;
- (NSString *) target;
- (NSString *) fromClauseForSelect;

- (struct bx_predicate_st) whereClauseForPredicate: (NSPredicate *) predicate 
														   object: (BXDatabaseObject *) object;
- (struct bx_predicate_st) whereClauseForPredicate: (NSPredicate *) predicate 
														   entity: (BXEntityDescription *) entity 
													   connection: (PGTSConnection *) connection;
- (void) setQueryType: (enum BXPGQueryType) queryType;
- (void) reset;
@end
