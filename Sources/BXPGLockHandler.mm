//
// BXPGLockHandler.mm
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
#import "BXDatabaseObjectIDPrivate.h"
#import "BXLogger.h"
#import "PGTSAdditions.h"
#import "PGTSScannedMemoryAllocator.h"
#import "PGTSOids.h"
#import <tr1/unordered_map>


struct lock_st 
{
	__strong NSMutableArray* l_for_update;
	__strong NSMutableArray* l_for_delete;
};
typedef std::tr1::unordered_map <Oid, lock_st, 
	std::tr1::hash <Oid>, 
	std::equal_to <Oid>, 
	PGTS::scanned_memory_allocator <std::pair <const Oid, lock_st> > > 
	LockMap;


@implementation BXPGLockHandler
- (void) dealloc
{
	[mLockFunctionName release];
	[mLockTableName release];
	[super dealloc];
}

- (void) setLockTableName: (NSString *) aName
{
	if (mLockTableName != aName)
	{
		[mLockTableName release];
		mLockTableName = [aName retain];
	}
}

- (NSString *) lockFunctionName
{
	return mLockFunctionName;
}

- (void) setLockFunctionName: (NSString *) name
{
	if (mLockFunctionName != name)
	{
		[mLockFunctionName release];
		mLockFunctionName = [name retain];
	}
}

- (void) handleNotification: (PGTSNotification *) notification
{
	int backendPID = [mConnection backendPID];
	if ([notification backendPID] != backendPID)
	{
		NSString* query = 
		@"SELECT * FROM %@ "
		@"WHERE baseten_lock_cleared = false "
		@" AND baseten_lock_timestamp > COALESCE ($1, '-infinity')::timestamp "
		@" AND baseten_lock_backend_pid != $2 "
		@"ORDER BY baseten_lock_timestamp ASC";
		query = [NSString stringWithFormat: query, mLockTableName];
		PGTSResultSet* res = [mConnection executeQuery: query parameters: mLastCheck, [NSNumber numberWithInt: backendPID]];
		
		//Update the timestamp.
		while ([res advanceRow]) 
			[self setLastCheck: [res valueForKey: @"baseten_lock_timestamp"]];
		
		//Sort the locks by relation.
		LockMap* locks = new LockMap ([res count]);
		while ([res advanceRow])
		{
			NSDictionary* row = [res currentRowAsDictionary];
			unichar lockType = [[row valueForKey: @"baseten_lock_query_type"] characterAtIndex: 0];
			Oid reloid = [[row valueForKey: @"baseten_lock_reloid"] PGTSOidValue];
			
			struct lock_st ls = (* locks) [reloid];
			
			NSMutableArray* ids = nil;
			switch (lockType) 
			{
				case 'U':
					ids = ls.l_for_update;
					break;
				case 'D':
					ids = ls.l_for_delete;
					break;
			}
			
			if (! ids)
			{
				ids = [NSMutableArray arrayWithCapacity: [res count]];
				switch (lockType) 
				{
					case 'U':
						ls.l_for_update = ids;
						break;
					case 'D':
						ls.l_for_delete = ids;
						break;
				}
			}
			
			BXDatabaseObjectID* objectID = [BXDatabaseObjectID IDWithEntity: mEntity primaryKeyFields: row];
			[ids addObject: objectID];
		}
		
		//Send changes.
		LockMap::const_iterator iterator = locks->begin ();
		BXDatabaseContext* ctx = [mInterface databaseContext];
		while (locks->end () != iterator)
		{
			lock_st ls = iterator->second;
			if (ls.l_for_update) [ctx lockedObjectsInDatabase: ls.l_for_update status: kBXObjectLockedStatus];
			if (ls.l_for_delete) [ctx lockedObjectsInDatabase: ls.l_for_delete status: kBXObjectDeletedStatus];
		}
		
		delete locks;
	}
}
@end
