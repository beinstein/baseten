//
// BXEntityDescriptionPrivate.h
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
#import <BaseTen/BXEntityDescription.h>

@class BXDatabaseContext;
@class BXDatabaseObjectID;
@class BXRelationshipDescription;


@interface BXEntityDescription (PrivateMethods)
- (NSURL *) entityKey;
+ (NSURL *) entityKeyForDatabaseURI: (NSURL *) databaseURI schema: (NSString *) schemaName table: (NSString *) tableName;
+ (id) entityWithDatabaseURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName;
- (id) initWithDatabaseURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName;
- (void) registerObjectID: (BXDatabaseObjectID *) anID;
- (void) unregisterObjectID: (BXDatabaseObjectID *) anID;
- (NSArray *) attributes: (NSArray *) strings;
- (void) setAttributes: (NSDictionary *) attributes;
- (void) resetAttributeExclusion;
- (void) setValidated: (BOOL) flag;
- (void) setIsView: (BOOL) flag;
- (void) setRelationships: (NSDictionary *) aDict;
- (NSLock *) validationLock;
- (void) removeRelationship: (BXRelationshipDescription *) aRelationship;

- (void) inherits: (NSArray *) entities;
- (void) addSubEntity: (BXEntityDescription *) entity;
- (id) inheritedEntities;
- (id) subEntities;
- (void) viewGetsUpdatedWith: (NSArray *) entities;
- (id) viewsUpdated;
- (BOOL) getsChangedByTriggers;
- (void) setGetsChangedByTriggers: (BOOL) flag;
@end
