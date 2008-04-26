//
// PGTSAbstractDescription.m
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

#import "PGTSAbstractDescription.h"
#import "PGTSConstants.h"
#import "PGTSConnection.h"
#import "PGTSHOM.h"


@class PGTSInvocationRecorder;


@implementation PGTSAbstractDescriptionProxy

- (void) dealloc
{
	[mDescription release];
	[mInvocationRecorder release];
	[super dealloc];
}

- (id) initWithConnection: (PGTSConnection *) connection
			  description: (PGTSAbstractDescription *) anObject
{
	mConnection = connection;
	mDescription = [anObject retain];
	return self;
}

- (id) invocationRecorder
{
	if (! mInvocationRecorder)
	{
		mInvocationRecorder = [[PGTSInvocationRecorder alloc] init];
		[mInvocationRecorder setTarget: mDescription];
	}
	return mInvocationRecorder;
}

- (PGTSDatabaseDescription *) database
{
	return [mConnection databaseDescription];
}

- (PGTSConnection *) connection;
{
	return mConnection;
}

- (id) performSynchronizedAndReturnObject
{
	id retval = nil;
	[self performSynchronizedOnDescription: [mInvocationRecorder invocation]];
	[[mInvocationRecorder invocation] getReturnValue: &retval];
	return retval;
}

- (void) performSynchronizedOnDescription: (NSInvocation *) invocation
{
	BOOL responded = NO;
	@synchronized (mDescription)
	{
		[mDescription setConnection: mConnection];
		[mDescription setDescriptionProxy: self];
		
	    SEL selector = [invocation selector];
	    if ([mDescription respondsToSelector: selector])
		{
			responded = YES;
	        [invocation invokeWithTarget: mDescription];
		}
		
		[mDescription setConnection: nil];
		[mDescription setDescriptionProxy: nil];
	}	
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) selector
{
	NSMethodSignature* retval = [super methodSignatureForSelector: selector];
	if (! retval)
		retval = [mDescription methodSignatureForSelector: selector];
	return retval;
}

- (void) forwardInvocation: (NSInvocation *) invocation
{
	[self performSynchronizedOnDescription: invocation];
}
@end


/** 
 * Abstract base class
 */
@implementation PGTSAbstractDescription

+ (BOOL) accessInstanceVariablesDirectly
{
    return NO;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [mName release];
    [super dealloc];
}

- (Class) proxyClass
{
	NSLog (@"-proxyClass not implemented in %@", [self class]);
	return Nil;
}

- (id) proxy
{
	return [[[[self proxyClass] alloc] initWithConnection: mConnection description: self] autorelease];
}

- (NSString *) name
{
    return mName;
}

- (void) setName: (NSString *) aString
{
    if (aString != mName)
    {
        [mName release];
        mName = [aString copy];
    }
}

- (void) setConnection: (PGTSConnection *) aConnection
{
    mConnection = aConnection;
}

- (void) setDescriptionProxy: (PGTSAbstractDescriptionProxy *) aProxy
{
	mProxy = aProxy;
}

/**
 * Retain on copy.
 */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}

- (BOOL) isEqual: (id) anObject
{
    BOOL retval = NO;
    if (NO == [anObject isKindOfClass: [self class]])
        retval = [super isEqual: anObject];
    else
    {
        PGTSAbstractDescription* anInfo = (PGTSAbstractDescription *) anObject;
        retval = [mName isEqualToString: anInfo->mName];
    }
    return retval;
}

- (unsigned int) hash
{
    if (0 == mHash)
        mHash = ([mName hash]);
    return mHash;
}

- (PGTSDatabaseDescription *) database
{
	[NSException raise: NSInternalInconsistencyException format: @"-[PGTSAbstractDescription database] called."];
	return nil;
}

- (PGTSConnection *) connection;
{
	[NSException raise: NSInternalInconsistencyException format: @"-[PGTSAbstractDescription connection] called."];
	return nil;
}
@end
