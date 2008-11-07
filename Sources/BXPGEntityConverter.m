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
#import "BXDatabaseAdditions.h"
#import "BXPGTransactionHandler.h"
#import "NSEntityDescription+BXPGAdditions.h"
#import "NSAttributeDescription+BXPGAdditions.h"
#import "NSRelationshipDescription+BXPGAdditions.h"
#import "NSEntityDescription+BXPGAdditions.h"
#import "NSAttributeDescription+BXPGAdditions.h"
#import "NSRelationshipDescription+BXPGAdditions.h"
#import "PGTSDatabaseDescription.h"
#import "PGTSCFScannedMemoryAllocator.h"


static Boolean
EqualRelationship (const void *value1, const void *value2)
{
	Boolean retval = FALSE;
	NSRelationshipDescription* r1 = (id) value1;
	NSRelationshipDescription* r2 = (id) value2;
	if ([[r1 name] isEqualToString: [r2 name]])
	{
		if ([[r1 entity] isEqual: [r2 entity]])
			retval = TRUE;
	}
	return retval;
}


@implementation BXPGEntityConverter
- (NSMutableArray *) add: (NSString *) aName fromUnsatisfied: (NSMutableDictionary *) unsatisfied
{
    NSMutableArray* retval = [NSMutableArray array];
    TSEnumerate (subEntity, e, [[unsatisfied objectForKey: aName] objectEnumerator])
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
	NSError* retval = [NSError errorWithDomain: @"" code: 0 userInfo: userInfo];
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
    TSEnumerate (entityDesc, e, [entityArray objectEnumerator])
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
    
    TSEnumerate (currentEntityArray, e, [unsatisfiedDependencies objectEnumerator])
    {
        TSEnumerate (entityDesc, e, [currentEntityArray objectEnumerator])
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
	
	if (! [database schemaExists: schemaName])
		[retval addObject: [NSString stringWithFormat: @"CREATE SCHEMA \"%@\";", schemaName]];
	
	TSEnumerate (currentEntity, e, [entityArray objectEnumerator])
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
		
		TSEnumerate (currentAttr, e, [[currentEntity attributesByName] objectEnumerator])
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
	
	CFSetCallBacks callbacks = PGTSScannedSetCallbacks ();
	callbacks.equal = &EqualRelationship;
	NSMutableSet* handledRelationships = (id) CFSetCreateMutable (PGTSScannedMemoryAllocator (), 0, &callbacks);
	
	TSEnumerate (currentEntity, e, [entityArray objectEnumerator])
	{
		TSEnumerate (currentRel, e, [[currentEntity relationshipsByName] objectEnumerator])
		{
			if (! [handledRelationships containsObject: currentRel])
			{
				NSArray* constraints = [currentRel BXPGRelationshipConstraintsWithColumns: YES constraints: YES 
																				   schema: schemaName 
																		 enabledRelations: enabledRelations
																				   errors: errors];
				[retval addObjectsFromArray: constraints];
				[handledRelationships addObject: currentRel];
				if ([currentRel inverseRelationship])
					[handledRelationships addObject: [currentRel inverseRelationship]];
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
