//
// BXRelationshipDescription.m
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

#import "BXRelationshipDescription.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseObject.h"
#import "BXForeignKey.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseContextPrivate.h"
#import "BXDatabaseAdditions.h"
#import "BXSetRelationProxy.h"
#import "BXDatabaseObjectPrivate.h"
#import "BXLogger.h"


/**
 * A description for one-to-many relationships and a superclass for others.
 * Relationships between entities are defined with foreign keys in the database.
 * \note For this class to work in non-GC applications, the corresponding database context must be retained as well.
 * \ingroup descriptions
 */
@implementation BXRelationshipDescription

- (void) dealloc
{
    [[self entity] removeRelationship: self];
    [super dealloc];
}

/** 
 * \internal
 * Deallocation helper. 
 */
- (void) dealloc2
{
	[mForeignKey release];
	[super dealloc2];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"<%@ (%p) name: %@ entity: %@ destinationEntity: %@>",
		[self class], self, [self name], 
		(void *) [[self entity] name] ?: [self entity], 
		(void *) [[self destinationEntity] name] ?: [self destinationEntity]];
}

/**
 * Destination entity for this relationship.
 */
- (BXEntityDescription *) destinationEntity
{
    return mDestinationEntity;
}

/**
 * Inverse relationship for this relationship.
 * In BaseTen, inverse relationships always exist.
 */
- (BXRelationshipDescription *) inverseRelationship
{
	BXRelationshipDescription* retval = nil;
	if ([mDestinationEntity hasCapability: kBXEntityCapabilityRelationships])
		retval = [[mDestinationEntity relationshipsByName] objectForKey: mInverseName];
	return retval;
}

/**
 * Delete rule for this relationship.
 */
- (NSDeleteRule) deleteRule
{
	//See relationship creation in BXPGInterface.
	return mDeleteRule;
}

/**
 * Whether this relationship is to-many.
 */
- (BOOL) isToMany
{
	return !mIsInverse;
}

- (BOOL) isEqual: (id) anObject
{
	BOOL retval = NO;
	//Foreign keys and destination entities needn't be compared, because relationship names are unique in their entities.
	if (anObject == self || ([super isEqual: anObject] && [anObject isKindOfClass: [self class]]))
		retval = YES;
    return retval;	
}

- (id) mutableCopyWithZone: (NSZone *) zone
{
	BXRelationshipDescription* retval = [super mutableCopyWithZone: zone];
	retval->mDestinationEntity = mDestinationEntity;
	retval->mForeignKey = [mForeignKey copy];
	retval->mInverseName = [mInverseName copy];
	retval->mPredicate = [mPredicate copy];
	retval->mDeleteRule = mDeleteRule;
	retval->mIsInverse = mIsInverse;
	
	return retval;
}

- (enum BXPropertyKind) propertyKind
{
	return kBXPropertyKindRelationship;
}
@end


@implementation BXRelationshipDescription (PrivateMethods)

- (void) setDestinationEntity: (BXEntityDescription *) entity
{
	mDestinationEntity = entity; //Weak;
}

- (void) setForeignKey: (BXForeignKey *) aKey
{
	if (mForeignKey != aKey)
	{
		[mForeignKey release];
		mForeignKey = [aKey retain];
	}
}

- (void) setIsInverse: (BOOL) aBool
{
	mIsInverse = aBool;
}

- (BOOL) isInverse
{
	return mIsInverse;
}

- (void) setInverseName: (NSString *) aString
{
	if (mInverseName != aString)
	{
		[mInverseName release];
		mInverseName = [aString retain];
	}
}

- (id) targetForObject: (BXDatabaseObject *) aDatabaseObject error: (NSError **) error
{
	BXAssertValueReturn (NULL != error, nil , @"Expected error to be set.");
	BXAssertValueReturn (nil != aDatabaseObject, nil, @"Expected aDatabaseObject not to be nil.");
	BXAssertValueReturn ([[self entity] isEqual: [aDatabaseObject entity]], nil, 
						   @"Expected object's entity to match. Self: %@ aDatabaseObject: %@", self, aDatabaseObject);

	id retval = nil;
	//Many-to-many relationships don't call super's implementation, so we can determine from this, if we are to-one.
	if ([self isInverse])
	{
		BXDatabaseObjectID* objectID = [mForeignKey objectIDForDstEntity: [self destinationEntity] fromObject: aDatabaseObject];
		retval = (objectID ? [[aDatabaseObject databaseContext] objectWithID: objectID error: error] : [NSNull null]);
	}
	
	if (! retval)
	{
		NSPredicate* predicate = nil;
		if (mIsInverse)
		{
			//FIXME: this might not be necessary since we already try using the object ID above.
			//We want to select from foreign key's dst entity, which is our destination entity as well.
			predicate = [mForeignKey predicateForDstEntity: [self destinationEntity] valuesInObject: aDatabaseObject];
		}
		else
		{
			//We want to select from foreign key's src entity, which is our destination entity.
			predicate = [mForeignKey predicateForSrcEntity: [self destinationEntity] valuesInObject: aDatabaseObject];
		}
		
		if (nil != mPredicate)
		{
			predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
						 [NSArray arrayWithObjects: predicate, mPredicate, nil]];
		}
		
		//Expression order matters since foreign key is always in src table or view.
		id res = [[aDatabaseObject databaseContext] executeFetchForEntity: [self destinationEntity]
															withPredicate: predicate 
														  returningFaults: YES
														  excludingFields: nil
															returnedClass: [BXSetRelationProxy class]
																	error: error];
		[res setRelationship: self];
		[res setOwner: aDatabaseObject];
		[res setKey: [self name]];
		
		if ([self isToMany])
			retval = res;
		else
		{
			if (0 < [res count])
				retval = [res anyObject];
			else
				retval = [NSNull null];
		}		
	}
	return retval;
}

