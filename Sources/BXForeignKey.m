//
// BXForeignKey.m
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

#import <PGTS/private/PGTSHOM.h>

#import "BXForeignKey.h"
#import "BXForeignKeyPrivate.h"
#import "BXEntityDescription.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseObject.h"
#import "BXObjectKeyPathExpression.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXDatabaseObjectPrivate.h"
#import "BXLogger.h"


@implementation BXForeignKey

- (id) initWithName: (NSString *) aName
{
	if ((self = [super initWithName: aName]))
	{
		mFieldNames = [[NSMutableSet alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[mFieldNames release];
	[super dealloc];
}

- (NSString *) description
{
	NSArray* fieldNames = [mFieldNames allObjects];
	NSArray* from = [[fieldNames PGTSCollect] objectAtIndex: 0];
	NSArray* to   = [[fieldNames PGTSCollect] objectAtIndex: 1];
	NSString* retval = [NSString stringWithFormat: @"<%@ (%p): %@ (%@ -> %@)>", 
						[self class], self, [self name],
						[from componentsJoinedByString: @", "], [to componentsJoinedByString: @", "]];
	return retval;
}

- (void) addSrcFieldName: (NSString *) srcFName dstFieldName: (NSString *) dstFName
{
	BXAssertVoidReturn (nil != srcFName, @"Expected srcFName not to be nil.");
	BXAssertVoidReturn (nil != dstFName, @"Expected dstFName not to be nil.");
	[mFieldNames addObject: [NSArray arrayWithObjects: srcFName, dstFName, nil]];
}

- (NSArray *) srcFieldNames
{
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [mFieldNames count]];
	TSEnumerate (currentFieldArray, e, [mFieldNames objectEnumerator])
		[retval addObject: [currentFieldArray objectAtIndex: 0]];
	
	return retval;
}

- (NSArray *) dstFieldNames
{
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [mFieldNames count]];
	TSEnumerate (currentFieldArray, e, [mFieldNames objectEnumerator])
		[retval addObject: [currentFieldArray objectAtIndex: 1]];
	
	return retval;
}
- (NSSet *) fieldNames
{
	return mFieldNames;
}

- (NSDeleteRule) deleteRule
{
	return mDeleteRule;
}

- (void) setDeleteRule: (NSDeleteRule) aRule
{
	mDeleteRule = aRule;
}

- (NSPredicate *) predicateForSrcEntity: (BXEntityDescription *) srcEntity valuesInObject: (BXDatabaseObject *) anObject
{
	return [self predicateForEntity: srcEntity valuesInObject: anObject entityIndex: 0 objectIndex: 1];
}

- (NSPredicate *) predicateForDstEntity: (BXEntityDescription *) dstEntity valuesInObject: (BXDatabaseObject *) anObject
{
	return [self predicateForEntity: dstEntity valuesInObject: anObject entityIndex: 1 objectIndex: 0];
}

- (BXDatabaseObjectID *) objectIDForEntity: (BXEntityDescription *) entity fromObject: (BXDatabaseObject *) object
							   entityIndex: (int) ei objectIndex: (int) oi
{
	BOOL haveValues = YES;
	NSMutableDictionary* values = [NSMutableDictionary dictionaryWithCapacity: [mFieldNames count]];
	TSEnumerate (currentFieldArray, e, [mFieldNames objectEnumerator])
	{
		NSString* name = [currentFieldArray objectAtIndex: ei];
		NSString* objectKey = [currentFieldArray objectAtIndex: oi];
		id value = [object primitiveValueForKey: objectKey];
		if (value)
			[values setObject: value forKey: name];
		else
		{
			haveValues = NO;
			break;
		}
	}
	
	BXDatabaseObjectID* retval = nil;
	if (haveValues)
		retval = [BXDatabaseObjectID IDWithEntity: entity primaryKeyFields: values];
	return retval;	
}


- (BXDatabaseObjectID *) objectIDForDstEntity: (BXEntityDescription *) dstEntity fromObject: (BXDatabaseObject *) object
{
	return [self objectIDForEntity: dstEntity fromObject: object entityIndex: 1 objectIndex: 0];
}

- (BXDatabaseObjectID *) objectIDForSrcEntity: (BXEntityDescription *) srcEntity fromObject: (BXDatabaseObject *) object
{
	return [self objectIDForEntity: srcEntity fromObject: object entityIndex: 0 objectIndex: 1];
}


- (NSPredicate *) predicateForSrcEntity: (BXEntityDescription *) srcEntity
							  dstEntity: (BXEntityDescription *) dstEntity
{
	BXAssertValueReturn (nil != srcEntity, nil, @"Expected srcEntity to be set.");
	BXAssertValueReturn (nil != dstEntity, nil, @"Expected dstEntity to be set.");
	
	NSDictionary* srcAttributes = [srcEntity attributesByName];
	NSDictionary* dstAttributes = [dstEntity attributesByName];
	NSMutableArray* subPredicates = [NSMutableArray arrayWithCapacity: [mFieldNames count]];
	
	TSEnumerate (currentFieldArray, e, [mFieldNames objectEnumerator])
	{
		BXAttributeDescription* lhAttribute = [srcAttributes objectForKey: [currentFieldArray objectAtIndex: 0]];
		BXAttributeDescription* rhAttribute = [dstAttributes objectForKey: [currentFieldArray objectAtIndex: 1]];
		NSExpression* lhs = [NSExpression expressionForConstantValue: lhAttribute];
		NSExpression* rhs = [NSExpression expressionForConstantValue: rhAttribute];
		NSPredicate* predicate = [NSComparisonPredicate predicateWithLeftExpression: lhs
																	rightExpression: rhs
																		   modifier: NSDirectPredicateModifier
																			   type: NSEqualToPredicateOperatorType 
																			options: 0];
		[subPredicates addObject: predicate];
	}
	return [NSCompoundPredicate andPredicateWithSubpredicates: subPredicates];
}

- (NSMutableDictionary *) srcDictionaryFor: (BXEntityDescription *) entity valuesFromDstObject: (BXDatabaseObject *) object
{
	return [self valueDictionaryForEntity: entity valuesInObject: object entityIndex: 0 objectIndex: 1];
}

- (NSMutableDictionary *) dstDictionaryFor: (BXEntityDescription *) entity valuesFromSrcObject: (BXDatabaseObject *) object
{
	return [self valueDictionaryForEntity: entity valuesInObject: object entityIndex: 1 objectIndex: 0];
}

@end


@implementation BXForeignKey (PrivateMethods)

- (NSPredicate *) predicateForEntity: (BXEntityDescription *) entity 
					  valuesInObject: (BXDatabaseObject *) anObject
						 entityIndex: (unsigned int) ei 
						 objectIndex: (unsigned int) oi
{
	BXAssertValueReturn (nil != entity, nil, @"Expected entity to be set.");
	
	NSDictionary* attributes = [entity attributesByName];
	NSMutableArray* subPredicates = [NSMutableArray arrayWithCapacity: [mFieldNames count]];
	TSEnumerate (currentFieldArray, e, [mFieldNames objectEnumerator])
	{
		id attributeKey = [currentFieldArray objectAtIndex: ei];
		id objectKey = [currentFieldArray objectAtIndex: oi];
		BXAttributeDescription* attribute = [attributes objectForKey: attributeKey];
		
		NSExpression* lhs = [NSExpression expressionForConstantValue: attribute];
		NSExpression* rhs = [BXObjectKeyPathExpression expressionForKeyPath: objectKey object: [[anObject retain] autorelease]];
		NSPredicate* predicate = [NSComparisonPredicate predicateWithLeftExpression: lhs
																	rightExpression: rhs
																		   modifier: NSDirectPredicateModifier
																			   type: NSEqualToPredicateOperatorType 
																			options: 0];
		[subPredicates addObject: predicate];
	}
	return [NSCompoundPredicate andPredicateWithSubpredicates: subPredicates];	
}

/**
 * \internal
 * \param ei Either 0 or 1
 * \param oi Either 1 or 0
 */
- (NSMutableDictionary *) valueDictionaryForEntity: (BXEntityDescription *) entity valuesInObject: (BXDatabaseObject *) object 
									   entityIndex: (unsigned int) ei objectIndex: (unsigned int) oi
{
	BXAssertValueReturn (nil != entity, nil, @"Expected entity to be set.");
	
	NSMutableDictionary* retval = [NSMutableDictionary dictionaryWithCapacity: [mFieldNames count]];
	NSDictionary* attributes = [entity attributesByName];
	TSEnumerate (currentFieldArray, e, [mFieldNames objectEnumerator])
	{
		NSString* attributeName = [currentFieldArray objectAtIndex: ei];
		BXAttributeDescription* attribute = [attributes objectForKey: attributeName];
		NSString* objectKey = [currentFieldArray objectAtIndex: oi];
		[retval setObject: (object ? [object primitiveValueForKey: objectKey] : [NSNull null]) forKey: attribute];
	}	
	return retval;
}

@end
