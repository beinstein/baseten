//
// BXArrayProxy.m
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

#import "BXContainerProxy.h"
#import "BXDatabaseContext.h"
#import "BXConstants.h"
#import "BXConstantsPrivate.h"
#import "BXDatabaseAdditions.h"
#import "BXLogger.h"


/**
 * A generic self-updating container proxy.
 * \ingroup auto_containers
 */
@implementation BXContainerProxy

- (id) BXInitWithArray: (NSMutableArray *) anArray
{
    mIsMutable = YES;
    mChanging = NO;
    return self;
}

- (void) dealloc
{
    [[mContext notificationCenter] removeObserver: self];
    [mContainer release];    
    [mContext release];
    [mKey release];
    [mFilterPredicate release];
    [mEntity release];
    [super dealloc];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<%@: %p \n (%@ (%p) => %@)>: \n %@", 
		NSStringFromClass ([self class]), self, NSStringFromClass ([mOwner class]), mOwner, mKey, mContainer];
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) aSelector
{
    NSMethodSignature* rval = nil;
    if (YES == mIsMutable)
        rval = [mContainer methodSignatureForSelector: aSelector];
    else
    {
        //Only allow the non-mutating methods
		BXAssertLog (Nil != mNonMutatingClass, @"Expected mimiced class to be set.");
        rval = [mNonMutatingClass instanceMethodSignatureForSelector: aSelector];
    }
    return rval;
}

- (void) forwardInvocation: (NSInvocation *) anInvocation
{
    [anInvocation invokeWithTarget: mContainer];
}

- (BOOL) isEqual: (id) anObject
{
    return [mContainer isEqual: anObject];
}


- (id) copyWithZone: (NSZone *) aZone
{
	//Retain on copy.
	return [self retain];
}

#if 0
- (id) mutableCopyWithZone: (NSZone *) aZone
{
	BXContainerProxy* retval = [[self class] allocWithZone: aZone];
	retval->mContext = [mContext retain];
	retval->mContainer = [mContainer mutableCopyWithZone: aZone];
	retval->mNonMutatingClass = mNonMutatingClass;
	retval->mFilterPredicate = [mFilterPredicate retain];
	retval->mEntity = [mEntity copyWithZone: aZone];
	retval->mIsMutable = mIsMutable;
	retval->mChanging = mChanging;
	return retval;
}
#endif

- (void) filterObjectsForUpdate: (NSArray *) objects 
                          added: (NSMutableArray **) added 
                        removed: (NSMutableArray **) removed
{
    BXAssertVoidReturn (NULL != added && NULL != removed, 
						@"Expected given pointers not to have been NULL.");
    if (nil == mFilterPredicate)
    {
        //If filter predicate is not set, then every object in the entity should be added.
        *added = [[objects mutableCopy] autorelease];
    }
    else
    {
        //Otherwise, separate the objects using the filter predicate.
		NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: [self owner] 
																	  forKey: kBXOwnerObjectVariableName];
        *removed = [NSMutableArray arrayWithCapacity: [objects count]];
        *added   = [objects BXFilteredArrayUsingPredicate: mFilterPredicate others: *removed substitutionVariables: ctx];
    }    
}

@end


@implementation BXContainerProxy (Notifications)

- (void) addedObjects: (NSNotification *) notification
{
    if (NO == mChanging)
    {
        NSDictionary* userInfo = [notification userInfo];
        BXAssertVoidReturn (mContext == [userInfo objectForKey: kBXContextKey], 
                              @"Expected to observe another context.");
        
        NSArray* ids = [userInfo objectForKey: kBXObjectIDsKey];        
        BXLogDebug (@"Adding object ids: %@", ids);
        [self addedObjectsWithIDs: ids];
    }
}

- (void) updatedObjects: (NSNotification *) notification
{
    if (NO == mChanging)
    {
        NSDictionary* userInfo = [notification userInfo];
        BXAssertVoidReturn (mContext == [userInfo objectForKey: kBXContextKey], 
                              @"Expected to observe another context.");
        
        NSArray* ids = [userInfo objectForKey: kBXObjectIDsKey];
        BXLogDebug (@"Updating for object ids: %@", ids);
        [self updatedObjectsWithIDs: ids];
    }
}

- (void) deletedObjects: (NSNotification *) notification
{
    if (NO == mChanging)
    {
        NSDictionary* userInfo = [notification userInfo];
        BXAssertVoidReturn (mContext == [userInfo objectForKey: kBXContextKey], 
                              @"Expected to observe another context.");
        
        NSArray* ids = [userInfo objectForKey: kBXObjectIDsKey];
        BXLogDebug (@"Removing object ids: %@", ids);
        [self removedObjectsWithIDs: ids];
    }
}

@end


@implementation BXContainerProxy (Callbacks)

