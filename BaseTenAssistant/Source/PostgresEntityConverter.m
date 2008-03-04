//
// PostgresEntityConverter.m
// BaseTen Setup
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <PGTS/PGTS.h>
#import <PGTS/PGTSFunctions.h>
#import <PGTSTiger/NSPredicate+PGTSAdditions.h>
#import <PGTSTiger/PGTSTigerConstants.h>
#import "PostgresEntityConverter.h"
#import "Entity.h"
#import "Constants.h"
#import "Controller.h"
#import "PostgresVerbatimString.h"
#import "Additions.h"


@interface NSObject (PGEAdditions)
- (id) PGEDefaultValueForFieldType: (NSAttributeType) fieldType;
@end

@implementation NSString (PGEAdditions)
- (id) PGEDefaultValueForFieldType: (NSAttributeType) fieldType
{
	NSMutableString* retval = [NSMutableString stringWithString: self];
	[retval replaceOccurrencesOfString: @"'" withString: @"\\'" options: 0 range: NSMakeRange (0, [retval length])];
	[retval insertString: @"'" atIndex: 0];
	[retval appendString: @"'"];
	return retval;
}
@end

@implementation NSNumber (PGEAdditions)
- (id) PGEDefaultValueForFieldType: (NSAttributeType) fieldType
{
	id retval = self;
	if (NSBooleanAttributeType == fieldType)
		retval = ([self boolValue] ? @"true" : @"false");
	return retval;
}
@end

@implementation NSDate (PGEAdditions)
- (id) PGEDefaultValueForFieldType: (NSAttributeType) fieldType
{
	return [NSString stringWithFormat: @"timestamp with time zone 'epoch' + interval '%f seconds'", [self timeIntervalSince1970]];
}
@end



@implementation PostgresEntityConverter

- (NSString *) nameForDeleteRule: (NSDeleteRule) rule
{
	NSString* rval = nil;
	switch (rule)
	{
		case NSNoActionDeleteRule:
			rval = @"NO ACTION";
			break;
			
		case NSNullifyDeleteRule:
			rval = @"SET NULL";
			break;
			
		case NSCascadeDeleteRule:
			rval = @"CASCADE";
			break;
			
		case NSDenyDeleteRule:
			rval = @"RESTRICT";
			break;
			
		default:
			break;
	}
	return rval;
}

- (NSString *) nameForAttributeType: (NSAttributeType) type
{
    NSString* rval = nil;
    switch (type)
    {        
        case NSInteger16AttributeType:
            rval =  @"smallint";
            break;
            
        case NSInteger32AttributeType:
            rval = @"integer";
            break;
            
        case NSInteger64AttributeType:
            rval = @"bigint";
            break;
            
        case NSDecimalAttributeType:
            rval = @"numeric";
            break;
            
        case NSDoubleAttributeType:
            rval = @"double precision";
            break;
            
        case NSFloatAttributeType:
            rval = @"real";
            break;
            
        case NSStringAttributeType:
            rval = @"text";
            break;
            
        case NSBooleanAttributeType:
            rval = @"boolean";
            break;
            
        case NSDateAttributeType:
            rval = @"timestamp with time zone";
            break;
            
        case NSBinaryDataAttributeType:
            rval = @"bytea";
            break;
            
        case NSUndefinedAttributeType:
        default:
            break;            
    }
    return rval;
}

/**
 * Sort the entities so that the superentities go first and subentities last
 */
