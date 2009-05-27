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
 * bx_error_during_rollback
 * bx_error_during_clear_notification
 * bx_test_failed
 * pgts_unrecognized_selector
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
 */

/**
 * \page general_usage Using BaseTen framework
 *
 * \latexonly \section*{Topics} \endlatexonly
 * \li \subpage overview
 * \li \subpage baseten_assistant
 * \li \subpage getting_started
 * \li \subpage accessing_values
 * \li \subpage sql_views
 * \li \subpage database_types
 * \li \subpage relationships
 * \li \subpage predicates
 * \li \subpage tracking_changes
 * \li \subpage using_appkit_classes
 * \li \subpage autocommit_manual_commit
 * \li \subpage thread_safety
 * \li \subpage multiple_contexts
 * \li \subpage linking_to_baseten
 * \li \subpage building_baseten
 */ 

/**
 * \page overview Overview of BaseTen
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
 * \image html BaseTen-object-relationships.png "Relationships between BaseTen's objects"
 * \image html BaseTen-class-hierarchy.png "BaseTen class hierarchy"
 * \image latex BaseTen-object-relationships.pdf "Relationships between BaseTen's objects" width=\textwidth
 * \image latex BaseTen-class-hierarchy.pdf "BaseTen class hierarchy" width=\textwidth 
 */

/**
 * \page baseten_assistant BaseTen Assistant
 *
 * BaseTen Assistant is a simple database management application distributed with BaseTen framework. It has its own help that is available from within the application. 
 * In short, it has the following features:
 * \li It can be used to enable or disable tables and views for use with BaseTen.
 * \li It can refresh the tables that BaseTen uses to determine relationships between entities.
 * \li It can list entities' attributes and relationships as they are available when using the framework.
 * \li It can create a database schema from an Xcode data model.
 * \li It can create a chart of the database schema that can be displayed using Graphviz or OmniGraffle.
 */

