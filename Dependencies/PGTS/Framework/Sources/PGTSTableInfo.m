//
// PGTSTableInfo.m
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

#import "PGTSTableInfo.h"
#import "PGTSFieldInfo.h"
#import "PGTSFunctions.h"
#import "PGTSIndexInfo.h"
#import "PGTSResultSet.h"
#import "PGTSConnection.h"
#import "PGTSAdditions.h"
#import "PGTSDatabaseInfo.h"
#import "PGTSForeignKeyDescription.h"
#import <MKCCollections/MKCCollections.h>


/** 
 * Database table
 */
@implementation PGTSTableInfo

- (id) initWithConnection: (PGTSConnection *) aConnection
{
    if ((self = [super initWithConnection: aConnection]))
    {
        fieldCount = NSNotFound;
        fields = [MKCDictionary copyDictionaryWithKeyType: kMKCCollectionTypeInteger
                                                valueType: kMKCCollectionTypeObject];
        hasForeignKeys = NO;
        foreignKeys = [[NSMutableSet alloc] init];
        hasReferencingForeignKeys = NO;
        referencingForeignKeys = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [fields        makeObjectsPerformSelector: @selector (setTable:) withObject: nil];
    [uniqueIndexes makeObjectsPerformSelector: @selector (setTable:) withObject: nil];

    [fields release];
    [uniqueIndexes release];
    [schemaName release];
    [foreignKeys release];
    [referencingForeignKeys release];
    [relationOidsBasedOn release];
    [super dealloc];
}

- (void) setDatabase: (PGTSDatabaseInfo *) aDatabase
{
    database = aDatabase;
}

- (PGTSDatabaseInfo *) database
{
    return database;
}

- (void) setUniqueIndexes: (NSArray *) anArray
{
    if (anArray != uniqueIndexes)
    {
        [uniqueIndexes release];
        uniqueIndexes = [anArray retain];
    }
}

- (void) setFieldCount: (unsigned int) anInt
{
    fieldCount = anInt;
}

- (NSArray *) relationOidsBasedOn
{
    return relationOidsBasedOn; 
}

- (void) setRelationOidsBasedOn: (NSArray *) aRelationOidsBasedOn
{
    if (relationOidsBasedOn != aRelationOidsBasedOn) 
    {
        [relationOidsBasedOn release];
        relationOidsBasedOn = [aRelationOidsBasedOn retain];
    }
}

- (NSSet *) foreignKeySetWithResult: (PGTSResultSet *) res selfAsSource: (BOOL) selfAsSource
{
    PGTSTableInfo* src = nil;
    PGTSTableInfo* dst = nil;
    
    PGTSTableInfo** target = NULL;
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
    
    while (([res advanceRow]))
    {        
        *target = [[self database] tableInfoForTableWithOid: [[res valueForKey: @"oid"] PGTSOidValue]];
        
        NSArray* sources = [res valueForKey: @"sources"];
        NSMutableArray* sourceFields = [NSMutableArray arrayWithCapacity: [sources count]];
        TSEnumerate (currentIndex, e, [sources objectEnumerator])
            [sourceFields addObject: [src fieldInfoForFieldAtIndex: [currentIndex unsignedIntValue]]];
        
        NSArray* references = [res valueForKey: @"references"];
        NSMutableArray* refFields = [NSMutableArray arrayWithCapacity: [references count]];
        TSEnumerate (currentIndex, e, [references objectEnumerator])
            [refFields addObject: [dst fieldInfoForFieldAtIndex: [currentIndex unsignedIntValue]]];
        
        NSString* aName = [res valueForKey: @"name"];
        
        PGTSForeignKeyDescription* desc = [[PGTSForeignKeyDescription alloc] initWithConnection: connection
                                                                                           name: aName 
                                                                                   sourceFields: sourceFields 
                                                                                referenceFields: refFields];
		[desc setDeleteRule: [[res valueForKey: @"deltype"] characterAtIndex: 0]];
        [foreignKeys addObject: desc];
        [desc release];
        
    }
    return foreignKeys;
}

@end


@implementation PGTSTableInfo (Queries)

- (NSArray *) allFields
{
    if (NSNotFound == fieldCount)
    {
        NSString* query = @"SELECT max (attnum) AS count FROM pg_attribute WHERE attisdropped = false AND attrelid = $1";
        PGTSResultSet* res = [connection executeQuery: query parameters: PGTSOidAsObject (oid)];
        [res advanceRow];
        [self setFieldCount: [[res valueForKey: @"count"] unsignedIntValue]];
    }
    
    for (unsigned int i = 1; i <= fieldCount; i++)
        [self fieldInfoForFieldAtIndex: i];
    
    return [fields allObjects];
}

- (PGTSFieldInfo *) fieldInfoForFieldAtIndex: (unsigned int) anIndex
{
    PGTSFieldInfo* rval = [fields objectAtIndex: anIndex];    
    if (nil == rval)
    {
        rval = [[[PGTSFieldInfo alloc] initWithConnection: connection] autorelease];
        [rval setTable: self];
        [rval setIndex: anIndex];
        if (nil == [rval name])
            rval = nil;
        else
            [fields setObject: rval atIndex: anIndex];
    }
    return rval;
}

- (PGTSFieldInfo *) fieldInfoForFieldNamed: (NSString *) aName
{
	PGTSFieldInfo* retval = nil;
	NSArray* allFields = [self allFields];
	TSEnumerate (currentField, e, [allFields objectEnumerator])
	{
		if ([[currentField name] isEqualToString: aName])
		{
			retval = currentField;
			break;
		}
	}
	return retval;
}

- (NSArray *) uniqueIndexes;
{
    if (nil == uniqueIndexes)
    {
        switch ([self kind])
        {
            case 'r':
            {
                //c.oid is unique
                NSString* query = @"SELECT relname AS name, indexrelid AS oid, "
                "indisprimary, indnatts, indkey::INTEGER[] FROM pg_index, pg_class c "
                "WHERE indisunique = true AND indrelid = $1 AND indexrelid = c.oid "
                "ORDER BY indisprimary DESC";
                PGTSResultSet* res =  [connection executeQuery: query
                                                    parameters: PGTSOidAsObject (oid)];
                unsigned int count = [res numberOfRowsAffected];
                if (0 < count)
                {
                    NSMutableArray* indexes = [NSMutableArray arrayWithCapacity: count];
                    while (([res advanceRow]))
                    {
                        PGTSIndexInfo* currentIndex = [[PGTSIndexInfo alloc] initWithConnection: connection];
                        [indexes addObject: currentIndex];
                        [currentIndex release];
                        
                        //Some attributes from the result set
                        [currentIndex setName: [res valueForFieldNamed: @"name"]];
                        [currentIndex setOid: [[res valueForFieldNamed: @"oid"] PGTSOidValue]];
                        [currentIndex setPrimaryKey: [[res valueForFieldNamed: @"indisprimary"] intValue]];
                        
                        //Get the field indexes and set the fields
                        NSMutableSet* indexFields = [NSMutableSet setWithCapacity: 
                            [[res valueForFieldNamed: @"indnatts"] unsignedIntValue]];
                        TSEnumerate (currentFieldIndex, e, [[res valueForFieldNamed: @"indkey"] objectEnumerator])
                        {
                            int index = [currentFieldIndex intValue];
                            if (index > 0)
                                [indexFields addObject: [self fieldInfoForFieldAtIndex: index]];
                        }
                        [currentIndex setTable: self];
                        [currentIndex setFields: indexFields];
                        
                        [currentIndex setSchemaOid: schemaOid];
                    }
                    [self setUniqueIndexes: indexes];
                }
            }
            case 'v':
            {
                //This requires the primarykey view
                NSString* query = @"SELECT \"" PGTS_SCHEMA_NAME "\".array_accum (attnum) AS attnum "
                " FROM \"" PGTS_SCHEMA_NAME "\".primarykey WHERE oid = $1 GROUP BY oid";
                PGTSResultSet* res = [connection executeQuery: query parameters: PGTSOidAsObject (oid)];
                if (NO == [res advanceRow])
                    [self setUniqueIndexes: [NSArray array]];
                else
                {
                    PGTSIndexInfo* index = [[PGTSIndexInfo alloc] initWithConnection: connection];
                    NSMutableSet* indexFields = [NSMutableSet set];
                    TSEnumerate (currentFieldIndex, e, [[res valueForFieldNamed: @"attnum"] objectEnumerator])
                        [indexFields addObject: [self fieldInfoForFieldAtIndex: [currentFieldIndex intValue]]];
                    [index setPrimaryKey: YES];
                    [index setFields: indexFields];
                    [index setTable: self];
                    [self setUniqueIndexes: [NSArray arrayWithObject: index]];
                }
            }
            default:
                break;
        }
    }
    return uniqueIndexes;
}

- (PGTSIndexInfo *) primaryKey
{
    PGTSIndexInfo* rval = nil;
    NSArray* uIndexes = [self uniqueIndexes];
    if (0 < [uIndexes count])
    {
        PGTSIndexInfo* first = [uIndexes objectAtIndex: 0];
        if ([first isPrimaryKey])
            rval = first;
    }
    return rval;
}

- (NSSet *) foreignKeys
{
    if (NO == hasForeignKeys)
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
        
        PGTSResultSet* res = [connection executeQuery: query parameters: PGTSOidAsObject (oid)];
        hasForeignKeys = YES;
        if ([foreignKeys count] < [res countOfRows])
            [foreignKeys unionSet: [self foreignKeySetWithResult: res selfAsSource: YES]];
    }
    return foreignKeys;
}

- (NSSet *) referencingForeignKeys
{
    if (NO == hasReferencingForeignKeys)
    {
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
        
        PGTSResultSet* res = [connection executeQuery: query parameters: PGTSOidAsObject (oid)];
        hasReferencingForeignKeys = YES;
        if ([referencingForeignKeys count] < [res countOfRows])
            [referencingForeignKeys unionSet: [self foreignKeySetWithResult: res selfAsSource: NO]];
    }
    return referencingForeignKeys;
}

- (NSArray *) relationOidsBasedOn
{
    if ('v' == [self kind] && nil == relationOidsBasedOn)
    {
        NSString* query = @"SELECT reloid FROM \"" PGTS_SCHEMA_NAME "\".viewdependency WHERE viewoid = $1";
        PGTSResultSet* res = [connection executeQuery: query parameters: PGTSOidAsObject ([self oid])];
        NSMutableArray* oids = [NSMutableArray arrayWithCapacity: [res countOfRows]];
        while (([res advanceRow]))
            [oids addObject: [res valueForKey: @"reloid"]];
        
        [self setRelationOidsBasedOn: oids];
    }
    return relationOidsBasedOn;
}

@end