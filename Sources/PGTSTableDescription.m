//
// PGTSTableDescription.m
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

#import "PGTSTableDescription.h"
#import "PGTSFieldDescription.h"
#import "PGTSFunctions.h"
#import "PGTSIndexDescription.h"
#import "PGTSResultSet.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"
#import "PGTSDatabaseDescription.h"
//#import "PGTSForeignKeyDescription.h"
#import "PGTSHOM.h"


static PGTSIndexDescription*
PrimaryKey (NSArray* uIndexes)
{
	PGTSIndexDescription* retval = nil;
    if (0 < [uIndexes count])
    {
        PGTSIndexDescription* first = [uIndexes objectAtIndex: 0];
        if ([first isPrimaryKey])
            retval = first;
    }
    return retval;
}


@implementation PGTSTableDescriptionProxy
- (void) dealloc
{
	[mFields release];
	[mUniqueIndexes release];
	[mForeignKeys release];
	[mReferencingForeignKeys release];
	[mRelationOidsBasedOn release];
	[super dealloc];
}

- (NSDictionary *) fields
{
	if (! mFields)
	{
		[[[self invocationRecorder] record] fields];
		mFields = [[self performSynchronizedAndReturnProxies] retain];
	}
	return mFields;
}

- (PGTSFieldDescription *) fieldAtIndex: (int) anIndex
{
	[[NSException exceptionWithName: NSInternalInconsistencyException reason: @"-[PGTSTableDescriptionProxy fieldAtIndex:] called." userInfo: nil] raise];
	return nil;
}

- (PGTSIndexDescription *) primaryKey
{
	return PrimaryKey ([self uniqueIndexes]);
}

- (NSSet *) foreignKeys
{
	if (! mForeignKeys)
	{
		[[[self invocationRecorder] record] foreignKeys];
		mForeignKeys = [[self performSynchronizedAndReturnProxies] retain];
	}
	return mForeignKeys;
}

- (NSSet *) referencingForeignKeys
{
	if (! mReferencingForeignKeys)
	{
		[[[self invocationRecorder] record] referencingForeignKeys];
		mReferencingForeignKeys = [[self performSynchronizedAndReturnProxies] retain];
	}
	return mForeignKeys;	
}

- (NSArray *) uniqueIndexes
{
	if (! mUniqueIndexes)
	{
		[[[self invocationRecorder] record] uniqueIndexes];
		mUniqueIndexes = [[self performSynchronizedAndReturnProxies] retain];
	}
	return mUniqueIndexes;
}
@end


/** 
 * \internal
 * Database table
 */
@implementation PGTSTableDescription

- (void) dealloc
{
    [mFields release];
	[mFieldIndexes release];
    [mUniqueIndexes release];
    [mForeignKeys release];
    [mReferencingForeignKeys release];
    [mRelationOidsBasedOn release];
    [super dealloc];
}

- (void) setUniqueIndexes: (NSArray *) anArray
{
    if (anArray != mUniqueIndexes)
    {
        [mUniqueIndexes release];
        mUniqueIndexes = [anArray retain];
    }
}

#if 0
- (NSSet *) foreignKeySetWithResult: (PGTSResultSet *) res selfAsSource: (BOOL) selfAsSource
{
    PGTSTableDescription* src = nil;
    PGTSTableDescription* dst = nil;
    
    PGTSTableDescription** target = NULL;
    if (selfAsSource)
    {
        src = self;
        target = &dst;
    }
    else
    {
        target = &src;
        dst = self;
    }
    
	NSMutableSet* retval = [NSMutableSet setWithCapacity: [res count]];
	PGTSDatabaseDescription* database = [[res connection] databaseDescription];
    while (([res advanceRow]))
    {        
        *target = [database tableWithOid: [[res valueForKey: @"oid"] PGTSOidValue]];
        
        NSArray* sources = [res valueForKey: @"sources"];
        NSMutableArray* sourceFields = [NSMutableArray arrayWithCapacity: [sources count]];
        TSEnumerate (currentIndex, e, [sources objectEnumerator])
            [sourceFields addObject: [src fieldAtIndex: [currentIndex unsignedIntValue]]];
        
        NSArray* references = [res valueForKey: @"references"];
        NSMutableArray* refFields = [NSMutableArray arrayWithCapacity: [references count]];
        TSEnumerate (currentIndex, e, [references objectEnumerator])
            [refFields addObject: [dst fieldAtIndex: [currentIndex unsignedIntValue]]];
        
        NSString* aName = [res valueForKey: @"name"];
        
        PGTSForeignKeyDescription* desc = [[PGTSForeignKeyDescription alloc] initWithName: aName sourceFields: sourceFields referenceFields: refFields];
		[desc setDeleteRule: [[res valueForKey: @"deltype"] characterAtIndex: 0]];
        [retval addObject: desc];
        [desc release];
        
    }
    return retval;
}
#endif

- (Class) proxyClass
{
	return [PGTSTableDescriptionProxy class];
}

