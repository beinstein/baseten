//
// BXConnectionViewManager.m
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
        gManuallyNotifiedKeys = [[NSArray alloc] initWithObjects: @"isConnecting", @"useHostname", nil];
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
        [gConnectionViewNib instantiateNibWithOwner: self topLevelObjects: NULL];
    }
    return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
    
    //Top level objects
	[mBonjourListView release];
	[mByHostnameView release];
	[mBonjourArrayController release];
        
	[mNetServiceBrowser release];
	[mDatabaseContext release];
    
	[super dealloc];
}

- (BOOL) canConnect
{
	//FIXME: return some real value
	return YES;
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

- (void) setShowsOtherButton: (BOOL) aBool
{
	mShowsOtherButton = aBool;
}

- (void) startDiscovery
{
	if (nil == mNetServiceBrowser)
	{
		mNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
		[mNetServiceBrowser setDelegate: self];
	}
	[mNetServiceBrowser searchForBrowsableDomains];
}

- (void) setDatabaseContext: (BXDatabaseContext *) ctx
{
	if (mDatabaseContext != ctx)
	{
		NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
		[nc removeObserver: self name: kBXConnectionSuccessfulNotification object: mDatabaseContext];
		[nc removeObserver: self name: kBXConnectionFailedNotification object: mDatabaseContext];
		
		[mDatabaseContext release];
		mDatabaseContext = [ctx retain];
	
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
    [self willChangeValueForKey: @"isConnecting"];
    mIsConnecting = NO;
    [self didChangeValueForKey: @"isConnecting"];    
}

@end


@implementation BXConnectionViewManager (NetServiceBrowserDelegate)
- (void) netServiceBrowser: (NSNetServiceBrowser *) netServiceBrowser 
			 didFindDomain: (NSString *) domainName moreComing: (BOOL) moreDomainsComing
{
	[netServiceBrowser searchForServicesOfType: @"_postgresql._tcp" inDomain: domainName];
}

- (void) netServiceBrowser: (NSNetServiceBrowser *) netServiceBrowser 
			didFindService: (NSNetService *) netService moreComing: (BOOL) moreServicesComing
{
	[mBonjourArrayController addObject: netService];
}
@end


@implementation BXConnectionViewManager (IBActions)

- (IBAction) connect: (id) sender
{
	[mNetServiceBrowser stop];
	
	[self willChangeValueForKey: @"isConnecting"];
	mIsConnecting = YES;
	[self didChangeValueForKey: @"isConnecting"];
    
    NSURL* databaseURI = nil;
    if (YES == mUseHostname)
    {
        NSString* schema = @"pgsql://";
        NSString* uriString = [mHostnameField stringValue];
        if (NO == [uriString hasPrefix: uriString])
            uriString = [schema stringByAppendingString: uriString];
        databaseURI = [NSURL URLWithString: uriString];
    }
    else
    {
        NSNetService* selection = [[mBonjourArrayController selectedObjects] objectAtIndex: 0];
        databaseURI = [NSURL URLWithString: [NSString stringWithFormat: @"pgsql://%@/%@", 
            [selection hostName], [selection name]]];
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
        [mDatabaseContext connect];
    }
}

- (IBAction) cancelConnecting: (id) sender
{
	[self willChangeValueForKey: @"isConnecting"];
	mIsConnecting = NO;
	[self didChangeValueForKey: @"isConnecting"];
    
    [mDelegate BXCancelConnecting];
}

- (IBAction) showBonjourList: (id) sender
{
    [self willChangeValueForKey: @"useHostname"];
    mUseHostname = YES;
    [self didChangeValueForKey: @"useHostname"];
    
    [mDelegate BXShowBonjourListView: mBonjourListView];
}

- (IBAction) showHostnameView: (id) sender
{
    [self willChangeValueForKey: @"useHostname"];
    mUseHostname = NO;
    [self didChangeValueForKey: @"useHostname"];
    
    [mDelegate BXShowByHostnameView: mByHostnameView];
}

@end