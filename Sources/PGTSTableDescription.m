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
#import "PGTSForeignKeyDescription.h"


/** 
 * Database table
 */
@implementation PGTSTableDescription

- (id) initWithConnection: (PGTSConnection *) aConnection
{
    if ((self = [super initWithConnection: aConnection]))
    {
        fieldCount = NSNotFound;
        fields = [[NSMutableDictionary alloc] init];
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

- (void) setDatabase: (PGTSDatabaseDescription *) aDatabase
{
    database = aDatabase;
}

- (PGTSDatabaseDescription *) database
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
    
    while (([res advanceRow]))
    {        
        *target = [[self database] tableWithOid: [[res valueForKey: @"oid"] PGTSOidValue]];
        
        NSArray* sources = [res valueForKey: @"sources"];
        NSMutableArray* sourceFields = [NSMutableArray arrayWithCapacity: [sources count]];
        TSEnumerate (currentIndex, e, [sources objectEnumerator])
            [sourceFields addObject: [src fieldAtIndex: [currentIndex unsignedIntValue]]];
        
        NSArray* references = [res valueForKey: @"references"];
        NSMutableArray* refFields = [NSMutableArray arrayWithCapacity: [references count]];
        TSEnumerate (currentIndex, e, [references objectEnumerator])
            [refFields addObject: [dst fieldAtIndex: [currentIndex unsignedIntValue]]];
        
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


//FIXME: Field indices can be negative.
@implementation PGTSTableDescription (Queries)

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
        [self fieldAtIndex: i];
    
    return [fields allObjects];
}

- (PGTSFieldDescription *) fieldAtIndex: (unsigned int) anIndex
{
    PGTSFieldDescription* rval = [fields objectAtIndex: anIndex];    
    if (nil == rval)
    {
        rval = [[[PGTSFieldDescription alloc] initWithConnection: connection] autorelease];
        [rval setTable: self];
        [rval setIndex: anIndex];
        if (nil == [rval name])
            rval = nil;
        else
            [fields setObject: rval forKey: [NSNumber numberWithUnsignedInt: anIndex]];
    }
    return rval;
}

- (PGTSFieldDescription *) fieldNamed: (NSString *) aName
{
	PGTSFieldDescription* retval = nil;
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
                unsigned int count = [res count];
                if (0 < count)
                {
                    NSMutableArray* indexes = [NSMutableArray arrayWithCapacity: count];
                    while (([res advanceRow]))
                    {
                        PGTSIndexDescription* currentIndex = [[PGTSIndexDescription alloc] initWithConnection: connection];
                        [indexes addObject: currentIndex];
                        [currentIndex release];
                        
                        //Some attributes from the result set
                        [currentIndex setName: [res valueForKey: @"name"]];
                        [currentIndex setOid: [[res valueForKey: @"oid"] PGTSOidValue]];
                        [currentIndex setPrimaryKey: [[res valueForKey: @"indisprimary"] intValue]];
                        
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
                        
                        [currentIndex setSchemaOid: schemaOid];
                    }
                    [self setUniqueIndexes: indexes];
                }
            }
            case 'v':
            {
                //This requires the primarykey view
                NSString* query = @"SELECT baseten.array_accum (attnum) AS attnum "
                " FROM baseten.primarykey WHERE oid = $1 GROUP BY oid";
                PGTSResultSet* res = [connection executeQuery: query parameters: PGTSOidAsObject (oid)];
                if (NO == [res advanceRow])
                    [self setUniqueIndexes: [NSArray array]];
                else
                {
                    PGTSIndexDescription* index = [[PGTSIndexDescription alloc] initWithConnection: connection];
                    NSMutableSet* indexFields = [NSMutableSet set];
                    TSEnumerate (currentFieldIndex, e, [[res valueForKey: @"attnum"] objectEnumerator])
                        [indexFields addObject: [self fieldAtIndex: [currentFieldIndex intValue]]];
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

- (PGTSIndexDescription *) primaryKey
{
    PGTSIndexDescription* rval = nil;
    NSArray* uIndexes = [self uniqueIndexes];
    if (0 < [uIndexes count])
    {
        PGTSIndexDescription* first = [uIndexes objectAtIndex: 0];
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
        if ([foreignKeys count] < [res count])
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
        if ([referencingForeignKeys count] < [res count])
            [referencingForeignKeys unionSet: [self foreignKeySetWithResult: res selfAsSource: NO]];
    }
    return referencingForeignKeys;
}

- (NSArray *) relationOidsBasedOn
{
    if ('v' == [self kind] && nil == relationOidsBasedOn)
    {
        NSString* query = @"SELECT reloid FROM baseten.viewdependency WHERE viewoid = $1";
        PGTSResultSet* res = [connection executeQuery: query parameters: PGTSOidAsObject ([self oid])];
        NSMutableArray* oids = [NSMutableArray arrayWithCapacity: [res count]];
        while (([res advanceRow]))
            [oids addObject: [res valueForKey: @"reloid"]];
        
        [self setRelationOidsBasedOn: oids];
    }
    return relationOidsBasedOn;
}

@end