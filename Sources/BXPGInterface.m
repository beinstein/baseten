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

#import "PGTS.h"
#import "PGTSHOM.h"
#import "PGTSDeleteRule.h"
#import "PGTSConstants.h"
#import "PGTSOids.h"
#import "PGTSMetadataStorage.h"

#import "BaseTen.h"
#import "BXRelationshipDescription.h"
#import "BXOneToOneRelationshipDescription.h"
#import "BXManyToManyRelationshipDescription.h"
#import "BXForeignKey.h"
#import "BXDatabaseObjectModel.h"

#import "BXPGInterface.h"
#import "BXPGLockHandler.h"
#import "BXPGModificationHandler.h"
#import "BXPGClearLocksHandler.h"
#import "BXPGAdditions.h"
#import "BXPGCertificateVerificationDelegate.h"
#import "BXPGAutocommitTransactionHandler.h"
#import "BXPGManualCommitTransactionHandler.h"
#import "BXPGDatabaseDescription.h"
#import "BXPGTableDescription.h"
#import "BXPGQueryBuilder.h"
#import "BXPGFromItem.h"
#import "BXPGEFMetadataContainer.h"
#import "BXPGForeignKeyDescription.h"

#import "BXLocalizedString.h"
#import "BXLogger.h"
#import "BXEnumerate.h"
#import "BXError.h"

//FIXME: it'd be nicer if we didn't need any private headers.
#import "BXDatabaseContextPrivate.h"
#import "BXPropertyDescriptionPrivate.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseObjectPrivate.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXAttributeDescriptionPrivate.h"


static NSString* kBXPGLockerKey = @"BXPGLockerKey";
static NSString* kBXPGWhereClauseKey = @"BXPGWhereClauseKey";
static NSString* kBXPGParametersKey = @"BXPGParametersKey";
static NSString* kBXPGObjectKey = @"BXPGObjectKey";
static NSString* kBXPGPrimaryRelationAliasKey = @"kBXPGPrimaryRelationAliasKey";
static NSString* kBXPGFromClauseKey = @"kBXPGFromClauseKey";


static void
RemoveCharactersFromEnd (NSMutableString* string, NSUInteger count)
{
	NSUInteger length = [string length];
	if ( length >= count)
	{
		NSRange removedRange = NSMakeRange (length - count, count);
		[string deleteCharactersInRange: removedRange];
	}
}


/**
 * \internal
 * \brief A helper for determining returned attributes.
 *
 * Primary key attributes are always returned.
 */
static int
ShouldReturn (BXAttributeDescription* attr)
{
	return (![attr isExcluded] || [attr isPrimaryKey]);
}


static int
IsPkeyAttr (BXAttributeDescription* attr)
{
	return ([attr isPrimaryKey]);
}


NSString*
BXPGReturnList (NSArray* attrs, NSString* alias, BOOL prependAlias)
{
	NSMutableArray* qnames = [NSMutableArray arrayWithCapacity: [attrs count]];
	BXEnumerate (currentAttribute, e, [attrs objectEnumerator])
	{
		NSString* name = [currentAttribute name];
		NSString* qname = nil;
		
		if (prependAlias)
			qname = [NSString stringWithFormat: @"%@.\"%@\"", alias, name];
		else
			qname = [NSString stringWithFormat: @"\"%@\"", name];
		
		[qnames addObject: qname];
	}
	return [qnames componentsJoinedByString: @", "];		
}


static NSString*
ReturnedFields (BXPGQueryBuilder* queryBuilder, NSArray* attrs, BOOL prependAlias)
{
	BXPGFromItem* fromItem = [queryBuilder primaryRelation];
	NSString* alias = [fromItem alias];
	BXEntityDescription* entity = [fromItem entity];
	
	BXEnumerate (currentAttribute, e, [attrs objectEnumerator])
		Expect ([[currentAttribute entity] isEqual: entity]);
	
	NSString* retval = BXPGReturnList (attrs, alias, prependAlias);
	return retval;
}


/**
 * \internal
 * \brief Create a list of returned fields.
 *
 * This may be passed to SELECT or to a RETURNING clause.
 */
static NSString*
ReturnedFieldsByCallback (BXPGQueryBuilder* queryBuilder, int (* filterFunction)(BXAttributeDescription *), BOOL prependAlias)
{
	BXPGFromItem* fromItem = [queryBuilder primaryRelation];
	BXEntityDescription* entity = [fromItem entity];
	NSDictionary* attrs = [entity attributesByName];
	NSArray* filteredAttrs = [attrs PGTSValueSelectFunction: filterFunction];
	return ReturnedFields (queryBuilder, filteredAttrs, prependAlias);
}


/**
 * \internal
 * \brief Create a WHERE clause.
 */
static struct bx_predicate_st
WhereClauseUsingEntity (BXPGQueryBuilder* queryBuilder, NSPredicate* predicate, BXEntityDescription* entity, PGTSConnection* connection)
{
	struct bx_predicate_st retval = {};
	ExpectR (queryBuilder, retval);
	ExpectR (entity, retval);
	ExpectR (connection, retval);

	retval = [queryBuilder whereClauseForPredicate: predicate entity: entity connection: connection];
	return retval;
}


/**
 * \internal
 * \brief Create a WHERE clause.
 */
static struct bx_predicate_st
WhereClauseUsingObject (BXPGQueryBuilder* queryBuilder, NSPredicate* predicate, BXDatabaseObject* object)
{
	struct bx_predicate_st retval = {};
	ExpectR (queryBuilder, retval);
	ExpectR (predicate, retval);
	ExpectR (object, retval);
	
	retval = [queryBuilder whereClauseForPredicate: predicate object: object];
	return retval;
}


/**
 * \internal
 * \brief Create a SELECT query.
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
 * \brief Create an NSArray from a PGTSResultSet.
 *
 * Objects that are already registered wont'be recreated.
 */
static NSArray*
Result (BXDatabaseContext* context, BXEntityDescription* entity, PGTSResultSet* res, Class rowClass, NSPredicate* filterPredicate)
{
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [res count]];
	[res setRowClass: rowClass];
	while (([res advanceRow]))
	{
		BXDatabaseObject* currentRow = [res currentRowAsObject];
		
		//If the object is already in memory, don't make a copy
		if (! [currentRow registerWithContext: context entity: entity])
			currentRow = [context registeredObjectWithID: [currentRow objectID]];
		
		if (filterPredicate && ! [filterPredicate evaluateWithObject: currentRow])
			continue;
		
		[retval addObject: currentRow];
	}
	return retval;
}