- (NSDictionary *) fields
{
	if (! mFields)
	{
		NSString* query = 
		@"SELECT a.attname, a.attnum, a.atttypid, a.attnotnull, pg_get_expr (d.adbin, d.adrelid, false) AS default "
		@" FROM pg_attribute a LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid "
		@" WHERE a.attisdropped = false AND a.attrelid = $1"; 
		PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject (mOid)];
		
		mFields = [[NSMutableDictionary alloc] initWithCapacity: [res count]];
		mFieldIndexes = [[NSMutableDictionary alloc] initWithCapacity: [res count]];
		while ([res advanceRow])
		{
			NSString* name = [res valueForKey: @"attname"];
			NSNumber* index = [res valueForKey: @"attnum"];
			
			PGTSFieldDescription* field = [[[PGTSFieldDescription alloc] init] autorelease];
			[field setName: name];
			[field setIndex: [index intValue]];
			[field setTypeOid: [[res valueForKey: @"atttypid"] PGTSOidValue]];
			[field setNotNull: [[res valueForKey: @"attnotnull"] boolValue]];			
			[field setDefaultValue: [res valueForKey: @"default"]];
			
			[mFields setObject: field forKey: [field name]];
			[mFieldIndexes setObject: name forKey: index];
		}
	}
	return mFields;
}

- (PGTSFieldDescription *) fieldAtIndex: (int) anIndex
{
	NSDictionary* fields = [self fields];
	return [fields objectForKey: [mFieldIndexes objectForKey: [NSNumber numberWithInt: anIndex]]];
}

- (PGTSFieldDescription *) fieldNamed: (NSString *) aName
{
	return [[self fields] objectForKey: aName];
}

- (void) fetchUniqueIndexesForTable
{
	//c.oid is unique
	NSString* query = @"SELECT relname AS name, indexrelid AS oid, "
	"indisprimary, indnatts, indkey::INTEGER[] FROM pg_index, pg_class c "
	"WHERE indisunique = true AND indrelid = $1 AND indexrelid = c.oid "
	"ORDER BY indisprimary DESC";
	PGTSResultSet* res =  [mConnection executeQuery: query
										 parameters: PGTSOidAsObject (mOid)];
	unsigned int count = [res count];
	if (0 < count)
	{
		NSMutableArray* indexes = [NSMutableArray arrayWithCapacity: count];
		while (([res advanceRow]))
		{
			PGTSIndexDescription* currentIndex = [[[PGTSIndexDescription alloc] init] autorelease];
			[indexes addObject: currentIndex];
			
			//Some attributes from the result set
			[currentIndex setName: [res valueForKey: @"name"]];
			[currentIndex setOid: [[res valueForKey: @"oid"] PGTSOidValue]];
			[currentIndex setPrimaryKey: [[res valueForKey: @"indisprimary"] boolValue]];
			
			//Get the field indexes and set the fields
			NSMutableSet* indexFields = [NSMutableSet setWithCapacity: 
										 [[res valueForKey: @"indnatts"] unsignedIntValue]];
			TSEnumerate (currentFieldIndex, e, [[res valueForKey: @"indkey"] objectEnumerator])
			{
				int index = [currentFieldIndex intValue];
				if (index > 0)
					[indexFields addObject: [self fieldAtIndex: index]];
			}
			[currentIndex setTable: self];
			[currentIndex setFields: indexFields];
			
			[currentIndex setSchemaOid: mSchemaOid];
		}
		[self setUniqueIndexes: indexes];
	}
}

- (void) fetchUniqueIndexesForView
{
	//Views don't normally have unique indexes.
}

- (NSArray *) uniqueIndexes;
{
    if (nil == mUniqueIndexes)
    {
        switch ([self kind])
        {
            case 'r':
				[self fetchUniqueIndexesForTable];
				break;
				
            case 'v':
				[self fetchUniqueIndexesForView];
				break;
				
            default:
                break;
        }
    }
    return mUniqueIndexes;
}

- (PGTSIndexDescription *) primaryKey
{
	return PrimaryKey ([self uniqueIndexes]);
}

#if 0
- (NSSet *) foreignKeys
{
    if (! mForeignKeys)
    {
        NSString* query = 
        @"SELECT "
        "c.conname AS name, "
        "c.confrelid AS oid, "          //Referenced table's OID
        "c.conkey AS sources, "         //Constrained columns
        "c.confkey AS references, "     //Referenced columns
		"c.confdeltype AS deltype "		//Delete rule
        "FROM pg_constraint c "
        "WHERE c.contype = 'f' AND "    //Foreign keys
        "c.conrelid = $1 ";             //Source's OID
        
        PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject (mOid)];
		mForeignKeys = [[self foreignKeySetWithResult: res selfAsSource: YES] retain];
    }
    return mForeignKeys;
}

- (NSSet *) referencingForeignKeys
{
    if (! mReferencingForeignKeys)
    {
		mReferencingForeignKeys = [[NSMutableSet alloc] init];
		
        NSString* query = 
        @"SELECT "
        "c.conname AS name, "
        "c.conrelid AS oid, "           //Source table's OID
        "c.conkey AS sources, "         //Constrained columns
        "c.confkey AS references, "     //Referenced columns
		"c.confdeltype AS deltype "		//Delete rule
        "FROM pg_constraint c "
        "WHERE c.contype = 'f' AND "    //Foreign keys
        "c.confrelid = $1 ";            //Reference's OID
        
        PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject (mOid)];
		mReferencingForeignKeys = [[self foreignKeySetWithResult: res selfAsSource: NO] retain];
    }
    return mReferencingForeignKeys;
}
#endif

- (NSArray *) relationOidsBasedOn
{
    if ('v' == [self kind] && ! mRelationOidsBasedOn)
    {
        NSString* query = @"SELECT reloid FROM baseten.viewdependency WHERE viewoid = $1";
        PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject ([self oid])];
        NSMutableArray* oids = [NSMutableArray arrayWithCapacity: [res count]];
        while (([res advanceRow]))
            [oids addObject: [res valueForKey: @"reloid"]];
        
		[mRelationOidsBasedOn release];
		mRelationOidsBasedOn = [oids retain];
    }
    return mRelationOidsBasedOn;
}

@end
