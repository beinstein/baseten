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


#import <BaseTen/BXConstants.h>
#import <BaseTen/BXDatabaseContext.h>
#import <BaseTen/BXDatabaseContextDelegateProtocol.h>
#import <BaseTen/BXDatabaseObject.h>
#import <BaseTen/BXDatabaseObjectID.h>
#import <BaseTen/BXEntityDescription.h>
#import <BaseTen/BXAttributeDescription.h>
#import <BaseTen/BXRelationshipDescription.h>
#import <BaseTen/BXException.h>

/*
 * Helpful breakpoints:
 *
 * BXHandleError2
 * BXAssertionDebug
 * bx_error_during_rollback
 * bx_error_during_clear_notification
 * bx_test_failed
 * pgts_unrecognized_selector
 *
 */

/**
 * \defgroup baseten BaseTen
 * BaseTen is linked to Foundation, CoreData, Security, IOKit and SystemConfiguration frameworks and 
 * libcrypto, libssl and libstdc++ dynamic libraries. In addition, it is weakly linked to AppKit framework.
 * Therefore it can be used to develop applications that don't require the graphical user interface.
 */

/**
 * \defgroup descriptions Descriptions
 * \ingroup baseten
 * Database introspection.
 */

/**
 * \defgroup auto_containers Self-updating collections
 * \ingroup baseten
 * Collections updated by the database context.
 * The context will change the collection's contents according to its filter predicate 
 * after each relevant modification to the database. 
 */

/**
 * \mainpage Introduction
 *
 * BaseTen is an open source Cocoa database framework for working with PostgreSQL databases. BaseTen 
 * has been designed with familiar, Core Data -like semantics and APIs. 
 *
 * The BaseTen feature highlights include:
 * \li BaseTen Assistant imports Core Data / Xcode data models.
 * \li Discovers the database schema automatically at runtime, including 1-1, 1-many and many-many relationships.
 * \li Database changes are propagated to clients automatically, without polling.
 * \li In-memory database objects are uniqued, and objects fetched via relationships are faults by default.
 * \li Support for RDBMS features like database-driven data validation, multi-column primary keys and updateable views.
 * \li Autocommit and manual save/rollback modes, both with NSUndoManager integration.
 * \li A BaseTen-aware NSArrayController subclass automates locking and change propagation.
 * \li Fetches are specified with NSPredicates (the relevant portions of which are evaluated on the database).
 * 
 * \sa \ref general_usage
 */

/**
 * \page general_usage Using BaseTen framework
 *
 * \li \subpage overview
 * \li \subpage accessing_values
 * \li \subpage getting_started
 * \li \subpage tracking_changes
 * \li \subpage using_appkit_classes
 * \li \subpage database_types
 * \li \subpage postgresql_installation
 * \li \subpage building_baseten
 * \li \subpage limitations
 */ 

