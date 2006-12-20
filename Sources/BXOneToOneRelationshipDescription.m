//
// BXOneToOneRelationshipDescription.m
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
#import "BXOneToOneRelationshipDescription.h"
#import "BXRelationshipDescription.h"
#import "BXEntityDescription.h"
#import "BXDatabaseObject.h"
#import "BXDatabaseObjectID.h"
#import "BXException.h"


@class BXEntityDescription;


@implementation BXOneToOneRelationshipDescription

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

- (void) dealloc
{
    [relationship1 release];
    [relationship2 release];
    [super dealloc];
}

- (int) isToManyFromEntity: (BXEntityDescription *) entity
{
#if 0
    int rval = -1;
    if ([relationship1 srcEntity] == entity || [relationship2 srcEntity] == entity)
        rval = 0;
    return rval;
#endif
    return 0;
}

- (id) resolveFrom: (BXDatabaseObject *) object error: (NSError **) error
{
    return [self resolveFrom: object to: nil error: error];
}

- (id) resolveFrom: (BXDatabaseObject *) object to: (BXEntityDescription *) targetEntity error: (NSError **) error
{
    id rval = nil;
    
    BXEntityDescription* entity = [[object objectID] entity];
    
    if ([relationship1 srcEntity] == entity)
        rval = [relationship1 resolveFrom: object to: targetEntity error: error];
    else if ([relationship2 srcEntity] == entity)
        rval = [relationship2 resolveFrom: object to: targetEntity error: error];
    else if ([entity hasAncestor: [relationship1 srcEntity]])
        rval = [relationship1 resolveFrom: object to: targetEntity error: error];
    else if ([entity hasAncestor: [relationship2 srcEntity]])
        rval = [relationship2 resolveFrom: object to: targetEntity error: error];
    else
        NSAssert (NO, nil);
    
    return rval;
}

- (BOOL) isManyToMany
{
    return NO;
}

- (BOOL) isOneToOne
{
    return YES;
}

- (NSSet *) entities
{
    return [NSSet setWithObjects: [relationship1 srcEntity], [relationship2 srcEntity], nil];
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
    if (relationship2 != aRelationship2) {
        [relationship2 release];
        relationship2 = [aRelationship2 retain];
    }
}

- (NSString *) nameFromEntity: (BXEntityDescription *) entity
{
    NSString* rval = nil;
    
    if ([relationship1 srcEntity] == entity)
        rval = [relationship1 name];
    else if ([relationship2 srcEntity] == entity)
        rval = [relationship2 name];
    else if ([entity hasAncestor: [relationship1 srcEntity]])
        rval = [relationship1 name];
    else if ([entity hasAncestor: [relationship2 srcEntity]])
        rval = [relationship2 name];
    
    return rval;
}

- (void) setTarget: (id) anObject referenceFrom: (BXDatabaseObject *) refObject error: (NSError **) error
{
    //FIXME: these should be in a transaction
    @try
    {
        [relationship1 setTarget: anObject referenceFrom: refObject error: error];
        [relationship2 setTarget: anObject referenceFrom: refObject error: error];
    }
    @catch (BXException* anException)
    {
        if (NULL != error)
            *error = [[anException userInfo] objectForKey: kBXErrorKey];
        else
            [anException raise];
    }    
}

- (void) addObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) anotherObject error: (NSError **) error
{
    //FIXME: make this a little bit better (userInfo etc.)
    [[BXException exceptionWithName: NSInternalInconsistencyException 
                             reason: @"Attempted to treat a to-one relationship as a to-many one."
                           userInfo: nil] raise];
}

- (void) removeObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) anotherObject error: (NSError **) error
{
    //FIXME: make this a little bit better (userInfo etc.)
    [[BXException exceptionWithName: NSInternalInconsistencyException 
                             reason: @"Attempted to treat a to-one relationship as a to-many one."
                           userInfo: nil] raise];    
}

- (NSArray *) subrelationships
{
    return [NSArray arrayWithObjects: relationship1, relationship2, nil];
}
@end
