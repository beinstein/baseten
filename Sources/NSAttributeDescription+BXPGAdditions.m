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
#import "NSPredicate+PGTSAdditions.h"
#import "PGTSHOM.h"
#import "PGTSConstantValue.h"
#import "PGTSFunctions.h"
#import "BXLogger.h"
#import "PGTSFoundationObjects.h"
#import "BXEnumerate.h"


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


- (NSMutableSet *) BXPGParentPredicates
{
	NSString* name = [self name];
	NSEntityDescription* parent = [self entity];
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


- (void) BXPGPredicate: (NSPredicate *) givenPredicate 
			 lengthExp: (NSExpression *) lengthExp 
			 maxLength: (NSInteger *) maxLength
{
	if ([givenPredicate isKindOfClass: [NSComparisonPredicate class]])
	{
		NSComparisonPredicate* predicate = (NSComparisonPredicate *) givenPredicate;
		NSExpression* lhs = [predicate leftExpression];
		NSExpression* rhs = [predicate rightExpression];
		NSPredicateOperatorType operator = [predicate predicateOperatorType];
		
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


static NSExpression*
CharLengthExpression (NSString* name)
{
	NSString* fcall = [NSString stringWithFormat: @"char_length (\"%@\")", name];
	PGTSConstantValue* value = [PGTSConstantValue valueWithString: fcall];
	NSExpression* retval = [NSExpression expressionForConstantValue: value];
	return retval;
}

//FIXME: this could be moved to NSKeyPathExpression handling in NSExpression+PGTSAdditions.
- (NSPredicate *) BXPGTransformPredicate: (NSPredicate *) givenPredicate
{
	NSPredicate* retval = givenPredicate;
	NSAttributeType attrType = [self attributeType];
	//FIXME: handle more special cases? Are there any?
	switch (attrType) 
	{
		case NSStringAttributeType:
		{
			//FIXME: this could be generalized. We don't iterate subpredicates because Xcode data modeler doesn't create compound predicates.
			if ([givenPredicate isKindOfClass: [NSComparisonPredicate class]])
			{
				NSComparisonPredicate* predicate = (NSComparisonPredicate *) givenPredicate;
				NSExpression* lhs = [predicate leftExpression];
				NSExpression* rhs = [predicate rightExpression];
				NSExpression* lenghtExp = [NSExpression expressionForKeyPath: @"length"];
				if ([lhs isEqual: lenghtExp])
				{
					NSExpression* lhs = CharLengthExpression ([self name]);
					retval = [NSComparisonPredicate predicateWithLeftExpression: lhs rightExpression: rhs 
																	   modifier: [predicate comparisonPredicateModifier] 
																		   type: [predicate predicateOperatorType] 
																		options: [predicate options]];
				}
				else if ([rhs isEqual: lenghtExp])
				{
					NSExpression* rhs = CharLengthExpression ([self name]);
					retval = [NSComparisonPredicate predicateWithLeftExpression: lhs rightExpression: rhs 
																	   modifier: [predicate comparisonPredicateModifier] 
																		   type: [predicate predicateOperatorType] 
																		options: [predicate options]];
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


- (NSArray *) BXPGAttributeConstraintsInSchema: (NSString *) schemaName
{
	NSString* name = [self name];
	NSString* entityName = [[self entity] name];
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: 2];
		
	if (! [self isOptional])
	{
		NSString* format = @"ALTER TABLE \"%@\".\"%@\" ALTER COLUMN \"%@\" SET NOT NULL;";
		[retval addObject: [NSString stringWithFormat: format, schemaName, entityName, name]];
	}
	
	return retval;
}


- (NSArray *) BXPGConstraintsForValidationPredicatesInSchema: (NSString *) schemaName
												  connection: (PGTSConnection *) connection
{
	NSString* name = [self name];
	NSString* entityName = [[self entity] name];
	NSArray* givenValidationPredicates = [self validationPredicates];
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [givenValidationPredicates count]];
	
	//Check parent's validation predicates so that we don't create the same predicates two times.
	NSSet* parentPredicates = [self BXPGParentPredicates];
	NSString* format = @"ALTER TABLE \"%@\".\"%@\" ADD CHECK (%@);"; //Patch by Tim Bedford 2008-08-06.
	BXEnumerate (currentPredicate, e, [givenValidationPredicates objectEnumerator])
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
									nil];
		NSString* SQLExpression = [currentPredicate PGTSExpressionWithObject: name context: ctx];
		NSMutableString* constraint = [NSMutableString stringWithFormat: format, schemaName, entityName, SQLExpression];
		[retval addObject: constraint];
	}
	
	return retval;
}


- (NSString *) BXPGAttributeDefinition
{
	NSString* typeDefinition = [self BXPGValueType];
	NSString* addition = @"";
	id defaultValue = [self defaultValue];
	if (defaultValue)
	{
		NSString* defaultExp = [defaultValue PGTSExpressionOfType: [self attributeType]];
		addition = [NSString stringWithFormat: @"DEFAULT %@", defaultExp];
	}
	return [NSString stringWithFormat: @"\"%@\" %@ %@", [self name], typeDefinition, addition];
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


- (BOOL) BXCanAddAttribute: (NSError **) outError
{
	BOOL retval = NO;
	NSString* errorFormat = @"Skipped attribute %@ in %@.";
	NSError* localError = nil;
	switch ([self attributeType]) 
	{
        case NSUndefinedAttributeType:
		{
			NSString* errorString = [NSString stringWithFormat: errorFormat, [self name], [[self entity] name]];
			localError = ImportError (errorString, @"Attributes with undefined type are not supported.");
			break;
		}
			
		case NSTransformableAttributeType:
		{
			NSString* errorString = [NSString stringWithFormat: errorFormat, [self name], [[self entity] name]];
			localError = ImportError (errorString, @"Attributes with transformable type are not supported.");
            break;
		}
			
		default:
			retval = YES;
			break;
	}
	
	if (outError)
		*outError = localError;
	return retval;
}
@end
