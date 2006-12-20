//
// BXRelationshipDescriptionProtocol.h
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

#import <Foundation/Foundation.h>

@class BXDatabaseObject;
@class BXEntityDescription;

/** 
 * A protocol to which relationship descriptions acquired from the database context conform. 
 * \note    Normally, objects conforming to this protocol needen't be used directly. Instead, 
 *          BXDatabaseObject's -valueForKey: and -primitiveValueForKey: methods cause the 
 *          relationships to be resolved automatically, when using the foreign key's name, 
 *          the referencing foreign key's name or the helper table's name as the key.
 *
 * Relationships in BaseTen differ from those of Core Data in that they are always bidirectional.
 * The direction is determined when the relationship is resolved.
 */
@protocol BXRelationshipDescription <NSObject>
/** Whether this relationship is to-many from the given entity. */
- (int) isToManyFromEntity: (BXEntityDescription *) entity;
/** 
 * Name of the relationship from the given entity.
 * The relationship name might be taken from the corresponding foreign key, in which case the name
 * might vary from one entity to another.
 */
- (NSString *) nameFromEntity: (BXEntityDescription *) entity;
/**
 * Resolve the relationship from the given object.
 * \param       object      The object which is used as the source. Objects from the destination entity
 *                          will be returned.
 * \param       error       If an error occurs, the error parameter will be set. If NULL, an BXException will be
 *                          raised on error.
 * \throw       BXException named \c kBXExceptionUnhandledError if \c error is NULL 
 *                          and the query failed.
 * \return                  Either a BXDatabaseObject or an NSArray of them, if the relationship 
 *                          is to-many from the given object.
 */
- (id) resolveFrom: (BXDatabaseObject *) object error: (NSError **) error;
/**
 * Resolve the relationship from the given object.
 * Returned objects are from the target entity, which should be a view that is based on an entity this relationship
 * knows of.
 * \param       object       The object which is used as the source. Objects from the destination entity
 *                           will be returned.
 * \param       targetEntity The destination entity should be passed, if it is a view.
 * \param       error        If an error occurs, the error parameter will be set. If NULL, an BXException will be
 *                           raised on error.
 * \throw       BXException named \c kBXExceptionUnhandledError if \c error is NULL 
 *                           and the query failed.
 * \return                   Either a BXDatabaseObject or an NSArray of them, if the relationship 
 *                           is to-many from the given object.
 */
- (id) resolveFrom: (BXDatabaseObject *) object to: (BXEntityDescription *) targetEntity error: (NSError **) error;
/** Whether this relationship is many-to-many. */
- (BOOL) isManyToMany;
/** Whether this relationship is one-to-one. */
- (BOOL) isOneToOne;
/** Entities that are part of this relationship. */
- (NSSet *) entities;

/** Add objects to a to-many relationship. */
- (void) addObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) anotherObject error: (NSError **) error;
/** Remove objects from a to-many relationship. */
- (void) removeObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) anotherObject error: (NSError **) error;
/** Set either a to-one or a to-many relationship's target depending on the relationship type and the reference object. */
- (void) setTarget: (id) target referenceFrom: (BXDatabaseObject *) refObject error: (NSError **) error;
- (NSArray *) subrelationships;
@end
