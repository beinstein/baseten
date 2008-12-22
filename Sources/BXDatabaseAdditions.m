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
#import "BXURLEncoding.h"


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
