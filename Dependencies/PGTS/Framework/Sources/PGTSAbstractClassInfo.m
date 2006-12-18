//
// PGTSAbstractClassInfo.m
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

#import "PGTSAbstractClassInfo.h"
#import "PGTSResultSet.h"
#import "PGTSFunctions.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"
#import "PGTSConstants.h"
#import "PGTSRoleDescription.h"
#import "PGTSACLItem.h"
#import "PGTSDatabaseInfo.h"
#import <TSDataTypes/TSDataTypes.h>

/** 
 * Abstract base class for database class objects
 */
@implementation PGTSAbstractClassInfo

- (id) initWithConnection: (PGTSConnection *) aConn
{
    if ((self = [super initWithConnection: aConn]))
    {
        schemaOid = InvalidOid;
        aclItems = [[TSIndexDictionary alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [aclItems release];
    [schemaName release];
    [super dealloc];
}

- (Oid) schemaOid
{
    return schemaOid;
}

- (void) setSchemaOid: (Oid) anOid
{
    schemaOid = anOid;
}

- (void) setSchemaName: (NSString *) aString
{
    if (schemaName != aString)
    {
        [schemaName release];
        schemaName = [aString retain];
    }
}

- (void) addACLItem: (PGTSACLItem *) item
{
    [aclItems setObject: item atIndex: [[item role] oid]];
}

- (PGTSRoleDescription *) owner
{
    return owner; 
}

- (void) setOwner: (PGTSRoleDescription *) anOwner
{
    if (owner != anOwner) {
        [owner release];
        owner = [anOwner retain];
    }
}

@end


@implementation PGTSAbstractClassInfo (Queries)

- (Oid) schemaOid
{
    //Perform the query and check again
    if (InvalidOid == schemaOid)
        [self name];
    return schemaOid;
}

- (NSString *) schemaName
{
    if (nil == schemaName)
        [self name];
    return schemaName;
}

- (NSString *) name
{
    if (nil == name)
    {
        NSString* query = 
        @"SELECT c.relname, c.relacl, c.relowner, n.oid, n.nspname, r.rolname "
        " FROM pg_class c, pg_namespace n, pg_roles r "
        " WHERE c.relnamespace = n.oid AND r.oid = c.relowner AND c.oid = $1";
        PGTSResultSet* res = [connection executeQuery: query parameters: PGTSOidAsObject (oid)];
        if (0 < [res numberOfRowsAffected])
        {
            [res advanceRow];
            [self setName:  [res valueForKey: @"relname"]];
            [self setSchemaName: [res valueForKey: @"nspname"]];
            [self setSchemaOid: [[res valueForKey: @"oid"] PGTSOidValue]];
            
            PGTSRoleDescription* role = [[connection databaseInfo] roleNamed: [res valueForKey: @"rolname"]
                                                                         oid: [[res valueForKey: @"relowner"] PGTSOidValue]];
            [self setOwner: role];
            
            TSEnumerate (currentACLItem, e, [[res valueForKey: @"relacl"] objectEnumerator])
                [self addACLItem: currentACLItem];
        }
    }
    return name;
}

- (NSString *) qualifiedName
{
    if (nil == name)
        [self name];
    return [NSString stringWithFormat: @"\"%@\".\"%@\"", schemaName, name];
}

- (BOOL) role: (PGTSRoleDescription *) aRole 
 hasPrivilege: (enum PGTSACLItemPrivilege) aPrivilege
{
    if (nil == name)
        [self name];
    
    //First try the user's privileges, then PUBLIC's and last different groups'.
    //The owner has all the privileges.
    BOOL rval = (owner == aRole || [owner isEqual: aRole]);
    if (NO == rval)
        (0 != (aPrivilege & [[aclItems objectAtIndex: [aRole oid]] privileges]));
    if (NO == rval)
        rval = (0 != (aPrivilege & [[aclItems objectAtIndex: kPGTSPUBLICOid] privileges]));
    if (NO == rval)
    {
        TSEnumerate (currentItem, e, [aclItems objectEnumerator])
        {
            if (aPrivilege & [currentItem privileges] && [[currentItem role] hasMember: aRole])
            {
                rval = YES;
                break;
            }
        }
    }
    return rval;
}

- (NSArray *) ACLItems
{
    if (nil == name)
        [self name];
    return [aclItems allObjects];
}

@end