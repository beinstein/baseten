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
#import "PGTSInvocationRecorder.h"
#import "PGTSFunctions.h"


static id 
VisitorTrampoline (id self, id target, SEL callback, id userInfo)
{
	id retval = nil;
	if (0 < [self count])
	{
		PGTSCallbackInvocationRecorder* recorder = [[[PGTSCallbackInvocationRecorder alloc] init] autorelease];
		[recorder setTarget: target];
		[recorder setCallbackTarget: self];
		[recorder setCallback: callback];
		[recorder setUserInfo: userInfo];
		retval = [recorder record];
	}
	return retval;
}


static id
HOMTrampoline (id self, SEL callback, id userInfo)
{
	id retval = nil;
	if (0 < [self count])
	{
		PGTSHOMInvocationRecorder* recorder = [[[PGTSHOMInvocationRecorder alloc] init] autorelease];
		[recorder setCallback: callback target: self];
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
CollectAndPerformKeysSetArray (id self, id retval, NSInvocation* invocation)
{
	TSEnumerate (currentObject, e, [self objectEnumerator])
	{
		[invocation invokeWithTarget: currentObject];
		id collected = nil;
		[invocation getReturnValue: &collected];
		if (! collected) collected = [NSNull null];
		[retval setObject: collected forKey: currentObject];
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


static id
SelectFunction2 (id sender, id retval, int (* fptr)(id, void*), void* arg)
{
	TSEnumerate (currentObject, e, [sender objectEnumerator])
	{
		if (fptr (currentObject, arg))
			[retval addObject: currentObject];
	}
	return retval;
}


static void
Visit (NSInvocation* invocation, NSEnumerator* enumerator)
{
	TSEnumerate (currentObject, e, enumerator)
	{
		[invocation setArgument: &currentObject atIndex: 2];
		[invocation invoke];
	}
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

- (id) PGTSKeyCollect
{
	return HOMTrampoline (self, @selector (PGTSKeyCollect:userInfo:), nil);
}

- (id) PGTSSelectFunction: (int (*)(id)) fptr
{
	id retval = [NSMutableSet setWithCapacity: [self count]];
	return SelectFunction (self, retval, fptr);
}

- (id) PGTSSelectFunction: (int (*)(id, void*)) fptr argument: (void *) arg
{
	id retval = [NSMutableSet setWithCapacity: [self count]];
	return SelectFunction2 (self, retval, fptr, arg);
}

- (void) PGTSCollect: (NSInvocation *) invocation userInfo: (Class) retclass
{
	id retval = [[[retclass alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformSetArray (self, retval, invocation);
}

- (void) PGTSKeyCollect: (NSInvocation *) invocation userInfo: (id) ignored
{
	id retval = [[[NSMutableDictionary alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformKeysSetArray (self, retval, invocation);
}

- (void) PGTSDo: (NSInvocation *) invocation userInfo: (id) anObject
{
	Do (invocation, [self objectEnumerator]);
}

- (void) PGTSVisit: (NSInvocation *) invocation userInfo: (id) userInfo
{
	Visit (invocation, [self objectEnumerator]);
}

- (id) PGTSCollectReturning: (Class) aClass
{
	return HOMTrampoline (self, @selector (PGTSCollect:userInfo:), aClass);
}

- (id) PGTSDo
{
	return HOMTrampoline (self, @selector (PGTSDo:userInfo:), nil);
}

- (id) PGTSVisit: (id) visitor
{
	return VisitorTrampoline (self, visitor, @selector (PGTSVisit:userInfo:), nil);
}
@end


@implementation NSArray (PGTSHOM)
- (NSArray *) PGTSReverse
{
	return [[self reverseObjectEnumerator] allObjects];
}

- (id) PGTSAny
{
	return [self lastObject];
}

- (id) PGTSCollect
{
	return [self PGTSCollectReturning: [NSMutableArray class]];
}

- (id) PGTSKeyCollect
{
	return HOMTrampoline (self, @selector (PGTSKeyCollect:userInfo:), nil);
}

- (id) PGTSCollectReturning: (Class) aClass
{
	return HOMTrampoline (self, @selector (PGTSCollect:userInfo:), aClass);
}

- (id) PGTSDo
{
	return HOMTrampoline (self, @selector (PGTSDo:userInfo:), nil);
}

- (id) PGTSVisit: (id) visitor
{
	return VisitorTrampoline (self, visitor, @selector (PGTSVisit:userInfo:), nil);
}

- (id) PGTSSelectFunction: (int (*)(id)) fptr
{
	id retval = [NSMutableArray arrayWithCapacity: [self count]];
	return SelectFunction (self, retval, fptr);
}

- (id) PGTSSelectFunction: (int (*)(id, void*)) fptr argument: (void *) arg
{
	id retval = [NSMutableArray arrayWithCapacity: [self count]];
	return SelectFunction2 (self, retval, fptr, arg);
}

- (void) PGTSCollect: (NSInvocation *) invocation userInfo: (Class) retclass
{
	id retval = [[[retclass alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformSetArray (self, retval, invocation);
}

- (void) PGTSKeyCollect: (NSInvocation *) invocation userInfo: (id) ignored
{
	id retval = [[[NSMutableDictionary alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformKeysSetArray (self, retval, invocation);
}

- (void) PGTSDo: (NSInvocation *) invocation userInfo: (id) userInfo
{
	Do (invocation, [self objectEnumerator]);
}

- (void) PGTSVisit: (NSInvocation *) invocation userInfo: (id) userInfo
{
	Visit (invocation, [self objectEnumerator]);
}
@end


@implementation NSDictionary (PGTSHOM)
- (id) PGTSAny
{
	return [[self objectEnumerator] nextObject];
}

- (id) PGTSCollect
{
	return HOMTrampoline (self, @selector (PGTSCollect:userInfo:), nil);
}

- (id) PGTSDo
{
	return HOMTrampoline (self, @selector (PGTSDo:userInfo:), nil);
}

- (id) PGTSVisit: (id) visitor
{
	return VisitorTrampoline (self, visitor, @selector (PGTSVisit:userInfo:), nil);
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

- (void) PGTSKeyCollect: (NSInvocation *) invocation userInfo: (id) userInfo
{
	id retval = [NSMutableDictionary dictionaryWithCapacity: [self count]];
	TSEnumerate (currentKey, e, [self keyEnumerator])
	{
		id collected = nil;
		[invocation invokeWithTarget: currentKey];
		[invocation getReturnValue: &collected];
		if (collected)
			[retval setObject: [self objectForKey: currentKey] forKey: collected];
	}
	[invocation setReturnValue: &retval];
}

- (void) PGTSDo: (NSInvocation *) invocation userInfo: (id) userInfo
{
	Do (invocation, [self objectEnumerator]);
}

- (void) PGTSVisit: (NSInvocation *) invocation userInfo: (id) userInfo
{
	Visit (invocation, [self objectEnumerator]);
}

- (id) PGTSValueSelectFunction: (int (*)(id)) fptr
{
	id retval = [NSMutableArray arrayWithCapacity: [self count]];
	return SelectFunction (self, retval, fptr);
}

- (id) PGTSValueSelectFunction: (int (*)(id, void*)) fptr argument: (void *) arg
{
	id retval = [NSMutableArray arrayWithCapacity: [self count]];
	return SelectFunction2 (self, retval, fptr, arg);
}

- (id) PGTSKeyCollect
{
	id retval = nil;
	if (0 < [self count])
	{
		PGTSCallbackInvocationRecorder* recorder = [[[PGTSCallbackInvocationRecorder alloc] init] autorelease];
		[recorder setCallback: @selector (PGTSKeyCollect:userInfo:)];
		[recorder setCallbackTarget: self];
		[recorder setTarget: [[self allKeys] PGTSAny]];
		retval = [recorder record];
	}
	return retval;
}
@end
