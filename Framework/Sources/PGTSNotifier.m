//
// PGTSNotifier.m
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

#import <PGTS/postgresql/libpq-fe.h>
#import <MKCCollections/MKCCollections.h>
#import "PGTSNotifier.h"
#import "PGTSFunctions.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"
#import "PGTSConstants.h"
#import "PGTSTableInfo.h"
#import "PGTSDatabaseInfo.h"
#import "PGTSConnectionDelegate.h"
#import <Log4Cocoa/Log4Cocoa.h>

//FIXME: change this so that being connection specific is actually enforced

@implementation PGTSNotifier

- (void) setObservesSelfGenerated: (BOOL) aBool
{
    observesSelfGenerated = aBool;
}

- (BOOL) observesSelfGenerated
{
    return observesSelfGenerated;
}

- (NSDate *) lastCheckForTable: (NSString *) table
{
	return [lastChecks objectForKey: table];
}

- (void) setLastCheck: (NSDate *) date forTable: (NSString *) table;
{
	NSDate* oldDate = [lastChecks objectForKey: table];
    if (oldDate != date && (nil == oldDate || NSOrderedAscending == [oldDate compare: date]))
		[lastChecks setObject: date forKey: table];
}

- (id) init
{
    if ((self = [super init]))
    {
        observedTables = [[NSCountedSet alloc] init];
        notificationNames = [MKCDictionary copyDictionaryWithKeyType: kMKCCollectionTypeInteger 
                                                           valueType: kMKCCollectionTypeObject];
        observesSelfGenerated = NO;
		lastChecks = [[NSMutableDictionary alloc] init];
		postedNotifications = [[NSCountedSet alloc] init];
    }
    return self;
}

- (void) finalize
{
	//FIXME: this requires some consideration.
	NS_DURING
		[connection stopListening: self];
	NS_HANDLER
	NS_ENDHANDLER
	[super finalize];
}

- (void) dealloc
{
	NS_DURING
		[connection stopListening: self];
	NS_HANDLER
		log4Warn (@"Failed to execute UNLISTEN; caught exception: %@.", localException);
	NS_ENDHANDLER
				
    [notificationNames release];
    [observedTables release];
    [lastChecks release];
    [sentNotifications release];
	[postedNotifications release];
    [connection release];
    [super dealloc];
}

- (void) removeObserverForTable: (PGTSTableInfo *) tableInfo
			   notificationName: (NSString *) notificationName
{
	if ([postedNotifications containsObject: notificationName])
	{
		[[tableInfo retain] autorelease];
		[postedNotifications removeObject: notificationName];
		if (0 == [postedNotifications countForObject: notificationName])
			[[NSNotificationCenter defaultCenter] removeObserver: delegate name: notificationName object: tableInfo];
		[observedTables removeObject: tableInfo];
		[lastChecks removeObjectForKey: [notificationNames objectAtIndex: [tableInfo oid]]];
		[self removeNotificationIfNeeded: tableInfo];
	}
}

- (void) removeNotificationIfNeeded: (PGTSTableInfo *) tableInfo
{
}

- (NSArray *) sentNotifications
{
    return nil;
}

- (BOOL) observeTable: (PGTSTableInfo *) tableInfo selector: (SEL) aSelector 
	 notificationName: (NSString *) notificationName
{
    return NO;
}

- (BOOL) observeTable: (PGTSTableInfo *) tableInfo selector: (SEL) aSelector  
	 notificationName: (NSString *) notificationName notificationQuery: (NSString *) query
{
    BOOL rval = NO;
    
    [observedTables addObject: tableInfo];
    unsigned int count = [observedTables countForObject: tableInfo];
    if (1 < count)
    {
        rval = YES;
    }
    else if (1 == count)
    {
        Oid oid = [tableInfo oid];
		log4AssertValueReturn (nil != connection, NO, @"Expected to have a connection.");
                
        PGTSResultSet* res = [connection executeQuery: query
                                           parameters: PGTSOidAsObject (oid)];
        log4Debug (@"Notification query res: %@", res);
        if (YES == [res querySucceeded])
        {
            rval = YES;
            [res advanceRow];
            NSString* nname = [res valueForFieldNamed: @"nname"];
#if 0
            //Remove slashes
            nname = [nname substringWithRange: NSMakeRange (1, [nname length] - 2)];
#endif
            [notificationNames setObject: nname atIndex: oid];
            
            log4Debug (@"Notification name: %@", nname);
            [connection startListening: self forNotification: nname
                              selector: @selector (handleNotification:) sendQuery: NO];
        }
    }
    
    if (YES == rval)
    {
		if (0 == [postedNotifications countForObject: notificationName])
		{
			if (nil != notificationName)
				[[NSNotificationCenter defaultCenter] addObserver: delegate selector: aSelector
															 name: notificationName object: self];
			else
			{            
				TSEnumerate (notification, e, [[self sentNotifications] objectEnumerator])
				{
					[[NSNotificationCenter defaultCenter] addObserver: delegate selector: aSelector
																 name: notification object: self];
				}
			}
		}
		[postedNotifications addObject: notificationName];
    }
    
    return rval;
}

- (BOOL) observe: (NSNotification *) notification
{
    log4AssertValueReturn (nil != connection, NO, @"Expected to have a connection.");
    NSDictionary* userInfo = [notification userInfo];
    NSNumber* backendPID = [NSNumber numberWithInt: [connection backendPID]];
    return (observesSelfGenerated || NO == [[userInfo objectForKey: kPGTSBackendPIDKey] isEqualToNumber: backendPID]);
}

- (PGTSConnection *) connection
{
    return connection; 
}
- (void) setConnection: (PGTSConnection *) aConnection
{
    if (connection != aConnection) {
        [connection stopListening: self];
        [connection release];
        connection = [aConnection retain];
    }
}

- (BOOL) shouldHandleNotification: (NSNotification *) notification
{
    BOOL rval = NO;
    if (YES == delegateDecidesNotificationPosting)
    {
        rval = [delegate PGTSNotifierShouldHandleNotification: notification
                                             fromTableWithOid: [notificationNames indexOfObject: [notification name]]];
    }
    else
    {
        NSDictionary* userInfo = [notification userInfo];
        NSNumber* backendPID = [NSNumber numberWithInt: [connection backendPID]];
        if (observesSelfGenerated || NO == [[userInfo objectForKey: kPGTSBackendPIDKey] isEqualToNumber: backendPID])
            rval = YES;
    }
    return rval;
}

- (void) setDelegate: (id) anObject
{
	delegate = anObject;
	delegateDecidesNotificationPosting =
		[delegate respondsToSelector: @selector (PGTSNotifierShouldHandleNotification:fromTableWithOid:)];
}

@end
