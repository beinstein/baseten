//
// BXSynchronizedArrayControllerInspector.h
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

#import <InterfaceBuilder/InterfaceBuilder.h>


@class BXDatabaseContext;
@class BXEntityDescription;

@interface BXSynchronizedArrayControllerInspector : IBInspector 
{
    IBOutlet NSTextField* contextWarningField;
    IBOutlet NSTextField* schemaNameField;
    IBOutlet NSTextField* tableNameField;
    IBOutlet NSTextField* customClassNameField;
    IBOutlet NSButtonCell* avoidsEmptySelectionButton;
    IBOutlet NSButtonCell* preservesSelectionButton;
    IBOutlet NSButtonCell* selectsInsertedButton;
    IBOutlet NSButtonCell* multipleValuesMarkerButton;
    IBOutlet NSButtonCell* clearsFilterPredicateButton;
    IBOutlet NSButtonCell* fetchesOnAwakeButton;
    IBOutlet NSTextView* fetchPredicateTextView;
    IBOutlet NSButton* setPredicateButton;
}

- (IBAction) setPredicate: (id) sender;
- (BXDatabaseContext *) dbContext;

- (BOOL) fetchesOnAwake;
- (void) setFetchesOnAwake: (BOOL) aVal;
- (BOOL) avoidsEmptySelection;
- (void) setAvoidsEmptySelection: (BOOL) aVal;
- (BOOL) preservesSelection;
- (void) setPreservesSelection: (BOOL) aVal;
- (BOOL) selectsInsertedObjects;
- (void) setSelectsInsertedObjects: (BOOL) aVal;
- (BOOL) alwaysUsesMultipleValuesMarker;
- (void) setAlwaysUsesMultipleValuesMarker: (BOOL) aVal;
- (BOOL) clearsFilterPredicateOnInsertion;
- (void) setClearsFilterPredicateOnInsertion: (BOOL) aVal;
- (BOOL) fetchesOnAwake;
- (void) setFetchesOnAwake: (BOOL) aVal;

#if 0
- (void) assignEntityForTable: (NSString *) tableName schema: (NSString *) schemaName;
- (void) assignEntity: (BXEntityDescription *) newEntity inPlaceOf: (BXEntityDescription *) oldEntity;
#endif

@end
