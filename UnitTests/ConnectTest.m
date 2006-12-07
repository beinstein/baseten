//
// ConnectTest.m
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

#import "ConnectTest.h"
#import <BaseTen/BaseTen.h>
#import "MKCSenTestCaseAdditions.h";


@implementation ConnectTest

- (void) setUp
{
    ctx = [[BXDatabaseContext alloc] init];
}

- (void) tearDown
{
    [ctx release];
}

- (void) testConnect1
{
    
    MKCAssertNoThrow ([ctx setDatabaseURI: [NSURL URLWithString: @"pgsql://tsnorri@localhost/basetentest"]]);
    MKCAssertNoThrow ([ctx connectIfNeeded: nil]);
}

- (void) testConnect2
{
    MKCAssertNoThrow ([ctx setDatabaseURI: [NSURL URLWithString: @"pgsql://tsnorri@localhost/basetentest/"]]);
    MKCAssertNoThrow ([ctx connectIfNeeded: nil]);
}
 
- (void) testConnectFail1
{
    MKCAssertNoThrow ([ctx setDatabaseURI: [NSURL URLWithString: @"pgsql://tsnorri@localhost/anonexistantdatabase"]]);
    MKCAssertThrows ([ctx connectIfNeeded: nil]);
}
 
- (void) testConnectFail2
{
    MKCAssertNoThrow ([ctx setDatabaseURI: 
        [NSURL URLWithString: @"pgsql://tsnorri@localhost/basetentest/a/malformed/database/uri"]]);
    MKCAssertThrows ([ctx connectIfNeeded: nil]);
}

- (void) testConnectFail3
{
    MKCAssertThrows ([ctx setDatabaseURI: [NSURL URLWithString: @"invalid://tsnorri@localhost/invalid"]]);
}

@end
