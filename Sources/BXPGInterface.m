//
// BXPGInterface.m
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

#import <PGTS/PGTS.h>
#import <PGTS/PGTSFunctions.h>
#import <PGTSTiger/PGTSTiger.h>
#import <TSDataTypes/TSDataTypes.h>
#import <Foundation/Foundation.h>
#import <Log4Cocoa/Log4Cocoa.h>

#import "BXPGInterface.h"
#import "BXDatabaseObject.h"
#import "BXDatabaseObjectPrivate.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseContextPrivate.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXEntityDescription.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXConstants.h"
#import "BXPropertyDescription.h"
#import "BXRelationshipDescription.h"
#import "BXArrayProxy.h"
#import "BXOneToOneRelationshipDescription.h"
#import "BXHelperTableMTMRelationshipDescription.h"
#import "BXRelationshipDescriptionProtocol.h"
#import "BXException.h"
#import "BXPGCertificateVerificationDelegate.h"
#import "BXPropertyDescriptionPrivate.h"


static unsigned int savepointIndex;
static NSString* SavepointQuery ()
{
    savepointIndex++;
    return [NSString stringWithFormat: @"SAVEPOINT BXPGSavepoint%u", savepointIndex];
}

static NSString* RollbackToSavepointQuery ()
{
    NSCAssert (0 < savepointIndex, @"savepointIndex should be greater than zero.");
	savepointIndex--;
    NSString* rval = [NSString stringWithFormat: @"ROLLBACK TO SAVEPOINT BXPGSavepoint%u", savepointIndex];
    return rval;
}

static void ResetSavepointIndex ()
{
    savepointIndex = 0;
}

static unsigned int SavepointIndex ()
{
    return savepointIndex;
}

static NSString* SSLMode (enum BXSSLMode mode)
{
	NSString* rval = @"require";
	if (kBXSSLModeDisable == mode)
		rval = @"disable";
	return rval;
}


@interface PGTSForeignKeyDescription (BXPGInterfaceAdditions)
- (BXRelationshipDescription *) BXPGRelationshipFromEntity: (BXEntityDescription *) srcEntity
                                                      toEntity: (BXEntityDescription *) dstEntity;
@end


@interface NSArray (BXPGInterfaceAdditions)
- (NSArray *) BXPGEscapedNames: (PGTSConnection *) connection;
@end


@implementation NSString (BXPGAdditions)
- (NSArray *) BXPGKeyPathComponents
{
    return [self BXKeyPathComponentsWithQuote: @"\""];
}
@end


@implementation BXDatabaseObject (BXPGInterfaceAdditions)
- (void) PGTSSetRow: (int) row resultSet: (PGTSResultSet *) res
{
    [res goToRow: row];
    [self setCachedValuesForKeysWithDictionary: [res currentRowAsDictionary]];
}
@end


@implementation BXEntityDescription (BXPGInterfaceAdditions)
- (NSString *) BXPGQualifiedName: (PGTSConnection *) connection
{
    return [NSString stringWithFormat: @"\"%@\".\"%@\"", 
        [[self schemaName] PGTSEscapedString: connection], [[self name] PGTSEscapedString: connection]];
}
@end


@implementation BXPropertyDescription (BXPGInterfaceAdditions)
- (NSString *) BXPGQualifiedName: (PGTSConnection *) connection
{
    return [NSString stringWithFormat: @"%@.%@", 
        [[self entity] BXPGQualifiedName: connection], [self BXPGEscapedName: connection]];
}

- (NSString *) BXPGEscapedName: (PGTSConnection *) connection
{
    return [NSString stringWithFormat: @"\"%@\"", [[self name] PGTSEscapedString: connection]];
}

- (id) PGTSConstantExpressionValue: (NSMutableDictionary *) context
{
    PGTSConnection* connection = [context objectForKey: kPGTSConnectionKey];
    log4AssertValueReturn (nil != connection, nil, @"Expected connection not to be nil.");
    return [self BXPGQualifiedName: connection];
}
@end


@implementation NSArray (BXPGInterfaceAdditions)
- (NSArray *) BXPGEscapedNames: (PGTSConnection *) connection
{
    NSMutableArray* rval = [NSMutableArray arrayWithCapacity: [self count]];
    TSEnumerate (currentDesc, e, [self objectEnumerator])
    {
        log4AssertValueReturn ([currentDesc isKindOfClass: [BXPropertyDescription class]], nil, 
							   @"Expected to have only BXPropertyDescriptions (%@).", self);
        [rval addObject: [currentDesc BXPGEscapedName: connection]];
    }
    return rval;
}
@end



@implementation PGTSForeignKeyDescription (BXPGInterfaceAdditions)
- (BXRelationshipDescription *) BXPGRelationshipFromEntity: (BXEntityDescription *) srcEntity
												  toEntity: (BXEntityDescription *) dstEntity
{
    NSArray* srcFields = [self sourceFields];
    NSArray* dstFields = [self referenceFields];
    NSMutableArray *srcProperties = nil, *dstProperties = nil;
    
    unsigned int count = [srcFields count];
    log4AssertValueReturn (count == [dstFields count], nil, @"Expected counts to match (srcFields: %@ dstFields: %@).", srcFields, dstFields);
    srcProperties = [NSMutableArray arrayWithCapacity: count];
    dstProperties = [NSMutableArray arrayWithCapacity: count];
	
	log4AssertValueReturn ([srcEntity isValidated] && [dstEntity isValidated], nil, 
						   @"Expected entities to have been validated (src: %@ dst: %@).", srcEntity, dstEntity);
	NSDictionary* srcAttributes = [srcEntity attributesByName];
	NSDictionary* dstAttributes = [dstEntity attributesByName];
    
    for (unsigned int i = 0; i < count; i++)
    {
		id p1 = [srcAttributes objectForKey: [[srcFields objectAtIndex: i] name]];
		id p2 = [dstAttributes objectForKey: [[dstFields objectAtIndex: i] name]];
        [srcProperties addObject: p1];
        [dstProperties addObject: p2];
    }
    
    return [BXRelationshipDescription relationshipWithName: [self name] srcProperties: srcProperties 
                                                dstProperties: dstProperties];
}
@end


@implementation BXPGInterface

+ (void) initialize
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        [BXDatabaseContext setInterfaceClass: [self class] forScheme: @"pgsql"];        
    }
}

