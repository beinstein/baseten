//
// BXPGInterface.m
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

#import <PGTS/PGTS.h>
#import <PGTS/private/PGTSHOM.h>
#import "BXPGInterface.h"
#import "BXPGLockHandler.h"
#import "BXPGModificationHandler.h"
#import "BXPGAdditions.h"


static NSString* kBXLockerKey = @"BXLockerKey";


/**
 * \internal
 * Get a string like "$1, $2, $3".
 * \param count Number of fields.
 */
static NSString* 
FieldAliases (NSUInteger count)
{
    id retval = nil;
    if (count <= 0)
        retval = @"";
    else
    {
        retval = [NSMutableString stringWithCapacity: 3 * (count % 10) + 4 * ((count / 10) % 10)];
        for (unsigned int i = 1; i <= count; i++)
            [retval appendFormat: @"$%u,", i];
        [retval deleteCharactersInRange: NSMakeRange ([retval length] - 1, 1)];
    }
    return retval;
}


/**
 * \internal
 * A helper for determining returned attributes.
 * Primary key attributes are always returned.
 */
static int
ShouldReturn (BXAttributeDescription* attr)
{
	return (![attr isExcluded] || [attr isPrimaryKey]);
}


/**
 * \internal
 * Create a list of returned fields.
 * This may be passed to SELECT or to a RETURNING clause.
 */
static NSString*
ReturnedFields (PGTSConnection* connection, BXEntityDescription* entity)
{
	NSArray* attrs = [[entity attributesByName] allValues];
	NSArray* returned = [attrs PGTSSelectFunction: &ShouldReturn];
	NSArray* qualifiedNames = [[returned PGTSCollect] PGTSQualifiedName: connection];
	return [qualifiedNames componentsJoinedByString: @", "];	
}


/**
 * \internal
 * Create an insert query.
 */
static NSString*
InsertQuery (PGTSConnection* connection, BXEntityDescription* entity, NSArray* insertedAttrs)
{
	NSString* retval = nil;
	NSString* entityName = [entity PGTSQualifiedName: connection];
	NSString* returned = ReturnedFields (connection, entity);
	if (0 == [insertedAttrs count])
	{
		NSString* format = @"INSERT INTO %@ DEFAULT VALUES RETURNING %@";
		retval = [NSString stringWithFormat: format, entityName, returned];
	}
	else
	{
		NSString* format = @"INSERT INTO %@ (%@) VALUES (%@) RETURNING %@";
		NSString* nameString = [(id) [[insertedAttrs PGTSCollect] PGTSQualifiedName: connection] componentsJoinedByString: @", "];
		retval = [NSString stringWithFormat: format, entityName, nameString, FieldAliases ([insertedAttrs count]), returned];
	}
	return retval;
}


/**
 * \internal
 * Create a WHERE clause.
 * The context dictionary will contain an array of paramters,
 * which may be passed to a -sendQuery:...paramters: method.
 */
static NSString*
WhereClause (PGTSConnection* connection, NSPredicate* predicate, NSMutableDictionary* ctx)
{
	//Make sure that the where clause contains at least something, so the query is easier to format.
	NSString* whereClause = [predicate PGTSWhereClauseWithContext: ctx];
	if (nil == whereClause)
		whereClause = @"(true)";
	return whereClause;
}	


/**
 * \internal
 * Create a SELECT query.
 */
static NSString*
SelectQueryFormat (PGTSConnection* connection, BOOL forUpdate)
{
	NSString* queryFormat = @"SELECT %@ FROM %@ WHERE %@";
	if (forUpdate)
		queryFormat = @"SELECT %@ FROM %@ WHERE %@ FOR UPDATE";
	return queryFormat;
}


/**
 * \internal
 * Create a FROM clause.
 * The returned clause will include tables referenced in the given predicate.
 * \param additionalEntity An optional entity which may be added to the returned clause.
 * \param excludedEntity An optional entity which may not appear in the returned clause.
 */
