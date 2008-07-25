//
// BXObjectStatusInfo.m
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

#import "BXObjectStatusInfo.h"
#import "BXDatabaseObject.h"
#import "BXDatabaseObjectPrivate.h"


/**
 * A proxy for retrieving database object status.
 * \see ValueTransformers
 * \ingroup baseten
 */
@implementation BXObjectStatusInfo

+ (id) statusInfoWithTarget: (BXDatabaseObject *) target
{
    return [[[[self class] alloc] initWithTarget: target] autorelease];
}

- (id) initWithTarget: (BXDatabaseObject *) target
{
    checker = [[NSProtocolChecker alloc] initWithTarget: target protocol: @protocol (BXObjectStatusInfo)];
    return self;
}

- (void) dealloc
{
    [checker release];
    [super dealloc];
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) aSelector
{
    return [checker methodSignatureForSelector: aSelector];
}

- (void) forwardInvocation: (NSInvocation *) anInvocation
{
    [anInvocation invokeWithTarget: checker];
}

- (void) addObserver: (NSObject *) anObserver forKeyPath: (NSString *) keyPath 
             options: (NSKeyValueObservingOptions) options context: (void *) context
{
    [[checker target] addObserver: anObserver forKeyPath: @"statusInfo" options: options context: context];
}

- (void) removeObserver: (NSObject *) anObserver forKeyPath: (NSString *) keyPath
{
    [[checker target] removeObserver: anObserver forKeyPath: @"statusInfo"];
}

- (NSNumber *) unlocked
{
    return [NSNumber numberWithBool: ![(id) [checker target] isLockedForKey: nil]];
}

//We have to implement this by hand since this is an NSProxy.
- (id) valueForKeyPath: (NSString *) keyPath
{
    id rval = nil;
    if (NSNotFound == [keyPath rangeOfCharacterFromSet: 
        [NSCharacterSet characterSetWithCharactersInString: @"."]].location)
    {
        SEL selector = NSSelectorFromString (keyPath);
        if ([self respondsToSelector: selector])
            rval = [self performSelector: selector];
        else
            rval = [self valueForKey: keyPath];
    }
    else
    {
        [[NSException exceptionWithName: NSInternalInconsistencyException 
								 reason: [NSString stringWithFormat: @"Keypath shouldn't contain periods but was %@", keyPath]
                               userInfo: nil] raise];
    }
    return rval;
}

/** 
 * Returns a status constant for the given key.
 * The constant may then be passed to value transformers in BaseTenAppKit.
 * \param aKey An NSString that corresponds to a field name.
 * \return An NSValue that contains the constant.
 */
- (id) valueForKey: (NSString *) aKey
{
    enum BXObjectLockStatus rval = kBXObjectNoLockStatus;
    id target = [checker target];
    if ([target isDeleted] || [target lockedForDelete])
        rval = kBXObjectDeletedStatus;
    else if (([target isLockedForKey: aKey]))
        rval = kBXObjectLockedStatus;
    
    return [NSValue valueWithBytes: &rval objCType: @encode (enum BXObjectLockStatus)];
}
@end