- (id) initWithContext: (BXDatabaseContext *) aContext
{
    if ((self = [super init]))
    {
        context = aContext; //Weak
        autocommits = YES;
        logsQueries = NO;
        clearedLocks = NO;
        state = kBXPGQueryIdle;
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    PGTSDatabaseInfo* dbInfo = [connection databaseInfo];
    TSEnumerate (currentEntity, e, [[context seenEntities] objectEnumerator])
    {
        PGTSTableInfo* tableInfo = [dbInfo tableInfoForTableNamed: [currentEntity name] inSchemaNamed: [currentEntity schemaName]];
		if (nil != tableInfo)
		{
			[modificationNotifier removeObserver: self table: tableInfo notificationName: kPGTSInsertModification];
			[modificationNotifier removeObserver: self table: tableInfo notificationName: kPGTSUpdateModification];
			[modificationNotifier removeObserver: self table: tableInfo notificationName: kPGTSDeleteModification];
			[lockNotifier removeObserver: self table: tableInfo notificationName: kPGTSLockedForUpdate];
			[lockNotifier removeObserver: self table: tableInfo notificationName: kPGTSLockedForDelete];
			[lockNotifier removeObserver: self table: tableInfo notificationName: kPGTSUnlockedRowsNotification];
		}
    }
    [modificationNotifier release];
    [lockNotifier release];
    if (NO == clearedLocks && [notifyConnection connected])
    {
        clearedLocks = YES;
        [notifyConnection executeQuery: @"SELECT baseten.ClearLocks ()"];
    }
    [notifyConnection setDelegate: nil];
    [notifyConnection disconnect];
    [notifyConnection endWorkerThread];
    [notifyConnection release];

    [connection setDelegate: nil];
    [connection disconnect];
    [connection endWorkerThread];
    [connection release];
	
	[cvDelegate release];
     
    [locker release];
    [databaseURI release];
    [super dealloc];
}

- (void) setDatabaseURI: (NSURL *) anURI
{
    if (databaseURI != anURI)
    {
        [databaseURI release];
        databaseURI = [anURI retain];
    }
}

- (void) connect: (NSError **) error
{
	enum BXSSLMode mode = [context sslMode];
	[self prepareConnection: mode];
	[connection connect];
	[self checkConnectionStatus: error];
	
	if (NO == invalidCertificate && nil != *error && mode == kBXSSLModePrefer)
	{
		*error = nil;
		[self prepareConnection: kBXSSLModeDisable];
		[connection connect];
		[self checkConnectionStatus: error];
	}
	
	[self setDatabaseURI: nil];
}

- (void) connectAsync: (NSError **) error
{
	[self prepareConnection: [context sslMode]];
	[self setDatabaseURI: nil];
	[connection connectAsync];
}

- (void) disconnect
{
	if (CONNECTION_OK != [connection connectionStatus])
		[connection disconnect];
}

- (NSArray *) executeQuery: (NSString *) queryString error: (NSError **) error
{
	NSArray* rval = nil;
	PGTSResultSet* res = [connection executeQuery: queryString];
	if (YES == [res querySucceeded])
		rval = [res resultAsArray];
	else
	{
		*error = [NSError errorWithDomain: kBXErrorDomain
									 code: kBXErrorUnsuccessfulQuery
								 userInfo: nil];
	}
	return rval;
}

- (unsigned long long) executeCommand: (NSString *) commandString error: (NSError **) error;
{
	int rval = 0;
	PGTSResultSet* res = [connection executeQuery: commandString];
	if (YES == [res querySucceeded])
		rval = [res numberOfRowsAffectedByCommand];
	else
	{
		*error = [NSError errorWithDomain: kBXErrorDomain
									 code: kBXErrorUnsuccessfulQuery
								 userInfo: nil];		
	}
	return rval;
}

- (id) createObjectForEntity: (BXEntityDescription *) entity 
             withFieldValues: (NSDictionary *) valueDict
                       class: (Class) aClass 
                       error: (NSError **) error;
{
    PGTSResultSet* res = nil;
    id rval = nil;
    NSArray* fields = [valueDict allKeys];
    NSArray* fieldNames = [fields BXPGEscapedNames: connection];
    NSArray* fieldValues = [valueDict objectsForKeys: fields notFoundMarker: nil];

    log4AssertValueReturn (NULL != error, nil, @"Expected error to be set (was %p)", error);
    log4AssertValueReturn (NO == [connection overlooksFailedQueries], nil, @"Connection should throw when a query fails");
    @try
    {
		[self beginIfNeeded];
		
        //This is needed if the entity is passed from one context to another.
        if (nil != [self validateEntity: entity error: error])
		{
			//Inserted values
			NSString* queryFormat = nil;
			if (0 == [valueDict count])
				queryFormat = [NSString stringWithFormat: @"INSERT INTO %@ DEFAULT VALUES RETURNING %%@", [entity BXPGQualifiedName: connection]];
			else
			{
				queryFormat = [NSString stringWithFormat: @"INSERT INTO %@ (%@) VALUES (%@) RETURNING %%@",
					[entity BXPGQualifiedName: connection], (nil == fieldNames ? @"" : [fieldNames componentsJoinedByString: @", "]), 
					[NSString PGTSFieldAliases: [fieldNames count]]];
			}
			
			//Returned values
			NSArray* pkeyfields = [entity primaryKeyFields];
			NSMutableArray* pkeyQNames = [NSMutableArray arrayWithCapacity: [pkeyfields count]];            
			TSEnumerate (currentField, e, [pkeyfields objectEnumerator])
				[pkeyQNames addObject: [currentField BXPGEscapedName: connection]];			
			NSMutableArray* remainingFields = [NSMutableArray arrayWithArray: pkeyQNames];
			TSEnumerate (currentField, e, [fields objectEnumerator])
			{
				if (![currentField isExcluded])
					[remainingFields addObject: [currentField BXPGEscapedName: connection]];
			}

			//Make the query
			queryFormat = [NSString stringWithFormat: queryFormat, [remainingFields componentsJoinedByString: @", "]];
			res = [connection executeQuery: queryFormat parameterArray: fieldValues];
			
			//If registration fails, there should be a suitable object in memory.
			[res setRowClass: aClass];
			[res advanceRow];
			rval = [res currentRowAsObject];
			if (NO == [rval registerWithContext: context entity: entity])
				rval = [context registeredObjectWithID: [rval objectID]];
			[rval faultKey: nil];
		}
    }
    @catch (PGTSQueryException* exception)
    {
        [self packPGError: error exception: exception];
    }
    
    return rval;
}

- (NSMutableArray *) executeFetchForEntity: (BXEntityDescription *) entity 
                             withPredicate: (NSPredicate *) predicate 
                           returningFaults: (BOOL) returnFaults 
                                     class: (Class) aClass 
                                     error: (NSError **) error
{
	return [self executeFetchForEntity: entity withPredicate: predicate returningFaults: returnFaults 
								 class: aClass forUpdate: NO error: error];
}

- (NSMutableArray *) executeFetchForEntity: (BXEntityDescription *) entity 
                             withPredicate: (NSPredicate *) predicate 
                           returningFaults: (BOOL) returnFaults 
                                     class: (Class) aClass
								 forUpdate: (BOOL) forUpdate
                                     error: (NSError **) error
{
    NSMutableArray* rows = nil;
    log4AssertValueReturn (NO == [connection overlooksFailedQueries], nil, @"Connection should throw when a query fails");
    log4AssertValueReturn (NULL != error, nil, @"Expected error to be set (was %p)", error);
	log4AssertValueReturn (Nil != aClass, nil, @"Expected class to be set.");

    //Begin the exception handling context, since the metadata queries might also fail
    @try
    {
		PGTSTableInfo* tableInfo = [self validateEntity: entity error: error];
		if (nil != tableInfo)
		{        
			//Get the primary key
			NSArray* pkeyfields = [entity primaryKeyFields];
			
			//While we're at it, set the fields as well
			NSArray* pkeyFNames = [pkeyfields valueForKey: @"name"];
			NSArray* fields = [entity fields];
			
			//Execute the query
			log4AssertValueReturn (nil != pkeyfields, nil, @"Expected pkeyfields not to be nil (entity: %@).", entity);
			
			{
				unsigned int count = [pkeyfields count];
				NSMutableArray* pkeyQNames = [NSMutableArray arrayWithCapacity: count];            
				TSEnumerate (currentField, e, [pkeyfields objectEnumerator])
					[pkeyQNames addObject: [currentField BXPGQualifiedName: connection]];
				
				//What to query
				NSString* queryFields = nil;
				if (YES == returnFaults)
					queryFields = [pkeyQNames componentsJoinedByString: @", "];
				else
				{
					NSMutableArray* remainingFields = [NSMutableArray arrayWithArray: pkeyQNames];
					TSEnumerate (currentField, e, [fields objectEnumerator])
					{
						if (![currentField isExcluded])
							[remainingFields addObject: [currentField BXPGQualifiedName: connection]];
					}
					queryFields = [remainingFields componentsJoinedByString: @", "];
				}            
				
				//Make sure that the where clause contains at least something, so the query is easier to format.
				NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
				NSString* whereClause = [predicate PGTSWhereClauseWithContext: ctx];
				if (nil == whereClause)
					whereClause = @"(true)";
				
				//FROM clause
				NSString* fromClause = nil;
				{
					NSMutableSet* entitySet = [NSMutableSet setWithSet: [predicate BXEntitySet]];
					log4AssertValueReturn (nil != entitySet, nil, @"Expected to receive an entity set (predicate: %@).", predicate);
					[entitySet addObject: entity];
					NSMutableArray* components = [NSMutableArray arrayWithCapacity: [entitySet count]];
					TSEnumerate (currentEntity, e, [entitySet objectEnumerator])
						[components addObject: [currentEntity BXPGQualifiedName: connection]];
					fromClause = [components componentsJoinedByString: @", "];
					log4AssertValueReturn (nil != fromClause, nil, @"Expected to have a from clause (predicate: %@).", predicate);
				}
				
				//Make the query
				NSString* queryFormat = @"SELECT %@ FROM %@ WHERE %@";
				if (YES == forUpdate)
					queryFormat = @"SELECT %@ FROM %@ WHERE %@ FOR UPDATE";
				NSString* query = [NSString stringWithFormat: queryFormat, queryFields, fromClause, whereClause];
				
				//Execute the query
				NSArray* parameters = [ctx objectForKey: kPGTSParametersKey];
				PGTSResultSet* res = [connection executeQuery: query parameterArray: parameters];
				
				//Handle the result
				rows = [NSMutableArray arrayWithCapacity: [res countOfRows]];
				
				[res setRowClass: aClass];
				[res goBeforeFirstRow];
				while (([res advanceRow]))
				{
					BXDatabaseObject* currentRow = [res currentRowAsObject];
					
					//If the object is already in memory, don't make a copy
					if (NO == [currentRow registerWithContext: context entity: entity])
						currentRow = [context registeredObjectWithID: [currentRow objectID]];
					if (YES == returnFaults)
						[currentRow faultKey: nil];
					[rows addObject: currentRow];
				}
				
				//Lock status
				//FIXME: does lock status for the referenced tables get correctly determined?
				NSSet* usedEntities = [predicate BXEntitySet];
				NSMutableArray* fromItems = [NSMutableArray arrayWithCapacity: [usedEntities count]];
				TSEnumerate (currentEntity, e, [usedEntities objectEnumerator])
				{
					if (! ([[currentEntity name] isEqualToString: [tableInfo name]] && 
						   [[currentEntity schemaName] isEqualToString: [tableInfo schemaName]]))
						[fromItems addObject: [currentEntity BXPGQualifiedName: connection]];
				}
				NSArray* locks = [lockNotifier locksForTable: tableInfo fromItems: fromItems whereClause: whereClause parameters: parameters];
				NSDictionary* translationDict = [NSDictionary dictionaryWithObjects: pkeyfields forKeys: pkeyFNames];
				TSEnumerate (currentLock, e, [locks objectEnumerator])
				{
					NSDictionary* pkey = [currentLock BXTranslateUsingKeys: translationDict];
					BXDatabaseObjectID* objectID = [BXDatabaseObjectID IDWithEntity: entity
																   primaryKeyFields: pkey];
					BXDatabaseObject* object = [context registeredObjectWithID: objectID];
					[object setLockedForKey: nil]; //TODO: set the key accordingly
				}
			}
		}
    }
    @catch (BXException* exception)
    {
        [self packError: error exception: exception];
    }
    @catch (PGTSQueryException* exception)
    {
        [self packPGError: error exception: exception];
    }
    
    return rows;
}

- (BOOL) fireFault: (BXDatabaseObject *) anObject keys: (NSArray *) keys error: (NSError **) error
{
    BOOL rval = NO;
    log4AssertValueReturn (NULL != error, NO, @"Expected error to be set.", error);
	log4AssertValueReturn (nil != keys && 0 < [keys count], NO, @"Expected to have received some keys to fetch.");
    @try
    {
        BXDatabaseObjectID* objectID = [anObject objectID];
        NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
		NSMutableArray* escapedKeys = [NSMutableArray arrayWithCapacity: [keys count]];
		TSEnumerate (currentKey, e, [keys objectEnumerator])
			[escapedKeys addObject: [currentKey BXPGEscapedName: connection]];
        NSString* query = [NSString stringWithFormat: @"SELECT %@ FROM %@ WHERE %@", 
			[escapedKeys componentsJoinedByString: @", "],
			[[objectID entity] BXPGQualifiedName: connection],
			[[objectID predicate] PGTSWhereClauseWithContext: ctx]];
        PGTSResultSet* res = [connection executeQuery: query parameterArray: [ctx objectForKey: kPGTSParametersKey]];
        if (YES == [res advanceRow])
        {
            rval = YES;
            [anObject setCachedValuesForKeysWithDictionary: [res currentRowAsDictionary]];
        }
    }
    @catch (PGTSException* exception)
    {
        [self packPGError: error exception: exception];
    }
    return rval;
}

- (NSArray *) executeUpdateWithDictionary: (NSDictionary *) aDict
                                 objectID: (BXDatabaseObjectID *) objectID
                                   entity: (BXEntityDescription *) entity
                                predicate: (NSPredicate *) predicate
                                    error: (NSError **) error
{
    log4AssertValueReturn (NO == [connection overlooksFailedQueries], nil, @"Connection should throw when a query fails");
    log4AssertValueReturn (objectID || entity, nil, @"Expected to be called either with the objectID or with an entity.");
    log4AssertValueReturn (NULL != error, nil, @"Expected error to be set (was %p)", error);
    NSString* queryString = nil;
    
    NSArray* rval = nil;
    @try
    {   
        //Check for a previously locked row
        if (nil != lockedObjectID)
        {
            log4AssertValueReturn (nil == objectID || objectID == lockedObjectID, nil, 
								   @"Expected modified object to match the locked one.\n\t%@ \n\t%@",
								   objectID, lockedObjectID);
            
            //The run loop probably hasn't ran yet, if we don't have the transaction.
            if ((PQTRANS_INTRANS != [connection transactionStatus]))
            {
                struct timeval tv = [connection timeout];
                NSDate* date = [NSDate dateWithTimeIntervalSinceNow: tv.tv_usec + tv.tv_sec];
                BOOL runLoopRan = NO;
                do
                    runLoopRan = [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate: date] || runLoopRan;
                while (! (PQTRANS_INTRANS == [connection transactionStatus] || [date timeIntervalSinceNow] < 0));
                log4AssertValueReturn (YES == runLoopRan, nil, @"Expected to have runloop run.");
            }
        }
		
        if (nil != objectID)
        {
            predicate = [objectID predicate];
            entity = [objectID entity];
        }
		
		[self beginIfNeeded];
		
		//This is needed if the entity is passed from one context to another.
        if (nil != [self validateEntity: entity error: error])
		{
			NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
			NSString* whereClause = [predicate PGTSWhereClauseWithContext: ctx];
			NSMutableArray* parameters = [ctx objectForKey: kPGTSParametersKey];
			if (nil == whereClause)
				whereClause = @"(true)";
            if (nil == parameters)
				parameters = [NSMutableArray array];

			NSArray* pkeyFields = [entity primaryKeyFields];
			NSArray* pkeyFNames = [pkeyFields valueForKey: @"name"];
			NSDictionary* translationDict = [NSDictionary dictionaryWithObjects: pkeyFields forKeys: pkeyFNames];        
			NSString* name = [entity BXPGQualifiedName: connection];
			
			//Check if pkey should be updated
			BOOL updatedPkey = NO;
			NSArray* objectIDs = nil;
			if (nil != [pkeyFNames firstObjectCommonWithArray: [aDict allKeys]])
			{
				updatedPkey = YES;

				//Transaction for locking the rows (?)
				if (YES == autocommits)
					[self beginSubtransactionIfNeeded];
				
				//Since we are reading committed changes, SELECT the object IDs FOR UPDATE.
				NSArray* res = [self executeFetchForEntity: entity withPredicate: predicate returningFaults: YES
													 class: [entity databaseObjectClass] forUpdate: YES error: error];
				objectIDs = [res valueForKey: @"objectID"];
			}
			
			if (nil == *error)
			{
				//Send the UPDATE query
				queryString = [NSString stringWithFormat: @"UPDATE %@ SET %@ WHERE %@ RETURNING %@", 
					name, [aDict PGTSSetClauseParameters: parameters], whereClause,
					[[[entity primaryKeyFields] BXPGEscapedNames: connection] componentsJoinedByString: @", "]];
				PGTSResultSet* res = [connection executeQuery: queryString parameterArray: parameters];
				
				//Notify only if we are not updating a view.
				if (NO == [entity isView])
					[self lockAndNotifyForEntity: entity whereClause: whereClause parameters: parameters willDelete: NO];        
				
				//FIXME: if we are continuously updating the value in autocommit mode, we are going to lose the lock here.
				//See -lockObject:key:lockType:sender:
				[self endSubtransactionIfNeeded]; 
				
				//Handle the result and get new pkey values
				NSDictionary* pkeyDict = nil;
				if (YES == updatedPkey)
				{
					if (1 == [objectIDs count])
					{                
						//If 1 == [objectIDs count], then information about last modification 
						//can be used, since the modification is unambiguous.
						NSDictionary* lastModification = [[self lastModificationForEntity: entity] objectForKey: kPGTSRowsKey];
						NSArray* pkeyFValues = [lastModification objectsForKeys: pkeyFNames
																 notFoundMarker: nil];
						pkeyDict = [NSDictionary dictionaryWithObjects: pkeyFValues forKeys: pkeyFields];
					}
					else
					{
						//Updating the primary key is safer to do one by one, since now
						//we don't check the values from the database.
						pkeyDict = [aDict BXTranslateUsingKeys: translationDict];
					}
				}
				else
				{
					//Otherwise get the ids from the result
					NSMutableArray* ids = [NSMutableArray arrayWithCapacity: [res countOfRows]];
					log4AssertValueReturn (nil != entity, nil, @"Expected entity not to be nil.");
					while (([res advanceRow]))
					{
						BXDatabaseObjectID* currentID = [BXDatabaseObjectID IDWithEntity: entity primaryKeyFields:
							[[res currentRowAsDictionary] BXTranslateUsingKeys: translationDict]];
						[ids addObject: currentID];
					}
					rval = ids;
					objectIDs = ids;
				}
				
				//Update the object
				//Also mark the objects locked        
				TSEnumerate (currentID, e, [objectIDs objectEnumerator])
				{
					BXDatabaseObject* object = [context registeredObjectWithID: currentID];
					if (nil != object)
					{
						[object setCachedValuesForKeysWithDictionary: aDict];
						//Object ID remembers the pkey
						[object removePrimaryKeyValuesFromStore];
						
						//Update the object ID. 
						if (nil != pkeyDict)
						{
							[context unregisterObject: object];
							[currentID replaceValuesWith: pkeyDict];
							[context registerObject: object];
						}
					}
				}
			}
		}
	}
	@catch (BXException* exception)
    {
        [self packError: error exception: exception];
    }
    @catch (PGTSException* exception)
    {
        [self packPGError: error exception: exception];
    }
    return rval;    
}

- (NSArray *) executeDeleteObjectWithID: (BXDatabaseObjectID *) objectID 
                                 entity: (BXEntityDescription *) entity 
                              predicate: (NSPredicate *) predicate 
                                  error: (NSError **) error
{
    NSArray* rval = nil;
    log4AssertValueReturn (NO == [connection overlooksFailedQueries], nil, @"Connection should throw when a query fails");
    log4AssertValueReturn (objectID || entity, nil, @"Expected to be called either with an objectID or with an entity.");
    log4AssertValueReturn (NULL != error, nil, @"Expected error to be set (was %p)", error);
    @try
    {
		[self beginIfNeeded];

        if (nil != objectID)
        {
            entity = [objectID entity];
            predicate = [objectID predicate];
        }
		
        //This is needed if the entity is passed from one context to another.
        if (nil != [self validateEntity: entity error: error])
		{
			NSString* name = [entity BXPGQualifiedName: connection];
			NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
			NSString* whereClause = [predicate PGTSWhereClauseWithContext: ctx];
			NSArray* parameters = [ctx objectForKey: kPGTSParametersKey];
			if (nil == whereClause)
				whereClause = @"(true)";
            if (nil == parameters)
				parameters = [NSMutableArray array];
			
			//Notify only if we are not updating a view.
			if (NO == [entity isView])
				[self lockAndNotifyForEntity: entity whereClause: whereClause parameters: parameters willDelete: YES];
			
			NSString* pkeyFNames = [[[entity primaryKeyFields] BXPGEscapedNames: connection] componentsJoinedByString: @", "];
			NSString* queryString = [NSString stringWithFormat: @"DELETE FROM %@ WHERE %@ RETURNING %@", name, whereClause, pkeyFNames];
			PGTSResultSet* res = [connection executeQuery: queryString parameterArray: parameters];
			
			NSMutableArray* objectIDs = [NSMutableArray arrayWithCapacity: [res countOfRows]];
			NSArray* pkeyfields = [entity primaryKeyFields];
			NSDictionary* translationDict = [NSDictionary dictionaryWithObjects: pkeyfields forKeys: [pkeyfields valueForKey: @"name"]];
			while ([res advanceRow])
			{
				NSDictionary* pkey = [[res currentRowAsDictionary] BXTranslateUsingKeys: translationDict];
				BXDatabaseObjectID* objectID = [BXDatabaseObjectID IDWithEntity: entity
															   primaryKeyFields: pkey];
				[objectIDs addObject: objectID];
			}
			
			log4AssertLog (nil == objectID || (1 == [objectIDs count] && [objectIDs containsObject: objectID]),
						   @"Expected to have deleted only one row. \nobjectID: %@\npredicate: %@\nObjectIDs: %@",
						   objectID, predicate, objectIDs);
			
			rval = objectIDs;
		}
    }
    @catch (BXException* exception)
    {
        [self packError: error exception: exception];
    }
    @catch (PGTSException* exception)
    {
        [self packPGError: error exception: exception];
    }
    
    return rval;
}

/**
 * \internal
 * Rollback the transaction.
 * Use internalRollback instead of this within BXPGInterface.
 */
- (void) rollback
{
    if ([self connected])
    {
        log4AssertLog (NO == [connection overlooksFailedQueries], @"Connection should throw when a query fails");
        @try
        {
            [self internalRollback];
        }
        @catch (id exception)
        {
            log4Error (@"Exception caught during ROLLBACK: %@", exception);
        }
    }
}

- (BOOL) save: (NSError **) error
{
    BOOL rval = NO;
    log4AssertLog (NULL != error, @"Expected error to be set.", error);
    if ([self connected])
    {
        log4AssertLog (NO == [connection overlooksFailedQueries], @"Connection should throw when a query fails.");
        @try
        {
            [self internalCommit];
            rval = YES;
        }
        @catch (PGTSQueryException* exception)
        {
            [self packPGError: error exception: exception];
        }
    }
    else
    {
        rval = YES;
    }
    return rval;    
}

- (NSArray *) relationshipsWithEntity: (BXEntityDescription *) srcEntity
							   entity: (BXEntityDescription *) givenDSTEntity
								types: (enum BXRelationshipType) typeBitmap
								error: (NSError **) error
{    
    log4AssertValueReturn (nil != srcEntity, nil, @"Expected to have srcEntity.");
    log4AssertValueReturn (NULL != error, nil, @"Expected error to be set.");
    
	NSMutableArray* rval = nil;
	
    NSMutableArray* types = [NSMutableArray arrayWithObject: @"t"];
    if (typeBitmap == kBXRelationshipUndefined || typeBitmap & kBXRelationshipOneToOne)
        [types addObject: @"o"];
    if (typeBitmap == kBXRelationshipUndefined || typeBitmap & kBXRelationshipManyToMany)
        [types addObject: @"m"];
    
    //FIXME: these could be stored procedures or something
    NSString* query = nil;
    if (nil == givenDSTEntity)
    {
        query = 
            @"SELECT conoid, refconoids, type, "
            " srcname, dstname, srcfnames, dstfnames, helperfnames, "
            " srcrelname, srcnspname, dstnspname, dstrelname, "
            " (srcnspname = $1 AND srcrelname = $2) AS should_add_m "
            " FROM baseten.Relationships "
            " WHERE ((srcnspname = $1 AND srcrelname = $2) OR (type = 't')) "
            " AND type = ANY ($3) AND dst_is_pkey = true "
            " ORDER BY type DESC";
    }
    else
    {
        //Here we need all MTO's from the potential helper table to both destination and source
        //as well as from destination to source
        query = 
            @"SELECT conoid, refconoids, type, "
            " srcname, dstname, srcfnames, dstfnames, helperfnames, "
            " srcrelname, srcnspname, dstnspname, dstrelname, "
            " (srcnspname = $1 AND srcrelname = $2) AS should_add_m "
            " FROM baseten.Relationships "
            " WHERE ((srcnspname = $1 AND srcrelname = $2) OR "
            "         (type = 't' AND "
            "          (dstnspname = $1 AND dstrelname = $2) OR "
            "          (dstnspname = $4 AND dstrelname = $5) "
            "         ) "
            "       ) AND type = ANY ($3) AND dst_is_pkey = true "
            " ORDER BY type DESC";
    }
    
	@try
	{
		PGTSResultSet* res = [connection executeQuery: query parameters:
			[srcEntity schemaName], [srcEntity name], types, [givenDSTEntity schemaName], [givenDSTEntity name]];
		
		rval = [NSMutableArray arrayWithCapacity: [res countOfRows]];
		NSMutableDictionary* manyToOne = [NSMutableDictionary dictionary];
		while ([res advanceRow])
		{
			if (nil != *error) break;
			
			unichar type = [[res valueForKey: @"type"] characterAtIndex: 0];
			Class relationshipClass = Nil;
			switch (type)
			{
				case 'o':
					relationshipClass = [BXOneToOneRelationshipDescription class];
					//Fall through on purpose
				case 'm':
				{
					if (Nil == relationshipClass)
						relationshipClass = [BXHelperTableMTMRelationshipDescription class];
					
					NSArray* conoids = [res valueForKey: @"refconoids"];
					NSArray* rels = [manyToOne objectsForKeys: conoids notFoundMarker: [NSNull null]];
					log4AssertValueReturn (NO == [rels containsObject: [NSNull null]], nil, @"Didn't expect NSNulls (rels: %@).", rels);
					log4AssertValueReturn (2 == [rels count], nil, @"Expected to have two objects in rels (found instead: %@).", rels);
					
					id rel = [relationshipClass relationshipWithRelationship1: [rels objectAtIndex: 0]
																relationship2: [rels objectAtIndex: 1]];
					NSString* relationName = [res valueForKey: @"dstname"];
					if ('m' == type)
						[rel setName: relationName];
					[rval addObject: rel];
					break;
				}
				case 't':
				{
					NSNumber* conoid = [res valueForKey: @"conoid"];
					
					//Go through the source columns' names
					NSMutableArray* srcProperties = nil;
					NSMutableArray* dstProperties = nil;
					BXEntityDescription* srcEntity = [context entityForTable: [res valueForKey: @"srcrelname"]
																	inSchema: [res valueForKey: @"srcnspname"]
																	   error: error];
					if (nil != *error)
					{
						//Continue if we were not able to observe the entity.
						if ([kBXErrorDomain isEqualToString: [*error domain]] && kBXErrorObservingFailed == [*error code])
							*error = nil;
						break;
					}
					
					BXEntityDescription* dstEntity = [context entityForTable: [res valueForKey: @"dstrelname"]
																	inSchema: [res valueForKey: @"dstnspname"]
																	   error: error];
					if (nil != *error)
					{
						//Continue we were not able to observe the entity.
						if ([kBXErrorDomain isEqualToString: [*error domain]] && kBXErrorObservingFailed == [*error code])
							*error = nil;
						break;
					}
					
					{
						log4AssertValueReturn ([srcEntity isValidated], nil, @"Expected srcEntity to have been validated.");
						NSArray* srcFNames = [res valueForKey: @"srcfnames"];
						NSDictionary* srcAttributes = [srcEntity attributesByName];
						srcProperties = [NSMutableArray arrayWithCapacity: [srcFNames count]];                
						
						TSEnumerate (currentFName, e, [srcFNames objectEnumerator])
						{
							BXPropertyDescription* desc = [srcAttributes objectForKey: currentFName];
							[srcProperties addObject: desc];
						}
						
						//Use the information supplied by the database, if the user wants all the relationships
						//and not just those between given two tables.
						log4AssertValueReturn ([dstEntity isValidated], nil, @"Expected dstEntity to have been validated.");
						NSDictionary* dstAttributes = [dstEntity attributesByName];
						NSArray* dstFNames = [res valueForKey: @"dstfnames"];
						dstProperties = [NSMutableArray arrayWithCapacity: [dstFNames count]];
						TSEnumerate (currentFName, e, [dstFNames objectEnumerator])
						{
							BXPropertyDescription* desc = [dstAttributes objectForKey: currentFName];
							[dstProperties addObject: desc];
						}
					}
					
					//Now we have enough information to make the relationship object
					NSString* relationName = [res valueForKey: @"srcname"];
					BXRelationshipDescription* rel = 
						[BXRelationshipDescription relationshipWithName: relationName
														  srcProperties: srcProperties 
														  dstProperties: dstProperties];
					
					[manyToOne setObject: rel forKey: conoid];
					
					//Add the object. At this point rval contains only MTO's, 
					//so if we are adding a foreign key from any other table than srcEntity,
					//we only need to check that there isn't one with the same name yet.
					[rval addObject: rel];
					
					break;
				}
				default:
					break;
			}
		}		
	}
	@catch (PGTSException* exception)
	{
		[self packPGError: error exception: exception];
	}
	
	if (NULL != error && nil != *error) rval = nil;
    return rval;
}

/** 
 * Lock an object asynchronously.
 * Lock notifications should always be listened to, since modifications cause the rows to be locked until
 * the end of the ongoing transaction.
 * \note For now, this doesn't work in autocommit mode. See the UPDATE method.
 */
- (void) lockObject: (BXDatabaseObject *) anObject key: (id) aKey lockType: (enum BXObjectLockStatus) type
             sender: (id <BXObjectAsynchronousLocking>) sender
{
	if (NO == autocommits)
	{
		BXDatabaseObjectID* objectID = [anObject objectID];
		BXEntityDescription* entity = [objectID entity];
		
		//There was a strange problem with views in january 2007. This might not be needed in the future.
		if (NO == [entity isView])
		{
			NSString* name = [entity BXPGQualifiedName: connection];
			NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
			NSString* whereClause = [[objectID predicate] PGTSWhereClauseWithContext: ctx];
			
			//Lock the row
			//Transaction for locking the rows (?)
			[self beginIfNeeded];
			//If we supported autocommit, we needed to begin a transaction, 
			//since the lock would be immediately lost otherwise.
			[self beginSubtransactionIfNeeded];
			state = kBXPGQueryBegun;
			[connection sendQuery: [NSString stringWithFormat: @"SELECT NULL FROM %@ WHERE %@ FOR UPDATE NOWAIT;", name, whereClause]
				   parameterArray: [ctx objectForKey: kPGTSParametersKey]];
			state = kBXPGQueryLock;
			
			[self setLockedKey: aKey];
			[self setLockedObjectID: objectID];
		}
	}
}

/**
 * Unlock a locked object synchronously.
 */
- (void) unlockObject: (BXDatabaseObject *) anObject key: (id) aKey
{
    //FIXME: at least conditionally ending a transaction would be needed here when in autocommit mode.
}

- (NSArray *) keyPathComponents: (NSString *) keyPath
{
    return [keyPath BXPGKeyPathComponents];
}

- (BOOL) connected
{
    return [connection connected];
}

- (void) setAutocommits: (BOOL) aBool
{
    if (autocommits != aBool)
    {
        autocommits = aBool;
        if ([self connected])
        {
            log4AssertVoidReturn (NO == [connection overlooksFailedQueries], @"Connection should throw when a query fails");
			PGTransactionStatusType status = [connection transactionStatus];
            if (PQTRANS_IDLE != status)
                [self internalCommit];
        }
    }
}

- (BOOL) autocommits
{
    return autocommits;
}

- (void) setLogsQueries: (BOOL) aBool
{
    logsQueries = aBool;
    [connection setLogsQueries: aBool];
    [notifyConnection setLogsQueries: aBool];
}

- (BOOL) logsQueries
{
    BOOL rval = logsQueries;
    if (nil != connection)
        rval = [connection logsQueries];
    return rval;
}

- (BOOL) messagesForViewModifications
{
    //At the moment this means:
    //"Messages for view modifications that originate from the tables the view is based on."
    return NO;
}

/**
 * \internal
 * Check that the entity exists.
 * Also tell the entity about the pkey and other fields.
 * \note BXPropertyDescriptions should only be created here and in -[BXEntityDescription setPrimaryKeyFields:]
 */
- (id) validateEntity: (BXEntityDescription *) entity error: (NSError **) error
{
    log4AssertValueReturn (NULL != error, nil, @"Expected error to be set.");
    log4AssertValueReturn (nil != notifyConnection, nil, @"Expected notifyConnection to be set.");

    PGTSDatabaseInfo* database = [notifyConnection databaseInfo];
    PGTSTableInfo* tableInfo = [database tableInfoForTableNamed: [entity name] inSchemaNamed: [entity schemaName]];
    if (nil == tableInfo)
    {
        NSString* localizedError = [NSString stringWithFormat: 
            BXLocalizedString (@"tableNotFound", @"Table %@ was not found in schema %@.", @"Error message for fetch"),
            [entity name], [entity schemaName]];
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: 
            BXSafeObj (localizedError), NSLocalizedFailureReasonErrorKey,
            BXSafeObj (localizedError), NSLocalizedRecoverySuggestionErrorKey,
            BXSafeObj (context),        kBXDatabaseContextKey,
            BXSafeObj (entity),         kBXEntityDescriptionKey,
            BXLocalizedString (@"databaseError", @"Database Error", @"Title for a sheet"), NSLocalizedDescriptionKey,
            nil];
        *error = [NSError errorWithDomain: kBXErrorDomain code: kBXErrorNoTableForEntity userInfo: userInfo];
    }
    else
    {
		//Get the primary key
		NSMutableDictionary* attributes = nil;
		NSArray* pkeyfields = [entity primaryKeyFields];
		NSArray* fields = [entity fields];
		if (nil == fields && nil != pkeyfields)
		{
			//Attributes only contains primary key fields and we might not get them from the database.
			attributes = [[[entity attributesByName] mutableCopy] autorelease];
		}
		else if (nil == pkeyfields)
		{
			attributes = [NSMutableDictionary dictionary];
		}
		
		//Attributes won't be set if we have the required information.
		if (nil != attributes)
		{
			if (nil == pkeyfields)
			{
				//Modification observing already requires a primary key. We need the error for views, however.
				PGTSIndexInfo* pkey = [tableInfo primaryKey];
				if (nil == pkey)
				{
					NSString* message = BXLocalizedString (@"noPrimaryKeyFmt", 
														   @"There was no primary key for table %@ in schema %@.", 
														   @"Error description format string");
					message = [NSString stringWithFormat: message, [tableInfo schemaName], [tableInfo name]];
					NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
						self,                kBXDatabaseContextKey,
						BXSafeObj (entity),  kBXEntityDescriptionKey,
						BXLocalizedString (@"databaseError", @"Database Error", @"Title for a sheet"), NSLocalizedDescriptionKey,
						BXSafeObj (message), NSLocalizedFailureReasonErrorKey,
						BXSafeObj (message), NSLocalizedRecoverySuggestionErrorKey,
						nil];
					*error = [NSError errorWithDomain: kBXErrorDomain code: kBXErrorNoPrimaryKey userInfo: userInfo];
				}
				else
				{
					NSArray* pkeyFNames = [[[pkey fields] allObjects] valueForKey: @"name"];
					TSEnumerate (currentFName, e, [pkeyFNames objectEnumerator])
					{
						BXPropertyDescription* desc = [attributes objectForKey: currentFName];
						if (nil == desc)
							desc = [BXPropertyDescription propertyWithName: currentFName entity: entity];
						[desc setOptional: NO];
						[desc setPrimaryKey: YES];
						[attributes setObject: desc forKey: currentFName];
					}
				}
			}
			
			//While we're at it, set the fields as well.
			if (nil == fields)
			{
				TSEnumerate (currentField, e, [[tableInfo allFields] objectEnumerator])
				{
					NSString* currentFName = [currentField name];
					if (nil == [attributes objectForKey: currentFName])
					{
						BXPropertyDescription* desc = [attributes objectForKey: currentFName];
						if (nil == desc)
							desc = [BXPropertyDescription propertyWithName: currentFName entity: entity];
						[desc setOptional: ![currentField isNotNull]];
						[desc setPrimaryKey: NO];
						[attributes setObject: desc forKey: currentFName];
					}
				}
			}
			[entity setAttributes: attributes];
		}
			
        //If the entity is a view, set the dependent entities.
        if ('v' == [tableInfo kind] && nil == [entity entitiesBasedOn])
        {
            NSArray* oidsBasedOn = [tableInfo relationOidsBasedOn];
            NSMutableSet* dependentEntities = [NSMutableSet setWithCapacity: [oidsBasedOn count]];
            TSEnumerate (currentOid, e, [oidsBasedOn objectEnumerator])
            {
                Oid oid = [currentOid PGTSOidValue];
                PGTSTableInfo* dependentTable = [database tableInfoForTableWithOid: oid]; 
                BXEntityDescription* dependentEntity = [context entityForTable: [dependentTable name] 
                                                                      inSchema: [dependentTable schemaName]
                                                                         error: error];
                
                //FIXME: this probably should be done only if needed. If we obsereve a view that references three tables, we get four notifications for each modification.
                [self validateEntity: dependentEntity error: error];
                [dependentEntities addObject: dependentEntity];
            }
            [entity viewIsBasedOnEntities: dependentEntities];
        }
        
        if (nil != *error) tableInfo = nil;
        [self observeIfNeeded: entity error: error];
        if (nil != *error) tableInfo = nil;
    }
    return tableInfo;
}