/**
 * \page getting_started Getting started
 *
 * Typically accessing a database consists roughly of the following steps:
 * <ul>
 *     <li>\ref creating_a_database_context "Creating an instance of BXDatabaseContext"</li>
 *     <li>\ref connecting_to_a_database "Connecting to a database"</li>
 *     <li>\ref getting_an_entity_and_a_predicate "Getting an entity description from the context and possibly creating an NSPredicate for reducing the number of fetched objects"</li>
 *     <li>\ref performing_a_fetch "Performing a fetch using the entity and the predicate"</li>
 *     <li>\ref handling_the_results "Handling the results"</li>
 *     <li>\ref creating_objects "Creating new objects"</li>
 * </ul>
 * Here is a small walkthrough with sample code. More examples are available in the BaseTen Subversion repository and at http://basetenframework.org.
 *
 * \latexonly
 * \lstset{language=[Objective]C, backgroundcolor=\color[rgb]{0.84,0.87,0.90}, rulecolor=\color[gray]{0.53}, frame=single, framesep=0pt, framextopmargin=2pt, framexbottommargin=2pt, fontadjust, columns=fullflexible, captionpos=b}
 * \begin{lstlisting}[caption=A simple command line tool that uses BaseTen]
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
 *     NSDictionary* values = [NSDictionary dictionaryWithObject: @"newValue" forKey: @"column"];
 *     BXDatabaseObject* newObject = [ctx createObjectForEntity: entity 
 *                                     withFieldValues: values error: NULL];
 *     NSLog (@"new object: %@", newObject);
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
 *     NSDictionary* values = [NSDictionary dictionaryWithObject: @"newValue" forKey: @"column"];
 *     BXDatabaseObject* newObject = [ctx createObjectForEntity: entity withFieldValues: values error: NULL];
 *     NSLog (@"new object: %@", newObject);
 *
 *     return 0;
 * }</code>
 * \endhtmlonly
 *
 *
 * \section creating_a_database_context Creating a database context
 *
 * The designated initializer of BXDatabaseContext is 
 * \ref BXDatabaseContext::initWithDatabaseURI: "-initWithDatabaseURI:". \ref BXDatabaseContext::init "-init" 
 * is also available but the context does require an URI before connecting.
 *
 * BXDatabaseContext requires the URI to be formatted as follows:<br>
 * <tt>pgsql://username:password\@host/database_name</tt>. Currently, as PostgreSQL is the only supported 
 * database, only <tt>pgsql://</tt> URIs are allowed. In command line tools, all parameters are required 
 * except for the password, the need for which depends on the database configuration.
 *
 * Various methods in BXDatabaseContext take a double pointer to an NSError object as a parameter. if the 
 * called method fails, the NSError will be set on return. If the parameter is NULL, the default error
 * handler raises a BXException. BXDatabaseContext's delegate may change this behaviour.
 *
 *
 * \section connecting_to_a_database Connecting to a database
 *
 * \latexonly 
 * \begin{lstlisting}
 * [ctx connectSync: NULL];
 * \end{lstlisting}
 * \endlatexonly
 * \htmlonly
 * <code>[ctx connectSync: NULL];</code>
 * \endhtmlonly
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
 * like <tt>pgsql:///<em>database_name</em></tt> allowed. Additionally a <em>kBXConnectionSetupAlertDidEndNotification</em>
 * will be posted when the user dismisses an alert panel, which is presented on failure.
 *
 * Since <em>NULL</em> is passed in place of an NSError double pointer, a BXException will be thrown on error.
 * See BXDatabaseContext's documentation for details on error handling.
 *
 *
 * \section getting_an_entity_and_a_predicate Getting a BXEntityDescription and an NSPredicate
 *
 * \latexonly
 * \begin{lstlisting}
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
 *
 *
 * \section performing_a_fetch Performing a fetch using the entity and the predicate
 *
 * \latexonly
 * \begin{lstlisting}
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
 *
 *
 * \section handling_the_results Handling the results
 *
 * \latexonly
 * \begin{lstlisting}
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
 * Since BXDatabaseObject conforms to <em>NSKeyValueObserving</em>, methods -valueForKey: and 
 * -setValue:forKey: are available. See \ref accessing_values for details.
 *
 *
 * \section creating_objects Creating a new object
 *
 * \latexonly
 * \begin{lstlisting}
 * NSDictionary* values = [NSDictionary dictionaryWithObject: @"newValue" forKey: @"column"];
 * BXDatabaseObject* newObject = [ctx createObjectForEntity: entity 
 *                                 withFieldValues: values error: NULL];
 * NSLog (@"new object: %@", newObject);
 * \end{lstlisting}
 * \endlatexonly
 * \htmlonly 
 * <code>NSDictionary* values = [NSDictionary dictionaryWithObject: @"newValue" forKey: @"column"];
 * BXDatabaseObject* newObject = [ctx createObjectForEntity: entity withFieldValues: values error: NULL];
 * NSLog (@"new object: %@", newObject);</code>
 * \endhtmlonly
 *
 * New rows are inserted with BXDatabaseContext's method -createObjectForEntity:withFieldValues:error:.
 * The values dictionary may contain initial values for both attributes and to-one relationships in
 * case the target entity contains the foreign key.
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
 * Currently handled data types are listed in \ref database_types.
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
 *         <td>bigint, bigserial</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>bit</td>
 *         <td>NSString</td>
 *     </tr>
 *     <tr>
 *         <td>boolean</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>bytea</td>
 *         <td>NSData</td>
 *     </tr>
 *     <tr>
 *         <td>char, bpchar</td>
 *         <td>NSString</td>
 *     </tr>
 *     <tr>
 *         <td>date</td>
 *         <td>NSDate</td>
 *     </tr>
 *     <tr>
 *         <td>decimal, numeric</td>
 *         <td>NSDecimalNumber</td>
 *     </tr>
 *     <tr>
 *         <td>double precision</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>int2vector</td>
 *         <td>NSArray of NSNumbers</td>
 *     </tr> 
 *     <tr>
 *         <td>integer, serial</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>name</td>
 *         <td>NSString</td>
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
 *         <td>real</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>smallint</td>
 *         <td>NSNumber</td>
 *     </tr>
 *     <tr>
 *         <td>text</td>
 *         <td>NSString</td>
 *     </tr>
 *     <tr>
 *         <td>time</td>
 *         <td>NSDate</td>
 *     </tr>
 *     <tr>
 *         <td>time with time zone</td>
 *         <td>NSDate</td>
 *     </tr>
 *     <tr>
 *         <td>timestamp</td>
 *         <td>NSDate</td>
 *     </tr>
 *     <tr>
 *         <td>timestamp with time zone</td>
 *         <td>NSDate</td>
 *     </tr>
 *     <tr>
 *         <td>varbit</td>
 *         <td>NSString</td>
 *     </tr>
 *     <tr>
 *         <td>varchar</td>
 *         <td>NSString</td>
 *     </tr>
 *     <tr>
 *         <td>uuid</td>
 *         <td>NSString</td>
 *     </tr>
 *     <tr>
 *         <td>xml</td>
 *         <td>NSData or NSXMLDocument</td>
 *     </tr>
 * </table>
 *
 *
 * \section string_handling String types
 *
 * When NSStrings are passed to the database, they are normalized to Unicode NFD. In case the database's encoding isn't Unicode (UTF-8), PostgreSQL will handle the
 * conversion.
 *
 * Even if the database's encoding is Unicode, PostgreSQL compares bytes, not Unicode characters, in strings as of version 8.3. 
 * Thus, comparison within the database could fail when done with non-normalized strings or strings in NFC.
 *
 * <!-- We begun to do this before version 1.5. -->
 *
 *
 * \section date_handling Date and time types
 *
 * Cocoa's and Core Foundation's date classes store the date as seconds from a reference date, 2001-01-01 00:00:00 UTC. SQL times and timestamps, on the other hand, might have
 * an associated time zone specified as an offset to GMT. In PostgreSQL 8.3, removing the time zone information by casting truncates the value. Casting a time or a timestamp 
 * lacking a time zone assigns the current time zone to it instead of converting.
 *
 * BaseTen does several things to cope with this:
 * \li It sets the connection's time zone to UTC.
 * \li It assigns UTC to times and timestamps that don't have a time zone.
 * \li It converts received times and timestamps in other time zones to UTC.
 * \li NSCalendarDates passed as parameters will be converted to UTC.
 *
 * Therefore, NSDates received from the server should in fact contain the offset from their point in time to the reference date. To ease handling, the date is set to
 * 2001-01-01 in case of time types. This allows -[NSDate timeIntervalSinceReferenceDate] to return the time's difference to midnight in seconds.
 *
 * NSDates are converted to their date representation using NSCalendar and its underlying ICU library. ICU specifies a single cut-over date for the switch from Julian to
 * Gregorian calendar, which is 1582-10-04. (It isn't currently possible to specify a different cut-over date to NSCalendar.) NSDates before this point will be converted 
 * to Julian calendar dates. The rationale for this is that timestamps can't be passed directly to PostgreSQL, and NSCalendar seems to be the best option for representing
 * timestamps as dates. PostgreSQL, on the other hand, uses Julian days (number of days since January 1, 4713 BCE with fraction, length of the year specified as 365.2425 
 * days) for date calculations, and most likely converts them to Gregorian calendar dates for presentation. Thus, your mileage may vary when calculating dates within 
 * the database.
 *
 * \note In versions earlier than 1.7, date handling depended on several factors, such as the current time zone and the server's time zone. This is no longer the case. Also, all 
 *       date and time types are currently returned as NSDate, not NSCalendarDate.
 *
 *
 * \section xml_handling The XML type
 *
 * PostgreSQL's xml data type handles both XML documents and content fragments. BaseTen creates NSData objects from them by default, but if the
 * table also has a constraint like <em>CHECK (xml_column IS DOCUMENT)</em>, NSXMLDocuments will be created instead. The constraint mustn't
 * contain any other conditions, but there may be additional CHECK constraints.
 */

