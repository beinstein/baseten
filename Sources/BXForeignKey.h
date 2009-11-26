//
// BXForeignKey.h
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
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
#import <CoreData/CoreData.h>
#import <BaseTen/BXExport.h>

@class BXEntityDescription;
@class BXDatabaseObject;
@class BXDatabaseObjectID;


@protocol BXForeignKey <NSObject>
- (NSString *) name;
- (NSDeleteRule) deleteRule;
- (NSUInteger) numberOfColumns;
- (void) iterateColumnNames: (void (*)(NSString* srcName, NSString* dstName, void* context)) callback context: (void *) context;
- (void) iterateReversedColumnNames: (void (*)(NSString* dstName, NSString* srcName, void* context)) callback context: (void *) context;
@end


BX_EXPORT NSMutableDictionary* BXFkeySrcDictionary (id <BXForeignKey> fkey, BXEntityDescription* entity, BXDatabaseObject* valuesFrom);
BX_EXPORT NSMutableDictionary* BXFkeyDstDictionary (id <BXForeignKey> fkey, BXEntityDescription* entity, BXDatabaseObject* valuesFrom);
BX_EXPORT BXDatabaseObjectID* BXFkeySrcObjectID (id <BXForeignKey> fkey, BXEntityDescription* entity, BXDatabaseObject* valuesFrom, BOOL fireFault);
BX_EXPORT BXDatabaseObjectID* BXFkeyDstObjectID (id <BXForeignKey> fkey, BXEntityDescription* entity, BXDatabaseObject* valuesFrom, BOOL fireFault);