- (BOOL) establishSavepoint: (NSError **) error
{
	BOOL rval = NO;
	log4AssertValueReturn (NULL != error, NO, @"Expected error to be set.");
	log4AssertValueReturn (PQTRANS_INTRANS == [connection transactionStatus], NO, @"Transaction should be in progress.");
	log4AssertValueReturn (NO == [connection overlooksFailedQueries], NO, @"Connection should throw when a query fails");
	@try
	{
		[connection executeQuery: SavepointQuery ()];
		rval = YES;
	}
    @catch (PGTSQueryException* exception)
    {
        [self packPGError: error exception: exception];
    }
	return rval;
}

- (BOOL) rollbackToLastSavepoint: (NSError **) error
{
	BOOL rval = NO;
	log4AssertValueReturn (NULL != error, NO, @"Expected error to be set.");
	log4AssertValueReturn (NO == [connection overlooksFailedQueries], NO, @"Connection should throw when a query fails");
	@try
	{
		[notifyConnection executeQuery: @"SELECT baseten.LocksStepBack ()"];
		[connection executeQuery: RollbackToSavepointQuery ()];
		rval = YES;
	}
    @catch (PGTSQueryException* exception)
    {
        [self packPGError: error exception: exception];
    }
	return rval;
}

- (void) rejectedTrust
{
	[cvDelegate clearCaches];
}
@end


