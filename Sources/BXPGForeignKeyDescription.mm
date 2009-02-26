//
// BXPGForeignKeyDescription.mm
// BaseTen
//
// Copyright (C) 2006-2009 Marko Karppinen & Co. LLC.
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


#import "BXPGForeignKeyDescription.h"
#import "BXLogger.h"
#import <iterator>


using namespace PGTS;


@implementation BXPGForeignKeyDescription
- (id) init
{
	if ((self = [super init]))
	{
		mFieldNames = new RetainingIdPairSet ();
		Expect (0 == pthread_rwlock_init (&mFieldNameLock, NULL));
	}
	return self;
}

- (void) dealloc
{
	delete mFieldNames;
	pthread_rwlock_destroy (&mFieldNameLock);
	[super dealloc];
}

- (void) finalize
{
	delete mFieldNames;
	pthread_rwlock_destroy (&mFieldNameLock);
	[super finalize];
}

- (void) addSrcFieldName: (NSString *) srcFName dstFieldName: (NSString *) dstFName
{
	pthread_rwlock_wrlock (&mFieldNameLock);
	mFieldNames->insert (RetainingIdPair (srcFName, dstFName));
	pthread_rwlock_unlock (&mFieldNameLock);
}

- (NSDeleteRule) deleteRule
{
	return mDeleteRule;
}

- (void) setDeleteRule: (NSDeleteRule) aRule
{
	mDeleteRule = aRule;
}

- (void) iterateColumnNames: (void (*)(NSString* srcName, NSString* dstName, void* context)) callback context: (void *) context
{
	pthread_rwlock_rdlock (&mFieldNameLock);
	for (RetainingIdPairSet::const_iterator it = mFieldNames->begin (), end = mFieldNames->end ();
		 it != end; it++)
	{
		callback (it->first, it->second, context);
	}
	pthread_rwlock_unlock (&mFieldNameLock);
}

- (void) iterateReversedColumnNames: (void (*)(NSString* dstName, NSString* srcName, void* context)) callback context: (void *) context
{
	pthread_rwlock_rdlock (&mFieldNameLock);
	for (RetainingIdPairSet::const_iterator it = mFieldNames->begin (), end = mFieldNames->end ();
		 it != end; it++)
	{
		callback (it->second, it->first, context);
	}
	pthread_rwlock_unlock (&mFieldNameLock);
}

- (NSUInteger) numberOfColumns
{
	NSUInteger retval = 0;
	pthread_rwlock_rdlock (&mFieldNameLock);
	retval = mFieldNames->size ();
	pthread_rwlock_unlock (&mFieldNameLock);
	return retval;
}
@end
