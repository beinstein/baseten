//
// PGTSResultSet.m
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

#import <stdlib.h>
#import <limits.h>
#import <PGTS/postgresql/libpq-fe.h> 
#import <Log4Cocoa/Log4Cocoa.h>
#import "PGTSResultSet.h"
#import "PGTSResultSetPrivate.h"
#import "PGTSAdditions.h"
#import "PGTSResultRow.h"
#import "PGTSConnection.h"
#import "PGTSFunctions.h"
#import "PGTSConstants.h"
#import "PGTSDatabaseInfo.h"
#import "PGTSTableInfo.h"
#import "PGTSFieldInfo.h"
#import "PGTSTypeInfo.h"


/** 
 * Result set for a query.
 * A result set contains rows that may be iterated by the user.
 */
@implementation PGTSResultSet

#if 0
- (PGTSConnection *) connection
{
    return connection;
}
#endif

//FIXME: check that all retained objects are released
- (void) dealloc
{
	PQclear (result);
    
#if 0
    [fieldnames release];
	if (deserializedFields)
	{
		free (valueClassArray);
	}
    [rowAwakenInvocation release];
#endif
    
	[super dealloc];
}

- (ExecStatusType) status
{
	return PQresultStatus (mResult);
}

- (BOOL) querySucceeded
{
    ExecStatusType s = [self status];
    return (PGRES_FATAL_ERROR != s && PGRES_BAD_RESPONSE != s);
}

- (int) numberOfFields
{
	return mFields;
}

- (BOOL) isAtEnd
{
    return (currentRow == mTuples - 1);
}

- (BOOL) advanceRow
{
    BOOL retval = NO;
    if (NO == deserializedFields && YES == determinesFieldClassesAutomatically)
        [self beginDeserialization];
    
    //Row numbering is zero-based.
    //The number is initially -1. 
	if (currentRow < tuples - 1)
	{
        currentRow++;
		retval = YES;
	}
	return retval;
}

- (id) valueForFieldAtIndex: (int) columnIndex row: (int) rowIndex
{
    id retval = nil;
    if (! ((columnIndex < mFields) && (rowIndex < mTuples)))
    {
        @throw [NSException exceptionWithName: NSRangeException reason: nil userInfo: nil];
    }
    
    if (!PQgetisnull (result, rowIndex, columnIndex))
    {
        Class objectClass = Nil;
        if (!deserializedFields || Nil == (objectClass = valueClassArray [columnIndex]))
            objectClass = [NSData class];
        char* value = PQgetvalue (result, rowIndex, columnIndex);
        PGTSTypeInfo* type = [[connection databaseInfo] typeInfoForTypeWithOid: PQftype (result, columnIndex)];
        rval = [objectClass newForPGTSResultSet: self withCharacters: value typeInfo: type];
    }
    return retval;
}

- (id) valueForFieldNamed: (NSString *) aName row: (int) rowIndex
{
    unsigned int columnIndex = [fieldnames integerForKey: aName];
    if (NSNotFound == columnIndex)
    {
        [[NSException exceptionWithName: kPGTSFieldNotFoundException reason: nil 
                               userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                   aName, kPGTSFieldnameKey,
                                   self,  kPGTSResultSetKey,
                                   nil]] 
            raise];
    }
    return [self valueForFieldAtIndex: columnIndex row: rowIndex];
}

- (id) valueForFieldNamed: (NSString *) aName
{
    return [self valueForFieldNamed: aName row: currentRow];
}

- (id) valueForKey: (NSString *) aKey
{
	//Unknown key raises an exception.
    return [self valueForFieldNamed: aKey];
}

- (id) valueForFieldAtIndex: (int) columnIndex
{
    return [self valueForFieldAtIndex: columnIndex row: currentRow];
}

- (unsigned int) indexOfFieldNamed: (NSString *) aName
{
    return [fieldnames integerForKey: aName];
}

- (int) currentRow
{
    return currentRow;
}

/**
 * Current row with values in the same order as given in the query
 */
- (NSArray *) currentRowAsArray
{
    NSMutableArray* row = [NSMutableArray arrayWithCapacity: fields];
    for (int i = 0; i < fields; i++)
    {
        id value = [self valueForFieldAtIndex: i];
        [row addObject: (value == nil ? [NSNull null] : value)];
    }
    return row;
}