@implementation BXPGInterface (Helpers)
- (BOOL) observeIfNeeded: (BXEntityDescription *) entity error: (NSError **) error
{
    log4AssertValueReturn (NULL != error, NO, @"Expected error to be set.");
    BOOL rval = NO;
    if (nil == modificationNotifier)
    {
        //PostgreSQL backends don't deliver notifications to interfaces during transactions
        log4AssertValueReturn (connection == notifyConnection || PQTRANS_IDLE == [notifyConnection transactionStatus], NO,
							   @"Connection %p was expected to be in PQTRANS_IDLE (status: %d connection: %p notifyconnection: %p).", 
							   [notifyConnection transactionStatus], connection, notifyConnection);
        
        modificationNotifier = [[PGTSModificationNotifier alloc] init];
        [modificationNotifier setConnection: notifyConnection];
        [modificationNotifier setObservesSelfGenerated: NO];
    }
    if (nil == lockNotifier)
    {
        lockNotifier = [[PGTSLockNotifier alloc] init];
        [lockNotifier setConnection: notifyConnection];
    }
    
    if (YES == [context hasSeenEntity: entity])
        rval = YES;
    else
    {
		PGTSTableInfo* table = [[notifyConnection databaseInfo] tableInfoForTableNamed: [entity name] inSchemaNamed: [entity schemaName]];
		
		{
			SEL selectors [] = {@selector (rowsInserted:), @selector (rowsUpdated:), @selector (rowsDeleted:)};
			NSString* notificationNames [] = {kPGTSInsertModification, kPGTSUpdateModification, kPGTSDeleteModification};
			for (int i = 0; i < 3; i++)
			{
				rval = [modificationNotifier addObserver: self 
												selector: selectors [i] 
												   table: table 
										notificationName: notificationNames [i]];
				if (NO == rval)
					goto bail;
			}
		}
		
		{
			SEL selectors [] = {@selector (rowsLocked:), @selector (rowsLocked:), @selector (rowsUnlocked:)};
			NSString* notificationNames [] = {kPGTSLockedForUpdate, kPGTSLockedForDelete, kPGTSUnlockedRowsNotification};
			for (int i = 0; i < 3; i++)
			{
				rval = [lockNotifier addObserver: self 
										selector: selectors [i]
										   table: table 
								notificationName: notificationNames [i]];
				if (NO == rval)
					goto bail;
			}
		}
		
		[context setHasSeen: YES entity: entity];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector (notifyConnectionWillClose:)
													 name: kPGTSWillDisconnectNotification 
												   object: notifyConnection];
	}
	return rval;

