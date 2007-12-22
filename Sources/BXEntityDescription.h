//
// BXEntityDescription.h
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
// $Id$
//

#import <Foundation/Foundation.h>
#import <BaseTen/BXAbstractDescription.h>


@class BXDatabaseContext;
@class BXDatabaseObjectID;


enum BXEntityFlag
{
	kBXEntityNoFlag					= 0,
	//kBXEntityHasAllRelationships	= 1 << 0, //Not needed
	kBXEntityIsValidated			= 1 << 1,
	kBXEntityIsView					= 1 << 2
};

@interface BXEntityDescription : BXAbstractDescription <NSCopying, NSCoding>
{
    NSURL*                  mDatabaseURI;
    NSString*               mSchemaName;
    Class                   mDatabaseObjectClass;
	NSDictionary*			mAttributes;
	NSLock*					mValidationLock;

    id                      mObjectIDs;    
    id						mRelationships;
    id                      mInheritedEntities;
    id                      mSubEntities;
    enum BXEntityFlag       mFlags;
}

- (void) dealloc2;
- (NSURL *) databaseURI;
- (NSString *) schemaName;
- (BOOL) isEqual: (id) anObject;
- (unsigned int) hash;
- (void) setDatabaseObjectClass: (Class) cls;
- (Class) databaseObjectClass;
- (void) setPrimaryKeyFields: (NSArray *) anArray;
- (NSDictionary *) attributesByName;
- (NSArray *) primaryKeyFields;
- (NSArray *) fields;
- (BOOL) isView;
- (NSArray *) objectIDs;
- (NSComparisonResult) caseInsensitiveCompare: (BXEntityDescription *) anotherEntity;
- (BOOL) isValidated;
- (NSDictionary *) relationshipsByName;
@end
