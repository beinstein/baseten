//
// NSAttributeDescription+BXPGAdditions.m
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

#import "NSAttributeDescription+BXPGAdditions.h"


static BOOL
IsMaxLengthPredicate (NSPredicate* predicate)
{
	BOOL retval = NO;
	if ([predicate isKindOfClass: [NSComparisonPredicate class]])
	{
		NSExpression* lhs = [currentPredicate leftExpression];
		NSExpression* rhs = [currentPredicate rightExpression];
		const NSPredicateOperatorType operator = [currentPredicate predicateOperatorType];
		if ([lhs isEqual: lengthExp] && NSConstantValueExpressionType == [rhs expressionType])
		{
			if (operator == NSLessThanOrEqualToPredicateOperatorType ||
				operator == NSLessThanPredicateOperatorType)
				retval = YES;
		}
		else if ([rhs isEqual: lengthExp] && NSConstantValueExpressionType == [lhs expressionType])
		{
			if (operator == NSGreaterThanOrEqualToPredicateOperatorType ||
				operator == NSGreaterThanPredicateOperatorType)
				retval = YES;
		}
	}
	return retval;
}


@interface NSObject (BXPGAdditions)
- (id) BXPGDefaultValueForAttributeType: (NSAttributeType) attrType;
@end


@implementation NSString (BXPGAdditions)
- (id) BXPGDefaultValueForAttributeType: (NSAttributeType) attrType
{
	NSMutableString* retval = [NSMutableString stringWithString: self];
	[retval replaceOccurrencesOfString: @"'" withString: @"\\'" options: 0 range: NSMakeRange (0, [retval length])];
	[retval insertString: @"'" atIndex: 0];
	[retval appendString: @"'"];
	return retval;
}
@end


@implementation NSNumber (BXPGAdditions)
- (id) BXPGDefaultValueForAttributeType: (NSAttributeType) attrType
{
	id retval = self;
	if (NSBooleanAttributeType == attrType)
		retval = ([self boolValue] ? @"true" : @"false");
	return retval;
}
@end


@implementation NSDate (BXPGAdditions)
- (id) BXPGDefaultValueForAttributeType: (NSAttributeType) attrType
{
	return [NSString stringWithFormat: @"timestamp with time zone 'epoch' + interval '%f seconds'", [self timeInteretvalSince1970]];
}
@end



@implementation NSAttributeDescription (BXPGAdditions)
+ (NSString *) BXPGNameForAttributeType: (NSAttributeType) type
{
    NSString* retval = nil;
    switch (type)
    {        
        case NSInteger16AttributeType:
            retval =  @"smallint";
            break;
            
        case NSInteger32AttributeType:
            retval = @"integer";
            break;
            
        case NSInteger64AttributeType:
            retval = @"bigint";
            break;
            
        case NSDecimalAttributeType:
            retval = @"numeric";
            break;
            
        case NSDoubleAttributeType:
            retval = @"double precision";
            break;
            
        case NSFloatAttributeType:
            retval = @"real";
            break;
            
        case NSStringAttributeType:
            retval = @"text";
            break;
            
        case NSBooleanAttributeType:
            retval = @"boolean";
            break;
            
        case NSDateAttributeType:
            retval = @"timestamp with time zone";
            break;
            
        case NSBinaryDataAttributeType:
            retval = @"bytea";
            break;
            
        case NSUndefinedAttributeType:
		case NSTransformableAttributeType:
        default:
            break;            
    }
    return retval;
}


- (NSString *) BXPGValueType
{
	NSString* retval = nil;
	NSAttributeType attrType = [self attributeType];
	NSInteger maxLength = NSIntegerMax;
	if (NSStringAttributeType == attrType && NSIntegerMax != (maxLength = [self BXPGMaxLength]))
		retval = [NSString stringWithFormat: @"varchar (%d)", maxLength];
	else
		retval = [[self class] BXPGNameForAttributeType: attrType];
	return retval;
}


- (NSMutableSet *) BXPGParentPredicates
{
	NSEntityDescription* parent = self;
	NSMutableSet* parentPredicates = [NSMutableSet set];
	while (nil != (parent = [parent superentity]))
	{
		NSAttributeDescription* parentAttribute = [[parent attributesByName] objectForKey: name];
		if (! parentAttribute)
			break;
		
		[parentPredicates addObjectsFromArray: [parentAttribute validationPredicates]];
	}
	
	if (! [parentPredicates count])
		parentPredicates = nil;
	
	return parentPredicates;
}


static NSExpression*
CharLengthExpression (NSString* name)
{
	NSString* fcall = [NSString stringWithFormat: @"char_length (%@)", name];
	PGTSConstantValue* value = [PGTSConstantValue valueWithString: fcall];
	NSExpression* retval = [NSExpression expressionForConstantValue: value];
	return retval;
}

