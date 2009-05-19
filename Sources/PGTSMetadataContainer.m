//
// PGTSMetadataContainer.m
// BaseTen
//
// Copyright (C) 2009 Marko Karppinen & Co. LLC.
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


#import "PGTSMetadataContainer.h"
#import "PGTSMetadataStorage.h"
#import "BXLogger.h"
#import "PGTSConnection.h"
#import "PGTSResultSet.h"
#import "PGTSDatabaseDescription.h"
#import "PGTSSchemaDescription.h"
#import "PGTSTypeDescription.h"
#import "PGTSTableDescription.h"
#import "PGTSColumnDescription.h"
#import "PGTSIndexDescription.h"
#import "PGTSRoleDescription.h"
#import "PGTSOids.h"
#import "BXEnumerate.h"



@implementation PGTSMetadataContainer
- (id) initWithStorage: (PGTSMetadataStorage *) storage key: (NSURL *) key
{
	if ((self = [super init]))
	{
		mStorage = [storage retain];
		mStorageKey = [key retain];
	}
	return self;
}

- (id) init
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (void) dealloc
{
	[mStorage containerWillDeallocate: mStorageKey];
	[mStorage release];
	[mStorageKey release];
	[mDatabase release];
	[super dealloc];
}

- (Class) databaseDescriptionClass
{
	return [PGTSDatabaseDescription class];
}

- (Class) tableDescriptionClass
{
	return [PGTSTableDescription class];
}

- (id) databaseDescription;
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (void) prepareForConnection: (PGTSConnection *) connection;
{
	[self doesNotRecognizeSelector: _cmd];
}

- (void) reloadUsingConnection: (PGTSConnection *) connection
{
	[self doesNotRecognizeSelector: _cmd];
}
@end


@implementation PGTSEFMetadataContainer
//FIXME: come up with a better way to handle query problems than ExpectV.
- (void) fetchTypes: (PGTSConnection *) connection
{
	ExpectV (connection);
	NSString* query = 
	@"SELECT t.oid, typname, typnamespace, typelem, typdelim, typtype, typlen "
	@" FROM pg_type t ";
	PGTSResultSet* res = [connection executeQuery: query];
	ExpectV ([res querySucceeded]);
	
	{
		[res setDeterminesFieldClassesAutomatically: NO];
		//Oid is parsed manually.
		[res setClass: [NSString class] forKey: @"typname"];
		[res setClass: [NSNumber class] forKey: @"typnamespace"];
		[res setClass: [NSNumber class] forKey: @"typelem"];
		[res setClass: [NSString class] forKey: @"typdelim"];
		[res setClass: [NSString class] forKey: @"typtype"];
		[res setClass: [NSNumber class] forKey: @"typlen"];
		
		while ([res advanceRow])
		{
			PGTSTypeDescription* type = [[[PGTSTypeDescription alloc] init] autorelease];
			
			//Oid needs to be parsed manually to prevent infinite recursion.
			//The type description of Oid might not be cached yet.
			char* oidString = PQgetvalue ([res PGresult], [res currentRow], 0);
			long oid = strtol (oidString, NULL, 10);
			[type setOid: oid];
			
			[type setName: [res valueForKey: @"typname"]];
			[type setElementOid: [[res valueForKey: @"typelem"] PGTSOidValue]];
			unichar delimiter = [[res valueForKey: @"typdelim"] characterAtIndex: 0];
			ExpectV (delimiter <= UCHAR_MAX);
			[type setDelimiter: delimiter];
			unichar kind = [[res valueForKey: @"typtype"] characterAtIndex: 0];
			ExpectV (kind <= UCHAR_MAX);
			[type setKind: kind];
			NSInteger length = [[res valueForKey: @"typlen"] integerValue];
			[type setLength: length];
			
			[type setSchema: [mDatabase schemaWithOid: [[res valueForKey: @"typnamespace"] PGTSOidValue]]];
			
			[mDatabase addType: type];
		}		
	}
}


- (void) fetchSchemas: (PGTSConnection *) connection
{
	ExpectV (connection);
	NSString* query = 
	@"SELECT oid, nspname "
	@" FROM pg_namespace "
	@" WHERE nspname NOT IN ('information_schema', 'baseten') AND "
	@"  nspname NOT LIKE 'pg_%'";
	PGTSResultSet* res = [connection executeQuery: query];
	ExpectV ([res querySucceeded]);
	
	{
		while ([res advanceRow])
		{
			PGTSSchemaDescription* schema = [[[PGTSSchemaDescription alloc] init] autorelease];
			NSNumber* oid = [res valueForKey: @"oid"];
			[schema setOid: [oid PGTSOidValue]];
			[schema setName: [res valueForKey: @"nspname"]];
			
			[mDatabase addSchema: schema];
		}
	}
}