static NSString*
FromClause (PGTSConnection connection, NSPredicate* predicate, BXEntityDescription* additionalEntity, BXEntityDescription* excludedEntity)
{
	NSString* fromClause = nil;
	
	NSMutableSet* entitySet = [NSMutableSet setWithSet: [predicate BXEntitySet]];
	log4AssertValueReturn (nil != entitySet, nil, @"Expected to receive an entity set (predicate: %@).", predicate);
	if (additionalEntity) [entitySet addObject: entity];
	//FIXME: a better way to exclude the corrent table for update would be to change BXEntitySet (above) so that in case of an update, it wouldn't return the target entity, unless a self-join was intended.
	if (excludedEntity) [entitySet removeObject: entity]; 
	
	if (0 < [entitySet count])
	{
		NSArray* components = [[entitySet PGTSCollectReturning: [NSMutableArray class]] PGTSQualifiedName: connection];
		fromClause = [components componentsJoinedByString: @", "];
		log4AssertValueReturn (nil != fromClause, nil, @"Expected to have a from clause (predicate: %@).", predicate);
	}
	
	return fromClause;
}


/**
 * \internal
 * Create an NSArray from a PGTSResultSet.
 * Objects that are already registered wont'be recreated.
 */
static NSArray*
Result (BXDatabaseContext* context, BXEntityDescription* entity, PGTSResultSet* res)
{
	retval = [NSMutableArray arrayWithCapacity: [res countOfRows]];
	[res setRowClass: aClass];
	while (([res advanceRow]))
	{
		BXDatabaseObject* currentRow = [res currentRowAsObject];
		
		//If the object is already in memory, don't make a copy
		if (NO == [currentRow registerWithContext: mContext entity: entity])
			currentRow = [mContext registeredObjectWithID: [currentRow objectID]];
		[retval addObject: currentRow];
	}
}


/**
 * \internal
 * Create an UPDATE query.
 */
static NSString*
UpdateQuery (PGTSConnection* connection, BXEntityDescription* entity, NSString* setClause, NSString* fromClause)
{
	NSString* query = nil;
	NSString* pkeyFields = [(id) [[[entity primaryKeyFields] PGTSCollect] PGTSEscapedName: connection] componentsJoinedByString: @", "];
	if (fromClause)
	{
		queryFormat = @"UPDATE %@ SET %@ FROM %@ WHERE %@ RETURNING %@";
		query = [NSString stringWithFormat: [entity PGTSQualifiedName: connection], setClause, fromClause, whereClause, pkeyFields];
	}
	else
	{
		queryFormat = @"UPDATE %@ SET %@ WHERE %@ RETURNING %@";
		query = [NSString stringWithFormat: [entity PGTSQualifiedName: connection], setClause, whereClause, pkeyFields];
	}
	return query;
}


/**
 * \internal
 * Create a database error.
 * Automatically fills some common fields in the userInfo dictionary.
 */
static NSError*
DatabaseError (NSInteger errorCode, NSString* localizedError, BXDatabaseContext* context, BXEntityDescription* entity)
{
	Expect (localizedError);
	NSString* title = BXLocalizedString (@"databaseError", @"Database Error", @"Title for a sheet");
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									 localizedError, NSLocalizedFailureReasonErrorKey,
									 localizedError, NSLocalizedRecoverySuggestionErrorKey,
									 title, NSLocalizedDescriptionKey,
									 nil];
	if (context)	[userInfo setObject: context forKey: kBXDatabaseContextKey];
	if (entity)		[userInfo setObject: entity	forKey: kBXEntityDescriptionKey];
	return [NSError errorWithDomain: kBXErrorDomain code: errorCode userInfo: userInfo];		
}


/**
 * \internal
 * Create object IDs from a PGTSResultSet.
 * \param entity The IDs' entity.
 */
static NSArray*
ObjectIDs (BXEntityDescription* entity, PGTSResultSet* res)
{
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [res countOfRows]];
	while ([res advanceRow])
	{
		NSDictionary* pkey = [res currentRowAsDictionary];
		BXDatabaseObjectID* objectID = [BXDatabaseObjectID IDWithEntity: entity
													   primaryKeyFields: pkey];
		[objectIDs addObject: objectID];
	}
	
	[self checkSuperEntities: entity]; //FIXME: is this needed?
	return retval;
}


/**
 * An error handler for ROLLBACK errors.
 * The intended use is to set a symbolic breakpoint for possible errors caught during ROLLBACK.
 */
