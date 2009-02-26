//
// PGTSACLItem.m
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

#import "PGTSACLItem.h"
#import "PGTSConnection.h"
#import "PGTSResultSet.h"
#import "PGTSConstants.h"
#import "PGTSDatabaseDescription.h"
#import "BXLogger.h"


@class PGTSTypeDescription;


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
    if (mRole != aRole) 
	{
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
    if (mGrantingRole != aGrantingRole) 
	{
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

+ (id) newForPGTSResultSet: (PGTSResultSet *) res withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{        
    //Role and privileges are separated by an equals sign
    id retval = nil;
	size_t length = strlen (value) + 1;
    char* grantingRole = alloca (length);
	strlcpy (grantingRole, value, length);
    char* role = strsep (&grantingRole, "=");
    char* privileges = strsep (&grantingRole, "/");
    
    //Zero-length but not NULL
    BXAssertValueReturn (NULL != privileges && NULL != role && NULL != grantingRole, nil, @"Unable to parse privileges (%s).", value);
    
    //Role is zero-length if the privileges are for PUBLIC
    retval = [[[PGTSACLItem alloc] init] autorelease];
    if (0 != strlen (role))
    {
        PGTSDatabaseDescription* database = [[res connection] databaseDescription];
        
        //Remove "group " from beginning
        if (role == strstr (role, "group "))
            role = &role [6]; //6 == strlen ("group ");
        if (grantingRole == strstr (role, "group "))
            grantingRole = &grantingRole [6];
        
        [retval setRole: [database roleNamed: [NSString stringWithUTF8String: role]]];
        [retval setGrantingRole: [database roleNamed: [NSString stringWithUTF8String: grantingRole]]];
    }
    
    //Parse the privileges
    enum PGTSACLItemPrivilege userPrivileges = kPGTSPrivilegeNone;
    enum PGTSACLItemPrivilege grantOption = kPGTSPrivilegeNone;
    for (unsigned int i = 0, length = strlen (privileges); i < length; i++)
    {
        switch (privileges [i])
        {
            case 'r': //SELECT
                userPrivileges |= kPGTSPrivilegeSelect;
                grantOption = kPGTSPrivilegeSelectGrant;
                break;
            case 'w': //UPDATE
                userPrivileges |= kPGTSPrivilegeUpdate;
                grantOption = kPGTSPrivilegeUpdateGrant;
                break;
            case 'a': //INSERT
                userPrivileges |= kPGTSPrivilegeInsert;
                grantOption = kPGTSPrivilegeInsertGrant;
                break;
            case 'd': //DELETE
                userPrivileges |= kPGTSPrivilegeDelete;
                grantOption = kPGTSPrivilegeDeleteGrant;
                break;
            case 'x': //REFERENCES
                userPrivileges |= kPGTSPrivilegeReferences;
                grantOption = kPGTSPrivilegeReferencesGrant;
                break;
            case 't': //TRIGGER
                userPrivileges |= kPGTSPrivilegeTrigger;
                grantOption = kPGTSPrivilegeTriggerGrant;
                break;
            case 'X': //EXECUTE
                userPrivileges |= kPGTSPrivilegeExecute;
                grantOption = kPGTSPrivilegeExecuteGrant;
                break;
            case 'U': //USAGE
                userPrivileges |= kPGTSPrivilegeUsage;
                grantOption = kPGTSPrivilegeUsageGrant;
                break;
            case 'C': //CREATE
                userPrivileges |= kPGTSPrivilegeCreate;
                grantOption = kPGTSPrivilegeCreateGrant;
                break;
            case 'c': //CONNECT
                userPrivileges |= kPGTSPrivilegeConnect;
                grantOption = kPGTSPrivilegeConnectGrant;
                break;
            case 'T': //TEMPORARY
                userPrivileges |= kPGTSPrivilegeTemporary;
                grantOption = kPGTSPrivilegeTemporaryGrant;
                break;
            case '*': //Grant option
                userPrivileges |= grantOption;
                grantOption = kPGTSPrivilegeNone;
                break;
            default:
                break;
        }
    }
    [retval setPrivileges: userPrivileges];
    
    return retval;    
}
@end