bail:
	if (NULL != error)
	{
		NSString* message = BXLocalizedString (@"observingErrorFmt", 
											   @"Table %@ in schema %@ has not been prepared for modification observing.", 
											   @"Error description format");
		message = [NSString stringWithFormat: message, [entity name], [entity schemaName]];
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			BXSafeObj (context), kBXDatabaseContextKey,
			BXSafeObj (entity),  kBXEntityDescriptionKey,
			BXLocalizedString (@"databaseError", @"Database Error", @"Title for a sheet"), NSLocalizedDescriptionKey,
			BXSafeObj (message), NSLocalizedFailureReasonErrorKey,
			BXSafeObj (message), NSLocalizedRecoverySuggestionErrorKey,
			nil];
		*error = [NSError errorWithDomain: kBXErrorDomain
									 code: kBXErrorObservingFailed
								 userInfo: userInfo];
	}
	return NO;
}

/**
 * \internal
 * Lock rows using SELECT...FOR UPDATE.
 * \note No safety checks in this method.
 */
- (NSArray *) lockRowsWithObjectID: (BXDatabaseObjectID *) objectID 
                            entity: (BXEntityDescription *) entity
                       whereClause: (NSString *) whereClause
                        parameters: (NSArray *) parameters
{
    NSArray* pkeyFields = [entity primaryKeyFields];
    NSArray* pkeyFNames = [pkeyFields valueForKey: @"name"];
    NSDictionary* translationDict = [NSDictionary dictionaryWithObjects: pkeyFields forKeys: pkeyFNames];
    return [self lockRowsWithObjectID: objectID entity: entity pkeyTranslationDict: translationDict
                          whereClause: whereClause parameters: parameters];
}

