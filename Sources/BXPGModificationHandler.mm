//
// BXPGModificationHandler.mm
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

#import "BXPGModificationHandler.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "PGTSScannedMemoryAllocator.h"
#import <tr1/unordered_map>

typedef std::tr1::unordered_map <unichar, NSMutableArray*,
	std::tr1::hash <unichar>,
	std::equal_to <unichar>,
	PGTS::scanned_memory_allocator <std::pair <const unichar, NSMutableArray*> > > 
	ChangeMap;


@implementation BXPGModificationHandler
- (void) handleNotification: (PGTSNotification *) notification
{
	int backendPID = [mEntity getsChangedByTriggers] ? 0 : [mConnection backendPID];
	[self checkModifications: backendPID];
}

- (void) checkModifications: (int) backendPID
{
    //When observing self-generated modifications, also the ones that still have NULL values for 
    //pgts_modification_timestamp should be included in the query.	
	BOOL isIdle = (PQTRANS_IDLE == [mConnection transactionStatus]);
	
    NSString* query = [NSString stringWithFormat: @"SELECT * FROM %@ ($1, $2::timestamp, $3)", mTableName];
	PGTSResultSet* res = [mConnection executeQuery: query parameters: [NSNumber numberWithBool: isIdle], mLastCheck, [NSNumber numberWithInt: backendPID]];
	
	//Update the timestamp.
	while ([res advanceRow]) 
		[self setLastCheck: [res valueForKey: @"baseten_modification_timestamp"]];
	
	//Sort the changes by type.
	ChangeMap* changes = new ChangeMap (3);
	[res goBeforeFirstRow];
    while ([res advanceRow])
    {
		NSDictionary* row = [res currentRowAsDictionary];
		unichar modificationType = [[row valueForKey: @"baseten_modification_type"] characterAtIndex: 0];                            
		NSMutableArray* objectIDs = (* changes) [modificationType];
		if (! objectIDs)
		{
			objectIDs = [NSMutableArray arrayWithCapacity: [res count]];
			(* changes) [modificationType] = objectIDs;
		}
		
		BXDatabaseObjectID* objectID = [BXDatabaseObjectID IDWithEntity: mEntity primaryKeyFields: row];
		[objectIDs addObject: objectID];
	}
	
	//Send changes.
	ChangeMap::iterator iterator = changes->begin ();
    while (changes->end () != iterator)
    {
		unichar type = iterator->first;
		NSArray* objectIDs = iterator->second;
		switch (type)
		{
			case 'I':
				[[mInterface databaseContext] addedObjectsToDatabase: objectIDs];
				break;
				
			case 'U':
				[[mInterface databaseContext] updatedObjectsInDatabase: objectIDs faultObjects: YES];
				break;
				
			case 'D':
				[[mInterface databaseContext] deletedObjectsFromDatabase: objectIDs];
				break;
				
			default:
				break;
		}
        iterator++;
    }
	
	//Contents are already autoreleased.
	delete changes;
}
@end
