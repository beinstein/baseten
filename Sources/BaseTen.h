//
// BaseTen.h
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

//FIXME: this doesn't seem to work.
#if 0 && MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
#define NSUInteger unsigned int
#define NSInteger int
#endif


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

/*
 * Helpful breakpoints:
 *
 * _log4AssertionDebug
 * bx_error_during_rollback
 * bx_error_during_clear_notification
 * bx_test_failed
 * pgts_hom_unrecognized_selector
 * BXHandleError2
 *
 */


/**
 * \defgroup BaseTen BaseTen
 * BaseTen is linked to Foundation, Security and IOKit frameworks and 
 * libcrypto, libssl and libstdc++ dynamic libraries. In addition, it is weakly linked to AppKit framework.
 * Therefore it can be used to develop applications that don't require the graphical user interface.
 */

/**
 * \defgroup Descriptions Descriptions
 * \ingroup BaseTen
 * Database introspection.
 */

/**
 * \defgroup AutoContainers Self-updating collections
 * \ingroup BaseTen
 * Collections updated by the database context.
 * The context will change the collection's contents according to its filter predicate 
 * after each relevant modification to the database. 
 */


/**
 * \mainpage Using BaseTen framework
 * \section introduction Introduction
 *
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
 *
 *
 * \section overview Overview of BaseTen
 *
 * BaseTen aims to provide a Core Data -like API for handling a database. A database connection is managed
 * by an instance of BXDatabaseContext, which also fetches rows from the database. Rows are represented
 * by instances of BXDatabaseObjects. Objects are identified by BXDatabaseObjectIDs, that are created using
 * tables' primary keys. Foreign keys are interpreted as relationships between objects.
 *
 * Like some other object-relational mappers, BaseTen fetches the data model from the database. 
 * There are classes available for database introspection: BXEntityDescription, BXAttributeDescription, 
 * BXRelationshipDescription and its subclasses. Currently, the database contents aren't validated 
 * against a developer-supplied data model. 
 *
 * Database objects are retrieved using an instance of BXDatabaseContext. The rows are specified using 
 * instances of BXEntityDescription and NSPredicate. This pattern should match most use cases. It is also
 * possible to fetch rows as NSDictionaries by specifying an SQL query.
 *
 * Unlike in the typical use case of Core Data, multiple users might be connected to the database being 
 * accessed using BaseTen. Thus, data manipulated with database objects could change at any time. BaseTen
 * copes with this situation by updating objects' contents as soon as other database clients commit their
 * changes.
 *
 * Instead of constantly polling the database for changes, BaseTen listes for PostgreSQL notifications.
 * It then queries the database about the notification type and faults the relevant objects. For this to
 * work, certain tables, views and functions need to be created in the database. The easiest way to do this
 * is to connect to the database with BaseTen Assistant. Using it, relations may be enabled for use with 
 * the framework. Everything will be installed or will reference to a database schema called baseten, so
 * removal, if needed, will be an easy process. BaseTen can connect to databases without the schema, but
 * in this case functionality will be limited.
 *
 * Since BaseTen relies on database introspection, SQL may be used to define the database schema.
 * Another option is to create a data model using Xcode's data modeler and import it using BaseTen Assistant.
 * Currently, migration models aren't understood by the assistant, though, so the easiest way to do model
 * migration might be using SQL.
 *
 *
 * \subsection sqlViews SQL views
 *
 * Contents of SQL views may be manipulated using database objects provided that some conditions are met.
 * Unlike tables, views don't have primary keys but BaseTen still needs to be able to reference individual 
 * rows. If a view has a group of columns that can act as a primary key, the columns may be marked as a 
 * primary key with the assistant, after which the view may be enabled.
 *
 * Views also lack foreign keys. Despite of this entities that correspond to views may have relationships
 * provided that a certain condition is met: the view needs to have the column or columns of an underlying
 * table that form a foreign key, and the columns' names need to match. In this case, relationships will 
 * be created between the view and the target table as well as the view and all the views that are based
 * on the target table and contain the columns the foreign key references to. This applies to the complete
 * view hierarchy.
 *
 * PostgreSQL allows INSERT and UPDATE queries to target views if rules have been created to handle them.
 * In this case, the view contents may be modified also by using BaseTen.
 *
 *
 *
 * \section gettingStarted Getting started
 * FIXME: write me.
 *
 *
 *
 * \section changeTracking Tracking database changes
 *
 * BXDatabaseObject conforms to NSKeyValueObserving and uses self-updating collections for storing 
 * related objects; changes in them may thus be tracked with KVO. 
 * 
 * BXSynchronizedArrayController's contents will be updated automatically. BXDatabaseContext's fetch 
 * methods also have the option to return a self-updating array instead of an 
 * ordinary one. In this case, the collection's owner has to be specified for KVO notifications to be posted.
 * See the collection classes' documentation for details.
 *
 * Another, a more low-level means of tracking changes is observing NSNotifications. Notifications on 
 * entity changes will be posted to the relevant context's notification center. The notification object
 * will be a BXEntityDescription which corresponds to the table where the change happened. The names 
 * of the notifications are:
 * \li \c kBXInsertNotification on database \c INSERT
 * \li \c kBXUpdateNotification on database \c UPDATE
 * \li \c kBXDeleteNotification on database \c DELETE
 *
 * At the time the notifications are posted, database objects and self-updating collections will 
 * already have been updated.
 *
 *
 *
 * \section usingAppKitClasses Using the controller subclasses provided with the framework
 *
 * BXDatabaseObjects may be used much in the same manner as NSManagedObjects to populate various Cocoa views. However,
 * the initial fetch needs to be performed and the controller has to assigned the result set. To facilitate this,
 * some NSController subclasses have been provided with the framework. For now, the only directly usable one is 
 * BXSynchronizedArrayController. Additionally, there is BXController and additions to NSController for creating
 * controller subclasses.
 *
 *
 * \subsection BXSynchronizedArrayControllerIB Using BXSyncronizedArrayController from Interface Builder
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
 *
 *
 *
 * \section postgreSQLInstallation PostgreSQL installation
 *
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
 *
 *
 *
 * \section limitations Limitations in current version
 * 
 * These are some of the most severe limitations in the current version.
 * \li Renaming tables after having them prepared for modification observing will not work.
 *     Should tables need to be renamed, first cancel modification observing, then rename the table and finally prepare it again.
 * \li Changing tables' primary keys after having them prepared for modification observing will not work. Use the method 
 *     described above.
 * \li Practically all public classes are non-thread-safe, so thread safety must be enforced externally if it's required.
 *     Furthermore, all queries must be performed from the thread in which the context made a database connection. This could change
 *     in the future, so it is best to create and handle a context only in one thread.
 * \li NSCoding has not been implemented for BXDatabaseObject.
 * \li BaseTen is currently suitable for inserting small data sets into the database. 
 *     Insertion of larger data sets (thousands of objects) takes considerable amount of time and 
 *     may cause 'out of shared memory' errors if executed without the autocommit flag.
 *     Fetching large data sets should be fast enough.  
 */