/**
 * Current row with field names as keys
 * NSNull is used in place of nil
 */
- (NSDictionary *) currentRowAsDictionary
{
    NSMutableDictionary* rowDict = [NSMutableDictionary dictionaryWithCapacity: fields];
    [self setValuesFromRow: currentRow target: rowDict nullPlaceholder: [NSNull null]];
    return [[rowDict copy] autorelease];
}

/** Move to the beginning of the result set */
- (void) goBeforeFirstRow
{
    [self goToRow: -1];
}

- (BOOL) goToRow: (int) aRow
{
	if (-1 <= aRow && aRow < tuples)
	{
		currentRow = aRow;
		return YES;
	}
	return NO;
}

- (int) numberOfRowsAffected;
{
	return tuples;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<%@ %u (%p) PGres: %p cr: %d t: %d f: %d hbv: %d ok: %d>",
        [self class], serial, self, result, currentRow, tuples, fields, deserializedFields, [self querySucceeded]];
}

- (unsigned long long) numberOfRowsAffectedByCommand;
{
	return strtoull (PQcmdTuples (result), NULL, 10);
}

@end


/** Automatic construction of objects */
@implementation PGTSResultSet (Serialization)

- (void) setDeterminesFieldClassesAutomatically: (BOOL) aBool
{
    determinesFieldClassesAutomatically = aBool;
}

- (BOOL) determinesFieldClassesAutomatically
{
    return determinesFieldClassesAutomatically;
}

/**
 * Set the class that should be used with a specific field
 * @{
 */
- (BOOL) setClass: (Class) aClass forFieldNamed: (NSString *) aName
{
    return [self setClass: aClass forFieldAtIndex: [fieldnames integerForKey: aName]];
}

- (BOOL) setClass: (Class) aClass forFieldAtIndex: (int) fieldIndex
{
    BOOL rval = NO;
    if (!deserializedFields)
        [self beginDeserialization];
    if (fieldIndex < fields)
    {
        valueClassArray [fieldIndex] = aClass;
        rval = YES;
    }
    return rval;
}

- (Class) classForFieldNamed: (NSString *) aName
{
	return [self classForFieldAtIndex: [fieldnames integerForKey: aName]];
}

- (Class) classForFieldAtIndex: (int) fieldIndex
{
	Class retval = Nil;
	if (!deserializedFields)
		[self beginDeserialization];
	if (fieldIndex < fields)
        retval = valueClassArray [fieldIndex];
	return retval;
}

- (BOOL) setFieldClassesFromArray: (NSArray *) classes
{
    int count = [classes count];
    for (int i = 0; i < count; i++)
    {
        Class currentClass = [classes objectAtIndex: i];
        log4AssertValueReturn ([currentClass class] == currentClass, NO, 
							   @"Class array may contain only classes (was %@).", classes);

        if ([NSNull null] != (void *) currentClass)
            if (NO == [self setClass: currentClass forFieldAtIndex: i])
                return NO;
    }
    return YES;
}
//@}

- (void) setRowClass: (Class) aClass
{
    if ([aClass conformsToProtocol: @protocol (PGTSResultRowProtocol)])
        rowClass = aClass;
    else
    {
        //FIXME: localize me
        NSString* reason = @"Class %@ does not conform to protocol PGTSResultRowProtocol";
        [NSException raise: NSInvalidArgumentException 
                    format: reason, aClass];
    }
}

- (Class) rowClass
{
    return rowClass;
}

- (NSInvocation *) rowAwakenInvocation
{
    return rowAwakenInvocation;
}

- (void) setRowAwakenInvocation: (NSInvocation *) invocation
{
    if (invocation != rowAwakenInvocation)
    {
        [rowAwakenInvocation release];
        rowAwakenInvocation = [invocation retain];
    }
}

- (void) setValuesToTarget: (id) targetObject
{
    [self setValuesFromRow: currentRow target: targetObject nullPlaceholder: nil];
}