/**
 * \page overview Overview of BaseTen
 *
 * \image html BaseTen-object-relationships.png "Relationships between BaseTen's objects"
 * \image html BaseTen-class-hierarchy.png "BaseTen class hierarchy"
 * \image latex BaseTen-object-relationships.pdf "Relationships between BaseTen's objects" width=\textwidth
 * \image latex BaseTen-class-hierarchy.pdf "BaseTen class hierarchy" width=\textwidth 
 *
 * BaseTen aims to provide a Core Data -like API for handling a database. A database connection is managed
 * by an instance of BXDatabaseContext, which also fetches rows from the database. Rows are represented
 * by instances of BXDatabaseObject. Objects are identified by 
 * \link BXDatabaseObjectID BXDatabaseObjectIDs\endlink, that are created using
 * tables' primary keys. Foreign keys are interpreted as relationships between objects.
 *
 * Like some other object-relational mappers, BaseTen fetches the data model from the database. 
 * There are classes available for database introspection: BXEntityDescription, BXAttributeDescription, 
 * BXRelationshipDescription and its subclasses.
 *
 * Database objects are retrieved using an instance of BXDatabaseContext. The rows are specified using 
 * instances of BXEntityDescription and NSPredicate. This pattern should match most use cases. It is also
 * possible to fetch rows as NSDictionaries by specifying an SQL query.
 *
 * Unlike the typical use case of Core Data, multiple users might be connected to the database being 
 * accessed using BaseTen. Thus, data manipulated with database objects could change at any time. BaseTen
 * copes with this situation by updating objects' contents as soon as other database clients commit their
 * changes. The other clients needn't use BaseTen.
 *
 * Instead of constantly polling the database for changes, BaseTen listens for PostgreSQL notifications.
 * It then queries the database about the notification type and faults the relevant objects. For this to
 * work, certain tables, views and functions need to be created in the database. The easiest way to do this
 * is to connect to the database with BaseTen Assistant. Using it, relations may be enabled for use with 
 * the framework. Everything will be installed or will reference to a database schema called baseten, so
 * removal, if needed, will be an easy process. BaseTen can connect to databases without the schema, but
 * in this case functionality will be limited.
 *
 * Since BaseTen relies on database introspection, SQL may be used to define the database schema.
 * Another option is to create a data model using Xcode's data modeler and import it using BaseTen Assistant.
 *
 * \see \subpage predicates
 * \see \subpage sql_views
 * \see \subpage baseten_enabling
 */

/**
 * \page predicates Predicates
 *
 * Most types of predicates and expressions are converted to SQL and sent to the database server.
 * Others cause the returned object set to be filtered again on the client side. Specifically, the following
 * use cases work in this manner: The affected part of the predicate is replaced with \em true (or \em false, 
 * if the part is inside an odd number of NOT predicates), and excess objects are removed from the result set 
 * after it has been received.
 *
 * <ul>
 *     <li>Use of NSDiacriticInsensitivePredicateOption</li>
 *     <li>Use of NSCustomSelectorPredicateOperatorType</li>
 *     <li>Use of NSSubqueryExpressionType</li>
 *     <li>Use of NSUnionSetExpressionType</li>
 *     <li>Use of NSIntersectSetExpressionType</li>
 *     <li>Use of NSMinusSetExpressionType</li>
 *     <li>A modifier other than NSDirectPredicateModifier in combination with any of the following:
 *         <ul>
 *             <li>NSBeginsWithPredicateOperatorType</li>
 *             <li>NSEndsWithPredicateOperatorType</li>
 *             <li>NSMatchesPredicateOperatorType</li>
 *             <li>NSLikePredicateOperatorType</li>
 *             <li>NSContainsPredicateOperatorType</li>
 *             <li>NSInPredicateOperatorType</li>
 *         </ul>
 *     </li>
 * </ul>
 */

/**
 * \page sql_views SQL views
 *
 * Contents of SQL views may be manipulated using database objects provided that some conditions are met.
 * Unlike tables, views don't have primary keys but BaseTen still needs to be able to reference individual 
 * rows. If a view has a group of columns that can act as a primary key, the columns may be marked as a 
 * primary key with the assistant, after which the view may be enabled.
 *
 * Views also lack foreign keys. Despite this entities that correspond to views may have relationships
 * provided that a certain condition is met: the view needs to have the column or columns of an underlying
 * table that form a foreign key, and the columns' names need to match. In this case, relationships will 
 * be created between the view and the target table as well as the view and all the views that are based
 * on the target table and contain the columns the foreign key references to. This applies to the complete
 * view hierarchy.
 *
 * PostgreSQL allows INSERT and UPDATE queries to target views if rules have been created to handle them.
 * In this case, the view contents may be modified also with BaseTen.
 */

