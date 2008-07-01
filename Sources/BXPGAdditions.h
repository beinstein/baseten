//
// BXPGAdditions.h
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

#import <Foundation/Foundation.h>
#import <PGTS/PGTS.h>

#import "BaseTen.h"

#define Expect( X )	BXAssertValueReturn( X, nil, @"Expected " #X " to have been set.");
#define ExpectR( X, RETVAL )	BXAssertValueReturn( X, RETVAL, @"Expected " #X " to have been set.");
#define ExpectV( X ) BXAssertVoidReturn( X, @"Expected " #X " to have been set.");
//C function variants.
#define ExpectC( X ) Expect( X )
#define ExpectCV( X ) ExpectV( X )
#define ExpectCR( X, RETVAL ) ExpectR( X, RETVAL )


@interface NSObject (BXPGAdditions)
- (NSString *) BXPGEscapedName: (PGTSConnection *) connection;
- (NSString *) BXPGQualifiedName: (PGTSConnection *) connection;
@end


@interface PGTSFieldDescriptionProxy (BXPGInterfaceAdditions)
- (NSString *) BXPGEscapedName: (PGTSConnection *) connection;
@end


@interface BXEntityDescription (BXPGInterfaceAdditions)
- (NSString *) BXPGQualifiedName: (PGTSConnection *) connection;
@end


@interface BXAttributeDescription (BXPGInterfaceAdditions)
- (NSString *) BXPGQualifiedName: (PGTSConnection *) connection;
@end


@interface NSURL (BXPGInterfaceAdditions)
- (NSMutableDictionary *) BXPGConnectionDictionary;
@end


@interface BXDatabaseObject (BXPGInterfaceAdditions) <PGTSResultRowProtocol>
@end
