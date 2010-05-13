//
// BXHostResolver.h
// BaseTen
//
// Copyright (C) 2010 Marko Karppinen & Co. LLC.
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

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

@class BXHostResolver;


@protocol BXHostResolverDelegate
- (void) hostResolverDidSucceed: (BXHostResolver *) resolver addresses: (NSArray *) addresses;
- (void) hostResolverDidFail: (BXHostResolver *) resolver error: (NSError *) error;
@end



@interface BXHostResolver : NSObject
{
	CFRunLoopRef mRunLoop;
	NSString *mRunLoopMode;
	
	NSString *mNodeName;
	NSArray *mAddresses;
	
	SCNetworkReachabilityRef mReachability;
	CFHostRef mHost;
	CFStreamError mHostError;
	
	id <BXHostResolverDelegate> mDelegate;
}
- (void) resolveHost: (NSString *) host;
- (void) cancelResolution;
@end



@interface BXHostResolver (Accessors)
- (CFRunLoopRef) runLoop;
- (void) setRunLoop: (CFRunLoopRef) runLoop;

- (NSString *) runLoopMode;
- (void) setRunLoopMode: (NSString *) mode;

- (id <BXHostResolverDelegate>) delegate;
- (void) setDelegate: (id <BXHostResolverDelegate>) delegate;
@end
