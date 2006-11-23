//
// NSController+BXCocoaAdditions.m
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

#import "NSController+BXAppKitAdditions.h"
#import "BXControllerProtocol.h"
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseContextPrivate.h>


@implementation NSObjectController (BXCocoaAdditions)
/** A convenience method for locking the key in the currently selected object. */
- (void) BXLockKey: (NSString *) key status: (enum BXObjectStatus) status editor: (id) editor
{
    [self BXLockObject: [self selection] key: key status: status editor: editor];
}

- (void) BXUnlockKey: (NSString *) key editor: (id) editor
{
    [self BXUnlockObject: [self selection] key: key editor: editor];
}
@end


@implementation NSController (BXCocoaAdditions)

/** Lock an object asynchronously. */
- (void) BXLockObject: (BXDatabaseObject *) object key: (NSString *) key 
                  status: (enum BXObjectStatus) status editor: (id) editor
{
    BXDatabaseContext* ctx = [self BXDatabaseContext];
    
    //Replace the proxy with the real object
    if (NO == [object isKindOfClass: [BXDatabaseObject class]] || [object isProxy])
    {
        BXDatabaseObjectID* objectID = [object valueForKey: @"objectID"];
        object = [ctx registeredObjectWithID: objectID];
    }
    
    [ctx lockObject: object key: key status: status sender: self];
}

/** Unlock an object synchronously. */
- (void) BXUnlockObject: (BXDatabaseObject *) object key: (NSString *) key editor: (id) editor
{
    BXDatabaseContext* ctx = [self BXDatabaseContext];
    //Replace the proxy with the real object
    if (NO == [object isKindOfClass: [BXDatabaseObject class]] || [object isProxy])
    {
        BXDatabaseObjectID* objectID = [object valueForKey: @"objectID"];
        object = [ctx registeredObjectWithID: objectID];
    }

    [ctx unlockObject: object key: key];
}

/** Handle the error if a lock couldn't be acquired. */
- (void) BXLockAcquired: (BOOL) lockAcquired object: (BXDatabaseObject *) receiver
{
    if (NO == lockAcquired)
    {
        [[self BXWindow] endEditingFor: nil];
        NSError* error = [NSError errorWithDomain: kBXErrorDomain
                                             code: kBXErrorLockNotAcquired
                                         userInfo: nil];
        [self BXHandleError: error];
    }
}

/** Return the database context. */
- (BXDatabaseContext *) BXDatabaseContext
{
    @throw [NSException exceptionWithName: NSInternalInconsistencyException
                                   reason: @"Insufficient functionality; use a subclass provided with the BXCocoa framework instead"
                                 userInfo: nil];
    return nil;
}

/** The window in which all the edited NSControls are. */
- (NSWindow *) BXWindow
{
    return nil;
}

- (void) BXHandleError: (NSError *) error
{
    [[NSAlert alertWithError: error] beginSheetModalForWindow: [self BXWindow] 
                                                modalDelegate: self 
                                               didEndSelector: NULL 
                                                  contextInfo: NULL];
}

@end