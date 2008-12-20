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
#import "PGTSHOM.h"
#import "BXPropertyDescriptionPrivate.h"
#import "BXProbes.h"
#import "BXAttributeDescriptionPrivate.h"
#import "BXEnumerate.h"


/**
 * \brief A description for one-to-many relationships and a superclass for others.
 *
 * Relationships between entities are defined with foreign keys in the database.
 * \note For this class to work in non-GC applications, the corresponding database context must be retained as well.
 * \ingroup descriptions
 */
@implementation BXRelationshipDescription
- (id) initWithName: (NSString *) name entity: (BXEntityDescription *) entity 
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

/** 
 * \internal
 * \brief Deallocation helper. 
 */
- (void) dealloc2
{
	[mForeignKey release];
	[mInverseName release];
	[super dealloc2];
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"<%@ (%p) name: %@ entity: %@ destinationEntity: %@>",
		[self class], self, [self name], 
		(id) [[self entity] name] ?: [self entity], 
		(id) [[self destinationEntity] name] ?: [self destinationEntity]];
}

/**
 * \brief Destination entity for this relationship.
 */
- (BXEntityDescription *) destinationEntity
{
    return mDestinationEntity;
}

/**
 * \brief Inverse relationship for this relationship.
 *
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
 * \brief Delete rule for this relationship.
 */
- (NSDeleteRule) deleteRule
{
	//See relationship creation in BXPGInterface.
	return mDeleteRule;
}

