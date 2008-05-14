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
#import <Log4Cocoa/Log4Cocoa.h>
#import "BXPGInterface.h"


#define Expect( X )	log4AssertValueReturn( X, nil, @"Expected " #X " to have been set.");
#define ExpectR( X, RETVAL )	log4AssertValueReturn( X, RETVAL, @"Expected " #X " to have been set.");



@implementation BXEntityDescription (BXPGInterfaceAdditions)
- (NSString *) PGTSQualifiedName: (PGTSConnection *) connection
{
    return [NSString stringWithFormat: @"%@.%@", 
			[[self schemaName] PGTSEscapedName: connection], [[self name] PGTSEscapedName: connection]];
}
@end


@implementation BXAttributeDescription (BXPGInterfaceAdditions)
- (NSString *) PGTSQualifiedName: (PGTSConnection *) connection
{    
	return [NSString stringWithFormat: @"%@.%@", 
			[[self entity] PGTSQualifiedName: connection], [[self name] PGTSEscapedName: connection]];
}
@end


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


static int
ShouldReturn (BXAttributeDescription* attr)
{
	return (![attr isExcluded] || [attr isPrimaryKey]);
}


static NSString*
ReturnedFields (PGTSConnection* connection, BXEntityDescription* entity)
{
	NSArray* attrs = [[entity attributesByName] allValues];
	NSArray* returned = [[attrs PGTSSelectFunction: &ShouldReturn] PGTSCollect];
	NSArray* qualifiedNames = [returned PGTSQualifiedName: connection];
	return [qualifiedNames componentsJoinedByString: @", "];	
}


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


static NSString*
WhereClause (PGTSConnection* connection, NSPredicate* predicate, NSMutableDictionary* ctx)
{
	//Make sure that the where clause contains at least something, so the query is easier to format.
	NSString* whereClause = [predicate PGTSWhereClauseWithContext: ctx];
	if (nil == whereClause)
		whereClause = @"(true)";
	return whereClause;
}	


static NSString*
SelectQueryFormat (PGTSConnection* connection, BOOL forUpdate)
{
	NSString* queryFormat = @"SELECT %@ FROM %@ WHERE %@";
	if (forUpdate)
		queryFormat = @"SELECT %@ FROM %@ WHERE %@ FOR UPDATE";
	return queryFormat;
}


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
	{
		*error = [res error];
		goto error;
	}	
	retval = Result (mContext, entity, res);
	
error:
	return retval;
}


//XXX valueDict needs attributes as keys.
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

- (void) fetchForeignKeys
{
	if (nil == mForeignKeys)
	{
		mForeignKeys = [[NSMutableDictionary alloc] init];
		NSString* query = @"SELECT * from baseten.foreignkey";
		PGTSResultSet* res = [mConnection executeQuery: query];
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
		NSString* localizedError = [NSString stringWithFormat: 
									BXLocalizedString (@"tableNotFound", @"Table %@ was not found in schema %@.", @"Error message for fetch"),
									[entity name], [entity schemaName]];
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: 
								  BXSafeObj (localizedError), NSLocalizedFailureReasonErrorKey,
								  BXSafeObj (localizedError), NSLocalizedRecoverySuggestionErrorKey,
								  BXSafeObj (mContext),       kBXDatabaseContextKey,
								  BXSafeObj (entity),         kBXEntityDescriptionKey,
								  BXLocalizedString (@"databaseError", @"Database Error", @"Title for a sheet"), NSLocalizedDescriptionKey,
								  nil];
		*error = [NSError errorWithDomain: kBXErrorDomain code: kBXErrorNoTableForEntity userInfo: userInfo];		
	}
	return retval;
}

@end


@interface PGTSFieldDescriptionProxy (BXPGInterfaceAdditions)
- (void) addAttributeFor: (BXEntityDescription *) entity attributes: (NSMutableDictionary *) attrs;
@end


@implementation PGTSFieldDescriptionProxy (BXPGAttributeDescription)
- (void) addAttributeFor: (BXEntityDescription *) entity attributes: (NSMutableDictionary *) attrs primaryKeyFields: (NSSet *) pkey
{
	BXAttributeDescription* desc = [attrs objectForKey: [self name]];
	if (! desc)
		desc = [BXAttributeDescription attributeWithName: [self name] entity: entity];
	
	BOOL isPrimaryKey = [pkey containsObject: self];
	BOOL isOptional = (! ([self isNotNull] || isPrimaryKey));
	[desc setOptional: isOptional];
	[desc setPrimaryKey: isPrimaryKey];
	[attrs setObject: desc forKey: [self name]];
}
@end
