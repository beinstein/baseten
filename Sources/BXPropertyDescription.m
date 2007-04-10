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


#ifndef L4_BLOCK_ASSERTIONS
static NSMutableDictionary* gProperties;
#endif


/**
 * A property description contains information about a column in a specific entity.
 * The corresponding class in Core Data is NSAttributeDescription. This class is thread-safe.
 */
@implementation BXPropertyDescription

+ (void) initialize
{
	static BOOL tooLate = NO;
	if (NO == tooLate)
	{
		tooLate = YES;
#ifndef L4_BLOCK_ASSERTIONS
		gProperties = [[NSMutableDictionary alloc] init];
#endif
	}
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
	if ((self = [self initWithName: [decoder decodeObjectForKey: @"name"]
							entity: [decoder decodeObjectForKey: @"entity"]]))
	{
		[self setOptional: [decoder decodeBoolForKey: @"isOptional"]];
		[self setPrimaryKey: [decoder decodeBoolForKey: @"isPrimaryKey"]];
		[self setExcluded: [decoder decodeBoolForKey: @"isExcluded"]];
	}
	return self;
}

- (void) encodeWithCoder: (NSCoder *) coder
{
	[coder encodeObject: mName forKey: @"name"];
	[coder encodeObject: mEntity forKey: @"entity"];
	[coder encodeBool: [self isOptional] forKey: @"isOptional"];
	[coder encodeBool: [self isPrimaryKey] forKey: @"isPrimaryKey"];
	[coder encodeBool: [self isExcluded] forKey: @"isExcluded"];
}

- (unsigned int) hash
{
    if (0 == mHash)
        mHash = ([super hash] ^ [mName hash]);
    return mHash;
}

- (BOOL) isEqual: (id) anObject
{
    BOOL rval = [super isEqual: anObject];
    if ([anObject isKindOfClass: [self class]])
    {
        BXPropertyDescription* aDesc = (BXPropertyDescription *) anObject;
        rval = rval && [mEntity isEqual: aDesc->mEntity];
    }
    return rval;
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

/** Whether the attribute is optional. */
- (BOOL) isOptional
{
	return (mFlags & kBXPropertyOptional ? YES : NO);
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


@implementation BXPropertyDescription (PrivateMethods)

/** 
 * \internal
 * \name Creating a property description
 */
//@{
/**
 * \internal
 * Create a property description.
 * \param       aName       Name of the property
 * \param       anEntity    The entity which contains the property.
 * \return                  The property description.
 */
+ (id) propertyWithName: (NSString *) aName entity: (BXEntityDescription *) anEntity
{
    return [[[self alloc] initWithName: aName entity: anEntity] autorelease];
}

/**
 * \internal
 * The designated initializer.
 * Create a property description.
 * \param       aName       Name of the property
 * \param       anEntity    The entity which contains the property.
 * \return                  The property description.
 */
- (id) initWithName: (NSString *) aName entity: (BXEntityDescription *) anEntity
{
    if ((self = [super initWithName: aName]))
    {
        log4AssertValueReturn (nil != anEntity, nil, @"Expected entity not to be nil.");
        mEntity = anEntity; //Weak since entities are not released anyway
		
		//Enforcing this shouldn't be necessary since properties should only get created in our code.
#ifndef L4_BLOCK_ASSERTIONS
		NSMutableSet* entities = [gProperties objectForKey: aName];
		if (nil == entities)
		{
			entities = [NSMutableSet set];
			[gProperties setObject: entities forKey: aName];
		}
		
		TSEnumerate (currentEntity, e, [entities objectEnumerator])
		{
			if (currentEntity == anEntity)
				log4AssertValueReturn (NO, nil, @"Expected to have only single instance of property %@", self);
		}

		[entities addObject: anEntity];
#endif
    }
    return self;
}
//@}

- (id) initWithName: (NSString *) name
{
    [self release];
    return nil;
}

- (void) setOptional: (BOOL) aBool
{
	if (aBool)
		mFlags |= kBXPropertyOptional;
	else
		mFlags &= ~kBXPropertyOptional;
}

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
