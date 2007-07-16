//
// BXRelationshipDescription.m
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
// $Id: BXRelationshipDescription.m 225 2007-07-12 08:33:55Z tuukka.norri@karppinen.fi $
//

#import "BXRelationshipDescription.h"
#import "BXEntityDescriptionPrivate.h"


@implementation BXRelationshipDescription

- (void) dealloc
{
	[mForeignKey release];
	[super dealloc];
}

- (BXEntityDescription *) destinationEntity
{
    return mDestinationEntity;
}

- (BXRelationshipDescription *) inverseRelationship
{
	return [mDestinationEntity inverseRelationshipFor: self];
}

- (NSDeleteRule) deleteRule
{
    //FIXME: this is only a stub.
    return NSNoActionDeleteRule;
}

- (BOOL) isToMany
{
	return mIsToMany;
}

/** Retain on copy. */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}

- (unsigned int) hash
{
	if (0 == mHash)
	{
		mHash = [super hash] ^ [mDestinationEntity hash] ^ [mForeignKey hash];
	}
	return mHash;
}

- (BOOL) isEqual: (id) anObject
{
	BOOL retval = NO;
	if (anObject == self)
		retval = YES;
	else if ([super isEqual: anObject] && [anObject isKindOfClass: [self class]])
	{
		BXRelationshipDescription* aDesc = (BXRelationshipDescription *) anObject;
		if ([mDestinationEntity isEqual: aDesc->mDestinationEntity] &&
			[mForeignKey isEqual: aDesc->mForeignKey])
		{
			retval = YES;
		}
	}
    return retval;	
}

@end


@implementation BXRelationshipDescription (PrivateMethods)

- (void) setDestinationEntity: (BXEntityDescription *) entity
{
	mDestinationEntity = entity; //Weak;
}

- (void) setForeignKey: (BXForeignKey *) aKey
{
	if (mForeignKey != aKey)
	{
		[mForeignKey release];
		mForeignKey = [aKey retain];
	}
}

- (void) setIsToMany: (BOOL) aBool
{
	mIsToMany = aBool;
}

- (void) setInverseName: (NSString *) aString
{
	//FIXME: stub.
}

@end