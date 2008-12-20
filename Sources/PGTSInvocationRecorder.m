//
// PGTSInvocationRecorder.m
// BaseTen
//
// Copyright (C) 2008 Marko Karppinen & Co. LLC.
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

#import "PGTSFunctions.h"
#import "PGTSInvocationRecorder.h"
#import "PGTSHOM.h"

@class PGTSInvocationRecorder;


@interface PGTSInvocationRecorderHelper
{
@private
	Class isa;
	
@public
	id mTarget;
	NSInvocation* mInvocation;
	PGTSInvocationRecorder* mRecorder; //Weak
}
+ (id) alloc;
@end



@interface PGTSPersistentTargetInvocation : NSInvocation
{
	id mPersistentTarget; //Weak
}
+ (id) invocationWithInvocation: (NSInvocation *) invocation;
@end



@implementation PGTSInvocationRecorder
- (id) init
{
	if ((self = [super init]))
	{
		mHelper = [PGTSInvocationRecorderHelper alloc];
		mHelper->mRecorder = self;
	}
	return self;
}

- (void) dealloc
{
	[mHelper->mInvocation release];
	[mHelper->mTarget release];
	NSDeallocateObject ((id) mHelper);
	[super dealloc];
}

- (NSInvocation *) invocation
{
	return mHelper->mInvocation;
}

- (void) setTarget: (id) target
{
	[mHelper->mTarget release];
	mHelper->mTarget = [target retain];
}

- (void) gotInvocation
{
	if (mOutInvocation)
		*mOutInvocation = mHelper->mInvocation;
}

- (id) record
{
	mOutInvocation = NULL;
	return mHelper;
}

- (id) recordWithTarget: (id) target
{
	[self setTarget: target];
	return [self record];
}

- (id) recordWithTarget: (id) target outInvocation: (NSInvocation **) outInvocation
{
	mOutInvocation = outInvocation;
	[self setTarget: target];
	return mHelper;
}

+ (id) recordWithTarget: (id) target outInvocation: (NSInvocation **) outInvocation
{
	PGTSInvocationRecorder* recorder = [[[self alloc] init] autorelease];
	return [recorder recordWithTarget: target outInvocation: outInvocation];
}
@end



@implementation PGTSInvocationRecorderHelper
static void
pgts_unrecognized_selector ()
{
}

+ (void) initialize
{
	//This is required by the runtime.
}

- (void) finalize
{
	//This is required by the runtime.
}

+ (id) alloc
{
	return NSAllocateObject (self, 0, NULL);
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) selector
{
	NSMethodSignature* signature = [mTarget methodSignatureForSelector: selector];
	if (! signature)
	{
		pgts_unrecognized_selector ();
		//We need to raise an exception because we don't implement -doesNotRecognizeSelector.
		[NSException raise: NSInvalidArgumentException format: @"%@ does not respond to %s.", mTarget, selector];
	}
	return signature;
}

- (void) forwardInvocation: (NSInvocation *) anInvocation
{
	[mInvocation autorelease];
	mInvocation = [anInvocation retain];
	[mInvocation setTarget: mTarget];
	[mRecorder gotInvocation];
}
@end



@implementation PGTSPersistentTargetInvocation
+ (id) invocationWithInvocation: (NSInvocation *) invocation
{
	NSMethodSignature* sig = [invocation methodSignature];
	id retval = [self invocationWithMethodSignature: sig];
	[retval setSelector: [invocation selector]];
	[retval setTarget: [invocation target]];
	
	//We could save some space by getting the largest argument but this is easier.
	NSUInteger size = [sig frameLength];
	void* argumentBuffer = alloca (size);	
	for (NSUInteger i = 2, count = [sig numberOfArguments]; i < count; i++)
	{
		bzero (argumentBuffer, size);
		[invocation getArgument: argumentBuffer atIndex: i];
		[retval setArgument: argumentBuffer atIndex: i];
	}	
	return retval;
}

- (void) setTarget: (id) target
{
	mPersistentTarget = target;
}

- (id) target
{
	return mPersistentTarget;
}

- (void) invoke
{
	[self invokeWithTarget: mPersistentTarget];
}
@end



@implementation PGTSPersistentTargetInvocationRecorder
- (void) gotInvocation
{
	if (mOutInvocation)
		*mOutInvocation = mHelper->mInvocation;
}

- (NSInvocation *) invocation
{
	return mHelper->mInvocation;
}
@end



@implementation PGTSCallbackInvocationRecorder
- (void) dealloc
{
	[mUserInfo release];
	[mCallbackTarget release];
	[super dealloc];
}

- (void) gotInvocation
{
	[mCallbackTarget performSelector: mCallback withObject: mHelper->mInvocation withObject: mUserInfo];
}

- (void) setCallback: (SEL) callback
{
	mCallback = callback;
}

- (void) setUserInfo: (id) anObject
{
	if (mUserInfo != anObject)
	{
		[mUserInfo release];
		mUserInfo = [anObject retain];
	}
}

- (id) userInfo
{
	return mUserInfo;
}

- (void) setCallbackTarget: (id) anObject
{
	if (mCallbackTarget != anObject)
	{
		[mCallbackTarget release];
		mCallbackTarget = [anObject retain];
	}
}
@end


@implementation PGTSHOMInvocationRecorder
- (void) setCallback: (SEL) callback target: (id) target
{
	[self setCallback: callback];
	[self setCallbackTarget: target];
	[self setTarget: [mCallbackTarget PGTSAny]];
}
@end
