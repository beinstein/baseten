//
// BXEntityDescription.h
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
#import <BaseTen/BXAbstractDescription.h>


@protocol BXRelationshipDescription;
@class BXDatabaseContext;
@class BXDatabaseObjectID;

@interface BXEntityDescription : BXAbstractDescription <NSCopying>
{
    NSURL*                  mDatabaseURI;
    NSString*               mSchemaName;
    Class                   mDatabaseObjectClass;
    NSString*               mIBDatabaseObjectClassName;
    NSArray*                mPkeyFields;
    NSSet*                  mViewEntities;
    NSMutableDictionary*    mTargetViews;

    NSMutableSet*           mDependentViewEntities;
    id                      mObjectIDs;    
    NSArray*                mFields;
    NSMutableDictionary*    mRelationships;
    BOOL                    mHasAllRelationships;
}

+ (NSSet *) views;
+ (id) entityWithURI: (NSURL *) anURI table: (NSString *) eName;
+ (id) entityWithURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName;
- (id) initWithURI: (NSURL *) anURI table: (NSString *) tName inSchema: (NSString *) sName;
- (NSURL *) databaseURI;
- (NSString *) schemaName;
- (BOOL) isEqual: (id) anObject;
- (unsigned int) hash;
- (void) setDatabaseObjectClass: (Class) cls;
- (Class) databaseObjectClass;
- (NSString *) IBDatabaseObjectClassName;
- (void) setIBDatabaseObjectClassName:(NSString *)IBDatabaseObjectClassName;
- (void) setPrimaryKeyFields: (NSArray *) anArray;
- (NSArray *) primaryKeyFields;
- (NSArray *) fields;
- (BOOL) viewIsBasedOnTablesInItsSchema: (NSSet *) tableNames;
- (BOOL) viewIsBasedOnEntities: (NSSet *) entities;
- (BOOL) isView;
- (NSSet *) entitiesBasedOn;
- (NSSet *) dependentViews;
- (NSArray *) objectIDs;
- (void) setTargetView: (BXEntityDescription *) viewEntity 
  forRelationshipNamed: (NSString *) relationshipName;
- (NSComparisonResult) caseInsensitiveCompare: (BXEntityDescription *) anotherEntity;
@end


@interface BXEntityDescription (PrivateMethods)
- (void) addDependentView: (BXEntityDescription *) viewEntity;
- (void) setFields: (NSArray *) fieldArray;
- (id <BXRelationshipDescription>) relationshipNamed: (NSString *) aName context: (BXDatabaseContext *) context;
- (void) cacheRelationship: (id <BXRelationshipDescription>) relationship;
- (void) registerObjectID: (BXDatabaseObjectID *) anID;
- (void) unregisterObjectID: (BXDatabaseObjectID *) anID;
- (BXEntityDescription *) targetForRelationship: (id <BXRelationshipDescription>) rel;
- (NSArray *) correspondingProperties: (NSArray *) properties;
- (BOOL) hasAncestor: (BXEntityDescription *) entity;
@end
