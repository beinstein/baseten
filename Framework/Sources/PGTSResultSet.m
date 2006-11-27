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

#if (1020 == MAC_OS_X_VERSION_MIN_REQUIRED)
    #ifdef JAGUAR_COMPATIBILITY
        #import <JaguarCompatibility/JaguarCompatibility.h>
    #else
        @interface NSObject (PGTSPrivateAdditions)
        - (void) setValue: (id) aValue forKey: (id) aKey;
        @end
    #endif
#endif

#import <stdlib.h>
#import <limits.h>
#import <PGTS/postgresql/libpq-fe.h> 
#import <TSDataTypes/TSDataTypes.h>
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


#define USE_ASSERTIONS 1


//This is somehow ifdef'd out from stdlib.h in Mac OS X 10.2.8 when using std=c99 but not in 10.4
unsigned long long
strtoull (const char * restrict nptr, char ** restrict endptr, int base);


static unsigned int _serial;

/** 
 * Result set for a query.
 * A result set contains rows that may be iterated by the user.
 */
@implementation PGTSResultSet

+ (void) initialize
{
    static BOOL tooLate = NO;
    if (!tooLate)
    {
        _serial = 0;
        tooLate = YES;
    }
}

- (PGTSConnection *) connection
{
    return connection;
}

//FIXME: check that all retained objects are released
- (void) dealloc
{
	PQclear (result);
    [fieldnames release];
	if (deserializedFields)
	{
		free (valueClassArray);
	}
    [rowAwakenInvocation release];
	[super dealloc];
}

- (ExecStatusType) status
{
	return PQresultStatus (result);
}

- (BOOL) querySucceeded
{
    ExecStatusType s = [self status];
    return (PGRES_FATAL_ERROR != s && PGRES_BAD_RESPONSE != s);
}

/** Error message returned by the database */
- (NSString *) errorMessage
{
    NSString* rval = nil;
    char* error = PQresultErrorMessage (result);
    if (NULL != error)
        rval = [NSString stringWithUTF8String: error];
	return rval;
}

/**
 * A specific field in the error message.
 * \param fieldcode Similar to PQresultErrorField
 */
- (NSString *) errorMessageField: (int) fieldcode
{
    NSString* rval = nil;
    char* error = PQresultErrorField (result, fieldcode);
    if (NULL != error)
        rval = [NSString stringWithUTF8String: error];
	return rval;
}

- (int) numberOfFields
{
	return fields;
}

- (BOOL) isAtEnd
{
    return (currentRow == tuples - 1);
}

- (BOOL) advanceRow
{
    BOOL rval = NO;
    if (NO == deserializedFields && YES == determinesFieldClassesAutomatically)
        [self beginDeserialization];
    
    //Row numbering is zero-based.
    //The number is initially -1. 
	if (currentRow < tuples - 1)
	{
        currentRow++;
		rval = YES;
	}
	return rval;
}

- (id) valueForFieldAtIndex: (int) columnIndex row: (int) rowIndex
{
    id rval = nil;
    if (! ((columnIndex < fields) && (rowIndex < tuples)))
    {
        [[NSException exceptionWithName: kPGTSFieldNotFoundException reason: nil
                               userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                   self, kPGTSResultSetKey,
                                   //FIXME: add some more information
                                   nil]]
            raise];
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
    return rval;
}

- (id) valueForFieldNamed: (NSString *) aName row: (int) rowIndex
{
    unsigned int columnIndex = [fieldnames tagForKey: aName];
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
    //FIXME: unknown key? We probably shouldn't return nil
    return [self valueForFieldNamed: aKey];
}

- (id) valueForFieldAtIndex: (int) columnIndex
{
    return [self valueForFieldAtIndex: columnIndex row: currentRow];
}

- (unsigned int) indexOfFieldNamed: (NSString *) aName
{
    return [fieldnames tagForKey: aName];
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
    return [self setClass: aClass forFieldAtIndex: [fieldnames tagForKey: aName]];
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

- (BOOL) setFieldClassesFromArray: (NSArray *) classes
{
    int count = [classes count];
    for (int i = 0; i < count; i++)
    {
        Class currentClass = [classes objectAtIndex: i];
        //FIXME: NSInvalidArgumentException might be better that an assertion
#ifdef USE_ASSERTIONS
        NSAssert ([currentClass class] == currentClass, @"Class array may contain only classes");
#endif
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
        id value = [self valueForFieldAtIndex: [fieldnames tagForKey: fieldname] row: rowIndex];
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
	result = aResult;
    connection = aConnection;
	currentRow = -1;
	tuples = PQntuples (result);
	fields = PQnfields (result);
    
    _serial++;
    serial = _serial;
    
    
    fieldnames = [TSObjectTagDictionary dictionaryWithCapacity: fields];
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
        [fieldnames setTag: i forKey: [NSString stringWithUTF8String: fname]];
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

- (void) logError
{
    fprintf (stderr, "*** Result error: %s\n", PQresultErrorMessage (result));
}

@end


@implementation PGTSResultSet (NSKeyValueCoding)

- (unsigned int) countOfRows
{
    return [self numberOfRowsAffected];
}

- (id <PGTSResultRowProtocol>) objectInRowsAtIndex: (unsigned int) index 
{
    id rval = [[[rowClass alloc] init] autorelease];

    if (rval)
    {
        //Use the custom awaken method
        [rowAwakenInvocation invokeWithTarget: rval];

        [rval PGTSSetRow: index resultSet: self];
    }
    
    //We are too simple to cache and reuse these
    return rval;
}

@end

/** Information about the database contents */
@implementation PGTSResultSet (ResultInfo)

- (PGTSTableInfo *) tableInfoForFieldNamed: (NSString *) aName
{
    return [self tableInfoForFieldAtIndex: [fieldnames tagForKey: aName]];
}

- (PGTSTableInfo *) tableInfoForFieldAtIndex: (unsigned int) fieldIndex
{
    return [[connection databaseInfo] tableInfoForTableWithOid: PQftable (result, fieldIndex)];
}

- (Oid) tableOidForFieldNamed: (NSString *) aName
{
    return [self tableOidForFieldAtIndex: [fieldnames tagForKey: aName]];
}

- (Oid) tableOidForFieldAtIndex: (unsigned int) index
{
    return PQftable (result, index);
}

- (Oid) typeOidForFieldAtIndex: (unsigned int) index
{
    return PQftype (result, index);
}

- (Oid) typeOidForFieldNamed: (NSString *) aName
{
    return [self typeOidForFieldAtIndex: [fieldnames tagForKey: aName]];
}

- (PGTSFieldInfo *) fieldInfoForFieldNamed: (NSString *) aName
{
    return [self fieldInfoForFieldAtIndex: [fieldnames tagForKey: aName]];
}

- (PGTSFieldInfo *) fieldInfoForFieldAtIndex: (unsigned int) anIndex
{
    PGTSTableInfo* tableInfo = [self tableInfoForFieldAtIndex: anIndex];
    PGTSFieldInfo* rval = [tableInfo fieldInfoForFieldAtIndex: PQftablecol (result, anIndex)];
    [rval setIndexInResultSet: anIndex];
    return rval;
}

- (NSSet *) fieldInfoForSelectedFields
{
    NSMutableSet* rval = [NSMutableSet setWithCapacity: fields];
    for (unsigned int i = 0; i < fields; i++)
        [rval addObject: [self fieldInfoForFieldAtIndex: i]];
    return rval;
}

@end
/** @} */
