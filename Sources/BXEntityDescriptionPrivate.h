//
// BXEntityDescriptionPrivate.h
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
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
#import <BaseTen/BXEntityDescription.h>

@class BXDatabaseContext;
@class BXDatabaseObjectID;
@protocol BXRelationshipDescription;

@interface BXEntityDescription (PrivateMethods)
+ (id) entityWithURI: (NSURL *) anURI table: (NSString *) eName;
+ (id) entityWithURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName;
- (id) initWithURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName;
- (void) addDependentView: (BXEntityDescription *) viewEntity;
- (id <BXRelationshipDescription>) relationshipNamed: (NSString *) aName context: (BXDatabaseContext *) context error: (NSError **) error;
- (void) cacheRelationship: (id <BXRelationshipDescription>) relationship;
- (void) registerObjectID: (BXDatabaseObjectID *) anID;
- (void) unregisterObjectID: (BXDatabaseObjectID *) anID;
- (BXEntityDescription *) targetForRelationship: (id <BXRelationshipDescription>) rel;
- (NSArray *) correspondingProperties: (NSArray *) properties;
- (BOOL) hasAncestor: (BXEntityDescription *) entity;
- (void) setViewEntities: (NSSet *) aSet;
- (void) setAttributes: (NSDictionary *) attributes;
@end