static NSString*
UpdateQuery (BXPGQueryBuilder* queryBuilder, NSString* setClause, NSString* whereClause)
{
	NSString* updateTarget = [queryBuilder target];
	NSString* fromClause = [queryBuilder fromClause];
	NSString* returnedFields = ReturnedFieldsByCallback (queryBuilder, &IsPkeyAttr, YES);
	NSString* retval = nil;
	
	if (fromClause)
	{
		NSString* queryFormat = @"UPDATE %@ SET %@ FROM %@ WHERE %@ RETURNING %@";
		retval = [NSString stringWithFormat: queryFormat, updateTarget, setClause, fromClause, whereClause, returnedFields];
	}
	else
	{
		NSString* queryFormat = @"UPDATE %@ SET %@ WHERE %@ RETURNING %@";
		retval = [NSString stringWithFormat: queryFormat, updateTarget, setClause, whereClause, returnedFields];
	}
	return retval;
}


static NSString*
DeleteQuery (BXPGQueryBuilder* queryBuilder, NSString* whereClause)
{
	NSString* deleteTarget = [queryBuilder target];
	NSString* usingClause = [queryBuilder fromClause];
	NSString* returnedFields = ReturnedFieldsByCallback (queryBuilder, &IsPkeyAttr, YES);
	NSString* retval = nil;
	
	if (usingClause)
	{
		NSString* queryFormat = @"DELETE FROM %@ USING %@ WHERE %@ RETURNING %@";
		retval = [NSString stringWithFormat: queryFormat, deleteTarget, usingClause, whereClause, returnedFields];
	}
	else
	{
		NSString* queryFormat = @"DELETE FROM %@ WHERE %@ RETURNING %@";
		retval = [NSString stringWithFormat: queryFormat, deleteTarget, whereClause, returnedFields];
	}
	return retval;
}


static NSMutableDictionary*
ErrorUserInfo (NSString* localizedName, NSString* localizedError, BXDatabaseContext* context)
{
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									 localizedError, NSLocalizedFailureReasonErrorKey,
									 localizedError, NSLocalizedRecoverySuggestionErrorKey,
									 localizedName, NSLocalizedDescriptionKey,
									 nil];
	if (context)
		[userInfo setObject: context forKey: kBXDatabaseContextKey];
	return userInfo;
}


/**
 * \internal
 * \brief Create a database error.
 *
 * Automatically fills some common fields in the userInfo dictionary.
 */
static NSError*
DatabaseError (NSInteger errorCode, NSString* localizedError, BXDatabaseContext* context, BXEntityDescription* entity)
{
	ExpectCR (localizedError, nil);
	NSString* title = BXLocalizedString (@"databaseError", @"Database Error", @"Title for a sheet");
	NSMutableDictionary* userInfo = ErrorUserInfo (title, localizedError, context);
	if (entity) 
		[userInfo setObject: entity	forKey: kBXEntityDescriptionKey];
	return [BXError errorWithDomain: kBXErrorDomain code: errorCode userInfo: userInfo];		
}


static NSError*
PredicateNotAllowedError (BXDatabaseContext* context, NSPredicate* predicate)
{
	NSString* title = BXLocalizedString (@"predicateNotAllowedForDM", @"Predicate not allowed for data manipulation", @"Title for a sheet");
	NSString* error = BXLocalizedString (@"predicateNotAllowedForUpdateDeleteExplanation", 
										 @"UPDATE and DELETE queries require a predicate that may be interpreted entirely in the database.", 
										 @"Error explanation");
	NSMutableDictionary* userInfo = ErrorUserInfo (title, error, context);
	[userInfo setObject: predicate forKey: kBXPredicateKey];
	return [BXError errorWithDomain: kBXErrorDomain code: kBXErrorPredicateNotAllowedForUpdateDelete userInfo: userInfo];
}


static NSError*
TableNotFoundError (BXDatabaseContext* context, BXEntityDescription* entity)
{
	NSString* errorFormat = BXLocalizedString (@"relationNotFound", @"Relation %@ was not found in schema %@.", @"Error message for getting or using an entity description.");
	NSString* errorMessage = [NSString stringWithFormat: errorFormat, [entity name], [entity schemaName]];
	NSError* retval = DatabaseError (kBXErrorNoTableForEntity, errorMessage, context, entity);
	return retval;
}


/**
 * \internal
 * \brief Create object IDs from a PGTSResultSet.
 * \param entity The IDs' entity.
 */
static NSArray*
ObjectIDs (BXEntityDescription* entity, PGTSResultSet* res)
{
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [res count]];
	while ([res advanceRow])
	{
		NSDictionary* pkey = [res currentRowAsDictionary];
		BXDatabaseObjectID* objectID = [BXDatabaseObjectID IDWithEntity: entity
													   primaryKeyFields: pkey];
		[retval addObject: objectID];
	}
	
	return retval;
}


static NSString*
SetClause (BXPGQueryBuilder* queryBuilder, NSDictionary* valueDict)
{
    NSMutableArray* fields = [NSMutableArray arrayWithCapacity: [valueDict count]];
    BXEnumerate (field, e, [valueDict keyEnumerator])
    {
		id value = [valueDict objectForKey: field];
		NSString* valueParam = [queryBuilder addParameter: value];
		NSString* name = [field name];
		NSString* qname = [NSString stringWithFormat: @"\"%@\" = %@", name, valueParam];
		[fields addObject: qname];
	}
    return [fields componentsJoinedByString: @", "];
}


static void
MarkLocked (BXPGTransactionHandler* transactionHandler, 
			BXEntityDescription* entity, 
			BXPGQueryBuilder* queryBuilder, 
			NSString* whereClause,
			NSArray* parameters,
			BOOL willDelete)
{
	BXPGFromItem* fromItem = [queryBuilder primaryRelation];
	NSString* alias = [fromItem alias];
	NSString* fromClause = [queryBuilder fromClauseForSelect];
	
	ExpectCV (entity);
	ExpectCV (alias);
	ExpectCV (fromClause);
	ExpectCV (whereClause);

	[transactionHandler markLocked: entity
					 relationAlias: alias 
						fromClause: fromClause
					   whereClause: whereClause
						parameters: parameters 
						willDelete: willDelete];
}


/**
 * \brief An error handler for ROLLBACK errors.
 *
 * The intended use is to set a symbolic breakpoint for possible errors caught during ROLLBACK.
 */
static void
bx_error_during_rollback (id self, NSError* error)
{
	BXLogError (@"Got error during ROLLBACK: %@", [error localizedDescription]);
}


@implementation BXPGInterface
+ (void) initialize
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        [BXDatabaseContext setInterfaceClass: self forScheme: @"pgsql"];
		
		//Ensure that PGTSConnection gets initialized.
		[PGTSConnection class];
		[[PGTSMetadataStorage defaultStorage] setContainerClass: [BXPGEFMetadataContainer class]];
    }
}


