//
// BXOneToOneRelationshipDescription.h
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

@protocol BXRelationshipDescription;
@class BXRelationshipDescription;


@interface BXOneToOneRelationshipDescription : NSObject <BXRelationshipDescription>
{
    BXRelationshipDescription* relationship1;
    BXRelationshipDescription* relationship2;
}

+ (id) relationshipWithRelationship1: (BXRelationshipDescription *) r1 
                       relationship2: (BXRelationshipDescription *) r2;
- (id) initWithRelationship1: (BXRelationshipDescription *) r1 relationship2: (BXRelationshipDescription *) r2;

- (void) setRelationship1: (BXRelationshipDescription *) aRelationship1;
- (void) setRelationship2: (BXRelationshipDescription *) aRelationship2;
- (BXRelationshipDescription *) relationship1;
- (BXRelationshipDescription *) relationship2;
- (BXEntityDescription *) otherEntity: (BXEntityDescription *) anEntity;

@end
