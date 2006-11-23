//
// TSInvocation.m
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

#import "TSInvocation.h"


@implementation TSInvocation

+ (id) invocationWithInvocation: (NSInvocation *) anInvocation
{
    id rval = [[[self alloc] init] autorelease];
    [rval setInvocation: anInvocation];
    return rval;
}

- (id) init
{
    return self;
}

- (void) dealloc
{
    [invocation release];
    [super dealloc];
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) aSelector
{
    return [NSInvocation instanceMethodSignatureForSelector: aSelector];
}

- (void) forwardInvocation: (NSInvocation *) anInvocation
{
    [anInvocation invokeWithTarget: invocation];
}

- (id) target
{
    return persistentTarget;
}

- (void) setTarget: (id) anObject
{
    persistentTarget = anObject;
}

- (void) invoke
{
    [invocation invokeWithTarget: persistentTarget];
}

- (void) setInvocation: (NSInvocation *) anInvocation
{
    if (invocation != anInvocation) 
    {
        [invocation release];
        invocation = [anInvocation retain];
        
        [self setTarget: [invocation target]];
        [invocation setTarget: nil];
    }
}

@end