- (NSArray *) sortedEntities: (NSArray *) entityArray
{
    NSMutableArray* rval = [NSMutableArray arrayWithCapacity: [entityArray count]];
    NSMutableDictionary* unsatisfiedDependencies = [NSMutableDictionary dictionary];
    NSMutableSet* addedEntities = [NSMutableSet setWithCapacity: [entityArray count]];
    TSEnumerate (currentEntity, e, [entityArray objectEnumerator])
    {
        NSEntityDescription* entityDesc = [currentEntity entityDescription];
        NSEntityDescription* superentityDesc = [entityDesc superentity];
        if (nil == superentityDesc || [addedEntities containsObject: superentityDesc])
        {
            [rval addObject: currentEntity];
            [addedEntities addObject: entityDesc];
            
            //Check recursively if adding this entity made some other entities available
            NSMutableArray* subentities = [self add: [entityDesc name] fromUnsatisfied: unsatisfiedDependencies];
            [rval addObjectsFromArray: subentities];
            [addedEntities addObjectsFromArray: [subentities valueForKey: @"entityDescription"]];
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
            [unsatisfied addObject: currentEntity];
        }
    }
    
    TSEnumerate (currentEntityArray, e, [[unsatisfiedDependencies allValues] objectEnumerator])
    {
        TSEnumerate (currentEntity, e, [currentEntityArray objectEnumerator])
        {
            NSEntityDescription* entityDesc = [currentEntity entityDescription];
            [self log: [NSString stringWithFormat: @"-- Skipping entity %@; superentity %@ was not added.",
                [entityDesc name], [[entityDesc superentity] name]]];
        }
    }
    return rval;
}

- (NSMutableArray *) add: (NSString *) aName fromUnsatisfied: (NSMutableDictionary *) unsatisfied
{
    NSMutableArray* rval = [NSMutableArray array];
    TSEnumerate (subEntity, e, [[unsatisfied objectForKey: aName] objectEnumerator])
    {
        [rval addObject: subEntity];
        [rval addObjectsFromArray: [self add: [[subEntity entityDescription] name] fromUnsatisfied: unsatisfied]];
    }
    
    //The dependency was satisfied
    [unsatisfied removeObjectForKey: aName];
    
    return rval;
}

