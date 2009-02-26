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
#import "PGTSHOM.h"
#import <tr1/unordered_map>

typedef std::tr1::unordered_map <unichar, NSMutableArray*,
	std::tr1::hash <unichar>,
	std::equal_to <unichar>,
	PGTS::scanned_memory_allocator <std::pair <const unichar, NSMutableArray*> > > 
	ChangeMap;


@interface PGTSColumnDescription (BXPGModificationHandlerAdditions)
- (NSString *) columnDefinition;
@end


@implementation PGTSColumnDescription (BXPGModificationHandlerAdditions)
- (NSString *) columnDefinition
{
	NSString* retval = nil;
	PGTSTypeDescription* type = [self type];
	NSString* schemaName = [[type schema] name];
	if (schemaName)
		retval = [NSString stringWithFormat: @"\"%@\" \"%@\".\"%@\"", [self name], schemaName, [type name]];
	else
		retval = [NSString stringWithFormat: @"\"%@\" \"%@\"", [self name], [type name]];
		
	return retval;
}
@end


@implementation BXPGModificationHandler
- (void) dealloc
{
	[mQueryString release];
	[super dealloc];
}

- (void) prepare
{
	[super prepare];
	
	BXPGTableDescription* rel = [mInterface tableForEntity: mEntity];
	PGTSIndexDescription* pkey = [rel primaryKey];
	NSArray* columns = [[[pkey columns] allObjects] sortedArrayUsingSelector: @selector (indexCompare:)];
	NSString* pkeyString = [(id) [[columns PGTSCollect] columnDefinition] componentsJoinedByString: @", "];
	
	NSString* queryFormat = 
	@"SELECT * FROM \"baseten\".modification ($1, $2, $3, $4) "
	@"AS m ( "
	@"\"baseten_modification_type\" character (1), "
	@"\"baseten_modification_timestamp\" timestamp (6) without time zone, "
	@"\"baseten_modification_insert_timestamp\" timestamp (6) without time zone, "
	@"%@)";
    mQueryString = [[NSString alloc] initWithFormat: queryFormat, pkeyString];
}

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
	
	PGTSResultSet* res = [mConnection executeQuery: mQueryString 
										parameters: PGTSOidAsObject (mOid), [NSNumber numberWithBool: isIdle], mLastCheck, [NSNumber numberWithInt: backendPID]];
	BXAssertVoidReturn ([res querySucceeded], @"Expected query to succeed: %@", [res error]);
	
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
	ChangeMap::const_iterator iterator = changes->begin ();
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
	
	//Contents have already been autoreleased.
	delete changes;
}

- (void) setOid: (Oid) oid
{
	mOid = oid;
}
@end