static void
bx_error_during_rollback (id self, NSError* error)
{
	log4Error (@"Got error during ROLLBACK: %@", [error localizedDescription]);
}


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
        mContext = aContext; //Weak
#if 0
        mAutocommits = YES;
        mLogsQueries = NO;
        mClearedLocks = NO;
        mState = kBXPGQueryIdle;
#endif
    }
    return self;
}


- (void) disconnect
{
	[mConnection disconnect];
	[mNotifyConnection disconnect];
}


- (void) dealloc
{
	[mContext release];
	[mConnection release];
	[mNotifyConnection release];
	[mObservedEntities release];
	[mObservers release];
	[super dealloc];
}


- (void) finalize
{
	//Connections will finalize themselves.
	[super finalize];
}


- (NSString *) description
{
	return [NSString stringWithFormat: @"<%@: %p (%@, %@)>", [self class], self, 
			[mConnection errorMessage], [mNotifyConnection errorString]];
}


- (NSArray *) executeQuery: (NSString *) queryString parameters: (NSArray *) parameters error: (NSError **) error
{
	Expect (queryString);
	Expect (parameters);
	Expect (error);
	
	NSArray* retval = nil;
	PGTSResultSet* res = [mConnection executeQuery: queryString parameterArray: parameters];
	if (YES == [res querySucceeded])
		retval = [res resultAsArray];
	else
	{
        //FIXME: reason for error?
		*error = [NSError errorWithDomain: kBXErrorDomain
									 code: kBXErrorUnsuccessfulQuery
								 userInfo: nil];
	}
	return retval;
}


- (unsigned long long) executeCommand: (NSString *) commandString error: (NSError **) error;
{
	ExpectR (error, 0);
	unsigned long long retval = 0;
	PGTSResultSet* res = [mConnection executeQuery: commandString];
	if (YES == [res querySucceeded])
		retval = [res numberOfRowsAffectedByCommand];
	else
	{
        //FIXME: reason for error?
		*error = [NSError errorWithDomain: kBXErrorDomain
									 code: kBXErrorUnsuccessfulQuery
								 userInfo: nil];		
	}
	return retval;
}


- (id) createObjectForEntity: (BXEntityDescription *) entity 
             withFieldValues: (NSDictionary *) valueDict
                       class: (Class) aClass 
                       error: (NSError **) error;
{
	Expect (entity);
	Expect (valueDict);
	Expect (aClass);
	Expect (error);
    id retval = nil;
	PGTSResultSet* res = nil;
	
	if (! [self beginIfNeeded: error]) goto error;
	if (! [self validateEntity: entity error: error]) goto error;
	if (! [self observeIfNeeded: entity error: error]) goto error;
	
	//Inserted values
	NSArray* insertedAttrs = [valueDict allKeys];
	NSString* query = InsertQuery (mConnection, entity, insertedAttrs);
	NSArray* values = [valueDict objectsForKeys: insertedAttrs notFoundMarker: [NSNull null]];
	if (! (res = [mConnection executeQuery: query parameterArray: values]))
	{
		*error = [res error];
		goto error;
	}
	
	[res setRowClass: aClass];
	[res advanceRow];
	retval = [res currentRowAsObject];
	
	[self checkSuperEntities: entity];
	
error:
	return retval;
}


- (NSMutableArray *) executeFetchForEntity: (BXEntityDescription *) entity 
                             withPredicate: (NSPredicate *) predicate 
                           returningFaults: (BOOL) returnFaults 
                                     class: (Class) aClass
								 forUpdate: (BOOL) forUpdate
                                     error: (NSError **) error
{
	Expect (entity);
	Expect (aClass);
	Expect (error);
    NSMutableArray* retval = nil;
	PGTSTableDescription* table = [self validateEntity: entity error: error];
	if (! table) goto error;
	if (! [self observeIfNeeded: entity error: error]) goto error;
	
	NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
	NSString* queryFormat = SelectQueryFormat (mConnection, forUpdate);
	NSString* returnedFields = ReturnedFields (mConnection, entity);
	NSString* fromClause = FromClause (mConnection, predicate, entity, nil);
	NSString* whereClause = WhereClause (mConnection, predicate, ctx);
	NSString* query = [NSString stringWithFormat: queryFormat, returnedFields, fromClause, whereClause];
	
	NSArray* parameters = [ctx objectForKey: kPGTSParametersKey];
	PGTSResultSet* res = [mConnection executeQuery: query parameterArray: parameters];
	if (! [res querySucceeded])
		*error = [res error];
		goto error;
	else
		retval = Result (mContext, entity, res);

	return retval;
}