//FIXME: this could be moved to NSKeyPathExpression handling in NSExpression+PGTSAdditions.
- (NSPredicate *) BXPGTransformPredicate: (NSPredicate *) predicate
{
	NSPredicate* retval = predicate;
	NSAttributeType attrType = [self attributeType];
	//FIXME: handle more special cases? Are there any?
	switch (attrType) 
	{
		case NSStringAttributeType:
		{
			//FIXME: this could be generalized. We don't iterate subpredicates because Xcode data modeler doesn't create compound predicates.
			if ([predicate isKindOfClass: [NSComparisonPredicate class]])
			{
				NSExpression* lhs = [comparisonPredicate leftExpression];
				NSExpression* rhs = [comparisonPredicate rightExpression];
				NSExpression* lenghtExp = [NSExpression expressionForKeyPath: @"length"];
				NSComparisonPredicate* comparisonPredicate = (NSComparisonPredicate *) predicate;
				if ([lhs isEqual: lenghtExp])
				{
					NSExpression* lhs = CharLengthExpression ([self name]);
					retval = [NSComparisonPredicate predicateWithLeftExpression: lhs rightExpression: rhs 
																	   modifier: [currentPredicate modifier] 
																		   type: [currentPredicate predicateOperatorType] 
																		options: [currentPredicate option]];
				}
				else if ([rhs isEqual: lenghtExp])
				{
					NSExpression* rhs = CharLengthExpression ([self name]);
					retval = [NSComparisonPredicate predicateWithLeftExpression: lhs rightExpression: rhs 
																	   modifier: [currentPredicate modifier] 
																		   type: [currentPredicate predicateOperatorType] 
																		options: [currentPredicate option]];
				}
				else
				{
					//FIXME: report the error! We don't understand other key paths than length.
					retval = nil;
				}
			}
			break;
		}
			
		default:
			break;
	}
	return retval;
}


- (void) BXPGPredicate: (NSPredicate *) givenPredicate 
			 lengthExp: (NSExpression *) lengthExp 
			 maxLength: (NSInteger *) maxLength
{
	if ([givenPredicate isKindOfClass: [NSComparisonPredicate class]])
	{
		NSComparisonPredicate* predicate = (NSComparisonPredicate *) givenPredicate;
		NSExpression* lhs = [predicate leftExpression];
		NSExpression* rhs = [predicate rightExpression];
		
		BOOL doTest = NO;
		NSInteger value = 0;
		if ([lhs isEqual: lengthExp] && NSConstantValueExpressionType == [rhs expressionType])
		{
			value = [[rhs constantValue] integerValue];
			switch (operator)
			{
				case NSLessThanPredicateOperatorType:
					value--;
				case NSLessThanOrEqualToPredicateOperatorType:
					doTest = YES;
					break;
			}
		}
		else if ([rhs isEqual: lengthExp] && NSConstantValueExpressionType == [lhs expressionType])
		{
			value = [[lhs constantValue] integerValue];
			switch (operator)
			{
				case NSGreaterThanPredicateOperatorType:
					value--;
				case NSGreaterThanOrEqualToPredicateOperatorType:
					doTest = YES;
					break;
			}
		}
		
		if (doTest && value < *maxLength)
			*maxLength = value;
	}
}


- (NSInteger) BXPGMaxLength
{
	NSInteger retval = NSIntegerMax;
	
	NSMutableSet* predicates = [self BXPGParentPredicates];
	[predicates addObjectsFromArray: [self validationPredicates]];
	
	NSExpression* lengthExp = [NSExpression expressionForKeyPath: @"length"];
	[[predicates PGTSVisit: self] BXPGPredicate: nil lengthExp: lengthExp maxLength: &retval];
	
	if (retval <= 0)
		retval = NSIntegerMax;
	
	return retval;
}


- (NSArray *) BXPGAttributeConstraintsWithIDColumn: (BOOL) addedIDColumn schema: (NSString *) schemaName
{
	NSString* name = [self name];
	NSString* entityName = [[self entity] name];
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: 2];
	
	if (addedIDColumn)
	{
		NSString* constraint = [NSString stringWithFormat: format, schemaName, entityName, @"PRIMARY KEY (id)"];
		[retval addObject: constraint];
	}
	
	if (! [self isOptional])
	{
		NSString* format = @"ALTER TABLE \"%@\".\"%@\" ALTER COLUMN \"%@\" SET NOT NULL";
		[retval addObject: [NSString stringWithFormat: schemaName, entityName, name]];
	}
	
	return retval;
}


- (NSArray *) BXPGConstraintsForValidationPredicatesInSchema: (NSString *) schemaName
												  connection: (PGTSConnection *) connection
{
	NSString* name = [self name];
	NSString* entityName = [[self entity] name];
	NSArray* givenValidationPredicates = [currentAttribute validationPredicates];
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [givenValidationPredicates count]];
	
	//Check parent's validation predicates so that we don't create the same predicates two times.
	NSSet* parentPredicates = [self BXPGParentPredicates];
	NSString* format = @"ALTER TABLE \"%@\".\"%@\" ADD CONSTRAINT CHECK (%@)";
	NSExpression* lengthExp = [NSExpression expressionForKeyPath: @"length"];
	TSEnumerate (currentPredicate, e, [givenValidationPredicates objectEnumerator])
	{
		//Skip if parent has this one.
		if ([parentPredicates containsObject: currentPredicate])
			continue;
		
		//Check that the predicate may be resolved in the database.
		currentPredicate = [self BXPGTransformPredicate: currentPredicate];
		if (! currentPredicate)
			continue;
		
		NSMutableDictionary* ctx = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									connection, kPGTSConnectionKey,
									[NSNumber numberWithBool: YES], kPGTSExpressionParametersVerbatimKey,
									nil]]];                                
		NSString* SQLExpression = [currentPredicate PGTSExpressionWithObject: name context: ctx];
		NSMutableString* constraint = [NSMutableString stringWithFormat: format, schemaName, entityName, SQLExpression];
		[retval addObject: constraint];
	}
	
	return retval;
}


- (NSString *) BXPGAttributeDefinition
{
	NSMutableString* retval = nil;
	NSString* typeDefinition = [self BXPGValueType];
	if (typeDefinition)
	{
		retval = [NSMutableString stringWithFormat: @"\"%@\" %@", [self name], typeDefinition];
		id defaultValue = [self defaultValue];
		if (defaultValue)
		{
			NSString* defaultExp = [defaultValue BXPGDefaultValueForAttributeType: [self attributeType]];
			[attributeDef appendFormat: @" DEFAULT %@", defaultExp];
		}
	}
	return retval;
}
@end