- (id) init
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}


- (id) initWithContext: (BXDatabaseContext *) aContext
{
    if ((self = [super init]))
    {
        mContext = aContext; //Weak
		mLockedObjects = [[NSMutableSet alloc] init];
		mQueryBuilder = [[BXPGQueryBuilder alloc] init];
    }
    return self;
}


- (void) disconnect
{
	[mTransactionHandler disconnect];
	[mTransactionHandler release];
	mTransactionHandler = nil;
}


- (void) dealloc
{
	[mTransactionHandler release];
	[mLockedObjects release];
	[mQueryBuilder release];
	[super dealloc];
}


- (NSString *) description
{
	return [NSString stringWithFormat: @"<%@: %p (%@)>", [self class], self, mTransactionHandler];
}


- (BOOL) isSSLInUse
{
	return [mTransactionHandler isSSLInUse];
}


- (NSNumber *) defaultPort
{
	return [NSNumber numberWithInteger: 5432];
}


- (NSError *) connectionErrorForContext: (NSError *) error
{
	NSInteger code = kBXErrorUnknown;
	switch ([error code])
	{
		case kPGTSConnectionErrorSSLUnavailable:
			code = kBXErrorSSLUnavailable;
			break;
			
		case kPGTSConnectionErrorSSLCertificateVerificationFailed:
			code = kBXErrorSSLCertificateVerificationFailed;
			break;
			
		case kPGTSConnectionErrorSSLError:
			code = kBXErrorSSLError;
			break;
			
		case kPGTSConnectionErrorPasswordRequired:
		case kPGTSConnectionErrorInvalidPassword:
			code = kBXErrorAuthenticationFailed;
			break;
			
		case kPGTSConnectionErrorUnknown:
		default:
			break;
	}
	
	NSMutableDictionary* userInfo = [[[error userInfo] mutableCopy] autorelease];
	[userInfo setObject: error forKey: NSUnderlyingErrorKey];
	NSError* newError = [BXError errorWithDomain: kBXErrorDomain code: code userInfo: userInfo];
	return newError;
}


- (NSArray *) executeQuery: (NSString *) queryString parameters: (NSArray *) parameters error: (NSError **) error
{
	Expect (queryString);
	Expect (error);
	
	NSArray* retval = nil;
	if (! [mTransactionHandler canSend: error]) 
		goto error;

	PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: queryString parameterArray: parameters];
	if (YES == [res querySucceeded])
		retval = [res resultAsArray];
	else
	{
        //FIXME: reason for error!
		*error = [BXError errorWithDomain: kBXErrorDomain
									 code: kBXErrorUnsuccessfulQuery
								 userInfo: nil];
	}
	
error:
	return retval;
}


- (unsigned long long) executeCommand: (NSString *) commandString error: (NSError **) error;
{
	ExpectR (error, 0);

	unsigned long long retval = 0;
	if (! [mTransactionHandler canSend: error]) 
		goto error;

	PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: commandString];
	if (YES == [res querySucceeded])
		retval = [res numberOfRowsAffectedByCommand];
	else
	{
        //FIXME: reason for error?
		*error = [BXError errorWithDomain: kBXErrorDomain
									 code: kBXErrorUnsuccessfulQuery
								 userInfo: nil];		
	}
	
error:
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
	
	if (! [mTransactionHandler canSend: error]) goto error;
	if (! [mTransactionHandler savepointIfNeeded: error]) goto error;
	if (! [entity isValidated])
	{
		*error = TableNotFoundError (mContext, entity);
		goto error;
	}
	if ([entity hasCapability: kBXEntityCapabilityAutomaticUpdate])
		if (! [mTransactionHandler observeIfNeeded: entity error: error]) goto error;
		
	//Inserted values
	[mQueryBuilder reset];
	[mQueryBuilder setQueryType: kBXPGQueryTypeInsert];
	[mQueryBuilder addPrimaryRelationForEntity: entity]; //The predicate parser uses this to validate key paths.
	NSString* query = [self insertQuery: entity fieldValues: valueDict error: error];
	if (! query) goto error;
	
	NSArray* parameters = [mQueryBuilder parameters];
	PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: query parameterArray: parameters];
	if (! [res querySucceeded])
	{
		//FIXME: pack errors elsewhere, too.
		*error = [[self databaseContext] packQueryError: [res error]];
		goto error;
	}
	
	Expect (1 == [res count]);
	[res setRowClass: aClass];
	[res advanceRow];
	retval = [res currentRowAsObject];
	
	[mTransactionHandler checkSuperEntities: entity];
	
error:
	return retval;
}


- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity 
                             withPredicate: (NSPredicate *) predicate 
                           returningFaults: (BOOL) returnFaults 
                                     class: (Class) aClass 
                                     error: (NSError **) error
{
	return [self executeFetchForEntity: entity withPredicate: predicate returningFaults: returnFaults 
								 class: aClass forUpdate: NO error: error];
}


- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity 
                             withPredicate: (NSPredicate *) predicate 
                           returningFaults: (BOOL) returnFaults 
                                     class: (Class) aClass
								 forUpdate: (BOOL) forUpdate
                                     error: (NSError **) error
{
	Expect (entity);
	Expect (aClass);
	Expect (error);
    NSArray* retval = nil;
	if (! [mTransactionHandler canSend: error]) goto error;
	if (! [entity isValidated])
	{
		*error = TableNotFoundError (mContext, entity);
		goto error;
	}	
	PGTSTableDescription* table = [self tableForEntity: entity];
	Expect (table);
	if ([entity hasCapability: kBXEntityCapabilityAutomaticUpdate])
		if (! [mTransactionHandler observeIfNeeded: entity error: error]) goto error;
	
	PGTSConnection* connection = [mTransactionHandler connection];
	[mQueryBuilder reset];
	[mQueryBuilder setQueryType: kBXPGQueryTypeSelect];
	[mQueryBuilder addPrimaryRelationForEntity: entity];
	NSString* queryFormat = SelectQueryFormat (connection, forUpdate);
	NSString* returnedFields = ReturnedFieldsByCallback (mQueryBuilder, &ShouldReturn, YES);	
	struct bx_predicate_st predicateContainer = WhereClauseUsingEntity (mQueryBuilder, predicate, entity, connection);
	NSString* whereClause = predicateContainer.p_where_clause;
	Expect (whereClause);
	NSString* fromClause = [mQueryBuilder fromClause];
	
	NSString* query = [NSString stringWithFormat: queryFormat, returnedFields, fromClause, whereClause];
	NSArray* parameters = [mQueryBuilder parameters];
	
	PGTSResultSet* res = [connection executeQuery: query parameterArray: parameters];
	if (! [res querySucceeded])
	{
		*error = [res error];
		goto error;
	}
	else
	{
		NSPredicate* filterPredicate = nil;
		if (predicateContainer.p_results_require_filtering)
			filterPredicate = predicate;
		retval = Result (mContext, entity, res, aClass, filterPredicate);
	}

error:
	return retval;
}


