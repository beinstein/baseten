//
// BXHostResolver.m
// BaseTen
//
// Copyright (C) 2006-2010 Marko Karppinen & Co. LLC.
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


#import "BXHostResolver.h"
#import "BXLogger.h"
#import "BXError.h"
#import "BXConstants.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <netdb.h>



@interface BXHostResolver (PrivateMethods)
- (void) setNodeName: (NSString *) nodeName;
- (void) setAddresses: (NSArray *) addresses;

- (NSError *) errorForStreamError: (const CFStreamError *) streamError;

- (void) reachabilityCheckDidComplete: (SCNetworkConnectionFlags) flags;
- (void) hostCheckDidComplete: (const CFStreamError *) streamError;

- (void) removeReachability;
- (void) removeHost;
@end



static NSArray * 
CopySockaddrArrayFromAddrinfo (struct addrinfo *addrinfo)
{
	NSMutableArray *retval = [NSMutableArray array];
	while (addrinfo)
	{
		NSData *address = [NSData dataWithBytes: addrinfo->ai_addr length: addrinfo->ai_addrlen];
		[retval addObject: address];
		addrinfo = addrinfo->ai_next;
	}
	return [retval copy];
}


static void
ReachabilityCallback (SCNetworkReachabilityRef target, SCNetworkConnectionFlags flags, void *info)
{
	[(id) info reachabilityCheckDidComplete: flags];
}


static void 
HostCallback (CFHostRef theHost, CFHostInfoType typeInfo, const CFStreamError *error, void *info)
{
	[(id) info hostCheckDidComplete: error];
}



@implementation BXHostResolver
+ (BOOL) getAddrinfo: (struct addrinfo **) outAddrinfo forIPAddress: (NSString *) host
{
	ExpectR (outAddrinfo, NO);
	ExpectR (0 < [host length], NO);
	
	struct addrinfo hints = {
		AI_NUMERICHOST,
		PF_UNSPEC,
		0,
		0,
		0,
		NULL,
		NULL
	};
	int status = getaddrinfo ([host UTF8String], NULL, &hints, outAddrinfo);
	return (0 == status ? YES : NO);
}


- (void) dealloc
{	
	[self removeReachability];
	[self removeHost];
	
	if (mRunLoop)
		CFRelease (mRunLoop);
	
	[mRunLoopMode release];
	[super dealloc];
}


- (void) finalize
{
	[self removeReachability];
	[self removeHost];

	if (mRunLoop)
		CFRelease (mRunLoop);
	
	[super finalize];
}


- (void) cancelResolution
{
	[self removeReachability];
	[self removeHost];
}


- (void) removeReachability
{
	if (mReachability)
	{
		SCNetworkReachabilityUnscheduleFromRunLoop (mReachability, mRunLoop, (CFStringRef) mRunLoopMode);
		SCNetworkReachabilitySetCallback (mReachability, NULL, NULL);
		CFRelease (mReachability);
		mReachability = NULL;
	}
}


- (void) removeHost
{
	if (mHost)
	{
		CFHostCancelInfoResolution (mHost, kCFHostAddresses);
		CFHostUnscheduleFromRunLoop (mHost, mRunLoop, (CFStringRef) mRunLoopMode);
		CFHostSetClient (mHost, NULL, NULL);
		CFRelease (mHost);
		mHost = NULL;
	}
}


- (void) resolveHost: (NSString *) host
{	
	ExpectV (mRunLoop);
	ExpectV (mRunLoopMode);
	ExpectV (host);
	ExpectV ([host characterAtIndex: 0] != '/');	
	
	[self removeReachability];
	[self removeHost];
	bzero (&mHostError, sizeof (mHostError));

	[self setNodeName: host];
	SCNetworkReachabilityContext ctx = {
		0,
		self,
		NULL,
		NULL,
		NULL
	};
	Boolean status = FALSE;
	
	struct addrinfo *addrinfo = NULL;
	if ([[self class] getAddrinfo: &addrinfo forIPAddress: host])
	{
		NSArray *addresses = CopySockaddrArrayFromAddrinfo (addrinfo);
		[self setAddresses: addresses];
		[addresses release];
		
		mReachability = SCNetworkReachabilityCreateWithAddress (kCFAllocatorDefault, addrinfo->ai_addr);
		
		// For some reason the reachability check doesn't work with numeric addresses when using the run loop.
		SCNetworkConnectionFlags flags = 0;
		status = SCNetworkReachabilityGetFlags (mReachability, &flags);
		ExpectL (status)
		
		[self reachabilityCheckDidComplete: flags];
	}
	else
	{
		mReachability = SCNetworkReachabilityCreateWithName (kCFAllocatorDefault, [host UTF8String]);

		status = SCNetworkReachabilitySetCallback (mReachability, &ReachabilityCallback, &ctx);
		ExpectL (status);
		
		status = SCNetworkReachabilityScheduleWithRunLoop (mReachability, mRunLoop, (CFStringRef) mRunLoopMode);
		ExpectL (status);		
	}
	
	if (addrinfo)
		freeaddrinfo (addrinfo);

	[host self]; // For GC.
}