- (NSArray *) createStatementsForEntities: (NSArray *) entityArray
{
    NSMutableSet* handledEntities = [NSMutableSet setWithCapacity: [entityArray count]];
    NSMutableArray* rval = [NSMutableArray arrayWithCapacity: [entityArray count]];
    entityArray = [self sortedEntities: entityArray];
    TSEnumerate (currentEntity, e, [entityArray objectEnumerator])
    {
        [rval addObject: [self createStatementForEntity: currentEntity]];
        [handledEntities addObject: [currentEntity entityDescription]];
    }
    
    if (YES == addsForeignKeys)
    {
        CFSetCallBacks callbacks = {
            0,
            &MKCSetRetain,
            &MKCRelease,
            &MKCCopyDescription,
            &MKCEqualRelationshipDescription,
            &MKCHash};
        NSMutableSet* handledRelationships = 
            [(id) CFSetCreateMutable (NULL, 0, &callbacks) autorelease];
        NSMutableString* statementFormat = 
			@"ALTER TABLE \"%@\".\"%@\" ADD COLUMN \"%@\" integer %@ CONSTRAINT \"%@\" REFERENCES \"%@\".\"%@\" (id) ON DELETE %@ ON UPDATE CASCADE;";

        TSEnumerate (currentEntity, e, [entityArray objectEnumerator])
        {
            NSEntityDescription* currentEntityDesc = [currentEntity entityDescription];
            TSEnumerate (currentRelationship, e, [[currentEntityDesc relationshipsByName] objectEnumerator])
            {
                if (NO == [handledRelationships containsObject: currentRelationship])
                {
                    NSRelationshipDescription* inverseRelationship = [currentRelationship inverseRelationship];

                    if (nil == inverseRelationship && [currentRelationship isToMany])
                    {
                        [self log: [NSString stringWithFormat: 
                            @"-- Skipping relationship %@; inverse relationships are required for to-many relationships.", [currentRelationship name]]];
                    }
                    else if (NO == ([handledEntities containsObject: [currentRelationship entity]] && 
                                    [handledEntities containsObject: [currentRelationship destinationEntity]]))
                    {
                        [self log: [NSString stringWithFormat: @"-- Skipping relationship %@; entity %@ or %@ was not found.", 
                            [currentRelationship name], [[currentRelationship entity] name], [[currentRelationship destinationEntity] name]]];
                    }
                    else if ([currentRelationship isToMany] && [inverseRelationship isToMany])
                    {
                        //Many-to-many
                        if (! ([currentRelationship isOptional] && [inverseRelationship isOptional]))
                        {
                            [self log: [NSString stringWithFormat: 
                                @"-- Made relationship %@ optional; required many-to-many relationships are not supported.", 
                                [currentRelationship name]]];
                        }
                        
                        NSEntityDescription* destinationEntityDesc = [currentRelationship destinationEntity];                            
                        NSString* helperTableName = [NSString stringWithFormat: @"%@_%@_rel", 
                            [currentRelationship name], [inverseRelationship name]];
                        NSString* schemaName = [currentEntity schemaName];
                                                
                        NSString* entity1Name = [currentEntityDesc name];
                        NSString* entity2Name = [destinationEntityDesc name];
                        NSString* id1Name     = [entity1Name stringByAppendingString: @"_id"];
                        NSString* id2Name     = [entity2Name stringByAppendingString: @"_id"];
                        NSString* fkey1Name   = [currentRelationship name];
                        NSString* fkey2Name   = [inverseRelationship name];
                        
                        //Saved for implementing required MTM relationships.
#if 0
                        NSString* createFkeyFormat = @"ALTER TABLE \"%@\".\"%@\" ADD CONSTRAINT \"%@\" "
                            " FOREIGN KEY (\"%@\") REFERENCES \"%@\".\"%@\" (id) "
                            " ON UPDATE CASCADE ON DELETE %@ " //For required relationships.
                            " DEFERRABLE INITIALLY DEFERRED;";
#endif
                        NSString* createFkeyFormat = @"ALTER TABLE \"%@\".\"%@\" ADD CONSTRAINT \"%@\" "
                            " FOREIGN KEY (\"%@\") REFERENCES \"%@\".\"%@\" (id) "
                            " ON UPDATE CASCADE ON DELETE CASCADE;";
                        
						id relationships [2] = {currentRelationship, inverseRelationship};
						for (int i = 0; i < 2; i++)
						{
							if (NSCascadeDeleteRule != [relationships [i] deleteRule])
								[self log: [NSString stringWithFormat: 
									@"-- Made relationship %@ cascade on delete; other delete rules are not supported for many-to-many relationships.", 
									[relationships [i] name]]];
						}
						
                        [rval addObject: [NSString stringWithFormat: @"SELECT baseten.cancelmodificationobserving (c.oid) FROM pg_class c, pg_namespace n "
                            " WHERE c.relnamespace = n.oid AND n.nspname = '%@' AND c.relname = '%@';",
                            [schemaName PGTSEscapedString: connection], [helperTableName PGTSEscapedString: connection]]];
                        [rval addObject: [NSString stringWithFormat: @"DROP TABLE IF EXISTS \"%@\".\"%@\" CASCADE;", schemaName, helperTableName]];
                        [rval addObject: [NSString stringWithFormat: @"CREATE TABLE \"%@\".\"%@\" (\"%@\" integer, \"%@\" integer, PRIMARY KEY (\"%@\", \"%@\"));",
                            schemaName, helperTableName, id1Name, id2Name, id1Name, id2Name]];
                        [rval addObject: [NSString stringWithFormat: createFkeyFormat, schemaName, helperTableName, fkey1Name, id1Name, schemaName, entity1Name]];
                        [rval addObject: [NSString stringWithFormat: createFkeyFormat, schemaName, helperTableName, fkey2Name, id2Name, schemaName, entity2Name]];
                        [rval addObject: [NSString stringWithFormat: @"SELECT baseten.prepareformodificationobserving (c.oid) FROM pg_class c, pg_namespace n "
                            " WHERE c.relnamespace = n.oid AND n.nspname = '%@' AND c.relname = '%@';", 
                            [schemaName PGTSEscapedString: connection], [helperTableName PGTSEscapedString: connection]]];
                    }
					else
					{
						BOOL isOneToOne = NO;
                        if ([currentRelationship isToMany] || nil == inverseRelationship || [inverseRelationship isToMany])
						{
							//One-to-many
							//Reorder so that we are in the foreign key's table.
							if (YES == [currentRelationship isToMany])
							{
								id tmp = currentRelationship;
								currentRelationship = inverseRelationship;
								inverseRelationship = tmp;
								currentEntityDesc = [currentRelationship entity];
							}
							
							if (! (nil == inverseRelationship || NSNullifyDeleteRule == [inverseRelationship deleteRule]))
							{
								[self log: [NSString stringWithFormat: 
									@"-- Made delete rule for relationship %@ nullify; other delete rules are not supported on to-one side of a one-to-many relationship.",
									[inverseRelationship name]]];
							}
						}
						else
						{
							//One-to-one
							isOneToOne = YES;
							
							if (nil != inverseRelationship && 
								(NSNullifyDeleteRule != [inverseRelationship deleteRule] ||
								 NO == [inverseRelationship isOptional]))
							{
								id tmp = currentRelationship;
								currentRelationship = inverseRelationship;
								inverseRelationship = tmp;
								currentEntityDesc = [currentRelationship entity];
							}
							
							if (nil != inverseRelationship)
							{
								if (NSNullifyDeleteRule != [inverseRelationship deleteRule])
								{
									[self log: [NSString stringWithFormat: 
										@"-- Made delete rule for relationship %@ nullify; one-to-one relationships need an optional inverse relationship which has to nullify on delete.",
										[inverseRelationship name]]];
								}
								
								if (NO == [inverseRelationship isOptional])
								{
									[self log: [NSString stringWithFormat:
										@"-- Made relationship %@ optional; one-to-one relationships need an optional inverse relationship which has to nullify on delete.",
										[inverseRelationship name]]];
								}
							}
                        }
                        
                        //We assume that the schema name is the same for all entities
                        NSString* schemaName = [currentEntity schemaName];
                        NSString* destinationEntityName = [[currentRelationship destinationEntity] name];
                        NSString* currentRelationshipName = [currentRelationship name];
                        NSString* columnName = [currentRelationshipName stringByAppendingString: @"_id"];
                        
                        [rval addObject: [NSString stringWithFormat: statementFormat, 
                            schemaName, [currentEntityDesc name],
                            columnName,
                            ([currentRelationship isOptional] ? @"" : @"NOT NULL"),
                            currentRelationshipName, schemaName, destinationEntityName,
                            [self nameForDeleteRule: [currentRelationship deleteRule]]]];
                        
                        if (isOneToOne)
                        {
                            [rval addObject: [NSString stringWithFormat:
                                @"ALTER TABLE \"%@\".\"%@\" ADD UNIQUE (\"%@\");", 
                                schemaName, [currentEntityDesc name], columnName]];
                        }
					}
                    
                    [handledRelationships addObject: currentRelationship];
                    if (nil != inverseRelationship)
                        [handledRelationships addObject: inverseRelationship];
                }
            }
        }
    }
    
    return rval;
}