/**
 * \internal
 * Lock rows using SELECT...FOR UPDATE.
 * \note No safety checks in this method.
 */
- (NSArray *) lockRowsWithObjectID: (BXDatabaseObjectID *) objectID 
                            entity: (BXEntityDescription *) entity
               pkeyTranslationDict: (NSDictionary *) translationDict
                       whereClause: (NSString *) whereClause
                        parameters: (NSArray *) parameters
{
    //objectID is optional
    log4AssertValueReturn (entity && whereClause, nil, @"Expected to be called with parameters.");
    NSArray* rval = nil;
    NSString* name = [entity BXPGQualifiedName: connection];
    if (nil != objectID)
    {
        //We only need to lock the row, since we already know the object ID.
        [connection executeQuery: [NSString stringWithFormat: @"SELECT NULL FROM %@ WHERE %@ FOR UPDATE NOWAIT", name, whereClause]
                  parameterArray: parameters];
        rval = [NSArray arrayWithObject: objectID];
    }
    else
    {
        //We don't yet know the updated objects' IDs.
        NSString* query = [NSString stringWithFormat: @"SELECT %@ FROM %@ WHERE %@ FOR UPDATE NOWAIT", 
            [[translationDict allKeys] componentsJoinedByString: @", "], name, whereClause];
        PGTSResultSet* res = [connection executeQuery: query parameterArray: parameters];
        NSMutableArray* objectIDs = [NSMutableArray arrayWithCapacity: [res countOfRows]];
        while (([res advanceRow]))
        {
            NSDictionary* pkey = [[res currentRowAsDictionary] BXTranslateUsingKeys: translationDict];
            BXDatabaseObjectID* objectID = [BXDatabaseObjectID IDWithEntity: entity
                                                           primaryKeyFields: pkey];
            [objectIDs addObject: objectID];
        }            
        rval = objectIDs;
    }
    return rval;
}

