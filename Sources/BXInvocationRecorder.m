//
// BXInvocationRecorder.m
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

#import "BXInvocationRecorder.h"
#import "BXInvocation.h"


/** \internal Records invocations the same way as NSUndoManager. */
@implementation BXInvocationRecorder

+ (id) recorder
{
    return [[[self alloc] init] autorelease];
}

- (id) init
{
    if ((self = [super init]))
    {
        recordedInvocations = [[NSMutableArray alloc] init];
        retainsArguments = YES;
        invocationsRetainTarget = YES;
    }
    return self;
}

- (void) dealloc
{
    [recordedInvocations release];
    [super dealloc];
}

/** 
 * \internal
 * Record an invocation.
 * \attention   Does NOT work with variable argument lists on i386.
 */
- (id) recordWithTarget: (id) anObject
{
    invocationsRetainTarget = YES;
    recordingTarget = anObject;
    return self;
}

/**
 * \internal
 * Record an invocation.
 * \attention   Does NOT work with variable argument lists on i386.
 * \param       anObject        An object that will not be retained.
 */
- (id) recordWithPersistentTarget: (id) anObject
{
    id rval = [self recordWithTarget: anObject];
    invocationsRetainTarget = NO;
    return rval;
}

- (NSInvocation *) recordedInvocation
{
    id rval = [recordedInvocations lastObject];
    [recordedInvocations removeLastObject];
    return rval;
}

- (NSArray *) recordedInvocations
{
    id rval = [[recordedInvocations copy] autorelease];
    [recordedInvocations removeAllObjects];
    return rval;
}

- (void) forwardInvocation: (NSInvocation *) invocation
{
    [invocation setTarget: recordingTarget];
    if (YES == retainsArguments)
    {
        if (NO == invocationsRetainTarget)
            invocation = [BXInvocation invocationWithInvocation: invocation];
        [invocation retainArguments];
    }
    [recordedInvocations addObject: invocation];
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) aSelector
{
    NSMethodSignature* rval = nil;
#if 0
    //+[Class class] always returns self, right?
    if ([recordingTarget class] == recordingTarget)
        rval = [recordingTarget instanceMethodSignatureForSelector: aSelector];
    else
#endif
        rval = [recordingTarget methodSignatureForSelector: aSelector];
    return rval;
}

@end
