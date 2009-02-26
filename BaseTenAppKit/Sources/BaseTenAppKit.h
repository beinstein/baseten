//
// BaseTenAppKit.h
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

#import <BaseTenAppKit/BXSynchronizedArrayController.h>
#import <BaseTenAppKit/BXObjectStatusToColorTransformer.h>

/**
 * \defgroup baseten_appkit BaseTenAppKit
 * BaseTenAppKit is a separate framework with AppKit bindings.
 * It contains a subclass of NSArrayController, namely 
 * BXSynchronizedArrayController, generic connection panels for use with
 * Bonjour and manually entered addresses and value transformers.
 */

/**
 * \defgroup balue_transformers Value Transformers
 * Transform database objects' status to various information.
 * BXDatabaseObject has BXDatabaseObject#statusInfo method which
 * returns a proxy for retrieving object's status. The status may
 * then be passed to NSValueTransformer subclasses. For example, 
 * an NSTableColumn's editable binding may be bound to a key path
 * like arrayController.arrangedObjects.statusInfo.some_key_name
 * and the value transformer may then be set to
 * BXObjectStatusToEditableTransformer.
 * \ingroup baseten_appkit
 */
