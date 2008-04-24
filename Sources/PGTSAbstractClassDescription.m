//
// PGTSAbstractClassDescription.m
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

#import "PGTSAbstractClassDescription.h"
#import "PGTSResultSet.h"
#import "PGTSFunctions.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"
#import "PGTSConstants.h"
#import "PGTSRoleDescription.h"
#import "PGTSACLItem.h"
#import "PGTSDatabaseDescription.h"

/** 
 * Abstract base class for database class objects
 */
@implementation PGTSAbstractClassDescription

- (id) init
{
    if ((self = [super init]))
    {
        mSchemaOid = InvalidOid;
        mACLItems = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [mACLItems release];
    [mSchemaName release];
	[mOwner release];
    [super dealloc];
}

- (Oid) schemaOid
{
    return mSchemaOid;
}

- (void) setSchemaOid: (Oid) anOid
{
    mSchemaOid = anOid;
}

- (void) setSchemaName: (NSString *) aString
{
    if (mSchemaName != aString)
    {
        [mSchemaName release];
        mSchemaName = [aString retain];
    }
}

- (void) addACLItem: (PGTSACLItem *) item
{
    [mACLItems setObject: item forKey: PGTSOidAsObject ([[item role] oid])];
}

- (PGTSRoleDescription *) owner
{
    return mOwner; 
}

- (void) setOwner: (PGTSRoleDescription *) anOwner
{
    if (mOwner != anOwner) 
	{
        [mOwner release];
        mOwner = [anOwner retain];
    }
}

- (void) setKind: (char) kind
{
    mRelkind = kind;
}

- (Class) proxyClass
{
	return [PGTSAbstractClassDescriptionProxy class];
}

@end


@implementation PGTSAbstractClassDescription (Queries)

- (Oid) schemaOid
{
	[self fetchFromDatabase];
    return mSchemaOid;
}

- (NSString *) schemaName
{
	[self fetchFromDatabase];
    return mSchemaName;
}

- (NSString *) name
{
	[self fetchFromDatabase];
    return mName;
}

- (NSString *) qualifiedName
{
	[self fetchFromDatabase];
    return [NSString stringWithFormat: @"\"%@\".\"%@\"", mSchemaName, mName];
}

- (BOOL) role: (PGTSRoleDescription *) aRole 
 hasPrivilege: (enum PGTSACLItemPrivilege) aPrivilege
{
	[self fetchFromDatabase];
    
    //First try the user's privileges, then PUBLIC's and last different groups'.
    //The owner has all the privileges.
    BOOL retval = (mOwner == aRole || [mOwner isEqual: aRole]);
    if (NO == retval)
        (0 != (aPrivilege & [[mACLItems objectAtIndex: [aRole oid]] privileges]));
    if (NO == retval)
        retval = (0 != (aPrivilege & [[mACLItems objectAtIndex: kPGTSPUBLICOid] privileges]));
    if (NO == retval)
    {
        TSEnumerate (currentItem, e, [mACLItems objectEnumerator])
        {
            if (aPrivilege & [currentItem privileges] && [[currentItem role] hasMember: aRole])
            {
                retval = YES;
                break;
            }
        }
    }
    return retval;
}

- (NSArray *) ACLItems
{
	[self fetchFromDatabase];
    return [mACLItems allObjects];
}

- (char) kind
{
	[self fetchFromDatabase];
    return mRelkind;
}

- (void) fetchFromDatabase
{
	if (! mName)
    {
        NSString* query = 
        @"SELECT c.relname, c.relacl, c.relowner, c.relkind, n.oid, n.nspname, r.rolname "
        " FROM pg_class c, pg_namespace n, pg_roles r "
        " WHERE c.relnamespace = n.oid AND r.oid = c.relowner AND c.oid = $1";
        PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject (mOid)];
        if (0 < [res count])
        {
            [res advanceRow];
            mRelkind = [[res valueForKey: @"relkind"] characterAtIndex: 0];
            [self setName:  [res valueForKey: @"relname"]];
            [self setSchemaName: [res valueForKey: @"nspname"]];
            [self setSchemaOid: [[res valueForKey: @"oid"] PGTSOidValue]];
            
            PGTSRoleDescription* role = [[mConnection databaseDescription] roleNamed: [res valueForKey: @"rolname"]
																				 oid: [[res valueForKey: @"relowner"] PGTSOidValue]];
            [self setOwner: role];
            
            TSEnumerate (currentACLItem, e, [[res valueForKey: @"relacl"] objectEnumerator])
				[self addACLItem: currentACLItem];
        }
    }
}	

@end