- (NSArray *) executeUpdateWithDictionary: (NSDictionary *) valueDict
                                 objectID: (BXDatabaseObjectID *) objectID
                                   entity: (BXEntityDescription *) entity
                                predicate: (NSPredicate *) predicate
                                    error: (NSError **) error
{
	Expect (valueDict);
	Expect (objectID || entity);
	Expect (error);
	
	NSArray* retval = nil;
	
	if (nil != objectID)
	{
		predicate = [objectID predicate];
		entity = [objectID entity];
	}
	
	if (! [entity isValidated])
	{
		*error = TableNotFoundError (mContext, entity);
		goto error;
	}		
	if (! [mTransactionHandler canSend: error]) goto error;
	if (! [mTransactionHandler savepointIfNeeded: error]) goto error;

	PGTSConnection* connection = [mTransactionHandler connection];
	[mQueryBuilder reset];
	[mQueryBuilder setQueryType: kBXPGQueryTypeUpdate];
	[mQueryBuilder addPrimaryRelationForEntity: entity];
	
	NSString* whereClause = WhereClauseUsingEntity (mQueryBuilder, predicate, entity, connection).p_where_clause;
	if (! whereClause)
	{
		*error = PredicateNotAllowedError (mContext, predicate);
		goto error;
	}
	NSArray* whereClauseParameters = [mQueryBuilder parameters];
	
	NSString* setClause = SetClause (mQueryBuilder, valueDict);
	NSString* updateQuery = UpdateQuery (mQueryBuilder, setClause, whereClause);
	NSArray* parameters = [mQueryBuilder parameters];
	
	PGTSResultSet* res = [connection executeQuery: updateQuery parameterArray: parameters];
	
	if (! [res querySucceeded])
	{
		*error = [res error];
		goto error;
	}
	else
	{
		if ([mContext sendsLockQueries])
			MarkLocked (mTransactionHandler, entity, mQueryBuilder, whereClause, whereClauseParameters, NO);
		[mTransactionHandler checkSuperEntities: entity];
		NSArray* objectIDs = ObjectIDs (entity, res);

		NSDictionary* values = (id) [[valueDict PGTSKeyCollectD] name];
		if (objectID)
		{
			BXDatabaseObject* object = [mContext registeredObjectWithID: objectID];
			[object setCachedValuesForKeysWithDictionary: values];
		}
		else
		{
			BXEnumerate (currentID, e, [objectIDs objectEnumerator])
			{
				BXDatabaseObject* object = [mContext registeredObjectWithID: currentID];
				[object setCachedValuesForKeysWithDictionary: values];
			}
		}
													   
		retval = objectIDs;
	}
	
error:
	return retval;
}


- (BOOL) fireFault: (BXDatabaseObject *) anObject keys: (NSArray *) keys error: (NSError **) error
{
	ExpectR (error, NO);
	BXAssertValueReturn (0 < [keys count], NO, @"Expected to have received some keys to fetch.");
	
    BOOL retval = NO;
	if (! [mTransactionHandler canSend: error]) goto error;
	
	NSPredicate* predicate = [[anObject objectID] predicate];
	PGTSConnection* connection = [mTransactionHandler connection];
	[mQueryBuilder reset];
	[mQueryBuilder setQueryType: kBXPGQueryTypeSelect];
	[mQueryBuilder addPrimaryRelationForEntity: [anObject entity]];
	NSString* queryFormat = SelectQueryFormat (connection, NO);
	NSString* returnedFields = ReturnedFields (mQueryBuilder, keys, YES);
	NSString* whereClause = WhereClauseUsingObject (mQueryBuilder, predicate, anObject).p_where_clause;
	ExpectR (whereClause, NO);
	NSString* fromClause = [mQueryBuilder fromClause];
	NSString* query = [NSString stringWithFormat: queryFormat, returnedFields, fromClause, whereClause];

	NSArray* parameters = [mQueryBuilder parameters];
	PGTSResultSet* res = [connection executeQuery: query parameterArray: parameters];
	if (! [res querySucceeded])
		*error = [res error];
	else
	{
		[res advanceRow];
		[anObject setCachedValuesForKeysWithDictionary: [res currentRowAsDictionary]];
		retval = YES;
	}
	
error:
	return retval;
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
	
	if (! [mTransactionHandler canSend: error]) goto error;
	if (! [mTransactionHandler savepointIfNeeded: error]) goto error;
	if (! [entity isValidated])
	{
		*error = TableNotFoundError (mContext, entity);
		goto error;
	}
	PGTSTableDescription* table = [self tableForEntity: entity];
	Expect (table);
	if ([entity hasCapability: kBXEntityCapabilityAutomaticUpdate])
		if (! [mTransactionHandler observeIfNeeded: entity error: error]) goto error;
	
	PGTSConnection* connection = [mTransactionHandler connection];
	[mQueryBuilder reset];
	[mQueryBuilder setQueryType: kBXPGQueryTypeDelete];
	[mQueryBuilder addPrimaryRelationForEntity: entity];
	NSString* whereClause = WhereClauseUsingEntity (mQueryBuilder, predicate, entity, connection).p_where_clause;
	if (! whereClause)
	{
		*error = PredicateNotAllowedError (mContext, predicate);
		goto error;
	}
	
	NSString* query = DeleteQuery (mQueryBuilder, whereClause);
	NSArray* parameters = [mQueryBuilder parameters];
	
	PGTSResultSet* res = [connection executeQuery: query parameterArray: parameters];
	if ([res querySucceeded])
	{
		if ([mContext sendsLockQueries])
			MarkLocked (mTransactionHandler, entity, mQueryBuilder, whereClause, parameters, YES);
		[mTransactionHandler checkSuperEntities: entity];
		retval = ObjectIDs (entity, res);
	}
	else
	{
		*error = [res error];
	}
	
	BXAssertLog (! objectID || 0 == [retval count] || (1 == [retval count] && [retval containsObject: objectID]),
				   @"Expected to have deleted only one row. \nobjectID: %@\npredicate: %@\nretval: %@",
				   objectID, predicate, retval);
	
error:
	return retval;
}


- (void) reloadDatabaseMetadata
{
	[mTransactionHandler reloadDatabaseMetadata];
}


