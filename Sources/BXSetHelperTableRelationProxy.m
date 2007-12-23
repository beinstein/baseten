//
// BXSetHelperTableRelationProxy.m
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

#import "BXSetHelperTableRelationProxy.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXDatabaseContext.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXManyToManyRelationshipDescription.h"
#import "BXForeignKey.h"


/**
 * An NSCountedSet-style self-updating container proxy for many-to-many relationships.
 * \ingroup AutoContainers
 */
//FIXME: this needs to be changed to use set mutation -style KVO notifications.
@implementation BXSetHelperTableRelationProxy

- (NSArray *) objectIDsFromHelperObjectIDs: (NSArray *) ids others: (NSMutableArray *) otherObjectIDs
{
	NSMutableArray* retval = [NSMutableArray array];
	NSMutableArray* otherHelperIDs = nil;
	
    //Iterate two times if ids that don't pass the filter should be added to otherObjectIDs
    unsigned int count = 1;
    if (nil != otherObjectIDs)
    {
        otherHelperIDs = [NSMutableArray arrayWithCapacity: [ids count]];
        count = 2;
    }
	
	NSArray* helperIDs = [ids BXFilteredArrayUsingPredicate: mFilterPredicate others: otherHelperIDs];
	id filteredIDs [2] = {helperIDs, otherObjectIDs};
	id targetArrays [2] = {retval, otherObjectIDs};
	NSSet* fieldNames = [[(BXManyToManyRelationshipDescription *) mRelationship dstForeignKey] fieldNames];
	NSMutableDictionary* pkeyFValues = [NSMutableDictionary dictionaryWithCapacity: [fieldNames count]];

	for (int i = 0; i < count; i++)
	{
		unsigned int count = [filteredIDs [i] count];
		if (0 < count)
		{
			TSEnumerate (currentHelperID, e, [filteredIDs [i] objectEnumerator])
			{
				[pkeyFValues removeAllObjects];
				NSDictionary* helperValues = [(BXDatabaseObjectID *) currentHelperID allValues];
				TSEnumerate (currentFieldArray, e, [fieldNames objectEnumerator])
				{
					NSString* helperFName = [currentFieldArray objectAtIndex: 0];
					NSString* fName = [currentFieldArray objectAtIndex: 1];
					
					[pkeyFValues setObject: [helperValues objectForKey: helperFName] forKey: fName];
					BXDatabaseObjectID* objectID = [BXDatabaseObjectID IDWithEntity: [mRelationship destinationEntity] 
																   primaryKeyFields: pkeyFValues];
					[targetArrays [i] addObject: objectID];
				}
			}
		}
	}
	return retval;
}

- (void) addedObjectsWithIDs: (NSArray *) ids
{
    NSArray* objectIDs = [self objectIDsFromHelperObjectIDs: ids others: nil];
    if (0 < [objectIDs count])
	{
		//Post notifications since modifying a self-updating collection won't cause
		//value cache to be changed.
		[mOwner willChangeValueForKey: [self key]];
        [self handleAddedObjects: [mContext faultsWithIDs: objectIDs]];
		[mOwner didChangeValueForKey: [self key]];
	}
}

- (void) removedObjectsWithIDs: (NSArray *) ids
{
    NSArray* objectIDs = [self objectIDsFromHelperObjectIDs: ids others: nil];
    if (0 < [objectIDs count])
	{
		//See above.
		[mOwner willChangeValueForKey: [self key]];
        [self handleRemovedObjects: [mContext registeredObjectsWithIDs: objectIDs]];
		[mOwner didChangeValueForKey: [self key]];
	}
}

- (void) updatedObjectsWithIDs: (NSArray *) ids
{
    NSMutableArray* removedIDs = [NSMutableArray arrayWithCapacity: [ids count]];
    NSArray* addedIDs = [self objectIDsFromHelperObjectIDs: ids others: removedIDs];
	if (0 < [removedIDs count] || 0 < [addedIDs count])
	{
		//See above.
		[mOwner willChangeValueForKey: [self key]];
		if (0 < [removedIDs count])
			[self handleRemovedObjects: [mContext registeredObjectsWithIDs: removedIDs]];
		if (0 < [addedIDs count])
			[self handleAddedObjects: [mContext faultsWithIDs: addedIDs]];
		[mOwner didChangeValueForKey: [self key]];
	}
}

@end
