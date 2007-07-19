//
// BXRelationshipDescription.m
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
// $Id: BXRelationshipDescription.m 225 2007-07-12 08:33:55Z tuukka.norri@karppinen.fi $
//

#import <Log4Cocoa/Log4Cocoa.h>

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

@implementation BXRelationshipDescription

- (void) dealloc
{
	[mForeignKey release];
	[super dealloc];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"<%@ (%p) name: %@ entity: %@ destinationEntity: %@>",
		[self class], self, [self name], [self entity], [self destinationEntity]];
}

- (BXEntityDescription *) destinationEntity
{
    return mDestinationEntity;
}

- (BXRelationshipDescription *) inverseRelationship
{
	return [[mDestinationEntity relationshipsByName] objectForKey: mInverseName];
}

- (NSDeleteRule) deleteRule
{
    //FIXME: this is only a stub.
    return NSNoActionDeleteRule;
}

- (BOOL) isToMany
{
	return !mIsInverse;
}

/** Retain on copy. */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}

- (unsigned int) hash
{
	if (0 == mHash)
	{
		mHash = [super hash] ^ [mDestinationEntity hash] ^ [mForeignKey hash];
	}
	return mHash;
}

- (BOOL) isEqual: (id) anObject
{
	BOOL retval = NO;
	if (anObject == self)
		retval = YES;
	else if ([super isEqual: anObject] && [anObject isKindOfClass: [self class]])
	{
		BXRelationshipDescription* aDesc = (BXRelationshipDescription *) anObject;
		if ([mDestinationEntity isEqual: aDesc->mDestinationEntity] &&
			[mForeignKey isEqual: aDesc->mForeignKey])
		{
			retval = YES;
		}
	}
    return retval;	
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
	log4AssertValueReturn (NULL != error, nil , @"Expected error to be set.");
	log4AssertValueReturn (nil != aDatabaseObject, nil, @"Expected aDatabaseObject not to be nil.");
	log4AssertValueReturn ([[self entity] isEqual: [aDatabaseObject entity]], nil, 
						   @"Expected object's entity to match. Self: %@ aDatabaseObject: %@", self, aDatabaseObject);

	id retval = nil;
	NSPredicate* predicate = nil;
	
	if (mIsInverse)
	{
		//We want to select from foreign key's dst entity, which is our destination entity as well.
		predicate = [mForeignKey predicateForDstEntity: [self destinationEntity] valuesInObject: aDatabaseObject];
	}
	else
	{
		//We want to select from foreign key's src entity, which is our destination entity.
		predicate = [mForeignKey predicateForSrcEntity: [self destinationEntity] valuesInObject: aDatabaseObject];
	}
	
	//Expression order matters since foreign key is always in src table or view.
	NSSet* res = [[aDatabaseObject databaseContext] executeFetchForEntity: [self destinationEntity]
															withPredicate: predicate 
														  returningFaults: YES
														  excludingFields: nil
															returnedClass: [BXSetRelationProxy class]
																	error: error];
	if ([self isToMany])
		retval = res;
	else
	{
		if (0 < [res count])
			retval = [res anyObject];
		else
			retval = [NSNull null];
	}
	return retval;
}

- (void) setTarget: (id) target
		 forObject: (BXDatabaseObject *) aDatabaseObject
			 error: (NSError **) error
{
	log4AssertVoidReturn (NULL != error, @"Expected error to be set.");
	log4AssertVoidReturn (nil != aDatabaseObject, @"Expected aDatabaseObject not to be nil.");
	log4AssertVoidReturn ([[self entity] isEqual: [aDatabaseObject entity]], 
						  @"Expected object's entity to match. Self: %@ aDatabaseObject: %@", self, aDatabaseObject);	
	
	//We always want to modify the foreign key's (or corresponding view's) entity, hence the branch here.
	if (mIsInverse)
	{		
		NSPredicate* predicate = [[aDatabaseObject objectID] predicate];
		NSDictionary* values = [mForeignKey srcDictionaryFor: [self entity] valuesFromDstObject: target];
		
		[[aDatabaseObject databaseContext] executeUpdateEntity: [self entity]
												withDictionary: values
													 predicate: predicate error: error];
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
			[[aDatabaseObject databaseContext] executeUpdateEntity: [self destinationEntity]
													withDictionary: values
														 predicate: predicate 
															 error: error];
		}
		
		if (nil == *error)
		{
			if ([self shouldAddForTarget: target databaseObject: aDatabaseObject predicate: &predicate values: &values])
			{
				[[aDatabaseObject databaseContext] executeUpdateEntity: [self destinationEntity]
														withDictionary: values
															 predicate: predicate 
																 error: error];
			}
		
			if (nil == *error)
				[aDatabaseObject setCachedValue: target forKey: [self name]];
		}
	}
}

- (BXForeignKey *) foreignKey
{
	return mForeignKey;
}

//Subclassing helpers
- (BOOL) shouldRemoveForTarget: (id) target databaseObject: (BXDatabaseObject *) databaseObject
					 predicate: (NSPredicate **) predicatePtr
{
	log4AssertValueReturn (NULL != predicatePtr, NO, @"Expected predicatePtr not to be NULL.");
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

- (BOOL) shouldAddForTarget: (id) target databaseObject: (BXDatabaseObject *) databaseObject
				  predicate: (NSPredicate **) predicatePtr values: (NSDictionary **) valuePtr
{
	log4AssertValueReturn (NULL != predicatePtr && NULL != valuePtr, NO, @"Expected predicatePtr and valuePtr not to be NULL.");
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

@end