- (void) prepareForEntityValidation
{
	//Warm-up the cache by ensuring that an entity exists for each table.
	BXDatabaseObjectModel* objectModel = [mContext databaseObjectModel];
	BXEnumerate (schema, e, [[[mTransactionHandler databaseDescription] schemasByName] objectEnumerator])
	{
		BXEnumerate (table, e, [[schema allTables] objectEnumerator])
		{
			[objectModel entityForTable: [table name] inSchema: [table schemaName] error: NULL];
		}
	}
}
	
	
- (NSDictionary *) relationshipBySrcSchemaAndName
{
	NSString* query = 
	@"SELECT "
	@"	conid, "
    @"	dstconid, "
    @"	name, "
    @"	inversename, "
    @"	kind, "
    @"	is_inverse, "
	@"  is_deprecated, "
	@"	srcnspname, "
    @"	srcrelname, "
	@"	dstnspname, "
	@"	dstrelname, "
	@"	helpernspname, "
	@"	helperrelname "
	@"FROM baseten.relationship "
	@"ORDER BY srcnspname, srcrelname ASC ";
	PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: query];

	NSMutableDictionary* retval = [NSMutableDictionary dictionary];
	while (([res advanceRow]))
	{
		NSDictionary* currentRow = [res currentRowAsDictionary];
		NSString* srcnspname = [currentRow objectForKey: @"srcnspname"];
		NSString* srcrelname = [currentRow objectForKey: @"srcrelname"];
		
		NSMutableDictionary* schema = [retval objectForKey: srcnspname];
		if (! schema)
		{
			schema = [NSMutableDictionary dictionary];
			[retval setObject: schema forKey: srcnspname];
		}
		
		NSMutableArray* relation = [schema objectForKey: srcrelname];
		if (! relation)
		{
			relation = [NSMutableArray array];
			[schema setObject: relation forKey: srcrelname];
		}
		
		[relation addObject: currentRow];
	}
	
	return retval;
}


- (BOOL) validateEntities: (NSArray *) entities error: (NSError **) outError
{
	BOOL retval = NO;
	NSDictionary* allRelationships = nil;
	BXDatabaseObjectModel* objectModel = [mContext databaseObjectModel];
	NSDictionary* classDict = [[mTransactionHandler connection] deserializationDictionary];

	NSMutableDictionary* currentAttributes = [NSMutableDictionary dictionary];
	NSMutableDictionary* currentRelationships = [NSMutableDictionary dictionary];
	
	BXPGDatabaseDescription* database = [mTransactionHandler databaseDescription];
	NSNumber* currentCompatVersion = [BXPGVersion currentCompatibilityVersionNumber];
	BOOL haveBaseTenSchema = ([currentCompatVersion isEqualToNumber: [database schemaCompatibilityVersion]]);
	
	BXEnumerate (entity, e, [entities objectEnumerator])
	{
		if ([entity beginValidation])
		{
			BXPGTableDescription* table = [self tableForEntity: entity];
			if (! table)
			{
				//Entity has been created before connecting but it doesn't exist.
				continue;
			}
			
			//Entity
			{
				if ('v' == [table kind])
					[entity setIsView: YES];
				
				if ([table isEnabled])
				{
					[entity setEnabled: YES];
					[entity setHasCapability: kBXEntityCapabilityAutomaticUpdate to: YES];
					[entity setHasCapability: kBXEntityCapabilityRelationships to: YES];
				}
			}
			
			//Attributes
			{
				[currentAttributes removeAllObjects];
				NSDictionary* columns = [table columns];
				NSSet* pkeyColumns = [[table primaryKey] columns];
				BXEnumerate (column, e, [columns objectEnumerator])
				{
					NSString* name = [column name];
					BXAttributeDescription* attr = [BXAttributeDescription attributeWithName: name entity: entity];
					
					//Primary key
					BOOL isPkey = [pkeyColumns containsObject: column];
					if (isPkey)
						[attr setPrimaryKey: YES];					
					BOOL isOptional = (! ([column isNotNull] || isPkey));
					[attr setOptional: isOptional];
					
					//Optionality
					NSString* typeName = [[(PGTSColumnDescription *) column type] name];
					[attr setDatabaseTypeName: typeName];
					[attr setAttributeValueClass: [classDict objectForKey: typeName] ?: [NSData class]];
					
					//Internal fields are excluded by default.
					NSInteger idx = [column index];
					if (idx <= 0)
					{
						[attr setExcludedByDefault: YES];
						[attr setExcluded: YES];					
					}
					
					[currentAttributes setObject: attr forKey: name];
				}
				[(BXEntityDescription *) entity setAttributes: currentAttributes];
			}
			
			//Relationships
			if (haveBaseTenSchema)
			{
				[currentRelationships removeAllObjects];
				
				if (! allRelationships)
					allRelationships = [self relationshipBySrcSchemaAndName];
				
				NSDictionary* relations = [allRelationships objectForKey: [table schemaName]];
				NSArray* relationships = [relations objectForKey: [table name]];
				BXEnumerate (currentRel, e, [relationships objectEnumerator])
				{
					const unichar kind = [[currentRel objectForKey: @"kind"] characterAtIndex: 0];
					
					id rel = nil;
					NSString* name = [currentRel objectForKey: @"name"];
					NSString* dstrelname = [currentRel objectForKey: @"dstrelname"];
					NSString* dstnspname = [currentRel objectForKey: @"dstnspname"];
					BXEntityDescription* dstEntity = [objectModel entityForTable: dstrelname inSchema: dstnspname error: NULL];
					switch (kind)
					{
						case 't':
							rel = [[[BXRelationshipDescription alloc] initWithName: name 
																			entity: entity 
																 destinationEntity: dstEntity] autorelease];
							break;
							
						case 'o':
							rel = [[[BXOneToOneRelationshipDescription alloc] initWithName: name 
																					entity: entity 
																		 destinationEntity: dstEntity] autorelease];
							break;
							
						case 'm':
							rel = [[[BXManyToManyRelationshipDescription alloc] initWithName: name 
																					  entity: entity 
																		   destinationEntity: dstEntity] autorelease];
							break;
							
						default:
							break;
					}
										
					//Foreign key
					NSInteger conid = [[currentRel objectForKey: @"conid"] integerValue];
					BXPGForeignKeyDescription* fkey = [database foreignKeyWithIdentifier: conid];
					ExpectL (fkey);
					[rel setForeignKey: fkey];

					//Inverse name
					[rel setInverseName: [currentRel objectForKey: @"inversename"]];
					
					//Inversity					
					[rel setIsInverse: [[currentRel objectForKey: @"is_inverse"] boolValue]];
					
					//Deprecation
					[rel setDeprecated: [[currentRel objectForKey: @"is_deprecated"] boolValue]];
					
					//Optionality
					//FIXME: all relationships are now treated as optional. NULL constraints should be checked, though.
					[rel setOptional: YES];
		
					if ('m' == kind)
					{
						NSInteger dstconid = [[currentRel objectForKey: @"dstconid"] integerValue];
						BXPGForeignKeyDescription* dstFkey = [database foreignKeyWithIdentifier: dstconid];
						[rel setDstForeignKey: dstFkey];
						
						NSString* helperrelname = [currentRel objectForKey: @"helperrelname"];
						NSString* helpernspname = [currentRel objectForKey: @"helpernspname"];
						BXEntityDescription* helper = [objectModel entityForTable: helperrelname inSchema: helpernspname error: NULL];
						
						//The helper entity may get changed by trigger if rows are deleted from source
						//and destination entities.
						[helper setGetsChangedByTriggers: YES];                                         
						[rel setHelperEntity: helper];
					}
					
					[currentRelationships setObject: rel forKey: name];
				}
				
				[entity setRelationships: currentRelationships];
			}
			
			[entity setValidated: YES];
			[entity endValidation];
		}
	}
	
	retval = YES;
	
//bail:
	return retval;
}


