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

#import <TSDataTypes/TSDataTypes.h>
#import <Log4Cocoa/Log4Cocoa.h>


static TSNonRetainedObjectSet* gProperties;


/**
 * A superclass for various description classes.
 * \ingroup BaseTen
 */
@implementation BXPropertyDescription

/** \note Override dealloc2 in subclasses instead! */
- (void) dealloc
{
	[[self class] unregisterProperty: self];
	[self dealloc2];
	
	//Suppress a compiler warning.
	if (0) [super dealloc];
}

- (void) dealloc2
{
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

//FIXME: should we have init2... as well?
- (id) initWithCoder: (NSCoder *) decoder
{
	if ((self = [super initWithCoder: decoder]))
	{
		[self setEntity: [decoder decodeObjectForKey: @"entity"]];
		[self setOptional: [decoder decodeBoolForKey: @"isOptional"]];
		log4AssertLog ([[self class] registerProperty: self], 
					   @"Expected to have only single instance of property %@.", self);
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

+ (void) initialize
{
	static BOOL tooLate = NO;
	if (!tooLate)
	{
		tooLate = YES;
		gProperties = [[TSNonRetainedObjectSet alloc] init];
	}
}

+ (BOOL) registerProperty: (id) aProperty
{
	BOOL retval = NO;
	@synchronized (gProperties)
	{
		if (! [gProperties containsObject: aProperty])
		{
			retval = YES;
			[gProperties addObject: aProperty];
		}
	}
	return retval;
}

+ (void) unregisterProperty: (id) aProperty
{
	@synchronized (gProperties)
	{
		[gProperties removeObject: aProperty];
	}
}

/**
 * \internal
 * The designated initializer.
 */
- (id) initWithName: (NSString *) aName entity: (BXEntityDescription *) anEntity
{
    if ((self = [super initWithName: aName]))
    {
		[self setEntity: anEntity];
		//Check only since only our code is supposed to create new properties.
		log4AssertLog ([[self class] registerProperty: self], 
					   @"Expected to have only single instance of property %@.", self);
	}
	return self;
}

- (id) initWithName: (NSString *) name
{
	log4Error (@"This initializer should not have been called (name: %@).", name);
    [self release];
    return nil;
}

- (void) setEntity: (BXEntityDescription *) anEntity
{
	mEntity = anEntity; //Weak
}

- (void) setOptional: (BOOL) aBool
{
	if (aBool)
		mFlags |= kBXPropertyOptional;
	else
		mFlags &= ~kBXPropertyOptional;
}

@end