//FIXME: valueDict needs attributes, not strings, as keys.
- (NSArray *) executeUpdateWithDictionary: (NSDictionary *) valueDict
                                 objectID: (BXDatabaseObjectID *) objectID
                                   entity: (BXEntityDescription *) entity
                                predicate: (NSPredicate *) predicate
                                    error: (NSError **) error
{
	Expect (valueDict);
	Expect (objectID || entity);
	Expect (predicate);
	Expect (error);
	
	NSArray* retval = nil;
	
	if (nil != objectID)
	{
		predicate = [objectID predicate];
		entity = [objectID entity];
	}
	
	NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: mConnection forKey: kPGTSConnectionKey];
	NSString* whereClause = WhereClause (mConnection, predicate, context);
	NSMutableArray* parameters = [ctx objectForKey: kPGTSParametersKey] ?: [NSMutableArray parameters];
	NSString* fromClause = FromClause (mConnection, predicate, nil, entity);
	NSString* setClause = [valueDict PGTSSetClauseParameters: parameters connection: mConnection];
	NSString* updateQuery = UpdateQuery (mConnection, entity, setClause, fromClause);
	[mConnection executeQuery: updateQuery parameterArray: parameters];
	
}


//FIXME: keys needs attributes, not strings.
- (BOOL) fireFault: (BXDatabaseObject *) anObject keys: (NSArray *) keys error: (NSError **) error
{
	ExpectR (error);
	log4AssertValueReturn (0 < [keys count], NO, @"Expected to have received some keys to fetch.");
	
    BOOL retval = NO;
	NSArray* qualifiedNames = [[keys PGTSCollect] PGTSQualifiedName: connection];
	NSString* fieldNames = [keys componentsJoinedByString: @", "];
	NSPredicate* predicate = [[anObject objectID] predicate];
	
	NSString* fromClause = FromClause (mConnection, predicate, entity, nil);
	NSString* whereClause = WhereClause (mConnection, predicate, ctx);
	NSString* queryFormat = SelectQueryFormat (mConnection, NO);

	NSString* query = [NSString stringWithFormat: queryFormat, fieldNames, fromClause, whereClause];
	NSArray* parameters = [ctx objectForKey: kPGTSParametersKey];
	PGTSResultSet* res = [mConnection executeQuery: query parameterArray: parameters];
	if (! [res querySucceeded])
		*error = [res error];
	else
	{
		[res advanceRow];
		[anObject setCachedValuesForKeysWithDictionary: [res currentRowAsDictionary]];
		retval = YES;
	}
}


- (NSArray *) executeDeleteObjectWithID: (BXDatabaseObjectID *) objectID 
                                 entity: (BXEntityDescription *) entity 
                              predicate: (NSPredicate *) predicate 
                                  error: (NSError **) error
{
	Expect (objectID || entity);
	Expect (error);
		
    NSArray* retval = nil;

	if (nil != objectID)
	{
		entity = [objectID entity];
		predicate = [objectID predicate];
	}
	
	PGTSTableDescription* table = [self validateEntity: entity error: error];
	if (! table) goto error;
	if (! [self observeIfNeeded: entity error: error]) goto error;
	
	NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
	NSString* whereClause = WhereClause (mConnection, predicate, ctx);
	NSString* fromClause = [entity PGTSQualifiedName: mConnection];
	NSString* returnedFields = ReturnedFields (mConnection, entity);
	NSString* queryFormat = @"DELETE FROM %@ WHERE %@ RETURNING %@";
	NSString* query = [NSString stringWithFormat: queryFormat, returnedFields, fromClause, whereClause];
	NSArray* parameters = [ctx objectForKey: kPGTSParametersKey];
	PGTSResultSet* res = [mConnection executeQuery: query parameters: parameters];
	if ([res querySucceeded])
		retval = ObjectIDs (entity, res);
	else
		*error = [res error];
	
	//FIXME: mark locked?

error:
	return retval;
}


