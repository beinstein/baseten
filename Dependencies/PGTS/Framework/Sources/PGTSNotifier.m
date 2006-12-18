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
#import <TSDataTypes/TSDataTypes.h>
#import "PGTSNotifier.h"
#import "PGTSFunctions.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"
#import "PGTSConstants.h"
#import "PGTSTableInfo.h"
#import "PGTSDatabaseInfo.h"


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

- (void) setLastCheck: (NSDate *) date;
{
    if (lastCheck != date && (nil == lastCheck || NSOrderedAscending == [lastCheck compare: date]))
    {
        [lastCheck release];
        lastCheck = [date retain];
    }
}

- (id) init
{
    if ((self = [super init]))
    {
        observedTables = [[NSCountedSet alloc] init];
        notificationNames = [[TSIndexDictionary alloc] init];
        observesSelfGenerated = NO;
    }
    return self;
}

- (void) dealloc
{
    [connection stopListening: self];
    
    [notificationNames release];
    [observedTables release];
    [lastCheck release];
    [sentNotifications release];
    [connection release];
    [super dealloc];
}

- (void) removeObserver: (id) anObject table: (PGTSTableInfo *) tableInfo 
       notificationName: (NSString *) notificationName
{
    [[NSNotificationCenter defaultCenter] removeObserver: anObject name: notificationName object: tableInfo];
    [observedTables removeObject: tableInfo];
    [self removeNotificationIfNeeded: tableInfo];
}

- (void) removeNotificationIfNeeded: (PGTSTableInfo *) tableInfo
{
}

- (NSArray *) sentNotifications
{
    return nil;
}

- (BOOL) addObserver: (id) anObject selector: (SEL) aSelector table: (PGTSTableInfo *) tableInfo 
    notificationName: (NSString *) notificationName
{
    return NO;
}

- (BOOL) addObserver: (id) anObject selector: (SEL) aSelector table: (PGTSTableInfo *) tableInfo 
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
        NSAssert (nil != connection, nil);
                
        PGTSResultSet* res = [connection executeQuery: query
                                           parameters: PGTSOidAsObject (oid)];
        PGTSLog (@"Notification query res: %@", res);
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
            
            PGTSLog (@"Notification name: %@", nname);
            [connection startListening: self forNotification: nname
                              selector: @selector (handleNotification:) sendQuery: NO];
        }
    }
    
    if (YES == rval)
    {
        if (nil != notificationName)
            [[NSNotificationCenter defaultCenter] addObserver: anObject selector: aSelector
                                                         name: notificationName object: self];
        else
        {            
            TSEnumerate (notification, e, [[self sentNotifications] objectEnumerator])
            [[NSNotificationCenter defaultCenter] addObserver: anObject selector: aSelector
                                                         name: notification object: self];
        }
    }
    
    return rval;
}

- (BOOL) observe: (NSNotification *) notification
{
    NSAssert (nil != connection, nil);
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

@end
