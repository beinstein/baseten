//
// BXRelationshipDescription.m
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

@class BXEntityDescription;

#import "BXRelationshipDescriptionProtocol.h"
#import "BXRelationshipDescription.h"
#import "BXPropertyDescription.h"
#import "BXEntityDescription.h"
#import "BXDatabaseObject.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseContextPrivate.h"
#import "BXDatabaseAdditions.h"
#import "BXSetRelationProxy.h"


static BOOL gReturnsArrayProxies = NO;

static NSArray*
NullArray (unsigned int count)
{
    id* buffer = malloc (count * sizeof (id));
    for (unsigned int i = 0; i < count; i++)
        buffer [i] = [NSNull null];
    NSArray* rval = [NSArray arrayWithObjects: buffer count: count];
    free (buffer);
    return rval;
}


@implementation BXRelationshipDescription

+ (BOOL) returnsArrayProxies
{
    return gReturnsArrayProxies;
}

+ (void) setReturnsArrayProxies: (BOOL) aBool
{
    gReturnsArrayProxies = aBool;
}

+ (id) relationshipWithName: (NSString *) aName
                srcProperties: (NSArray *) anArray
                dstProperties: (NSArray *) anotherArray
{
    return [[[self alloc] initWithName: aName 
                           srcProperties: anArray
                           dstProperties: anotherArray] autorelease];
}

- (id) initWithName: (NSString *) aName 
        srcProperties: (NSArray *) anArray
        dstProperties: (NSArray *) anotherArray
{
    if ((self = [super initWithName: aName]))
    {
        NSAssert (nil != anArray && nil != anotherArray, nil);
        NSAssert ([anArray count] == [anotherArray count], nil);
        NSAssert (1 == [[NSSet setWithArray: [anArray valueForKey: @"entity"]] count], nil);
        NSAssert (1 == [[NSSet setWithArray: [anotherArray valueForKey: @"entity"]] count], nil);

        srcProperties = [anArray copy];
        dstProperties = [anotherArray copy];
    }
    return self;
}

- (id) initWithName: (NSString *) aName
{
    //Don't use this initializer
    [self release];
    return nil;
}

- (void) dealloc
{
    [srcProperties release];
    [dstProperties release];
    [super dealloc];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@ (%p) \n\t\tsrcProperties:\t %@ \n\t\tdstProperties:\t %@", 
        [self class], self, srcProperties, dstProperties];
}

/**
 * \internal
 * Returns a negative value, if the specified entity is not part of the
 * relationship
 */
- (int) isToManyFromEntity: (BXEntityDescription *) entity
{
    //Many-to-one
    //FIXME: to support views, this should check ancestors as well with the -hasAncestor: method
    int rval = -1;
    if (0 < [srcProperties count])
    {
        if ([self srcEntity] == entity)
            rval = 0;
        else if ([self dstEntity] == entity)
            rval = 1;
    }
    return rval;
}

- (id) resolveFrom: (BXDatabaseObject *) object error: (NSError **) error
{
    return [self resolveFrom: object to: nil error: error];
}

- (id) resolveFrom: (BXDatabaseObject *) object to: (BXEntityDescription *) targetEntity error: (NSError **) error
{
    id rval = nil;
    BXEntityDescription* entity = [[object objectID] entity];    
    
    //Decide, what kind of query will be sent
    BOOL manyToOne = NO;
    BOOL oneToMany = NO;
    if ([[self srcEntity] isEqual: entity]) 
        manyToOne = YES;
    else if ([[self dstEntity] isEqual: entity]) 
        oneToMany = YES;
    else
    {
        if ([entity hasAncestor: [self srcEntity]]) 
            manyToOne = YES;
        else if ([entity hasAncestor: [self dstEntity]]) 
            oneToMany = YES;
    }
    
    if (YES == manyToOne)
    {
        NSArray* values = [object objectsForKeys: [entity correspondingProperties: [self srcProperties]]];
        if ([values containsObject: [NSNull null]])
        {
            //In this case, the value of the foreign key field is null
            rval = [NSNull null];
        }
        else
        {
            if (nil == targetEntity)
                targetEntity = [self dstEntity];
            NSArray* properties = [targetEntity correspondingProperties: [self dstProperties]];

            //Many (one)-to-one
            NSDictionary* primaryKeyFields = [NSDictionary dictionaryWithObjects: values forKeys: properties];
            BXDatabaseObjectID* anID = [BXDatabaseObjectID IDWithEntity: targetEntity primaryKeyFields: primaryKeyFields];
        
            rval = [[object databaseContext] objectWithID: anID error: error];
        }
    }
    else if (YES == oneToMany)
    {
        NSArray* values = [object objectsForKeys: [entity correspondingProperties: [self dstProperties]]];
        if (nil == targetEntity)
            targetEntity = [self srcEntity];
        NSArray* properties = [targetEntity correspondingProperties: [self srcProperties]];

        //one-to-many
        NSPredicate* predicate = [NSCompoundPredicate BXAndPredicateWithProperties: values
                                                                 matchingProperties: properties
                                                                               type: NSEqualToPredicateOperatorType];
        
        rval = [[object databaseContext] executeFetchForEntity: targetEntity
                                                 withPredicate: predicate
                                               returningFaults: YES
                                               excludingFields: nil
                                                 returnedClass: [BXSetRelationProxy class]
                                                         error: error];
        [rval setFilterPredicate: predicate];
        [rval setRelationship: self];
        [rval setReferenceObject: object];
    }
    return rval;
}