/**
 * \page baseten_enabling More detail on enabling relations
 *
 * Some tables are created in BaseTen schema to track changes in other relations. The association is based
 * on relation \em oids \ref baseten_enabling_ref_1 "¹". The BaseTen tables store values for the actual 
 * relations' primary keys. Thus, changing tables' primary keys after having them enabled will not work. 
 * Should this need to be done, first disable the relation, then alter the primary key and finally enable 
 * the relation again. Renaming or otherwise altering relations should be possible, though.
 *
 * In addition to using BaseTen Assistant, it is possible to enable and disable tables with SQL functions.
 * The functions are <em>baseten.enable</em> and <em>baseten.disable</em> and they take an \em oid as an argument.
 *
 * Views' primary keys are stored in <em>baseten.view_pkey</em>. The table has three columns: \em nspname, 
 * \em relname and \em attname, which correspond to the view's schema name, the view's name and each primary 
 * key column's name respectively. They also make up the table's primary key. In addition to using 
 * BaseTen Assistant, it is possible to determine a view's primary key by inserting rows into the table.
 *
 * Relationships and view hierarchies among other things are stored in automatically-generated tables. 
 * These should be refreshed with the SQL function <em>baseten.refresh_caches</em> after all changes to views,
 * primary keys and foreign keys. BaseTen Assistant does this automatically.
 *
 * <ol>
 *     <li>\anchor baseten_enabling_ref_1 PostgreSQL assigns an \em oid to each relation. This does not imply that tables should be created WITH OIDS.</li>
 * </ol>
 */

/**
 * \page getting_started Getting started
 *
 * Typically accessing a database consists roughly of the following steps:
 * <ul>
 *     <li>\subpage creating_a_database_context "Creating an instance of BXDatabaseContext"</li>
 *     <li>\subpage connecting_to_a_database "Connecting to a database"</li>
 *     <li>\subpage getting_an_entity_and_a_predicate "Getting an entity description from the context and possibly creating an NSPredicate for reducing the number of fetched objects"</li>
 *     <li>\subpage performing_a_fetch "Performing a fetch using the entity and the predicate"</li>
 *     <li>\subpage handling_the_results "Handling the results"</li>
 * </ul>
 * Here is a small walkthrough with sample code.
 *
 * \latexonly
 * \lstset{language=[Objective]C, backgroundcolor=\color[rgb]{0.84,0.87,0.90}, rulecolor=\color[gray]{0.53}}
 * \begin{lstlisting}[fontadjust, columns=fullflexible, float=h, frame=single, caption=A simple command line tool that uses BaseTen]
 * #import <Foundation/Foundation.h>
 * #import <BaseTen/BaseTen.h>
 *
 * int main (int argc, char** argv)
 * {
 *     NSURL* databaseURI = [NSURL URLWithString: @"pgsql://username@localhost/database"];
 *     BXDatabaseContext* ctx = [[BXDatabaseContext alloc] initWithDatabaseURI: databaseURI];
 * 
 *     [ctx connectSync: NULL];
 *     BXEntityDescription* entity = [ctx entityForTable: @"table" error: NULL];
 *     NSArray* result = [ctx executeFetchForEntity: entity withPredicate: nil error: NULL];
 *
 *     for (BXDatabaseObject* object in result)
 *     {
 *         NSLog (@"Object ID: %@ column: %@", 
 *                [[object objectID] URIRepresentation], [object valueForKey: @"column"]);
 *     }
 *
 *     return 0;
 * }
 * \end{lstlisting} 
 * \endlatexonly
 * \htmlonly
 * <code> #import &lt;Foundation/Foundation.h&gt;
 * #import &lt;BaseTen/BaseTen.h&gt;
 *
 * int main (int argc, char** argv)
 * {
 *     NSURL* databaseURI = [NSURL URLWithString: @"pgsql://username@localhost/database"];
 *     BXDatabaseContext* ctx = [[BXDatabaseContext alloc] initWithDatabaseURI: databaseURI];
 * 
 *     [ctx connectSync: NULL];
 *     BXEntityDescription* entity = [ctx entityForTable: @"table" error: NULL];
 *     NSArray* result = [ctx executeFetchForEntity: entity withPredicate: nil error: NULL];
 *
 *     for (BXDatabaseObject* object in result)
 *     {
 *         NSLog (@"Object ID: %@ column: %@", 
 *                [[object objectID] URIRepresentation], [object valueForKey: @"column"]);
 *     }
 *
 *     return 0;
 * }</code>
 * \endhtmlonly
 */
 