/**
 * \brief Whether this relationship is to-many.
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
- (id) initWithName: (NSString *) name 
			 entity: (BXEntityDescription *) entity 
  destinationEntity: (BXEntityDescription *) destinationEntity
{
	Expect (name);
	Expect (entity);
	Expect (destinationEntity);
	
	if ((self = [super initWithName: name entity: entity]))
	{
		mDestinationEntity = destinationEntity;
	}
	return self;
}

- (void) removeDestinationEntity
{
	[[self entity] removeRelationship: self];
	mDestinationEntity = nil;
}


struct rel_attr_st
{
	__strong BXRelationshipDescription* ra_sender;
	__strong NSDictionary* ra_attrs;
};


static void
RemoveRelFromAttribute (NSString* srcKey, NSString* dstKey, void* context)
{
	struct rel_attr_st* ctx = (struct rel_attr_st *) context;
	BXRelationshipDescription* self = ctx->ra_sender;
	NSDictionary* attributes = ctx->ra_attrs;
	
	BXAttributeDescription* attr = [attributes objectForKey: srcKey];
	[attr removeDependentRelationship: self];
}


static void
AddRelToAttribute (NSString* srcKey, NSString* dstKey, void* context)
{
	struct rel_attr_st* ctx = (struct rel_attr_st *) context;
	BXRelationshipDescription* self = ctx->ra_sender;
	NSDictionary* attributes = ctx->ra_attrs;
	
	BXAttributeDescription* attr = [attributes objectForKey: srcKey];
	[attr addDependentRelationship: self];
}


- (void) removeAttributeDependency
{
	if ([self isInverse] && ![self isToMany])
	{
		struct rel_attr_st ctx = {self, [[self entity] attributesByName]};
		[self iterateForeignKey: &RemoveRelFromAttribute context: &ctx];
	}
}


- (void) makeAttributeDependency
{
	if ([self isInverse] && ![self isToMany])
	{
		struct rel_attr_st ctx = {self, [[self entity] attributesByName]};
		[self iterateForeignKey: &AddRelToAttribute context: &ctx];
	}
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

- (NSPredicate *) predicateForObject: (BXDatabaseObject *) databaseObject
{
	BXRelationshipDescription* inverse = [self inverseRelationship];
	NSComparisonPredicateModifier modifier = NSDirectPredicateModifier;
	if ([inverse isToMany])
		modifier = NSAnyPredicateModifier;
	
	NSExpression* lhs = [NSExpression expressionForKeyPath: [inverse name]];
	NSExpression* rhs = [NSExpression expressionForConstantValue: databaseObject];
	NSPredicate* predicate = [NSComparisonPredicate predicateWithLeftExpression: lhs
																rightExpression: rhs
																	   modifier: modifier 
																		   type: NSEqualToPredicateOperatorType 
																		options: 0];
	return predicate;
}

//Subclassing helpers
- (NSPredicate *) predicateForRemoving: (id) target 
						databaseObject: (BXDatabaseObject *) databaseObject
{
	NSPredicate* retval = nil;
	
	//Compare collection to cached values.
	NSSet* oldObjects = [databaseObject primitiveValueForKey: [self name]];	
	
	NSMutableSet* removedObjects = [[oldObjects mutableCopy] autorelease];
	[removedObjects minusSet: target];
	
	if (0 < [removedObjects count])
	{
		NSExpression* lhs = [NSExpression expressionForConstantValue: removedObjects];
		NSExpression* rhs = [NSExpression expressionForEvaluatedObject];
		retval = [NSComparisonPredicate predicateWithLeftExpression: lhs rightExpression: rhs
														   modifier: NSAnyPredicateModifier 
															   type: NSEqualToPredicateOperatorType 
															options: 0];
	}
	return retval;
}

- (NSPredicate *) predicateForAdding: (id) target 
					  databaseObject: (BXDatabaseObject *) databaseObject
{
	NSPredicate* retval = nil;
	
	//Compare collection to cached values.
	NSSet* oldObjects = [databaseObject primitiveValueForKey: [self name]];	
	NSMutableSet* addedObjects = [[target mutableCopy] autorelease];
	[addedObjects minusSet: oldObjects];
	
	if (0 < [addedObjects count])
	{
		NSExpression* lhs = [NSExpression expressionForConstantValue: addedObjects];
		NSExpression* rhs = [NSExpression expressionForEvaluatedObject];
		retval = [NSComparisonPredicate predicateWithLeftExpression: lhs rightExpression: rhs
														   modifier: NSAnyPredicateModifier 
															   type: NSEqualToPredicateOperatorType 
															options: 0];
	}
	return retval;
}

- (Class) fetchedClass
{
	return [BXSetRelationProxy class];
}

- (id) toOneTargetFor: (BXDatabaseObject *) databaseObject registeredOnly: (BOOL) registeredOnly 
			fireFault: (BOOL) fireFault error: (NSError **) error
{
	Expect ([self isInverse]);
	Expect (! [self isToMany]);
	Expect (registeredOnly || error);

	BXDatabaseObject* retval = nil;
	BXEntityDescription* entity = [self destinationEntity];
	BXDatabaseObjectID* objectID = [mForeignKey objectIDForDstEntity: entity fromObject: databaseObject fireFault: fireFault];
	if (objectID)
	{
		BXDatabaseContext* ctx = [databaseObject databaseContext];
		if (registeredOnly)
			retval = [ctx registeredObjectWithID: objectID];
		else
			retval = [ctx objectWithID: objectID error: error];	
	}
	return retval;
}
			
- (id) registeredTargetFor: (BXDatabaseObject *) databaseObject fireFault: (BOOL) fireFault
{
	id retval = nil;
	if (databaseObject)
		retval = [self toOneTargetFor: databaseObject registeredOnly: YES fireFault: fireFault error: NULL];
	return retval;
}

- (id) targetForObject: (BXDatabaseObject *) databaseObject error: (NSError **) error
{
	Expect (error);
	Expect (databaseObject);
    BXAssertValueReturn ([[self entity] isEqual: [databaseObject entity]], nil, 
						 @"Expected object's entity to match. Self: %@ aDatabaseObject: %@", self, databaseObject);
	
	id retval = nil;
	//If we can determine an object ID, fetch the target object from the context's cache.
    if (! [self isToMany] && [self isInverse])
		retval = [self toOneTargetFor: databaseObject registeredOnly: NO fireFault: YES error: error];
	else
	{
		BXEntityDescription* entity = [self destinationEntity];
		NSPredicate* predicate = [self predicateForObject: databaseObject];
		Class fetchedClass = [self fetchedClass];
		id res = [[databaseObject databaseContext] executeFetchForEntity: entity
														   withPredicate: predicate 
														 returningFaults: NO
														 excludingFields: nil
														   returnedClass: fetchedClass
																   error: error];
		if (fetchedClass)
			[res fetchedForRelationship: self owner: databaseObject key: [self name]];
		
		if ([self isToMany])
			retval = res;
		else
			retval = [res PGTSAny];
	}
	
	if (! retval)
		retval = [NSNull null];
	
	return retval;
}

- (BOOL) setTarget: (id) target
		 forObject: (BXDatabaseObject *) databaseObject
			 error: (NSError **) error
{
	ExpectR (error, NO);
	ExpectR (databaseObject, NO);
	ExpectR ([[self entity] isEqual: [databaseObject entity]], NO);
	BOOL retval = NO;
	BXRelationshipDescription* inverse = [self inverseRelationship];
	NSString* inverseName = [inverse name];
	
    //We always want to modify the foreign key's (or corresponding view's) entity, hence the branch here.
	//Also with one-to-many relationships the false branch is for modifying a collection of objects.
    if (mIsInverse)
    {		
    	NSPredicate* predicate = [[databaseObject objectID] predicate];
    	NSDictionary* values = [mForeignKey srcDictionaryFor: [self entity] valuesFromDstObject: target];
		
		BXDatabaseObject* oldTarget = nil;
		if (inverseName)
		{
			oldTarget = [self registeredTargetFor: databaseObject fireFault: NO];
			[oldTarget willChangeValueForKey: inverseName];
			[target willChangeValueForKey: inverseName];
		}
		
    	[[databaseObject databaseContext] executeUpdateObject: nil
    													entity: [self entity]
    												 predicate: predicate
    											withDictionary: values
    													 error: error];
    	if (! *error)
    		[databaseObject setCachedValue: target forKey: [self name]];

		if (inverseName)
		{
			[oldTarget didChangeValueForKey: inverseName];
			[target didChangeValueForKey: inverseName];
		}

		if (*error)
			goto bail;
    }
    else
    {
    	//First remove old objects from the relationship, then add new ones.
    	//FIXME: this could be configurable by the user unless we want to look for
    	//       non-empty or maximum size constraints, which are likely CHECK clauses.
    	//FIXME: these should be inside a transaction. Use the undo manager?
		
		BXDatabaseObject* oldTarget = nil;
		if (! [self isToMany] && inverseName)
		{
			oldTarget = [databaseObject cachedValueForKey: [self name]];
			[oldTarget willChangeValueForKey: inverseName];
			[target willChangeValueForKey: inverseName];
		}
		
		NSPredicate* predicate = nil;
    	if ((predicate = [self predicateForRemoving: target databaseObject: databaseObject]))
    	{
    		NSDictionary* values = [mForeignKey srcDictionaryFor: [self destinationEntity] valuesFromDstObject: nil];
    		[[databaseObject databaseContext] executeUpdateObject: nil
    														entity: [self destinationEntity]
    													 predicate: predicate 
    												withDictionary: values
    														 error: error];
			
			if (*error)
				goto bail;
    	}
		
		if ((predicate = [self predicateForAdding: target databaseObject: databaseObject]))
		{
			NSDictionary* values = [mForeignKey srcDictionaryFor: [self destinationEntity] valuesFromDstObject: databaseObject];
			[[databaseObject databaseContext] executeUpdateObject: nil
														   entity: [self destinationEntity]
														predicate: predicate 
												   withDictionary: values
															error: error];
			
			if (*error)
				goto bail;
		}
				
		//Don't set if we are updating a collection because if the object has the
		//value, it will be self-updating one.
		if (! [self isToMany] && inverseName)
		{
			[oldTarget didChangeValueForKey: inverseName];
			[target didChangeValueForKey: inverseName];
		}
	}
	
	retval = YES;
bail:
	return retval;
}

- (BXForeignKey *) foreignKey
{
	return mForeignKey;
}

- (void) setDeleteRule: (NSDeleteRule) aRule
{
	mDeleteRule = aRule;
}

- (void) iterateForeignKey: (void (*)(NSString*, NSString*, void*)) callback context: (void *) ctx
{
	NSUInteger i = 1, j = 0;
	if ([self isInverse])
	{
		i = 0;
		j = 1;
	}
	
	BXEnumerate (currentFieldPair, e, [[[self foreignKey] fieldNames] objectEnumerator])
		callback ([currentFieldPair objectAtIndex: i], [currentFieldPair objectAtIndex: j], ctx);
}
@end


@implementation BXRelationshipDescription (BXPGRelationAliasMapper)
- (id) BXPGVisitRelationship: (id <BXPGRelationshipVisitor>) visitor fromItem: (BXPGRelationshipFromItem *) fromItem
{
	return [visitor visitSimpleRelationship: fromItem];
}
@end
