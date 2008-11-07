//
// BXRelationshipDescriptionPrivate.h
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

#import <BaseTen/BXRelationshipDescription.h>
#import <BaseTen/BXPGRelationAliasMapper.h>

@class BXForeignKey;
@class BXDatabaseObject;

@interface BXRelationshipDescription (PrivateMethods)
- (id) initWithName: (NSString *) aName entity: (BXEntityDescription *) entity 
  destinationEntity: (BXEntityDescription *) destinationEntity;
- (BXForeignKey *) foreignKey;
- (void) setDestinationEntity: (BXEntityDescription *) entity;
- (void) setForeignKey: (BXForeignKey *) aKey;
- (BOOL) isInverse;
- (void) setIsInverse: (BOOL) aBool;
- (void) setInverseName: (NSString *) aString;
- (void) setDeleteRule: (NSDeleteRule) aRule;

//Remember to override these in subclasses.
- (id) targetForObject: (BXDatabaseObject *) anObject error: (NSError **) error;
- (BOOL) setTarget: (id) target
		 forObject: (BXDatabaseObject *) aDatabaseObject
			 error: (NSError **) error;

- (void) iterateForeignKey: (void (*)(NSString*, NSString*, void*) )callback context: (void *) ctx;

- (void) removeAttributeDependency;
- (void) setAttributeDependency;
@end


@interface BXRelationshipDescription (BXPGRelationAliasMapper)
- (id) BXPGVisitRelationship: (id <BXPGRelationshipVisitor>) visitor fromItem: (BXPGRelationshipFromItem *) fromItem;
@end