- (BOOL) isManyToMany
{
    return NO;
}

- (BOOL) isOneToOne
{
    return NO;
}

- (NSSet *) entities
{
    NSSet* rval = nil;
    if (0 < [srcProperties count])
    {
        rval = [NSSet setWithObjects: [[srcProperties objectAtIndex: 0] entity], 
                [[dstProperties objectAtIndex: 0] entity], nil];
    }
    return rval;
}

- (NSArray *) srcProperties
{
    return srcProperties; 
}

- (void) setSRCProperties: (NSArray *) aSRCProperties
{
    if (srcProperties != aSRCProperties) {
        [srcProperties release];
        srcProperties = [aSRCProperties retain];
    }
}

- (NSArray *) dstProperties
{
    return dstProperties; 
}

- (void) setDSTProperties: (NSArray *) aDSTProperties
{
    if (dstProperties != aDSTProperties) {
        [dstProperties release];
        dstProperties = [aDSTProperties retain];
    }
}

- (BXEntityDescription *) srcEntity
{
    return [[srcProperties objectAtIndex: 0] entity];
}

- (BXEntityDescription *) dstEntity
{
    return [[dstProperties objectAtIndex: 0] entity];
}

- (NSString *) nameFromEntity: (BXEntityDescription *) entity
{
    NSString* rval = nil;
    if ([self srcEntity] == entity || [self dstEntity] == entity)
        rval = [self name];
    return rval;
}

//FIXME: the three methods below should probably use correspondingProperties.
- (void) addObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) refObject error: (NSError **) error;
{
    NSAssert (nil != refObject, @"Expected refObject not to be nil");
    BXEntityDescription* refEntity = [[refObject objectID] entity];
    NSAssert (1 == [self isToManyFromEntity: refEntity], @"Expected relationship to be to-many for this accessor");
    if (0 < [objectSet count])
    {
        //to-many
        NSArray* values = [refObject objectsForKeys: dstProperties];
        NSArray* keys = [srcProperties valueForKey: @"name"];
        [[refObject databaseContext] executeUpdateEntity: [self srcEntity] 
                                          withDictionary: [NSDictionary dictionaryWithObjects: values forKeys: keys]
                                               predicate: [objectSet BXOrPredicateForObjects]
                                                   error: error];
    }
}

- (void) removeObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) refObject error: (NSError **) error
{
    NSAssert (nil != refObject, @"Expected refObject not to be nil");
    BXDatabaseObjectID* refID = [refObject objectID];
    BXEntityDescription* refEntity = [refID entity];
    NSAssert (1 == [self isToManyFromEntity: refEntity], @"Expected relationship to be to-many for this accessor");

    //to-many
    //Remove objects by setting fkey columns to null. If the objectSet was nil, then remove all objects.
    NSPredicate* predicate = [NSPredicate BXAndPredicateWithProperties: srcProperties
                                                     matchingProperties: [refObject objectsForKeys: dstProperties]
                                                                   type: NSEqualToPredicateOperatorType];
    if (nil != objectSet)
    {
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates: [NSArray arrayWithObjects:
            predicate, [objectSet BXOrPredicateForObjects], nil]];
    }
    NSArray* keys = [srcProperties valueForKey: @"name"];
    NSArray* updatedValues = NullArray ([keys count]);
    [[refObject databaseContext] executeUpdateEntity: [self srcEntity]
                                      withDictionary: [NSDictionary dictionaryWithObjects: updatedValues forKeys: keys]
                                           predicate: predicate
                                               error: error];
}

- (void) setTarget: (id) target referenceFrom: (BXDatabaseObject *) refObject error: (NSError **) error
{
    //Set either a to-one or a to-many relationship's target depending on the relationship type and the reference object.
    BXEntityDescription* refEntity = [[refObject objectID] entity];
    //Always modify the many end of the relationship.
    BXEntityDescription* updatedEntity = [self srcEntity];
    NSArray* updatedKeys = [srcProperties valueForKey: @"name"];
    NSArray* values = nil;
    NSPredicate* predicate = nil;
    switch ([self isToManyFromEntity: refEntity])
    {
        case 0:
            //to-one
            NSAssert ([target isKindOfClass: [BXDatabaseObject class]], 
                      @"Expected to receive an object target for a to-one relationship.");
            NSAssert ([updatedEntity isEqual: refEntity], @"Expected to be modifying the correct entity.");
            values = [target objectsForKeys: dstProperties];
            predicate = [[refObject objectID] predicate];
            break;
        case 1:
            //to-many
            if (YES == [target isKindOfClass: [BXDatabaseObject class]])
                target = [NSSet setWithObject: target];
            if (nil != target)
                values = [refObject objectsForKeys: dstProperties];
            predicate = [target BXOrPredicateForObjects];
            //All other rows will be updated not to have the value in referencing fields.
            [self removeObjects: nil referenceFrom: refObject error: error];
            break;
        case -1:
        default:
            NSAssert (NO , @"Expected the relationship to be defined for this accessor");
    }
    
    if (nil == *error)
    {
        if (nil == values)
            values = NullArray ([dstProperties count]);
    
        NSDictionary* change = [NSDictionary dictionaryWithObjects: values forKeys: updatedKeys];
        [[refObject databaseContext] executeUpdateEntity: updatedEntity
                                          withDictionary: change
                                               predicate: predicate
                                                   error: error];
    }
}

@end
