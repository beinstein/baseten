//
// PGTSDatabaseDescription.mm
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


#import "PGTSDatabaseDescription.h"
#import "PGTSOids.h"
#import "PGTSScannedMemoryAllocator.h"
#import "PGTSAbstractDescription.h"
#import "PGTSAbstractObjectDescription.h"
#import "PGTSTableDescription.h"
#import "PGTSSchemaDescription.h"
#import "PGTSTypeDescription.h"
#import "PGTSRoleDescription.h"
#import "PGTSCollections.h"
#import "BXLogger.h"
#import "BXArraySize.h"


using namespace PGTS;


static NSArray*
FindUsingOidVector (const Oid* oidVector, OidMap* map)
{
	NSMutableArray* retval = [NSMutableArray array];
	for (unsigned int i = 0; InvalidOid != oidVector [i]; i++)
	{
		id type = FindObject (map, oidVector [i]);
		if (type)
			[retval addObject: type];
	}
	return retval;
}


/** 
 * \internal
 * \brief Database.
 */
@implementation PGTSDatabaseDescription
+ (BOOL) accessInstanceVariablesDirectly
{
    return NO;
}

/**
 * \internal
 * \brief Retain on copy.
 */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}

- (void) dealloc
{
	OidMap* maps [] = {mSchemasByOid, mTablesByOid, mTypesByOid, mRolesByOid};
	for (int i = 0, count = BXArraySize (maps); i < count; i++)
	{
		OidMap::const_iterator iterator = maps [i]->begin ();
		while (maps [i]->end () != iterator)
		{
			[iterator->second autorelease];
			iterator++;
		}
		delete maps [i];
	}
	
	[mSchemasByName release];
	[mRolesByName release];
	
	[mSchemaLock release];
	[mRoleLock release];
		
	[super dealloc];
}


- (void) finalize
{
	delete mSchemasByOid;
	delete mTablesByOid;
	delete mTypesByOid;
	delete mRolesByOid;
	[super finalize];
}


- (id) init
{
	if ((self = [super init]))
	{
		mSchemasByOid = new OidMap ();
		mTablesByOid = new OidMap ();
		mTypesByOid = new OidMap ();
		mRolesByOid = new OidMap ();
		mSchemaLock = [[NSLock alloc] init];
		mRoleLock = [[NSLock alloc] init];
	}
	return self;
}


- (void) addTable: (PGTSTableDescription *) table
{
	ExpectV (table);
	InsertConditionally (mTablesByOid, table);
	
	PGTSSchemaDescription* schema = [table schema];
	ExpectV (schema);
	[schema addTable: table];
}


- (void) addSchema: (PGTSSchemaDescription *) schema
{
	ExpectV (schema);
	[mSchemaLock lock];
	if (mSchemasByName)
	{
		[mSchemasByName release];
		mSchemasByName = nil;
	}
	[mSchemaLock unlock];
	InsertConditionally (mSchemasByOid, schema);
}


- (void) addType: (PGTSTypeDescription *) type
{
	ExpectV (type);
	InsertConditionally (mTypesByOid, type);
}


- (void) addRole: (PGTSRoleDescription *) role
{
	ExpectV (role);
	[mRoleLock lock];
	if (mRolesByName)
	{
		[mRolesByName release];
		mRolesByName = nil;
	}	
	[mRoleLock unlock];
	InsertConditionally (mRolesByOid, role);
}


- (PGTSSchemaDescription *) schemaWithOid: (Oid) oid
{
	return FindObject (mSchemasByOid, oid);
}


- (PGTSTypeDescription *) typeWithOid: (Oid) oid
{
	return FindObject (mTypesByOid, oid);
}


- (id) tableWithOid: (Oid) oid
{
	return FindObject (mTablesByOid, oid);
}


- (PGTSRoleDescription *) roleWithOid: (Oid) oid
{
	return FindObject (mRolesByOid, oid);
}


- (PGTSSchemaDescription *) schemaNamed: (NSString *) name
{
	Expect (name);

	[mSchemaLock lock];
	if (! mSchemasByName)
		mSchemasByName = [[CreateCFMutableDictionaryWithNames (mSchemasByOid) autorelease] copy];
	[mSchemaLock unlock];

	//We assume that external locking is used if schemas are added while this method may be called.
	return [mSchemasByName objectForKey: name];
}


- (NSDictionary *) schemasByName
{
	id retval = nil;
	[mSchemaLock lock];
	if (! mSchemasByName)
		mSchemasByName = [[CreateCFMutableDictionaryWithNames (mSchemasByOid) autorelease] copy];
	retval = [[mSchemasByName retain] autorelease];
	[mSchemaLock unlock];
	return retval;
}


- (PGTSRoleDescription *) roleNamed: (NSString *) name
{
	Expect (name);
	
	[mRoleLock lock];
	if (! mRolesByName)
		mRolesByName = [[CreateCFMutableDictionaryWithNames (mRolesByOid) autorelease] copy];
	[mRoleLock unlock];
	
	//We assume that external locking is used if schemas are added while this method may be called.
	return [mRolesByName objectForKey: name];
}


- (NSArray *) typesWithOids: (const Oid *) oidVector
{
	Expect (oidVector);
	return FindUsingOidVector (oidVector, mTypesByOid);
}


- (NSArray *) tablesWithOids: (const Oid *) oidVector
{
	Expect (oidVector);
	return FindUsingOidVector (oidVector, mTablesByOid);
}


- (id) table: (NSString *) tableName inSchema: (NSString *) schemaName
{
	Expect (tableName);
	Expect (schemaName);
		
	return [[self schemaNamed: schemaName] tableNamed: tableName];
}
@end