- (void) setValuesFromRow: (int) rowIndex target: (id) targetObject
{
    [self setValuesFromRow: rowIndex target: targetObject nullPlaceholder: nil];
}

- (void) setValuesFromRow: (int) rowIndex target: (id) targetObject nullPlaceholder: (id) anObject
{
    TSEnumerate (fieldname, e, [fieldnames keyEnumerator])
    {
        id value = [self valueForFieldAtIndex: [fieldnames integerForKey: fieldname] row: rowIndex];
        if (nil == value)
        {
            value = anObject;
        }
        
        //setValue throws an exception if a suitable method or an ivar cannot be found
        NS_DURING
            [targetObject setValue: value forKey: fieldname];
        NS_HANDLER
        NS_ENDHANDLER
    }    
}

- (id) currentRowAsObject
{
    return [self objectInRowsAtIndex: currentRow];
}

- (NSArray *) resultAsArray
{
    if (NO == deserializedFields && YES == determinesFieldClassesAutomatically)
        [self beginDeserialization];

    NSMutableArray* rval = [NSMutableArray arrayWithCapacity: tuples];
    for (int i = 0; i < tuples; i++)
        [rval addObject: [self objectInRowsAtIndex: i]];
    return rval;
}

//FIXME: reconsider this
#if 0
//FIXME: Add some comments to this method
- (NSArray *) allObjects
{
    unsigned int* indexes = [fieldnames tagVectorSortedByValue];
    if ([objectCache count] < [self numberOfRowsAffected])
    {
        int expectedIndex = 0;
        TSEnumerate (currentKey, e, [keys objectEnumerator])
        {
            expectedIndex++;
            while ([currentKey intValue] > expectedIndex)
            {
                [self rowAsObject: expectedIndex];
                expectedIndex++;
            }
        }
    }
    return [objectCache objectsForKeys: keys notFoundMarker: [NSNull null]];
}
#endif

@end


@implementation PGTSResultSet (PrivateMethods)

- (PGresult *) pgresult
{
    return result;
}

+ (id) resultWithPGresult: (PGresult *) aResult connection: (PGTSConnection *) aConnection
{
	return [[[self alloc] initWithResult: aResult connection: aConnection] autorelease];
}

- (id) initWithResult: (PGresult *) aResult connection: (PGTSConnection *) aConnection;
{
	if (! (self = [super init])) return nil;
	mResult = aResult;
	mCurrentRow = -1;
	mTuples = PQntuples (result);
	mFields = PQnfields (result);
    
    fieldnames = [MKCDictionary copyDictionaryWithCapacity: fields 
                                                   keyType: kMKCCollectionTypeObject 
                                                 valueType: kMKCCollectionTypeInteger];
    for (int i = 0; i < fields; i++)
    {
        //FIXME: workaround for what seems to be a bug in libpq
        //This should be isolated and reported
        //Occures at least with the COPY command
        char* fname = PQfname (result, i);
        if (NULL == fname)
        {
            fields = i;
            break;
        }
        [fieldnames setInteger: i forKey: [NSString stringWithUTF8String: fname]];
    }
    
    determinesFieldClassesAutomatically = YES;
    rowClass = [NSMutableDictionary class];
    rowAwakenInvocation = nil;
	deserializedFields = NO;
	valueClassArray = NULL;
    
    if (YES == [connection logsQueries] && NO == [self querySucceeded])
        [self logError];
	    
	return self;
}

- (void) beginDeserialization
{
	deserializedFields = YES;
	valueClassArray = calloc (fields, sizeof (Class));
    
    if (determinesFieldClassesAutomatically)
    {
        PGTSDatabaseInfo* dbInfo = [connection databaseInfo];
        NSDictionary* deserializationDictionary = [connection deserializationDictionary];
        if (nil == deserializationDictionary)
            deserializationDictionary = [NSDictionary PGTSDeserializationDictionary];
        for (int i = 0; i < fields; i++)
        {
            PGTSTypeInfo* typeInfo = [dbInfo typeInfoForTypeWithOid: [self typeOidForFieldAtIndex: i]];
            NSString* name = [typeInfo name];
            [self setClass: [deserializationDictionary objectForKey: name] forFieldAtIndex: i];
        }
    }
}

@end
