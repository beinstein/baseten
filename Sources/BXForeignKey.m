//
// BXForeignKey.m
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

#import "BXForeignKey.h"
#import "BXLogger.h"
#import "BXAttributeDescription.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXDatabaseObject.h"


struct srcdst_dictionary_st
{
	__strong NSMutableDictionary* sd_target;
	__strong id sd_object;
	__strong NSDictionary* sd_attributes_by_name;
};


static void
SrcDstDictionary (NSString* attributeName, NSString* objectKey, void* ctx)
{
	struct srcdst_dictionary_st* sd = (struct srcdst_dictionary_st *) ctx;
	
	NSDictionary* attrs = sd->sd_attributes_by_name;
	id object = sd->sd_object;
	BXAttributeDescription* attr = [attrs objectForKey: attributeName];
	[sd->sd_target setObject: (object ? [object primitiveValueForKey: objectKey] : [NSNull null]) forKey: attr];
}


NSMutableDictionary* 
BXFkeySrcDictionary (id <BXForeignKey> fkey, BXEntityDescription* entity, BXDatabaseObject* valuesFrom)
{
	ExpectC (fkey);
	ExpectC (entity);
	
	NSMutableDictionary* retval = [NSMutableDictionary dictionaryWithCapacity: [fkey numberOfColumns]];
	NSDictionary* attributes = [entity attributesByName];
	struct srcdst_dictionary_st ctx = {retval, valuesFrom, attributes};
	[fkey iterateColumnNames: &SrcDstDictionary context: &ctx];
	return retval;	
}


NSMutableDictionary* 
BXFkeyDstDictionaryUsing (id <BXForeignKey> fkey, BXEntityDescription* entity, BXDatabaseObject* valuesFrom)
{
	ExpectC (fkey);
	ExpectC (entity);
	
	NSMutableDictionary* retval = [NSMutableDictionary dictionaryWithCapacity: [fkey numberOfColumns]];
	NSDictionary* attributes = [entity attributesByName];
	struct srcdst_dictionary_st ctx = {retval, valuesFrom, attributes};
	[fkey iterateReversedColumnNames: &SrcDstDictionary context: &ctx];
	return retval;
}


struct object_ids_st
{
	__strong NSMutableDictionary* oi_values;
	__strong id oi_object;
	BOOL oi_fire_fault;
};

static void
ObjectIDs (NSString* name, NSString* objectKey, void* ctx)
{
	struct object_ids_st* os = (struct object_ids_st *) ctx;
	if (os->oi_values)
	{
		id value = nil;
		if (os->oi_fire_fault)
			value = [os->oi_object primitiveValueForKey: objectKey];
		else
		{
			value = [os->oi_object cachedValueForKey: objectKey];
			if ([NSNull null] == value)
				value = nil;
		}

		if (value)
			[os->oi_values setObject: value forKey: name];
		else
			os->oi_values = nil;
	}
}

BXDatabaseObjectID*
BXFkeySrcObjectID (id <BXForeignKey> fkey, BXEntityDescription* entity, BXDatabaseObject* valuesFrom, BOOL fireFault)
{
	NSMutableDictionary* values = [NSMutableDictionary dictionaryWithCapacity: [fkey numberOfColumns]];
	struct object_ids_st ctx = {values, valuesFrom, fireFault};
	[fkey iterateColumnNames: &ObjectIDs context: &ctx];

	BXDatabaseObjectID* retval = nil;
	if (ctx.oi_values)
		retval = [BXDatabaseObjectID IDWithEntity: entity primaryKeyFields: values];
	return retval;
}

BXDatabaseObjectID*
BXFkeyDstObjectID (id <BXForeignKey> fkey, BXEntityDescription* entity, BXDatabaseObject* valuesFrom, BOOL fireFault)
{
	NSMutableDictionary* values = [NSMutableDictionary dictionaryWithCapacity: [fkey numberOfColumns]];
	struct object_ids_st ctx = {values, valuesFrom, fireFault};
	[fkey iterateReversedColumnNames: &ObjectIDs context: &ctx];
	
	BXDatabaseObjectID* retval = nil;
	if (ctx.oi_values)
		retval = [BXDatabaseObjectID IDWithEntity: entity primaryKeyFields: values];
	return retval;
}