- (void) reachabilityCheckDidComplete: (SCNetworkConnectionFlags) actual
{
	// We use the old type name, since the new one only appeared in 10.6.
	
	[self removeReachability];
	bzero (&mHostError, sizeof (mHostError));
	
	if (mAddresses)
	{
		//Any flag in "required" will suffice. (Hence not 'required == (required & actual)'.)
		SCNetworkConnectionFlags required = kSCNetworkFlagsReachable | kSCNetworkFlagsConnectionAutomatic;	
		if ((required & actual) && [mAddresses count])
			[mDelegate hostResolverDidSucceed: self addresses: mAddresses];
		else
		{
			// The given address was numeric but isn't reachable. Since SCNetworkReachability
			// doesn't provide us with good error messages, we settle with a generic one.
			if (NULL != &kCFStreamErrorDomainSystemConfiguration)
				mHostError.domain = kCFStreamErrorDomainSystemConfiguration;
			[mDelegate hostResolverDidFail: self error: [self errorForStreamError: &mHostError]];
		}
	}
	else
	{
		Boolean status = FALSE;			
		mHost = CFHostCreateWithName (CFAllocatorGetDefault (), (CFStringRef) mNodeName);
		CFHostClientContext ctx = {
			0,
			self,
			NULL,
			NULL,
			NULL
		};
		status = CFHostSetClient (mHost, &HostCallback, &ctx);
		CFHostScheduleWithRunLoop (mHost, mRunLoop, (CFStringRef) mRunLoopMode);
		
		if (! CFHostStartInfoResolution (mHost, kCFHostAddresses, &mHostError))
			[self hostCheckDidComplete: &mHostError];
	}
}


- (void) hostCheckDidComplete: (const CFStreamError *) streamError
{	
	if (streamError && streamError->domain)
	{
		NSError *error = [self errorForStreamError: streamError];
		[mDelegate hostResolverDidFail: self error: error];
	}
	else
	{
		Boolean status = FALSE;
		[mDelegate hostResolverDidSucceed: self addresses: (id) CFHostGetAddressing (mHost, &status)];
	}
	
	[self removeHost];
}


- (NSError *) errorForStreamError: (const CFStreamError *) streamError
{
	// In case the domain field hasn't been set, return a generic error.
	NSError* retval = nil;
	if (streamError)
	{
		// Create an error. The domain field in CFStreamError is a CFIndex, so we need to replace it with something
		// more suitable for NSErrors. According to the documentation, kCFStreamErrorDomainNetDB and
		// kCFStreamErrorDomainSystemConfiguration are avaible in Mac OS X 10.5, so we need to check
		// symbol existence, too.
		NSString* errorTitle = NSLocalizedStringWithDefaultValue (@"connectionError", nil, [NSBundle bundleForClass: [self class]],
																  @"Connection error", @"Title for a sheet.");

		const char* reason = NULL;
		NSString* messageFormat = nil; //FIXME: localization.
		if (NULL != &kCFStreamErrorDomainNetDB && streamError->domain == kCFStreamErrorDomainNetDB)
		{
			reason = (gai_strerror (streamError->error)); //FIXME: check that this returns locale-specific strings.
			if (reason)
				messageFormat = @"The server %@ wasn't found: %s.";
			else
				messageFormat = @"The server %@ wasn't found.";
		}
		else if (NULL != &kCFStreamErrorDomainSystemConfiguration && streamError->domain == kCFStreamErrorDomainSystemConfiguration)
		{
			messageFormat = @"The server %@ wasn't found. Network might be unreachable.";
		}
		else
		{
			messageFormat = @"The server %@ wasn't found.";
		}
		NSString* message = [NSString stringWithFormat: messageFormat, mNodeName, reason];

		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  errorTitle, NSLocalizedDescriptionKey,
								  errorTitle, NSLocalizedFailureReasonErrorKey,
								  message, NSLocalizedRecoverySuggestionErrorKey,
								  [NSValue valueWithBytes: streamError objCType: @encode (CFStreamError)], kBXStreamErrorKey,
								  nil];
		retval = [BXError errorWithDomain: kBXErrorDomain code: kBXErrorHostResolutionFailed userInfo: userInfo];
	}
	return retval;
}
@end



@implementation BXHostResolver (Accessors)
- (void) setNodeName: (NSString *) nodeName
{
	if (nodeName != mNodeName)
	{
		[mNodeName release];
		mNodeName = [nodeName retain];
	}
}


- (void) setAddresses: (NSArray *) addresses
{
	if (addresses != mAddresses)
	{
		[mAddresses release];
		mAddresses = [addresses retain];
	}
}


- (NSString *) runLoopMode;
{
	return mRunLoopMode;
}


- (void) setRunLoopMode: (NSString *) mode
{
	if (mode != mRunLoopMode)
	{
		[self removeHost];
		
		[mRunLoopMode release];
		mRunLoopMode = [mode retain];
	}
}


- (CFRunLoopRef) runLoop
{
	return mRunLoop;
}


- (void) setRunLoop: (CFRunLoopRef) runLoop
{
	if (runLoop != mRunLoop)
	{
		[self removeHost];
		
		if (mRunLoop)
			CFRelease (mRunLoop);
		
		mRunLoop = runLoop;
		
		if (mRunLoop)
			CFRetain (mRunLoop);
	}
}


- (id <BXHostResolverDelegate>) delegate
{
	return mDelegate;
}


- (void) setDelegate: (id <BXHostResolverDelegate>) delegate
{
	mDelegate = delegate;
}
@end
