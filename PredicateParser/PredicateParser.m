//
// PredicateParser.m
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


#import <Foundation/Foundation.h>


#define kBufferSize 1024

#define BXEnumerate( LOOP_VAR, ENUMERATOR_VAR, ENUMERATION ) \
    for (id ENUMERATOR_VAR = ENUMERATION, LOOP_VAR = [ENUMERATOR_VAR nextObject]; \
            nil != LOOP_VAR; LOOP_VAR = [ENUMERATOR_VAR nextObject])


static void 
PrintIndent (int count)
{
	for (int i = 0; i < count; i++)
		printf ("    ");
}


static const char*
CompoundPredicateType (NSCompoundPredicateType type)
{
	const char* retval = "Unknown";
	switch (type)
	{
		case NSNotPredicateType:
			retval = "NOT";
			break;

		case NSAndPredicateType:
			retval = "AND";
			break;
			
		case NSOrPredicateType:
			retval = "OR";
			break;
			
		default:
			break;
	}
	return retval;
}


@interface NSPredicate (BXAdditions)
- (void) BXDescription: (int) indent;
@end


@interface NSExpression (BXAdditions)
- (void) BXDescription: (int) indent isLhs: (BOOL) isLhs;
- (void) BXDescription: (int) indent;
@end


@implementation NSPredicate (BXAdditions)
- (void) BXDescription: (int) indent
{
	PrintIndent (indent);
    printf ("Other predicate (%c): %s\n", 
        [self evaluateWithObject: nil] ? 't' : 'f',
        [[self predicateFormat] UTF8String]);
}
@end


@implementation NSCompoundPredicate (BXAdditions)
- (void) BXDescription: (int) indent
{
	PrintIndent (indent);

    char value = '?';
    @try
    {
        value = ([self evaluateWithObject: nil] ? 't' : 'f');
    }
    @catch (NSException* e)
    {
    }

    printf ("Compound predicate (%c): %s\n", 
            value, CompoundPredicateType ([self compoundPredicateType]));

    BXEnumerate (predicate, e, [[self subpredicates] objectEnumerator])
		[predicate BXDescription: indent + 1];
}
@end


@implementation NSComparisonPredicate (BXAdditions)
- (void) BXDescription: (int) indent
{
	PrintIndent (indent);

    char value = '?';
    @try
    {
        value = ([self evaluateWithObject: nil] ? 't' : 'f');
    }
    @catch (NSException* e)
    {
    }

    printf ("Comparison predicate (%c): %s\n", 
            value, [[self predicateFormat] UTF8String]);
	[[self leftExpression] BXDescription: indent + 1 isLhs: YES];
	[[self rightExpression] BXDescription: indent + 1 isLhs: NO];
}
@end


@implementation NSExpression (BXAdditions)
- (NSString *) BXExpressionDesc
{
	NSString* retval = @"";
	NSExpressionType type = [self expressionType];
	switch (type)
	{
		case NSConstantValueExpressionType:
			retval = [NSString stringWithFormat: @"Constant value: %@", [self constantValue]];
			break;
			
		case NSEvaluatedObjectExpressionType:
			retval = @"Evaluated object";
			break;
			
		case NSVariableExpressionType:
			retval = [NSString stringWithFormat: @"Variable: %@", [self variable]];
			break;
			
		case NSKeyPathExpressionType:
			retval = [NSString stringWithFormat: @"Key path: %@", [self keyPath]];
			break;
			
		case NSFunctionExpressionType:
			retval = [NSString stringWithFormat: @"Function: %@", [self function]];
			break;
			
        case 14: //NSAggregateExpressionType
			retval = @"Aggregate expression";
			break;
			
        case 13: //NSSubqueryExpressionType
			retval = @"Subquery:";
			break;
			
        case 5: //NSUnionSetExpressionType
			retval = @"Union expression";
			break;
			
        case 6: //NSIntersectSetExpressionType
			retval = @"Intersection expression";
			break;
			
        case 7: //NSMinusSetExpressionType
			retval = @"Exclusion expression";
			break;
			
		case 10:
			retval = [NSString stringWithFormat: @"Key path specifier (undocumented, type %d): %@", 
            type, [self keyPath]];
			break;
			
		default:
			retval = [NSString stringWithFormat: @"Unknown (type %d, class %@)", type, [self class]];
			break;
	}
	return retval;
}

- (void) BXSubDescriptions: (int) indent
{
	NSExpressionType type = [self expressionType];
	switch (type)
	{
		case NSFunctionExpressionType:
		{
			PrintIndent (indent);
			printf ("Operand:\n");
			[[self operand] BXDescription: indent + 1];
			PrintIndent (indent);
			printf ("Arguments:\n");
            BXEnumerate (expression, e, [[self arguments] objectEnumerator])
				[expression BXDescription: indent + 1];
			break;
		}

#if defined(MAC_OS_X_VERSION_10_5) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5
		case NSSubqueryExpressionType:
		{
            PrintIndent (indent);
            printf ("Variable name: %s\n", [[self variable] UTF8String]);
            
            PrintIndent (indent);
            printf ("Collection:\n");
            NSExpression* collection = [self collection];
            [collection BXDescription: 1 + indent];

			NSPredicate* predicate = [self predicate];
			[predicate BXDescription: indent];
			break;
		}
	
		case NSUnionSetExpressionType:
		case NSIntersectSetExpressionType:
		case NSMinusSetExpressionType:
		case NSAggregateExpressionType:
		{
			for (NSExpression* expression in [self collection])
				[expression BXDescription: indent];
			break;
		}
#endif

		default:
			break;
	}
		
	end:
		;
}

- (void) BXDescription: (int) indent isLhs: (BOOL) isLhs
{
	PrintIndent (indent);
	printf ("%s: %s\n", (isLhs ? "lhs" : "rhs"), [[self BXExpressionDesc] UTF8String]);
	[self BXSubDescriptions: indent + 1];
}

- (void) BXDescription: (int) indent
{
	PrintIndent (indent);
	printf ("%s\n", [[self BXExpressionDesc] UTF8String]);
	[self BXSubDescriptions: indent + 1];
}
@end


int main (int argc, char** argv)
{
	char buffer [kBufferSize] = {};
	while (! feof (stdin))
	{
		printf ("\nEnter predicate: ");
		if (fgets (buffer, kBufferSize, stdin))
		{
            NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

			NSString* predicateFormat = [NSString stringWithUTF8String: buffer];
			predicateFormat = [predicateFormat stringByTrimmingCharactersInSet: 
				[NSCharacterSet whitespaceAndNewlineCharacterSet]];

			@try
			{
				NSPredicate* predicate = [NSPredicate predicateWithFormat: predicateFormat argumentArray: nil];
				[predicate BXDescription: 0];
			}
			@catch (NSException* e)
			{
				printf ("\nCaught exception: %s\n", [[e description] UTF8String]);
			}

            [pool release];
		}
	}
	return 0;
}
