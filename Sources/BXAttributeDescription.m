//
// BXAttributeDescription.m
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

#import "BXAttributeDescription.h"
#import "BXAttributeDescriptionPrivate.h"
#import "BXEntityDescription.h"
#import "BXDatabaseAdditions.h"
#import "BXPropertyDescriptionPrivate.h"

#import <Log4Cocoa/Log4Cocoa.h>



/**
 * An attribute description contains information about a column in a specific entity.
 */
@implementation BXAttributeDescription

- (id) initWithCoder: (NSCoder *) decoder
{
	if ((self = [super initWithCoder: decoder]))
	{
		[self setPrimaryKey: [decoder decodeBoolForKey: @"isPrimaryKey"]];
		[self setExcluded: [decoder decodeBoolForKey: @"isExcluded"]];
	}
	return self;
}

- (void) encodeWithCoder: (NSCoder *) coder
{
	[coder encodeBool: [self isPrimaryKey] forKey: @"isPrimaryKey"];
	[coder encodeBool: [self isExcluded] forKey: @"isExcluded"];
	[super encodeWithCoder: coder];
}

/** Whether the attribute is part of the primary key for its entity. */
- (BOOL) isPrimaryKey
{
	return (mFlags & kBXPropertyPrimaryKey ? YES : NO);
}

/** Whether the attribute will be excluded from fetches and queried only when needed. */
- (BOOL) isExcluded
{
	return (mFlags & kBXPropertyExcluded ? YES : NO);
}

@end


@implementation BXAttributeDescription (PrivateMethods)

/** 
 * \internal
 * \name Creating an attribute description
 */
//@{
/**
 * \internal
 * Create an attribute description.
 * \param       aName       Name of the attribute
 * \param       anEntity    The entity which contains the attribute.
 * \return                  The attribute description.
 */
+ (id) attributeWithName: (NSString *) aName entity: (BXEntityDescription *) anEntity
{
    return [[[self alloc] initWithName: aName entity: anEntity] autorelease];
}
//@}

- (void) setPrimaryKey: (BOOL) aBool
{
	if (aBool)
	{
		mFlags |= kBXPropertyPrimaryKey;
		mFlags &= ~kBXPropertyExcluded;
	}
	else
	{
		mFlags &= ~kBXPropertyPrimaryKey;
	}
}

- (void) setExcluded: (BOOL) aBool
{
	if (![self isPrimaryKey])
	{
		if (aBool)
			mFlags |= kBXPropertyExcluded;
		else
			mFlags &= ~kBXPropertyExcluded;
	}
}

@end