- (BXPGTableDescription *) tableForEntity: (BXEntityDescription *) entity
{
	return [self tableForEntity: entity inDatabase: [mTransactionHandler databaseDescription]];
}


- (BXPGTableDescription *) tableForEntity: (BXEntityDescription *) entity 
							   inDatabase: (BXPGDatabaseDescription *) database 
{
	ExpectR (entity, NO);
	ExpectR (database, NO);

	return [database table: [entity name] inSchema: [entity schemaName]];
}


/** 
 * \internal
 * \brief Lock an object asynchronously.
 *
 * Lock notifications should always be listened to, since modifications cause the rows to be locked until
 * the end of the ongoing transaction.
 */
//FIXME: unlock on -discardEditing?
- (void) lockObject: (BXDatabaseObject *) anObject key: (id) aKey 
		   lockType: (enum BXObjectLockStatus) type
             sender: (id <BXObjectAsynchronousLocking>) sender
{
	if (mLocking)
		[sender BXLockAcquired: NO object: anObject error: nil]; //FIXME: set the error.
	else if ([mLockedObjects containsObject: anObject])
		[sender BXLockAcquired: YES object: anObject error: nil];
	else
	{
		NSError* error = nil;
		if (! [mTransactionHandler canSend: &error])
			[sender BXLockAcquired: NO object: anObject error: error];
		
		mLocking = YES;
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  sender, kBXPGLockerKey,
								  anObject, kBXPGObjectKey,
								  nil];
		[mTransactionHandler beginAsyncSubTransactionFor: self callback: @selector (begunForLocking:) userInfo: userInfo];
	}
}

- (void) begunForLocking: (id <BXPGResultSetPlaceholder>) placeholderResult
{
	NSDictionary* userInfo = [placeholderResult userInfo];
	id <BXObjectAsynchronousLocking> sender = [userInfo objectForKey: kBXPGLockerKey];
	if ([placeholderResult querySucceeded])
	{
		BXDatabaseObject* object = [userInfo objectForKey: kBXPGObjectKey];		
		BXDatabaseObjectID* objectID = [object objectID];
		BXEntityDescription* entity = [objectID entity];
		PGTSConnection* connection = [mTransactionHandler connection];
		NSPredicate* predicate = [objectID predicate];
		
		[mQueryBuilder reset];
		[mQueryBuilder setQueryType: kBXPGQueryTypeSelect];
		[mQueryBuilder addPrimaryRelationForEntity: entity];
		
		NSString* whereClause = [mQueryBuilder whereClauseForPredicate: predicate entity: entity connection: connection].p_where_clause;
		NSString* fromClause = [mQueryBuilder fromClause];
		NSString* queryFormat = @"SELECT null FROM ONLY %@ WHERE %@ FOR UPDATE NOWAIT";
		NSString* queryString = [NSString stringWithFormat: queryFormat, fromClause, whereClause];
		NSString* alias = [[mQueryBuilder primaryRelation] alias];
		NSArray* parameters = [mQueryBuilder parameters];
		
		ExpectV (sender);
		ExpectV (object);
		ExpectV (alias);
		ExpectV (fromClause);
		ExpectV (whereClause);
		ExpectV (parameters);

		NSDictionary* newUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									 sender, kBXPGLockerKey,
									 object, kBXPGObjectKey,
									 alias, kBXPGPrimaryRelationAliasKey,
									 fromClause, kBXPGFromClauseKey,
									 whereClause, kBXPGWhereClauseKey,
									 parameters, kBXPGParametersKey,
									 nil];
		[connection sendQuery: queryString delegate: self callback: @selector (lockedRow:) 
			   parameterArray: parameters userInfo: newUserInfo];	
	}
	else
	{
		[sender BXLockAcquired: NO object: nil error: [placeholderResult error]];
		[mTransactionHandler rollbackSubtransaction];
		mLocking = NO;
	}
}


- (void) lockedRow: (PGTSResultSet *) res
{
	NSDictionary* userInfo = [res userInfo];
	id <BXObjectAsynchronousLocking> sender = [userInfo objectForKey: kBXPGLockerKey];
	BXDatabaseObject* object = [userInfo objectForKey: kBXPGObjectKey];
	
	if ([res querySucceeded])
	{
		[mLockedObjects addObject: object];
		NSString* alias = [userInfo objectForKey: kBXPGPrimaryRelationAliasKey];
		NSString* fromClause = [userInfo objectForKey: kBXPGFromClauseKey];
		NSString* whereClause = [userInfo objectForKey: kBXPGWhereClauseKey];
		NSArray* parameters = [userInfo objectForKey: kBXPGParametersKey];
		[sender BXLockAcquired: YES object: object error: nil];

		
		[mTransactionHandler markLocked: [object entity]
						  relationAlias: alias
							 fromClause: fromClause
							whereClause: whereClause 
							 parameters: parameters
							 willDelete: NO];
	}
	else
	{
		[sender BXLockAcquired: NO object: nil error: [res error]];
		[mTransactionHandler rollbackSubtransaction];
	}
	mLocking = NO;
}


/**
 * \internal
 * \brief Unlock a locked object synchronously.
 */
- (void) unlockObject: (BXDatabaseObject *) anObject key: (id) aKey
{
	if ([mLockedObjects containsObject: anObject])
	{
		[mLockedObjects removeObject: anObject];
	
		NSError* localError = nil;
		if (! [mTransactionHandler endSubtransactionIfNeeded: &localError])
		{
			BXLogError (@"Subtransaction failed! Error: %@", localError);
			[mTransactionHandler rollbackSubtransaction];
		}
	}
}


