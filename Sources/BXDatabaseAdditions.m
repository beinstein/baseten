//
// BXDatabaseAdditions.m
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

#import "BXConstants.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseObjectPrivate.h"
#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXDatabaseContext.h"
#import "BXException.h"
#import "BXDatabaseObject.h"
#import "BXAttributeDescription.h"
#import "BXLogger.h"
#import "BXEnumerate.h"


@interface NSPredicate (BXAdditions)
- (BOOL) evaluateWithObject: (id) anObject variableBindings: (id) bindings;
@end


@implementation NSURL (BXDatabaseAdditions)

- (unsigned int) BXHash
{
    unsigned int u = 0;
	u = [[self scheme] hash];
	u ^= [[self host] hash];
	u ^= [[self port] hash];
	u ^= [[self path] hash];
	u ^= [[self query] hash];
    return u;
}

- (NSURL *) BXURIForHost: (NSString *) host database: (NSString *) dbName username: (NSString *) username password: (id) password
{
	NSString* scheme = [self scheme];
	NSURL* retval = nil;
	
	if (nil != scheme)
	{
		NSMutableString* URLString = [NSMutableString string];
		[URLString appendFormat: @"%@://", scheme];

		if (nil == username) username = [self user];
		
		if (nil == password) password = [self password];
		else if ([NSNull null] == password) password = nil;
		
		if (nil != password && 0 < [password length])
			[URLString appendFormat: @"%@:%@@", [username BXURLEncodedString] ?: @"", [password BXURLEncodedString]];
		else if (nil != username && 0 < [username length])
			[URLString appendFormat: @"%@@", [username BXURLEncodedString]];
	
		if (! host) 
			host = [self host];
		
		if (host)
		{
			if (NSNotFound != [host rangeOfString: @":"].location)
			{
				//IPv6
				[URLString appendString: @"["];
				[URLString appendString: host];
				[URLString appendString: @"]"];
			}
			else
			{
				[URLString appendString: host];
			}
		}
		
		NSNumber* port = [self port];
		if (port) [URLString appendFormat: @":%@", port];
	
		if (nil != dbName)
            dbName = [dbName BXURLEncodedString];
        else
            dbName = [[self path] substringFromIndex: 1];
        
        if (nil != dbName) [URLString appendFormat: @"/%@", dbName];
		retval = [NSURL URLWithString: URLString];
	}
	return retval;
}

@end


static NSData*
URLEncode (const char* bytes, size_t length)
{
    NSMutableData* retval = [NSMutableData data];
    char hex [4] = "\0\0\0\0";
    for (unsigned int i = 0; i < length; i++)
    {
        char c = bytes [i];
        if (('0' <= c && c <= '9') || ('A' <= c && c <= 'Z') || ('a' <= c && c <= 'z') || 
            '-' == c || '_' == c || '.' == c || '~' == c)
            [retval appendBytes: &c length: sizeof (char)];
        else
        {
            snprintf (hex, 4, "%%%02hhx", c);
            [retval appendBytes: hex length: 3 * sizeof (char)];
        }
    }
    return retval;
}

static NSData* 
URLDecode (const char* bytes, size_t length, id sender)
{
    NSMutableData* retval = [NSMutableData data];
    char hex [3] = "\0\0\0";
    for (unsigned int i = 0; i < length; i++)
    {
        char c = bytes [i];
        if ('%' != c)
            [retval appendBytes: &c length: sizeof (char)];
        else
        {
            if (length < i + 3)
            {
                @throw [NSException exceptionWithName: NSRangeException reason: nil 
                                             userInfo: [NSDictionary dictionaryWithObject: sender forKey: kBXObjectKey]];
            }
            i++;
            strlcpy ((char *) &hex, &bytes [i], 3);
            char c = (char) strtol ((char *) &hex, NULL, 16);
            [retval appendBytes: &c length: sizeof (char)];
            i++;
        }
    }
    return retval;
}


@implementation NSData (BXDatabaseAdditions)
- (NSData *) BXURLDecodedData;
{
    return URLDecode ((char *) [self bytes], [self length], self);
}

- (NSData *) BXURLEncodedData
{
    return URLEncode ((char *) [self bytes], [self length]);
}
@end


@implementation NSString (BXDatabaseAdditions)

+ (NSString *) BXURLEncodedData: (id) data
{
    return [[[self alloc] initWithData: [data BXURLEncodedData] 
                              encoding: NSASCIIStringEncoding] autorelease];
}

+ (NSString *) BXURLDecodedData: (id) data
{
    return [[[self alloc] initWithData: [data BXURLDecodedData]
                              encoding: NSUTF8StringEncoding] autorelease];
}

- (NSData *) BXURLDecodedData
{
    return [[self dataUsingEncoding: NSASCIIStringEncoding] BXURLDecodedData];
}

- (NSData *) BXURLEncodedData
{
    const char* UTF8String = [self UTF8String];
    size_t length = strlen (UTF8String);
    return URLEncode (UTF8String, length);
}

- (NSString *) BXURLEncodedString
{
    return [NSString BXURLEncodedData: self];
}

- (NSString *) BXURLDecodedString
{
    return [NSString BXURLDecodedData: self];
}

- (NSString *) BXAttributeName
{
	return self;
}
@end


@implementation NSPredicate (BXDatabaseAdditions)
- (BOOL) BXEvaluateWithObject: (id) object substitutionVariables: (NSMutableDictionary *) ctx
{
	//10.5 and 10.4 have the same method but it's named differently.
	BOOL retval = NO;
	if ([self respondsToSelector: @selector (evaluateWithObject:substitutionVariables:)])
		retval = [self evaluateWithObject: object substitutionVariables: ctx];
	else
		retval = [self evaluateWithObject: object variableBindings: ctx];
	
	return retval;
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


@implementation NSArray (BXDatabaseAdditions)
- (NSMutableArray *) BXFilteredArrayUsingPredicate: (NSPredicate *) predicate 
											others: (NSMutableArray *) otherArray
							 substitutionVariables: (NSMutableDictionary *) variables
{
    NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [self count]];
    BXEnumerate (currentObject, e, [self objectEnumerator])
    {
		if ([predicate BXEvaluateWithObject: currentObject substitutionVariables: [[variables mutableCopy] autorelease]])
            [retval addObject: currentObject];
        else
            [otherArray addObject: currentObject];
    }
    return retval;
}
@end


@implementation NSObject (BXDatabaseAdditions)
- (BOOL) BXIsRelationshipProxy
{
	return NO;
}
@end


@implementation NSProxy (BXDatabaeAdditions)
- (BOOL) BXIsRelationshipProxy
{
	return NO;
}
@end