/**
 * \page creating_a_database_context Creating a database context
 *
 * The designated initializer of BXDatabaseContext is 
 * \ref BXDatabaseContext::initWithDatabaseURI: "-initWithDatabaseURI:". \ref BXDatabaseContext::init "-init" 
 * is also available but the context does require an URI before connecting.
 *
 * BXDatabaseContext requires the URI to be formatted as follows:
 * <tt>pgsql://username:password\@host/database_name</tt>. Currently, as PostgreSQL is the only supported 
 * database, only <tt>pgsql://</tt> URIs are allowed. All parameters are required except for the password,
 * the need for which depends on the database configuration.
 *
 * Various methods in BXDatabaseContext take a double pointer to an NSError object as a parameter. if the 
 * called method fails, the NSError will be set on return. If the parameter is NULL, the default error
 * handler raises a BXException. BXDatabaseContext's delegate may change this behaviour.
 */

/**
 * \page connecting_to_a_database Connecting to a database
 *
 * \latexonly 
 * \begin{lstlisting}[fontadjust, columns=fullflexible, float=h, frame=single, title=Connecting to a database]
 * [ctx connectSync: NULL];
 * \end{lstlisting}
 * \endlatexonly
 * \htmlonly
 * <code>[ctx connectSync: NULL];</code>
 * \endhtmlonly
 *
 *
 * Connection to the database may be made synchronously using the method
 * \ref BXDatabaseContext::connectSync: "-connectSync". Applications that use an NSRunLoop also have the
 * option to use \ref BXDatabaseContext::connectAsync "-connectAsync". The method returns immediately. 
 * When the connection attempt has finished, the context's delegate will be called and notifications will
 * be posted to the context's notification center (accessed with 
 * \ref BXDatabaseContext::notificationCenter "-notificationCenter").
 *
 * In AppKit applications, the easiest way to connect to the database is to use the IBAction
 * \ref BXDatabaseContext::connect: "-connect:". In addition to attempting the connection asynchronously,
 * it also presents a number of panels to the user, if some required information is missing from the URI. 
 * The panels allow the user to specify their username, password and the database host making URIs
 * like <tt>pgsql:///database_name</tt> allowed. Additionally a \em kBXConnectionSetupAlertDidEndNotification
 * will be posted when the user dismisses an alert panel, which is presented on failure.
 *
 * Since \em NULL is passed in place of an NSError double pointer, a BXException will be thrown on error.
 * See BXDatabaseContext's documentation for details on error handling.
 */

/** 
 * \page getting_an_entity_and_a_predicate Getting a BXEntityDescription and an NSPredicate
 *
 * \latexonly
 * \begin{lstlisting}[fontadjust, columns=fullflexible, float=h, frame=single, title=Getting a BXEntityDescription]
 * BXEntityDescription* entity = [ctx entityForTable: @"table" error: NULL];
 * \end{lstlisting}
 * \endlatexonly
 * \htmlonly
 * <code>BXEntityDescription* entity = [ctx entityForTable: @"table" error: NULL];</code>
 * \endhtmlonly
 *
 * BXEntityDescriptions are used to specify tables for fetches. For getting a specific 
 * entity description, BXDatabaseContext has two methods: 
 * -entityForTable:error:
 * and
 * -entityForTable:inSchema:error:.
 * Entity descriptions may be accessed before making a
 * connection in which case the database context will check their existence on connect.
 *
 * NSPredicates are created by various Cocoa objects and may be passed directly to BXDatabaseContext.
 * One way to create ad-hoc predicates is by using NSPredicate's method -predicateWithFormat:.
 * In this example, we fetch all the objects instead of filtering them, though.
 */