/**
 * \page relationships Relationships
 *
 * BaseTen supports the same types of relationships as Core Data: one-to-one, one-to-many and many-to-many.
 * The relationships are created using foreign keys as shown in the following table.
 *
 * <table>
 *     <caption>Required conditions for relationsips</caption>
 *     <tr>
 *         <th><strong>Relationship type</strong></th>
 *         <th><strong>Required conditions</strong></th>
 *     </tr>
 *     <tr>
 *         <td>One-to-many</td>
 *         <td>A foreign key constraint on the many-side.</td>
 *     </tr>
 *     <tr>
 *         <td>One-to-one</td>
 *         <td>A foreign key constraint the columns of which also have an unique constraint.</td>
 *     </tr>
 *     <tr>
 *         <td>Many-to-many</td>
 *         <td>A helper table that has foreign keys referencing two other tables. The foreign key columns also need to form the table's primary key.</td>
 *     </tr>
 * </table>
 * 
 *
 * \section relationship_naming Relationship naming
 *
 * Relationship names are determined from foreign key names. For one-to-one and one-to-many 
 * relationships, the foreign key's name should have the form <em>name1__name2</em>, where <em>name1</em> is 
 * the relationship's name from the foreign key's side, and <em>name2</em> is the inverse relationship's 
 * name. If the foreign key's name doesn't contain two consecutive underscores, a generated name is 
 * used for the inverse relationship. (Similarly, if the foreign key's name begins with two 
 * underscores, a generated name is used for the relationship. The generated name has the format 
 * <em>schema_table_foreignkey</em>.
 *
 * Many-to-many relationships have the same name as the foreign key that references the target table.
 *
 * BaseTen Assistant generates foreign keys with names like this, but if creating or altering the 
 * database schema isn't an option, a set of identical relationships is created with different names. 
 * Each relationship has the same name as the target table, with the word “Set” appended in the case 
 * of to-many relationships.
 *
 * The latter naming is also available with views, while the former is not.
 *
 * In case the two relationships created into the same entity have matching names, the one named 
 * after the table and its inverse relationship are removed. In case two relationships created into 
 * one entity using different foreign keys have matching names, they will both be removed with their 
 * inverse relationships.
 *
 * <table>
 *     <caption>Relationship names</caption>
 *     <tr>
 *         <th><strong>Relationship type</strong></th>
 *         <th><strong>Available names</strong></th>
 *     </tr>
 *     <tr>
 *         <td>One-to-many (inverse, from the foreign key's side)</td>
 *         <td><em>target</em>Set, first part of the foreign key's name</td>
 *     </tr>
 *     <tr>
 *         <td>One-to-many (from the referenced side)</td>
 *         <td><em>target</em>, second part of the foreign key's name</td>
 *     </tr>
 *     <tr>
 *         <td>One-to-one (from the foreign key's side)</td>
 *         <td><em>target</em>, first part of the foreign key's name</td>
 *     </tr>
 *     <tr>
 *         <td>One-to-one (from the referenced side)</td>
 *         <td><em>target</em>, second part of the foreign key's name</td>
 *     </tr>
 *     <tr>
 *         <td>Many-to-many</td>
 *         <td><em>target</em>Set, name of the foreign key that references the target table</td>
 *     </tr>
 * </table>
 *     
 * \note The relationship names used before version 1.7 are still available. They won't be listed
 *       by BaseTen Assistant, though, and using them will call \ref BXDeprecationWarning.
 *
 *
 * \section relationship_naming_example Relationship example
 *
 * Consider the following case:
 * \latexonly
 * \lstset{language=SQL, backgroundcolor=\color[rgb]{0.84,0.87,0.90}, rulecolor=\color[gray]{0.53}, frame=single, framesep=0pt, framextopmargin=2pt, framexbottommargin=2pt, fontadjust, columns=fullflexible, captionpos=b}
 * \begin{lstlisting}[caption=Tables with a one-to-many relationship]
 * CREATE TABLE person (
 *     id SERIAL PRIMARY KEY,
 *     firstname VARCHAR (255),
 *     surname VARCHAR (255)
 * );
 *
 * CREATE TABLE email (
 *     id SERIAL PRIMARY KEY,
 *     address VARCHAR (255),
 *     person_id INTEGER REFERENCES person (id)
 * );
 * \end{lstlisting} 
 * \endlatexonly
 * \htmlonly
 * <code>CREATE TABLE person (
 *     id SERIAL PRIMARY KEY,
 *     firstname VARCHAR (255),
 *     surname VARCHAR (255)
 * );
 *
 * CREATE TABLE email (
 *     id SERIAL PRIMARY KEY,
 *     address VARCHAR (255),
 *     person_id INTEGER REFERENCES person (id)
 * );</code>
 * \endhtmlonly
 *
 * Lets say we have two objects: <em>aPerson</em> and <em>anEmail</em> which have been fetched from the person and email
 * tables, respectively.<br>
 * <tt>[aPerson valueForKey:\@"emailSet"]</tt> will now return a collection of <em>email</em> objects.<br>
 * <tt>[anEmail valueForKey:\@"person"]</tt> will return a single <em>person</em> object.
 *
 * If we modify the previous example by adding an unique constraint, we get a one-to-one relationship: 
 *
 * \latexonly
 * \begin{lstlisting}
 * ALTER TABLE email ADD UNIQUE (person_id);
 * \end{lstlisting} 
 * \endlatexonly
 * \htmlonly
 * <code>ALTER TABLE email ADD UNIQUE (person_id);</code> 
 * \endhtmlonly
 *
 * Now both of the following messages will return a single object from the corresponding table:<br>
 * <tt>[aPerson valueForKey:\@"email"]</tt><br>
 * <tt>[anEmail valueForKey:\@"person"]</tt>
 *
 * Many-to-many relationships are modeled with helper tables. The helper table needs to have columns to contain 
 * both tables' primary keys. It needs to be BaseTen enabled as well.
 *
 * Another example:
 * \latexonly
 * \begin{lstlisting}[caption=Tables with a many-to-many relationship]
 * CREATE TABLE person (
 *     id SERIAL PRIMARY KEY,
 *     firstname VARCHAR (255),
 *     surname VARCHAR (255)
 * );
 *
 * CREATE TABLE title (
 *     id SERIAL PRIMARY KEY,
 *     name VARCHAR (255)
 * );
 *
 * CREATE TABLE person_title_rel (
 *     person_id INTEGER REFERENCES person (id),
 *     title_id INTEGER REFERENCES title (id),
 *     PRIMARY KEY (person_id, title_id)
 * );
 * \end{lstlisting} 
 * \endlatexonly
 * \htmlonly
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
 * \endhtmlonly
 *
 * Lets say <em>aPerson</em> has been fetched from the person table and <em>aTitle</em> from the title table. 
 * In this case,<br>
 * <tt>[aPerson valueForKey:\@"titleSet"]</tt> will return a collection of title objects and <br>
 * <tt>[aTitle valueForKey:\@"personSet"]</tt> a collection of person objects.<br>
 * Any two foreign keys 
 * in one table will be interpreted as a many-to-many relationship, if they also form the table's 
 * primary key. Objects from the helper table may be retrieved as with one-to-many relationships:<br>
 * <tt>[aPerson valueForKey:\@"person_title_rel"]</tt>.
 */

