//
// PGTSColumnDescription.m
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

#import "PGTSColumnDescription.h"
#import "NSString+PGTSAdditions.h"


/** 
 * \internal
 * \brief Table field.
 */
@implementation PGTSColumnDescription

- (id) init
{
    if ((self = [super init]))
    {
        mIndex = 0;
    }
    return self;
}

- (void) dealloc
{
	[mDefaultValue release];
	[super dealloc];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<%@ (%p) %@ (%d)>", 
			[self class], self, mName, mIndex];
}

- (void) setIndex: (NSInteger) anIndex
{
    mIndex = anIndex;
}

- (NSString *) name
{
    return mName;
}

- (NSString *) quotedName: (PGTSConnection *) connection
{
	NSString* retval = nil;
    if (nil != mName)
        retval = [mName quotedIdentifierForPGTSConnection: connection];
    return retval;
}

- (NSInteger) index
{
    return mIndex;
}

- (NSString *) defaultValue
{
	return mDefaultValue;
}

- (PGTSTypeDescription *) type
{
	return mType;
}

- (NSComparisonResult) indexCompare: (PGTSColumnDescription *) aCol
{
    NSComparisonResult result = NSOrderedAscending;
    NSInteger anIndex = aCol->mIndex;
    if (mIndex > anIndex)
        result = NSOrderedDescending;
    else if (mIndex == anIndex)
        result = NSOrderedSame;
    return result;
}

- (BOOL) isNotNull
{
	return mIsNotNull;
}

- (void) setType: (PGTSTypeDescription *) type
{
	if (mType != type)
	{
		[mType release];
		mType = [type retain];
	}
}

- (void) setNotNull: (BOOL) aBool
{
	mIsNotNull = aBool;
}

- (void) setDefaultValue: (NSString *) anObject
{
	if (mDefaultValue != anObject)
	{
		[mDefaultValue release];
		mDefaultValue = [anObject retain];
	}
}
@end