/**
 * \page performing_a_fetch Performing a fetch using the entity and the predicate
 *
 * \latexonly
 * \begin{lstlisting}[fontadjust, columns=fullflexible, float=h, frame=single, title=Performing a fetch]
 * NSArray* result = [ctx executeFetchForEntity: entity withPredicate: nil error: NULL];
 * \end{lstlisting}
 * \endlatexonly
 * \htmlonly 
 * <code>NSArray* result = [ctx executeFetchForEntity: entity withPredicate: nil error: NULL];</code>
 * \endhtmlonly
 *
 * BXDatabaseContext's method
 * -executeFetchForEntity:withPredicate:error:
 * and its variations may be used to fetch objects from the database. The method takes a BXEntityDescription 
 * and an NSPredicate and performs a fetch synchronously. The fetched objects are returned in an NSArray.
 */

/**
 * \page handling_the_results Handling the results
 *
 * \latexonly
 * \begin{lstlisting}[fontadjust, columns=fullflexible, float=h, frame=single, title=Handling fetch results]
 * for (BXDatabaseObject* object in result)
 * {
 *    NSLog (@"Object ID: %@ column: %@", 
 *           [[object objectID] URIRepresentation], [object valueForKey: @"column"]);
 * } 
 * \end{lstlisting}
 * \endlatexonly
 * \htmlonly 
 * <code>for (BXDatabaseObject* object in result)
 *{
 *    NSLog (@"Object ID: %@ column: %@", 
 *           [[object objectID] URIRepresentation], [object valueForKey: @"column"]);
 *}</code>
 * \endhtmlonly 
 *
 * Since BXDatabaseObject conforms to \em NSKeyValueObserving, methods -valueForKey: and 
 * -setValue:forKey: are available. See \ref accessing_values for details.
 */

