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
#import <BaseTen/postgresql/libpq-fe.h>


@interface PGTSResultSet : NSObject
{
}
+ (id) resultWithPGresult: (const PGresult *) aResult connection: (PGTSConnection *) aConnection;
+ (NSError *) errorForPGresult: (const PGresult *) result;
@end


@interface PGTSResultSet (Implementation)
- (id) initWithPGResult: (const PGresult *) aResult connection: (PGTSConnection *) aConnection;
- (PGTSConnection *) connection;
- (BOOL) querySucceeded;
- (ExecStatusType) status;
- (BOOL) advanceRow;
- (id) valueForFieldAtIndex: (int) columnIndex row: (int) rowIndex;
- (id) valueForFieldAtIndex: (int) columnIndex;
- (id) valueForKey: (NSString *) aName row: (int) rowIndex;
- (BOOL) setClass: (Class) aClass forKey: (NSString *) aName;
- (BOOL) setClass: (Class) aClass forFieldAtIndex: (int) fieldIndex;
- (PGresult *) PGresult;
- (NSArray *) resultAsArray;

- (BOOL) isAtEnd;
- (int) currentRow;
- (id) currentRowAsObject;
- (void) setRowClass: (Class) aClass;
- (void) setValuesFromRow: (int) rowIndex target: (id) targetObject nullPlaceholder: (id) nullPlaceholder;
- (NSDictionary *) currentRowAsDictionary;
- (void) goBeforeFirstRow;
- (BOOL) goToRow: (int) aRow;
- (int) count;
- (unsigned long long) numberOfRowsAffectedByCommand;
- (BOOL) advanceRow;
- (int) identifier;
- (void) setIdentifier: (int) anIdentifier;
- (NSError *) error;
- (NSString *) errorString;
- (void) setUserInfo: (id) userInfo;
- (id) userInfo;

- (void) setDeterminesFieldClassesAutomatically: (BOOL) aBool;
@end


@protocol PGTSResultRowProtocol <NSObject>
/** Called when a new result set and row index are associated with the target */
- (void) PGTSSetRow: (int) row resultSet: (PGTSResultSet *) res;
@end
