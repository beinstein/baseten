//
// BXSetRelationProxy.m
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

#import "BXDatabaseContext.h"
#import "BXSetRelationProxy.h"
#import "BXRelationshipDescriptionProtocol.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObject.h"


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
		//mContainer should be retained by now.
        mOriginalContainer = mContainer;
        
        //From now on, receive notifications
        mHelper = [[BXSetRelationProxyHelper alloc] initWithProxy: self container: mContainer];
        mContainer = [[mHelper mutableSetValueForKey: @"set"] retain];
    }
    return self;
}

- (void) dealloc
{
    [mHelper release];
    [mOriginalContainer release];
    [super dealloc];
}

- (unsigned int) countForObject: (id) anObject
{
    return [mOriginalContainer countForObject: anObject];
}

- (void) observeValueForKeyPath: (NSString *) keyPath
                       ofObject: (id) object
                         change: (NSDictionary *) change
                        context: (void *) context
{
    mChanging = YES;
    switch ([[change objectForKey: NSKeyValueChangeKindKey] intValue])
    {
        case NSKeyValueChangeInsertion:
        {
            NSSet* objects = [change objectForKey: NSKeyValueChangeNewKey];
            BXEntityDescription* entity = [[[objects anyObject] objectID] entity];
            [mRelationship addObjects: objects
                        referenceFrom: mReferenceObject
                                   to: entity
                                error: NULL];
            
            //For autocommit
            if ([mContext autocommits])
            {
                [[[mContext undoManager] prepareWithInvocationTarget: mRelationship]
                    removeObjects: objects referenceFrom: mReferenceObject to: entity error: NULL];
            }
            break;
        }
        case NSKeyValueChangeRemoval:
        {
            NSSet* objects = [change objectForKey: NSKeyValueChangeOldKey];
            BXEntityDescription* entity = [[[objects anyObject] objectID] entity];
            [mRelationship removeObjects: objects
                           referenceFrom: mReferenceObject
                                      to: entity
                                   error: NULL];

            //For autocommit
            if ([mContext autocommits])
            {
                [[[mContext undoManager] prepareWithInvocationTarget: mRelationship]
                    addObjects: objects referenceFrom: mReferenceObject to: entity error: NULL];
            }
            break;
        }
        default:
            break;
    }
    mChanging = NO;
}

- (void) setRelationship: (id <BXRelationshipDescription>) relationship
{
    //BXEntityDescription retains these, so we don't have to.
    mRelationship = relationship;
}

- (void) setReferenceObject: (BXDatabaseObject *) aReferenceObject
{
    if (mReferenceObject != aReferenceObject) 
    {
        [mReferenceObject release];
        mReferenceObject = [aReferenceObject retain];
    }
}

- (void) handleAddedObjects: (NSArray *) objectArray
{
    TSEnumerate (currentObject, e, [objectArray objectEnumerator])
	{
		if (NO == [mOriginalContainer containsObject: currentObject])
			[mOriginalContainer addObject: currentObject];
	}
}

- (void) handleRemovedObjects: (NSArray *) objectArray
{
    TSEnumerate (currentObject, e, [objectArray objectEnumerator])
        [mOriginalContainer removeObject: currentObject];
}

- (id) countedSet
{
    return mOriginalContainer;
}

@end
