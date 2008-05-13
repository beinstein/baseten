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
#import <BaseTenAppKit/BXConnectionPanel.h>
#import <BaseTenAppKit/BXAuthenticationPanel.h>

/**
 * \defgroup BaseTenAppKit BaseTenAppKit
 * BaseTenAppKit is a separate framework with AppKit bindings.
 * Its contains a subclass of NSArrayController, namely 
 * BXArrayController, generic connection panels for use with
 * Bonjour and manually entered addresses and value transformers.
 */

/**
 * \defgroup ValueTransformers Value Transformers
 * Transform database objects' status to various information.
 * BXDatabaseObject has BXDatabaseObject#statusInfo method which
 * returns a proxy for retrieving object's status. The status may
 * then be passed to NSValueTransformer subclasses. For example, 
 * an NSTableColumn's editable binding may be bound to a key path
 * like arrayController.arrangedObjects.statusInfo.some_key_name
 * and the value transformer may then be set to
 * BXObjectStatusToEditableTransformer.
 * \ingroup BaseTenAppKit
 */

/**
 * \page usingAppKitClasses Using the controller subclasses provided with the framework
 * BXDatabaseObjects may be used much in the same manner as NSManagedObjects to populate various Cocoa views. However,
 * the initial fetch needs to be performed and the controller has to assigned the result set. To facilitate this,
 * some NSController subclasses have been provided with the framework. For now, the only directly usable one is 
 * BXSynchronizedArrayController. Additionally, there is BXController and additions to NSController for creating
 * controller subclasses.
 *
 * \section BXSynchronizedArrayControllerIB Using BXSyncronizedArrayController from Interface Builder
 * <ol>
 *     <li>Load the BaseTen plug-in or palette.</li>
 *     <li>Create a new nib file.</li>
 *     <li>Drag a database context and an array controller from the BaseTen palette to the file.</li>
 *     <li>Select the database context and choose Attributes from the inspector's pop-up menu.</li>
 *     <li>Enter a valid database URI. 
 *         <ul>
 *             <li>If autocommit is selected from the context settings, the changes will be propagated immediately and
 *                 undo affects most operations but not all. Otherwise, the context's -save: and -revert: methods 
 *                 should be used to commit and rollback. Undo may be used between commits.</li>
 *             <li>If query logging is enabled, all queries will be logged to standard output.</li>
 *         </ul>
 *     </li>
 *     <li>Select the array controller and choose Attributes from the inspector's pop-up menu.</li>
 *     <li>Enter a table name into the field.
 *         <ul>
 *             <li>The schema field may be left empty, in which case <tt>public</tt> will be used.</li>
 *             <li>Please note that the table needs to be enabled for change observing. This can be 
 *                 done using the Setup Application.</li>
 *         </ul>
 *     </li>
 *     <li>Bind the Cocoa views to the controller.</li> 
 *     <li>Test the interface. The views should be populated using the database.</li>
 * </ol>
 */ 
