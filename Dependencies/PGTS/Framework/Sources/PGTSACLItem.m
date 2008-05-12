//
// PGTSACLItem.m
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

#import "PGTSACLItem.h"
#import "PGTSRoleDescription.h"


@implementation PGTSACLItem

- (id) init
{
    if ((self = [super init]))
    {
        mPrivileges = kPGTSPrivilegeNone;
    }
    return self;
}

- (void) dealloc
{
    [mRole release];
    [mGrantingRole release];
    [super dealloc];
}

- (PGTSRoleDescription *) role
{
    return mRole;
}

- (void) setRole: (PGTSRoleDescription *) aRole
{
    if (mRole != aRole) {
        [mRole release];
        mRole = [aRole retain];
    }
}

- (PGTSRoleDescription *) grantingRole
{
    return mGrantingRole; 
}

- (void) setGrantingRole: (PGTSRoleDescription *) aGrantingRole
{
    if (mGrantingRole != aGrantingRole) {
        [mGrantingRole release];
        mGrantingRole = [aGrantingRole retain];
    }
}

- (enum PGTSACLItemPrivilege) privileges
{
    return mPrivileges;
}

- (void) setPrivileges: (enum PGTSACLItemPrivilege) anEnum
{
    mPrivileges = anEnum;
}

@end
