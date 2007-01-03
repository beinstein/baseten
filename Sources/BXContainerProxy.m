//
// BXArrayProxy.m
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

#import "BXContainerProxy.h"
#import "BXDatabaseContext.h"
#import "BXConstants.h"
#import "BXDatabaseAdditions.h"
#import <Log4Cocoa/Log4Cocoa.h>


@implementation BXContainerProxy

- (id) BXInitWithArray: (NSMutableArray *) anArray
{
    mIsMutable = YES;
    mChanging = NO;
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [mContainer release];
    [mContext release];
    [mFilterPredicate release];
    [super dealloc];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@: %@", [self class], mContainer];
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) aSelector
{
    NSMethodSignature* rval = nil;
    if (YES == mIsMutable)
        rval = [mContainer methodSignatureForSelector: aSelector];
    else
    {
        //Only allow the non-mutating methods
        NSAssert (Nil != mNonMutatingClass, nil);
        rval = [mNonMutatingClass instanceMethodSignatureForSelector: aSelector];
    }
    return rval;
}

- (void) forwardInvocation: (NSInvocation *) anInvocation
{
    [anInvocation invokeWithTarget: mContainer];
}

- (void) addedObjects: (NSNotification *) notification
{
    if (NO == mChanging)
    {
        NSDictionary* userInfo = [notification userInfo];
        BXDatabaseContext* sendingContext = [userInfo objectForKey: kBXContextKey];
        if (mContext == sendingContext)
        {
            log4Debug (@"Added objects");
            
            NSArray* ids = [userInfo objectForKey: kBXObjectIDsKey];        
            [self addedObjectsWithIDs: ids];
        }
    }
}

- (void) addedObjectsWithIDs: (NSArray *) ids
{    
    NSArray* objects = [mContext faultsWithIDs: ids];
    if (nil != mFilterPredicate)
        objects = [objects BXFilteredArrayUsingPredicate: mFilterPredicate others: nil];
    
    [self handleAddedObjects: objects];
}

- (void) handleAddedObjects: (NSArray *) objectArray
{
    TSEnumerate (currentObject, e, [objectArray objectEnumerator])
        [mContainer addObject: currentObject];
}

- (void) deletedObjects: (NSNotification *) notification
{
    if (NO == mChanging)
    {
        NSDictionary* userInfo = [notification userInfo];
        BXDatabaseContext* sendingContext = [userInfo objectForKey: kBXContextKey];
        if (mContext == sendingContext)
        {        
            log4Debug (@"Deleted objects");
            NSArray* ids = [userInfo objectForKey: kBXObjectIDsKey];
            [self removedObjectsWithIDs: ids];
        }
    }
}

- (void) removedObjectsWithIDs: (NSArray *) ids
{
    [self handleRemovedObjects: [mContext registeredObjectsWithIDs: ids]];
}

- (void) handleRemovedObjects: (NSArray *) objectArray
{
    TSEnumerate (currentObject, e, [objectArray objectEnumerator])
        [mContainer removeObject: currentObject];
}

- (void) updatedObjects: (NSNotification *) notification
{
    if (NO == mChanging)
    {
        NSDictionary* userInfo = [notification userInfo];
        BXDatabaseContext* sendingContext = [userInfo objectForKey: kBXContextKey];
        if (mContext == sendingContext)
        {
            log4Debug (@"Updated objects");
            
            NSArray* ids = [userInfo objectForKey: kBXObjectIDsKey];
            [self updatedObjectsWithIDs: ids];
        }
    }
}

- (void) updatedObjectsWithIDs: (NSArray *) ids
{
    NSArray* objects = [mContext faultsWithIDs: ids];
    
    NSArray* addedObjects = nil;
    NSMutableArray* removedObjects = nil;
    if (nil == mFilterPredicate)
    {
        //If filter predicate is not set, then every object in the entity should be added.
        //FIXME: this might need a reality check.
        addedObjects = objects;
    }
    else
    {
        //Otherwise, separate the objects using the filter predicate.
        removedObjects = [NSMutableArray arrayWithCapacity: [objects count]];
        addedObjects   = [objects BXFilteredArrayUsingPredicate: mFilterPredicate others: removedObjects];
    }
    
    [self handleRemovedObjects: removedObjects];
    [self handleAddedObjects: addedObjects];
}

- (BXDatabaseContext *) context
{
    return mContext; 
}

- (void) setDatabaseContext: (BXDatabaseContext *) aContext
{
    if (mContext != aContext) 
    {
        [mContext release];
        mContext = [aContext retain];
    }
}

- (NSPredicate *) filterPredicate;
{
    return mFilterPredicate;
}

- (void) setFilterPredicate: (NSPredicate *) aFilterPredicate
{
    if (mFilterPredicate != aFilterPredicate) 
    {
        [mFilterPredicate release];
        mFilterPredicate = [aFilterPredicate retain];
    }
}

- (void) setEntity: (BXEntityDescription *) entity
{
    //Set up the modification notification
    if (mEntity != entity) 
    {
        mEntity = entity; //Retain not needed since the entities won't be released

        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver: self];
        
        SEL addSelector = @selector (addedObjects:);
        SEL delSelector = @selector (deletedObjects:);
        SEL updSelector = @selector (updatedObjects:);
    
        [nc addObserver: self selector: addSelector name: kBXInsertNotification object: entity];
        [nc addObserver: self selector: delSelector name: kBXDeleteNotification object: entity];                    
        [nc addObserver: self selector: updSelector name: kBXUpdateNotification object: entity];
    }
}

@end