- (NSDictionary *) relationshipsForEntity: (BXEntityDescription *) entity
									error: (NSError **) error
{    
	Expect (entity);
	Expect (error);
    
	NSMutableDictionary* retval = [NSMutableDictionary dictionary];

	if ([self fetchForeignKeys: error])
	{
		NSString* queryFormat = @"SELECT * FROM baseten.%@ WHERE srcnspname = $1 AND srcrelname = $2";
		NSString* views [4] = {@"onetomany", @"onetoone", @"manytomany", @"relationship_v"};
		
		//Entities between views and between tables and views are stored in a different place.
		//If given entity is a view, we only need to check those.
		int i = 0;
		if ([entity isView])
			i = 3;
		
		while (i < 4)
		{
			NSString* queryString = [NSString stringWithFormat: queryFormat, views [i]];
			PGTSResultSet* res = [mConnection executeQuery: queryString parameters:
								  [entity schemaName], [entity name]];
			if (! [res querySucceeded])
			{
				*error = [res error];
				retval = nil;
				break;
			}
			
			while ([res advanceRow])
			{
				id rel = nil;
				NSString* name = [res valueForKey: @"name"];
				NSString* inverseName = [res valueForKey: @"inversename"];
				BXEntityDescription* dst = [mContext entityForTable: [res valueForKey: @"dstrelname"] 
														   inSchema: [res valueForKey: @"dstnspname"]
												validateImmediately: NO
															  error: error];
				if (nil != *error) goto bail;
				
				int kind = i;
				if (kind == 3)
				{
					if ([[res valueForKey: @"ismanytomany"] boolValue])
						kind = 2;
					else if ([[res valueForKey: @"istoone"] boolValue])
						kind = 1;
					else
						kind = 0;
				}
				
				switch (kind)
				{
						//One-to-many
					case 0:
					{
						rel = [[BXRelationshipDescription alloc] initWithName: name entity: entity];
						//Fall through
					}
						
						//One-to-one
					case 1:
					{
						if (nil == rel)
							rel = [[BXOneToOneRelationshipDescription alloc] initWithName: name entity: entity];
						
						[rel setIsInverse: [[res valueForKey: @"isinverse"] boolValue]];						
						[rel setForeignKey: [mForeignKeys objectForKey: [res valueForKey: @"conoid"]]];
						
						//We only have a delete rule for the foreign key's source table.
						//If it isn't also the relationship's source table, we have no way of controlling deletion.
						[(BXRelationshipDescription *) rel setDeleteRule: ([rel isInverse] ? NSNullifyDeleteRule : [[rel foreignKey] deleteRule])];
						
						break;
					}
						
						//Many-to-many
					case 2:
					{
						BXEntityDescription* helper = [mContext entityForTable: [res valueForKey: @"helperrelname"] 
																	  inSchema: [res valueForKey: @"helpernspname"] 
														   validateImmediately: NO
																		 error: error];
						if (nil != *error) goto bail;
						
						rel = [[BXManyToManyRelationshipDescription alloc] initWithName: name entity: entity];
						
						[rel setSrcForeignKey: [mForeignKeys objectForKey: [res valueForKey: @"conoid"]]];
						[rel setDstForeignKey: [mForeignKeys objectForKey: [res valueForKey: @"dstconoid"]]];
						
						[rel setHelperEntity: helper];
						break;
					}
						
					default:
						break;
				}
				
				if (nil != rel)
				{
					//FIXME: all relationships are now treated as optional. NULL constraints should be checked, though.
					[rel setOptional: YES];
					
					[rel setInverseName: inverseName];
					[(BXRelationshipDescription *) rel setDestinationEntity: dst];
					
					[retval setObject: rel forKey: [rel name]];
					[rel release];
				}
			}
			i++;
		}
	}
    return retval;
}


