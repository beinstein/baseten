//
// BXPropertyDescription.m
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

#import "BXPropertyDescription.h"
#import "BXPropertyDescriptionPrivate.h"
#import "BXEntityDescription.h"
#import "BXDatabaseAdditions.h"

#import <Log4Cocoa/Log4Cocoa.h>


@implementation BXPropertyDescription

- (void) dealloc
{
	[mEntity release];
	[super dealloc];
}

/** Entity for this property. */
- (BXEntityDescription *) entity
{
    return mEntity;
}

/** Retain on copy. */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}

- (id) initWithCoder: (NSCoder *) decoder
{
	if ((self = [super initWithCoder: decoder]))
	{
		[self setEntity: [decoder decodeObjectForKey: @"entity"]];
		[self setOptional: [decoder decodeBoolForKey: @"isOptional"]];
	}
	return self;
}

- (void) encodeWithCoder: (NSCoder *) coder
{
	[coder encodeObject: mEntity forKey: @"entity"];	
	[coder encodeBool: [self isOptional] forKey: @"isOptional"];
	[super encodeWithCoder: coder];
}

- (unsigned int) hash
{
	if (0 == mHash)
	{
		mHash = [super hash] ^ [mEntity hash];
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
		BXPropertyDescription* aDesc = (BXPropertyDescription *) anObject;
		retval = [mEntity isEqual: aDesc->mEntity];
	}
    return retval;
}

- (NSString *) description
{
    //return [NSString stringWithFormat: @"<%@ (%p) name: %@ entity: %@>", [self class], self, name, mEntity];
    return [NSString stringWithFormat: @"%@.%@.%@", [mEntity schemaName], [mEntity name], mName];
}

- (NSComparisonResult) caseInsensitiveCompare: (BXPropertyDescription *) anotherObject
{
    log4AssertValueReturn ([anotherObject isKindOfClass: [BXPropertyDescription class]], NSOrderedSame,
						   @"Property descriptions can only be compared with other similar objects for now.");
    NSComparisonResult rval = NSOrderedSame;
    if (self != anotherObject)
    {
        rval = [mEntity caseInsensitiveCompare: [anotherObject entity]];
        if (NSOrderedSame == rval)
            rval = [mName caseInsensitiveCompare: [anotherObject name]];
    }
    return rval;
}

/** Whether the property is optional. */
- (BOOL) isOptional
{
	return (mFlags & kBXPropertyOptional ? YES : NO);
}

@end


@implementation BXPropertyDescription (PrivateMethods)

- (id) initWithName: (NSString *) aName entity: (BXEntityDescription *) anEntity
{
    if ((self = [super initWithName: aName]))
    {
		[self setEntity: anEntity];
	}
	return self;
}

- (void) setEntity: (BXEntityDescription *) anEntity
{
	if (mEntity != anEntity)
	{
		[mEntity release];
		mEntity = [anEntity retain];
	}
}

- (void) setOptional: (BOOL) aBool
{
	if (aBool)
		mFlags |= kBXPropertyOptional;
	else
		mFlags &= ~kBXPropertyOptional;
}

@end
