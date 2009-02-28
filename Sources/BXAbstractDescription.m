//
// BXAbstractDescription.m
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

#import "BXAbstractDescription.h"
#import "BXLogger.h"


/**
 * \brief An abstract superclass for various description classes.
 *
 * \note This class's documented methods are thread-safe. Creating objects, however, is not.
 * \note For this class to work in non-GC applications, the corresponding database context must be retained as well.
 * \ingroup descriptions
 */
@implementation BXAbstractDescription

- (id) initWithName: (NSString *) aName
{
    if ((self = [super init]))
    {
        BXAssertValueReturn (nil != aName, nil, @"Expected name not to be nil.");
        mName = [aName copy];
		mHash = [mName hash];
    }
    return self;
}

- (id) initWithCoder: (NSCoder *) decoder
{
	if ((self = [self initWithName: [decoder decodeObjectForKey: @"name"]]))
	{
	}
	return self;
}

- (void) dealloc
{
	[mName release];
	[super dealloc];
}

- (void) encodeWithCoder: (NSCoder *) encoder
{
	[encoder encodeObject: mName forKey: @"name"];
}

/** \brief Name of the object. */
- (NSString *) name
{
    return [[mName retain] autorelease];
}

- (unsigned int) hash
{
    return mHash;
}

- (NSComparisonResult) compare: (id) anObject
{
    NSComparisonResult retval = NSOrderedSame;
    if ([anObject isKindOfClass: [self class]])
        retval = [[self name] compare: [anObject name]];
    return retval;
}

- (NSComparisonResult) caseInsensitiveCompare: (id) anObject
{
    NSComparisonResult retval = NSOrderedSame;
    if ([anObject isKindOfClass: [self class]])
        retval = [[self name] caseInsensitiveCompare: [anObject name]];
    return retval;
}

- (BOOL) isEqual: (BXAbstractDescription *) desc
{
    BOOL retval = NO;
    if ([desc isKindOfClass: [self class]])
    {
        retval = [[self name] isEqualToString: [desc name]];
    }
    return retval;
}
@end