/**
 * \page predicates Predicates
 *
 * Most types of predicates and expressions are converted to SQL and sent to the database server.
 * Others cause the returned object set to be filtered again on the client side. Specifically, the following
 * use cases work in this manner: The affected part of the predicate is replaced with <em>true</em> (or <em>false</em>, 
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
 * \li <em>kBXInsertNotification</em> on database <em>INSERT</em>
 * \li <em>kBXUpdateNotification</em> on database <em>UPDATE</em>
 * \li <em>kBXDeleteNotification</em> on database <em>DELETE</em>
 *
 * At the time the notifications are posted, database objects and self-updating collections will 
 * already have been updated.
 */

/**
 * \page using_appkit_classes Using BaseTenAppKit
 *
 * When BaseTenAppKit is linked to an application, BXDatabaseContext gains some additional capabilities. If given
 * a partial database URI, it will present a number of connection panels when 
 * \ref BXDatabaseContext::connect: "-connect:" is called.
 *
 * BXDatabaseObjects may be used much in the same manner as NSManagedObjects to populate various Cocoa views. 
 * To handle some situations unique to BaseTen,
 * some NSController subclasses have been provided with the framework. For now, the only directly usable one is 
 * BXSynchronizedArrayController. Additionally, there is BXController and additions to NSController for creating
 * controller subclasses.
 *
 * Compared to NSArrayController, BXSynchronizedArrayController can do the following things:
 * <ul>
 *     <li>It can present errors to the user when creating a new object fails.</li>
 *     <li>It can get a BXEntityDescription from its database context and fetch objects using it. NSEntityDescriptions cannot be used because they are CoreData-specific.</li>
 *     <li>It can lock the edited row in the database when an editing session begins.</li>
 *     <li>It can provide the selected objects' ids.</li>
 * </ul>
 *
 *
 * BXSynchronizedArrayController shouldn't be set to entity mode; the user interface for this isn't even available
 * in Interface Builder. It also doesn't make use of a managed object context.
 *
 *
 * \section related_objects_with_bxsynchronizedarraycontroller Binding to a set of related objects
 *
 * The synchronized array controller's Content Set may be bound to another synchronized array controller with
 * a key path that represents a relationship. In case of a one-to-many relationship, the foreign key field
 * values will also be set when -newObject or -createObject: gets called.
 *
 *
 * \section using_bxdatabasecontext_ib Using BXDatabaseContext from Interface Builder
 *
 * <ol>
 *     <li>Load the BaseTen plug-in.</li>
 *     <li>Create a new nib file.</li>
 *     <li>Drag a database context from the library to the file.</li>
 *     <li>Select the database context and choose Attributes from the inspector's pop-up menu.</li>
 *     <li>Enter a valid database URI, <tt>pgsql:///<em>database_name</em></tt> at minimum.</li>
 * </ol>
 *
 *
 * \section using_bxsynchronizedarraycontroller_ib Using BXSynchronizedArrayController from Interface Builder
 *
 * <ol>
 *     <li>Drag a BXSynchronizedArrayController from the library to the file.</li>
 *     <li>Select the array controller and choose Attributes from the inspector's pop-up menu.</li>
 *     <li>Enter a table name into the field.
 *         <ul>
 *             <li>The schema field may be left empty, in which case <em>public</em> will be used.</li>
 *         </ul>
 *     </li>
 *     <li>Bind the Cocoa views to the controller.</li> 
 *     <li>Bind the array controller to the database context using the Database Context binding or 
 *         connect the databaseContext outlet.</li>
 *     <li>Test the interface. The views should be populated using the database.</li>
 * </ol>
 *
 *
 * \section using_value_transformers_ib Using BaseTenAppKit's value transformers from Interface Builder
 *
 * When database rows get locked, it might be desirable to disable editing and indicate this visually
 * in the user interface. Most AppKit's classes, have an Editable binding, and some, like NSTableColumn, 
 * have bindings that affect the display of their value. Lets say a table column's <em>Value</em> is 
 * bound to a BXArrayController using <em>my_key</em> as the model key path. BaseTenAppKit could then 
 * be used to set the rows to be conditionally editable like this:
 * <ol>
 *     <li>Select the table column inside its table view</li>
 *     <li>Open the Bindings Inspector</li>
 *     <li>Click the Editable binding</li>
 *     <li>Set the binding to the array controller and set the controller key to <em>arrangedObjects</em>.
 *     <li>Set the model key to <em>statusInfo.my_key</em>.</li>
 *     <li>Set the value transformer to <em>BXObjectStatusToEditableTransformer</em>.</li>
 * </ol>
 * The rows may also be coloured so that their status is visible:
 * <ol>
 *     <li>Inspecting the same column as in the previous example, click the Text Color binding.</li>
 *     <li>Set the binding to the array controller and set the controller key to <em>arrangedObjects</em>.
 *     <li>Set the model key to <em>statusInfo.my_key</em>.</li>
 *     <li>Set the value transformer to <em>BXObjectStatusToColorTransformer</em>.</li>
 * </ol>
 */

