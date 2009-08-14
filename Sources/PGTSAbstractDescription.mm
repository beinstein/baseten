//
// PGTSAbstractDescription.mm
// BaseTen
//
// Copyright (C) 2006-2009 Marko Karppinen & Co. LLC.
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


#import "PGTSAbstractDescription.h"


void 
PGTS::InsertConditionally (IdMap* map, PGTSAbstractDescription* description)
{
	NSString* name = [description name];
	if (! (* map) [name])
		(* map) [[name retain]] = [description retain];
}


/** 
 * \internal
 * \brief Abstract base class.
 */
@implementation PGTSAbstractDescription
+ (BOOL) accessInstanceVariablesDirectly
{
    return NO;
}

- (void) dealloc
{
    [mName release];
    [super dealloc];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<%@ (%p) %@>", 
			[self class], self, mName];
}

- (NSString *) name
{
	return mName;
}

- (void) setName: (NSString *) aString
{
	if (aString != mName)
	{
		[mName release];
		mName = [aString copy];
		mHash = [mName hash];
	}
}

/**
 * \internal
 * \brief Retain on copy.
 */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}

- (BOOL) isEqual: (PGTSAbstractDescription *) anObject
{
    BOOL retval = NO;
    if (! [anObject isKindOfClass: [self class]])
        retval = [super isEqual: anObject];
    else
    {
        retval = [mName isEqualToString: anObject->mName];
    }
    return retval;
}

- (NSUInteger) hash
{
    return mHash;
}
@end