- (void) addedObjectsWithIDs: (NSArray *) ids
{    
    NSArray* objects = [mContext faultsWithIDs: ids];
	BXLogDebug (@"Adding objects: %@", objects);
	NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: [self owner] 
																  forKey: kBXOwnerObjectVariableName];
    if (nil != mFilterPredicate)
	{
        objects = [objects BXFilteredArrayUsingPredicate: mFilterPredicate 
												  others: nil
								   substitutionVariables: ctx];
	}
    
    //Post notifications since modifying a self-updating collection won't cause
    //value cache to be changed.
	NSString* key = [self key];
    [mOwner willChangeValueForKey: key];    
    [self handleAddedObjects: objects];
    [mOwner didChangeValueForKey: key];
    
    BXLogDebug (@"Contents after adding: %@", mContainer);
}

- (void) removedObjectsWithIDs: (NSArray *) ids
{
    //Post notifications since modifying a self-updating collection won't cause
    //value cache to be changed.
	NSString* key = [self key];
    [mOwner willChangeValueForKey: key];    
    [self handleRemovedObjects: [mContext registeredObjectsWithIDs: ids]];
    [mOwner didChangeValueForKey: key];
    BXLogDebug (@"Contents after removal: %@", mContainer);
}

- (void) updatedObjectsWithIDs: (NSArray *) ids
{
    NSArray* objects = [mContext faultsWithIDs: ids];
    NSMutableArray *addedObjects = nil, *removedObjects = nil;
    [self filterObjectsForUpdate: objects added: &addedObjects removed: &removedObjects];        

	//Remove redundant objects
	TSEnumerate (currentObject, e, [[[addedObjects copy] autorelease] objectEnumerator])
	{
		if ([mContainer containsObject: currentObject])
			[addedObjects removeObject: currentObject];
	}
	TSEnumerate (currentObject, e, [[[removedObjects copy] autorelease] objectEnumerator])
	{
		if (! [mContainer containsObject: currentObject])
			[removedObjects removeObject: currentObject];
	}
	
	BOOL changed = (0 < [removedObjects count] || 0 < [addedObjects count]);
    
	BXLogDebug (@"Removing:\t%@", removedObjects);
	BXLogDebug (@"Adding:\t%@", addedObjects);
	
    //Post notifications since modifying a self-updating collection won't cause
    //value cache to be changed.
	if (changed)
	{
		NSString* key = [self key];
		[mOwner willChangeValueForKey: key];    
		[self handleRemovedObjects: removedObjects];
		[self handleAddedObjects: addedObjects];
		[mOwner didChangeValueForKey: key];
	}
	
	BXLogDebug (@"Count after operation:\t%d", [mContainer count]);
}

- (void) handleAddedObjects: (NSArray *) objectArray
{
    TSEnumerate (currentObject, e, [objectArray objectEnumerator])
	{
		if (NO == [mContainer containsObject: currentObject])
			[mContainer addObject: currentObject];
	}
}

- (void) handleRemovedObjects: (NSArray *) objectArray
{
    TSEnumerate (currentObject, e, [objectArray objectEnumerator])
        [mContainer removeObject: currentObject];
}

@end


@implementation BXContainerProxy (Accessors)

/** The container's context. */
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

/** The container's filter predicate. */
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

- (void) fetchedForEntity: (BXEntityDescription *) entity predicate: (NSPredicate *) predicate
{
	[self setEntity: entity];
	[self setFilterPredicate: predicate];
}

- (void) setEntity: (BXEntityDescription *) entity
{
    BXAssertVoidReturn (nil != mContext, @"Expected mContext not to be nil.");
    
    //Set up the modification notification
    if (mEntity != entity) 
    {
		[mEntity release];
        mEntity = [entity retain];
        
        NSNotificationCenter* nc = [mContext notificationCenter];
        [nc removeObserver: self];
        
        SEL addSelector = @selector (addedObjects:);
        SEL delSelector = @selector (deletedObjects:);
        SEL updSelector = @selector (updatedObjects:);

        [nc addObserver: self selector: addSelector name: kBXInsertEarlyNotification object: entity];
        [nc addObserver: self selector: delSelector name: kBXDeleteEarlyNotification object: entity];                    
        [nc addObserver: self selector: updSelector name: kBXUpdateEarlyNotification object: entity];
    }
}

/** The container's owner. */
- (id) owner
{
	return mOwner;
}

/** 
 * Set the cotainer's owner.
 * NSKeyValueObserving notifications will be posted to the owner.
 * \note The owner is not retained.
 */
- (void) setOwner: (id) anObject
{
    mOwner = anObject;
}

/** The owner's key for the container. */
- (NSString *) key
{
    return [[mKey copy] autorelease];
}

/** 
 * Set the owner's key for the container.
 * NSKeyValueObserving notifications will be posted using this key.
 */
- (void) setKey: (NSString *) aString
{
    if (mKey != aString)
    {
        [mKey release];
        mKey = [aString retain];
    }
}

@end