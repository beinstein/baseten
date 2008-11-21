//
// BXSetProxy.m
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

#import "BXSetProxy.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseAdditions.h"
#import "BXLogger.h"
#import "BXDatabaseObject.h"


/**
 * \brief An NSCountedSet-style self-updating container proxy.
 * \ingroup auto_containers
 */
@implementation BXSetProxy

- (id) BXInitWithArray: (NSMutableArray *) anArray
{
    if ((self = [super BXInitWithArray: anArray]))
    {
        mContainer = [[NSCountedSet alloc] initWithArray: anArray];
        mNonMutatingClass = [NSSet class];
    }
    return self;
}

- (unsigned int) countForObject: (id) anObject
{
    return [mContainer countForObject: anObject];
}

- (id) countedSet
{
    return mContainer;
}

- (void) addedObjectsWithIDs: (NSArray *) ids
{
    NSArray* objects = [mContext faultsWithIDs: ids];
	BXLogDebug (@"Adding objects: %@", objects);
    if (nil != mFilterPredicate)
	{
		NSMutableDictionary* ctx = [self substitutionVariables];
        objects = [objects BXFilteredArrayUsingPredicate: mFilterPredicate 
												  others: nil
								   substitutionVariables: ctx];
	}
    
	if (0 < [objects count])
	{
		NSSet* change = [NSSet setWithArray: objects];
		NSString* key = [self key];
		[mOwner willChangeValueForKey: key
					  withSetMutation: NSKeyValueUnionSetMutation 
						 usingObjects: change];
		[mContainer unionSet: change];
		[mOwner didChangeValueForKey: key 
					 withSetMutation: NSKeyValueUnionSetMutation 
						usingObjects: change];
	}
	BXLogDebug (@"Contents after adding: %@", mContainer);
}

- (void) removedObjectsWithIDs: (NSArray *) ids
{
    NSMutableSet* change = [NSMutableSet setWithArray: [mContext registeredObjectsWithIDs: ids]];
	[change intersectSet: mContainer];
	if (0 < [change count])
	{
		NSString* key = [self key];
		[mOwner willChangeValueForKey: key
					  withSetMutation: NSKeyValueMinusSetMutation 
						 usingObjects: change];
		[mContainer minusSet: change];
		[mOwner didChangeValueForKey: key 
					 withSetMutation: NSKeyValueMinusSetMutation 
						usingObjects: change];
	}
	BXLogDebug (@"Contents after removal: %@", mContainer);
}

- (void) updatedObjectsWithIDs: (NSArray *) ids
{
    NSMutableSet *added = nil, *removed = nil;

    {
        NSArray* objects = [mContext faultsWithIDs: ids];
        NSMutableArray *addedObjects = nil, *removedObjects = nil;
        [self filterObjectsForUpdate: objects added: &addedObjects removed: &removedObjects];
        added = [NSMutableSet setWithArray: addedObjects];
        removed = [NSMutableSet setWithArray: removedObjects];
    }
    
	//Remove redundant objects
    [added minusSet: mContainer];
    [removed intersectSet: mContainer];	    
	BXLogDebug (@"Removing:\t%@", removed);
	BXLogDebug (@"Adding:\t%@", added);
    
    //Determine the change
    NSMutableSet* changed = nil;
    NSKeyValueSetMutationKind mutation = 0;
    if (0 < [added count] && 0 == [removed count])
    {
        mutation = NSKeyValueUnionSetMutation;
        changed = added;
    }
    else if (0 == [added count] && 0 < [removed count])
    {
        mutation = NSKeyValueMinusSetMutation;
        changed = removed;
    }
    else if (0 < [added count] && 0 < [removed count])
    {
        mutation = NSKeyValueSetSetMutation;
        changed = added;
        [changed unionSet: mContainer];
        [changed minusSet: removed];
    }        
    
    if (changed)
    {
		NSString* key = [self key];
        [mOwner willChangeValueForKey: key withSetMutation: mutation usingObjects: changed];
        switch (mutation)
        {
            case NSKeyValueUnionSetMutation:
                [mContainer unionSet: changed];
                break;
            case NSKeyValueMinusSetMutation:
                [mContainer minusSet: changed];
                break;
            case NSKeyValueSetSetMutation:
                [mContainer setSet: changed];
                break;
            default:
                break;
        }
        [mOwner didChangeValueForKey: key withSetMutation: mutation usingObjects: changed];
    }
	BXLogDebug (@"Count after operation:\t%d", [mContainer count]);
}

@end