- (void) fetchRoles: (PGTSConnection *) connection
{
	ExpectV (connection);

	//We could easily fetch login, connection limit etc. privileges here.
	NSString* query =
	@"SELECT oid, rolname "
	@" FROM pg_roles ";
	PGTSResultSet* res = [connection executeQuery: query];
	ExpectV ([res querySucceeded]);
	
	{
		while ([res advanceRow]) 
		{
			PGTSRoleDescription* role = [[[PGTSRoleDescription alloc] init] autorelease];
			NSNumber* oid = [res valueForKey: @"oid"];
			[role setOid: [oid PGTSOidValue]];
			[role setName: [res valueForKey: @"rolname"]];
			
			[mDatabase addRole: role];
		}
	}
	
	query = 
	@"SELECT roleid, member "
	@" FROM pg_auth_members ";
	res = [connection executeQuery: query];
	
	{
		while ([res advanceRow])
		{
			Oid roleOid = [[res valueForKey: @"roleid"] PGTSOidValue];
			Oid memberOid = [[res valueForKey: @"member"] PGTSOidValue];
			PGTSRoleDescription* role = [mDatabase roleWithOid: roleOid];
			PGTSRoleDescription* member = [mDatabase roleWithOid: memberOid];
			[role addMember: member];
		}
	}
}


- (void) fetchRelations: (PGTSConnection *) connection
{
	ExpectV (connection);
	NSString* query = 
	@"SELECT c.oid, c.relnamespace, c.relname, c.relkind, c.relacl, c.relowner "
	@" FROM pg_class c "
	@" INNER JOIN pg_namespace n ON c.relnamespace = n.oid "
	@" WHERE c.relkind IN ('r', 'v') AND "
	@"  n.nspname NOT IN ('information_schema', 'baseten') AND "
	@"  n.nspname NOT LIKE 'pg_%'";
	PGTSResultSet* res = [connection executeQuery: query];
	ExpectV ([res querySucceeded]);
	
	{
		while ([res advanceRow]) 
		{
			PGTSTableDescription* table = [[[[self tableDescriptionClass] alloc] init] autorelease];
			[table setOid: [[res valueForKey: @"oid"] PGTSOidValue]];
			[table setName: [res valueForKey: @"relname"]];
			unichar kind = [[res valueForKey: @"relkind"] characterAtIndex: 0];
			ExpectV (kind <= UCHAR_MAX);
			[table setKind: kind];
			[table setACL: [res valueForKey: @"relacl"]];
			
			[table setOwner: [mDatabase roleWithOid: [[res valueForKey: @"relowner"] PGTSOidValue]]];
			[table setSchema: [mDatabase schemaWithOid: [[res valueForKey: @"relnamespace"] PGTSOidValue]]];
			
			[mDatabase addTable: table];
		}
	}
}


