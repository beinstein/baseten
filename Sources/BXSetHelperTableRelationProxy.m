//
// BXSetHelperTableRelationProxy.m
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

#import "BXSetHelperTableRelationProxy.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXDatabaseContext.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXManyToManyRelationshipDescription.h"
#import "BXForeignKey.h"
#import "BXEntityDescription.h"


/**
 * \internal
 * An NSCountedSet-style self-updating container proxy for many-to-many relationships.
 * \ingroup auto_containers
 */
//FIXME: this needs to be changed to use set mutation -style KVO notifications.
@implementation BXSetHelperTableRelationProxy
- (void) fetchedForEntity: (BXEntityDescription *) entity predicate: (NSPredicate *) predicate
{
}

- (void) fetchedForRelationship: (BXRelationshipDescription *) rel
						  owner: (BXDatabaseObject *) databaseObject
							key: (NSString *) key
{
	BXManyToManyRelationshipDescription* relationship = (id) rel;
	BXEntityDescription* entity = [relationship helperEntity];
	[self setEntity: entity];
	[self setRelationship: relationship];
	[self setOwner: databaseObject];
	[self setKey: key];
	[self setFilterPredicate: [relationship filterPredicateFor: databaseObject]];
}

- (NSArray *) objectIDsFromHelperObjectIDs: (NSArray *) ids others: (NSMutableArray *) others
{
	
    //Iterate two times if ids that don't pass the filter should be added to otherObjectIDs
    int count = 1;
    if (others)
        count = 2;
	
	NSArray* faults = [mContext faultsWithIDs: ids];
	NSMutableArray* otherObjects = [NSMutableArray arrayWithCapacity: [faults count]];
	NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: [self owner] 
																  forKey: kBXOwnerObjectVariableName];
	NSArray* filteredObjects = [faults BXFilteredArrayUsingPredicate: mFilterPredicate 
															  others: otherObjects
											   substitutionVariables: ctx];
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [filteredObjects count]];
	
	id filtered [2] = {filteredObjects, otherObjects};
	id target [2] = {retval, others};
	NSSet* fieldNames = [[(BXManyToManyRelationshipDescription *) mRelationship dstForeignKey] fieldNames];
	NSMutableDictionary* pkeyFValues = [NSMutableDictionary dictionaryWithCapacity: [fieldNames count]];

	for (int i = 0; i < count; i++)
	{
		unsigned int count = [filtered [i] count];
		if (0 < count)
		{
			TSEnumerate (currentObject, e, [filtered [i] objectEnumerator])
			{
				[pkeyFValues removeAllObjects];
				TSEnumerate (currentFieldArray, e, [fieldNames objectEnumerator])
				{
					NSString* helperFName = [currentFieldArray objectAtIndex: 0];
					NSString* fName = [currentFieldArray objectAtIndex: 1];
					
					[pkeyFValues setObject: [currentObject primitiveValueForKey: helperFName] forKey: fName];
				}
				BXDatabaseObjectID* objectID = [BXDatabaseObjectID IDWithEntity: [mRelationship destinationEntity] 
															   primaryKeyFields: pkeyFValues];
				[target [i] addObject: objectID];				
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
		NSString* key = [self key];
		[mOwner willChangeValueForKey: key];
        [self handleAddedObjects: [mContext faultsWithIDs: objectIDs]];
		[mOwner didChangeValueForKey: key];
	}
}

- (void) removedObjectsWithIDs: (NSArray *) ids
{
    NSArray* objectIDs = [self objectIDsFromHelperObjectIDs: ids others: nil];
    if (0 < [objectIDs count])
	{
		//See above.
		NSString* key = [self key];
		[mOwner willChangeValueForKey: key];
        [self handleRemovedObjects: [mContext registeredObjectsWithIDs: objectIDs]];
		[mOwner didChangeValueForKey: key];
	}
}

- (void) updatedObjectsWithIDs: (NSArray *) ids
{
    NSMutableArray* removedIDs = [NSMutableArray arrayWithCapacity: [ids count]];
    NSArray* addedIDs = [self objectIDsFromHelperObjectIDs: ids others: removedIDs];
	if (0 < [removedIDs count] || 0 < [addedIDs count])
	{
		//See above.
		NSString* key = [self key];
		[mOwner willChangeValueForKey: key];
		if (0 < [removedIDs count])
			[self handleRemovedObjects: [mContext registeredObjectsWithIDs: removedIDs]];
		if (0 < [addedIDs count])
			[self handleAddedObjects: [mContext faultsWithIDs: addedIDs]];
		[mOwner didChangeValueForKey: key];
	}
}

@end
