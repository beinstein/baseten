//
// PGTSDatabaseDescription.m
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

#import "PGTSDatabaseDescription.h"
#import "PGTSTypeDescription.h"
#import "PGTSTableDescription.h"
#import "PGTSResultSet.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"
#import "PGTSFunctions.h"
#import "PGTSRoleDescription.h"
//FIXME: enable logging.
//#import <Log4Cocoa/Log4Cocoa.h>
#define log4AssertValueReturn(...)
    

@implementation PGTSDatabaseDescriptionProxy
- (void) dealloc
{
	[mTypes release];
	[mTables release];
	[mSchemas release];
	[super dealloc];
}

- (PGTSTableDescription *) tableWithOid: (Oid) anOid
{
	//Get the cached proxy or create one.
	id retval = [mTables objectForKey: PGTSOidAsObject (anOid)];
	if (! retval)
	{
		[[[self invocationRecorder] record] tableWithOid: anOid];
		retval = [[self performSynchronizedAndReturnObject] proxy];
		[self updateTableCache: retval];
	}
	return PGTSNilReturn (retval);
}

- (PGTSTableDescription *) table: (NSString *) tableName inSchema: (NSString *) schemaName
{
	//Get the cached proxy or create one.
	id retval = [[mSchemas objectForKey: schemaName] objectForKey: tableName];
	if (! retval)
	{
		[[[self invocationRecorder] record] table: tableName inSchema: schemaName];
		retval = [[self performSynchronizedAndReturnObject] proxy];
		[self updateTableCache: retval];
	}
	return PGTSNilReturn (retval);
}

- (PGTSTypeDescription *) typeWithOid: (Oid) anOid
{
	if (! mTypes)
		mTypes = [[NSMutableDictionary alloc] init];
	
	//Get the cached proxy or create one.
	id key = PGTSOidAsObject (anOid);
	id retval = [mTypes objectForKey: key];
	if (! retval)
	{
		[[[self invocationRecorder] record] typeWithOid: anOid];
		retval = [[self performSynchronizedAndReturnObject] proxy] ?: [NSNull null];
		[mTypes setObject: retval forKey: key];
	}
	return PGTSNilReturn (retval);
}

- (PGTSRoleDescription *) roleNamed: (NSString *) name
{
	//FIXME: implement this.
	[[NSException exceptionWithName: NSInternalInconsistencyException reason: @"-[PGTSDatabaseDescriptionProxy roleNamed:] called." userInfo: nil] raise];
	return nil;
}

- (PGTSRoleDescription *) roleNamed: (NSString *) name oid: (Oid) oid
{
	//FIXME: implement this.
	[[NSException exceptionWithName: NSInternalInconsistencyException reason: @"-[PGTSDatabaseDescriptionProxy roleNamed:oid:] called." userInfo: nil] raise];
	return nil;
}

- (void) updateTableCache: (id) table
{
    if (nil != table)
    {
		if (! mTables)
			mTables = [[NSMutableDictionary alloc] init];
		
		if (! mSchemas)
			mSchemas = [[NSMutableDictionary alloc] init];
		
        NSString* schemaName = [table schemaName];
        NSMutableDictionary* schema = [mSchemas objectForKey: schemaName];
        if (! schema)
        {
            schema = [NSMutableDictionary dictionary];
            [mSchemas setObject: schema forKey: schemaName];
        }
		
        [schema setObject: table forKey: [table name]];
    }
}
@end


/** 
 * Database.
 */
@implementation PGTSDatabaseDescription

+ (id) databaseForConnection: (PGTSConnection *) connection
{
	id description = [[[PGTSDatabaseDescription alloc] init] autorelease];
	id retval = [[[PGTSDatabaseDescriptionProxy alloc] initWithConnection: connection description: description] autorelease];
	return retval;
}

- (id) addDescriptionFor: (Oid) oidValue class: (Class) c toContainer: (NSMutableDictionary *) aDict
{
    id retval = nil;
    if (InvalidOid != oidValue)
    {
        id oidObject = PGTSOidAsObject (oidValue);
        retval = [aDict objectForKey: oidObject];
        if (! retval)
        {
            retval = [[c alloc] init];
            [retval setOid: oidValue];
            [aDict setObject: retval forKey: oidObject];
            [retval release];
        }
    }
    return retval;
}

