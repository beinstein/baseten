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

- (id) init
{
    if ((self = [super init]))
    {
        mFieldCount = NSNotFound;
        mFields = [[NSMutableDictionary alloc] init];
        mHasForeignKeys = NO;
        mForeignKeys = [[NSMutableSet alloc] init];
        mHasReferencingForeignKeys = NO;
        mReferencingForeignKeys = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [mFields        makeObjectsPerformSelector: @selector (setTable:) withObject: nil];
    [mUniqueIndexes makeObjectsPerformSelector: @selector (setTable:) withObject: nil];

    [mFields release];
    [mUniqueIndexes release];
    [mSchemaName release];
    [mForeignKeys release];
    [mReferencingForeignKeys release];
    [mRelationOidsBasedOn release];
    [super dealloc];
}

- (void) setDatabase: (PGTSDatabaseDescription *) aDatabase
{
    mDatabase = aDatabase;
}

- (PGTSDatabaseDescription *) database
{
    return mDatabase;
}

- (void) setUniqueIndexes: (NSArray *) anArray
{
    if (anArray != mUniqueIndexes)
    {
        [mUniqueIndexes release];
        mUniqueIndexes = [anArray retain];
    }
}

- (void) setFieldCount: (unsigned int) anInt
{
    mFieldCount = anInt;
}

- (NSArray *) relationOidsBasedOn
{
    return mRelationOidsBasedOn; 
}

- (void) setRelationOidsBasedOn: (NSArray *) aRelationOidsBasedOn
{
    if (mRelationOidsBasedOn != aRelationOidsBasedOn) 
    {
        [mRelationOidsBasedOn release];
        mRelationOidsBasedOn = [aRelationOidsBasedOn retain];
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
        
        PGTSForeignKeyDescription* desc = [[PGTSForeignKeyDescription alloc] initWithName: aName sourceFields: sourceFields referenceFields: refFields];
		[desc setDeleteRule: [[res valueForKey: @"deltype"] characterAtIndex: 0]];
        [mForeignKeys addObject: desc];
        [desc release];
        
    }
    return mForeignKeys;
}

@end


//FIXME: Field indices can be negative.
@implementation PGTSTableDescription (Queries)

- (NSArray *) allFields
{
    if (NSNotFound == mFieldCount)
    {
        NSString* query = @"SELECT max (attnum) AS count FROM pg_attribute WHERE attisdropped = false AND attrelid = $1";
        PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject (mOid)];
        [res advanceRow];
        [self setFieldCount: [[res valueForKey: @"count"] unsignedIntValue]];
    }
    
    for (unsigned int i = 1; i <= mFieldCount; i++)
        [self fieldAtIndex: i];
    
    return [mFields allObjects];
}

- (PGTSFieldDescription *) fieldAtIndex: (unsigned int) anIndex
{
    PGTSFieldDescription* rval = [mFields objectAtIndex: anIndex];    
    if (nil == rval)
    {
        rval = [[[PGTSFieldDescription alloc] init] autorelease];
        [rval setTable: self];
        [rval setIndex: anIndex];
        if (nil == [rval name])
            rval = nil;
        else
            [mFields setObject: rval forKey: [NSNumber numberWithUnsignedInt: anIndex]];
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
    if (nil == mUniqueIndexes)
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
                PGTSResultSet* res =  [mConnection executeQuery: query
                                                    parameters: PGTSOidAsObject (mOid)];
                unsigned int count = [res count];
                if (0 < count)
                {
                    NSMutableArray* indexes = [NSMutableArray arrayWithCapacity: count];
                    while (([res advanceRow]))
                    {
                        PGTSIndexDescription* currentIndex = [[PGTSIndexDescription alloc] init];
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
                        
                        [currentIndex setSchemaOid: mSchemaOid];
                    }
                    [self setUniqueIndexes: indexes];
                }
            }
            case 'v':
            {
                //This requires the primarykey view
                NSString* query = @"SELECT baseten.array_accum (attnum) AS attnum "
                " FROM baseten.primarykey WHERE oid = $1 GROUP BY oid";
                PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject (mOid)];
                if (NO == [res advanceRow])
                    [self setUniqueIndexes: [NSArray array]];
                else
                {
                    PGTSIndexDescription* index = [[PGTSIndexDescription alloc] init];
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
    return mUniqueIndexes;
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
    if (NO == mHasForeignKeys)
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
        mHasForeignKeys = YES;
        if ([mForeignKeys count] < [res count])
            [mForeignKeys unionSet: [self foreignKeySetWithResult: res selfAsSource: YES]];
    }
    return mForeignKeys;
}

- (NSSet *) referencingForeignKeys
{
    if (NO == mHasReferencingForeignKeys)
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
        
        PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject (mOid)];
        mHasReferencingForeignKeys = YES;
        if ([mReferencingForeignKeys count] < [res count])
            [mReferencingForeignKeys unionSet: [self foreignKeySetWithResult: res selfAsSource: NO]];
    }
    return mReferencingForeignKeys;
}

- (NSArray *) relationOidsBasedOn
{
    if ('v' == [self kind] && nil == mRelationOidsBasedOn)
    {
        NSString* query = @"SELECT reloid FROM baseten.viewdependency WHERE viewoid = $1";
        PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject ([self oid])];
        NSMutableArray* oids = [NSMutableArray arrayWithCapacity: [res count]];
        while (([res advanceRow]))
            [oids addObject: [res valueForKey: @"reloid"]];
        
        [self setRelationOidsBasedOn: oids];
    }
    return mRelationOidsBasedOn;
}

@end