- (BOOL) fetchForeignKeys: (NSError **) outError
{
	ExpectR (outError, NO);
	BOOL retval = NO;
	if (mForeignKeys)
		retval = YES;
	else
	{
		NSString* query = @"SELECT * from baseten.foreignkey";
		PGTSResultSet* res = [mConnection executeQuery: query];
		if (! [res querySucceeded])
		{
			*outError = [res error];
		}
		else
		{
			mRetval = YES;
			mForeignKeys = [[NSMutableDictionary alloc] init];
			while (([res advanceRow]))
			{
				BXForeignKey* key = [[BXForeignKey alloc] initWithName: [res valueForKey: @"name"]];
				
				NSArray* srcFNames = [res valueForKey: @"srcfnames"];
				NSArray* dstFNames = [res valueForKey: @"dstfnames"];
				log4AssertVoidReturn ([srcFNames count] == [dstFNames count], 
									  @"Expected array counts to match. Row: %@.", 
									  [res currentRowAsArray]);
				
				for (unsigned int i = 0, count = [srcFNames count]; i < count; i++)
					[key addSrcFieldName: [srcFNames objectAtIndex: i] dstFieldName: [dstFNames objectAtIndex: i]];
				
				NSDeleteRule deleteRule = NSDenyDeleteRule;
				enum PGTSDeleteRule pgDeleteRule = PGTSDeleteRule ([[res valueForKey: @"deltype"] characterAtIndex: 0]);
				switch (pgDeleteRule)
				{
					case kPGTSDeleteRuleUnknown:
					case kPGTSDeleteRuleNone:
					case kPGTSDeleteRuleNoAction:
					case kPGTSDeleteRuleRestrict:
						deleteRule = NSDenyDeleteRule;
						
					case kPGTSDeleteRuleCascade:
						deleteRule = NSCascadeDeleteRule;
						break;
						
					case kPGTSDeleteRuleSetNull:
					case kPGTSDeleteRuleSetDefault:
						deleteRule = NSNullifyDeleteRule;
						break;
						
					default:
						break;
				}
				[key setDeleteRule: deleteRule];
				
				[mForeignKeys setObject: key forKey: [res valueForKey: @"conoid"]];
				[key release];
			}
		}
	}
	return retval;
}


- (BOOL) validateEntity: (BXEntityDescription *) entity error: (NSError **) error
{
	ExpectR (entity, NO);
	ExpectR (error, NO);
	BOOL retval = [entity isValidated];
	if (! retval)
	{
		PGTSDatabaseDescription* database = [mNotifyConnection databaseDescription];
		PGTSTableDescription* table = [database table: [entity name] inSchema: [entity schemaName]];
		if (table)
		{
			//If attributes exists, it only contains primary key fields but we haven't received them from the database.
			NSMutableDictionary* attributes = ([[[entity attributesByName] mutableCopy] autorelease] ?: [NSMutableDictionary dictionary]);
			
			//While we're at it, set the fields as well as the primary key.
			NSSet* pkey = [[table primaryKey] fields];
			[[[table allFields] PGTSDo] addAttributeFor: entity attributes: attributes primaryKeyFields: pkey];
			[entity setAttributes: attributes];
			
			if ('v' == [table kind])
				[entity setIsView: YES];
			
			retval = YES;
		}
	}
	else
	{
		NSString* errorFormat = BXLocalizedString (@"tableNotFound", @"Table %@ was not found in schema %@.", @"Error message for fetch");
		NSString* localizedError = [NSString stringWithFormat: errorFormat, [entity name], [entity schemaName]];
		*error = DatabaseError (kBXErrorNoTableForEntity, localizedError, mContext, entity);
	}
	return retval;
}


