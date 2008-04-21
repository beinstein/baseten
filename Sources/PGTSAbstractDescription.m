//
// PGTSAbstractDescription.m
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
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

#import <PGTS/PGTSAbstractDescription.h>
#import <PGTS/PGTSConstants.h>


/** 
 * Abstract base class
 */
@implementation PGTSAbstractDescription

+ (BOOL) accessInstanceVariablesDirectly
{
    return NO;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [mName release];
    [super dealloc];
}

- (void) setName: (NSString *) aString
{
    if (aString != mName)
    {
        [mName release];
        mName = [aString copy];
    }
}

- (PGTSConnection *) connection
{
    return mConnection;
}

- (void) setConnection: (PGTSConnection *) aConnection
{
    mConnection = aConnection;
}

- (void) setDescriptionProxy: (PGTSAbstractDescriptionProxy *) aProxy
{
	mProxy = aProxy;
}

- (NSString *) name
{
    return mName;
}

/**
 * Retain on copy.
 */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}

- (BOOL) isEqual: (id) anObject
{
    BOOL rval = NO;
    if (NO == [anObject isKindOfClass: [self class]])
        rval = [super isEqual: anObject];
    else
    {
        PGTSAbstractDescription* anInfo = (PGTSAbstractDescription *) anObject;
        rval = ([mConnection isEqual: anInfo->mConnection] &&
                [mName isEqualToString: anInfo->mName]);
    }
    return rval;
}

- (unsigned int) hash
{
    if (0 == mHash)
        mHash = ([mConnection hash] ^ [mName hash]);
    return mHash;
}
@end
