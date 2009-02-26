//
// PGTSSchemaDescription.mm
// BaseTen
//
// Copyright (C) 2006-2009 Marko Karppinen & Co. LLC.
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

#import "PGTSSchemaDescription.h"
#import "PGTSHOM.h"
#import "PGTSTableDescription.h"
#import "PGTSCollections.h"
#import "BXLogger.h"


using namespace PGTS;


@implementation PGTSSchemaDescription
- (id) init
{
	if ((self = [super init]))
	{
		mTablesByName = new IdMap ();
		mTableLock = [[NSLock alloc] init];
	}
	return self;
}


- (void) dealloc
{
	for (IdMap::const_iterator it = mTablesByName->begin (); mTablesByName->end () != it; it++)
	{
		[it->first release];
		[it->second release];
	}
	delete mTablesByName;
	
	[mAllTables release];
	[mTableLock release];
	[super dealloc];
}


- (void) finalize
{
	delete mTablesByName;
	[super finalize];
}


- (PGTSTableDescription *) tableNamed: (NSString *) name
{
	Expect (name);
	return FindObject (mTablesByName, name);
}


- (void) addTable: (PGTSTableDescription *) table
{
	ExpectV (table);
	[mTableLock lock];
	if (mAllTables)
	{
		[mAllTables release];
		mAllTables = nil;
	}
	[mTableLock unlock];
	InsertConditionally (mTablesByName, table);
}

- (NSArray *) allTables
{
	[mTableLock lock];
	if (! mAllTables)
	{
		NSMutableArray* tables = [NSMutableArray arrayWithCapacity: mTablesByName->size ()];
		for (IdMap::const_iterator it = mTablesByName->begin (), end = mTablesByName->end ();
			 it != end; it++)
		{
			[tables addObject: it->second];
		}
		mAllTables = [tables copy];
	}
	[mTableLock unlock];
	return [[mAllTables retain] autorelease];
}
@end
