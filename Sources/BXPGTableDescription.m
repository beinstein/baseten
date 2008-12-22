//
// BXPGTableDescription.m
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

#import "BXPGTableDescription.h"
#import "BXPGDatabaseDescription.h"
#import "PGTSConnection.h"
#import "PGTSResultSet.h"
#import "PGTSIndexDescription.h"
#import "PGTSOids.h"
#import "BXEnumerate.h"


@implementation BXPGTableDescription
- (void) setEnabled: (BOOL) aBool
{
	mIsEnabled = aBool;
}

- (BOOL) isEnabled
{
	return mIsEnabled;
}

- (void) fetchUniqueIndexesForView
{
	if ([(id) [mConnection databaseDescription] hasBaseTenSchema])
	{
		NSString* query = @"SELECT baseten.array_accum (attnum) AS attnum "
		" FROM baseten.primarykey WHERE oid = $1 GROUP BY oid";
		PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject (mOid)];
		if (NO == [res advanceRow])
			[self setUniqueIndexes: [NSArray array]];
		else
		{
			PGTSIndexDescription* index = [[[PGTSIndexDescription alloc] init] autorelease];
			NSMutableSet* indexFields = [NSMutableSet set];
			BXEnumerate (currentFieldIndex, e, [[res valueForKey: @"attnum"] objectEnumerator])
			[indexFields addObject: [self fieldAtIndex: [currentFieldIndex intValue]]];
			[index setPrimaryKey: YES];
			[index setFields: indexFields];
			[index setTable: self];
			[self setUniqueIndexes: [NSArray arrayWithObject: index]];
		}
	}
}
@end
