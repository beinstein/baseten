//
// BXSetRelationProxy.m
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
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

#import "BXDatabaseContext.h"
#import "BXSetRelationProxy.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObject.h"
#import "BXRelationshipDescription.h"
#import "BXRelationshipDescriptionPrivate.h"


//Sadly, this is needed to receive the set proxy
@interface BXSetRelationProxyHelper : NSObject
{
    NSMutableSet* set;
    id observer;
}
- (id) initWithProxy: (id) aProxy container: (NSMutableSet *) aContainer;
@end


@implementation BXSetRelationProxyHelper
- (id) initWithProxy: (id) aProxy container: (NSMutableSet *) aContainer
{
    if ((self = [super init]))
    {
        set = aContainer;
        observer = aProxy;
        [self addObserver: self forKeyPath: @"set"
                  options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                  context: NULL];
    }
    return self;
}

- (void) dealloc
{
    [self removeObserver: self forKeyPath: @"set"];
    [super dealloc];
}

- (void) observeValueForKeyPath: (NSString *) keyPath
                       ofObject: (id) object
                         change: (NSDictionary *) change
                        context: (void *) context
{
    [observer observeValueForKeyPath: keyPath ofObject: object change: change context: context];
}   
@end


/**
 * An NSCountedSet-style self-updating container proxy for relationships.
 */
@implementation BXSetRelationProxy

- (id) BXInitWithArray: (NSMutableArray *) anArray
{
    if ((self = [super BXInitWithArray: anArray]))
    {
        //From now on, receive notifications
        mHelper = [[BXSetRelationProxyHelper alloc] initWithProxy: self container: mContainer];
    }
    return self;
}

- (void) dealloc
{
    [mHelper release];
    [mRelationship release];
    [super dealloc];
}

- (void) observeValueForKeyPath: (NSString *) keyPath
                       ofObject: (id) object
                         change: (NSDictionary *) change
                        context: (void *) context
{
	NSMutableSet* oldValue = nil;
	if ([mContext autocommits])
	{
		oldValue = [NSMutableSet setWithSet: mContainer];
		switch ([[change objectForKey: NSKeyValueChangeKindKey] intValue])
		{
			case NSKeyValueChangeInsertion:
				[oldValue minusSet: [change objectForKey: NSKeyValueChangeNewKey]];
				break;
			
			case NSKeyValueChangeRemoval:
				[oldValue unionSet: [change objectForKey: NSKeyValueChangeOldKey]];
				break;
			
			default:
				break;
		}
	}
	[self updateDatabaseWithNewValue: mContainer oldValue: oldValue];
}

- (void) updateDatabaseWithNewValue: (NSSet *) new oldValue: (NSSet *) old
{
	mChanging = YES;
	//If context isn't autocommitting, we don't care for the old value since undo and redo happen differently.
	if ([mContext autocommits])
	{
		[[[mContext undoManager] prepareWithInvocationTarget: self]
			updateDatabaseWithNewValue: old oldValue: new];
	}
	
	[mRelationship setTarget: new forObject: mReferenceObject error: NULL];
	mChanging = NO;
}

- (void) setRelationship: (BXRelationshipDescription *) relationship
{
    if (mRelationship != relationship)
    {
        [mRelationship release];
        mRelationship = [relationship retain];
    }
}

- (void) setReferenceObject: (BXDatabaseObject *) aReferenceObject
{
    if (mReferenceObject != aReferenceObject) 
    {
        [mReferenceObject release];
        mReferenceObject = [aReferenceObject retain];
    }
}

- (void) forwardInvocation: (NSInvocation *) anInvocation
{
    //Unless we modify the helper's proxy object, changes won't be notified.
    [anInvocation invokeWithTarget: [mHelper mutableSetValueForKey: @"set"]];
}

@end
