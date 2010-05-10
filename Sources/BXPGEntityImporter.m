//
// BXPGEntityImporter.m
// BaseTen
//
// Copyright (C) 2006-2010 Marko Karppinen & Co. LLC.
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

#import "BXPGEntityImporter.h"
#import "BXLogger.h"
#import "BXPGInterface.h"
#import "BXDatabaseContextPrivate.h"
#import "BXPGTransactionHandler.h"
#import "BXPGEntityConverter.h"
#import "PGTSResultSet.h"
#import "PGTSHOM.h"
#import "PGTSDatabaseDescription.h"


@implementation BXPGEntityImporter
- (void) dealloc
{
	[mContext release];
	[mEntityConverter release];
	[mEntities release];
	[mSchemaName release];
	[mStatements release];
	[mEnabledRelations release];
	[super dealloc];
}

- (void) setDatabaseContext: (BXDatabaseContext *) aContext
{
	if (mContext != aContext)
	{
		[mContext release];
		mContext = [aContext retain];
	}
}

- (void) setConverter: (BXPGEntityConverter *) aConverter
{
	if (mEntityConverter != aConverter)
	{
		[mEntityConverter setDelegate: nil];
		[mEntityConverter release];
		mEntityConverter = [aConverter retain];
		[mEntityConverter setDelegate: self];
	}
}

- (void) setStatements: (NSArray *) anArray
{
	if (mStatements != anArray)
	{
		[mStatements release];
		mStatements = [anArray retain];
	}
}

- (void) setEntities: (NSArray *) aCollection
{
	if (mEntities != aCollection)
	{
		[mEntities release];
		mEntities = [aCollection retain];
		
		[self setStatements: nil];
	}
}

- (void) setSchemaName: (NSString *) aName
{
	if (mSchemaName != aName)
	{
		[mSchemaName release];
		mSchemaName = [aName retain];
	}
}

- (void) setEnabledRelations: (NSArray *) anArray
{
	if (mEnabledRelations != anArray)
	{
		[mEnabledRelations release];
		mEnabledRelations = [anArray retain];
	}
}

- (void) setDelegate: (id <BXPGEntityImporterDelegate>) anObject
{
	mDelegate = anObject;
}

- (NSArray *) importStatements
{
	return [self importStatements: NULL];
}

- (NSArray *) importStatements: (NSArray **) outErrors
{
	Expect (mContext);
	Expect (mEntities);
	
	if (! mSchemaName)
		[self setSchemaName: @"public"];

	if (! mEntityConverter)
	{
		mEntityConverter = [[BXPGEntityConverter alloc] init];
		[mEntityConverter setDelegate: self];
	}
	
	NSArray* enabledRelations = nil;
	NSArray* statements = [mEntityConverter statementsForEntities: mEntities 
													   schemaName: mSchemaName
												 enabledRelations: &enabledRelations
														   errors: outErrors];
	[self setStatements: statements];
	[self setEnabledRelations: enabledRelations];
	return statements;
}

- (void) enumerateStatements: (NSEnumerator *) statementEnumerator
{
	NSString* statement = [statementEnumerator nextObject];
	if (statement)
	{
		[mDelegate entityImporterAdvanced: self];
		
		PGTSConnection* connection = [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] connection];
		[connection sendQuery: statement delegate: self callback: @selector (receivedResult:) 
			   parameterArray: nil userInfo: statementEnumerator];
	}
	else
	{
		[mDelegate entityImporter: self finishedImporting: YES error: nil];
	}
}

- (void) receivedResult: (PGTSResultSet *) res
{
	if ([res querySucceeded])
		[self enumerateStatements: [res userInfo]];
	else
		[mDelegate entityImporter: self finishedImporting: NO error: [res error]];
}

- (void) importEntities
{
	NSArray* statements = [self importStatements];
	[self enumerateStatements: [statements objectEnumerator]];
}

- (BOOL) enableEntities: (NSError **) outError
{
	BOOL retval = YES;
	
	ExpectR (mSchemaName, NO);
	if (0 < [mEnabledRelations count])
	{
		NSString* queryString = 
		@"SELECT baseten.enable (c.oid) "
		"  FROM pg_class c, pg_namespace n "
		"  WHERE c.relnamespace = n.oid AND n.nspname = $1 AND c.relname = ANY ($2);";
		
		PGTSConnection* connection = [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] connection];
		PGTSResultSet* res = [connection executeQuery: queryString parameters: mSchemaName, mEnabledRelations];
		
		if (! [res querySucceeded])
		{
			retval = NO;
			if (outError)
				*outError = [res error];
		}
	}
	return retval;
}

- (BOOL) disableEntities: (NSArray *) entities error: (NSError **) outError
{
	BOOL retval = YES;
	ExpectR (mSchemaName, NO);
	if (0 < [entities count])
	{
		NSArray* names = (id) [[entities PGTSCollect] name];
		NSString* queryString = 
		@"SELECT baseten.disable (c.oid) "
		"  FROM pg_class c, pg_namespace n "
		"  WHERE c.relnamespace = n.oid AND n.nspname = $1 AND c.relname = ANY ($2);";
		
		PGTSConnection* connection = [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] connection];
		PGTSResultSet* res = [connection executeQuery: queryString parameters: mSchemaName, names];
		
		if (! [res querySucceeded])
		{
			retval = NO;
			if (outError)
				*outError = [res error];
		}
	}
	return retval;
}
@end



@implementation BXPGEntityImporter (BXPGEntityConverterDelegate)
- (BXEntityDescription *) entityConverter: (BXPGEntityConverter *) converter 
 shouldAddDropStatementFromEntityMatching: (NSEntityDescription *) importedEntity
								 inSchema: (NSString *) schemaName
									error: (NSError **) outError
{
	return [[mContext databaseObjectModel] matchingEntity: importedEntity inSchema: schemaName];
}


- (BOOL) entityConverter: (BXPGEntityConverter *) converter shouldCreateSchema: (NSString *) schemaName
{
	ExpectR (mContext, NO);
	PGTSConnection* connection = [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] connection];
	PGTSDatabaseDescription* database = [connection databaseDescription];
	return ([database schemaNamed: schemaName] ? NO : YES);
}


- (PGTSConnection *) connectionForEntityConverter: (BXPGEntityConverter *) converter
{
	Expect (mContext);
	return [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] connection];
}
@end