- (NSString *) createStatementForEntity: (Entity *) entity
{
    NSEntityDescription* entityDesc = [entity entityDescription];
    NSDictionary* attributes = [entityDesc attributesByName];
    NSMutableString* statement = [NSMutableString stringWithFormat: @"CREATE TABLE \"%@\".\"%@\" (", 
        [entity schemaName], [entityDesc name]];
    NSMutableArray* attributeDefs = [NSMutableArray arrayWithCapacity: [attributes count]];
    
    if (YES == addsIDColumns)
        [attributeDefs addObject: @"id SERIAL PRIMARY KEY"];
    
    TSEnumerate (currentAttribute, e, [attributes objectEnumerator])
    {
        //Transient values are not stored
        if (NO == [currentAttribute isTransient])
        {
            NSAttributeType attributeType = [currentAttribute attributeType];            
            NSString* fieldType = nil;
            NSMutableString* attributeDef = [NSMutableString stringWithFormat: @"\"%@\" ", [currentAttribute name]];
            
			NSArray* givenValidationPredicates = [currentAttribute validationPredicates];
            NSMutableArray* validationPredicates = nil;
            unsigned int count = [givenValidationPredicates count];
			if (0 < count)
			{
                //Iterate the validation predicates and see if there are any lenght constraints.
                //Based on the information, decide, if we should create a varchar field.
                validationPredicates = [NSMutableArray arrayWithCapacity: count];
                NSExpression* lengthExp = [NSExpression expressionForKeyPath: @"length"];
                
                //Also check parent's validation predicates so that we don't create the same predicates two times.
                NSEntityDescription* parent = entityDesc;
                NSMutableSet* parentPredicates = [NSMutableSet set];
                while (nil != (parent = [parent superentity]))
                {
                    NSAttributeDescription* parentAttribute = [[parent attributesByName] objectForKey: [currentAttribute name]];
                    if (nil == parentAttribute)
                        break;
                    
                    [parentPredicates addObjectsFromArray: [parentAttribute validationPredicates]];
                }
                
                TSEnumerate (currentPredicate, e, [givenValidationPredicates objectEnumerator])
                {
                    //Skip if parent has this one.
                    if ([parentPredicates containsObject: currentPredicate])
                        continue;

                    BOOL shouldAdd = YES;
                    if ([currentPredicate isKindOfClass: [NSComparisonPredicate class]])
                    {
                        NSPredicateOperatorType operator = [currentPredicate predicateOperatorType];
                        
                        NSNumber* minLength = nil;
                        NSNumber* maxLength = nil;
                        
                        {
                            NSExpression* lhs = [currentPredicate leftExpression];
                            NSExpression* rhs = [currentPredicate rightExpression];
                            
                            if ([lhs isEqual: lengthExp] && NSConstantValueExpressionType == [rhs expressionType])
                            {
                                id value = [rhs constantValue];
                                switch (operator)
                                {
                                    case NSGreaterThanPredicateOperatorType:
                                    case NSGreaterThanOrEqualToPredicateOperatorType:
                                        minLength = value;
                                        break;
                                        
                                    case NSLessThanPredicateOperatorType:
                                    case NSLessThanOrEqualToPredicateOperatorType:
                                        maxLength = value;
                                        break;
                                        
                                    default:
                                        break;
                                }
                            }
                            else if ([rhs isEqual: lengthExp] && NSConstantValueExpressionType == [lhs expressionType])
                            {
                                id value = [lhs constantValue];
                                switch (operator)
                                {
                                    case NSGreaterThanPredicateOperatorType:
                                        operator = NSLessThanOrEqualToPredicateOperatorType;
                                    case NSGreaterThanOrEqualToPredicateOperatorType:
                                        operator = NSLessThanPredicateOperatorType;
                                        maxLength = value;
                                        break;
                                        
                                    case NSLessThanPredicateOperatorType:
                                        operator = NSGreaterThanOrEqualToPredicateOperatorType;
                                    case NSLessThanOrEqualToPredicateOperatorType:
                                        operator = NSGreaterThanPredicateOperatorType;
                                        minLength = value;
                                        break;
                                        
                                    default:
                                        break;
                                }
                            }
                        }
                        
                        if (nil != maxLength)
                        {
                            shouldAdd = NO;
                            fieldType = [NSString stringWithFormat: @"VARCHAR (%@)", maxLength];
                        }
                        else if (nil != minLength)
                        {
                            shouldAdd = NO;
                            NSExpression* lhs = [NSExpression expressionForConstantValue: [PostgresVerbatimString stringWithString:
                                [NSString stringWithFormat: @"char_length (%@)", [[currentAttribute name] PGTSEscapedName: connection]]]];
                            NSExpression* rhs = [NSExpression expressionForConstantValue: minLength];
                            NSPredicate* predicate = [NSComparisonPredicate predicateWithLeftExpression: lhs
                                                                                        rightExpression: rhs 
                                                                                               modifier: NSDirectPredicateModifier
                                                                                                   type: operator
                                                                                                options: 0];
                            [validationPredicates addObject: predicate];
                        }                        
                    }
                        
                    if (YES == shouldAdd)
                    {
                        [validationPredicates addObject: currentPredicate];
                    }
                }                
            }
            
            if (nil == fieldType)
                fieldType = [self nameForAttributeType: attributeType];
            [attributeDef appendString: fieldType];
            
            if (0 < [validationPredicates count])
            {
                NSPredicate* predicate = [NSCompoundPredicate andPredicateWithSubpredicates: validationPredicates];
                NSExpression* fieldname = [NSExpression expressionForKeyPath: [currentAttribute name]];
                [attributeDef appendFormat: @" CHECK (%@)", [predicate PGTSExpressionWithObject: fieldname context: 
                    [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        connection, kPGTSConnectionKey,
                        [NSNumber numberWithBool: YES], kPGTSExpressionParametersVerbatimKey,
                        nil]]];                                
            }            
            
            //Is the attribute required?
            if (![currentAttribute isOptional])
                [attributeDef appendString: @" NOT NULL"];
            
            id currentDefault = [currentAttribute defaultValue];
            if (nil != currentDefault)
				[attributeDef appendFormat: @" DEFAULT %@", [currentDefault PGEDefaultValueForFieldType: attributeType]];

            [attributeDefs addObject: attributeDef];
        }
    }

    [statement appendString: [attributeDefs componentsJoinedByString: @", "]];
    [statement appendString: @")"];
    
    //Parent
    NSEntityDescription* superentity = [entityDesc superentity];
    if (nil != superentity)
        [statement appendFormat: @" INHERITS (\"%@\".\"%@\")", [entity schemaName], [superentity name]];
	
	[statement appendString: @";"];
    
    return statement;
}

