//
// BXContainerProxy.h
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

@class BXDatabaseContext;
@class BXEntityDescription;
@class BXDatabaseObject;

@interface BXContainerProxy : NSProxy <NSCopying>
{
    BXDatabaseContext* mContext;
    id mContainer;
    id mOwner;
    NSString* mKey;
    Class mNonMutatingClass;
    NSPredicate* mFilterPredicate;
    BXEntityDescription* mEntity;
    BOOL mIsMutable;
    BOOL mChanging;
}

- (id) BXInitWithArray: (NSMutableArray *) anArray;
- (void) filterObjectsForUpdate: (NSArray *) objects 
                          added: (NSMutableArray **) added 
                        removed: (NSMutableArray **) removed;
- (NSMutableDictionary *) substitutionVariables;
@end


@interface BXContainerProxy (Accessors)
- (BXDatabaseContext *) context;
- (void) setDatabaseContext: (BXDatabaseContext *) aContext;
- (NSPredicate *) filterPredicate;
- (void) setFilterPredicate: (NSPredicate *) aPredicate;
- (void) setEntity: (BXEntityDescription *) anEntity;
- (void) fetchedForEntity: (BXEntityDescription *) entity predicate: (NSPredicate *) predicate;
- (id) owner;
- (void) setOwner: (id) anObject;
- (void) setKey: (NSString *) aString;
- (NSString *) key;
@end


@interface BXContainerProxy (Callbacks)
- (void) handleAddedObjects: (NSArray *) objectArray;
- (void) handleRemovedObjects: (NSArray *) objectArray;
- (void) addedObjectsWithIDs: (NSArray *) ids;
- (void) removedObjectsWithIDs: (NSArray *) ids;
- (void) updatedObjectsWithIDs: (NSArray *) ids;
@end


@interface BXContainerProxy (Notifications)
- (void) addedObjects: (NSNotification *) notification;
- (void) deletedObjects: (NSNotification *) notification;
- (void) updatedObjects: (NSNotification *) notification;
@end
