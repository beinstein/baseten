//
// BXHelperTableMTMRelationshipDescription.m
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
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

#import "BXRelationshipDescriptionProtocol.h"
#import "BXHelperTableMTMRelationshipDescription.h"
#import "BXRelationshipDescription.h"
#import "BXEntityDescription.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseObject.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseContextPrivate.h"
#import "BXException.h"
#import "BXSetRelationProxy.h"
#import "BXSetHelperTableRelationProxy.h"


//FIXME: when requested, create a mutable array proxy to which objects from the helper table get added.
//This way modifications to the helper table get notified.
//The helper also has to be queried first.

@implementation BXHelperTableMTMRelationshipDescription
+ (id) relationshipWithRelationship1: (BXRelationshipDescription *) r1 
                       relationship2: (BXRelationshipDescription *) r2
{
    return [[[self alloc] initWithRelationship1: r1 relationship2: r2] autorelease];
}

- (id) initWithRelationship1: (BXRelationshipDescription *) r1 
               relationship2: (BXRelationshipDescription *) r2
{
    if ((self = [super init]))
    {
        relationship1 = [r1 retain];
        relationship2 = [r2 retain];
    }
    return self;
}

/**
 * \internal
 * Normalize.
 * reference <- helper table -> targets
 *    dst            src          dst
 */
- (void) normalizeNames: (BXDatabaseObject *) refObject from: (BXRelationshipDescription **) refRel to: (BXRelationshipDescription **) targetRel
{
    *refRel = relationship1;
    *targetRel = relationship2;
    BXEntityDescription* dstEntity = [*targetRel dstEntity];
    BXEntityDescription* refEntity = [[refObject objectID] entity];
    if (dstEntity == refEntity || [refEntity hasAncestor: dstEntity])
    {
        *refRel = relationship2;
        *targetRel = relationship1;
    }
}

- (void) dealloc
{
    [relationship1 release];
    [relationship2 release];
    [super dealloc];
}

- (int) isToManyFromEntity: (BXEntityDescription *) entity
{
    int rval = -1;
    //Use dstEntity for the helper table's point of view
    if ([relationship1 dstEntity] == entity || [relationship2 dstEntity] == entity)
        rval = 1;
    return rval;
}

- (id) resolveFrom: (BXDatabaseObject *) object to: (BXEntityDescription *) givenDST error: (NSError **) error
{
    //srcEntity is the helper table in both relationships
    BXEntityDescription* entity = [[object objectID] entity];
    BXEntityDescription* dstEntity = nil;
    BXRelationshipDescription* helperToSRC = relationship1;
    BXRelationshipDescription* helperToDST = relationship2;
    NSError* localError = nil;
    
    //Normalize
    {
        BXEntityDescription* entity1 = [relationship1 dstEntity];
        BXEntityDescription* entity2 = [relationship2 dstEntity];
        
        if (entity == entity1)
            dstEntity = entity2;
        else if (entity == entity2 || [entity hasAncestor: entity2])
        {
            dstEntity = entity1;
            helperToSRC = relationship2;
            helperToDST = relationship1;
        }
        else if ([entity hasAncestor: entity1])
        {
            dstEntity = entity2;
        }   
        else
        {
            NSAssert (NO, nil);
        }
        
        if (nil != givenDST)
        {
            NSAssert2 (YES == [givenDST hasAncestor: dstEntity], 
                       @"Given entity %@ is not part of %@", givenDST, self);
            dstEntity = givenDST;
        }
    }
    
    BXDatabaseContext* context = [object databaseContext];
#if 0
    //FIXME: this is a bit of a kludge, since entities should be validated by the database interface.
    //Perhaps the db interface should have the method -correspondingProperties:.
    [context validateEntity: entity];
    [context validateEntity: dstEntity];
#endif
    //Make the join using predicates: src --> helper --> dst
    //Use values only in place of src
    NSPredicate* helperToSRCPredicate = 
        [NSCompoundPredicate BXAndPredicateWithProperties: [object objectsForKeys: [entity correspondingProperties: [helperToSRC dstProperties]]]
                                        matchingProperties: [helperToSRC srcProperties]
                                                      type: NSEqualToPredicateOperatorType];
    NSArray* dstProperties = [dstEntity correspondingProperties: [helperToDST dstProperties]];
    NSArray* helperProperties = [helperToDST srcProperties];
    NSPredicate* helperToDSTPredicate = 
        [NSCompoundPredicate BXAndPredicateWithProperties: helperProperties
                                        matchingProperties: dstProperties
                                                      type: NSEqualToPredicateOperatorType];
    NSPredicate* compound = [NSCompoundPredicate andPredicateWithSubpredicates:
        [NSArray arrayWithObjects: helperToSRCPredicate, helperToDSTPredicate, nil]];
    
    //Finally execute the query
    id rval = [context executeFetchForEntity: dstEntity
                               withPredicate: compound
                             returningFaults: YES
                             excludingFields: nil
                               returnedClass: [BXSetHelperTableRelationProxy class]
                                       error: &localError];
    BXHandleError (error, localError);
    [rval setRelationship: self];
    [rval setEntity: [helperToSRC srcEntity]];
    [rval setMainEntity: dstEntity];
    [rval setFilterPredicate: helperToSRCPredicate];
    [rval setMainEntityProperties: dstProperties];
    [rval setHelperProperties: helperProperties];
    [rval setReferenceObject: object];
    return rval;
}

- (BOOL) isManyToMany
{
    return YES;
}

- (BOOL) isOneToOne
{
    return NO;
}

