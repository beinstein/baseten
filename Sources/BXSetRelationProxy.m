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
#import "BXDatabaseContextPrivate.h"


//Sadly, this is needed to receive the set proxy and to get a method signature.
@interface BXSetRelationProxyHelper : NSObject
{
    NSMutableSet* set;
    id observer;
}
- (id) initWithProxy: (id) aProxy container: (NSMutableSet *) aContainer;
- (void) updateDatabaseWithNewValue: (NSSet *) new oldValue: (NSSet *) old;
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

- (void) updateDatabaseWithNewValue: (NSSet *) new oldValue: (NSSet *) old
{
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
		mForwardToHelper = YES;
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
	NSMutableSet* oldValue = [NSMutableSet setWithSet: mContainer];
	
	switch ([[change objectForKey: NSKeyValueChangeKindKey] intValue])
	{
		case NSKeyValueChangeInsertion:
		{
			NSSet* added = [change objectForKey: NSKeyValueChangeNewKey];
			[oldValue minusSet: added];
			
			//If context isn't autocommitting, undo and redo happen differently.
			if ([mContext autocommits])
				[[[mContext undoManager] prepareWithInvocationTarget: self] minusSet: added];
			break;
		}
			
		case NSKeyValueChangeRemoval:
		{
			NSSet* removed = [change objectForKey: NSKeyValueChangeOldKey];
			[oldValue unionSet: removed];

			//If context isn't autocommitting, undo and redo happen differently.
			if ([mContext autocommits])
				[[[mContext undoManager] prepareWithInvocationTarget: self] unionSet: removed];
			break;
		}
			
		default:
			break;
	}
	
	[self updateDatabaseWithNewValue: mContainer oldValue: oldValue];
}

- (void) updateDatabaseWithNewValue: (NSSet *) new oldValue: (NSSet *) old
{
	mChanging = YES;
	
	//Set mContainer temporarily to old since someone might be KVC-observing.
	//We also send the KVC posting since we have to replace the container again
	//before didChange gets sent.
	id realContainer = mContainer;
	mContainer = old;
	mForwardToHelper = NO;
	[mReferenceObject willChangeValueForKey: [mRelationship name]];
		
	//Make the change.
	NSError* localError = nil;
	[mRelationship setTarget: new forObject: mReferenceObject error: &localError];
	if (nil != localError)
		[mContext handleError: localError];
	
	//Switch back.
	mContainer = realContainer;
	mForwardToHelper = YES;
	[mReferenceObject didChangeValueForKey: [mRelationship name]];
	
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
	//Do otherwise only under special circumstances.
	if (mForwardToHelper)
		[anInvocation invokeWithTarget: [mHelper mutableSetValueForKey: @"set"]];
	else
		[anInvocation invokeWithTarget: mContainer];
}

@end
