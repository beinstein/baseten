//
// BXConnectionViewManager.m
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
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

#import "BXConnectionViewManager.h"
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseAdditions.h>


static NSNib* gConnectionViewNib = nil;
static NSArray* gManuallyNotifiedKeys = nil;


@implementation BXConnectionViewManager

+ (void) initialize
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        gConnectionViewNib = [[NSNib alloc] initWithNibNamed: @"ConnectionView" 
                                                      bundle: [NSBundle bundleForClass: self]];
        gManuallyNotifiedKeys = [[NSArray alloc] initWithObjects: @"isConnecting", @"useHostname", @"givenHostname", nil];
    }
}

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *) aKey
{
    BOOL rval = NO;
    if (NO == [gManuallyNotifiedKeys containsObject: aKey])
        rval = [super automaticallyNotifiesObserversForKey: aKey];
    return rval;
}

- (id) init
{
    if ((self = [super init]))
    {
		mShowsCancelButton = YES;
        [gConnectionViewNib instantiateNibWithOwner: self topLevelObjects: NULL];
    }
    return self;
}

- (void) dealloc
{
	[[mDatabaseContext notificationCenter] removeObserver: self];
    
    //Top level objects
	[mBonjourListView release];
	[mByHostnameView release];
	[mBonjourArrayController release];
        
	[mNetServiceBrowser release];
	[mDatabaseContext release];
	[mDatabaseName release];
	[mNetServiceTimer release];
	[mGivenHostname release];
    
	[super dealloc];
}

- (BOOL) canConnect
{
	//FIXME: return some real value
	return YES;
}

- (void) setConnecting: (BOOL) aBool
{
	if (mIsConnecting != aBool)
	{
		[self willChangeValueForKey: @"isConnecting"];
		mIsConnecting = aBool;
		[self didChangeValueForKey: @"isConnecting"];
	}
}

- (BOOL) isConnecting
{
	return mIsConnecting;
}

- (BOOL) showsOtherButton
{
	return mShowsOtherButton;
}

- (BOOL) useHostname
{
    return mUseHostname;
}

- (BOOL) showsBonjourButton
{
	return mShowsBonjourButton;
}

- (BOOL) showsCancelButton
{
	return mShowsCancelButton;
}

- (void) setShowsOtherButton: (BOOL) aBool
{
	mShowsOtherButton = aBool;
}

- (void) setShowsBonjourButton: (BOOL) aBool
{
	mShowsBonjourButton = aBool;
}

- (void) setShowsCancelButton: (BOOL) aBool
{
	mShowsCancelButton = aBool;
}

- (NSString *) givenHostname
{
	NSString* rval = mGivenHostname;
	if (0 == [rval length])
		rval = nil;
	return rval;
}

- (void) setGivenHostname: (NSString *) aName
{
	if (aName != mGivenHostname && NO == [mGivenHostname isEqualToString: aName])
	{
		[self willChangeValueForKey: @"givenHostname"];
		[mGivenHostname release];
		mGivenHostname = [aName retain];
		[self didChangeValueForKey: @"givenHostname"];
	}
}

- (void) startDiscovery
{
	[mNetServiceTimer release];
	
	if (nil == mNetServiceBrowser)
	{
		mNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
		[mNetServiceBrowser setDelegate: self];
	}
	[mNetServiceBrowser searchForServicesOfType: @"_postgresql._tcp." inDomain: @""];
}

- (void) setDatabaseContext: (BXDatabaseContext *) ctx
{
	if (mDatabaseContext != ctx)
	{
		NSNotificationCenter* nc = [mDatabaseContext notificationCenter];
		[nc removeObserver: self name: kBXConnectionSuccessfulNotification object: mDatabaseContext];
		[nc removeObserver: self name: kBXConnectionFailedNotification object: mDatabaseContext];
		
		[mDatabaseContext release];
		mDatabaseContext = [ctx retain];
	
        nc = [mDatabaseContext notificationCenter];
		[nc addObserver: self selector: @selector (endConnecting:) name: kBXConnectionSuccessfulNotification object: mDatabaseContext];
		[nc addObserver: self selector: @selector (endConnecting:) name: kBXConnectionFailedNotification object: mDatabaseContext];
	}
}

- (BXDatabaseContext *) databaseContext
{
	return mDatabaseContext;
}

- (NSView *) bonjourListView
{
	return mBonjourListView;
}

- (NSView *) byHostnameView
{
    return mByHostnameView;
}

