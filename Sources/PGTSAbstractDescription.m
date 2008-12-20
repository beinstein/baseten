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
#import "PGTSInvocationRecorder.h"
#import "BXLogger.h"


extern inline
id PGTSNilReturn (id anObject);


@implementation PGTSAbstractDescriptionProxy

- (void) dealloc
{
	[mDescription release];
	[mInvocationRecorder release];
	[super dealloc];
}

- (id) initWithConnection: (PGTSConnection *) connection
			  description: (PGTSAbstractDescription *) description
{
	NSAssert (connection, @"Expected connection not to be nil.");
	NSAssert (description, @"Expected description not to be nil.");
	mConnection = connection;
	mDescription = [description retain];
	return self;
}

- (BOOL) respondsToSelector: (SEL) aSel
{
	return [mDescription respondsToSelector: aSel];
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
	NSInvocation* invocation = [mInvocationRecorder invocation];
	[self performSynchronizedOnDescription: invocation];
	[invocation getReturnValue: &retval];
	return retval;
}

- (void) performSynchronizedOnDescription: (NSInvocation *) invocation
{
	NSAssert (mConnection, @"Expected mConnection not to be nil."); 
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

- (id) performSynchronizedAndReturnProxies
{
	id concreteObjects = [self performSynchronizedAndReturnObject];
	[[concreteObjects PGTSDo] setConnection: mConnection];
	id retval = [[concreteObjects PGTSCollect] proxy];
	[[concreteObjects PGTSDo] setConnection: nil];
	return retval;
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) selector
{
	NSMethodSignature* retval = [mDescription methodSignatureForSelector: selector];
	if (! retval)
		retval = [super methodSignatureForSelector: selector];
	return retval;
}

- (void) forwardInvocation: (NSInvocation *) invocation
{
	[self performSynchronizedOnDescription: invocation];
}

- (BOOL) isEqual: (PGTSAbstractDescriptionProxy *) anObject
{
	BOOL retval = NO;
	if ([anObject isKindOfClass: [mDescription class]])
	{
		retval = [mDescription isEqual: anObject->mDescription];
	}
	return retval;
}

- (unsigned int) hash
{
	return [mDescription hash];
}
@end


/** 
 * \internal
 * \brief Abstract base class.
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
	BXLogError (@"-proxyClass not implemented in %@", [self class]);
	return Nil;
}

- (id) proxy
{
	return [[[[self proxyClass] alloc] initWithConnection: mConnection description: self] autorelease];
}

- (NSString *) name
{
	id retval = nil;
	@synchronized (self)
	{
	    retval = [[mName copy] autorelease];
	}
	return retval;
}

- (void) setName: (NSString *) aString
{
	@synchronized (self)
	{
	    if (aString != mName)
	    {
	        [mName release];
	        mName = [aString copy];
	    }
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
 * \internal
 * \brief Retain on copy.
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
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (PGTSConnection *) connection;
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}
@end
