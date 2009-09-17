//
// BXPGEntityConverter.m
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

#import "BXPGEntityConverter.h"
#import "BXDatabaseContext.h"
#import "BXDatabaseContextPrivate.h"
#import "BXLogger.h"
#import "BXPGInterface.h"
#import "BXPGTransactionHandler.h"
#import "NSEntityDescription+BXPGAdditions.h"
#import "NSAttributeDescription+BXPGAdditions.h"
#import "NSRelationshipDescription+BXPGAdditions.h"
#import "NSEntityDescription+BXPGAdditions.h"
#import "NSAttributeDescription+BXPGAdditions.h"
#import "NSRelationshipDescription+BXPGAdditions.h"
#import "PGTSDatabaseDescription.h"
#import "PGTSCollections.h"
#import "BXEnumerate.h"
#import "BXError.h"


@implementation BXPGEntityConverter
- (NSMutableArray *) add: (NSString *) aName fromUnsatisfied: (NSMutableDictionary *) unsatisfied
{
    NSMutableArray* retval = [NSMutableArray array];
    BXEnumerate (subEntity, e, [[unsatisfied objectForKey: aName] objectEnumerator])
    {
        [retval addObject: subEntity];
        [retval addObjectsFromArray: [self add: [subEntity name] fromUnsatisfied: unsatisfied]];
    }
    
    //The dependency was satisfied
    [unsatisfied removeObjectForKey: aName];
    
    return retval;
}


static NSError*
ImportError (NSString* message, NSString* reason)
{
	Expect (message);
	Expect (reason);
	
	//FIXME: set the domain and the code.
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  message, NSLocalizedFailureReasonErrorKey,
							  reason, NSLocalizedRecoverySuggestionErrorKey,
							  nil];
	NSError* retval = [BXError errorWithDomain: @"" code: 0 userInfo: userInfo];
	return retval;
}


/**
 * Sort the entities so that the superentities go first and subentities last
 */
- (NSArray *) sortedEntities: (NSArray *) entityArray errors: (NSMutableArray *) errors
{
	Expect (entityArray);
	Expect (errors);
	
    NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [entityArray count]];
    NSMutableDictionary* unsatisfiedDependencies = [NSMutableDictionary dictionary];
    NSMutableSet* addedEntities = [NSMutableSet setWithCapacity: [entityArray count]];
    BXEnumerate (entityDesc, e, [entityArray objectEnumerator])
    {
        NSEntityDescription* superentityDesc = [entityDesc superentity];
        if (! superentityDesc || [addedEntities containsObject: superentityDesc])
        {
            [retval addObject: entityDesc];
            [addedEntities addObject: entityDesc];
            
            //Check recursively if adding this entity made some other entities available
            NSMutableArray* subentities = [self add: [entityDesc name] fromUnsatisfied: unsatisfiedDependencies];
            [retval addObjectsFromArray: subentities];
            [addedEntities addObjectsFromArray: subentities];
        }
        else
        {
            NSString* name = [superentityDesc name];
            NSMutableArray* unsatisfied = [unsatisfiedDependencies objectForKey: name];
            if (nil == unsatisfied)
            {
                unsatisfied = [NSMutableArray array];
                [unsatisfiedDependencies setObject: unsatisfied forKey: name];
            }
            [unsatisfied addObject: entityDesc];
        }
    }
    
    BXEnumerate (currentEntityArray, e, [unsatisfiedDependencies objectEnumerator])
    {
        BXEnumerate (entityDesc, e, [currentEntityArray objectEnumerator])
        {
			NSString* message = [NSString stringWithFormat: @"Entity %@ was skipped.", [entityDesc name]];
			NSString* reason = [NSString stringWithFormat: @"Superentity %@ had not been added.", [[entityDesc superentity] name]];
			[errors addObject: ImportError (message, reason)];
        }
    }
    return retval;
}


- (NSArray *) statementsForEntities: (NSArray *) entityArray 
						 schemaName: (NSString *) schemaName
						 	context: (BXDatabaseContext *) context
				   enabledRelations: (NSArray **) outArray
							 errors: (NSArray **) outErrors
{
	Expect (entityArray);
	Expect (context);
	
	if (! [schemaName length])
		schemaName = @"public";
	
	NSMutableArray* errors = [NSMutableArray array];
	NSMutableArray* retval = [NSMutableArray array];
	NSMutableArray* enabledRelations = [NSMutableArray array];
	PGTSConnection* connection = [[(BXPGInterface *) [context databaseInterface] transactionHandler] connection];
	PGTSDatabaseDescription* database = [connection databaseDescription];
	entityArray = [self sortedEntities: entityArray errors: errors];
	
	if (! [database schemaNamed: schemaName])
		[retval addObject: [NSString stringWithFormat: @"CREATE SCHEMA \"%@\";", schemaName]];
	
	BXEnumerate (currentEntity, e, [entityArray objectEnumerator])
	{
        NSError* error = nil;
		BXEntityDescription* match = [context matchingEntity: currentEntity inSchema: schemaName error: &error];
		if (match)
		{
			if ([match isView])
				[retval addObject: [NSString stringWithFormat: @"DROP VIEW \"%@\".\"%@\";", schemaName, [match name]]];
			else
				[retval addObject: [NSString stringWithFormat: @"DROP TABLE \"%@\".\"%@\";", schemaName, [match name]]];
		}

        if (error)
            [errors addObject: error];
		
		[retval addObject: [currentEntity BXPGCreateStatementWithIDColumn: YES inSchema: schemaName errors: errors]];
		[retval addObject: [currentEntity BXPGPrimaryKeyConstraintInSchema: schemaName]];
		[enabledRelations addObject: [currentEntity name]];
		
		BXEnumerate (currentAttr, e, [[currentEntity attributesByName] objectEnumerator])
		{
            NSError* error = nil;
			if ([currentAttr BXCanAddAttribute: &error])
			{
				[retval addObjectsFromArray: [currentAttr BXPGAttributeConstraintsInSchema: schemaName]];
				[retval addObjectsFromArray: [currentAttr BXPGConstraintsForValidationPredicatesInSchema: schemaName connection: connection]];
			}

            if (error)
                [errors addObject: error];
		}
	}
	
	NSMutableSet* handledRelationships = PGTSSetCreateMutableStrongRetainingForNSRD ();
	BXEnumerate (currentEntity, e, [entityArray objectEnumerator])
	{
		BXEnumerate (currentProperty, e, [[currentEntity properties] objectEnumerator])
		{
			BOOL isRelationship = [currentProperty isKindOfClass: [NSRelationshipDescription class]];
			BOOL isHandled = [handledRelationships containsObject: currentProperty];
			if (isRelationship && !isHandled)
			{
				NSArray* constraints = [currentProperty BXPGRelationshipConstraintsWithColumns: YES constraints: YES 
																						schema: schemaName 
																			  enabledRelations: enabledRelations
																						errors: errors];
				[retval addObjectsFromArray: constraints];
				[handledRelationships addObject: currentProperty];
				if ([currentProperty inverseRelationship])
					[handledRelationships addObject: [currentProperty inverseRelationship]];
			}
		}
	}
	
	if (outErrors)
		*outErrors = errors;
	
	if (outArray)
		*outArray = enabledRelations;

    if (handledRelationships)
        CFRelease (handledRelationships);
	
	return retval;
}

@end
