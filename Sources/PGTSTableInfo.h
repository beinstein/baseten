//
// PGTSTableInfo.h
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
#import <PGTS/PGTSAbstractClassInfo.h>


@class PGTSFieldInfo;
@class PGTSDatabaseInfo;
@class PGTSIndexInfo;
@class PGTSResultSet;


@interface PGTSTableInfo : PGTSAbstractClassInfo 
{
    unsigned int fieldCount;
    id fields;
    NSArray* uniqueIndexes;
    PGTSDatabaseInfo* database;

    BOOL hasForeignKeys;
    NSMutableSet* foreignKeys;
    BOOL hasReferencingForeignKeys;
    NSMutableSet* referencingForeignKeys;

    NSArray* relationOidsBasedOn;
}

- (void) setDatabase: (PGTSDatabaseInfo *) aDatabase;
- (PGTSDatabaseInfo *) database;
- (void) setUniqueIndexes: (NSArray *) anArray;
- (void) setFieldCount: (unsigned int) anInt;
- (void) setRelationOidsBasedOn: (NSArray *) anArray;

- (NSSet *) foreignKeySetWithResult: (PGTSResultSet *) res selfAsSource: (BOOL) selfAsSource;
@end

@interface PGTSTableInfo (Queries)
- (NSArray *) uniqueIndexes;
- (PGTSIndexInfo *) primaryKey;
- (PGTSFieldInfo *) fieldInfoForFieldAtIndex: (unsigned int) anIndex;
- (PGTSFieldInfo *) fieldInfoForFieldNamed: (NSString *) aName;
- (NSArray *) allFields;
- (NSSet *) foreignKeys;
- (NSSet *) referencingForeignKeys;
- (NSArray *) relationOidsBasedOn;
@end
