//
// PGTSConnectionAsyncQueries.m
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

#import "PGTSConnection.h"


@interface PGTSConnection (QueriesAsync)
- (void) sendQueryAsync: (NSString *) queryString;
- (void) sendQueryAsync: (NSString *) queryString parameterCount: (int) paramCount, ...;
- (void) sendQueryAsync: (NSString *) queryString parameterArray: (NSArray *) parameters;
- (void) prepareQueryAsync: (NSString *) queryString name: (NSString *) aName;
- (void) prepareQueryAsync: (NSString *) queryString name: (NSString *) aName parameterTypes: (Oid *) types;
- (void) sendPreparedQueryAsync: (NSString *) aName parameters: (id) p1, ...;
- (void) sendPreparedQueryAsync: (NSString *) aName parameterArray: (NSArray *) parameters;
@end


@implementation PGTSConnection (QueriesAsync)

/**
 * Send the query
 * Work in a completely nonblocking manner. The delegate is messaged if the 
 * query wasn't dispatched and when the result is available.
 */
//@{
- (void) sendQueryAsync: (NSString *) queryString
{
    if (CheckExceptionTable (self, kPGTSRaiseForAsync | kPGTSRaiseForCompletelyAsync))
        [workerProxy sendQuery2: queryString messageDelegate: YES];
}

- (void) sendQueryAsync: (NSString *) queryString parameterCount: (int) paramCount, ...
{
    NSArray* parameters = nil;
    StdargToNSArray (parameters, ParamCount (queryString), p1);
    return [self sendQueryAsync: queryString parameterArray: parameters];
}

- (void) sendQueryAsync: (NSString *) queryString parameterArray: (NSArray *) parameters
{
    if (CheckExceptionTable (self, kPGTSRaiseForAsync | kPGTSRaiseForCompletelyAsync))
        [workerProxy sendQuery2: queryString parameterArray: parameters messageDelegate: YES];
}

- (void) prepareQueryAsync: (NSString *) queryString name: (NSString *) aName parameterCount: (int) nParams
{
    [self prepareQueryAsync: queryString name: aName parameterCount: nParams types: NULL];
}

- (void) prepareQueryAsync: (NSString *) queryString name: (NSString *) aName parameterCount: (int) nParams types: (Oid *) types
{
    [workerProxy prepareQuery: queryString name: aName parameterCount: nParams types: types];
}

- (void) sendPreparedQueryAsync: (NSString *) aName parameterCount: (int) nParams, ...
{
    NSArray* parameters = nil;
    StdargToNSArray (parameters, ParamCount (queryString), p1);
    [self sendPreparedQueryAsync: aName parameterArray: parameters];
}

- (void) sendPreparedQueryAsync: (NSString *) aName parameterArray: (NSArray *) parameters
{
    if (CheckExceptionTable (self, kPGTSRaiseForAsync | kPGTSRaiseForCompletelyAsync))
        [workerProxy sendPreparedQuery2: aName parameterArray: parameters messageDelegate: YES];
}
//@}

@end