- (void) prepareForConnecting
{
	if (! mTransactionHandler)
	{
		Class transactionHandlerClass = Nil;
		if ([mContext autocommits])
			transactionHandlerClass = [BXPGAutocommitTransactionHandler class];
		else
			transactionHandlerClass = [BXPGManualCommitTransactionHandler class];
		mTransactionHandler = [[transactionHandlerClass alloc] init];
		[mTransactionHandler setInterface: self];
	}
}


- (BOOL) connectSync: (NSError **) error
{
	ExpectR (error, NO);
	
	[self prepareForConnecting];
	BOOL retval = [mTransactionHandler connectSync: error];
	if (error && *error)
		*error = [self connectionErrorForContext: *error];
	return retval;
}


- (void) connectAsync
{
	[self prepareForConnecting];
	[mTransactionHandler connectAsync];
}


- (BXDatabaseContext *) databaseContext
{
	return mContext;
}


- (void) setTransactionHandler: (BXPGTransactionHandler *) handler
{
	if (handler != mTransactionHandler)
	{
		[mTransactionHandler release];
		mTransactionHandler = [handler retain];
	}
}


- (BOOL) autocommits
{
	return [mTransactionHandler autocommits];
}


- (BOOL) connected
{
	return [mTransactionHandler connected];
}


- (void) setAutocommits: (BOOL) aBool
{
	//FIXME: commit mode may only be changed before connecting.
}


- (BOOL) save: (NSError **) error
{
	BOOL retval = NO;
	if ([mTransactionHandler save: error])
	{
		[mLockedObjects removeAllObjects];
		retval = YES;
	}
	return retval;
}


- (void) rollback
{
    if ([self connected])
    {
		[mLockedObjects removeAllObjects];
		NSError* localError = nil;
		[mTransactionHandler rollback: &localError];
		if (localError) bx_error_during_rollback (self, localError);
    }
}


- (BOOL) rollbackToLastSavepoint: (NSError **) error
{
	return [mTransactionHandler rollbackToLastSavepoint: error];
}


- (BOOL) establishSavepoint: (NSError **) error
{
	return [mTransactionHandler savepointIfNeeded: error];
}


- (void) handledTrust: (SecTrustRef) trust accepted: (BOOL) accepted
{
	[mTransactionHandler handledTrust: trust accepted: accepted];
}

- (NSArray *) observedOids
{
	return [mTransactionHandler observedOids];
}

/**
 * \internal
 * \brief Create an insert query.
 */
- (NSString *) insertQuery: (BXEntityDescription *) entity fieldValues: (NSDictionary *) fieldValues error: (NSError **) error
{
	Expect (entity);
	Expect (error);

	NSString* retval = nil;
	NSArray* pkeyFields = [entity primaryKeyFields];
	NSString* returnedFields = ReturnedFields (mQueryBuilder, pkeyFields, NO);
	NSString* entityName = [NSString stringWithFormat: @"\"%@\".\"%@\"", [entity schemaName], [entity name]];
	
	//If the entity is a view and the user hasn't specified default values for the underlying tables'
	//primary key fields, we try to do them a favour and insert the default value expressions if
	//they are known.
	NSMutableDictionary* viewDefaultValues = nil;
	if ([entity isView])
	{
		viewDefaultValues = [NSMutableDictionary dictionaryWithCapacity: [pkeyFields count]];
		BXEnumerate (currentAttr, e, [pkeyFields objectEnumerator])
		{
			if (! [fieldValues objectForKey: currentAttr])
			{
				NSString* valueExpression = [self viewDefaultValue: currentAttr error: error];
				if (* error) 
					goto error;
				else if (valueExpression)
					[viewDefaultValues setObject: valueExpression forKey: currentAttr];
			}
		}
	}
		
	if (! [fieldValues count] && ! [viewDefaultValues count])
	{
		NSString* format = @"INSERT INTO %@ DEFAULT VALUES RETURNING %@";
		retval = [NSString stringWithFormat: format, entityName, returnedFields];
	}
	else
	{
		NSMutableString* fields = [NSMutableString string];
		NSMutableString* values = [NSMutableString string];
		
		BXEnumerate (currentAttr, e, [fieldValues keyEnumerator])
		{
			id value = [fieldValues objectForKey: currentAttr];
			NSString* alias = [mQueryBuilder addParameter: value];
			
			[fields appendString: @"\""];
			[fields appendString: [currentAttr name]];
			[fields appendString: @"\", "];
			
			[values appendString: alias];
			[values appendString: @", "];
		}
		
		BXEnumerate (currentAttr, e, [viewDefaultValues keyEnumerator])
		{
			NSString* expression = [viewDefaultValues objectForKey: currentAttr];

			[fields appendString: @"\""];
			[fields appendString: [currentAttr name]];
			[fields appendString: @"\", "];
			
			[values appendString: expression];
			[values appendString: @", "];
		}
		
		RemoveCharactersFromEnd (fields, 2);
		RemoveCharactersFromEnd (values, 2);
		
		NSString* format = @"INSERT INTO %@ (%@) VALUES (%@) RETURNING %@";
		retval = [NSString stringWithFormat: format, entityName, fields, values, returnedFields];
	}
	
error:
	return retval;
}

- (NSString *) viewDefaultValue: (BXAttributeDescription *) attr error: (NSError **) error
{
	Expect (attr);
	Expect (error);
	
	return [self recursiveDefaultValue: [attr name] entity: [attr entity] error: error];
}
	
- (NSString *) recursiveDefaultValue: (NSString *) name entity: (BXEntityDescription *) entity error: (NSError **) error
{
	Expect (name);
	Expect (entity);
	Expect (error);
	
	NSString* defaultValue = nil;
	if ([entity isView])
	{
		BXEnumerate (currentEntity, e, [[entity inheritedEntities] objectEnumerator])
		{
			defaultValue = [self recursiveDefaultValue: name entity: currentEntity error: error];
			if (defaultValue || *error)
				break;
		}
	}
	else
	{
		PGTSTableDescription* table = [self tableForEntity: entity];
		if (table)
		{
			NSDictionary* columns = [table columns];
			defaultValue = [[columns objectForKey: name] defaultValue];
		}
	}
	return defaultValue;
}

- (BOOL) canProcessEntities
{
	return [[mTransactionHandler databaseDescription] hasBaseTenSchema];
}

