//
// PGTSDatabaseDescription.h
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

#import <Foundation/Foundation.h>
#import <BaseTen/libpq-fe.h>
#import <BaseTen/PGTSAbstractDescription.h>
#import <BaseTen/PGTSOids.h>
#import <BaseTen/PGTSCollections.h>

@class PGTSSchemaDescription;
@class PGTSTableDescription;
@class PGTSTypeDescription;
@class PGTSRoleDescription;
@class PGTSResultSet;


@interface PGTSDatabaseDescription : NSObject <NSCopying>
{
	PGTS_OidMap* mSchemasByOid;
	PGTS_OidMap* mTablesByOid;
	PGTS_OidMap* mTypesByOid;
	PGTS_OidMap* mRolesByOid;	
	NSDictionary* mSchemasByName;
	NSDictionary* mRolesByName;
	NSLock* mSchemaLock;
	NSLock* mRoleLock;
}
- (PGTSSchemaDescription *) schemaWithOid: (Oid) anOid;
- (PGTSSchemaDescription *) schemaNamed: (NSString *) name;
- (NSDictionary *) schemasByName;

- (PGTSTypeDescription *) typeWithOid: (Oid) anOid;
- (NSArray *) typesWithOids: (const Oid *) oidVector;

- (id) tableWithOid: (Oid) anOid;
- (NSArray *) tablesWithOids: (const Oid *) oidVector;
- (id) table: (NSString *) tableName inSchema: (NSString *) schemaName;

- (PGTSRoleDescription *) roleWithOid: (Oid) anOid;
- (PGTSRoleDescription *) roleNamed: (NSString *) name;


//Thread un-safe methods.
- (void) addTable: (PGTSTableDescription *) table;
- (void) addSchema: (PGTSSchemaDescription *) schema;
- (void) addType: (PGTSTypeDescription *) type;
- (void) addRole: (PGTSRoleDescription *) role;
@end