/**
 * \page autocommit_manual_commit Commit modes and locking
 *
 * BXDatabaseContext has two modes for handling transactions, which affect queries sent to the database and the way
 * the context's undo manager is used. In both cases, the transaction isolation level is set to READ COMMITTED meaning that
 * changes committed by other connections will be received. The commit mode is set using -setAutocommits:. Generally,
 * autocommit is well-suited for non-document-based applications. Manual commit is well-suited for document-based 
 * applications, provided that changes are committed frequently enough.
 *
 *
 * \section autocommit Autocommit
 *
 * When using autocommit, each query creates its own transaction and changes get propagated immediately to other clients. 
 * Undo works at the level of -[BXDatabaseObject setPrimitiveValueForKey:]. For each change an invocation of the method
 * is added to the undo manager with the earlier value as a parameter.
 *
 *
 * \section manual_commit Manual commit
 *
 * In manual commit mode, a savepoint is added after each change. Undo causes a ROLLBACK TO SAVEPOINT query to be sent.
 * This causes not only the changes made by BaseTen to be reverted, but their possible side effects as well. For instance,
 * if database triggers fire when a specific change is made, its effects will be reverted, too. When -commit: or -rollback
 * is called, undo queue is emptied.
 *
 * In case one client updates a row, BaseTen doesn't send the change to other clients immediately. Instead, it sends a
 * notification indicating that the row is locked and changing it will cause the connection to block until the other
 * client ends its transaction. BXDatabaseObject's method -isLockedForKey:, BXDatabaseObjectStatusInfo class and
 * value transformers in BaseTenAppKit are useful for handling this situation. However, other than BaseTen clients
 * don't cause the lock status to be set, and the connection could block.
 *
 * The downside is that if -[BXDatabaseContext commit:] or -[BXDatabaseContext rollback] aren't called frequently enough,
 * transactions could become very long, which is against their intended use. This causes server resources to be consumed.
 *
 *
 * \section locking_rows Locking rows
 *
 * When a database connection sends UPDATE and DELETE queries, the affected rows will be locked until the connection
 * ends its transaction. If other connections try to change the rows, their queries will block. To handle this 
 * situation, BaseTen stores information about locked rows into its internal tables and notifies other BaseTen clients
 * about them. BXSynchronizedArrayController also tries to lock rows when the editing session begins.
 *
 * Lock information will be available using BXDatabaseObject's method -isLockedForKey:.
 * BXDatabaseContext has a method, -setSendsLockQueries:, for enabling or disabling lock notifications. If the
 * notifications are disabled, BXDatabaseContext won't notify other clients but still reacts to received notifications.
 *
 * When editing rows through BXSynchronizedArrayController, it tries to send a SELECT ... FOR UPDATE NOWAIT query
 * when the editing session begins. If the context is in autocommit mode, a transaction will also be started.
 * If the query succeeds, a lock notification will be sent regardless of BXDatabaseContext's setting. If the query
 * fails, the editing session will be ended using -discardEditing. BXSynchronizedArrayController's method
 * -setLocksRowsOnBeginEditing: can be used to disable this functionality.
 *
 * To make the changes visible in the user interface, BaseTenAppKit has some NSValueTransformer subclasses. See
 * \ref value_transformers for details.
 */

