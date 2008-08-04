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
#import "PGTSFunctions.h"
#import "BaseTen.h"
#import "BXRelationshipDescription.h"
#import "BXOneToOneRelationshipDescription.h"
#import "BXManyToManyRelationshipDescription.h"
#import "BXForeignKey.h"
#import "BXDatabaseAdditions.h";

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

#import "BXLogger.h"

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
	NSArray* qualifiedNames = (id) [[returned PGTSCollect] BXPGQualifiedName: connection];
	return [qualifiedNames componentsJoinedByString: @", "];	
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
FromClause (id self, PGTSConnection* connection, NSPredicate* predicate, BXEntityDescription* additionalEntity, BXEntityDescription* excludedEntity)
{
	NSString* fromClause = nil;
	
	NSMutableSet* entitySet = [NSMutableSet setWithSet: [predicate BXEntitySet]];
	BXAssertValueReturn (nil != entitySet, nil, @"Expected to receive an entity set (predicate: %@).", predicate);
	if (additionalEntity) [entitySet addObject: additionalEntity];
	//FIXME: a better way to exclude the corrent table for update would be to change BXEntitySet (above) so that in case of an update, it wouldn't return the target entity, unless a self-join was intended.
	if (excludedEntity) [entitySet removeObject: excludedEntity]; 
	
	if (0 < [entitySet count])
	{
		NSArray* components = (id) [[entitySet PGTSCollectReturning: [NSMutableArray class]] BXPGQualifiedName: connection];
		fromClause = [components componentsJoinedByString: @", "];
	}
	
	return fromClause;
}


/**
 * \internal
 * Create an NSArray from a PGTSResultSet.
 * Objects that are already registered wont'be recreated.
 */
static NSArray*
Result (BXDatabaseContext* context, BXEntityDescription* entity, PGTSResultSet* res, Class rowClass)
{
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [res count]];
	[res setRowClass: rowClass];
	while (([res advanceRow]))
	{
		BXDatabaseObject* currentRow = [res currentRowAsObject];
		
		//If the object is already in memory, don't make a copy
		if (NO == [currentRow registerWithContext: context entity: entity])
			currentRow = [context registeredObjectWithID: [currentRow objectID]];
		[retval addObject: currentRow];
	}
	return retval;
}


/**
 * \internal
 * Create an UPDATE query.
 */