/**
 * Mark objects locked.
 * Assume that the actual locking has been done elsewhere using SELECT...FOR UPDATE or otherwise.
 */
- (void) lockAndNotifyForEntity: (BXEntityDescription *) entity 
                    whereClause: (NSString *) whereClause
                     parameters: (NSArray *) parameters
                     willDelete: (BOOL) willDelete
{
    log4AssertVoidReturn (entity && whereClause, @"Expected to be called with parameters.");
    if (NO == autocommits)
    {
		log4AssertVoidReturn (PQTRANS_IDLE == [notifyConnection transactionStatus], @"Expected notifyConnection not to have transaction.");

        PGTSDatabaseInfo* database = [notifyConnection databaseInfo];
        PGTSTableInfo* table = [database tableInfoForTableNamed: [entity name] inSchemaNamed: [entity schemaName]];
        
        NSString* funcname = [lockNotifier lockFunctionNameForTable: table];
        
        //Lock type
        NSString* format = nil;
        if ((willDelete))
            format = @"SELECT %@ ('D', %u, \"%@\") FROM %@ WHERE %@";
        else
            format = @"SELECT %@ ('U', %u, \"%@\") FROM %@ WHERE %@";
        
        //Get and sort the primary key fields and execute the query
        NSArray* pkeyFields = [[[[table primaryKey] fields] allObjects] sortedArrayUsingSelector: @selector (indexCompare:)];
        log4AssertVoidReturn (nil != pkeyFields, @"Expected to know the primary key.");
        NSArray* pkeyFNames = [pkeyFields valueForKey: @"name"];
        NSString* query = [NSString stringWithFormat: format, funcname, SavepointIndex(),
            [pkeyFNames componentsJoinedByString: @"\", \""], [entity BXPGQualifiedName: notifyConnection], whereClause];

        //No error handling since all this is optional.
		[notifyConnection executeQuery: query parameterArray: parameters];
    }
}

- (void) packPGError: (NSError **) error exception: (PGTSException *) exception
{
    PGTSResultSet* res = [[exception userInfo] objectForKey: kPGTSResultSetKey];
    NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];
    
    NSString* errorMessage = [res errorMessageField: PG_DIAG_MESSAGE_PRIMARY];
    if (nil != errorMessage)
	{
        [userInfo setObject: errorMessage forKey: kBXErrorMessageKey];
        [userInfo setObject: errorMessage forKey: NSLocalizedDescriptionKey];
	}
	
    NSError* placeholder = [NSError errorWithDomain: kBXErrorDomain code: kBXErrorUnsuccessfulQuery userInfo: userInfo];
    
    log4AssertLog (NULL != error, @"Expected error to be set.");
    if (NULL != error)
        *error = placeholder;
}

- (void) packError: (NSError **) error exception: (NSException *) exception
{
    log4AssertLog (NULL != error, @"Expected error to be set.");
    if (NULL != error)
        *error = [[exception userInfo] objectForKey: kBXErrorKey];
}

- (NSDictionary *) lastModificationForEntity: (BXEntityDescription *) entity
{
    id rval = nil;
    NSError* localError = nil;
	[self validateEntity: entity error: &localError];
	if (nil == localError)
    {
        PGTSTableInfo* table = [[notifyConnection databaseInfo] tableInfoForTableNamed: [entity name] inSchemaNamed: [entity schemaName]];
        //Now use the real connection since we need the last modification from its viewpoint
        rval = [modificationNotifier lastModificationForTable: table connection: connection];
    }
	else
	{
		[localError BXExceptionWithName: kBXPGUnableToObserveModificationsException];
	}
    return rval;
}

- (NSArray *) notificationObjectIDs: (NSNotification *) notification relidKey: (NSString *) relidKey
{
    return [self notificationObjectIDs: notification relidKey: relidKey status: NULL];
}

- (NSArray *) notificationObjectIDs: (NSNotification *) notification relidKey: (NSString *) relidKey
                             status: (enum BXObjectLockStatus *) status
{
    NSMutableArray* ids = nil;
    NSDictionary* userInfo = [notification userInfo];
    
    NSArray* rows = [userInfo valueForKey: kPGTSRowsKey];
    unsigned int count = [rows count];
    if (0 < count)
    {
        ids = [NSMutableArray arrayWithCapacity: count];
        TSEnumerate (currentRow, e, [rows objectEnumerator])
        {
            PGTSTableInfo* tableInfo = [[connection databaseInfo] tableInfoForTableWithOid: 
                [[currentRow valueForKey: relidKey] PGTSOidValue]];
            BXEntityDescription* desc = [context entityForTable: [tableInfo name] inSchema: [tableInfo schemaName] error: NULL];
            NSArray* pkeyFields = [desc primaryKeyFields];
            NSMutableDictionary* pkeyValues = [NSMutableDictionary dictionaryWithCapacity: [pkeyFields count]];
            
            TSEnumerate (currentField, e, [pkeyFields objectEnumerator])
                [pkeyValues setValue: [currentRow valueForKey: [currentField name]] forKey: currentField];
            [ids addObject: [BXDatabaseObjectID IDWithEntity: desc primaryKeyFields: pkeyValues]];
        }
        if (NULL != status)
        {
            NSString* statusString = [[rows objectAtIndex: 0] objectForKey: @"baseten_lock_query_type"];
            if ([@"U" isEqualToString: statusString])
                *status = kBXObjectLockedStatus;
            else if ([@"D" isEqualToString: statusString])
                *status = kBXObjectDeletedStatus;
            else
                *status = kBXObjectNoLockStatus;
        }
    }
    return ids;
}

- (BXEntityDescription *) entityForTable: (PGTSTableInfo *) table error: (NSError **) error
{
    log4AssertValueReturn (NULL != error, nil, @"Expected error to be set.");
    return [context entityForTable: [table name] inSchema: [table schemaName] error: error];
}

- (void) prepareConnection: (enum BXSSLMode) mode
{
    if (nil == connection)
    {
        connection = [[PGTSConnection connection] retain];
		cvDelegate = [[BXPGCertificateVerificationDelegate alloc] init];
		cvDelegate->mContext = context;
		cvDelegate->mInterface = self;
		[connection setCertificateVerificationDelegate: cvDelegate];				
        [connection setOverlooksFailedQueries: NO];
		[connection setDelegate: self];
	}
	
	NSMutableDictionary* connectionDict = [databaseURI PGTSConnectionDictionary];
	[connectionDict setValue: SSLMode (mode) forKey: kPGTSSSLModeKey];
	[connection setConnectionDictionary: connectionDict];
	[connection setLogsQueries: logsQueries];

	invalidCertificate = NO;
}

