//
// PGTSWriteDelegateProtocol.h
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


@class PGTSTableInfo;

/** 
 * KVC to SQL translator.
 * Requirement for an object that processes the KVC messages received from PGTSMutableResultRow objects
 * and constructs SQL queries based on them.
 */
@protocol PGTSWriteDelegateProtocol <NSObject>

/** Count of rows currently available */
- (unsigned int) count;

/** Inserting */
//@{
- (void) addRowToTable: (PGTSTableInfo *) table;
- (void) addRowToTable: (PGTSTableInfo *) table withValues: (NSDictionary *) insertionDict;
//@}
    
/** Updating */
//@{
/** Set a single value on a given row */
- (void) setValue: (id) anObject forField: (NSString *) fieldname row: (unsigned int) rowIndex;
/**
 * Set multiple values on a given row.
 * Single SQL query is made for each table that needs to be updated
 */
- (void) setValuesFromDictionary: (NSDictionary *) aDict row: (unsigned int) rowIndex;
/**
 * Set multiple values on rows matching the given conditions with the equal operator
 * Single SQL query is made for each table that needs to be updated
 */
- (void) setValuesFromDictionary: (NSDictionary *) newValues rowsWithEqualCondition: (NSDictionary *) fieldValues;
//@}

/** Deleting */
//@{
- (void) removeRowFromTable: (PGTSTableInfo *) table atIndex: (unsigned int) rowIndex;
- (void) removeRowsFromTable: (PGTSTableInfo *) table withEqualCondition: (NSDictionary *) fieldValues;
//@}

@end