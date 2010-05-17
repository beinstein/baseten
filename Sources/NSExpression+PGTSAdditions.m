//
// NSExpression+PGTSAdditions.m
// BaseTen
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

#import "PGTSAdditions.h"
#import "NSExpression+PGTSAdditions.h"
#import "BXLogger.h"
#import "BXEntityDescription.h"
#import "BXKeyPathParser.h"
#import "BXPropertyDescription.h"
#import "BXPGAdditions.h"
#import "BXPGExpressionValueType.h"
#import "BXEnumerate.h"


@implementation NSExpression (BXPGAdditions)
- (BXPGExpressionValueType *) BXPGVisitExpression: (id <BXPGPredicateVisitor>) visitor
{
	//Return value of nil means unexpected.
	BXPGExpressionValueType* retval = nil;
	NSExpressionType type = [self expressionType];
	switch (type)
	{
		case NSConstantValueExpressionType:
			retval = [visitor visitConstantValueExpression: self];
			break;
			
		case NSEvaluatedObjectExpressionType:
			retval = [visitor visitEvaluatedObjectExpression: self];
			break;
			
		case NSVariableExpressionType:
			retval = [visitor visitVariableExpression: self];
			break;
			
		case 10: //NSKeyPathSpecifierExpression
		case NSKeyPathExpressionType:
			retval = [visitor visitKeyPathExpression: self];
			break;
						
		case NSFunctionExpressionType:
			retval = [visitor visitFunctionExpression: self];
			break;
			
		case NSAggregateExpressionType:
			retval = [visitor visitAggregateExpression: self];
			break;
			
		case NSSubqueryExpressionType:
			retval = [visitor visitSubqueryExpression: self];
			break;
			
		case NSUnionSetExpressionType:
			retval = [visitor visitUnionSetExpression: self];
			break;
			
		case NSIntersectSetExpressionType:
			retval = [visitor visitIntersectSetExpression: self];
			break;
			
		case NSMinusSetExpressionType:
			retval = [visitor visitMinusSetExpression: self];
			break;
			
		case NSBlockExpressionType:
			retval = [visitor visitBlockExpression: self];
			break;
			
		default:
			retval = [visitor visitUnknownExpression: self];
			break;
	}
	return retval;
}

//FIXME: These are only used with SQL schema generation. It should be removed in a future revision.
static void
AddRelationship (BXRelationshipDescription* rel, NSMutableDictionary* ctx)
{
	NSMutableSet* relationships = [ctx objectForKey: kBXRelationshipsKey];
	if (! relationships)
	{
		relationships = [NSMutableSet set];
		[ctx setObject: relationships forKey: kBXRelationshipsKey];
	}
	[relationships addObject: rel];
}

static NSString*
AddParameter (id parameter, NSMutableDictionary* context)
{
	BXAssertValueReturn (nil != context, nil, @"Expected context not to be nil");
    NSString* retval = nil;
	if (nil == parameter)
		parameter = [NSNull null];
	
	if (YES == [[context objectForKey: kPGTSExpressionParametersVerbatimKey] boolValue])
	{
		PGTSConnection* connection = [context objectForKey: kPGTSConnectionKey];
		retval = [NSString stringWithFormat: @"\"%@\"", [parameter PGTSEscapedObjectParameter: connection]]; //Patch by Tim Bedford 2008-08-06.
	}
	else
	{
		//First increment the parameter index. We start from zero, since indexing in
		//NSArray is zero-based. The kPGTSParameterIndexKey will have the total count
		//of parameters, however.
		NSNumber* indexObject = [context objectForKey: kPGTSParameterIndexKey];
		if (nil == indexObject)
		{
			indexObject = [NSNumber numberWithInt: 0];
		}
		int index = [indexObject intValue];
		[context setObject: [NSNumber numberWithInt: index + 1] forKey: kPGTSParameterIndexKey];
		
		NSMutableArray* parameters = [context objectForKey: kPGTSParametersKey];
		if (nil == parameters)
		{
			parameters = [NSMutableArray array];
			[context setObject: parameters forKey: kPGTSParametersKey];
		}
		[parameters insertObject: parameter atIndex: index];
		
		//Return the index used in the query.
		int count = index + 1;
		BXAssertValueReturn ([parameters count] == count, nil,
							 @"Expected count to be %d, was %d.\n\tparameter:\t%@ \n\tcontext:\t%@", 
							 [parameters count], count, parameter, context);
		retval = [NSString stringWithFormat: @"$%d", count];
	}
	return retval;
}

- (id) PGTSValueWithObject: (id) anObject context: (NSMutableDictionary *) context
{
    id retval = nil;
	NSString* keyPath = nil;
	NSExpressionType type = [self expressionType];
    switch (type)
    {
        case NSConstantValueExpressionType:
        {
            id constantValue = [self constantValue];
            if (YES == [constantValue respondsToSelector: @selector (PGTSConstantExpressionValue:)])
            {
                retval = [constantValue PGTSConstantExpressionValue: context];
                break;
            }
            //Otherwise continue.
        }

        case NSEvaluatedObjectExpressionType:
        case NSVariableExpressionType:
		{
            //Default behaviour unless the expression evaluates into a key path expression.
			id evaluated = [self expressionValueWithObject: anObject context: context];
			if (! ([evaluated isKindOfClass: [NSExpression class]] && 
				   [evaluated expressionType] == NSKeyPathExpressionType))
			{
				retval = AddParameter (evaluated, context);
				break;
			}
			else
			{
				keyPath = [evaluated keyPath];
				//Otherwise continue.
			}
		}
			
        case NSKeyPathExpressionType:
        {
			PGTSConnection* connection = [context objectForKey: kPGTSConnectionKey];
			BXEntityDescription* entity = [context objectForKey: kBXEntityDescriptionKey];
			
			if (! keyPath)
				keyPath = [self keyPath];
			NSArray* components = BXKeyPathComponents (keyPath);
			NSMutableSet* entities = [NSMutableSet setWithCapacity: [components count]];
			id property = nil;
			
			BXEnumerate (currentKey, e, [components objectEnumerator])
			{
				if ((property = [[entity attributesByName] objectForKey: currentKey]))
				{
					entity = [property entity];
					[entities addObject: entity];
					
					//If the key path continues, the predicate may not be evaluated on the database.
					if (0 < [[e allObjects] count])
						goto end;
				}
				else if ((property = [[entity relationshipsByName] objectForKey: currentKey]))
				{
					entity = [property entity];
					[entities addObject: entity];
					AddRelationship (property, context);
				}
				else
				{
					goto end;
				}
			}
			
			//If the key path ends in an object reference, the predicate may not be evaluated on the database.
			if (kBXPropertyKindAttribute != [property propertyKind])
				goto end;
			
			retval = [property BXPGQualifiedName: connection];
            break;
        }
         
        case NSFunctionExpressionType:
#if MAC_OS_X_VERSION_10_5 <= MAC_OS_X_VERSION_MAX_ALLOWED
		case NSAggregateExpressionType:
		case NSSubqueryExpressionType:
		case NSUnionSetExpressionType:
		case NSIntersectSetExpressionType:
		case NSMinusSetExpressionType:
#endif
            
        default:
            break;
    }
end:
    return retval;
}
@end
