//
// PGTSResultSet.h
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

#import <Foundation/Foundation.h>
#import <PGTS/postgresql/libpq-fe.h> 
#import <PGTS/PGTSResultRowProtocol.h>

@class PGTSConnection;
@class PGTSWriteDelegate;
@class PGTSResultRow;
@class PGTSTableInfo;
@class PGTSFieldInfo;


@interface PGTSResultSet : NSObject {
    
    @private
	PGresult* result;
    PGTSConnection* connection;
	int currentRow, fields, tuples;
    unsigned int serial;
	
    id fieldnames;
    
    BOOL determinesFieldClassesAutomatically;
    Class rowClass;
    NSInvocation* rowAwakenInvocation;
	BOOL deserializedFields;
	id** valueArray;
	Class* valueClassArray;
}

- (PGTSConnection *) connection;
- (BOOL) querySucceeded;
- (ExecStatusType) status;
- (NSString *) errorMessage;
- (NSString *) errorMessageField: (int) fieldcode;
- (int) numberOfFields;
- (BOOL) isAtEnd;
- (BOOL) advanceRow;
- (unsigned int) indexOfFieldNamed: (NSString *) aName;
- (id) valueForFieldAtIndex: (int) columnIndex;
- (id) valueForFieldAtIndex: (int) columnIndex row: (int) rowIndex;
- (id) valueForFieldNamed: (NSString *) aName;
- (id) valueForFieldNamed: (NSString *) aName row: (int) rowIndex;
- (id) valueForKey: (NSString *) aKey;
- (void) goBeforeFirstRow;
- (BOOL) goToRow: (int) aRow;
- (int) numberOfRowsAffected;
- (unsigned long long) numberOfRowsAffectedByCommand;
- (int) currentRow;
- (NSArray *) currentRowAsArray;
- (NSDictionary *) currentRowAsDictionary;
- (PGTSConnection *) connection;
@end


@interface PGTSResultSet (Serialization)
- (void) setDeterminesFieldClassesAutomatically: (BOOL) aBool;
- (BOOL) determinesFieldClassesAutomatically;
- (Class) classForFieldNamed: (NSString *) aName;
- (Class) classForFieldAtIndex: (int) fieldIndex;
- (BOOL) setClass: (Class) aClass forFieldNamed: (NSString *) aName;
- (BOOL) setClass: (Class) aClass forFieldAtIndex: (int) fieldIndex;
- (BOOL) setFieldClassesFromArray: (NSArray *) classes;

- (Class) rowClass;
- (void) setRowClass: (Class) aClass;
- (NSInvocation *) rowAwakenInvocation;
- (void) setRowAwakenInvocation: (NSInvocation *) invocation;

- (id) currentRowAsObject;
- (void) setValuesToTarget: (id) targetObject;
- (void) setValuesFromRow: (int) rowIndex target: (id) targetObject;
- (void) setValuesFromRow: (int) rowIndex target: (id) targetObject nullPlaceholder: (id) anObject;
- (NSArray *) resultAsArray;
@end


@interface PGTSResultSet (NSKeyValueCoding)
- (unsigned int) countOfRows;
- (id <PGTSResultRowProtocol>) objectInRowsAtIndex: (unsigned int) index;
@end


@interface PGTSResultSet (ResultInfo)
- (PGTSTableInfo *) tableInfoForFieldNamed: (NSString *) aName;
- (PGTSTableInfo *) tableInfoForFieldAtIndex: (unsigned int) fieldIndex;
- (Oid) tableOidForFieldNamed: (NSString *) aString;
- (Oid) tableOidForFieldAtIndex: (unsigned int) index;
- (Oid) typeOidForFieldAtIndex: (unsigned int) index;
- (Oid) typeOidForFieldNamed: (NSString *) aName;
- (PGTSFieldInfo *) fieldInfoForFieldNamed: (NSString *) aName;
- (PGTSFieldInfo *) fieldInfoForFieldAtIndex: (unsigned int) anIndex;
- (NSSet *) fieldInfoForSelectedFields;
@end