/**
 * \page thread_safety Thread safety
 *
 * For its mostly used parts, BaseTen isn't thread safe. In particular, BXDatabaseContext needs to be used from the same thread 
 * in which its connection methods have been called. This is because it adds a run loop source to the thread's run loop.
 *
 * The documented methods of the following classes are thread safe:
 *
 * \li BXEntityDescription
 * \li BXAttributeDescription
 * \li BXRelationshipDescription
 * \li BXDatabaseObjectID
 *
 * Additionally, BXDatabaseObject's method -cachedValueForKey: is thread safe. As a result, BXDatabaseObject's values may be 
 * accessed from multiple threads as soon as they have been fetched.
 *
 * One possibility to make use of multiple threads is to create a database context for each thread, but 
 * see \ref multiple_contexts "the next chapter".
 */

/**
 * \page multiple_contexts Using multiple database contexts
 *
 * In general, there aren't many reasons to have multiple database contexts in an application that connects 
 * to a single database. One possibility to make the context available
 * everywhere it's needed is to make it a property of the NSApplication delegate or an NSDocument subclass.
 *
 * Advantages:
 * \li Thread safety. Since database contexts should be created and used from within a single thread, it 
 *     might be advantageous to create one for each thread.
 * \li Transaction isolation. One could want to query the database state outside the current transaction.
 * \li Privilege separation. One might want to access the database using roles with different privileges.
 * \li Different commit modes.
 *
 * Disadvantages:
 * \li Increased memory usage on the server. Each database context makes a connection to the database 
 *     (two in manual commit mode). These require an amount of shared memory
 *     on the server. This limits the number of clients who can connect simultaneously.
 * \li Increased memory and network usage on the client side. Database objects are uniqued and updated 
 *     within a context, so each context requires its own copy of the objects.
 *     Each context also needs to update its objects on its own.
 * \li Database objects cannot be passed from one context to another. This causes problems.
 */

