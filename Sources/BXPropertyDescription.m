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
#import "BXLogger.h"


/**
 * \brief A superclass for various description classes.
 * \note This class's documented methods are thread-safe. Creating objects, however, is not.
 * \note For this class to work in non-GC applications, the corresponding database context must be retained as well.
 * \ingroup descriptions
 */
@implementation BXPropertyDescription

/** \brief Entity for this property. */
- (BXEntityDescription *) entity
{
    return mEntity;
}

/** \brief Retain on copy. */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}

//FIXME: need we this?
#if 0
- (id) mutableCopyWithZone: (NSZone *) zone
{
	id retval = [[[self class] allocWithZone: zone] initWithName: mName entity: mEntity];
	//Probably best not to set flags?
	return retval;
}
#endif

- (id) initWithCoder: (NSCoder *) decoder
{
	if ((self = [super initWithCoder: decoder]))
	{
		mEntity = [decoder decodeObjectForKey: @"entity"];
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
    NSComparisonResult retval = NSOrderedSame;
    if (self != anotherObject)
    {
        retval = [[self entity] caseInsensitiveCompare: [anotherObject entity]];
        if (NSOrderedSame == retval)
            retval = [[self name] caseInsensitiveCompare: [anotherObject name]];
    }
    return retval;
}

/** \brief Whether the property is optional. */
- (BOOL) isOptional
{
	return (mFlags & kBXPropertyOptional ? YES : NO);
}

/** \brief The property's subtype. */
- (enum BXPropertyKind) propertyKind
{
	return kBXPropertyNoKind;
}
@end


@implementation BXPropertyDescription (PrivateMethods)
- (void) setOptional: (BOOL) optional
{
	if (optional)
		mFlags |= kBXPropertyOptional;
	else
		mFlags &= ~kBXPropertyOptional;	
}

/**
 * \internal
 * \brief The designated initializer.
 */
- (id) initWithName: (NSString *) aName entity: (BXEntityDescription *) anEntity
{
    if ((self = [super initWithName: aName]))
    {
		mEntity = anEntity;
		mHash = [super hash] ^ [mEntity hash];
	}
	return self;
}

- (id) initWithName: (NSString *) name
{
	[self doesNotRecognizeSelector: _cmd];
    return nil;
}

- (NSString *) qualifiedName
{
	return [NSString stringWithFormat: @"%@.%@.%@", [mEntity schemaName], [mEntity name], mName];
}
@end
