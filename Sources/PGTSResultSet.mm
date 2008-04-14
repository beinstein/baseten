//
// PGTSResultSet.m
// BaseTen
//
// Copyright (C) 2008 Marko Karppinen & Co. LLC.
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
#import <tr1/unordered_map>
#import <PGTS/postgresql/libpq-fe.h> 
#import "PGTSConnection.h"
#import "PGTSResultSet.h"
#import "PGTSConstants.h"
#import "PGTSDatabaseInfo.h"
#import "PGTSTableInfo.h"
#import "PGTSFieldInfo.h"
#import "PGTSTypeInfo.h"
#import "PGTSFoundationObjects.h"
#import "PGTSAdditions.h"

//FIXME: enable (some of) these.
#if 0
#import <Log4Cocoa/Log4Cocoa.h>
#import "PGTSResultSetPrivate.h"
#import "PGTSResultRow.h"
#import "PGTSFunctions.h"
#endif


typedef std::tr1::unordered_map <NSString*, int, ObjectHash, ObjectCompare <NSString *> > FieldIndexMap;
typedef std::tr1::unordered_map <int, Class> FieldClassMap;


@interface PGTSConcreteResultSet : PGTSResultSet
{
    PGTSConnection* mConnection; //Weak
	PGresult* mResult;
	int mCurrentRow;
    int mFields;
    int mTuples;
    FieldIndexMap* mFieldIndices;
    FieldClassMap* mFieldClasses;
    Class mRowClass;
    
    BOOL mKnowsFieldClasses;
    BOOL mDeterminesFieldClassesFromDB;
}
+ (id) resultWithPGresult: (PGresult *) aResult connection: (PGTSConnection *) aConnection;
- (id) initWithPGResult: (PGresult *) aResult connection: (PGTSConnection *) aConnection;
@end



/** 
 * Result set for a query.
 * A result set contains rows that may be iterated by the user.
 */
@implementation PGTSConcreteResultSet

- (PGTSConnection *) connection
{
    return mConnection;
}

- (void) freeSTLTypes
{
    delete mFieldClasses;
    FieldIndexMap::iterator iterator = mFieldIndices->begin ();
    while (mFieldIndices->end () != iterator)
    {
        [iterator->first autorelease];
        iterator++;
    }
    delete mFieldIndices;
}

- (void) dealloc
{
	PQclear (mResult);
    [self freeSTLTypes];
    [mConnection release];
    [super dealloc];
}

- (void) finalize
{
	PQclear (mResult);
    [self freeSTLTypes];
    [super finalize];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<%@ (%p) cr: %d t: %d f: %d kc: %d ok: %d>",
        [self class], self, mResult, mCurrentRow, mTuples, mFields, mKnowsFieldClasses, [self querySucceeded]];
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

+ (id) resultWithPGresult: (PGresult *) aResult connection: (PGTSConnection *) aConnection
{
	return [[[self alloc] initWithPGResult: aResult connection: aConnection] autorelease];
}

- (id) initWithPGResult: (PGresult *) result connection: (PGTSConnection *) aConnection;
{
	if ((self = [super init]))
    {
        mConnection = [aConnection retain];
        
        mResult = result;
        mCurrentRow = -1;
        mTuples = PQntuples (result);
        mFields = PQnfields (result);
    
        mFieldIndices = new FieldIndexMap (mFields);
        mFieldClasses = new FieldClassMap (mFields);
        for (int i = 0; i < mFields; i++)
        {
            char* fname = PQfname (result, i);
            if (!fname)
            {
                mFields = i;
                break;
            }
            NSString* stringName = [[NSString alloc] initWithCString: fname encoding: NSUTF8StringEncoding];
            (* mFieldIndices) [stringName] = i;
        }
        mDeterminesFieldClassesFromDB = YES;
    }        
	return self;
}

- (void) setDeterminesFieldClassesAutomatically: (BOOL) aBool
{
    mDeterminesFieldClassesFromDB = aBool;
}

- (void) fetchFieldDescriptions
{
	mKnowsFieldClasses = YES;
    
    PGTSDatabaseDescription* db = [mConnection databaseDescription];
    NSDictionary* deserializationDictionary = [mConnection deserializationDictionary];
    for (int i = 0; i < mFields; i++)
    {
        PGTSTypeDescription* type = [db typeWithOid: PQftype (mResult, i)];
        NSString* name = [type name];
        [self setClass: [deserializationDictionary objectForKey: name] forFieldAtIndex: i];
    }
}

- (int) numberOfFields
{
	return mFields;
}

- (NSArray *) resultAsArray
{
    //FIXME: make this work.
#if 0
    if (NO == deserializedFields && YES == determinesFieldClassesAutomatically)
        [self fetchFieldDescriptions];
    
    NSMutableArray* rval = [NSMutableArray arrayWithCapacity: mTuples];
    for (int i = 0; i < mTuples; i++)
        [rval addObject: [self objectInRowsAtIndex: i]];
    return rval;
#endif
    return nil;
}

@end


@implementation PGTSConcreteResultSet (RowAccessors)

