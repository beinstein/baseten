//
// BXManyToManyRelationshipDescription.m
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


#import "BXManyToManyRelationshipDescription.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXDatabaseObject.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseContextPrivate.h"
#import "BXSetHelperTableRelationProxy.h"
#import "BXForeignKey.h"
#import "BXLogger.h"


@implementation BXManyToManyRelationshipDescription

/** Deallocation helper. */
- (void) dealloc2
{
	[mDstForeignKey release];
	[mHelperEntity release];
	[super dealloc2];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"<%@ (%p) name: %@ entity: %@ destinationEntity: %@ helperEntity: %@>",
		[self class], self, [self name], [self entity], [self destinationEntity], mHelperEntity];
}

- (BXForeignKey *) srcForeignKey
{
	return [self foreignKey];
}

- (BXForeignKey *) dstForeignKey
{
	return mDstForeignKey;
}

- (void) setSrcForeignKey: (BXForeignKey *) aKey
{
	[self setForeignKey: aKey];
}

- (void) setDstForeignKey: (BXForeignKey *) aKey
{
	if (mDstForeignKey != aKey)
	{
		[mDstForeignKey release];
		mDstForeignKey = [aKey retain];
	}
}

- (void) setHelperEntity: (BXEntityDescription *) anEntity
{
	if (mHelperEntity != anEntity)
	{
		[mHelperEntity release];
		mHelperEntity = [anEntity retain];
	}
}

- (NSDeleteRule) deleteRule
{
	//Many-to-manys have always this delete rule, since our implementation 
	//modifies the helper table.
	return NSNullifyDeleteRule;
}

- (id) targetForObject: (BXDatabaseObject *) aDatabaseObject error: (NSError **) error
{
	BXAssertValueReturn (NULL != error, nil , @"Expected error to be set.");
	BXAssertValueReturn (nil != aDatabaseObject, nil, @"Expected aDatabaseObject not to be nil.");
	BXAssertValueReturn ([[self entity] isEqual: [aDatabaseObject entity]], nil,
						  @"Expected aDatabaseObject entity to match. Self: %@ aDatabaseObject: %@", self, aDatabaseObject);	
	
	NSPredicate* helperSrcPredicate = [[self srcForeignKey] predicateForSrcEntity: mHelperEntity valuesInObject: aDatabaseObject];
	NSPredicate* helperDstPredicate = [[self dstForeignKey] predicateForSrcEntity: mHelperEntity dstEntity: [self destinationEntity]];
	NSPredicate* predicate = [NSCompoundPredicate andPredicateWithSubpredicates: 
		[NSArray arrayWithObjects: helperSrcPredicate, helperDstPredicate, mPredicate, nil]];
	
	id res = [[aDatabaseObject databaseContext] executeFetchForEntity: [self destinationEntity]
														withPredicate: predicate 
													  returningFaults: YES
													  excludingFields: nil
														returnedClass: [BXSetHelperTableRelationProxy class]
																error: error];
	//We want the helper to be observed instead of our destination entity.
	[(BXSetHelperTableRelationProxy *) res setEntity: mHelperEntity];
	[res setFilterPredicate: helperSrcPredicate];
	[res setRelationship: self];
	[res setOwner: aDatabaseObject];
	[res setKey: [self name]];
	return res;
}

- (void) setTarget: (id) target
		 forObject: (BXDatabaseObject *) aDatabaseObject
			 error: (NSError **) error
{
	BXAssertVoidReturn (NULL != error, @"Expected error to be set.");
	BXAssertVoidReturn (nil != aDatabaseObject, @"Expected aDatabaseObject not to be nil.");
	BXAssertVoidReturn ([[self entity] isEqual: [aDatabaseObject entity]], 
						  @"Expected aDatabaseObject entity to match. Self: %@ aDatabaseObject: %@", self, aDatabaseObject);	
	
	NSString* name = [self name];
		
	//Compare collection to cached values.
	NSSet* oldObjects = [aDatabaseObject primitiveValueForKey: name];
	NSMutableSet* removedObjects = [[oldObjects mutableCopy] autorelease];
	[removedObjects minusSet: target];
	NSMutableSet* addedObjects = [[target mutableCopy] autorelease];
	[addedObjects minusSet: oldObjects];
	
	//First remove old objects from the relationship, then add new ones.
	//FIXME: this could be configurable by the user unless we want to look for
	//       non-empty or maximum size constraints, which are likely CHECK clauses.
	//FIXME: these should be inside a transaction. Use the undo manager?
	BXDatabaseContext* context = [aDatabaseObject databaseContext];
	
	//Remove all objects from current object's set.
	if (0 < [removedObjects count])
	{
		NSMutableArray* parts = [NSMutableArray arrayWithCapacity: [removedObjects count]];
		
		TSEnumerate (currentObject, e, [removedObjects objectEnumerator])
			[parts addObject: [[self dstForeignKey] predicateForSrcEntity: mHelperEntity valuesInObject: currentObject]];
		
		NSPredicate* srcPredicate = [[self srcForeignKey] predicateForSrcEntity: mHelperEntity valuesInObject: aDatabaseObject];
		NSPredicate* dstPredicates = [NSCompoundPredicate orPredicateWithSubpredicates: parts];
		NSPredicate* predicate = [NSCompoundPredicate andPredicateWithSubpredicates: [NSArray arrayWithObjects: srcPredicate, dstPredicates, nil]];
		[context executeDeleteFromEntity: mHelperEntity
						   withPredicate: predicate 
								   error: error];
	}
	
	if (nil == *error)
	{
		//Add objects to current object's set.
		//First get values for helper entity from source foreign key and then add values from each destination object.
		//Here, src for the foreign key is always mHelper.
		NSDictionary* srcHelperValues = [[self srcForeignKey] srcDictionaryFor: mHelperEntity valuesFromDstObject: aDatabaseObject];
		TSEnumerate (currentObject, e, [addedObjects objectEnumerator])
		{
			NSMutableDictionary* values = [[self dstForeignKey] srcDictionaryFor: mHelperEntity valuesFromDstObject: currentObject];
			[values addEntriesFromDictionary: srcHelperValues];
			[context createObjectForEntity: mHelperEntity
						   withFieldValues: values 
									 error: error];
			
			if (nil != *error)
				break;
		}
		
		//Don't set since if the object has the collection cached, it will be self-updating one.
	}
}

@end
