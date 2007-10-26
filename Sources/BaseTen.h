//
// BaseTen.h
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
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
#import <BaseTen/BXAttributeDescription.h>
#import <BaseTen/BXDatabaseObjectID.h>
#import <BaseTen/BXException.h>
#import <BaseTen/BXPolicyDelegate.h>
#import <BaseTen/BXRelationshipDescription.h>


/**
 * \defgroup BaseTen
 * BaseTen is a new, open source Cocoa database framework for working with PostgreSQL databases. BaseTen 
 * has been designed with familiar, Core Data -like semantics and APIs. With this 1.0 Release Candidate 
 * 2 version, a final 1.0 release is very near and it is safe to start development with the current BaseTen API.
 *
 * The BaseTen feature highlights include:
 * \li BaseTen Assistant imports Core Data / Xcode data models
 * \li Discovers the database schema automatically at runtime, including 1-1, 1-many and many-many relationships
 * \li Database changes are propagated to clients automatically, without polling
 * \li In-memory database objects are uniqued, and objects fetched via relationships are faults by default
 * \li Support for RDBMS features like database-driven data validation, multi-column primary keys and updateable views
 * \li Autocommit and manual save/rollback modes, both with NSUndoManager integration
 * \li A BaseTen-aware NSArrayController subclass automates locking and change propagation
 * \li Fetches are specified with NSPredicates (the relevant portions of which are evaluated on the database)
 *
 * BaseTen is linked to Foundation and Security frameworks and libcrypto and libssl dynamic libraries. 
 * Therefore it can be used to develop applications that don't require the graphical user interface.
 * CoreData is used only for some constants and is only needed when the framework itself is being built. 
 */

/**
 * \page postgreSQLInstallation PostgreSQL installation
 * Here's a brief tutorial on PostgreSQL installation.
 * \li Get the latest PostgreSQL source release (8.2 or later) from http://www.postgresql.org/ftp/source.
 * \li Uncompress, configure, make, [sudo] make install. No special options are required, so 
 *     \c <tt>./configure && make && sudo make install</tt> is enough.
 * \li It's usually a good idea to create a separate user and group for PostgreSQL, but Mac OS X already comes with a database-specific user: for mysql. We'll just use that and hope PostgreSQL doesn't mind.\n
 * \li Make <tt>mysql</tt> the owner of the PostgreSQL folder, then sudo to <tt>mysql</tt>:\n
 *     <tt>
 *         sudo chown -R mysql:mysql /usr/local/pgsql\n
 *         sudo -u mysql -s
 *     </tt>
 * \li Initialize the PostgreSQL database folder. We'll use en_US.UTF-8 as the default locale:\n
 *     <tt>LC_ALL=en_US.UTF-8 /usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data</tt>
 * \li Launch the PostgreSQL server itself:\n
 *     <tt>
 *        /usr/local/pgsql/bin/pg_ctl -D /usr/local/pgsql/data\n
 *         -l /usr/local/pgsql/data/pg.log start
 *     </tt>
 * \li Create a superuser account for yourself. This way, you don't have to sudo to mysql to create new databases and users.\n
 *     <tt>/usr/local/pgsql/bin/createuser <your-short-user-name></tt>
 * \li Exit the <tt>mysql</tt> sudo and create a database. If you create a database with your short user name, psql will connect to it by default.\n
 *     <tt>
 *        exit\n
 *        /usr/local/pgsql/bin/createdb <your-short-user-name>
 *     </tt>
 */
 
/**
 * \page limitations Limitations in current version
 * 
 * These are some of the most severe limitations in the current version.
 * \li Renaming tables after having them prepared for modification observing will not work.
 *     Should tables need to be renamed, first cancel modification observing, then rename the table and finally prepare it again.
 * \li Changing tables' primary keys after having them prepared for modification observing will not work. Use the method 
 *     described above.
 * \li Practically all public classes are non-thread-safe, so thread safety must be enforced externally if it's required.
 *     Furthermore, all queries should be performed from the main thread. Exceptions to this are BXDatabaseObject 
 *     and BXDatabaseObjectID the thread-safe methods of which have been documented.
 * \li NSCoding has not been implemented for BXDatabaseObject.
 * \li BaseTen is currently suitable for inserting small data sets into the database. 
 *     Insertion of larger data sets (thousands of objects) takes considerable amount of time and 
 *     may cause 'out of shared memory' errors if executed without the autocommit flag.
 *     Fetching large data sets should be fast enough.  
 * \li The query logging system is not very consistent at the moment. Mostly, however, the queries are logged with the 
 *     performing connection object's address prepended.
 * \li Automatically updating collections currently don't post KVO notifications. Instead of binding, one should subscribe to NSNotifications kBXInsertNotification, kBXUpdateNotification and kBXDeleteNotification with the entity description as the notification object.
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