- (BOOL) observeIfNeeded: (BXEntityDescription *) entity error: (NSError **) error
{
	ExpectR (error, NO);
	ExpectR (entity, NO);
	
	BOOL retval = NO;
	
	if ([mEntityObservers objectForKey: entity])
		retval = YES;
	else
	{
		//PostgreSQL backends don't deliver notifications to interfaces during transactions
		log4AssertValueReturn (mConnection == mNotifyConnection || PQTRANS_IDLE == [mNotifyConnection transactionStatus], NO,
							   @"Connection %p was expected to be in PQTRANS_IDLE (status: %d connection: %p notifyconnection: %p).", 
							   mNotifyConnection, [mNotifyConnection transactionStatus], mConnection, mNotifyConnection);		
		
		if (! mObservedEntities)
			mObservedEntities = [[NSMutableSet alloc] init];
		
		PGTSTableDescription* table = [[mNotifyConnection databaseDescription] table: [entity name] inSchema: [entity schemaName]];
		if (! table)
		{
			NSString* errorFormat = BXLocalizedString (@"existenceErrorFmt", @"Table %@ in schema %@ does not exist.", @"Error description format");
			NSString* message = [NSString stringWithFormat: errorFormat, [entity name], [entity schemaName]];
			*error = DatabaseError (kBXErrorObservingFailed, message, mContext, entity);
		}
		else if ([self addClearLocksHandler: error])
		{
			id oid = PGTSOidAsObject ([table oid]);
			NSString* query = 
			@"SELECT CURRENT_TIMESTAMP::TIMESTAMP WITHOUT TIME ZONE AS ts, null AS nname UNION ALL "
			@"SELECT null AS ts, baseten.ObserveModifications ($1) AS nname UNION ALL "
			@"SELECT null AS ts, baseten.ObserveLocks ($1) AS nname";
			PGTSResultSet* res = [mConnection executeQuery: query parameters: oid];
			if ([res querySucceeded] && 3 == [res count])
			{
				[res advanceRow];
				NSDate* lastCheck = [res valueForKey: @"ts"];
				
				[self addObserverClass: [BXPGModificationHandler class] forResult: res lastCheck: lastCheck error: error];
				[self addObserverClass: [BXPGLockHandler class] forResult: res lastCheck: lastCheck error: error];

				[mObservedEntities addObject: entity];			
				retval = YES;
			}
			else
			{
				*error = [res error];
			}
		}
	}
	
	//Inheritance.
	TSEnumerate (currentEntity, e, [entity inheritedEntities])
	{
		if (! retval)
			break;
		retval = [self observeIfNeeded: currentEntity error: error];
	}
	
    return retval;
}


- (BOOL) addClearLocksHandler: (NSError **) outError
{
	ExpectR (outError, NO);
	
	BOOL retval = NO;
	
	NSString* nname = [BXPGClearedLocksHandler notificationName];
	if (! [mObservers objectForKey: nname])
	{		
		PGTSResultSet* res = [mNotifyConnection executeQuery: @"LISTEN $1", nname];
		if ([res querySucceeded])
		{
			if (! mObservers)
				mObservers = [[NSMutableDictionary alloc] init];
			BXPGClearedLocksHandler* handler = [[BXPGClearedLocksHandler alloc] init];
			[handler setInterface: self];
			[handler prepare];
			[mObservers setObject: handler forKey: nname];
			[handler release];
			
			retval = YES
		}
		else
		{
			*outError = [res error];
		}
	}
	return retval;
}


- (void) addObserverClass: (Class) observerClass forResult: (PGTSResultSet *) res lastCheck: (NSDate *) lastCheck error: (NSError **) outError
{
	ExpectV (observerClass);
	ExpectV (res)
	ExpectV (outError);
	
	[res advanceRow];
	NSString* notificationName = [res valueForKey: @"nname"];
		
	if (! mObservers)
		mObservers = [[NSMutableDictionary alloc] init];
		
	//Create the observer.
	BXPGNotificationHandler* handler = [[[handlerClass alloc] init] autorelease];
	[handler setInterface: self];
	[handler setLastCheck: lastCheck];
	[handler prepare];
	
	[mObservers setObject: handler forKey: nname];
}


/** 
 * \internal
 * Lock an object asynchronously.
 * Lock notifications should always be listened to, since modifications cause the rows to be locked until
 * the end of the ongoing transaction.
 */
