//
// PGTSDataSource.m
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

#import <PGTS/PGTSDataSource.h>
#import <PGTS/PGTSTableInfo.h>
#import <PGTS/PGTSFieldInfo.h>
#import <PGTS/PGTSIndexInfo.h>
#import <PGTS/PGTSConnection.h>
#import <PGTS/PGTSFunctions.h>
#import <PGTS/PGTSConstants.h>
#import <PGTS/PGTSResultSet.h>
#import <PGTS/PGTSAdditions.h>
#import <PGTS/PGTSDataSourceTable.h>


/** Implementation of PGTSWriteDelegateProtocol */
@implementation PGTSDataSource

- (id) init
{
    if ((self = [super init]))
    {
        tables = [[NSMutableDictionary alloc] init];
        modificationPlan = NoPlan;
    }
    return self;
}

- (void) dealloc
{
    [tables release];
    [super dealloc];
}

/**
 * The result set used by the data source
 */
- (PGTSResultSet *) resultSet
{
    return resultSet;
}

/**
 * The tables edited by the data source
 */
- (NSArray *) tables
{
    return [[tables copy] autorelease];
}

/**
 * Add a table to the modifiable list
 */
- (void) addTable: (PGTSDataSourceTable *) aTable
{
    [tables setObject: aTable forKey: [aTable name]]; //FIXME: does this use the table's real name?
}

/**
 * The modification method
 */
//@{
- (enum PGTSModificationPlan) modificationPlan
{
    return modificationPlan;
}

- (void) setModificationPlan: (enum PGTSModificationPlan) aPlan
{
    modificationPlan = aPlan;
}
//@}

/**
 * Set multiple values on rows matching the given conditions with the equal operator
 * Constructs an SQL query for each of the tables present in the value dictionary
 * \param newValues An NSDictionary containing PGTSFieldInfo objects as keys and any compliant objects as values
 * \param conditionValues An NSDictionary containing PGTSFieldInfo objects as keys and any compliant objects as values
 */
- (void) setValuesFromNormalizedDictionary: (NSDictionary *) newValues rowsWithEqualCondition: (NSDictionary *) conditionValues
{
    //Sort the fields by table
    NSDictionary* values = [newValues PGTSFieldsSortedByTable];
    NSDictionary* conditions = [conditionValues PGTSFieldsSortedByTable];
    PGTSConnection* connection = [resultSet connection];
    
    TSEnumerate (table, e, [values keyEnumerator])
    {
        NSString* tableName = [table name];
        NSString* schemaName = [table schemaName];
        
        NSMutableArray* parameters = [NSMutableArray array];
        NSMutableString* queryFormat = [NSMutableString stringWithFormat: 
            @"UPDATE \"%@\".\"%@\" SET %@ WHERE (%@)", [schemaName PGTSEscapedString: connection], [tableName PGTSEscapedString: connection], 
            [[tables objectForKey: table] PGTSSetClauseParameters: parameters],
            [[conditions objectForKey: table] PGTSWhereClauseParameters: parameters]];
        
        //FIXME: this might not work at all.
        
        [connection executeQuery: queryFormat parameterArray: parameters];
        //FIXME: check the results. The user should decide, whether an exeption will be thrown on error
        //FIXME: notifications? should some nsviews be updated? asynchronous operation?
    }    
}

- (NSDictionary *) normalizedValuesForDictionary: (NSDictionary *) newValues
{
    NSMutableDictionary* normalizedValues = [NSMutableDictionary dictionary];
    TSEnumerate (currentFieldAlias, e, [newValues keyEnumerator])
    {
        PGTSFieldInfo* currentField = [resultSet fieldInfoForFieldNamed: currentFieldAlias];
        [normalizedValues setObject: [newValues objectForKey: currentFieldAlias] forKey: currentField];
    }
    return  normalizedValues;
}

- (NSDictionary *) conditionsForRow: (int) rowIndex normalizedValues: (NSDictionary *) normalizedValues
{
    NSMutableSet* handledTables = [NSMutableSet set];
    NSMutableDictionary* conditions = [NSMutableDictionary dictionary];
    
    //Associate modified field values with real field names
    //Only take into account the fields that are going to be updated
    TSEnumerate (currentField, e, [normalizedValues keyEnumerator])
    {
        PGTSTableInfo* currentTable = [currentField table];
        
        //Add the conditions if the table for this field hasn't yet been handled
        if (![handledTables containsObject: currentTable])
        {
            [handledTables addObject: currentTable];
            //If a specific exception was risen, add some additional information to the userInfo dictionary
            NS_DURING
                [conditions addEntriesFromDictionary: [self conditionsForRow: rowIndex table: currentTable]];
            NS_HANDLER
                if (NO == [kPGTSNoKeyFieldsException isEqualToString: [localException name]])
                    [localException raise];
                else
                {
                    NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithDictionary: [localException userInfo]];
                    [userInfo setObject: currentField forKey: kPGTSFieldKey];
                    [userInfo setObject: [normalizedValues objectForKey: currentField] forKey: kPGTSValueKey];
                    [[NSException exceptionWithName: kPGTSNoKeyFieldsException
                                             reason: [localException reason]
                                           userInfo: userInfo] raise];
                }
            NS_ENDHANDLER
        }
    }
    return conditions;
}