- (void) checkConnectionStatus: (NSError **) error
{
	log4AssertVoidReturn (NULL != error, @"Expected error to be set.", error);
	if (CONNECTION_OK != [connection connectionStatus])
	{
		NSString* errorMessage = [connection errorMessage];
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			errorMessage, NSLocalizedFailureReasonErrorKey,
			errorMessage, NSLocalizedRecoverySuggestionErrorKey,
			errorMessage, kBXErrorMessageKey,
			BXLocalizedString (@"databaseError", @"Database Error", @"Title for a sheet"), NSLocalizedDescriptionKey,
			nil];
		*error = [NSError errorWithDomain: kBXErrorDomain code: kBXErrorConnectionFailed
		   						 userInfo: userInfo];
	}
	else
	{
		if (YES == autocommits)
			notifyConnection = [connection retain];
		else
		{
			//Switch the connections since database metadata is cached and the first connection 
			//to the database gets to be used with the metadata system
			//We want to use notifyConnection with the metadata
			PGTSConnection* tempConnection = [connection disconnectedCopy];
			[tempConnection setLogsQueries: logsQueries];
			[tempConnection setCertificateVerificationDelegate: cvDelegate];
			cvDelegate->mNotifyConnection = tempConnection;
			[tempConnection connect];
			notifyConnection = connection;
			connection = tempConnection;
			log4Debug (@"notifyConnection is %p, backend %d\n", notifyConnection, [notifyConnection backendPID]);                
		}
	}
}
@end


@implementation BXPGInterface (Transactions)

/**
 * \internal
 * Begin a transaction.
 */
- (void) beginIfNeeded
{
	if (NO == autocommits)
	{
		PGTransactionStatusType status = [connection transactionStatus];
		[self beginSubtransactionIfNeeded];
		if (PQTRANS_IDLE == status)
			[connection executeQuery: SavepointQuery ()];
	}
}

- (void) beginSubtransactionIfNeeded
{
	//Exception should get handled by the caller
	log4AssertVoidReturn (NO == [connection overlooksFailedQueries], @"Connection should throw when a query fails.");
	if (PQTRANS_IDLE == [connection transactionStatus])
		[connection executeQuery: @"BEGIN"];	
}

- (void) internalRollback
{
    //The locked key should be cleared in any case to cope with the situation
    //where the lock was acquired  after the last savepoint and the same key 
    //is to be locked again.
	if (PQTRANS_IDLE != [connection transactionStatus])
	{
		PGTSResultSet* res = nil;
		res = [notifyConnection executeQuery: @"SELECT baseten.ClearLocks ()"];
		res = [connection executeQuery: @"ROLLBACK"];
	}
	ResetSavepointIndex ();
	
	[self setLockedKey: nil];
	[self setLockedObjectID: nil];                
}

- (void) endSubtransactionIfNeeded
{
	if (YES == autocommits)
		[self internalCommit];
}

- (void) internalCommit
{
	//Exceptions should get handled by the caller.
	PGTransactionStatusType status = [connection transactionStatus];
	if (PQTRANS_INTRANS == status || PQTRANS_INERROR == status)
	{
		PGTSResultSet* res = nil;
		res = [notifyConnection executeQuery: @"SELECT baseten.ClearLocks ()"];
		res = [connection executeQuery: @"COMMIT"];
	}
	ResetSavepointIndex ();
	
	[self setLockedKey: nil];
	[self setLockedObjectID: nil];
}

@end


@implementation BXPGInterface (Accessors)
- (void) setLocker: (id <BXObjectAsynchronousLocking>) anObject
{
    if (locker != anObject)
    {
        [locker release];
        locker = [anObject retain];
    }
}

- (void) setLockedKey: (NSString *) aKey
{
    if (lockedKey != aKey)
    {
        [lockedKey release];
        lockedKey = [aKey retain];
    }
}

- (void) setLockedObjectID: (BXDatabaseObjectID *) aLockedObjectID
{
    if (lockedObjectID != aLockedObjectID) 
    {
        [lockedObjectID release];
        lockedObjectID = [aLockedObjectID retain];
    }
}

- (void) setHasInvalidCertificate: (BOOL) aBool
{
	invalidCertificate = aBool;
}

@end


@implementation BXPGInterface (Callbacks)
- (void) notifyConnectionWillClose: (NSNotification *) notification
{
    if (NO == clearedLocks)
    {
        clearedLocks = YES;
        [notifyConnection executeQuery: @"SELECT baseten.ClearLocks ()"];
    }
}

- (void) PGTSConnection: (PGTSConnection *) aConnection receivedResultSet: (PGTSResultSet *) result
{
    //We only expect results asynchronously for locking the objects.
    //Since we _don't_ implement PGTSConnection:receivedError:, the result might be invalid 
    //for asynchronous queries. This way, we can still have exception handling contexts
    //around synchronous queries.
    BOOL success = [result querySucceeded];
    
    if (kBXPGQueryBegun == state && NO == success)
    {
        [self endSubtransactionIfNeeded];
        state = kBXPGQueryIdle;
    }
    else if (kBXPGQueryLock == state)
    {
        BXDatabaseObjectID* objectID = [[lockedObjectID retain] autorelease];
        
        if (NO == success)
            [self endSubtransactionIfNeeded];
        else
        {
            NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
            NSPredicate* predicate = [objectID predicate];
            NSString* whereClause = [predicate PGTSWhereClauseWithContext: ctx];
            [self lockAndNotifyForEntity: [objectID entity] whereClause: whereClause 
                              parameters: [ctx objectForKey: kPGTSParametersKey] willDelete: NO];
        }
        
        [locker BXLockAcquired: success object: [context registeredObjectWithID: objectID]];
        state = kBXPGQueryIdle;
    }
}

- (void) PGTSConnectionFailed: (PGTSConnection *) aConnection
{
	NSString* localizedError = [aConnection errorMessage];
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: 
		BXSafeObj (localizedError), NSLocalizedFailureReasonErrorKey,
		BXSafeObj (localizedError), NSLocalizedRecoverySuggestionErrorKey,
		BXSafeObj (context),        kBXDatabaseContextKey,
		BXLocalizedString (@"connectionError", @"Connection Error", @"Title for a sheet"), NSLocalizedDescriptionKey,
		nil];
	
	int errorCode = kBXErrorConnectionFailed;
	int receivedCode = [aConnection errorCode];
	switch (receivedCode)
	{
		case PGCONN_AUTH_FAILURE:
			errorCode = kBXErrorAuthenticationFailed;
			break;
		case PGCONN_SSL_ERROR:
			errorCode = kBXErrorSSLError;
			break;
		default: 
			break;
	}
	NSError* error = [NSError errorWithDomain: kBXErrorDomain code: errorCode userInfo: userInfo];
	[context connectedToDatabase: NO async: YES error: &error];
}

- (void) PGTSConnectionEstablished: (PGTSConnection *) aConnection
{
    NSError* error = nil;
    [self checkConnectionStatus: &error];
	[context connectedToDatabase: YES async: YES error: &error];
}

- (void) rowsLocked: (NSNotification *) notification
{
    enum BXObjectLockStatus status = kBXObjectNoLockStatus;
    NSArray* ids = [self notificationObjectIDs: notification relidKey: @"baseten_lock_relid" status: &status];
    if (0 < [ids count])
        [context lockedObjectsInDatabase: ids status: status];
}

- (void) rowsUnlocked: (NSNotification *) notification
{
    NSArray* ids = [self notificationObjectIDs: notification relidKey: @"baseten_lock_relid"];
    if (0 < [ids count])
        [context unlockedObjectsInDatabase: ids];
}

- (void) rowsInserted: (NSNotification *) notification
{
    NSArray* ids = [self notificationObjectIDs: notification relidKey: @"baseten_modification_relid"];
    if (0 < [ids count])
        [context addedObjectsToDatabase: ids];
}

- (void) rowsUpdated: (NSNotification *) notification
{
    NSArray* ids = [self notificationObjectIDs: notification relidKey: @"baseten_modification_relid"];
    if (0 < [ids count])
        [context updatedObjectsInDatabase: ids faultObjects: YES];
}

- (void) rowsDeleted: (NSNotification *) notification
{
    NSArray* ids = [self notificationObjectIDs: notification relidKey: @"baseten_modification_relid"];
    if (0 < [ids count])
        [context deletedObjectsFromDatabase: ids];
}

@end