//FIXME: make this conditional.
//FIXME: unlock on -discardEditing?
- (void) lockObject: (BXDatabaseObject *) anObject key: (id) aKey 
		   lockType: (enum BXObjectLockStatus) type
             sender: (id <BXObjectAsynchronousLocking>) sender
{
	BXDatabaseObjectID* objectID = [anObject objectID];
	BXEntityDescription* entity = [objectID entity];

	[self beginIfNeeded]; //FIXME: make this async.
	NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: mConnection forKey: kPGTSConnectionKey];
	NSString* whereClause = [[objectID predicate] PGTSWhereClauseWithContext: ctx];
	NSString* fromClause = [entity PGTSQualifiedName: mConnection];
	NSString* queryFormat = @"SELECT null FROM ONLY %@ WHERE %@ FOR UPDATE NOWAIT";
	NSString* queryString = [NSString stringWithFormat: queryFormat, fromClause, whereClause];

	NSArray* parameters = [ctx objectForKey: kPGTSParametersKey];
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  sender, kBXLockerKey,
							  anObject, kBXObjectKey,
							  whereClause, kBXWhereClauseKey,
							  parameters, kBXParametersKey,
							  nil];
	[mConnection sendQuery: queryString delegate: self callback: @selector (lockedRow:) 
			parameterArray: parameters userInfo: userInfo];
}


- (void) lockedRow: (PGTSResultSet *) res
{
	NSDictionary* userInfo = [res userInfo];
	id <BXObjectAsynchronousLocking> sender = [userInfo objectForKey: kBXLockerKey];
	BXDatabaseObject* object = [userInfo objectForKey: kBXObjectKey];
	
	if ([res querySucceeded])
	{
		[sender BXLockAcquired: YES object: object error: nil];
		[self markLocked: [object entity] whereClause: whereClause parameters: parameters willDelete: NO];
	}
	else
	{
		//FIXME: end the transaction?
		[sender BXLockAcquired: NO object: nil error: [res error]];
	}
}


- (void) markLocked: (BXEntityDescription *) entity whereClause: (NSString *) whereClause 
		 parameters: (NSArray *) parameters willDelete: (BOOL) willDelete
{
	ExpectV (entity);
	ExpectV (whereClause);
	log4AssertVoidReturn (PQTRANS_IDLE == [notifyConnection transactionStatus], 
						  @"Expected notifyConnection not to have transaction.");
	NSString* funcname = nil; //FIXME: get this somehow.
	
	//Lock type
	NSString* format = @"SELECT %@ ('U', %u, %@) FROM %@ WHERE %@";
	if (willDelete)
		format = @"SELECT %@ ('D', %u, %@) FROM %@ WHERE %@";
        
	//Get and sort the primary key fields.
	NSDictionary* attrs = [entity attributesByName];
	NSArray* pkeyFields = [[[[table primaryKey] fields] allObjects] sortedArrayUsingSelector: @selector (indexCompare:)];
	log4AssertVoidReturn (nil != pkeyFields, @"Expected to know the primary key.");
	NSArray* quoted = [[pkeyFields PGTSCollect] qualifiedAttributeName: attrs connection: mNotifyConnection];
	NSString* quotedNames = [quoted componentsJoinedByString: @", "];
	NSString* entityName = [entity PGTSQualifiedName: notifyConnection];
	
	//Execute the query.
	NSString* query = [NSString stringWithFormat: format, funcname, 0, quotedNames, entityName, whereClause];
	[notifyConnection sendQuery: query delegate: nil callback: NULL parameterArray: parameters]; 
}

- (void) connect: (NSError **) error
{
	//FIXME: write this.
}

- (void) connectAsync: (NSError **) error
{
	//FIXME: write this.
}

- (void) disconnect
{
	//FIXME: write this.
}

- (BXDatabaseContext *) databaseContext
{
	return mContext;
}
@end


@interface BXPGInterface (ConnectionDelegate)
- (void) connectionSucceeded
{
	//FIXME: write this.
}

- (void) connectionFailed: (NSError *) error
{
	//FIXME: write this.
}

- (void) connectionLost: (BXPGTransactionHandler *) handler error: (NSError *) error
{
	//FIXME: write this.
}

- (void) connection: (PGTSConnection *) connection gotNotification: (PGTSNotification *) notification
{
	NSString* notificationName = [notification notificationName];
	[[mEntityObservers objectForKey: notificationName] handleNotification: notification];
}
@end


@implementation BXPGInterface (Transactions)
- (void) rollback
{
    if ([self connected])
    {
		NSError* localError = nil;
		[mTransactionHandler rollback: &localError];
		if (localError) bx_error_during_rollback (self, error);
    }
}
@end
