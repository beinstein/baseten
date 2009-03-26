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
#import "BXEnumerate.h"


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


static id
KeyTrampoline (id self, SEL callback, id userInfo)
{
	id retval = nil;
	if (0 < [self count])
	{
		PGTSCallbackInvocationRecorder* recorder = [[[PGTSCallbackInvocationRecorder alloc] init] autorelease];
		[recorder setCallback: callback];
		[recorder setCallbackTarget: self];
		[recorder setTarget: [[self keyEnumerator] nextObject]];
		retval = [recorder record];
	}
	return retval;
}


static void
CollectAndPerform (id self, id retval, NSInvocation* invocation, NSEnumerator* e)
{
	id currentObject = nil;
	while ((currentObject = [e nextObject]))
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
CollectAndPerformD (id self, NSMutableDictionary* retval, NSInvocation* invocation, NSEnumerator* e)
{
	id currentObject = nil;
	while ((currentObject = [e nextObject]))
	{
		[invocation invokeWithTarget: currentObject];
		id collected = nil;
		[invocation getReturnValue: &collected];
		if (collected)
			[retval setObject: currentObject forKey: collected];
	}
	[invocation setReturnValue: &retval];
}


static void
CollectAndPerformDK (id self, NSMutableDictionary* retval, NSInvocation* invocation, NSEnumerator* e)
{
	id currentObject = nil;
	while ((currentObject = [e nextObject]))
	{
		[invocation invokeWithTarget: currentObject];
		id collected = nil;
		[invocation getReturnValue: &collected];
		if (collected)
			[retval setObject: collected forKey: currentObject];
	}
	[invocation setReturnValue: &retval];
}


static void
Do (NSInvocation* invocation, NSEnumerator* enumerator)
{
	BXEnumerate (currentObject, e, enumerator)
		[invocation invokeWithTarget: currentObject];
}


static id
SelectFunction (id sender, id retval, int (* fptr)(id))
{
	BXEnumerate (currentObject, e, [sender objectEnumerator])
	{
		if (fptr (currentObject))
			[retval addObject: currentObject];
	}
	return retval;
}


static id
SelectFunction2 (id sender, id retval, int (* fptr)(id, void*), void* arg)
{
	BXEnumerate (currentObject, e, [sender objectEnumerator])
	{
		if (fptr (currentObject, arg))
			[retval addObject: currentObject];
	}
	return retval;
}


static void
Visit (NSInvocation* invocation, NSEnumerator* enumerator)
{
	BXEnumerate (currentObject, e, enumerator)
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

- (id) PGTSCollectReturning: (Class) aClass
{
	return HOMTrampoline (self, @selector (PGTSCollect:userInfo:), aClass);
}

- (id) PGTSCollectD
{
	return HOMTrampoline (self, @selector (PGTSCollectD:userInfo:), nil);
}

- (id) PGTSCollectDK
{
	return HOMTrampoline (self, @selector (PGTSCollectDK:userInfo:), nil);
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
	CollectAndPerform (self, retval, invocation, [self objectEnumerator]);
}

- (void) PGTSCollectD: (NSInvocation *) invocation userInfo: (id) ignored
{
	id retval = [[[NSMutableDictionary alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformD (self, retval, invocation, [self objectEnumerator]);
}

- (void) PGTSCollectDK: (NSInvocation *) invocation userInfo: (id) ignored
{
	id retval = [[[NSMutableDictionary alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformDK (self, retval, invocation, [self objectEnumerator]);
}

- (void) PGTSDo: (NSInvocation *) invocation userInfo: (id) anObject
{
	Do (invocation, [self objectEnumerator]);
}

- (void) PGTSVisit: (NSInvocation *) invocation userInfo: (id) userInfo
{
	Visit (invocation, [self objectEnumerator]);
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

- (id) PGTSCollectReturning: (Class) aClass
{
	return HOMTrampoline (self, @selector (PGTSCollect:userInfo:), aClass);
}

- (id) PGTSCollectD
{
	return HOMTrampoline (self, @selector (PGTSCollectD:userInfo:), nil);
}

- (id) PGTSCollectDK
{
	return HOMTrampoline (self, @selector (PGTSCollectDK:userInfo:), nil);
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
	CollectAndPerform (self, retval, invocation, [self objectEnumerator]);
}

- (void) PGTSCollectD: (NSInvocation *) invocation userInfo: (id) ignored
{
	id retval = [[[NSMutableDictionary alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformD (self, retval, invocation, [self objectEnumerator]);
}

- (void) PGTSCollectDK: (NSInvocation *) invocation userInfo: (id) ignored
{
	id retval = [[[NSMutableDictionary alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformDK (self, retval, invocation, [self objectEnumerator]);
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
	return [self PGTSCollectReturning: [NSMutableArray class]];
}

- (id) PGTSCollectReturning: (Class) aClass
{
	return HOMTrampoline (self, @selector (PGTSCollect:userInfo:), aClass);
}

- (id) PGTSCollectD
{
	return HOMTrampoline (self, @selector (PGTSCollectD:userInfo:), nil);
}

- (id) PGTSCollectDK
{
	return HOMTrampoline (self, @selector (PGTSCollectDK:userInfo:), nil);
}

- (id) PGTSKeyCollectD
{
	return KeyTrampoline (self, @selector (PGTSKeyCollectD:userInfo:), nil);
}

- (id) PGTSDo
{
	return HOMTrampoline (self, @selector (PGTSDo:userInfo:), nil);
}

- (id) PGTSVisit: (id) visitor
{
	return VisitorTrampoline (self, visitor, @selector (PGTSVisit:userInfo:), nil);
}

- (void) PGTSCollect: (NSInvocation *) invocation userInfo: (Class) retclass
{
	id retval = [[[retclass alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerform (self, retval, invocation, [self objectEnumerator]);
}

- (void) PGTSCollectD: (NSInvocation *) invocation userInfo: (id) ignored
{
	id retval = [[[NSMutableDictionary alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformD (self, retval, invocation, [self objectEnumerator]);
}

- (void) PGTSCollectDK: (NSInvocation *) invocation userInfo: (id) ignored
{
	id retval = [[[NSMutableDictionary alloc] initWithCapacity: [self count]] autorelease];
	CollectAndPerformDK (self, retval, invocation, [self objectEnumerator]);
}

- (void) PGTSKeyCollectD: (NSInvocation *) invocation userInfo: (id) ignored
{
	id retval = [[[NSMutableDictionary alloc] initWithCapacity: [self count]] autorelease];
	BXEnumerate (currentKey, e, [self keyEnumerator])
	{
		id value = [self objectForKey: currentKey];
		id newKey = nil;
		[invocation invokeWithTarget: currentKey];
		[invocation getReturnValue: &newKey];
		if (newKey)
			[retval setObject: value forKey: newKey];
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
@end
