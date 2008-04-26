//
// PGTSHOM.m
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

#import "PGTSHOM.h"

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


@interface PGTSHOMInvocationRecorder : PGTSInvocationRecorder
{
}
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
+ (id) alloc
{
	return NSAllocateObject (self, 0, NULL);
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) selector
{
	return [mTarget methodSignatureForSelector: selector];
}

- (void) forwardInvocation: (NSInvocation *) anInvocation
{
	[mInvocation autorelease];
	mInvocation = [anInvocation retain];
	[mRecorder gotInvocation];
}
@end


@implementation PGTSHOMInvocationRecorder
- (void) gotInvocation
{
	//FIXME: what now?
}
@end