- (void) setDelegate: (id <BXConnectionViewManagerDelegate>) anObject
{
    mDelegate = anObject;
}

- (void) endConnecting: (NSNotification *) notification
{
	[self setConnecting: NO];
}

- (void) setDatabaseName: (NSString *) aName
{
	if (aName != mDatabaseName)
	{
		[mDatabaseName release];
		mDatabaseName = [aName retain];
	}
}

- (NSButton *) bonjourCancelButton
{
	return mBonjourCancelButton;
}

@end


@implementation BXConnectionViewManager (NetServiceBrowserDelegate)
- (void) netServiceBrowser: (NSNetServiceBrowser *) netServiceBrowser 
			didFindService: (NSNetService *) netService moreComing: (BOOL) moreServicesComing
{
	[netService resolveWithTimeout: 5.0];
	[netService retain];
	[netService setDelegate: self];
	
	if (NO == moreServicesComing)
	{
		mNetServiceTimer = [[NSTimer alloc] initWithFireDate: [NSDate dateWithTimeIntervalSinceNow: 10.0]
													interval: 0.0 target: self selector: @selector (startDiscovery)
													userInfo: nil repeats: NO];
	}
}

- (void) netServiceDidResolveAddress: (NSNetService *) netService
{
	[mBonjourArrayController addObject: netService];
	[netService release];
}

- (void) netService: (NSNetService *) netService didNotResolve: (NSDictionary *) errorDict
{
	[mBonjourArrayController addObject: netService];
	[netService release];
}
@end


@implementation BXConnectionViewManager (IBActions)

- (IBAction) connect: (id) sender
{
	[mNetServiceBrowser stop];
	[self setConnecting: YES];
    
    NSURL* databaseURI = nil;
	NSURL* baseURI = [mDatabaseContext databaseURI];
	if (nil == baseURI)
		baseURI = [NSURL URLWithString: @"pgsql:///"];
	
    if (YES == mUseHostname)
    {
        NSString* scheme = [baseURI scheme];
        NSString* uriString = mGivenHostname;
        if (NO == [uriString hasPrefix: scheme])
            uriString = [scheme stringByAppendingString: uriString];
		NSURL* userURI = [NSURL URLWithString: uriString];
		if (nil != userURI)
		{
			databaseURI = [baseURI BXURIForHost: [userURI host] database: mDatabaseName
									   username: [userURI user] password: [userURI password]];
		}
    }
    else
    {
        NSNetService* selection = [[mBonjourArrayController selectedObjects] objectAtIndex: 0];
		databaseURI = [baseURI BXURIForHost: [selection hostName] database: mDatabaseName
								   username: nil password: nil];
    }
	    
    if (nil == databaseURI)
    {
        NSString* title = BXLocalizedString (@"invalidConnectionURI", @"Invalid Connection URI", 
                                             @"Title for dialog");
        NSString* explanation = BXLocalizedString (@"invalidConnectionURIDescription", 
                                                   @"The connection URI could not be resolved.", 
                                                   @"Explanation for dialog");
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            title,          NSLocalizedDescriptionKey,
            explanation,    NSLocalizedFailureReasonErrorKey,
            explanation,    NSLocalizedRecoverySuggestionErrorKey,
            nil];
        
        NSError* error = [NSError errorWithDomain: kBXErrorDomain 
                                             code: kBXErrorMalformedDatabaseURI 
                                         userInfo: userInfo];
        [mDelegate BXHandleError: error];
    }
    else
    {
        [mDatabaseContext setDatabaseURI: databaseURI];
        [mDelegate BXBeginConnecting];
    }
}

- (IBAction) cancelConnecting: (id) sender
{
	[self setConnecting: NO];
    
    [mDelegate BXCancelConnecting];
}

- (IBAction) showBonjourList: (id) sender
{
    [self willChangeValueForKey: @"useHostname"];
    mUseHostname = NO;
    [self didChangeValueForKey: @"useHostname"];
    
    [mDelegate BXShowBonjourListView: mBonjourListView];
	[[mBonjourList window] makeFirstResponder: mBonjourList];
}

- (IBAction) showHostnameView: (id) sender
{
    [self willChangeValueForKey: @"useHostname"];
    mUseHostname = YES;
    [self didChangeValueForKey: @"useHostname"];
    
    [mDelegate BXShowByHostnameView: mByHostnameView];
	[[mHostnameField window] makeFirstResponder: mHostnameField];
}

@end