/**
 * \page accessing_values Accessing object values
 *
 * BXDatabaseObjects implement NSKeyValueCoding and object values may thus be accessed with 
 * -valueForKey: and -setValue:forKey:. The key will be the column name. As with 
 * NSManagedObject, methods like -&lt;key&gt; and -set&lt;Key&gt;: are also automatically available.
 *
 * Column values are converted to Foundation objects based on the column type. Currently, there is no way to 
 * affect the type conversion. Instead, custom getters may be written for preprocessing
 * fetched objects. To support this, the column values may also be accessed using 
 * \ref BXDatabaseObject::primitiveValueForKey: "-primitiveValueForKey:". Similarly 
 * -setPrimitiveValue:forKey: may be used to set a column value.
 *
 * Currently handled types are listed in \ref database_types.
 *
 *
 * \section accessing_relationships Accessing relationships
 *
 * BaseTen supports the same types of relationships as Core Data: one-to-one, one-to-many and many-to-many.
 *
 * One-to-many is the simplest type of these three: a foreign key in one table referring another will be 
 * interpreted as such. Both of the tables need to be BaseTen enabled and BaseTen's cache tables need to be
 * up-to-date (see the BaseTen Assistant for details). Calling a database object's 
 * \ref BXDatabaseObject::valueForKey: "-valueForKey:" or 
 * \ref BXDatabaseObject::primitiveValueForKey: "-primitiveValueForKey:" 
 * on the to-one side with the name of the foreign key constraint will 
 * return the object on the other side of the reference. On the to-many side, -valueForKey: retrieves a 
 * collection of objects that reference the table in a foreign key. They key used is the other table's name.
 *
 * Consider the following example:
 * <code>CREATE TABLE person (
 *    id SERIAL PRIMARY KEY,
 *    firstname VARCHAR (255),
 *    surname VARCHAR (255)
 *);
 *
 *CREATE TABLE email (
 *    id SERIAL PRIMARY KEY,
 *    address VARCHAR (255),
 *    person_id INTEGER REFERENCES person (id)
 *);</code>
 *
 * Lets say we have two objects: \em aPerson and \em anEmail which have been fetched from the person and email
 * tables, respectively. <tt>[aPerson valueForKey: @"email"]</tt> will now return a collection of \em email objects. 
 * <tt>[anEmail valueForKey: @"person"]</tt> will return a single \em person object.
 *
 * If we modify the previous example, we get a one-to-one relationship: 
 * <code>ALTER TABLE email ADD UNIQUE (person_id);</code> 
 * Now both <tt>[aPerson valueForKey: @"email"]</tt> 
 * and <tt>[anEmail valueForKey: @"person"]</tt> will return a single object from the corresponding table.
 *
 * Many-to-many relationships are modeled with helper tables. The helper table needs to have columns to contain 
 * both tables' primary keys. It needs to be BaseTen enabled as well.
 *
 * Another example: 
 *<code>CREATE TABLE person (
 *    id SERIAL PRIMARY KEY,
 *    firstname VARCHAR (255),
 *    surname VARCHAR (255)
 *);
 *
 *CREATE TABLE title (
 *    id SERIAL PRIMARY KEY,
 *    name VARCHAR (255)
 *);
 *
 *CREATE TABLE person_title_rel (
 *    person_id INTEGER REFERENCES person (id),
 *    title_id INTEGER REFERENCES title (id),
 *    PRIMARY KEY (person_id, title_id)
 *);</code>
 *
 * Lets say \em aPerson has been fetched from the person table and \em aTitle from the title table. 
 * In this case, <tt>[aPerson valueForKey: @"title"]</tt> will return a collection of title objects 
 * and <tt>[aTitle valueForKey: @"person"]</tt> a collection of person objects. Any two foreign keys 
 * in one table will be interpreted as a many-to-many relationship, if they also form the table's 
 * primary key. Objects from the helper table may be retrieved as with one-to-many relationships: 
 * <tt>[aPerson valueForKey: @"person_title_rel"]</tt>.
 * 
 *
 * \section relationship_naming_conflicts Naming conflicts
 *
 * Referencing relationships with target table names works as long as there are only one foreign key in
 * a given table referencing another. As the number increases, relationships obviously cannot be 
 * referenced using the target table name in every case. The following table describes alternative
 * names for relationships in specific cases.
 *
 * <table>
 *     <caption>Relationship names</caption>
 *     <tr>
 *         <th><strong>Relationship type</strong></th>
 *         <th><strong>Target relation kind</strong></th>
 *         <th><strong>Available names</strong></th>
 *     </tr>
 *     <tr>
 *         <td rowspan="2">One-to-many (inverse, from the foreign key's side)</td>
 *         <td>Table</td>
 *         <td>Target table's name, foreign key's name</td>
 *     </tr>
 *     <tr>
 *         <td>View</td>
 *         <td>Target view's name</td>
 *     </tr>
 *     <tr>
 *         <td rowspan="2">One-to-many (from the referenced side)</td>
 *         <td>Table</td>
 *         <td>Target table's name, <em>schema_table_foreignkey</em></td>
 *     </tr>
 *     <tr>
 *         <td>View</td>
 *         <td>Target view's name</td>
 *     </tr>
 *     <tr>
 *         <td rowspan="2">One-to-one (from the foreign key's side)</td>
 *         <td>Table</td>
 *         <td>Target table's name, foreign key's name</td>
 *     </tr>
 *     <tr>
 *         <td>View</td>
 *         <td>Target view's name</td>
 *     </tr>
 *     <tr>
 *         <td rowspan="2">One-to-one (from the referenced side)</td>
 *         <td>Table</td>
 *         <td>Target table's name, <em>schema_table_foreignkey</em></td>
 *     </tr>
 *     <tr>
 *         <td>View</td>
 *         <td>Target view's name</td>
 *     </tr>
 *     <tr>
 *         <td rowspan="2">Many-to-many</td>
 *         <td>Table</td>
 *         <td>Target table's name, name of the foreign key that references the target table</td>
 *     </tr>
 *     <tr>
 *         <td>View</td>
 *         <td>Target view's name</td>
 *     </tr>
 * </table>
 */

