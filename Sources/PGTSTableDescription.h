//
// PGTSTableDescription.h
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
#import <PGTS/PGTSAbstractClassDescription.h>


@class PGTSFieldDescription;
@class PGTSDatabaseDescription;
@class PGTSIndexDescription;
@class PGTSResultSet;


@protocol PGTSTableDescription
- (NSArray *) uniqueIndexes;
- (PGTSIndexDescription *) primaryKey;
- (PGTSFieldDescription *) fieldAtIndex: (int) anIndex;
- (NSDictionary *) fields;
- (NSSet *) foreignKeys;
- (NSSet *) referencingForeignKeys;
@end


@interface PGTSTableDescriptionProxy : PGTSAbstractClassDescriptionProxy <PGTSTableDescription>
{
	NSMutableDictionary* mFields;
    NSMutableArray* mUniqueIndexes;
    NSMutableSet* mForeignKeys;
    NSMutableSet* mReferencingForeignKeys;
    NSArray* mRelationOidsBasedOn;
}
@end


@interface PGTSTableDescription : PGTSAbstractClassDescription <PGTSTableDescription>
{
    NSMutableDictionary* mFields;
	NSMutableDictionary* mFieldIndexes;
    NSArray* mUniqueIndexes;
    NSMutableSet* mForeignKeys;
    NSMutableSet* mReferencingForeignKeys;
    NSArray* mRelationOidsBasedOn;

    BOOL mHasForeignKeys;
    BOOL mHasReferencingForeignKeys;
}

- (void) setUniqueIndexes: (NSArray *) anArray;

- (NSSet *) foreignKeySetWithResult: (PGTSResultSet *) res selfAsSource: (BOOL) selfAsSource;
- (NSArray *) relationOidsBasedOn;
@end
