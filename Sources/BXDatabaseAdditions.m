//
// BXDatabaseAdditions.m
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
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

#import "BXDatabaseAdditions.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXConstants.h"
#import "BXDatabaseContext.h"
#import "BXException.h"
#import "BXDatabaseObject.h"


@implementation NSURL (BXDatabaseAdditions)

- (unsigned int) BXHash
{
    static unsigned int u = 0;
    if (0 == u)
    {
        u = [[self scheme] hash];
        u ^= [[self host] hash];
        u ^= [[self port] hash];
        u ^= [[self path] hash];
        u ^= [[self query] hash];
    }
    return u;
}

- (NSURL *) BXURIForHost: (NSString *) host database: (NSString *) dbName username: (NSString *) username password: (id) password
{
	NSString* scheme = [self scheme];
	NSURL* rval = nil;
	
	if (nil != scheme)
	{
		NSMutableString* URLString = [NSMutableString string];
		[URLString appendFormat: @"%@://", scheme];

		if (nil == username) username = [self user];
		
		if (nil == password) password = [self password];
		else if ([NSNull null] == password) password = nil;
		
		if (nil != password && 0 < [password length])
			[URLString appendFormat: @"%@:%@@", username ?: @"", password];
		else if (nil != username && 0 < [username length])
			[URLString appendFormat: @"%@@", username];
	
		if (nil == host) host = [self host];
		if (nil == host) host = @"";
		[URLString appendString: host];
	
		if (nil != dbName) 
			[URLString appendFormat: @"/%@", dbName];
		else
			[URLString appendFormat: [self path] ?: @""];
		
		rval = [NSURL URLWithString: URLString];
	}
	return rval;
}

#if 0
- (BXDatabaseObjectID *) BXDatabaseObjectID
{
    return [[[BXDatabaseObjectID alloc] initWithURI: self] autorelease];
}
#endif

@end


@implementation NSData (BXDatabaseAdditions)
- (NSData *) BXURLDecodedData;
{
    NSMutableData* rval = [NSMutableData data];
    unsigned int length = [self length];
    const char* bytes = [self bytes];
    size_t size = 3 * sizeof (char);
    char* hex = malloc (size);
    for (int i = 0; i < length; i++)
    {
        unsigned char c = bytes [i];
        if ('%' != c)
            [rval appendBytes: &c length: sizeof (char)];
        else
        {
            if (length < i + 3)
            {
                free (hex);
                @throw [NSException exceptionWithName: NSRangeException reason: nil 
                                             userInfo: [NSDictionary dictionaryWithObject: self forKey: kBXObjectKey]];
            }
            i++;
            strlcpy (hex, &bytes [i], size);
            long l = strtol (hex, NULL, 16);
            [rval appendBytes: &l length: sizeof (char)];
            i++;
        }
    }
    free (hex);
    return [NSData dataWithData: rval];
}

- (NSData *) BXURLEncodedData
{
    NSMutableData* rval = [NSMutableData data];
    unsigned int length = [self length];
    const char* bytes = [self bytes];
    char* hex = malloc (3 * sizeof (char));
    for (int i = 0; i < length; i++)
    {
        unsigned char c = bytes [i];
        if (('0' <= c && c <= '9') || ('A' <= c && c <= 'Z') || ('a' <= c && c <= 'z') || 
            '-' == c || '_' == c || '.' == c || '~' == c)
            [rval appendBytes: &c length: sizeof (char)];
        else
        {
            sprintf (hex, "%%%02x", c);
            [rval appendBytes: hex length: 3 * sizeof (char)];
        }
    }
    free (hex);
    return [NSData dataWithData: rval];
}
@end


@implementation NSString (BXDatabaseAdditions)
- (NSData *) BXURLDecodedData
{
    return [[self dataUsingEncoding: NSASCIIStringEncoding] BXURLDecodedData];
}

+ (NSString *) BXURLEncodedData: (NSData *) data
{
    return [[[NSString alloc] initWithData: [data BXURLEncodedData] 
                                  encoding: NSASCIIStringEncoding] autorelease];
}

- (NSArray *) BXKeyPathComponentsWithQuote: (NSString *) quoteString
{
    NSMutableArray* rval = [NSMutableArray array];
    NSString* part = nil;
    NSScanner* scanner = [NSScanner scannerWithString: self];
    for (;;)
    {
        if ('"' == [self characterAtIndex: [scanner scanLocation]])
        {
            NSMutableString* subpart = [NSMutableString string];
            [scanner scanString: quoteString intoString: NULL];
            for (;;) 
            {
                if ([scanner scanUpToString: quoteString intoString: &part])
                    [subpart appendString: part];
                else
                {
                    unichar c = [self characterAtIndex: [scanner scanLocation] - 1];
                    [scanner scanString: quoteString intoString: NULL];
                    if ('\\' != c)
                        break;
                }
            }
            [rval addObject: subpart];            
        }
        else if ([scanner scanUpToString: @"." intoString: &part])
        {
            [rval addObject: part];
        }
        
        if ([scanner isAtEnd])
            break;
        else
        {
            BOOL period = [scanner scanString: @"." intoString: NULL];
            assert (period);
        }
    }
    return rval;
}
@end


