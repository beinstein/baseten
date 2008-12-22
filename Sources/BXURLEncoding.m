//
// BXURLEncoding.m
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

#import "BXURLEncoding.h"
#import "BXConstants.h"


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
@end