static NSString*
UpdateQuery (PGTSConnection* connection, BXEntityDescription* entity, NSString* setClause, NSString* fromClause, NSString* whereClause)
{
	NSString* query = nil;
	NSString* entityName = [entity BXPGQualifiedName: connection];
	//FIXME: -BXPGEscapedName: might not get called here.
	NSString* pkeyFields = [(id) [[[entity primaryKeyFields] PGTSCollect] BXPGEscapedName: connection] componentsJoinedByString: @", "];
	if (fromClause)
	{
		NSString* queryFormat = @"UPDATE %@ SET %@ FROM %@ WHERE %@ RETURNING %@";
		query = [NSString stringWithFormat: queryFormat, entityName, setClause, fromClause, whereClause, pkeyFields];
	}
	else
	{
		NSString* queryFormat = @"UPDATE %@ SET %@ WHERE %@ RETURNING %@";
		query = [NSString stringWithFormat: queryFormat, entityName, setClause, whereClause, pkeyFields];
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
	ExpectCR (localizedError, nil);
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
SetClause (PGTSConnection* connection, NSDictionary* valueDict, NSMutableArray* parameters)
{
    NSMutableArray* fields = [NSMutableArray arrayWithCapacity: [valueDict count]];
    //Postgres's indexing is one-based
    unsigned int i = [parameters count] + 1;
    TSEnumerate (field, e, [valueDict keyEnumerator])
    {
        [parameters addObject: [valueDict objectForKey: field]];
		NSString* name = [field BXPGEscapedName: connection];
        [fields addObject: [NSString stringWithFormat: @"%@ = $%u", name, i]];
        i++;
    }
    return [fields componentsJoinedByString: @", "];
}


/**
 * An error handler for ROLLBACK errors.
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
        [BXDatabaseContext setInterfaceClass: [self class] forScheme: @"pgsql"];        
    }
}


- (id) initWithContext: (BXDatabaseContext *) aContext
{
    if ((self = [super init]))
    {
        mContext = aContext; //Weak
		mLockedObjects = [[NSMutableSet alloc] init];
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
	[mForeignKeys release];
	[mTransactionHandler release];
	[mLockedObjects release];
	[mFrameworkCompatVersion release];
	[super dealloc];
}


- (NSString *) description
{
	return [NSString stringWithFormat: @"<%@: %p (%@)>", [self class], self, mTransactionHandler];
}


- (NSError *) connectionErrorForContext: (NSError *) error
{
	NSInteger code = kBXErrorUnknown;	
	switch ([error code]) 
	{
		case kPGTSConnectionErrorSSLUnavailable:
			code = kBXErrorSSLError; //FIXME: this is too ambiguous. Differentiate between "SSL unavailable" and "other SSL error."
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
	NSError* newError = [NSError errorWithDomain: kBXErrorDomain code: code userInfo: userInfo];
	return newError;
}


- (NSArray *) executeQuery: (NSString *) queryString parameters: (NSArray *) parameters error: (NSError **) error
{
	Expect (queryString);
	Expect (error);
	
	NSArray* retval = nil;
	PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: queryString parameterArray: parameters];
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
	PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: commandString];
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
	
	if (! [mTransactionHandler savepointIfNeeded: error]) goto error;
	if (! [self validateEntity: entity error: error]) goto error;
	if ([entity hasCapability: kBXEntityCapabilityAutomaticUpdate])
		if (! [mTransactionHandler observeIfNeeded: entity error: error]) goto error;
		
	//Inserted values
	NSArray* insertedAttrs = [valueDict allKeys];
	NSString* query = [self insertQuery: entity insertedAttrs: insertedAttrs error: error];
	if (! query) goto error;
	
	NSArray* values = [valueDict objectsForKeys: insertedAttrs notFoundMarker: [NSNull null]];
	PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: query parameterArray: values];
	if (! [res querySucceeded])
	{
		//FIXME: pack errors elsewhere, too.
		*error = [[self databaseContext] packQueryError: [res error]];
		goto error;
	}
	
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
	PGTSTableDescription* table = [self tableForEntity: entity error: error];
	if (! table) goto error; //FIXME: set the error.
	if ([entity hasCapability: kBXEntityCapabilityAutomaticUpdate])
		if (! [mTransactionHandler observeIfNeeded: entity error: error]) goto error;
	
	PGTSConnection* connection = [mTransactionHandler connection];
	NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
	NSString* queryFormat = SelectQueryFormat (connection, forUpdate);
	NSString* returnedFields = ReturnedFields (connection, entity);
	NSString* fromClause = FromClause (self, connection, predicate, entity, nil);
	NSString* whereClause = WhereClause (connection, predicate, ctx);
	NSString* query = [NSString stringWithFormat: queryFormat, returnedFields, fromClause, whereClause];
	
	NSArray* parameters = [ctx objectForKey: kPGTSParametersKey];
	PGTSResultSet* res = [connection executeQuery: query parameterArray: parameters];
	if (! [res querySucceeded])
	{
		*error = [res error];
		goto error;
	}
	else
	{
		retval = Result (mContext, entity, res, aClass);
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
	
	if (! [mTransactionHandler savepointIfNeeded: error]) goto error;

	PGTSConnection* connection = [mTransactionHandler connection];
	NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
	NSString* whereClause = WhereClause (connection, predicate, ctx);
	NSMutableArray* parameters = [ctx objectForKey: kPGTSParametersKey] ?: [NSMutableArray array];
	NSString* fromClause = FromClause (self, connection, predicate, nil, entity);
	NSString* setClause = SetClause (connection, valueDict, parameters);
	NSString* updateQuery = UpdateQuery (connection, entity, setClause, fromClause, whereClause);
	PGTSResultSet* res = [connection executeQuery: updateQuery parameterArray: parameters];
	
	if ([res querySucceeded])
	{
		[mTransactionHandler markLocked: entity whereClause: whereClause parameters: parameters willDelete: NO];
		[mTransactionHandler checkSuperEntities: entity];
		NSArray* objectIDs = ObjectIDs (entity, res);

		NSDictionary* values = (id) [[valueDict PGTSKeyCollect] name];
		if (objectID)
		{
			BXDatabaseObject* object = [mContext registeredObjectWithID: objectID];
			[object setCachedValuesForKeysWithDictionary: values];
		}
		else
		{
			TSEnumerate (currentID, e, [objectIDs objectEnumerator])
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
	PGTSConnection* connection = [mTransactionHandler connection];
	NSString* fieldNames = [(id) [[keys PGTSCollect] BXPGQualifiedName: connection] componentsJoinedByString: @", "];
	NSPredicate* predicate = [[anObject objectID] predicate];

	NSString* fromClause = FromClause (self, connection, predicate, [anObject entity], nil);
	NSMutableDictionary* ctx = [NSMutableDictionary dictionary];
	[ctx setObject: connection forKey: kPGTSConnectionKey];
	NSString* whereClause = WhereClause (connection, predicate, ctx);
	NSString* queryFormat = SelectQueryFormat (connection, NO);

	NSString* query = [NSString stringWithFormat: queryFormat, fieldNames, fromClause, whereClause];
	NSArray* parameters = [ctx objectForKey: kPGTSParametersKey];
	PGTSResultSet* res = [connection executeQuery: query parameterArray: parameters];
	if (! [res querySucceeded])
		*error = [res error];
	else
	{
		[res advanceRow];
		[anObject setCachedValuesForKeysWithDictionary: [res currentRowAsDictionary]];
		retval = YES;
	}
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
	
	if (! [mTransactionHandler savepointIfNeeded: error]) goto error;
	PGTSTableDescription* table = [self tableForEntity: entity error: error];
	if (! table) goto error;
	if ([entity hasCapability: kBXEntityCapabilityAutomaticUpdate])
		if (! [mTransactionHandler observeIfNeeded: entity error: error]) goto error;
	
	PGTSConnection* connection = [mTransactionHandler connection];
	NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
	NSString* whereClause = WhereClause (connection, predicate, ctx);
	NSString* fromClause = [entity BXPGQualifiedName: connection];
	NSString* returnedFields = ReturnedFields (connection, entity);
	NSString* queryFormat = @"DELETE FROM %@ WHERE %@ RETURNING %@";
	NSString* query = [NSString stringWithFormat: queryFormat, fromClause, whereClause, returnedFields];
	NSArray* parameters = [ctx objectForKey: kPGTSParametersKey];
	PGTSResultSet* res = [connection executeQuery: query parameterArray: parameters];
	if ([res querySucceeded])
	{
		retval = ObjectIDs (entity, res);
		[mTransactionHandler checkSuperEntities: entity];
		[mTransactionHandler markLocked: entity whereClause: whereClause parameters: parameters willDelete: YES];
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


- (NSDictionary *) relationshipsForEntity: (BXEntityDescription *) entity
									error: (NSError **) error
{    
	Expect (entity);
	Expect (error);
    
	NSMutableDictionary* retval = [NSMutableDictionary dictionary];
	PGTSConnection* connection = [mTransactionHandler connection];

	if ([(id) [connection databaseDescription] hasBaseTenSchema] && [self fetchForeignKeys: error])
	{
		NSString* queryFormat = @"SELECT * FROM baseten.%@ WHERE srcnspname = $1 AND srcrelname = $2";
		NSString* views [4] = {@"onetomany", @"onetoone", @"manytomany", @"relationship_v"};
		
		//Relationships between views and between tables and views are stored in a different place.
		//If given entity is a view, we only need to check those.
		int i = 0;
		if ([entity isView])
			i = 3;
		
		while (i < 4)
		{
			NSString* queryString = [NSString stringWithFormat: queryFormat, views [i]];
			PGTSResultSet* res = [connection executeQuery: queryString parameters:
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
	
bail:
    return retval;
}


- (BOOL) fetchForeignKeys: (NSError **) outError
{
	ExpectR (outError, NO);
	BOOL retval = NO;
	if (mForeignKeys)
		retval = YES;
	else if ([[mTransactionHandler databaseDescription] hasBaseTenSchema])
	{
		NSString* query = @"SELECT * from baseten.foreignkey";
		PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: query];
		if (! [res querySucceeded])
		{
			*outError = [res error];
		}
		else
		{
			retval = YES;
			mForeignKeys = [[NSMutableDictionary alloc] init];
			while (([res advanceRow]))
			{
				BXForeignKey* key = [[[BXForeignKey alloc] initWithName: [res valueForKey: @"name"]] autorelease];
				
				NSArray* srcFNames = [res valueForKey: @"srcfnames"];
				NSArray* dstFNames = [res valueForKey: @"dstfnames"];
				BXAssertValueReturn ([srcFNames count] == [dstFNames count], NO,
									  @"Expected array counts to match. Row: %@.", 
									  [res currentRowAsDictionary]);
				
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
						break;
						
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
			}
		}
	}
	return retval;
}


- (BOOL) validateEntity: (BXEntityDescription *) entity error: (NSError **) error
{
	return (nil != [self tableForEntity: entity error: error]);
}


- (PGTSTableDescription *) tableForEntity: (BXEntityDescription *) entity error: (NSError **) error
{
	return [self tableForEntity: entity inDatabase: [mTransactionHandler databaseDescription] error: error];
}


- (PGTSTableDescription *) tableForEntity: (BXEntityDescription *) entity 
							   inDatabase: (BXPGDatabaseDescription *) database 
									error: (NSError **) error
{
	ExpectR (entity, NO);
	ExpectR (error, NO);
	ExpectR (database, NO);
	BXPGTableDescription* table = (id) [database table: [entity name] inSchema: [entity schemaName]];
	if (table)
	{
		if (! [entity isValidated])
		{
			[entity setValidated: YES];
			
			//If attributes exists, it only contains primary key fields but we haven't received them from the database.
			NSMutableDictionary* attributes = ([[[entity attributesByName] mutableCopy] autorelease] ?: [NSMutableDictionary dictionary]);
			
			//While we're at it, set the fields as well as the primary key.
			NSSet* pkey = [[table primaryKey] fields];
			[[[table fields] PGTSVisit: self] addAttributeFor: nil into: attributes entity: entity primaryKeyFields: pkey];
			[entity setAttributes: attributes];
			
			if ('v' == [table kind])
				[entity setIsView: YES];
			
			if ([table isEnabled])
			{
				[entity setEnabled: YES];
				[entity setHasCapability: kBXEntityCapabilityAutomaticUpdate to: YES];
				[entity setHasCapability: kBXEntityCapabilityRelationships to: YES];
			}
		}
	}
	else
	{
		NSString* errorFormat = BXLocalizedString (@"tableNotFound", @"Table %@ was not found in schema %@.", @"Error message for fetch");
		NSString* localizedError = [NSString stringWithFormat: errorFormat, [entity name], [entity schemaName]];
		*error = DatabaseError (kBXErrorNoTableForEntity, localizedError, mContext, entity);
	}
	return table;
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
	if (mLocking)
		[sender BXLockAcquired: NO object: anObject error: nil]; //FIXME: set the error.
	else if ([mLockedObjects containsObject: anObject])
		[sender BXLockAcquired: YES object: anObject error: nil];
	else
	{
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
		NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObject: connection forKey: kPGTSConnectionKey];
		NSString* whereClause = [[objectID predicate] PGTSWhereClauseWithContext: ctx];
		NSString* fromClause = [entity BXPGQualifiedName: connection];
		NSString* queryFormat = @"SELECT null FROM ONLY %@ WHERE %@ FOR UPDATE NOWAIT";
		NSString* queryString = [NSString stringWithFormat: queryFormat, fromClause, whereClause];
		NSArray* parameters = [ctx objectForKey: kPGTSParametersKey];

		NSDictionary* newUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									 sender, kBXPGLockerKey,
									 object, kBXPGObjectKey,
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
		NSString* whereClause = [userInfo objectForKey: kBXPGWhereClauseKey];
		NSArray* parameters = [userInfo objectForKey: kBXPGParametersKey];
		[sender BXLockAcquired: YES object: object error: nil];
		[mTransactionHandler markLocked: [object entity] whereClause: whereClause parameters: parameters willDelete: NO];
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
 * Unlock a locked object synchronously.
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
		BXPGTransactionHandler* handler = [[transactionHandlerClass alloc] init];
		[handler setInterface: self];
		
		mTransactionHandler = handler;
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


- (NSArray *) keyPathComponents: (NSString *) keyPath
{
	return [keyPath BXKeyPathComponentsWithQuote: @"\""];
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
 * Create an insert query.
 */
- (NSString *) insertQuery: (BXEntityDescription *) entity insertedAttrs: (NSArray *) insertedAttrs error: (NSError **) error
{
	Expect (entity);
	Expect (error);

	NSString* retval = nil;
	PGTSConnection* connection = [mTransactionHandler connection];
	NSString* entityName = [entity BXPGQualifiedName: connection];
	NSString* returned = ReturnedFields (connection, entity);

	//If the entity is a view and the user hasn't specified default values for the underlying tables'
	//primary key fields, we try to do them a favour and insert the default value expressions if
	//they are known.
	NSArray* attrs = insertedAttrs;
	NSString* valueString = nil;
	if ([entity isView])
	{		
		NSMutableArray* newAttrs = [[attrs mutableCopy] autorelease];
		NSMutableArray* defaultValues = [NSMutableArray array];
		NSArray* pkeyFields = [entity primaryKeyFields];
		
		TSEnumerate (currentField, e, [pkeyFields objectEnumerator])
		{
			if (! [insertedAttrs containsObject: currentField])
			{
				NSString* valueExpression = [self viewDefaultValue: currentField error: error];
				if (* error) 
					goto error;
				else if (valueExpression)
				{
					[newAttrs addObject: currentField];
					[defaultValues addObject: valueExpression];
				}
			}
		}
		
		NSString* aliases = nil;
		if ([insertedAttrs count])
			aliases = FieldAliases ([insertedAttrs count]);
		
		if ([defaultValues count])
		{
			NSString* defaults = [defaultValues componentsJoinedByString: @", "];
			insertedAttrs = newAttrs;
			if (aliases)
				valueString = [NSString stringWithFormat: @"%@, %@", aliases, defaults];
			else
				valueString = defaults;
		}
		else if (aliases)
		{
			valueString = aliases;
		}
	}
	
	if (0 == [insertedAttrs count])
	{
		NSString* format = @"INSERT INTO %@ DEFAULT VALUES RETURNING %@";
		retval = [NSString stringWithFormat: format, entityName, returned];
	}
	else
	{
		if (! valueString)
			valueString = FieldAliases ([insertedAttrs count]);
		
		NSString* format = @"INSERT INTO %@ (%@) VALUES (%@) RETURNING %@";
		NSString* nameString = [(id) [[insertedAttrs PGTSCollect] BXPGEscapedName: connection] componentsJoinedByString: @", "];
		retval = [NSString stringWithFormat: format, entityName, nameString, valueString, returned];
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
		TSEnumerate (currentEntity, e, [[entity inheritedEntities] objectEnumerator])
		{
			defaultValue = [self recursiveDefaultValue: name entity: currentEntity error: error];
			if (defaultValue || *error)
				break;
		}
	}
	else
	{
		PGTSTableDescription* table = [self tableForEntity: entity error: error];
		if (table)
		{
			NSDictionary* fields = [table fields];
			defaultValue = [[fields objectForKey: name] defaultValue];
		}
	}
	return defaultValue;
}

- (NSDictionary *) entitiesBySchemaAndName: (NSError **) error
{
	Expect (error);
	NSMutableDictionary* retval = nil;
	
	NSString* query = @"SELECT c.oid "
    " FROM pg_class c, pg_namespace n "
    " WHERE c.relnamespace = n.oid "
    " AND (c.relkind = 'r' OR c.relkind = 'v') "
    " AND n.nspname NOT IN ('baseten', 'pg_catalog', 'information_schema', 'pg_toast', 'pg_temp_1', 'pg_temp_2')";
	PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: query];
	if (! [res querySucceeded])
	{
		*error = [res error];
		goto error;
	}
	else
	{
		NSMutableArray* oids = [NSMutableArray arrayWithCapacity: [res count]];
		while ([res advanceRow])
			[oids addObject: [res valueForKey: @"oid"]];
		
		//Warm up the cache.
		NSSet* tables = [[mTransactionHandler databaseDescription] tablesWithOids: oids];
		retval = [NSMutableDictionary dictionary];
		TSEnumerate (currentTable, e, [tables objectEnumerator])
		{
			NSString* tableName = [currentTable name];
			NSString* schemaName = [currentTable schemaName];
			BXEntityDescription* entity = [mContext entityForTable: tableName
														  inSchema: schemaName
															 error: error];
			
			//FIXME: hackish; we should track all changes in PGTSTableDescriptions perhaps by using NSKVO.
			[entity setEnabled: [currentTable isEnabled]];
			
			NSMutableDictionary* schema = [retval objectForKey: schemaName];
			if (! schema)
			{
				schema = [NSMutableDictionary dictionary];
				[retval setObject: schema forKey: schemaName];
			}
			[schema setObject: entity forKey: tableName];
		}
	}
error:
	return retval;
}

- (BOOL) canProcessEntities
{
	return [[mTransactionHandler databaseDescription] hasBaseTenSchema];
}

- (void) removePrimaryKeyForEntity: (BXEntityDescription *) viewEntity error: (NSError **) outError
{
	ExpectV (viewEntity);
	ExpectV ([viewEntity isView]);
	ExpectV (outError);	
	
	NSString* query = [NSString stringWithFormat: @"DELETE FROM baseten.viewprimarykey WHERE nspname = $1 AND relname = $2"];
	PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: query parameters: [viewEntity schemaName], [viewEntity name]];
	if ([res querySucceeded])
	{
		TSEnumerate (currentAttribute, e, [viewEntity primaryKeyFields])
			[currentAttribute setPrimaryKey: NO];
	}
	else
	{
		*outError = [res error];
	}
}

