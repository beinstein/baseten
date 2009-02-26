//
// BXDatabaseObjectModelStorage.m
// BaseTen
//
// Copyright (C) 2009 Marko Karppinen & Co. LLC.
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

#import "BXDatabaseObjectModelStorage.h"
#import "BXDatabaseObjectModel.h"
#import "PGTSCollections.h"


@implementation BXDatabaseObjectModelStorage
__strong static id gSharedInstance = nil;

+ (void) initialize
{
	static BOOL tooLate = NO;
	if (! tooLate)
	{
		tooLate = YES;
		[self defaultStorage];
	}
}

+ (id) defaultStorage
{
	if (! gSharedInstance)
	{
		gSharedInstance = [[self alloc] init];
	}
	return gSharedInstance;
}

- (id) init
{
	if ((self = [super init]))
	{
		mModelsByURI = PGTSDictionaryCreateMutableWeakNonretainedObjects ();
	}
	return self;
}

- (void) dealloc
{
	[mModelsByURI release];
	[super dealloc];
}

- (BXDatabaseObjectModel *) objectModelForURI: (NSURL *) databaseURI
{
	id retval = nil;
	@synchronized (mModelsByURI)
	{
		retval = [mModelsByURI objectForKey: databaseURI];
		if (retval)
			[[retval retain] autorelease];
		else
		{
			retval = [[[BXDatabaseObjectModel alloc] initWithStorage: self key: databaseURI] autorelease];
			[mModelsByURI setObject: retval forKey: databaseURI];
		}
	}
	return retval;
}

- (void) objectModelWillDeallocate: (NSURL *) key
{
	@synchronized (mModelsByURI)
	{
		[mModelsByURI removeObjectForKey: key];
	}
}
@end
