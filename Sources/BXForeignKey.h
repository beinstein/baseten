//
// BXForeignKey.h
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
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
#import <CoreData/CoreData.h>
#import <BaseTen/BXAbstractDescription.h>

@class BXEntityDescription;
@class BXDatabaseObject;
@class BXDatabaseObjectID;

@interface BXForeignKey : BXAbstractDescription 
{
	NSMutableSet* mFieldNames;
	
	//FIXME: this shouldn't really be here but unfortunately we are not using
	//the PGTS metadata classes to fetch foreign keys and we have to store this somewhere.
	NSDeleteRule mDeleteRule;
}
- (void) addSrcFieldName: (NSString *) srcFName dstFieldName: (NSString *) dstFName;
- (NSSet *) fieldNames;
- (NSArray *) srcFieldNames;
- (NSArray *) dstFieldNames;

- (NSDeleteRule) deleteRule;
- (void) setDeleteRule: (NSDeleteRule) aRule;

- (BXDatabaseObjectID *) objectIDForSrcEntity: (BXEntityDescription *) srcEntity fromObject: (BXDatabaseObject *) object;
- (BXDatabaseObjectID *) objectIDForDstEntity: (BXEntityDescription *) dstEntity fromObject: (BXDatabaseObject *) anObject;
- (NSPredicate *) predicateForSrcEntity: (BXEntityDescription *) srcEntity valuesInObject: (BXDatabaseObject *) anObject;
- (NSPredicate *) predicateForDstEntity: (BXEntityDescription *) dstEntity valuesInObject: (BXDatabaseObject *) anObject;
- (NSPredicate *) predicateForSrcEntity: (BXEntityDescription *) srcEntity
							  dstEntity: (BXEntityDescription *) dstEntity;	
- (NSMutableDictionary *) srcDictionaryFor: (BXEntityDescription *) entity valuesFromDstObject: (BXDatabaseObject *) object;
- (NSMutableDictionary *) dstDictionaryFor: (BXEntityDescription *) entity valuesFromSrcObject: (BXDatabaseObject *) object;
@end
