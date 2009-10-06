//
// BXSetRelationProxy.m
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

#import "BXDatabaseContext.h"
#import "BXSetRelationProxy.h"
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
 * \internal
 * \brief An NSMutableSet-style self-updating container proxy for relationships.
 * \ingroup auto_containers
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

//FIXME: need we this?
#if 0
- (id) mutableCopyWithZone: (NSZone *) zone
{
	BXSetRelationProxy* retval = [super mutableCopyWithZone: zone];
	retval->mHelper = [[BXSetRelationProxyHelper alloc] initWithProxy: retval container: retval->mContainer];
	retval->mRelationship = [mRelationship copyWithZone: zone];
	retval->mForwardToHelper = mForwardToHelper;
	return retval;
}
#endif

- (void) observeValueForKeyPath: (NSString *) keyPath
                       ofObject: (id) object
                         change: (NSDictionary *) change
                        context: (void *) context
{
	NSMutableSet* oldValue = [NSMutableSet setWithSet: mContainer];
	NSSet* changed = nil;
	NSKeyValueSetMutationKind mutationKind = 0;
    SEL undoSelector = NULL;
	
	switch ([[change objectForKey: NSKeyValueChangeKindKey] intValue])
	{
        case NSKeyValueChangeReplacement:
        {
            changed = [change objectForKey: NSKeyValueChangeNewKey];
            [oldValue unionSet: [change objectForKey: NSKeyValueChangeOldKey]];
            mutationKind = NSKeyValueSetSetMutation;
            undoSelector = @selector (setSet:);
            break;
        }
        
		case NSKeyValueChangeInsertion:
		{
			changed = [change objectForKey: NSKeyValueChangeNewKey];
			[oldValue minusSet: changed];
			mutationKind = NSKeyValueUnionSetMutation;
            undoSelector = @selector (minusSet:);
			break;
		}
			
		case NSKeyValueChangeRemoval:
		{
			changed = [change objectForKey: NSKeyValueChangeOldKey];
			[oldValue unionSet: changed];
			mutationKind = NSKeyValueMinusSetMutation;
            undoSelector = @selector (unionSet:);
			break;
		}
			
		default:
			break;
	}
	
    if (0 != mutationKind)
    {
        mChanging = YES;
        
        //If context isn't autocommitting, undo and redo happen differently.
        if ([mContext autocommits] && NULL != undoSelector)
            [[mContext undoManager] registerUndoWithTarget: self selector: undoSelector object: changed];
        
        //Set mContainer temporarily to old since someone might be KVC-observing.
        //We also send the KVC posting since we have to replace the container again
        //before didChange gets sent.
        id realContainer = mContainer;
        mContainer = oldValue;
        mForwardToHelper = NO;
		NSString* key = [self key];
        [mOwner willChangeValueForKey: key
                      withSetMutation: mutationKind
                         usingObjects: changed];
		
        //Make the change.
        NSError* localError = nil;
        [mRelationship setTarget: realContainer forObject: mOwner error: &localError];
        if (nil != localError)
			[[mContext internalDelegate] databaseContext: mContext hadError: localError willBePassedOn: NO];
        
        //Switch back.
        mContainer = realContainer;
        mForwardToHelper = YES;
        [mOwner didChangeValueForKey: key
                     withSetMutation: mutationKind
						usingObjects: changed];
        
        mChanging = NO;
    }
}

- (void) fetchedForEntity: (BXEntityDescription *) entity predicate: (NSPredicate *) predicate
{
	[self setFilterPredicate: predicate];
}

- (void) fetchedForRelationship: (BXRelationshipDescription *) relationship 
						  owner: (BXDatabaseObject *) databaseObject
							key: (NSString *) key
{
	[self setEntity: [relationship destinationEntity]];
	[self setRelationship: relationship];
	[self setOwner: databaseObject];
	[self setKey: key];
}

- (void) setRelationship: (BXRelationshipDescription *) relationship
{
    if (mRelationship != relationship)
    {
        [mRelationship release];
        mRelationship = [relationship retain];
    }
}

- (BXRelationshipDescription *) relationship
{
    return mRelationship;
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

- (NSString *) key
{
    return [[[mRelationship name] copy] autorelease];
}
@end