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


#ifndef NS_BLOCK_ASSERTIONS
static NSMutableDictionary* gProperties;
#endif


/**
 *  A property description contains information about a column in a specific entity.
 *  The corresponding class in Core Data is NSAttributeDescription. This class is thread-safe.
 */
@implementation BXPropertyDescription

+ (void) initialize
{
	static BOOL tooLate = NO;
	if (NO == tooLate)
	{
		tooLate = YES;
#ifndef NS_BLOCK_ASSERTIONS
		gProperties = [[NSMutableDictionary alloc] init];
#endif
	}
}

/** Entity for this property. */
- (BXEntityDescription *) entity
{
    return mEntity;
}

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
    NSAssert ([anotherObject isKindOfClass: [BXPropertyDescription class]], 
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

- (BOOL) isOptional
{
	return (mOptions & kBXPropertyOptional ? YES : NO);
}

- (BOOL) isPrimaryKey
{
	return (mOptions & kBXPropertyPrimaryKey ? YES : NO);
}

- (BOOL) isExcluded
{
	return (mOptions & kBXPropertyExcluded ? YES : NO);
}

@end


@implementation BXPropertyDescription (PrivateMethods)

/** 
 * \internal
 * \name Creating a property description
 */
//@{
/**
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
        NSAssert (nil != anEntity, @"Expected entity not to be nil.");
        mEntity = anEntity; //Weak since entities are not released anyway
		
		//Enforcing this shouldn't be necessary since properties should only get created in our code.
#ifndef NS_BLOCK_ASSERTIONS
		NSMutableSet* props = [gProperties objectForKey: aName];
		if (nil == props)
		{
			props = [NSMutableSet setWithObject: self];
			[gProperties setObject: props forKey: aName];
		}
		else
		{
			TSEnumerate (currentProp, e, [props objectEnumerator])
			{
				if ([currentProp entity] == anEntity)
					NSAssert1 (NO, @"Expected to have only single instance of property %@", self);
			}
		}
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
		mOptions |= kBXPropertyOptional;
	else
		mOptions &= ~kBXPropertyOptional;
}

- (void) setPrimaryKey: (BOOL) aBool
{
	if (aBool)
	{
		mOptions |= kBXPropertyPrimaryKey;
		mOptions &= ~kBXPropertyExcluded;
	}
	else
	{
		mOptions &= ~kBXPropertyPrimaryKey;
	}
}

- (void) setExcluded: (BOOL) aBool
{
	if (![self isPrimaryKey])
	{
		if (aBool)
			mOptions |= kBXPropertyExcluded;
		else
			mOptions &= ~kBXPropertyExcluded;
	}
}

@end
