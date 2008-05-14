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
#import "PGTSFunctions.h"

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
//FIXME: testing only.
- (void) doesNotRecognizeSelector: (SEL) aSel
{
	NSLog (@"selector: %s", aSel);
}

+ (void) initialize
{
	//This is required by the runtime.
}

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


@interface PGTSHOMInvocationRecorder : PGTSInvocationRecorder
{
	id mCollection;
	id mUserInfo;
	SEL mCallback;
}
- (void) setCollection: (id) collection callback: (SEL) callback;
- (void) setUserInfo: (id) anObject;
- (id) userInfo;
@end


@implementation PGTSHOMInvocationRecorder
- (void) gotInvocation
{
	[mCollection performSelector: mCallback withObject: mHelper->mInvocation withObject: mUserInfo];
}

- (void) setCollection: (id) collection callback: (SEL) callback
{
	mCallback = callback;
	[mCollection release];
	mCollection = [collection retain];
	
	[self setTarget: [mCollection PGTSAny]];
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
@end


static id
HOMTrampoline (id self, SEL callback, id userInfo)
{
	id retval = nil;
	if (0 < [self count])
	{
		PGTSHOMInvocationRecorder* recorder = [[[PGTSHOMInvocationRecorder alloc] init] autorelease];
		[recorder setCollection: self callback: callback];
		[recorder setUserInfo: userInfo];
		retval = [recorder record];
	}
	return retval;
}


static void
CollectAndPerformSetArray (id self, id retval, NSInvocation* invocation)
{
	TSEnumerate (currentObject, e, [self objectEnumerator])
	{
		[invocation invokeWithTarget: currentObject];
		id collected = nil;
		[invocation getReturnValue: &collected];
		if (! collected) collected = [NSNull null];
		[retval addObject: collected];
	}
	[invocation setReturnValue: &retval];
}


static void
Do (NSInvocation* invocation, NSEnumerator* enumerator)
{
	TSEnumerate (currentObject, e, enumerator)
		[invocation invokeWithTarget: currentObject];
}


static id
SelectFunction (id sender, id retval, int (* fptr)(id))
{
	TSEnumerate (currentObject, e, [sender objectEnumerator])
	{
		if (fptr (currentObject))
			[retval addObject: currentObject];
	}
	return retval;
}



@implementation NSSet (PGTSHOM)
- (id) PGTSAny
{
	return [self anyObject];
}

- (id) PGTSCollect
{
	return [self PGTSCollectReturning: [NSMutableSet class]];
}

- (id) PGTSCollectReturning: (Class) aClass
{
	return HOMTrampoline (self, @selector (PGTSCollect:), aClass);
}

- (id) PGTSDo
{
	return HOMTrampoline (self, @selector (PGTSDo:), nil);
}

- (id) PGTSSelectFunction: (int (*)(id)) fptr
{
	id retval = [NSMutableSet setWithCapacity: [self count]];
	return SelectFunction (self, retval, fptr);
}

- (void) PGTSCollect: (NSInvocation *) invocation userInfo: (Class) retclass
{
	id retval = [[[retclass alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformSetArray (self, retval, invocation);
}

- (void) PGTSDo: (NSInvocation *) invocation userInfo: (id) anObject
{
	Do (invocation, [self objectEnumerator]);
}
@end


@implementation NSArray (PGTSHOM)
- (id) PGTSAny
{
	return [self lastObject];
}

- (id) PGTSCollect
{
	return [self PGTSCollectReturning: [NSMutableArray class]];
}

- (id) PGTSCollectReturning: (Class) aClass
{
	return HOMTrampoline (self, @selector (PGTSCollect:), aClass);
}

- (id) PGTSDo
{
	return HOMTrampoline (self, @selector (PGTSDo:), nil);
}

- (id) PGTSSelectFunction: (int (*)(id)) fptr
{
	id retval = [NSMutableArray arrayWithCapacity: [self count]];
	return SelectFunction (self, retval, fptr);
}

- (void) PGTSCollect: (NSInvocation *) invocation userInfo: (Class) retclass
{
	id retval = [[[retclass alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformSetArray (self, retval, invocation);
}

- (void) PGTSDo: (NSInvocation *) invocation
{
	Do (invocation, [self objectEnumerator]);
}
@end


@implementation NSDictionary (PGTSHOM)
- (id) PGTSAny
{
	return [[self objectEnumerator] nextObject];
}

- (id) PGTSCollect
{
	return HOMTrampoline (self, @selector (PGTSCollect:), nil);
}

- (id) PGTSDo
{
	return HOMTrampoline (self, @selector (PGTSDo:), nil);
}

- (void) PGTSCollect: (NSInvocation *) invocation userInfo: (id) userInfo
{
	id retval = [[self mutableCopy] autorelease];
	TSEnumerate (currentKey, e, [self keyEnumerator])
	{
		[invocation invokeWithTarget: [self objectForKey: currentKey]];
		id collected = nil;
		[invocation getReturnValue: &collected];
		if (! collected) collected = [NSNull null];
		[retval setObject: collected forKey: currentKey];
	}
	[invocation setReturnValue: &retval];	
}

- (void) PGTSDo: (NSInvocation *) invocation userInfo: (id) userInfo
{
	Do (invocation, [self objectEnumerator]);
}
@end
