//
// BXRelationshipDescription.h
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
@class BXEntityDescription;


@interface BXRelationshipDescription : BXAbstractDescription <BXRelationshipDescription>
{
    NSArray* srcProperties;
    NSArray* dstProperties;
}

+ (BOOL) returnsArrayProxies;
+ (void) setReturnsArrayProxies: (BOOL) aBool;

+ (id) relationshipWithName: (NSString *) aName
              srcProperties: (NSArray *) anArray
              dstProperties: (NSArray *) anotherArray;
- (id) initWithName: (NSString *) aName 
      srcProperties: (NSArray *) anArray
      dstProperties: (NSArray *) anotherArray;

- (NSArray *) srcProperties;
- (NSArray *) dstProperties;
- (void) setSRCProperties: (NSArray *) anArray;
- (void) setDSTProperties: (NSArray *) anArray;
- (BXEntityDescription *) srcEntity;
- (BXEntityDescription *) dstEntity;

- (void) addObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) refObject 
                 to: (BXEntityDescription *) targetEntity name: (NSString *) name error: (NSError **) error;
- (void) removeObjects: (NSSet *) objectSet referenceFrom: (BXDatabaseObject *) refObject 
                    to: (BXEntityDescription *) targetEntity name: (NSString *) name error: (NSError **) error;
- (BXEntityDescription *) otherEntity: (BXEntityDescription *) anEntity;
@end