- (BOOL) schemaExists: (NSString *) schemaName
{
	id schema = [mSchemas objectForKey: schemaName];
    if (! schema)
    {
        NSString* query = @"SELECT oid FROM pg_namespace WHERE nspname = $1";
        PGTSResultSet* res = [mConnection executeQuery: query parameters: schemaName];
        log4AssertValueReturn ([res querySucceeded], NO, @"Query failed (%@).", [res errorMessage]);
        if (0 == [res count])
			schema = [NSNull null];
        else
            schema = [NSMutableDictionary dictionary];
		[mSchemas setObject: schema forKey: schemaName];
    }
    return ([NSNull null] != schema);
}

- (id) init
{
    if ((self = [super init]))
    {
        mTables = [[NSMutableDictionary alloc] init];
        mTypes  = [[NSMutableDictionary alloc] init];
        mSchemas = [[NSMutableDictionary alloc] init];
        mRoles = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [mTables release];
    [mTypes release];
    [mSchemas release];
    [mRoles release];
    [super dealloc];
}

- (PGTSTableDescription *) tableWithOid: (Oid) anOid
{
    return [self addDescriptionFor: anOid class: [PGTSTableDescription class] toContainer: mTables];
}

- (PGTSTypeDescription *) typeWithOid: (Oid) anOid
{
    return [self addDescriptionFor: anOid class: [PGTSTypeDescription class] toContainer: mTypes];
}

- (PGTSTableDescription *) table: (NSString *) tableName inSchema: (NSString *) schemaName
{
    if (nil == schemaName || 0 == [schemaName length])
        schemaName = @"public";
    PGTSTableDescription* rval = [[mSchemas objectForKey: schemaName] objectForKey: tableName];
    if (nil == rval)
    {
        NSString* queryString = 
        @"SELECT c.oid AS oid, c.relnamespace AS schemaoid, c.relacl, c.relowner, c.relkind, r.rolname "
        " FROM pg_class c, pg_namespace n, pg_roles r "
        " WHERE c.relowner = r.oid AND c.relnamespace = n.oid AND c.relname = $1 AND n.nspname = $2";
        PGTSResultSet* res = [mConnection executeQuery: queryString parameters: tableName, schemaName];
        if (0 < [res count])
        {
            [res advanceRow];
            rval = [self tableWithOid: [[res valueForKey: @"oid"] PGTSOidValue]];
            [rval setName: tableName];
            [rval setKind: [[res valueForKey: @"relkind"] characterAtIndex: 0]];
            [rval setSchemaOid: [[res valueForKey: @"schemaoid"] PGTSOidValue]];

            PGTSRoleDescription* role = [[mConnection databaseDescription] roleNamed: [res valueForKey: @"rolname"]
                                                                                oid: [[res valueForKey: @"relowner"] PGTSOidValue]];
            [rval setOwner: role];
            
            [rval setSchemaName: schemaName];
            TSEnumerate (currentACLItem, e, [[res valueForKey: @"relacl"] objectEnumerator])
                [rval addACLItem: currentACLItem];
            [self updateTableCache: rval];
        }
    }
    return rval;
}

- (void) updateTableCache: (id) table
{
    if (nil != table)
    {
        NSString* schemaName = [table schemaName];
        NSMutableDictionary* schema = [mSchemas objectForKey: schemaName];
        if (! schema)
        {
            schema = [NSMutableDictionary dictionary];
            [mSchemas setObject: schema forKey: schemaName];
        }
        [schema setObject: table forKey: [table name]];
    }
}

- (PGTSRoleDescription *) roleNamed: (NSString *) aName
{
    return [self roleNamed: aName oid: InvalidOid];
}

- (PGTSRoleDescription *) roleNamed: (NSString *) originalName oid: (Oid) oid
{
    id aName = originalName;
    if (nil == aName)
        aName = [NSNull null];
    
    id rval = [mRoles objectForKey: aName];
    if (nil == rval)
    {
        if (nil != originalName && InvalidOid == oid)
        {
            NSString* query = @"SELECT oid FROM pg_roles WHERE rolname = $1";
            PGTSResultSet* res = [mConnection executeQuery: query parameters: aName];
            if (0 < [res count])
            {
                [res advanceRow];
                oid = [[res valueForKey: @"oid"] PGTSOidValue];
            }
        }
        
        rval = [[[PGTSRoleDescription alloc] init] autorelease];
        [rval setOid: oid];
        [rval setName: aName];
        [mRoles setObject: rval forKey: aName];        
    }
    return rval;
}

- (Class) proxyClass
{
	return [PGTSDatabaseDescriptionProxy class];
}
@end
