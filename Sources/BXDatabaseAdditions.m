//
// BXDatabaseAdditions.m
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
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
#import "BXDatabaseObjectPrivate.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXConstants.h"
#import "BXDatabaseContext.h"
#import "BXException.h"
#import "BXDatabaseObject.h"
#import "BXAttributeDescription.h"

#import <Log4Cocoa/Log4Cocoa.h>


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
	const size_t hexlength = 3;
    char* hex = malloc (hexlength * sizeof (char));
    for (int i = 0; i < length; i++)
    {
        unsigned char c = bytes [i];
        if (('0' <= c && c <= '9') || ('A' <= c && c <= 'Z') || ('a' <= c && c <= 'z') || 
            '-' == c || '_' == c || '.' == c || '~' == c)
            [rval appendBytes: &c length: sizeof (char)];
        else
        {
            snprintf (hex, hexlength, "%%%02x", c);
            [rval appendBytes: hex length: hexlength * sizeof (char)];
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

- (NSString *) BXAttributeName
{
	return self;
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
	log4AssertValueReturn (count == [otherProperties count], nil, @"Expected given arrays' counts to match.");
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
    return [[self BXAttribute] entity];
}

- (BXAttributeDescription *) BXAttribute
{
    BXAttributeDescription* rval = nil;
    if ([self expressionType] == NSConstantValueExpressionType)
    {
        id constantValue = [self constantValue];
        if ([constantValue isKindOfClass: [BXAttributeDescription class]])
            rval = constantValue;
    }
    return rval;
}
@end


@implementation NSComparisonPredicate (BXDatabaseAdditions)
- (NSMutableSet *) BXEntitySet
{
	return [NSMutableSet setWithArray: [self BXEntities]];
}

- (NSArray *) BXEntities
{
    id lEnt = [[self  leftExpression] BXEntity];
    id rEnt = [[self rightExpression] BXEntity];
	id rval = nil;
	if (nil == lEnt && nil == rEnt)
		rval = nil;
	else if (nil == lEnt)
		rval = [NSArray arrayWithObject: rEnt];
	else if (nil == rEnt)
		rval = [NSArray arrayWithObject: lEnt];
	else
		rval = [NSArray arrayWithObjects: lEnt, rEnt, nil];
	
	return rval;
}

- (BOOL) BXEvaluateWithObject: (id) anObject
{
    BOOL retval = NO;
    id expressions [2] = {[self leftExpression], [self rightExpression]};
    BOOL createNew = NO;
    NSDictionary* values = nil;
	
	//FIXME: reconsider this in the future.
    for (int i = 0; i < 2; i++)
    {
        if (NSConstantValueExpressionType == [expressions [i] expressionType])
        {
            id attribute = [expressions [i] constantValue];
            if ([attribute isKindOfClass: [BXAttributeDescription class]])
            {
                createNew = YES;
				
				//Stupid optimizations for objectIDs and database objects.
				//In case we have an object id or only need a fault, get the value dict.
				if (nil == values)
					values = [(BXDatabaseObject *) anObject allValues];
				NSString* name = [attribute name];
				id value = [values objectForKey: name];
				if (nil == value)
					value = [anObject primitiveValueForKey: name];
					
                expressions [i] = [NSExpression expressionForConstantValue: value];
            }
        }
    }
    
    if (NO == createNew)
        retval = [self evaluateWithObject: anObject];
    else
    {
        //Custom selectors needn't be supported, since Postgres interface won't handle them anyway.
        NSPredicate* predicate = [NSComparisonPredicate predicateWithLeftExpression: expressions [0]
                                                                    rightExpression: expressions [1]
                                                                           modifier: [self comparisonPredicateModifier]
                                                                               type: [self predicateOperatorType]
                                                                            options: [self options]];
        retval = [predicate evaluateWithObject: anObject];
    }
    return retval;
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

- (NSMutableArray *) BXFilteredArrayUsingPredicate: (NSPredicate *) predicate others: (NSMutableArray *) otherArray
{
    NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [self count]];
    TSEnumerate (currentObject, e, [self objectEnumerator])
    {
        if ([predicate BXEvaluateWithObject: currentObject])
            [retval addObject: currentObject];
        else
            [otherArray addObject: currentObject];
    }
    return retval;
}

+ (NSArray *) BXNullArray: (unsigned int) count
{
	id* buffer = alloca (count * sizeof (id));
	for (unsigned int i = 0; i < count; i++)
		buffer [i] = [NSNull null];
	
	NSArray* rval = [NSArray arrayWithObjects: buffer count: count];
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


@implementation NSMutableDictionary (BXDatabaseAdditions)
- (void) BXSetModificationType: (enum BXModificationType) aType forKey: (BXDatabaseObjectID *) aKey
{
    CFDictionarySetValue ((CFMutableDictionaryRef) self, aKey, &aType);
}

- (enum BXModificationType) BXModificationTypeForKey: (BXDatabaseObjectID *) aKey
{
    enum BXModificationType retval = (enum BXModificationType)
        CFDictionaryGetValue ((CFDictionaryRef) self, aKey);
    return retval;
}
@end