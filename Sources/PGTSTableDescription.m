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
	[super dealloc];
}

- (NSDictionary *) fields
{
	if (! mFields)
	{
		mFields = [[(PGTSTableDescription *) mDescription fields] mutableCopy];
		TSEnumerate (currentName, e, [[mFields allKeys] objectEnumerator])
		{
			id proxy = [[mFields objectForKey: currentName] proxy];
			[mFields setObject: proxy forKey: currentName];
		}
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
		NSSet* foreignKeys = [(PGTSTableDescription *) mDescription foreignKeys];
		mForeignKeys = [[NSMutableSet alloc] initWithCapacity: [foreignKeys count]];
		TSEnumerate (currentFKey, e, [foreignKeys objectEnumerator])
			[mForeignKeys addObject: [currentFKey proxy]];
	}
	return mForeignKeys;
}

- (NSSet *) referencingForeignKeys
{
	if (! mForeignKeys)
	{
		NSSet* foreignKeys = [(PGTSTableDescription *) mDescription referencingForeignKeys];
		mForeignKeys = [[NSMutableSet alloc] initWithCapacity: [foreignKeys count]];
		TSEnumerate (currentFKey, e, [foreignKeys objectEnumerator])
		[mForeignKeys addObject: [currentFKey proxy]];
	}
	return mForeignKeys;	
}

- (NSArray *) uniqueIndexes
{
	if (! mUniqueIndexes)
	{
		NSArray* indexes = [(PGTSTableDescription *) mDescription uniqueIndexes];
		mUniqueIndexes = [[NSMutableArray alloc] initWithCapacity: [indexes count]];
		TSEnumerate (currentIndex, e, [indexes objectEnumerator])
			[mUniqueIndexes addObject: [currentIndex proxy]];
	}
	return mUniqueIndexes;
}
@end


/** 
 * Database table
 */
@implementation PGTSTableDescription

- (void) dealloc
{
    [[mFields allValues] makeObjectsPerformSelector: @selector (setTable:) withObject: nil];
    [mUniqueIndexes makeObjectsPerformSelector: @selector (setTable:) withObject: nil];

    [mFields release];
	[mFieldIndexes release];
    [mUniqueIndexes release];
    [mSchemaName release];
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

- (Class) proxyClass
{
	return [PGTSTableDescriptionProxy class];
}

- (NSDictionary *) fields
{
	if (! mFields)
	{
		NSString* query = @"SELECT attname, attnum, atttypid, attnotnull FROM pg_attribute WHERE attisdropped = false AND attrelid = $1";
		PGTSResultSet* res = [mConnection executeQuery: query parameters: PGTSOidAsObject (mOid)];
		
		mFields = [NSMutableDictionary dictionaryWithCapacity: [res count]];
		mFieldIndexes = [NSMutableDictionary dictionaryWithCapacity: [res count]];
		while ([res advanceRow])
		{
			NSString* name = [res valueForKey: @"attname"];
			NSNumber* index = [res valueForKey: @"attnum"];
			
			PGTSFieldDescription* field = [[PGTSFieldDescription alloc] init];
			[field setName: name];
			[field setIndex: [index intValue]];
			[field setTypeOid: [[res valueForKey: @"atttypid"] PGTSOidValue]];
			[field setNotNull: [[res valueForKey: @"attnotnull"] boolValue]];
			
			[mFields setObject: field forKey: [field name]];
			[mFieldIndexes setObject: name forKey: index];
			[field release];
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
	return PrimaryKey ([self uniqueIndexes]);
}

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
