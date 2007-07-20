//
// BXOneToOneRelationshipDescription.m
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
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

#import <Log4Cocoa/Log4Cocoa.h>

#import "BXOneToOneRelationshipDescription.h"
#import "BXDatabaseObject.h"
#import "BXForeignKey.h"
#import "BXRelationshipDescriptionPrivate.h"


@implementation BXOneToOneRelationshipDescription

- (BOOL) isToMany
{
	return NO;
}

- (BOOL) shouldRemoveForTarget: (id) target 
				databaseObject: (BXDatabaseObject *) databaseObject
					 predicate: (NSPredicate **) predicatePtr
{
	log4AssertValueReturn (NULL != predicatePtr, NO, @"Expected predicatePtr not to be NULL.");
	BOOL retval = NO;
	BXDatabaseObject* oldObject = [databaseObject primitiveValueForKey: [self name]];
	if (nil != oldObject)
	{
		retval = YES;
		NSPredicate* predicate = [[oldObject objectID] predicate];
		*predicatePtr = predicate;
	}
	return retval;
}

- (BOOL) shouldAddForTarget: (id) target 
			 databaseObject: (BXDatabaseObject *) databaseObject
				  predicate: (NSPredicate **) predicatePtr 
					 values: (NSDictionary **) valuePtr
{
	log4AssertValueReturn (NULL != predicatePtr && NULL != valuePtr, NO, @"Expected predicatePtr and valuePtr not to be NULL.");
	BOOL retval = NO;
	if (nil != target)
	{
		retval = YES;
		NSDictionary* values = [mForeignKey srcDictionaryFor: [self destinationEntity] valuesFromDstObject: databaseObject];
		NSPredicate* predicate = [(BXDatabaseObjectID *) [target objectID] predicate];
		*valuePtr = values;
		*predicatePtr = predicate;
	}
	return retval;
}

@end
