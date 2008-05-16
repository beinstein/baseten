//
// BXPGLockHandler.m
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
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

#import "BXPGLockHandler.h"


@implementation BXPGLockHandler
- (void) handleNotification: (PGTSNotification *) notification
{
    //When observing self-generated modifications, also the ones that still have NULL values for 
    //pgts_modification_timestamp should be included in the query.
    NSNumber* backendPID = nil;
    if (observesSelfGenerated)
		backendPID = [NSNumber numberWithInt: 0];
	else
        backendPID = [NSNumber numberWithInt: [connection backendPID]];
    
    NSString* query = [NSString stringWithFormat: @"SELECT * FROM %@ ($1, $2::timestamp, $3)", modificationTableName];
	NSArray* parameters = [NSArray arrayWithObjects: 
						   [NSNumber numberWithBool: PQTRANS_IDLE == [connection transactionStatus]],
						   [self lastCheckForTable: modificationTableName], 
						   backendPID, 
						   nil];
	PGTSResultSet* res = [self checkModificationsInTableNamed: modificationTableName
														query: query 
												   parameters: parameters];
    if ([res advanceRow])
    {
		NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
		NSMutableDictionary* baseUserInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											 connection, kPGTSConnectionKey,
											 backendPID, kPGTSBackendPIDKey,
											 nil];		
        unichar lastType = '\0';
        NSMutableArray* rows = [NSMutableArray array];
        
        for (unsigned int i = 0, count = [res countOfRows]; i <= count; i++)
        {
            NSDictionary* row = [res currentRowAsDictionary];
            unichar modificationType = [[row valueForKey: @"" PGTS_SCHEMA_NAME "_modification_type"] characterAtIndex: 0];                            
            
            if (('\0' != lastType && modificationType != lastType) || i == count)
            {
                //Send the notification
                NSString* notificationName = PGTSModificationName (lastType);
                NSMutableDictionary* userInfo = [[baseUserInfo mutableCopy] autorelease];
                
                [userInfo setObject: [[rows copy] autorelease] forKey: kPGTSRowsKey];
                [nc postNotificationName: notificationName 
                                  object: self
                                userInfo: userInfo];
                sendCount++;
                [rows removeAllObjects];
            }
            
            [rows addObject: row];
            lastType = modificationType;
            [res advanceRow];
        }        
    }	
}
@end
