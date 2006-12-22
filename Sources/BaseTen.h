//
// BaseTen.h
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

#import <BaseTen/BXDatabaseContext.h>
#import <BaseTen/BXConstants.h>
#import <BaseTen/BXDatabaseObject.h>
#import <BaseTen/BXInterface.h>
#import <BaseTen/BXEntityDescription.h>
#import <BaseTen/BXPropertyDescription.h>
#import <BaseTen/BXDatabaseObjectID.h>
#import <BaseTen/BXRelationshipDescriptionProtocol.h>
#import <BaseTen/BXException.h>


/**
 * \page postgreSQLInstallation PostgreSQL installation
 * \li Get the latest PostgreSQL source release from http://www.postgresql.org/ftp/source. I used 8.2.
 * \li Uncompress postgresql and run configure script
 * \li Configure, make, [sudo] make install. No special options are required, so e.g. 
 *     \c <tt>./configure --prefix=/opt/local/postgresql</tt> is enough.
 * \li It's usually a good idea to create separate user & group for PostgreSQL. Find unused GID & UID by running:\n
 *     <tt>
 *         nireport / /users name uid\n
 *         nireport / /users name gui
 *     </tt>
 *     We'll assume that UID & GID 201 was unused.
 * \li Create PostgreSQL user & group:\n
 *     <tt>
 *         sudo niutil -create / /groups/postgres\n
 *         sudo niutil -createprop / /groups/postgres gid 201\n
 *         sudo niutil -create / /users/postgres\n
 *         sudo niutil -createprop / /users/postgres uid 201\n
 *         sudo niutil -createprop / /users/postgres gid 201\n
 *         sudo niutil -createprop / /users/postgres home /opt/local/postgresql\n
 *         sudo niutil -createprop / /users/postgres shell /bin/bash
 *     </tt>
 * \li Make data directory for PG & chown it:\n
 *     <tt>
 *         sudo mkdir /opt/local/postgresql/data\n
 *         sudo chown -R postgres:postgres /opt/local/postgresql\n
 *         su - postgres
 *     </tt>
 * \li Init PG database. We'll use UTF-8 as default encoding for the template database here, 
 *     and en_US.UTF-8 locale as default locale:
 *     <tt>/opt/local/postgresql/bin/initdb --encoding UTF-8 --locale en_US.UTF-8 -D /opt/local/postgresql/data</tt>
 * \li Launch the PG server itself (postmaster):
 *     <tt>/opt/local/postgresql/bin/postmaster -D /opt/local/postgresql/data > /opt/local/postgresql/postgresql.log 2>&1 &</tt>
 * \li Create your database.
 *     <tt>/opt/local/postgresql/bin/createdb myDB</tt>
 */
 
/**
 * \page dp1Limitations Limitations in Developer Preview 1
 * \li Renaming tables after having them prepared for modification observing will not work. Should tables need to be renamed, 
 *     first cancel modification observing, then rename the table and finally prepare it again.
 * \li Changing tables' primary keys after having them prepared for modification observing will not work. Use the method 
 *     described above.
 * \li Practically all public classes are not thread-safe, so thread safety must be enforced externally if it's required.
 *     Furthermore, all queries should be performed from the main thread. Exceptions to this are BXDatabaseObject 
 *     and BXDatabaseObjectID the thread-safe methods of which have been documented.
 * \li NSCoding has not been implemented for BXDatabaseObject.
 * \li BaseTen is currently suitable for inserting small data sets into the database. 
 *     Insertion of larger data sets (thousands of objects) takes considerable amount of time and 
 *     may cause 'out of shared memory' errors if executed without autocommit flag.
 *     Fetching large data sets should be fast enough.  
 * \li Timestamp parsing causes accuracy to be lost, if timestamp's precision is greater than 3. Workaround is to cast 
 *     timestamps to timestamp (3) using views or otherwise. This concerns timestamps with time zones as well.
 * \li The query logging system is not very consistent at the moment. Mostly, however, the queries are logged with the 
 *     performing connection object's address prepended.
 * \li Automatically updating collections currently don't post KVO notifications. Instead, one should subscribe to NSNotifications kBXInsertNotification, kBXUpdateNotification and kBXDeleteNotification with the entity description as the notification object.
 */