- (NSDictionary *) conditionsForRow: (int) rowIndex table: (PGTSTableInfo *) table
{
    NSMutableDictionary* conditions = [NSMutableDictionary dictionary];
    NSSet* availableFields = [resultSet fieldInfoForSelectedFields];
    NSArray* uniqueIndexes = [table uniqueIndexes];
    NSSet* useFields = nil;
    
    //Find a unique index all fields of which are selected
    TSEnumerate (currentIndex, e, [uniqueIndexes objectEnumerator])
    {
        NSSet* indexFields = [currentIndex fields];
        if ([indexFields isSubsetOfSet: availableFields])
        {
            useFields = indexFields;
            break;
        }
    }
    
    //Check our strategy here in the future
    //Only the UseCompleteUniqueKeyStrategy is available now; so raise an exception, if index fields were not found            
    if (useFields)
    {
        TSEnumerate (currentField, e, [useFields objectEnumerator])
        [conditions setObject: [resultSet valueForFieldAtIndex: [currentField indexInResultSet] row: rowIndex] 
                       forKey: currentField];
    }
    else
    {
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            resultSet,                                     kPGTSResultSetKey,
            self,                                          kPGTSDataSourceKey,
            rowIndex,                                      kPGTSRowIndexKey,
            nil];
        
        [[NSException exceptionWithName: kPGTSNoKeyFieldsException
                                 reason: NSLocalizedString (@"Could not find any key fields", @"Unable to perform update")
                               userInfo: userInfo] raise];
    }
    return conditions;
}


@end


/** The methods required by the protocol */
@implementation PGTSDataSource (PGTSWriteDelegateProtocol)

- (unsigned int) count
{
    return [resultSet countOfRows];
}

- (void) addRowToTable: (PGTSTableInfo *) table
{
    [[resultSet connection] executeQuery: @"INSERT INTO $1 DEFAULT VALUES" parameters: [table name]];
}

- (void) addRowToTable: (PGTSTableInfo *) table withValues: (NSDictionary *) insertionDict
{
    PGTSConnection* connection = [table connection];
    NSArray* keys = [insertionDict allKeys];
    NSArray* values = [insertionDict objectsForKeys: keys notFoundMarker: [NSNull null]];
    NSString* queryString = [NSString stringWithFormat: @"INSERT INTO \"%@\" (%@) VALUES (%@)",
        [[table name] PGTSEscapedString: connection], [keys PGTSFieldnames: connection], [NSString PGTSFieldAliases: [keys count]]];
    [[resultSet connection] executeQuery: queryString
                          parameterArray: values];
}

- (void) removeRowFromTable: (PGTSTableInfo *) table atIndex: (unsigned int) rowIndex
{
    [self removeRowsFromTable: table 
           withEqualCondition: [self conditionsForRow: rowIndex table: table]];
}

- (void) removeRowsFromTable: (PGTSTableInfo *) table withEqualCondition: (NSDictionary *) conditions
{
    //FIXME: this should be fixed
#if 0
    NSMutableString* queryFormat = [NSMutableString stringWithFormat: 
        @"DELETE FROM \"%@\".\"%@\" WHERE (%@)", [[table schemaName] PGTSEscapedString: connection], [[table name] PGTSEscapedString: connection], 
        [[conditions objectForKey: table] PGTSWhereClauseParameters: parameters]];        
    [connection executeQuery: queryFormat parameterArray: parameters];
#endif
}

- (void) setValue: (id) anObject forField: (NSString *) fieldname row: (unsigned int) rowIndex
{
    [self setValuesFromDictionary: [NSDictionary dictionaryWithObject: anObject forKey: fieldname]
                              row: rowIndex];
}

- (void) setValuesFromDictionary: (NSDictionary *) newValues row: (unsigned int) rowIndex
{   
    NSDictionary* normalizedValues = [self normalizedValuesForDictionary: newValues];
    [self setValuesFromNormalizedDictionary: normalizedValues
                     rowsWithEqualCondition: [self conditionsForRow: rowIndex normalizedValues: normalizedValues]];
}

- (void) setValuesFromDictionary: (NSDictionary *) newValues rowsWithEqualCondition: (NSDictionary *) conditionValues
{
    NSMutableDictionary* normalizedValues = [NSMutableDictionary dictionary];
    NSMutableDictionary* normalizedConditions = [NSMutableDictionary dictionary];
    TSEnumerate (fieldAlias, e, [newValues keyEnumerator])
        [normalizedValues setObject: [resultSet valueForFieldNamed: fieldAlias] 
                             forKey: [resultSet fieldInfoForFieldNamed: fieldAlias]];
    TSEnumerate (conditionFieldAlias, e, [conditionValues objectEnumerator])
    {
        unsigned int fieldIndex = [resultSet indexOfFieldNamed: conditionFieldAlias];
        if (NSNotFound != fieldIndex)
            [normalizedConditions setObject: [resultSet valueForFieldAtIndex: fieldIndex] 
                                     forKey: [resultSet fieldInfoForFieldNamed: conditionFieldAlias]];
        else
        {
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                conditionFieldAlias,                         kPGTSFieldnameKey,
                resultSet,                                   kPGTSResultSetKey,
                self,                                        kPGTSDataSourceKey,
                nil];
            
            [[NSException exceptionWithName: kPGTSNoKeyFieldException
                                     reason: NSLocalizedString (@"Could not find the specified key field", @"Unable to perform update")
                                   userInfo: userInfo] raise];            
        }
    }
    [self setValuesFromNormalizedDictionary: normalizedValues 
                     rowsWithEqualCondition: normalizedConditions];
}

@end