- (BOOL) removePrimaryKeyForEntity: (BXEntityDescription *) viewEntity error: (NSError **) outError
{
	ExpectR (viewEntity, NO);
	ExpectR ([viewEntity isView], NO);
	ExpectR (outError, NO);	
	
	BOOL retval = NO;
	if (! [mTransactionHandler canSend: outError])
		goto error;
	
	NSString* query = [NSString stringWithFormat: @"DELETE FROM baseten.view_pkey WHERE nspname = $1 AND relname = $2"];
	PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: query parameters: [viewEntity schemaName], [viewEntity name]];
	if ([res querySucceeded])
	{
		retval = YES;
		BXEnumerate (currentAttribute, e, [viewEntity primaryKeyFields])
			[currentAttribute setPrimaryKey: NO];
	}
	else
	{
		*outError = [res error];
	}
error:
	return retval;
}

- (BOOL) process: (BOOL) shouldAdd primaryKeyFields: (NSArray *) attributeArray error: (NSError **) outError
{
	ExpectR (attributeArray, NO);
	ExpectR (outError, NO);

	BOOL retval = NO;

	if (! [mTransactionHandler canSend: outError])
		goto bail;

	retval = YES;
	
	BXEnumerate (currentAttribute, e, [attributeArray objectEnumerator])
	{
		BXEntityDescription* entity = [(BXAttributeDescription *) currentAttribute entity];
		if ([entity isView] && [currentAttribute isPrimaryKey] != shouldAdd)
		{
			NSString* queryFormat = nil;
			if (shouldAdd)
				queryFormat = @"INSERT INTO baseten.view_pkey (nspname, relname, attname) VALUES ($1, $2, $3)";
			else
				queryFormat = @"DELETE FROM baseten.view_pkey WHERE nspname = $1 AND relname = $2 AND attname = $3";
			
			PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: queryFormat parameters: 
								  [entity schemaName], [entity name], [currentAttribute name]];
			if ([res querySucceeded])
				[currentAttribute setPrimaryKey: shouldAdd];
			else
			{
				retval = NO;
				*outError = [res error];
				break;
			}
		}
	}
bail:
	return retval;
}

- (BOOL) process: (BOOL) shouldEnable entities: (NSArray *) entityArray error: (NSError **) outError
{
	ExpectR (entityArray, NO);
	ExpectR (outError, NO);
	BOOL retval = NO;
	
	if (! [mTransactionHandler canSend: outError])
		goto bail;
	
	NSMutableArray* oids = [NSMutableArray arrayWithCapacity: [entityArray count]];
	BXEnumerate (currentEntity, e, [entityArray objectEnumerator])
	{
		if ([currentEntity isEnabled] != shouldEnable)
		{
			PGTSTableDescription* table = [self tableForEntity: currentEntity];
			if (table)
				[oids addObject: PGTSOidAsObject ([table oid])];
			else
				goto bail;
		}
	}
	
	if (0 < [oids count])
	{
		NSString* query = nil;
		if (shouldEnable)
		{
			query =
			@"SELECT baseten.enable ($1 [s]) "
			"  FROM generate_series (1, array_upper ($1::OID[], 1)) AS s";
		}
		else
		{
			query =
			@"SELECT baseten.disable ($1 [s]) "
			"  FROM generate_series (1, array_upper ($1::OID[], 1)) AS s";
		}
		
		PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: query parameters: oids];
		if ([res querySucceeded])
		{
			BXEnumerate (currentEntity, e, [entityArray objectEnumerator])
				[currentEntity setEnabled: shouldEnable];
		}
		else
		{
			*outError = [res error];
			goto bail;
		}
	}
	
	retval = YES;
bail:
	return retval;
}

- (BXPGTransactionHandler *) transactionHandler
{
	return mTransactionHandler;
}

- (BOOL) hasBaseTenSchema
{
	return [[mTransactionHandler databaseDescription] hasBaseTenSchema];
}

- (NSNumber *) schemaVersion
{
	return [[mTransactionHandler databaseDescription] schemaVersion];
}

- (NSNumber *) schemaCompatibilityVersion
{
	return [[mTransactionHandler databaseDescription] schemaCompatibilityVersion];
}

- (NSNumber *) frameworkCompatibilityVersion
{
	return [BXPGVersion currentCompatibilityVersionNumber];
}

- (BOOL) checkSchemaCompatibility: (NSError **) outError;
{
	ExpectR (outError, NO);
	
	BOOL retval = YES;
	NSNumber* current = [self schemaCompatibilityVersion];
	NSNumber* builtWith = [self frameworkCompatibilityVersion];
	if (NSOrderedDescending == [current compare: builtWith])
	{
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  @"The database version is newer than what this application is capable of handling", NSLocalizedFailureReasonErrorKey,
								  @"Try upgrading your client application.", NSLocalizedRecoverySuggestionErrorKey,
								  nil];
		//FIXME: set domain and code.
		NSError* error = [BXError errorWithDomain: @"" code: 1 userInfo: userInfo];
		*outError = error;
	}
	return retval;
}

- (void) setLogsQueries: (BOOL) shouldLog
{
	[mTransactionHandler setLogsQueries: shouldLog];
}

- (BOOL) logsQueries
{
	return [mTransactionHandler logsQueries];
}

- (BOOL) usedPassword
{
	return [mTransactionHandler usedPassword];
}
@end


@implementation BXPGInterface (ConnectionDelegate)
- (void) connectionSucceeded
{
	[mContext connectedToDatabase: YES async: YES error: NULL];
}

- (void) connectionFailed: (NSError *) error
{
	NSError* newError = [self connectionErrorForContext: error];
	[mContext connectedToDatabase: NO async: YES error: &newError];
}

- (void) connectionLost: (BXPGTransactionHandler *) handler error: (NSError *) error
{
	[mContext connectionLost: error];
}

- (FILE *) traceFile
{
	return NULL;
}

- (void) connection: (PGTSConnection *) connection sentQueryString: (const char *) queryString
{
	printf ("QUERY (%p) %s\n", connection, queryString);
}

- (void) connection: (PGTSConnection *) connection sentQuery: (PGTSQuery *) query
{
	printf ("QUERY  (%p) ", connection);
	[query visitQuery: self];
}

- (void) connection: (PGTSConnection *) connection receivedResultSet: (PGTSResultSet *) res
{
	printf ("RESULT (%p) ok: %d tuples: %d\n", connection, [res querySucceeded], [res count]);
}
@end


@implementation BXPGInterface (Visitor)
- (id) visitQuery: (PGTSQuery *) query
{	
	printf ("%s\n", [[query query] UTF8String]);
	return nil;
}

- (id) visitParameterQuery: (PGTSAbstractParameterQuery *) query
{
	printf ("%s\n", [[query query] UTF8String]);
	int i = 0;
	BXEnumerate (currentParameter, e, [[query parameters] objectEnumerator])
	{
		i++;
		const char* description = [[currentParameter description] UTF8String];
		printf ("\t%d: %.30s\n", i, description);
	}
	return nil;
}
@end