- (void) process: (BOOL) shouldAdd primaryKeyFields: (NSArray *) attributeArray error: (NSError **) outError
{
	ExpectV (attributeArray);
	ExpectV (outError);
	
	TSEnumerate (currentAttribute, e, [attributeArray objectEnumerator])
	{
		BXEntityDescription* entity = [(BXAttributeDescription *) currentAttribute entity];
		if ([entity isView] && [currentAttribute isPrimaryKey] != shouldAdd)
		{
			NSString* queryFormat = nil;
			if (shouldAdd)
				queryFormat = @"INSERT INTO baseten.viewprimarykey (nspname, relname, attname) VALUES ($1, $2, $3)";
			else
				queryFormat = @"DELETE FROM baseten.viewprimarykey WHERE nspname = $1 AND relname = $2 AND attname = $3";
			
			PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: queryFormat parameters: 
								  [entity schemaName], [entity name], [currentAttribute name]];
			if ([res querySucceeded])
				[currentAttribute setPrimaryKey: shouldAdd];
			else
			{
				*outError = [res error];
				break;
			}
		}
	}
}

- (void) process: (BOOL) shouldEnable entities: (NSArray *) entityArray error: (NSError **) outError
{
	ExpectV (entityArray);
	ExpectV (outError);
	
	NSMutableArray* oids = [NSMutableArray arrayWithCapacity: [entityArray count]];
	TSEnumerate (currentEntity, e, [entityArray objectEnumerator])
	{
		if ([currentEntity isEnabled] != shouldEnable)
		{
			PGTSTableDescription* table = [self tableForEntity: currentEntity error: outError];
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
			@"SELECT baseten.prepareformodificationobserving ($1 [s]) "
			"  FROM generate_series (1, array_upper ($1::OID[], 1)) AS s";
		}
		else
		{
			query =
			@"SELECT baseten.cancelmodificationobserving ($1 [s]) "
			"  FROM generate_series (1, array_upper ($1::OID[], 1)) AS s";
		}
		
		PGTSResultSet* res = [[mTransactionHandler connection] executeQuery: query parameters: oids];
		if ([res querySucceeded])
		{
			TSEnumerate (currentEntity, e, [entityArray objectEnumerator])
				[currentEntity setEnabled: shouldEnable];
		}
		else
		{
			*outError = [res error];
		}
	}
	
bail:
	;
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
	if (! mFrameworkCompatVersion)
		mFrameworkCompatVersion = BXPGCopyCurrentCompatibilityVersionNumber ();
	return mFrameworkCompatVersion;
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
		NSError* error = [NSError errorWithDomain: @"" code: 1 userInfo: userInfo];
		*outError = error;
	}
	return retval;
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

