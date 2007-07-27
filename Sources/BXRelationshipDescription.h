//
// BXRelationshipDescription.h
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
// $Id: BXRelationshipDescription.h 225 2007-07-12 08:33:55Z tuukka.norri@karppinen.fi $
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <BaseTen/BXPropertyDescription.h>

@class BXForeignKey;

/**
 * \note For this class to work in non-GC applications, the corresponding database context must be retained as well.
 */
@interface BXRelationshipDescription : BXPropertyDescription
{
	//FIXME: If entity objects are made non-persistent, 
	//this field should be nullified when the corresponding entity gets dealloced.
    BXEntityDescription* mDestinationEntity; //Weak

	BXForeignKey* mForeignKey;
	NSString* mInverseName;
	NSDeleteRule mDeleteRule;
	BOOL mIsInverse;
}

- (BXEntityDescription *) destinationEntity;
- (BXRelationshipDescription *) inverseRelationship;
- (NSDeleteRule) deleteRule;
- (BOOL) isToMany;
@end
