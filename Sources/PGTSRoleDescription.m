//
// PGTSRoleDescription.m
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

#import <BaseTen/postgresql/libpq-fe.h>
#import "PGTSRoleDescription.h"
#import "PGTSFunctions.h"
#import "PGTSResultSet.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"
#import "PGTSDatabaseDescription.h"
#import "BXEnumerate.h"


//FIXME: implement this.
@implementation PGTSRoleDescriptionProxy
@end


@implementation PGTSRoleDescription

- (void) dealloc
{
    [mRoles release];
    [super dealloc];
}

/** 
 * \brief Check if given role is member of self.
 * \param aRole The role to be tested. May be a proxy.
 */
- (BOOL) hasMember: (PGTSRoleDescription *) aRole
{
    BOOL retval = NO;
    
    if (nil == mRoles)
    {
        mRoles = [[NSMutableDictionary alloc] init];
        NSString* query = @"SELECT r.oid, r.rolname FROM pg_roles r INNER JOIN pg_authid a WHERE r.oid = a.member AND a.roleid = $1";
        PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject ([self oid])];
        while ([res advanceRow])
        {
            id memberOid = [res valueForKey: @"oid"];
            PGTSRoleDescription* role = [[mConnection databaseDescription] roleNamed: [res valueForKey: @"rolname"] 
																				 oid: [memberOid PGTSOidValue]];
            [mRoles setObject: role forKey: memberOid];
        }
    }
    
    if (nil != [mRoles objectAtIndex: [aRole oid]])
        retval = YES;
    else
    {
        BXEnumerate (currentRole, e, [mRoles objectEnumerator])
        {
            retval = [currentRole hasMember: aRole];
            if (YES == retval)
                break;
        }
    }
    return retval;
}

- (Class) proxyClass
{
	return [PGTSRoleDescriptionProxy class];
}
@end