@implementation NSPredicate (BXDatabaseAdditions)
+ (NSPredicate *) BXAndPredicateWithProperties: (NSArray *) properties
                             matchingProperties: (NSArray *) otherProperties
                                           type: (NSPredicateOperatorType) type
{
    NSArray* parts = [self BXSubpredicatesForProperties: properties
                                      matchingProperties: otherProperties
                                                    type: type];
    id rval = nil;
    if (nil != parts)
        rval = [NSCompoundPredicate andPredicateWithSubpredicates: parts];
    return rval;
}

+ (NSPredicate *) BXOrPredicateWithProperties: (NSArray *) properties
                            matchingProperties: (NSArray *) otherProperites
                                          type: (NSPredicateOperatorType) type
{
    NSArray* parts = [self BXSubpredicatesForProperties: properties
                                      matchingProperties: otherProperites
                                                    type: type];
    id rval = nil;
    if (nil != parts)
        rval = [NSCompoundPredicate orPredicateWithSubpredicates: parts];
    return rval;    
}

+ (NSArray *) BXSubpredicatesForProperties: (NSArray *) properties
                         matchingProperties: (NSArray *) otherProperties
                                       type: (NSPredicateOperatorType) type
{
    unsigned int count = [properties count];
    NSAssert (count == [otherProperties count], nil);
    NSMutableArray* parts = [NSMutableArray arrayWithCapacity: count];
    for (int i = 0; i < count; i++)
    {
        //The expression type should not be changed since it affects expression handling in NSExpression+PGTSAdditions.
        NSExpression* lhs = [NSExpression expressionForConstantValue: [properties objectAtIndex: i]];
        NSExpression* rhs = [NSExpression expressionForConstantValue: [otherProperties objectAtIndex: i]];
        [parts addObject: [NSComparisonPredicate predicateWithLeftExpression: lhs
                                                             rightExpression: rhs
                                                                    modifier: NSDirectPredicateModifier
                                                                        type: type
                                                                     options: 0]];
    }
    if (0 == [parts count])
        parts = nil;
    return parts;
}

- (NSArray *) BXEntities
{
    return nil;
}

- (NSSet *) BXEntitySet
{
    NSMutableSet* rval = [NSMutableSet setWithArray: [self BXEntities]];
    [rval removeObject: [NSNull null]];
    return rval;
}

- (BOOL) BXEvaluateWithObject: (id) anObject
{
    //True / false predicate
    return [self evaluateWithObject: anObject];
}

@end


@implementation NSCompoundPredicate (BXDatabaseAdditions)
- (NSSet *) BXEntitySet
{
    NSMutableSet* set = [NSMutableSet set];
    TSEnumerate (currentPredicate, e, [[self subpredicates] objectEnumerator])
        [set unionSet: [currentPredicate BXEntitySet]];
    return set;
}

- (BOOL) BXEvaluateWithObject: (id) anObject
{
    NSCompoundPredicateType type = [self compoundPredicateType];
    BOOL rval = NO;
    switch (type)
    {
        case NSNotPredicateType:
        {
            rval = ! ([[[self subpredicates] objectAtIndex: 0] BXEvaluateWithObject: anObject]);
            break;
        }
        case NSAndPredicateType:
        case NSOrPredicateType:
        {
            TSEnumerate (currentPredicate, e, [[self subpredicates] objectEnumerator])
            {
                rval = [currentPredicate BXEvaluateWithObject: anObject];
                if ((!rval && NSAndPredicateType == type) || (rval && NSOrPredicateType == type))
                    break;
            }
            break;
        }
        default:
            break;
    }
    return rval;
}
@end


@implementation NSMutableSet (BXDatabaseAdditions)
- (id) BXConditionalAdd: (id) anObject
{
    id rval = [self member: anObject];
    if (nil == rval)
    {
        [self addObject: anObject];
        rval = anObject;
    }
    return rval;
}
@end


@implementation NSError (BXDatabaseAdditions)
- (NSException *) BXExceptionWithName: (NSString *) aName
{
    NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithDictionary: [self userInfo]];
    [userInfo setObject: self forKey: kBXErrorKey];
    return [BXException exceptionWithName: kBXExceptionUnhandledError 
                                            reason: [self localizedFailureReason]
                                          userInfo: userInfo];
}
@end


