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
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseObject.h"
#import "BXForeignKey.h"
#import "BXForeignKeyPrivate.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseContextPrivate.h"
#import "BXDatabaseAdditions.h"

@implementation BXRelationshipDescription

- (void) dealloc
{
	[mForeignKey release];
	[super dealloc];
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
	return mIsToMany;
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

- (void) setIsToMany: (BOOL) aBool
{
	mIsToMany = aBool;
}

- (void) setInverseName: (NSString *) aString
{
	if (mInverseName != aString)
	{
		[mInverseName release];
		mInverseName = [aString retain];
	}
}

/** \internal Helps inheriting in BXOneToOneRelationshipDescription. */
- (BOOL) affectManySideWithObject: (BXDatabaseObject *) anObject
{
	return [self isToMany];
}

- (id) targetForObject: (BXDatabaseObject *) aDatabaseObject error: (NSError **) error
{
	log4AssertValueReturn (NULL != error, nil , @"Expected error to be set.");
	log4AssertValueReturn (nil != aDatabaseObject, nil, @"Expected aDatabaseObject not to be nil.");

	id retval = nil;
	BXEntityDescription* targetEntity = nil;
	BXEntityDescription* otherEntity = nil;
	
	if ([self affectManySideWithObject: aDatabaseObject])
	{
		targetEntity = [self entity];
		otherEntity = [self destinationEntity];
	}
	else
	{
		targetEntity = [self destinationEntity];
		otherEntity = [self entity];
	}
	
	log4AssertValueReturn ([otherEntity isEqual: [aDatabaseObject entity]], nil, 
						   @"Expected object's entity to match. Self: %@ aDatabaseObject: %@", self, aDatabaseObject);
	
	//Expression order doesn't actually matter.
	//FIXME: should returnedClass be self-updating?
	NSPredicate* predicate = [mForeignKey predicateForSrcEntity: targetEntity dstEntity: otherEntity];
	NSSet* res = [[aDatabaseObject databaseContext] executeFetchForEntity: targetEntity
															withPredicate: predicate 
														  returningFaults: YES
														  excludingFields: nil
															returnedClass: [NSMutableSet class]
																	error: error];
	if ([self isToMany])
		retval = res;
	else if (0 < [res count])
		retval = [res anyObject];
	return retval;
}

- (void) setTarget: (id) target
		 forObject: (BXDatabaseObject *) aDatabaseObject
			 error: (NSError **) error
{
	log4AssertVoidReturn (NULL != error, @"Expected error to be set.");
	log4AssertVoidReturn (nil != aDatabaseObject, @"Expected aDatabaseObject not to be nil.");
	
	NSString* name = [self name];
	
	if ([self affectManySideWithObject: aDatabaseObject])
	{
		BXEntityDescription* targetEntity = [self entity];
		NSArray* keys = [mForeignKey srcFieldNames];
		
		log4AssertVoidReturn ([[self destinationEntity] isEqual: [aDatabaseObject entity]], 
							  @"Expected object's entity to match. Self: %@ aDatabaseObject: %@", self, aDatabaseObject);	
		
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
		[aDatabaseObject willChangeValueForKey: name];
		
		NSPredicate* predicate = [removedObjects BXOrPredicateForObjects];
		NSArray* values = [NSArray BXNullArray: [keys count]];
		[[aDatabaseObject databaseContext] executeUpdateEntity: targetEntity
												withDictionary: [NSDictionary dictionaryWithObjects: values forKeys: keys]
													 predicate: predicate 
														 error: error];
		
		predicate = [addedObjects BXOrPredicateForObjects];
		values = [aDatabaseObject valuesForKeys: keys];
		[[aDatabaseObject databaseContext] executeUpdateEntity: targetEntity
												withDictionary: [NSDictionary dictionaryWithObjects: values forKeys: keys]
													 predicate: predicate 
														 error: error];
		
		[aDatabaseObject didChangeValueForKey: name];		
	}
	else
	{
		BXEntityDescription* targetEntity = [self destinationEntity];
		NSArray* keys = [mForeignKey dstFieldNames];
		NSArray* values = [aDatabaseObject valuesForKeys: keys];
		
		log4AssertVoidReturn ([[self entity] isEqual: [aDatabaseObject entity]], 
							  @"Expected object's entity to match. Self: %@ aDatabaseObject: %@", self, aDatabaseObject);	
		
		NSPredicate* predicate = [target BXOrPredicateForObjects];
		
		[aDatabaseObject willChangeValueForKey: name];
		[[aDatabaseObject databaseContext] executeUpdateEntity: targetEntity
												withDictionary: [NSDictionary dictionaryWithObjects: values forKeys: keys]
													 predicate: predicate error: error];
		[aDatabaseObject didChangeValueForKey: name];		
	}
}

- (BXForeignKey *) foreignKey
{
	return mForeignKey;
}

@end