- (void) fetchColumns: (PGTSConnection *) connection
{
	ExpectV (connection);
	
	{
		NSString* query = 
		@"SELECT a.attrelid, a.attname, a.attnum, a.atttypid, a.attnotnull, pg_get_expr (d.adbin, d.adrelid, false) AS default "
		@" FROM pg_attribute a "
		@" INNER JOIN pg_class c ON a.attrelid = c.oid "
		@" INNER JOIN pg_namespace n ON n.oid = c.relnamespace "
		@" LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid and a.attnum = d.adnum "
		@" WHERE a.attisdropped = false AND "
		@"  c.relkind IN ('r', 'v') AND "
		@"  n.nspname NOT IN ('information_schema', 'baseten') AND "
		@"  n.nspname NOT LIKE 'pg_%'";
		
		PGTSResultSet* res = [connection executeQuery: query];
		ExpectV ([res querySucceeded]);
		
		while ([res advanceRow])
		{
			Oid typeOid = [[res valueForKey: @"atttypid"] PGTSOidValue];
			Oid relid = [[res valueForKey: @"attrelid"] PGTSOidValue];			
			PGTSTypeDescription* type = [mDatabase typeWithOid: typeOid];
			PGTSColumnDescription* column = nil;
			if ([@"xml" isEqualToString: [type name]])
				column = [[[PGTSXMLColumnDescription alloc] init] autorelease];
			else
				column = [[[PGTSColumnDescription alloc] init] autorelease];
			
			[column setType: type];
			[column setName: [res valueForKey: @"attname"]];
			[column setIndex: [[res valueForKey: @"attnum"] integerValue]];
			[column setNotNull: [[res valueForKey: @"attnotnull"] boolValue]];			
			[column setDefaultValue: [res valueForKey: @"default"]];
			
			[[mDatabase tableWithOid: relid] addColumn: column];
		}
	}
	
	{
		//Fetch some column-specific constraints.
		//We can't determine whether a column accepts only XML document from its type.
		//Instead, we have to look for a constraint like 'CHECK ((column) IS DOCUMENT)'
		//or 'CHECK ("Column" IS DOCUMENT)'. We do this by comparing the constraint 
		//definition to an expression, where a number of parentheses is allowed around 
		//its parts. We use the reconstructed constraint instead of what the user wrote.
		NSString* query =
		@"SELECT conrelid, conkey "
		@"FROM ( "
		@"  SELECT c.conrelid, c.conkey [1], a.attname, "
		@"    regexp_matches (pg_get_constraintdef (c.oid, false), "
		@"	    '^CHECK ?[(]+(?:\"([^\"]+)\")|([^( ][^ )]*)[ )]+IS DOCUMENT[ )]+$' "
		@"    ) AS matches "
		@"  FROM pg_constraint c "
		@"  INNER JOIN pg_attribute a ON (c.conrelid = a.attrelid AND c.conkey [1] = a.attnum) "
		@"  INNER JOIN pg_type t ON (t.oid = a.atttypid AND t.typname = 'xml') "
		@"	WHERE c.contype = 'c' AND 1 = array_upper (c.conkey, 1) "
		@") c "
		@"WHERE attname = ANY (matches)";
		PGTSResultSet* res = [connection executeQuery: query];
		ExpectV ([res querySucceeded])
		
		while ([res advanceRow])
		{
			Oid relid = [[res valueForKey: @"conrelid"] PGTSOidValue];
			NSInteger attnum = [[res valueForKey: @"conkey"] integerValue];
			[[[mDatabase tableWithOid: relid] columnAtIndex: attnum] setRequiresDocuments: YES];
		}
	}
}


- (void) fetchUniqueIndexes: (PGTSConnection *) connection
{
	ExpectV (connection);
	//indexrelid is oid of the index, indrelid of the table.
	NSString* query = 
	@"SELECT i.indexrelid, i.indrelid, c.relname, i.indisprimary, i.indkey::INTEGER[] "
	@" FROM pg_index i "
	@" INNER JOIN pg_class c ON i.indexrelid = c.oid "
	@" INNER JOIN pg_namespace n ON c.relnamespace = n.oid "
	@" WHERE i.indisunique = true AND "
	@"  n.nspname NOT IN ('information_schema', 'baseten') AND "
	@"  n.nspname NOT LIKE 'pg_%' "
	@" ORDER BY i.indrelid ASC, i.indisprimary DESC";
	PGTSResultSet* res = [connection executeQuery: query];
	ExpectV ([res querySucceeded]);

	while ([res advanceRow]) 
	{
		PGTSIndexDescription* index = [[[PGTSIndexDescription alloc] init] autorelease];
		PGTSTableDescription* table = [mDatabase tableWithOid: [[res valueForKey: @"indrelid"] PGTSOidValue]];
		
		[index setName: [res valueForKey: @"relname"]];
		[index setOid: [[res valueForKey: @"indexrelid"] PGTSOidValue]];
		[index setPrimaryKey: [[res valueForKey: @"indisprimary"] boolValue]];

		NSArray* indices = [res valueForKey: @"indkey"];
		NSMutableSet* columns = [NSMutableSet setWithCapacity: [indices count]];
		BXEnumerate (currentIndex, e, [indices objectEnumerator])
		{
			NSInteger i = [currentIndex integerValue];
			if (0 < i)
				[columns addObject: [table columnAtIndex: i]];
		}
		[index setColumns: columns];
		
		[table addIndex: index];
	}
}


- (id) databaseDescription
{
	id retval = nil;
	@synchronized (self)
	{
		retval = [[mDatabase retain] autorelease];
	}
	return retval;
}


- (void) loadUsing: (PGTSConnection *) connection
{
	[mDatabase release];
	mDatabase = [[[self databaseDescriptionClass] alloc] init];
	
	//Order is important.
	[self fetchTypes: connection];
	[self fetchSchemas: connection];
	[self fetchRoles: connection];
	[self fetchRelations: connection];
	[self fetchColumns: connection];
	[self fetchUniqueIndexes: connection];	
}


- (void) prepareForConnection: (PGTSConnection *) connection
{
	@synchronized (self)
	{
		if (! mDatabase)
			[self loadUsing: connection];
	}
}


- (void) reloadUsingConnection: (PGTSConnection *) connection
{
	@synchronized (self)
	{
		[self loadUsing: connection];
	}
}
@end