/**
 * \page linking_to_baseten Linking to BaseTen and BaseTenAppKit
 *
 * Mac OS X's linker specifies paths to dynamic libraries (including frameworks) using a the install name of the library. The install name is specified in the library
 * itself. BaseTen and BaseTenAppKit distributed on the disk image have their install names set to a location inside the loading application's bundle, in the Frameworks folder.
 * When linking to the frameworks in Xcode, a Copy Files build phase should be added for the application target:
 * <ol>
 *     <li>Right-click your application target in the Groups & Files table</li>
 *     <li>Select Add, New Build Phase and New Copy Files Build Phase</li>
 *     <li>Select Frameworks as the destination</li>
 *     <li>Click the disclosure triangle next to your target</li>
 *     <li>Drag BaseTen and BaseTenAppKit inside the new build phase</li>
 * </ol>
 *
 * The frameworks are built with the -headerpad_max_install_names linker option, so changing the install names with tools like install_name_tool should also be possible.
 * When building BaseTen and BaseTenAppKit using the Debug configuration, the install name is left empty, which causes it to be set to the build directory.
 */

/**
 * \page building_baseten Building BaseTen
 *
 * For a successful build, Xcode 3.1 and Mac OS X 10.5 SDK are required.
 *
 * BaseTen has several subprojects, namely BaseTenAppKit and a plug-in for Interface Builder 3. The default target in 
 * BaseTen.xcodeproj, <em>BaseTen + GC</em>, builds them as well; the plug-in and the AppKit framework will appear in the 
 * subprojects' build folders, which are set to the default folder. The built files will be either in 
 * <em>build</em> folders in the subprojects' folders or in the user-specified build folder. The documentation will be
 * in the <em>Documentation</em> folder.
 *
 *
 * \section building_for_the_release_dmg Building for the release disk image
 *
 * The files needed to build the release disk image are in the SVN repository as well. Doxygen is needed during 
 * the process. To create the DMG, follow these steps:
 * <ol>
 *     <li>From the checked-out directory, <tt>cd ReleaseDMG</tt>.</li>
 *     <li>The default location for the built files is <em>BaseTen-dmg-build</em> in the current directory. To set a custom path, edit the <em>SYMROOT</em> variable in <em>create_release_dmg.sh</em>.</li>
 *     <li>
 *         Do <tt>./create_release_dmg.sh</tt>. The built DMG will appear in the <em>ReleaseDMG</em> folder.
 *         <ul>
 *             <li>If you don't have LaTeX installed, do <tt>./create_release_dmg.sh -&ndash;without-latex</tt> instead. The PDF manual won't be included on the DMG, though.</li>
 *         </ul>
 *     </li>
 * </ol>
 */