- (NSSet *) entities
{
    //srcEntity is the helper table in both relationships
    return [NSSet setWithObjects: [relationship1 dstEntity], [relationship2 dstEntity], nil];
}

- (NSString *) nameFromEntity: (BXEntityDescription *) entity
{
#ifndef NS_BLOCK_ASSERTIONS
    if (NO == [[self entities] containsObject: entity])
    {
        BOOL ok = NO;
        TSEnumerate (currentEntity, e, [[self entities] objectEnumerator])
        {
            ok = [entity hasAncestor: currentEntity];
            if (YES == ok)
                break;
        }
        NSAssert2 (YES == ok, @"Expected %@ to be one of %@ or to have one of them as an ancestor.", entity, [self entities]);
    }
#endif
    return [self name];
}

- (BXRelationshipDescription *) relationship1
{
    return relationship1; 
}

- (void) setRelationship1: (BXRelationshipDescription *) aRelationship1
{
    if (relationship1 != aRelationship1) {
        [relationship1 release];
        relationship1 = [aRelationship1 retain];
    }
}

- (BXRelationshipDescription *) relationship2
{
    return relationship2; 
}

- (void) setRelationship2: (BXRelationshipDescription *) aRelationship2
{
    if (relationship2 != aRelationship2) 
    {
        [relationship2 release];
        relationship2 = [aRelationship2 retain];
    }
}

- (void) setTarget: (id) collection referenceFrom: (BXDatabaseObject *) refObject error: (NSError **) error
{
    //FIXME: come up with a better way to handle the error
    //FIXME: this should be inside a transaction
    [self removeObjects: nil referenceFrom: refObject to: nil error: error];
    if (NULL == error || NULL != *error)
        [self addObjects: collection referenceFrom: refObject to: nil error: error];
}

- (void) addObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) refObject
                 to: (BXEntityDescription *) targetEntity error: (NSError **) error
{
    BXRelationshipDescription* refRel = nil;
    BXRelationshipDescription* targetRel = nil;
    [self normalizeNames: refObject from: &refRel to: &targetRel];
    BXDatabaseContext* context = [refObject databaseContext];
    NSError* localError = nil;
    
    //Get the properties used in the helper table
    NSArray* refHProperties = [refRel srcProperties];
    NSArray* targetHProperties = [targetRel srcProperties];
    unsigned int refPropCount = [refHProperties count];
    unsigned int targetPropCount = [targetHProperties count];
    
    //Get the field names
    NSMutableArray* keys = [NSMutableArray arrayWithCapacity: refPropCount + targetPropCount];
    [keys addObjectsFromArray: refHProperties];
    [keys addObjectsFromArray: targetHProperties];
    
    //Add the values from refObject once and from the target objects for each iteration.
    NSMutableArray* values = [NSMutableArray arrayWithCapacity: [keys count]];
    [values addObjectsFromArray: [refObject objectsForKeys: [refRel dstProperties]]];
    NSRange targetRange = NSMakeRange (refPropCount, targetPropCount);
    TSEnumerate (currentTarget, e, [objectSet objectEnumerator])
    {
        //FIXME: we should have a transaction.
        if (NULL != localError)
            break;
        
        if (refPropCount < [values count])
            [values removeObjectsInRange: targetRange];
        [values addObjectsFromArray: [currentTarget objectsForKeys: [targetRel dstProperties]]];
    
        [context createObjectForEntity: [refRel srcEntity]
                       withFieldValues: [NSDictionary dictionaryWithObjects: values forKeys: keys]
                                 error: &localError];
    }
    BXHandleError (error, localError);
}

- (void) removeObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) refObject
                    to: (BXEntityDescription *) targetEntity error: (NSError **) error
{
    NSError* localError = nil;
    BXRelationshipDescription* refRel = nil;
    BXRelationshipDescription* targetRel = nil;
    [self normalizeNames: refObject from: &refRel to: &targetRel];
    
    //To remove the relationship, we need to collect those tuples that have
    //refObject's fkey values and any target object's fkey values.
    //First collect from the reference object.
    NSPredicate* predicate = nil;
    {
        NSArray* keys = [refRel srcProperties];
        NSArray* values = [refObject objectsForKeys: [refRel dstProperties]];
        predicate = [NSPredicate BXAndPredicateWithProperties: keys
                                           matchingProperties: values
                                                         type: NSEqualToPredicateOperatorType];
    }
    //Then add the alternatives from target objects.
    if (0 < [objectSet count])
    {
        NSMutableArray* parts = [NSMutableArray arrayWithCapacity: [objectSet count]];
        NSArray* keys = [targetRel srcProperties];
        TSEnumerate (currentObject, e, [objectSet objectEnumerator])
        {
            NSArray* values = [currentObject objectsForKeys: [targetRel dstProperties]];
            NSPredicate* predicate = 
                [NSPredicate BXAndPredicateWithProperties: keys
                                        matchingProperties: values
                                                      type: NSEqualToPredicateOperatorType];
            [parts addObject: predicate];
        }
        NSPredicate* subPredicate = [NSCompoundPredicate orPredicateWithSubpredicates: parts];
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
            [NSArray arrayWithObjects: predicate, subPredicate, nil]];
    }
    
    //Finally, delete from the helper table
    [[refObject databaseContext] executeDeleteFromEntity: [targetRel srcEntity]
                                           withPredicate: predicate
                                                   error: &localError];
    BXHandleError (error, localError);
}

- (NSArray *) subrelationships
{
    return [NSArray arrayWithObjects: relationship1, relationship2, nil];
}
@end
