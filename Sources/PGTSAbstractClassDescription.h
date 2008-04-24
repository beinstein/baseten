//
// PGTSAbstractClassDescription.h
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

#import <Foundation/Foundation.h>
#import <PGTS/PGTSAbstractObjectDescription.h>
#import <PGTS/postgresql/libpq-fe.h> 

@class PGTSRoleDescription;
@class PGTSACLItem;


@interface PGTSAbstractClassDescriptionProxy : PGTSAbstractObjectDescriptionProxy
{
}
@end


@interface PGTSAbstractClassDescription : PGTSAbstractObjectDescription
{
    Oid mSchemaOid;
    NSString* mSchemaName;
    id mACLItems;
    PGTSRoleDescription* mOwner;
    char mRelkind;
}
- (void) setSchemaOid: (Oid) anOid;
- (void) setSchemaName: (NSString *) anString;
- (void) addACLItem: (PGTSACLItem *) item;
- (PGTSRoleDescription *) owner;
- (void) setOwner: (PGTSRoleDescription *) anOwner;
- (void) setKind: (char) kind;
@end


@interface PGTSAbstractClassDescription (Queries)
- (NSString *) name;
- (Oid) schemaOid;
- (NSString *) schemaName;
- (NSString *) qualifiedName;
- (BOOL) role: (PGTSRoleDescription *) aRole 
 hasPrivilege: (enum PGTSACLItemPrivilege) aPrivilege;
- (NSArray *) ACLItems;
- (char) kind;

- (void) fetchFromDatabase;
@end