- (void) setTarget: (id) target
		 forObject: (BXDatabaseObject *) aDatabaseObject
			 error: (NSError **) error
{
	BXAssertVoidReturn (NULL != error, @"Expected error to be set.");
	BXAssertVoidReturn (nil != aDatabaseObject, @"Expected aDatabaseObject not to be nil.");
	BXAssertVoidReturn ([[self entity] isEqual: [aDatabaseObject entity]], 
						  @"Expected object's entity to match. Self: %@ aDatabaseObject: %@", self, aDatabaseObject);	
	
	//We always want to modify the foreign key's (or corresponding view's) entity, hence the branch here.
	if (mIsInverse)
	{		
		NSPredicate* predicate = [[aDatabaseObject objectID] predicate];
		NSDictionary* values = [mForeignKey srcDictionaryFor: [self entity] valuesFromDstObject: target];
		
		[[aDatabaseObject databaseContext] executeUpdateObject: nil
														entity: [self entity]
													 predicate: predicate
												withDictionary: values
														 error: error];
		if (nil == *error)
			[aDatabaseObject setCachedValue: target forKey: [self name]];
	}
	else
	{
		//First remove old objects from the relationship, then add new ones.
		//FIXME: this could be configurable by the user unless we want to look for
		//       non-empty or maximum size constraints, which are likely CHECK clauses.
		//FIXME: these should be inside a transaction. Use the undo manager?
		
		NSPredicate* predicate = nil;
		NSDictionary* values = nil;
		
		if ([self shouldRemoveForTarget: target databaseObject: aDatabaseObject predicate: &predicate])
		{
			values = [mForeignKey srcDictionaryFor: [self destinationEntity] valuesFromDstObject: nil];
			[[aDatabaseObject databaseContext] executeUpdateObject: nil
															entity: [self destinationEntity]
														 predicate: predicate 
													withDictionary: values
															 error: error];
		}
		
		if (nil == *error)
		{
			if ([self shouldAddForTarget: target databaseObject: aDatabaseObject predicate: &predicate values: &values])
			{
				[[aDatabaseObject databaseContext] executeUpdateObject: nil
																entity: [self destinationEntity]
															 predicate: predicate 
														withDictionary: values
																 error: error];
			}

			//Don't set if we are updating a collection because if the object has the
			//value, it will be self-updating one.
			if (nil == *error && NO == [self isToMany])
				[aDatabaseObject setCachedValue: target forKey: [self name]];
		}
	}
}

- (BXForeignKey *) foreignKey
{
	return mForeignKey;
}

- (void) setDeleteRule: (NSDeleteRule) aRule
{
	mDeleteRule = aRule;
}

//Subclassing helpers
- (BOOL) shouldRemoveForTarget: (id) target 
				databaseObject: (BXDatabaseObject *) databaseObject
					 predicate: (NSPredicate **) predicatePtr
{
	BXAssertValueReturn (NULL != predicatePtr, NO, @"Expected predicatePtr not to be NULL.");
	BOOL retval = NO;
	
	//Compare collection to cached values.
	NSSet* oldObjects = [databaseObject primitiveValueForKey: [self name]];	
	
	NSMutableSet* removedObjects = [[oldObjects mutableCopy] autorelease];
	[removedObjects minusSet: target];
	
	if (0 < [removedObjects count])
	{
		retval = YES;
		NSPredicate* predicate = [removedObjects BXOrPredicateForObjects];
		*predicatePtr = predicate;
	}
	return retval;
}

- (BOOL) shouldAddForTarget: (id) target 
			 databaseObject: (BXDatabaseObject *) databaseObject
				  predicate: (NSPredicate **) predicatePtr 
					 values: (NSDictionary **) valuePtr
{
	BXAssertValueReturn (NULL != predicatePtr && NULL != valuePtr, NO, @"Expected predicatePtr and valuePtr not to be NULL.");
	BOOL retval = NO;
	
	//Compare collection to cached values.
	NSSet* oldObjects = [databaseObject primitiveValueForKey: [self name]];	
	NSMutableSet* addedObjects = [[target mutableCopy] autorelease];
	[addedObjects minusSet: oldObjects];

	if (0 < [addedObjects count])
	{
		retval = YES;
		
		NSDictionary* values = [mForeignKey srcDictionaryFor: [self destinationEntity] valuesFromDstObject: databaseObject];
		NSPredicate* predicate = [addedObjects BXOrPredicateForObjects];
		
		*valuePtr = values;
		*predicatePtr = predicate;
	}
	return retval;
}

- (void) setPredicate: (NSPredicate *) predicate
{
    if (mPredicate != predicate)
    {
        [mPredicate release];
        mPredicate = [predicate retain];
    }
}

@end