/**
 * \page usingAppKitClasses Using the NSController subclasses provided with the framework
 * BXDatabaseObjects may be used much in the same manner as NSManagedObjects to populate various Cocoa views. However,
 * the initial fetch needs to be performed and the controller has to assigned the result set. To facilitate this,
 * some NSController subclasses have been provided with the framework. For now, the only directly usable one is 
 * BXSynchronizedArrayController. Additionally, there is BXController and additions to NSController for creating
 * controller subclasses.
 *
 * \section BXSynchronizedArrayControllerIB Using BXSyncronizedArrayController from Interface Builder
 * <ol>
 *     <li>Load the BaseTen palette.</li>
 *     <li>Create a new nib file.</li>
 *     <li>Drag a database context and an array controller from the BaseTen palette to the file.</li>
 *     <li>Select the database context and choose Attributes from the inspector's pop-up menu.</li>
 *     <li>Enter a valid database URI. 
 *         <ul>
 *             <li>If autocommit is selected from the context settings, the changes will be propagated immediately
 *                 and Undo may not be used. Otherwise, the context's -save: and -revert: methods should be used to 
 *                 commit and rollback. Undo may be used between commits.</li>
 *             <li>If query logging is selected, all the queries will be logged to standard output.</li>
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

/**
 * \section RelationshipsIB Using relationships from Interface Builder
 * BaseTen interprets foreign keys as relationships. However, to prevent retain cycles, objects and object sets
 * fetched using a relationship <b>will not</b> be retained automatically by the context or the base objects. If a
 * relationship is accessed directly, several kinds of symptoms may be observed by the programmer. These include:
 *
 * <ul>
 *     <li>Program crashes because of EXC_BAD_ACCESS with a stack trace similar to the following:
 *
 *         <code>
 *             0   com.apple.CoreFoundation       0x907bf584 CFRetain + 60
 *
 *             1   com.apple.Foundation           0x929e7724 _NSKeyValueObservationInfoCreateByRemoving + 440
 *
 *             2   com.apple.Foundation           0x929e74fc -[NSObject(NSKeyValueObserverRegistration) _removeObserver:forProperty:] + 56
 *
 *             3   com.apple.Foundation           0x929e73ec -[NSObject(NSKeyValueObserverRegistration) removeObserver:forKeyPath:] + 436
 *
 *             4   com.apple.Foundation           0x929e733c -[NSObject(NSKeyValueObserverRegistration) removeObserver:forKeyPath:] + 260
 *
 *             etc.
 *         </code>
 *      
 *         The argument to CFRetain will be zero.
 *     </li>
 *     <li>Error messages during program execution indicating that an instance of class BXDatabaseObject is being deallocated while 
 *         key value observers are still registered with it.</li>
 * </ul>
 *
 * In order to use relationships, an NSController needs to be created for each relationship. Suppose we have a database with the following data:
 *
 * <code>
 * CREATE TABLE person (
 *     id serial NOT NULL,
 *     name text,
 *     soulmate serial NOT NULL,
 *     address integer
 * );
 *
 * CREATE TABLE person_address (
 *     id serial NOT NULL,
 *     address text
 * );
 *
 * ALTER TABLE ONLY person ADD CONSTRAINT person_pkey PRIMARY KEY (id);
 *
 * ALTER TABLE ONLY person_address ADD CONSTRAINT person_address_pkey PRIMARY KEY (id);
 *
 * ALTER TABLE ONLY person ADD CONSTRAINT person_address_fkey FOREIGN KEY (address) REFERENCES person_address(id);
 * 
 * INSERT INTO person VALUES (1, 'nzhuk', 1, 1);
 *
 * INSERT INTO person_address VALUES (1, 'Hämeentie 94');
 * </code>
 *
 * A BXSynchronizedArrayController may be used to provide the contents of the <tt>person</tt> table to an NSTableView.
 * In this example, a person only has one address. To display the address in a text field, these steps should be followed:
 *
 * <ol>
 *     <li>Drag an NSObjectController to the nib file.</li>
 *     <li>Bind the object controller's <tt>contentObject</tt> to the synchronized array controller's selection and set the 
 *         model key path to the relationship's name.</li>
 *     <li>Bind the text field to the object controller. Use <tt>address</tt> as the model key path. This way, NSObjectController
 *         takes care of the related objects.</li>
 * <ol>
 *
 */