- (NSArray *) dropStatementsForEntities: (NSArray *) entityArray
{
    NSMutableArray* rval = [NSMutableArray arrayWithCapacity: [entityArray count]];
    TSEnumerate (currentEntity, e, [entityArray objectEnumerator])
    {
        if ([currentEntity alreadyExists])
        {
            PGTSResultSet* res = [connection executeQuery: @"SELECT baseten.IsObservingCompatible ($1) AS compatible;" parameters: [currentEntity identifier]];
            [res advanceRow];
            if (YES == [[res valueForKey: @"compatible"] boolValue])
                [rval addObject: [NSString stringWithFormat: @"SELECT baseten.CancelModificationObserving (%@);", [currentEntity identifier]]];
            [rval addObject: [NSString stringWithFormat: @"DROP TABLE \"%@\".\"%@\" CASCADE;", [currentEntity schemaName], [[currentEntity entityDescription] name]]];
        }
    }
    return rval;
}

- (NSError *) importEntities: (NSArray *) entityArray
{
    NSMutableSet* createdSchemas = [NSMutableSet set];
    NSError* rval = nil;
    
    if (YES == dryRun)
        [self log: @"-- Beginning dry run."];
    @try
    {
        [connection setOverlooksFailedQueries: YES];
        
        {
            NSString* query = @"BEGIN TRANSACTION;";
            [self log: query];
            if (NO == dryRun)
                [connection executeQuery: query];
        }
            
        TSEnumerate (currentStatement, e, [[self dropStatementsForEntities: entityArray] objectEnumerator])
        {
            NSString* spQuery = @"SAVEPOINT ImportSavepoint;";
            [self log: spQuery];
            [self log: currentStatement];
            
            if (NO == dryRun)
            {
                [connection executeQuery: spQuery];
                PGTSResultSet* res = [connection executeQuery: currentStatement];
                if (NO == [res querySucceeded])
                    [connection executeQuery: @"ROLLBACK TO SAVEPOINT ImportSavepoint;"];
            }
        }

        [connection setOverlooksFailedQueries: NO];
        TSEnumerate (currentEntity, e, [entityArray objectEnumerator])
        {
            NSString* schemaName = [currentEntity schemaName];
            if (NO == [createdSchemas containsObject: schemaName])
            {
                [createdSchemas addObject: schemaName];
                if (NO == [[connection databaseInfo] schemaExists: schemaName])
                {
                    NSString* query = [NSString stringWithFormat: @"CREATE SCHEMA %@;", schemaName];
                    [self log: query];
                    if (NO == dryRun)
                        [connection executeQuery: query];
                }
            }
        }
        
        TSEnumerate (currentStatement, e, [[self createStatementsForEntities: entityArray] objectEnumerator])
        {
            [self log: currentStatement];
            if (NO == dryRun)
                [connection executeQuery: currentStatement];
        }
        
        TSEnumerate (currentEntity, e, [entityArray objectEnumerator])
        {
            NSString* query = 
            @"SELECT baseten.PrepareForModificationObserving (c.oid) FROM pg_class c, pg_namespace n "
            " WHERE c.relname = $1 AND n.nspname = $2 AND c.relnamespace = n.oid;";
            
            NSString* tableName = [[currentEntity entityDescription] name];
            NSString* schemaName = [currentEntity schemaName];
            [self log: [NSString stringWithFormat: @"%@ -- (%@, %@)", query, tableName, schemaName]];
            if (NO == dryRun)
                [connection executeQuery: query parameters: tableName, schemaName];
        }
        
        {
            NSString* query = @"COMMIT TRANSACTION;";
            [self log: query];
            if (NO == dryRun)
                [connection executeQuery: query];
        }
        
        if (YES == dryRun)
            [self log: @"-- Ending dry run."];
    }
    @catch (PGTSQueryException* exception)
    {
        [connection rollbackTransaction];
        NSString* errorMessage = [[[exception userInfo] objectForKey: kPGTSResultSetKey] errorMessage];
        [self log: errorMessage];
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			errorMessage,		kBXErrorMessageKey,
			errorMessage,		NSLocalizedFailureReasonErrorKey,
			errorMessage,		NSLocalizedRecoverySuggestionErrorKey,
			@"Import error",	NSLocalizedDescriptionKey,
			nil];
        rval = [NSError errorWithDomain: kBXSetupApplicationDomain code: kBXSetupErrorUndefined userInfo: userInfo];
    }
    [self log: @"\n"];
    [connection setOverlooksFailedQueries: YES];
    return rval;
}

@end


@implementation EntityConverter

- (NSString *) nameForAttributeType: (NSAttributeType) type
{
    return nil;
}

- (NSError *) importEntities: (NSArray *) entityArray
{
    return nil;
}

- (id) connection
{
    return connection; 
}

- (void) setConnection: (id) aConnection
{
    if (connection != aConnection) {
        [connection release];
        connection = [aConnection retain];
    }
}

- (BOOL) addsForeignKeys
{
    return addsForeignKeys;
}

- (void) setAddsForeignKeys: (BOOL) flag
{
    addsForeignKeys = flag;
}

- (BOOL) addsIDColumns
{
    return addsIDColumns;
}

- (void) setAddsIDColumns: (BOOL) flag
{
    addsIDColumns = flag;
}

- (void) setDryRun: (BOOL) flag 
{
    dryRun = flag;
}

- (void) log: (NSString *) query
{
    [controller logAppend: [query stringByAppendingString: @"\n"]];
}

- (void) setController: (id) aController
{
    controller = aController;
}

@end