- (BOOL) logsQueries
{
	return NO;
}

- (void) connection: (PGTSConnection *) connection sentQueryString: (const char *) queryString
{
}

- (void) connection: (PGTSConnection *) connection sentQuery: (PGTSQuery *) query
{
}
@end


@implementation BXPGInterface (Visitor)
- (void) addAttributeFor: (PGTSFieldDescription *) field into: (NSMutableDictionary *) attrs 
				  entity: (BXEntityDescription *) entity primaryKeyFields: (NSSet *) pkey
{
	NSString* name = [field name];
	BXAttributeDescription* desc = [attrs objectForKey: name];
	if (! desc)
		desc = [BXAttributeDescription attributeWithName: name entity: entity];
	
	BOOL isPrimaryKey = [pkey containsObject: field];
	BOOL isOptional = (! ([field isNotNull] || isPrimaryKey));
	[desc setOptional: isOptional];
	[desc setPrimaryKey: isPrimaryKey];
	
	PGTSConnection* connection = [mTransactionHandler connection];
	PGTSTypeDescription* typeDesc = [field type];
	NSString* typeName = [typeDesc name];
	[desc setDatabaseTypeName: typeName];
	
	NSDictionary* classDict = [connection deserializationDictionary];
	[desc setAttributeValueClass: [classDict objectForKey: typeName]];
	
	//Internal fields are excluded by default.
	if ([field index] <= 0)
		[desc setExcluded: YES];
	
	[attrs setObject: desc forKey: name];
}


- (void) qualifiedNameFor: (PGTSFieldDescription *) field into: (NSMutableArray *) array 
				   entity: (BXEntityDescription *) entity connection: (PGTSConnection *) connection
{
	NSString* name = [field name];
	BXAttributeDescription* attr = [[entity attributesByName] objectForKey: name];
	NSString* qname = [attr BXPGQualifiedName: connection];
	[array addObject: qname];
}
@end
