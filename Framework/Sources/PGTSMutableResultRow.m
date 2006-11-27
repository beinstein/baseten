//
// PGTSMutableResultRow.m
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

#import "PGTSMutableResultRow.h"


/** A mutable version of PGTSResultRow */
@implementation PGTSMutableResultRow

- (void) setValue: (id) value forKey: (id) aKey
{
    [writeDelegate setValue: value forField: aKey row: rowNumber];
}

//FIXME: this needs to be rethought.
- (id) initWithWriteDelegate: (id <PGTSWriteDelegateProtocol>) anObject
{
    if ((self = [super init]))
    {
        [self setWriteDelegate: anObject];
    }
    return self;
}

- (void) dealloc
{
    [writeDelegate release];
    [super dealloc];
}

/**
 * Set the object that manages modifying the values for this row
 */
- (void) setWriteDelegate: (id <PGTSWriteDelegateProtocol>) anObject
{
    if (writeDelegate != anObject)
    {
        [writeDelegate release];
        writeDelegate = [anObject retain];
    }
}

@end
