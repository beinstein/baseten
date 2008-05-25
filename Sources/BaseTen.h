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

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
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
 * pgts_hom_unrecognized_selector
 *
 */


/**
 * \mainpage Introduction
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
 */

/**
 * \defgroup BaseTen BaseTen
 * BaseTen is linked to Foundation and Security frameworks and libcrypto and libssl dynamic libraries. 
 * Therefore it can be used to develop applications that don't require the graphical user interface.
 * CoreData is used only for some constants and is only needed when the framework itself is being built. 
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
 * \page changeTracking Tracking database changes
 *
 * BXDatabaseObject conforms to NSKeyValueObserving and uses self-updating collections for storing 
 * related objects; changes in them may thus be tracked with KVO. 
 * 
 * BXSynchronizedArrayController's contents will be updated automatically. BXDatabaseContext's fetch 
 * methods also have the option to return a self-updating array instead of an 
 * ordinary one. In this case, KVO won't work since the object doesn't have an owner known to the context. 
 * (This will be addressed in the future.) 
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
 *     Furthermore, all queries should be performed from the main thread.
 * \li NSCoding has not been implemented for BXDatabaseObject.
 * \li BaseTen is currently suitable for inserting small data sets into the database. 
 *     Insertion of larger data sets (thousands of objects) takes considerable amount of time and 
 *     may cause 'out of shared memory' errors if executed without the autocommit flag.
 *     Fetching large data sets should be fast enough.  
 * \li The query logging system is not very consistent at the moment. Mostly, however, the queries are logged with the 
 *     performing connection object's address prepended.
 */