@implementation NSDictionary (BXDatabaseAdditions)
- (NSDictionary *) BXSubDictionaryExcludingKeys: (NSArray *) keys
{
    NSMutableDictionary* rval = [NSMutableDictionary dictionaryWithCapacity: [self count] - [keys count]];
    TSEnumerate (currentKey, e, [self keyEnumerator])
    {
        if (NO == [keys containsObject: currentKey])
            [rval setObject: [self objectForKey: currentKey] forKey: currentKey];
    }
    return rval;
}

- (NSDictionary *) BXTranslateUsingKeys: (NSDictionary *) translationDict
{
    NSMutableDictionary* rval = [NSMutableDictionary dictionaryWithCapacity: 
        MIN ([self count], [translationDict count])];
    TSEnumerate (currentKey, e, [translationDict keyEnumerator])
    {
        id currentObject = [self objectForKey: currentKey];
        if (nil != currentObject)
            [rval setObject: currentObject forKey: [translationDict objectForKey: currentKey]];
    }
    return rval;
}
@end


@implementation NSExpression (BXDatabaseAdditions)
- (BXEntityDescription *) BXEntity
{
    return [[self BXProperty] entity];
}

- (BXPropertyDescription *) BXProperty
{
    BXPropertyDescription* rval = nil;
    if ([self expressionType] == NSConstantValueExpressionType)
    {
        id constantValue = [self constantValue];
        if ([constantValue isKindOfClass: [BXPropertyDescription class]])
            rval = constantValue;
    }
    return rval;
}
@end


@implementation NSComparisonPredicate (BXDatabaseAdditions)
- (NSArray *) BXEntities
{
    id lEnt = [[self  leftExpression] BXEntity];
    id rEnt = [[self rightExpression] BXEntity];
    NSNull* null = [NSNull null];
    return [NSArray arrayWithObjects: (lEnt ? lEnt : null), (rEnt ? rEnt : null), nil];
}

- (BOOL) BXEvaluateWithObject: (id) anObject
{
    BOOL rval = NO;
    id expressions [2] = {[self leftExpression], [self rightExpression]};
    BOOL createNew = NO;
    
    for (int i = 0; i < 2; i++)
    {
        if (NSConstantValueExpressionType == [expressions [i] expressionType])
        {
            id property = [expressions [i] constantValue];
            if ([property isKindOfClass: [BXPropertyDescription class]])
            {
                createNew = YES;
                expressions [i] = [NSExpression expressionForConstantValue: 
                    [anObject objectForKey: property]];
            }
        }
    }
    
    if (NO == createNew)
        rval = [self evaluateWithObject: anObject];
    else
    {
        //Custom selectors needn't be supported, since Postgres interface won't handle them anyway.
        NSPredicate* predicate = [NSComparisonPredicate predicateWithLeftExpression: expressions [0]
                                                                    rightExpression: expressions [1]
                                                                           modifier: [self comparisonPredicateModifier]
                                                                               type: [self predicateOperatorType]
                                                                            options: [self options]];
        rval = [predicate evaluateWithObject: anObject];
    }
    return rval;
}
@end


@implementation NSArray (BXDatabaseAdditions)
- (BOOL) BXContainsObjectsInArray: (NSArray *) anArray
{
    BOOL rval = YES;
    TSEnumerate (currentObject, e, [anArray objectEnumerator])
    {
        if (NO == [self containsObject: currentObject])
        {
            rval = NO;
            break;
        }
    }
    return rval;
}

- (NSArray *) BXFilteredArrayUsingPredicate: (NSPredicate *) predicate others: (NSMutableArray *) otherArray
{
    NSMutableArray* rval = [NSMutableArray arrayWithCapacity: [self count]];
    TSEnumerate (currentObject, e, [self objectEnumerator])
    {
        if ([predicate BXEvaluateWithObject: currentObject])
            [rval addObject: currentObject];
        else
            [otherArray addObject: currentObject];
    }
    return rval;
}
@end


@implementation NSSet (BXDatabaseAdditions)
- (NSPredicate *) BXOrPredicateForObjects
{
    NSPredicate* rval = nil;
    if (0 < [self count])
    {
        NSMutableArray* parts = [NSMutableArray arrayWithCapacity: [self count]];
        TSEnumerate (currentObject, e, [self objectEnumerator])
            [parts addObject: [[currentObject objectID] predicate]];
        rval = [NSCompoundPredicate orPredicateWithSubpredicates: parts];
    }
    return rval;
}
@end
