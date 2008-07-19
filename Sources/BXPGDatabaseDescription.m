//
// BXPGDatabaseDescription.m
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

#import "BXPGDatabaseDescription.h"
#import "BXLogger.h"
#import "PGTSConnection.h"
#import "PGTSResultSet.h"
#import "BXPGTableDescription.h"


@implementation BXPGDatabaseDescription
- (BOOL) hasBaseTenSchema
{
	return mHasBaseTenSchema;
}

- (NSNumber *) schemaVersion
{
	return mSchemaVersion;
}

- (NSNumber *) schemaCompatibilityVersion
{
	return mSchemaCompatibilityVersion;
}

- (BOOL) checkBaseTenSchema: (NSError **) outError
{
	ExpectR (outError, NO);
	ExpectR (mConnection, NO);
	BOOL retval = NO;
	
	NSString* query = @"SELECT EXISTS (SELECT n.oid FROM pg_namespace n WHERE nspname = 'baseten') AS exists";
	PGTSResultSet* res = [mConnection executeQuery: query];
	if ([res querySucceeded])
	{
		retval = YES;
		[res advanceRow];
		mHasBaseTenSchema = [[res valueForKey: @"exists"] boolValue];
	}
	else
	{
		*outError = [res error];
	}
	return retval;
}

- (BOOL) checkSchemaVersions: (NSError **) outError
{
	ExpectR (outError, NO);
	ExpectR (mConnection, NO);
	BOOL retval = NO;

	if (! mHasBaseTenSchema)
		retval = YES;
	else
	{
		NSString* query = 
		@"SELECT baseten.version () AS version "
		@" UNION ALL "
		@" SELECT baseten.compatibilityversion () AS version";
		PGTSResultSet* res = [mConnection executeQuery: query];
		if ([res querySucceeded])
		{
			retval = YES;
			[mSchemaVersion release];
			[mSchemaCompatibilityVersion release];
			
			[res advanceRow];
			mSchemaVersion = [[res valueForKey: @"version"] retain];
			[res advanceRow];
			mSchemaCompatibilityVersion = [[res valueForKey: @"version"] retain];
		}
		else
		{
			*outError = [res error];
		}
	}
	return retval;
}

- (Class) tableDescriptionClass
{
	return [BXPGTableDescription class];
}

- (NSString *) tableDescriptionByNameQuery
{
	NSString* queryString = nil;
	if ([self hasBaseTenSchema])
	{
		queryString = 
		@"SELECT c.oid AS oid, c.relnamespace AS schemaoid, c.relacl, c.relowner, c.relkind, r.rolname, baseten.isobservingcompatible (c.oid) AS isenabled "
		" FROM pg_class c, pg_namespace n, pg_roles r "
		" WHERE c.relowner = r.oid AND c.relnamespace = n.oid AND c.relname = $1 AND n.nspname = $2";		
	}
	else
	{
		queryString = 
		@"SELECT c.oid AS oid, c.relnamespace AS schemaoid, c.relacl, c.relowner, c.relkind, r.rolname, false AS isenabled "
		" FROM pg_class c, pg_namespace n, pg_roles r "
		" WHERE c.relowner = r.oid AND c.relnamespace = n.oid AND c.relname = $1 AND n.nspname = $2";		
	}
	return queryString;
}

- (NSString *) tableDescriptionsByOidQuery
{
	NSString* queryString = nil;
	if ([self hasBaseTenSchema])
	{
		queryString = @"SELECT c.oid AS oid, c.relnamespace AS schemaoid, c.relname, n.nspname, "
		" c.relacl, c.relowner, c.relkind, r.rolname, baseten.isobservingcompatible (c.oid) AS isenabled "
		" FROM pg_class c, pg_namespace n, pg_roles r "
		" WHERE c.relowner = r.oid AND c.relnamespace = n.oid AND c.oid = ANY ($1)";
	}
	else
	{
		queryString = @"SELECT c.oid AS oid, c.relnamespace AS schemaoid, c.relname, n.nspname, "
		" c.relacl, c.relowner, c.relkind, r.rolname, false AS isenabled "
		" FROM pg_class c, pg_namespace n, pg_roles r "
		" WHERE c.relowner = r.oid AND c.relnamespace = n.oid AND c.oid = ANY ($1)";
	}
	return queryString;
}

- (void) handleResult: (PGTSResultSet *) res forTable: (BXPGTableDescription *) desc
{
	[super handleResult: res forTable: desc];
	[desc setEnabled: [[res valueForKey: @"isenabled"] boolValue]];
}
@end