/**
 * \page tracking_changes Tracking database changes
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
 * \li \em kBXInsertNotification on database \em INSERT
 * \li \em kBXUpdateNotification on database \em UPDATE
 * \li \em kBXDeleteNotification on database \em DELETE
 *
 * At the time the notifications are posted, database objects and self-updating collections will 
 * already have been updated.
 */

/**
 * \page using_appkit_classes Using the controller subclasses provided with the framework
 *
 * BXDatabaseObjects may be used much in the same manner as NSManagedObjects to populate various Cocoa views. However,
 * the initial fetch needs to be performed and the controller has to assigned the result set. To facilitate this,
 * some NSController subclasses have been provided with the framework. For now, the only directly usable one is 
 * BXSynchronizedArrayController. Additionally, there is BXController and additions to NSController for creating
 * controller subclasses.
 *
 *
 * \section using_bxsynchronizedarraycontroller Using BXSyncronizedArrayController from Interface Builder
 *
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
 *             <li>The schema field may be left empty, in which case \em public will be used.</li>
 *             <li>Please note that the table needs to be enabled for change observing. This can be 
 *                 done using the Setup Application.</li>
 *         </ul>
 *     </li>
 *     <li>Bind the Cocoa views to the controller.</li> 
 *     <li>Test the interface. The views should be populated using the database.</li>
 * </ol>
 */

/**
 * \page database_types Handled PostgreSQL types
 *
 * Composite types, domains and types not listed here are currently returned as NSData. 
 * Array types are returned as NSArrays of the respective type or NSArrays of NSData objects.
 *
 * <table>
 *     <caption>Type conversion</caption>
 *     <tr>
 *         <th><strong>PostgreSQL type</strong></th>
 *         <th><strong>Cocoa type</strong></th>
 *     </tr>
 *     <tr>
 *         <td>aclitem</td>
 *         <td>(A private class)</td>
 *     </tr>
 *     <tr>
 *         <td>bit</td>
 *         <td>NSData</td>
 *     </tr>
 *     <tr>
 *         <td>bool</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>bpchar</td>
 *         <td>NSString</td>
 *     </tr> 
 *     <tr>
 *         <td>bytea</td>
 *         <td>NSData</td>
 *     </tr>
 *     <tr>
 *         <td>char</td>
 *         <td>NSString</td>
 *     </tr>
 *     <tr>
 *         <td>date</td>
 *         <td>NSCalendarDate\ref database_types_ref_1 "¹"</td>
 *     </tr>
 *     <tr>
 *         <td>float4</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>float8</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>int2</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>int2vector</td>
 *         <td>NSArray of NSNumbers</td>
 *     </tr> 
 *     <tr>
 *         <td>int4</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>int8</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>name</td>
 *         <td>NSString</td>
 *     </tr>
 *     <tr>
 *         <td>numeric</td>
 *         <td>NSDecimalNumber</td>
 *     </tr>
 *     <tr>
 *         <td>oid</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>point</td>
 *         <td>NSValue</td>
 *     </tr>
 *     <tr>
 *         <td>text</td>
 *         <td>NSString</td>
 *     </tr>
 *     <tr>
 *         <td>timestamp</td>
 *         <td>NSDate</td>
 *     </tr>
 *     <tr>
 *         <td>timestamptz</td>
 *         <td>NSCalendarDate\ref database_types_ref_1 "¹"</td>
 *     </tr>
 *     <tr>
 *         <td>varbit</td>
 *         <td>NSData</td>
 *     </tr>
 *     <tr>
 *         <td>varchar</td>
 *         <td>NSString</td>
 *     </tr>
 *     <tr>
 *         <td>uuid</td>
 *         <td>NSString</td>
 *     </tr>
 * </table>
 * <ol>
 *     <li>\anchor database_types_ref_1 Subject to change as NSCalendarDate might become deprecated.</li>
 * </ol>
 */

