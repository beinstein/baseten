//
// PGTSTypeDescription.m
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

#import "PGTSTypeDescription.h"
#import "PGTSResultSet.h"
#import "PGTSFunctions.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"


/** 
 * Data type in a database.
 */
@implementation PGTSTypeDescription

- (id) init
{
    if ((self = [super init]))
    {
        mElementOid = InvalidOid;
        mElementCount = 0;
        mDelimiter = '\0';
    }
    return self;
}

- (NSString *) description
{
	id retval = nil;
	@synchronized (self)
	{
    	retval = [NSString stringWithFormat: @"%@ (%p) oid: %u sOid: %u sName: %@ t: %@ eOid: %u d: %c", 
				  [self class], self, mOid, mSchemaOid, mSchemaName, mName, mElementOid, mDelimiter];
	}
	return retval;
}

- (Class) proxyClass
{
	return Nil;
}

- (id) proxy
{
	return self;
}

- (NSString *) name
{
	id retval = nil;
	@synchronized (self)
	{
	    retval = [[mName copy] autorelease];
	}
	return retval;
}

//These are set once and never changed.
- (Oid) elementOid
{
	return mElementOid;
}

- (char) delimiter
{
    return mDelimiter;
}

- (char) kind
{
	return mKind;
}

- (void) setElementOid: (Oid) elementOid
{
	mElementOid = elementOid;
}

- (void) setDelimiter: (char) delimiter
{
	mDelimiter = delimiter;
}

- (void) setKind: (char) kind
{
	mKind = kind;
}
@end
