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
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseObject.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseContextPrivate.h"
#import "BXDatabaseAdditions.h"
#import "BXSetRelationProxy.h"

#import <Log4Cocoa/Log4Cocoa.h>


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
        log4AssertValueReturn (nil != anArray && nil != anotherArray, nil, @"Expected to be called with parameters.");
        log4AssertValueReturn ([anArray count] == [anotherArray count], nil, @"Expected array counts to match (anArray: %@ anotherArray: %@)", anArray, anotherArray);
        log4AssertValueReturn (1 == [[NSSet setWithArray: [anArray valueForKey: @"entity"]] count], nil, @"Expected all src properties to have the same entity (%@).", anArray);
        log4AssertValueReturn (1 == [[NSSet setWithArray: [anotherArray valueForKey: @"entity"]] count], nil, @"Expected all dst properties to have the same entity (%@).", anotherArray);

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
    int rval = -1;
    if (0 < [srcProperties count])
    {
        if ([self srcEntity] == entity)
            rval = 0;
        else if ([self dstEntity] == entity)
            rval = 1;
        else if ([entity hasAncestor: [self srcEntity]])
            rval = 0;
        else if ([entity hasAncestor: [self dstEntity]])
            rval = 1;
    }
    return rval;
}

- (id) resolveFrom: (BXDatabaseObject *) object to: (BXEntityDescription *) targetEntity error: (NSError **) error
{
    id rval = nil;
    BXEntityDescription* entity = [[object objectID] entity];    
    BXDatabaseContext* context = [object databaseContext];
    NSError* localError = nil;
    
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
        
            rval = [context objectWithID: anID error: &localError];
            BXHandleError (error, localError);
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
        
        rval = [context executeFetchForEntity: targetEntity
                                withPredicate: predicate
                              returningFaults: YES
                              excludingFields: nil
                                returnedClass: [BXSetRelationProxy class]
                                        error: &localError];
        BXHandleError (error, localError);
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
    if ([self srcEntity] == entity || 
        [self dstEntity] == entity || 
        [entity hasAncestor: [self srcEntity]] || 
        [entity hasAncestor: [self dstEntity]])
    {
        rval = [self name];
    }
    return rval;
}

- (void) addObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) refObject 
                 to: (BXEntityDescription *) targetEntity error: (NSError **) error;
{
    NSError* localError = nil;
    if (nil == targetEntity)
        targetEntity = [self srcEntity];
    log4AssertVoidReturn (nil != refObject, @"Expected refObject not to be nil");
    BXEntityDescription* refEntity = [[refObject objectID] entity];
    log4AssertVoidReturn (1 == [self isToManyFromEntity: refEntity], @"Expected relationship to be to-many for this accessor");
    if (0 < [objectSet count])
    {
        //to-many
        NSArray* values = [refObject objectsForKeys: [refEntity correspondingProperties: dstProperties]];
        NSArray* keys = [srcProperties valueForKey: @"name"];
        [[refObject databaseContext] executeUpdateEntity: targetEntity
                                          withDictionary: [NSDictionary dictionaryWithObjects: values forKeys: keys]
                                               predicate: [objectSet BXOrPredicateForObjects]
                                                   error: &localError];
        BXHandleError (error, localError);
    }
}

- (void) removeObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) refObject 
                    to: (BXEntityDescription *) targetEntity error: (NSError **) error
{
    NSError* localError = nil;
    if (nil == targetEntity)
        targetEntity = [self srcEntity];
    log4AssertVoidReturn (nil != refObject, @"Expected refObject not to be nil");
    BXDatabaseObjectID* refID = [refObject objectID];
    BXEntityDescription* refEntity = [refID entity];
    if (nil == targetEntity)
        targetEntity = [self srcEntity];
    log4AssertVoidReturn (1 == [self isToManyFromEntity: refEntity], @"Expected relationship to be to-many for this accessor");

    //to-many
    //Remove objects by setting fkey columns to null. If the objectSet was nil, then remove all objects.
    NSPredicate* predicate = [NSPredicate BXAndPredicateWithProperties: [targetEntity correspondingProperties: srcProperties]
                                                    matchingProperties: [refObject objectsForKeys: [refEntity correspondingProperties: dstProperties]]
                                                                  type: NSEqualToPredicateOperatorType];
    if (nil != objectSet)
    {
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates: [NSArray arrayWithObjects:
            predicate, [objectSet BXOrPredicateForObjects], nil]];
    }
    NSArray* keys = [srcProperties valueForKey: @"name"];
    NSArray* updatedValues = NullArray ([keys count]);
    [[refObject databaseContext] executeUpdateEntity: targetEntity
                                      withDictionary: [NSDictionary dictionaryWithObjects: updatedValues forKeys: keys]
                                           predicate: predicate
                                               error: &localError];
    BXHandleError (error, localError);
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
    NSError* localError = nil;
    switch ([self isToManyFromEntity: refEntity])
    {
        case 0:
            //to-one
            log4AssertVoidReturn ([target isKindOfClass: [BXDatabaseObject class]], 
								  @"Expected to receive an object target for a to-one relationship.");
            log4AssertVoidReturn ([refEntity isView] || [updatedEntity isEqual: refEntity], 
								  @"Expected to be modifying the correct entity.");
            //This is needed for views.
            updatedEntity = refEntity;
            values = [target objectsForKeys: [refEntity correspondingProperties: dstProperties]];
            predicate = [[refObject objectID] predicate];
            break;
        case 1:
            //to-many
            if (YES == [target isKindOfClass: [BXDatabaseObject class]])
                target = [NSSet setWithObject: target];
            if (nil != target)
                values = [refObject objectsForKeys: [refEntity correspondingProperties: dstProperties]];
                
            //Again, this is needed for views
            if (nil != target)
                updatedEntity = [[[target anyObject] objectID] entity];
            predicate = [target BXOrPredicateForObjects];
            //All other rows will be updated not to have the value in referencing fields.
            [self removeObjects: nil referenceFrom: refObject to: updatedEntity error: &localError];
            BXHandleError (error, localError);
            break;
        case -1:
        default:
		{
			log4AssertVoidReturn (NO , @"Expected the relationship to be defined for this accessor");
			break;
		}
    }
    
    if (nil == localError)
    {
        if (nil == values)
            values = NullArray ([dstProperties count]);
        
        NSDictionary* change = [NSDictionary dictionaryWithObjects: values forKeys: updatedKeys];
		BXDatabaseContext* context = [refObject databaseContext];
        [context executeUpdateEntity: updatedEntity
					  withDictionary: change
						   predicate: predicate
							   error: &localError];
		
        BXHandleError (error, localError);
    }
}

- (NSArray *) subrelationships
{
    return nil;
}

- (BXEntityDescription *) otherEntity: (BXEntityDescription *) anEntity
{
	BXEntityDescription* entity1 = [self srcEntity];
	BXEntityDescription* entity2 = [self dstEntity];
	
	id rval = entity1;
	if (anEntity == entity1)
		rval = entity2;
	
	return rval;	
}

@end