/**
 * \page postgresql_installation PostgreSQL installation
 *
 * Here's a brief tutorial on PostgreSQL installation.
 * <ol>
 *     <li>Get the latest PostgreSQL source release (8.2 or later) from http://www.postgresql.org/ftp/source.</li>
 *     <li>Uncompress, configure, make, [sudo] make install. On Mac OS X, Bonjour and OpenSSL are available, so <tt>./configure &ndash;-with-bonjour &ndash;-with-openssl && make && sudo make install</tt> probably gives the expected results.</li>
 *     <li>It's usually a good idea to create a separate user and group for PostgreSQL, but Mac OS X already comes with a database-specific user: for mysql. We'll just use that and hope PostgreSQL doesn't mind.</li>
 *     <li>Make \em mysql the owner of the PostgreSQL folder, then sudo to <tt>mysql</tt>:\n
 *         <tt>
 *             sudo chown -R mysql:mysql /usr/local/pgsql\n
 *             sudo -u mysql -s
 *         </tt>
 *     </li>
 *     <li>Initialize the PostgreSQL database folder. We'll use en_US.UTF-8 as the default locale:\n<tt>LC_ALL=en_US.UTF-8 /usr/local/pgsql/bin/initdb -D \\\n /usr/local/pgsql/data</tt></li>
 *     <li>Launch the PostgreSQL server itself:\n
 *         <tt>
 *             /usr/local/pgsql/bin/pg_ctl -D /usr/local/pgsql/data \\\n
 *             -l /usr/local/pgsql/data/pg.log start
 *         </tt>
 *     <li>Create a superuser account for yourself. This way, you don't have to sudo to mysql to create new databases and users.\n
 *         <tt>/usr/local/pgsql/bin/createuser <your-short-user-name></tt>
 *     </li>
 *     <li>Exit the \em mysql sudo and create a database. If you create a database with your short user name, psql will connect to it by default.\n
 *         <tt>
 *             exit\n
 *             /usr/local/pgsql/bin/createdb <your-short-user-name>
 *         </tt>
 *     </li>
 * </ol>
 */

/**
 * \page building_baseten Building BaseTen
 *
 * For a successful build, Xcode 3.1 and Mac OS X 10.5 SDK are required.
 *
 * BaseTen has several subprojects, namely BaseTenAppKit and a plug-in for Interface Builder 3. The default target in 
 * BaseTen.xcodeproj, <em>BaseTen + GC</em>, builds them as well; the plug-in and the AppKit framework will appear in the 
 * subprojects' build folders, which are set to the default folder. The built files will be either in 
 * \em build folders in the subprojects' folders or in the user-specified build folder. The documentation will be
 * in the \em Documentation folder.
 *
 *
 * \section building_for_the_release_dmg Building for the release disk image
 *
 * The files needed to build the release disk image are in the SVN repository as well. Doxygen is needed during 
 * the process. To create the DMG, follow these steps:
 * <ol>
 *     <li>From the checked-out directory, <tt>cd ReleaseDMG</tt>.</li>
 *     <li>The default location for the built files is <em>BaseTen-dmg-build</em> in the current directory. To set a custom path, edit the \em SYMROOT variable in <em>create_release_dmg.sh</em>.</li>
 *     <li>
 *         Do <tt>./create_release_dmg.sh</tt>. The built DMG will appear in the \em ReleaseDMG folder.
 *         <ul>
 *             <li>If you don't have LaTeX installed, do <tt>./create_release_dmg.sh -&ndash;without-latex</tt> instead. The PDF manual won't be included on the DMG, though.</li>
 *         </ul>
 *     </li>
 * </ol>
 */

/** 
 * \page limitations Limitations in current version
 * 
 * These are some of the most severe limitations in the current version.
 * \li Most public classes are non-thread-safe, so thread safety must be enforced externally if it's required.
 *     Furthermore, all queries must be performed from the thread in which the context made a database connection. This could change
 *     in the future, so it is best to create and handle a context only in one thread.
 * \li No serialization mechanism has been implemented for BXDatabaseObject.
 * \li Currently, migration models aren't understood by the assistant, so the easiest way to do model
 *	   migration might be using SQL.
 */
