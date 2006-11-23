//
// PGTSDataSource.h
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
#import <PGTS/PGTSWriteDelegateProtocol.h>


enum PGTSModificationPlan 
{
    NoPlan = 0,
    UseCompleteUniqueKeyStrategy,
    //TODO: koodaa tämä ehkä joskus
    //UsePartialUniqueKeyStrategy,
};


@class PGTSResultSet;
@class PGTSDataSourceTable;


@interface PGTSDataSource : NSObject
{
    PGTSResultSet* resultSet;
    NSMutableDictionary* tables;
    enum PGTSModificationPlan modificationPlan;
}

- (PGTSResultSet *) resultSet;
- (void) addTable: (PGTSDataSourceTable *) aTable;

- (enum PGTSModificationPlan) modificationPlan;
- (void) setModificationPlan: (enum PGTSModificationPlan) aPlan;

- (NSDictionary *) conditionsForRow: (int) rowIndex table: (PGTSTableInfo *) table;
- (void) setValuesFromNormalizedDictionary: (NSDictionary *) newValues 
                    rowsWithEqualCondition: (NSDictionary *) conditionValues;
- (NSDictionary *) normalizedValuesForDictionary: (NSDictionary *) newValues;
- (NSDictionary *) conditionsForRow: (int) rowIndex normalizedValues: (NSDictionary *) normalizedValues;
@end


@interface PGTSDataSource (PGTSWriteDelegateProtocol) <PGTSWriteDelegateProtocol>
- (unsigned int) count;
/** Updating */
- (void) setValue: (id) anObject forField: (NSString *) fieldname row: (unsigned int) rowIndex;
- (void) setValuesFromDictionary: (NSDictionary *) newValues row: (unsigned int) rowIndex;
- (void) setValuesFromDictionary: (NSDictionary *) newValues rowsWithEqualCondition: (NSDictionary *) conditionValues;
/** Inserting */
- (void) addRowToTable: (PGTSTableInfo *) table;
- (void) addRowToTable: (PGTSTableInfo *) table withValues: (NSDictionary *) insertionDict;
/** Deleting */
- (void) removeRowFromTable: (PGTSTableInfo *) table atIndex: (unsigned int) rowIndex;
- (void) removeRowsFromTable: (PGTSTableInfo *) table withEqualCondition: (NSDictionary *) fieldValues;
@end