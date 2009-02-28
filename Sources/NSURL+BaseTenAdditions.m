//
// NSURL+BaseTenAdditions.m
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


#import "NSURL+BaseTenAdditions.h"
#import "BXURLEncoding.h"


@implementation NSURL (BaseTenAdditions)
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
	return [self BXURIForHost: host port: nil database: dbName username: username password: password];
}

- (NSURL *) BXURIForHost: (NSString *) host port: (NSNumber *) port database: (NSString *) dbName username: (NSString *) username password: (id) password
{
	//FIXME: shouldn't we allow empty scheme?
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
		
		if (! port)
			port = [self port];
		if (port && -1 != [port integerValue]) [URLString appendFormat: @":%@", port];
	
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
