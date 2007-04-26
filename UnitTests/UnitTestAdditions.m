//
// UnitTestAdditions.m
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

#import "UnitTestAdditions.h"
#import <BaseTen/BXEntityDescriptionPrivate.h>


@implementation BXDatabaseObject (UnitTestAdditions)
- (id) resolveNoncachedRelationshipNamed: (NSString *) aName
{
	NSError* error = nil;
	//BXDatabaseObject caches related objects so for testing purposes we need to fetch using the relationship.
	BXEntityDescription* entity = [[self objectID] entity];
	id <BXRelationshipDescription> rel = [entity relationshipNamed: aName context: mContext error: &error];
	NSAssert (nil == error, [error localizedDescription]);
	id rval = [rel resolveFrom: self to: [entity targetForRelationship: aName] error: &error];
	NSAssert (nil == error, [error localizedDescription]);
	return rval;
}
@end