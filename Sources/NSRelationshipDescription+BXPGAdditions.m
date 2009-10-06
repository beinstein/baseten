//
// NSRelationshipDescription+BXPGAdditions.m
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

#import "NSRelationshipDescription+BXPGAdditions.h"
#import "BXLogger.h"
#import "BXError.h"
#import "BXArraySize.h"


static NSString*
BXPGDeleteRuleName (NSDeleteRule rule)
{
	NSString* retval = nil;
	switch (rule)
	{
		case NSNoActionDeleteRule:
			retval = @"NO ACTION";
			break;
			
		case NSNullifyDeleteRule:
			retval = @"SET NULL";
			break;
			
		case NSCascadeDeleteRule:
			retval = @"CASCADE";
			break;
			
		case NSDenyDeleteRule:
			retval = @"RESTRICT";
			break;
			
		default:
			break;
	}
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


static void
SortRelationships (NSRelationshipDescription* r1, NSRelationshipDescription* r2, NSRelationshipDescription* rels [2])
{
	if (NSOrderedAscending == [[r1 name] compare: [r2  name]])
	{
		rels [0] = r1;
		rels [1] = r2;
	}
	else
	{
		rels [0] = r2;
		rels [1] = r1;
	}
}


@implementation NSRelationshipDescription (BXPGAdditions)
//FIXME: this method is too long.
- (NSArray *) BXPGRelationshipConstraintsWithColumns: (BOOL) createColumns 
										 constraints: (BOOL) createConstraints
											  schema: (NSString *) schemaName
									enabledRelations: (NSMutableArray *) enabledRelations
											  errors: (NSMutableArray *) errorMessages
{
	Expect (schemaName);
	Expect (errorMessages);
		
	NSMutableArray* retval = nil;
	if (! [self inverseRelationship] && [self isToMany])
	{
		NSString* messageFormat = @"Relationship %@ in %@ will be skipped.";
		NSString* message = [NSString stringWithFormat: messageFormat, [self name], [[self entity] name]];
		NSString* reason = @"Inverse relationships are required for to-many relationships.";
		[errorMessages addObject: ImportError (message, reason)];
	}
	else
	{
		NSString* name = [self name];
		NSString* inverseName = [[self inverseRelationship] name];
		size_t nameLength = 0;
		if (name)
			nameLength = strlen ([name UTF8String]);
		size_t inverseNameLength = 0;
		if (inverseName)
			inverseNameLength = strlen ([inverseName UTF8String]);
		
		if (61 < nameLength + inverseNameLength)
		{
			//PostgreSQL's NAME data type is defined like char [NAMEDATALEN], see src/include/c.h.
			//It is treated like a C string.
			NSString* messageFormat = @"Relationship %@ in %@ will be skipped.";
			NSString* message = [NSString stringWithFormat: messageFormat, [self name], [[self entity] name]];
			NSString* reason = @"The relationship's and its inverse relationship's names combined exceed 61 bytes.";
			[errorMessages addObject: ImportError (message, reason)];
		}
		else if ([self isToMany] && [[self inverseRelationship] isToMany])
		{
			//Many-to-many

			retval = [NSMutableArray array];
			NSRelationshipDescription* rels [2] = {};
			SortRelationships (self, [self inverseRelationship], rels);
			
			NSString* rel1Name = [rels [0] name];
			NSString* rel2Name = [rels [1] name];
			NSString* entity1Name = [[rels [0] entity] name];
			NSString* entity2Name = [[rels [1] entity] name];
			NSString* id1Name = [entity1Name stringByAppendingString: @"_id"];
			NSString* id2Name = [entity2Name stringByAppendingString: @"_id"];
			NSString* fkey1Name = rel1Name;
			NSString* fkey2Name = rel2Name;
			NSString* helperTableName = [NSString stringWithFormat: @"%@_%@_rel", rel1Name, rel2Name];

			if (! ([rels [0] isOptional] && [rels [1] isOptional]))
			{
				NSString* messageFormat = @"Made relationship %@ optional.";
				NSString* message = [NSString stringWithFormat: messageFormat, rel1Name];
				NSString* reason = @"Required many-to-many relationships are not supported.";
				[errorMessages addObject: ImportError (message, reason)];
			}
			
			if (! (NSCascadeDeleteRule == [rels [0] deleteRule] && NSCascadeDeleteRule == [rels [1] deleteRule]))
			{
				NSString* messageFormat = @"Made relationship %@ cascade on delete.";
				NSString* message = [NSString stringWithFormat: messageFormat, rel1Name];
				NSString* reason = @"Delete rules other than cascade on delete are not supported for many-to-many relationships.";
				[errorMessages addObject: ImportError (message, reason)];
			}
									
			if (createColumns)
			{
				NSString* dropFormat = @"DROP TABLE IF EXISTS \"%@\".\"%@\" CASCADE;";
				NSString* createFormat = @"CREATE TABLE \"%@\".\"%@\" (\"%@\" integer, \"%@\" integer);";
				[retval addObject: [NSString stringWithFormat: dropFormat, schemaName, helperTableName]];
				[retval addObject: [NSString stringWithFormat: createFormat, schemaName, helperTableName, id2Name, id1Name]];
				[enabledRelations addObject: helperTableName];
			}
			
			if (createConstraints)
			{
				NSString* statementFormat = @"ALTER TABLE \"%@\".\"%@\" ADD PRIMARY KEY (\"%@\", \"%@\")";
				[retval addObject: [NSString stringWithFormat: statementFormat, schemaName, helperTableName, id2Name, id1Name]];
				
				//Saved for implementing required MTM relationships.
#if 0
				NSString* createFkeyFormat = 
				@"ALTER TABLE \"%@\".\"%@\" ADD CONSTRAINT \"%@\" "
				"  FOREIGN KEY (\"%@\") REFERENCES \"%@\".\"%@\" (id) "
				"  ON UPDATE CASCADE ON DELETE %@ " //For required relationships.
				"  DEFERRABLE INITIALLY DEFERRED;";
#endif
				NSString* createFkeyFormat = 
				@"ALTER TABLE \"%@\".\"%@\" ADD CONSTRAINT \"%@\" "
				"  FOREIGN KEY (\"%@\") REFERENCES \"%@\".\"%@\" (id) "
				"  ON UPDATE CASCADE ON DELETE CASCADE;";		
				[retval addObject: [NSString stringWithFormat: createFkeyFormat, schemaName, helperTableName, fkey1Name, id1Name, schemaName, entity1Name]];
				[retval addObject: [NSString stringWithFormat: createFkeyFormat, schemaName, helperTableName, fkey2Name, id2Name, schemaName, entity2Name]];			
			}
		}
		else
		{
			//FIXME: some of the checks below are not necessary since self may not be nil.
			retval = [NSMutableArray array];
			NSRelationshipDescription* srcRelationship = self;
			NSRelationshipDescription* inverseRelationship = [self inverseRelationship];
			NSEntityDescription* entity = nil;
			BOOL isOneToOne = NO;
			
			if ([srcRelationship isToMany] || !inverseRelationship || [inverseRelationship isToMany])
			{
				//One-to-many
				//Reorder so that we are in the foreign key's table.
				if ([self isToMany])
				{
					srcRelationship = inverseRelationship;
					inverseRelationship = self;
				}
				entity = [srcRelationship entity];
				
				if (inverseRelationship && NSNullifyDeleteRule != [inverseRelationship deleteRule])
				{
					NSString* messageFormat = @"Made delete rule for relationship %@ in %@ nullify.";
					NSString* message = [NSString stringWithFormat: messageFormat, 
										 [inverseRelationship name], [[inverseRelationship entity] name]];
					NSString* explanation = @"Delete rules other than nullify are not supported on to-one side of a one-to-many relationship.";
					[errorMessages addObject: ImportError (message, explanation)];
				}
			}
			else
			{
				//One-to-one
				isOneToOne = YES;
				
				if (inverseRelationship && 
					! (NSNullifyDeleteRule == [inverseRelationship deleteRule] || [inverseRelationship isOptional]))
				{
					srcRelationship = inverseRelationship;
					inverseRelationship = self;
				}
				entity = [srcRelationship entity];
				
				if (inverseRelationship)
				{
					if (NSNullifyDeleteRule != [inverseRelationship deleteRule])
					{
						NSString* messageFormat = @"Made delete rule for relationship %@ in %@ nullify.";
						NSString* message = [NSString stringWithFormat: messageFormat, 
											 [inverseRelationship name], [[inverseRelationship entity] name]];
						NSString* explanation = @"One-to-one relationships need an optional inverse relationship which has to nullify on delete.";
						[errorMessages addObject: ImportError (message, explanation)];
					}
					
					if (! [inverseRelationship isOptional])
					{
						NSString* messageFormat = @"Made relationship %@ in %@ optional.";
						NSString* message = [NSString stringWithFormat: messageFormat, 
											 [inverseRelationship name], [[inverseRelationship entity] name]];
						NSString* explanation = @"One-to-one relationships need an optional inverse relationship which has to nullify on delete.";
						[errorMessages addObject: ImportError (message, explanation)];
					}
				}			
			}
			
			//We assume that the schema name is the same for all entities.
			NSString* dstEntityName = [[srcRelationship destinationEntity] name];
			NSString* srcRelationshipName = [srcRelationship name];
			NSString* inverseName = [inverseRelationship name];
			NSString* columnName = [srcRelationshipName stringByAppendingString: @"_id"];
			
			if (createColumns)
			{
				NSString* statementFormat = @"ALTER TABLE \"%@\".\"%@\" ADD COLUMN \"%@\" integer;";
				[retval addObject: [NSString stringWithFormat: statementFormat, schemaName, [entity name], columnName]];
			}
			
			if (createConstraints)
			{
				if (! [srcRelationship isOptional])
				{
					NSString* statementFormat = @"ALTER TABLE \"%@\".\"%@\" ALTER COLUMN \"%@\" SET NOT NULL;";
					[retval addObject: [NSString stringWithFormat: statementFormat, schemaName, [entity name], columnName]];
				}
				
				if (isOneToOne)
				{
					NSString* statementFormat = @"ALTER TABLE \"%@\".\"%@\" ADD UNIQUE (\"%@\");";
					[retval addObject: [NSString stringWithFormat: statementFormat, schemaName, [entity name], columnName]];
				}		
				
				
				NSString* fkeyName = nil;
				if ([srcRelationshipName length] && [inverseName length])
					fkeyName = [NSString stringWithFormat: @"%@__%@", srcRelationshipName, inverseName];
				else if ([srcRelationshipName length])
					fkeyName = srcRelationshipName;
				else if ([inverseName length])
					fkeyName = [@"__" stringByAppendingString: inverseName];
				
				if (fkeyName)
				{
					NSString* statementFormat = 
					@"ALTER TABLE \"%@\".\"%@\" ADD CONSTRAINT \"%@\" "
					"  FOREIGN KEY (\"%@\") REFERENCES \"%@\".\"%@\" (id) "
					"  ON DELETE %@ ON UPDATE CASCADE;";
					[retval addObject: [NSString stringWithFormat: statementFormat,
										schemaName, [entity name], fkeyName,
										columnName, schemaName, dstEntityName,
										BXPGDeleteRuleName ([srcRelationship deleteRule])]];		
				}
				else
				{
					NSString* statementFormat = 
					@"ALTER TABLE \"%@\".\"%@\" ADD "
					"  FOREIGN KEY (\"%@\") REFERENCES \"%@\".\"%@\" (id) "
					"  ON DELETE %@ ON UPDATE CASCADE;";
					[retval addObject: [NSString stringWithFormat: statementFormat,
										schemaName, [entity name],
										columnName, schemaName, dstEntityName,
										BXPGDeleteRuleName ([srcRelationship deleteRule])]];				
				}
			}
		}
	}
	return retval;
}
@end
