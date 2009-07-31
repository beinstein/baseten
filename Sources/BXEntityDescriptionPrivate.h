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
- (id) initWithDatabaseURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName;
- (void) registerObjectID: (BXDatabaseObjectID *) anID;
- (void) unregisterObjectID: (BXDatabaseObjectID *) anID;
- (NSArray *) attributes: (NSArray *) strings;
- (void) setAttributes: (NSDictionary *) attributes;
- (void) resetAttributeExclusion;
- (void) setIsView: (BOOL) flag;
- (void) setRelationships: (NSDictionary *) aDict;
- (void) setHasCapability: (enum BXEntityCapability) aCapability to: (BOOL) flag;
- (void) setEnabled: (BOOL) flag;
- (id) inverseToOneRelationships;
- (void) setFetchedSuperEntities: (NSArray *) entities; //FIXME: merge with other super & sub entity methods.
- (id) fetchedSuperEntities; //FIXME: merge with other super & sub entity methods.

- (BOOL) beginValidation;
- (void) setValidated: (BOOL) flag;
- (void) endValidation;
- (void) removeValidation;
@end
