//
// BXPropertyDescription.m
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
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
#import "BXLogger.h"

#import "MKCCollections.h"


__strong static id gProperties = nil;


/**
 * A superclass for various description classes.
 * \ingroup descriptions
 */
@implementation BXPropertyDescription

/** 
 * \internal
 * \note Override dealloc2 in subclasses instead! 
 */
- (void) dealloc
{
	[[self class] unregisterProperty: self entity: mEntity];
	[self dealloc2];
	[super dealloc];
}

/**
 * \internal
 * Deallocation helper. 
 * Subclasses should override this instead of dealloc and then call 
 * super's implementation of dealloc2. This is because BXPropertyDescriptions 
 * will be stored into a non-retaining collection on creation and removed from 
 * it on dealloc.
 */
- (void) dealloc2
{
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

- (id) mutableCopyWithZone: (NSZone *) zone
{
	id retval = [[[self class] allocWithZone: zone] initWithName: mName entity: mEntity];
	//Probably best not to set flags?
	return retval;
}

//FIXME: should we have init2... as well?
- (id) initWithCoder: (NSCoder *) decoder
{
	if ((self = [super initWithCoder: decoder]))
	{
		[self setEntity: [decoder decodeObjectForKey: @"entity"]];
		[self setOptional: [decoder decodeBoolForKey: @"isOptional"]];
		BXAssertLog ([[self class] registerProperty: self entity: mEntity], 
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
	return [self qualifiedName];
}

- (NSComparisonResult) caseInsensitiveCompare: (BXPropertyDescription *) anotherObject
{
    BXAssertValueReturn ([anotherObject isKindOfClass: [BXPropertyDescription class]], NSOrderedSame,
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

- (enum BXPropertyKind) propertyKind
{
	return kBXPropertyNoKind;
}
@end


@implementation BXPropertyDescription (PrivateMethods)

+ (void) initialize
{
	static BOOL tooLate = NO;
	if (!tooLate)
	{
		tooLate = YES;
		gProperties = [[NSMutableSet alloc] init];
	}
}

+ (BOOL) registerProperty: (id) aProperty entity: (BXEntityDescription *) entity
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

	BXLogDebug (@"Called registerProperty: %@ entity: %@", [aProperty qualifiedName], entity);

	return retval;
}

+ (void) unregisterProperty: (id) aProperty entity: (BXEntityDescription *) entity
{
	BXLogDebug (@"Called unregisterProperty: %@ entity: %@", [aProperty qualifiedName], entity);
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
		BXAssertLog ([[self class] registerProperty: self entity: mEntity], 
					 @"Expected to have only single instance of property %@.", self);
	}
	return self;
}

- (id) initWithName: (NSString *) name
{
	BXLogError (@"This initializer should not have been called (name: %@).", name);
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

- (NSString *) qualifiedName
{
	return [NSString stringWithFormat: @"%@.%@.%@", [mEntity schemaName], [mEntity name], mName];
}
@end