/**
 * \page database_usage Database administration
 *
 * \latexonly \section*{Topics} \endlatexonly
 * \li \subpage baseten_enabling
 * \li \subpage database_dumps
 * \li \subpage postgresql_installation
 */

/**
 * \page baseten_enabling Enabling relations for use with BaseTen
 *
 * Some tables are created in BaseTen schema to track changes in other relations and storing relationships
 * between tables and views. The association is based on relation names.
 *
 * While this arrangement allows clients to fault only changed objects, it has some unfortunate side effects:
 * \li Altering relations' names after having them enabled will not work. To rename relations, they need
 *     to be disabled first and re-enabled afterwards.
 * \li Altering relations' primary keys will not work. Again, disabling and re-enabling is required.
 * \li Altering relations' foreign keys causes BaseTen's relationship information to become out-of-date
 *     and needing to be refreshed.
 *
 * All this can be done using BaseTen Assistant.
 *
 * \note In version 1.5, relations and BaseTen's tables were associated with each other based on relation
 *       names. This didn't work for all names, though, and made renaming enabled relations impossible.
 *       In versions 1.6 through 1.6.2, the association was based on relation oids. While this made 
 *       renaming relations possible, it also made dumping database contents exceedingly difficult.
 *
 *
 * \section sql_enabling Enabling relations and updating relationship cache using SQL functions
 *
 * In addition to using BaseTen Assistant, it is possible to enable and disable tables with SQL functions.
 * The functions are <em>baseten.enable (oid)</em> and <em>baseten.disable (oid)</em>. The object identifier
 * argument can be looked up from PostgreSQL's system tables, <em>pg_class</em> and <em>pg_namespace</em>.
 *
 * Views' primary keys are stored in <em>baseten.view_pkey</em>. The table has three columns: <em>nspname</em>, 
 * <em>relname</em> and <em>attname</em>, which correspond to the view's schema name, the view's name and each primary 
 * key column's name respectively. To enable a view, its primary key needs to be specified first.
 *
 * Relationships and view hierarchies among other things are stored in automatically-generated tables. 
 * These should be refreshed with the SQL function <em>baseten.refresh_caches ()</em> after all changes to views,
 * primary keys and foreign keys.
 */

/**
 * \page database_dumps Making a database dump
 *
 * After having been in use, the BaseTen schema might contain some temporary information. The temporary information is removed periodically when the 
 * database is queried, but for creating installation scripts it might be desirable to remove all unnecessary data. This can be done from BaseTen 
 * Assistant or by running the SQL function <em>baseten.prune ()</em>.
 *
 * For BaseTen schema to work, the table contents for most tables are needed, so dumps excluding the data are not recommended.
 */

/**
 * \page postgresql_installation PostgreSQL installation
 *
 * PostgreSQL is distributed as an Installer package at the following address:<br>
 * http://www.postgresql.org/download/macosx
 * Another option is to build the server from source. Here's a brief tutorial.
 * <ol>
 *     <li>Get the latest PostgreSQL source release (8.2 or later) from http://www.postgresql.org/ftp/source.</li>
 *     <li>Uncompress, configure, make, [sudo] make install. On Mac OS X, Bonjour and OpenSSL are available, so <tt>./configure &ndash;-with-bonjour &ndash;-with-openssl && make && sudo make install</tt> probably gives the expected results.</li>
 *     <li>It's usually a good idea to create a separate user and group for PostgreSQL, but Mac OS X already comes with a database-specific user: for mysql. We'll just use that and hope PostgreSQL doesn't mind.</li>
 *     <li>Make <em>mysql</em> the owner of the PostgreSQL folder, then sudo to <em>mysql</em>:\n
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
 *         <tt>/usr/local/pgsql/bin/createuser <em>your-short-user-name</em></tt>
 *     </li>
 *     <li>Exit the <em>mysql</em> sudo and create a database. If you create a database with your short user name, psql will connect to it by default.\n
 *         <tt>
 *             exit\n
 *             /usr/local/pgsql/bin/createdb <em>your-short-user-name</em>
 *         </tt>
 *     </li>
 * </ol>
 */