- (BOOL) isAtEnd
{
    return (mCurrentRow == mTuples - 1);
}

- (int) currentRow
{
    return mCurrentRow;
}

- (id) currentRowAsObject
{
    //FIXME: make this work.
    return nil;
    //return [self objectInRowsAtIndex: mCurrentRow];
}

- (void) setRowClass: (Class) aClass
{
    if ([aClass conformsToProtocol: @protocol (PGTSResultRowProtocol)])
        mRowClass = aClass;
    else
    {
        //FIXME: localize me.
        NSString* reason = @"Class %@ does not conform to protocol PGTSResultRowProtocol";
        [NSException raise: NSInvalidArgumentException 
                    format: reason, aClass];
    }
}

- (void) setValuesFromRow: (int) rowIndex target: (id) targetObject nullPlaceholder: (id) nullPlaceholder
{
    FieldIndexMap::iterator iterator = mFieldIndices->begin ();
    while (mFieldIndices->end () != iterator)
    {
        NSString* fieldname = iterator->first;
        id value = [self valueForKey: fieldname row: rowIndex];
        if (! value)
            value = nullPlaceholder;
        @try
        {
            [targetObject setValue: value forKey: fieldname];
        }
        @catch (id e)
        {
        }
        iterator++;
    }
}

/**
 * Current row with field names as keys.
 * NSNull is used in place of nil.
 */
- (NSDictionary *) currentRowAsDictionary
{
    NSMutableDictionary* retval = [NSMutableDictionary dictionaryWithCapacity: mFields];
    [self setValuesFromRow: mCurrentRow target: retval nullPlaceholder: [NSNull null]];
    return retval;
}

/** Move to the beginning of the result set */
- (void) goBeforeFirstRow
{
    [self goToRow: -1];
}

- (BOOL) goToRow: (int) aRow
{
    BOOL retval = NO;
	if (-1 <= aRow && aRow < mTuples)
	{
		mCurrentRow = aRow;
		retval = YES;
	}
	return retval;
}

- (int) count
{
	return mTuples;
}

- (unsigned long long) numberOfRowsAffectedByCommand
{
	return strtoull (PQcmdTuples (mResult), NULL, 10);
}

- (BOOL) advanceRow
{
    BOOL retval = NO;
    
    if (! mKnowsFieldClasses && mDeterminesFieldClassesFromDB)
        [self fetchFieldDescriptions];
    
    //Row numbering is zero-based.
    //The number is initially -1. 
	if (mCurrentRow < mTuples - 1)
	{
        mCurrentRow++;
		retval = YES;
	}
	return retval;
}

@end


@implementation PGTSConcreteResultSet (FieldAccessors)

/**
 * Set the class that should be used with a specific field.
 * @{
 */
- (BOOL) setClass: (Class) aClass forKey: (NSString *) aName
{
    return [self setClass: aClass forFieldAtIndex: (* mFieldIndices) [aName]];
}

- (BOOL) setClass: (Class) aClass forFieldAtIndex: (int) fieldIndex
{
    BOOL retval = NO;
    if (fieldIndex < mFields)
    {
        (* mFieldClasses) [fieldIndex] = aClass;
        retval = YES;
    }
    return retval;
}
/** @} */

- (id) valueForFieldAtIndex: (int) columnIndex row: (int) rowIndex
{
    id retval = nil;
    if (! ((columnIndex < mFields) && (rowIndex < mTuples)))
    {
        @throw [NSException exceptionWithName: kPGTSFieldNotFoundException reason: nil userInfo: nil];
    }
    
    if (! PQgetisnull (mResult, rowIndex, columnIndex))
    {
        Class objectClass = (* mFieldClasses) [columnIndex];
        if (! objectClass)
            objectClass = [NSData class];
        char* value = PQgetvalue (mResult, rowIndex, columnIndex);
        PGTSTypeDescription* type = [[mConnection databaseDescription] typeWithOid: PQftype (mResult, columnIndex)];
        retval = [objectClass newForPGTSResultSet: self withCharacters: value type: type];
    }
    return retval;
}

- (id) valueForFieldAtIndex: (int) columnIndex
{
    return [self valueForFieldAtIndex: columnIndex row: mCurrentRow];
}

- (id) valueForKey: (NSString *) aName row: (int) rowIndex
{
    FieldIndexMap::iterator iter = mFieldIndices->find (aName);
    if (mFieldIndices->end () == iter)
    {
        @throw [NSException exceptionWithName: kPGTSFieldNotFoundException reason: nil 
                                     userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                         aName, kPGTSFieldnameKey,
                                         self,  kPGTSResultSetKey,
                                         nil]];
    }
    int columnIndex = iter->second;
    return [self valueForFieldAtIndex: columnIndex row: rowIndex];
}

- (id) valueForKey: (NSString *) aName
{
    return [self valueForKey: aName row: mCurrentRow];
}

@end


@implementation PGTSResultSet
+ (id) resultWithPGresult: (PGresult *) aResult connection: (PGTSConnection *) aConnection
{
    return [[[PGTSConcreteResultSet alloc] initWithPGResult: aResult connection: aConnection] autorelease];
}
@end
