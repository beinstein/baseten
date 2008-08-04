//
// PGTSAdditions.m
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

#import <stdlib.h>
#import <limits.h>
#import <BaseTen/postgresql/libpq-fe.h>
#import "PGTSAdditions.h"
#import "PGTSConnection.h"
#import "PGTSConstants.h"
#import "PGTSTypeDescription.h"
#import "PGTSConnectionPrivate.h"
#import "PGTSFoundationObjects.h"
#import "BXLogger.h"


@implementation NSString (PGTSAdditions)
+ (NSString *) PGTSFieldAliases: (unsigned int) count
{
    return [self PGTSFieldAliases: count start: 1];
}

+ (NSString *) PGTSFieldAliases: (unsigned int) count start: (unsigned int) start
{
    NSString* rval = nil;
    if (0 >= count)
        rval = @"";
    else
    {
        rval = [NSMutableString stringWithCapacity: 3 * (count % 10) + 4 * ((count / 10) % 10)];
        for (unsigned int i = start; i <= count; i++)
            [(NSMutableString *) rval appendFormat: @"$%u,", i];
        [(NSMutableString *) rval deleteCharactersInRange: NSMakeRange ([rval length] - 1, 1)];
    }
    return rval;
}

/**
 * Escape the string for the SQL interpreter.
 */
- (NSString *) PGTSEscapedString: (PGTSConnection *) connection
{
    const char* from = [self UTF8String];
    size_t length = strlen (from);
    char* to = (char *) calloc (1 + 2 * length, sizeof (char));
    PQescapeStringConn ([connection pgConnection], to, from, length, NULL);
    NSString* rval = [NSString stringWithUTF8String: to];
    free (to);
    return rval;
}

/**
 * The number of parameters in a string.
 * Parameters are marked as follows: $n. The number of parameters is equal to the highest value of n.
 */
- (int) PGTSParameterCount
{
    NSScanner* scanner = [NSScanner scannerWithString: self];
    int paramCount = 0;
    while (NO == [scanner isAtEnd])
    {
        int foundCount = 0;
        [scanner scanUpToString: @"$" intoString: NULL];
        [scanner scanString: @"$" intoString: NULL];
        //The largest found number specifies the number of parameters
        if ([scanner scanInt: &foundCount])
            paramCount = MAX (foundCount, paramCount);
    }
    return paramCount;
}
@end


@implementation NSObject (PGTSAdditions)
- (NSString *) PGTSEscapedName: (PGTSConnection *) connection
{
	NSString* name = [[self description] PGTSEscapedString: connection];
	return [NSString stringWithFormat: @"\"%@\"", name];
}

- (NSString *) PGTSEscapedObjectParameter: (PGTSConnection *) connection
{
	NSString* retval = nil;
	int length = 0;
	char* charParameter = [self PGTSParameterLength: &length connection: connection];
	if (NULL != charParameter)
	{
		PGconn* pgConn = [connection pgConnection];
		char* escapedParameter = (char *) calloc (1 + 2 * length, sizeof (char));
		PQescapeStringConn (pgConn, escapedParameter, charParameter, length, NULL);
		const char* clientEncoding = PQparameterStatus (pgConn, "client_encoding");
		BXAssertValueReturn (0 == strcmp ("UNICODE", clientEncoding), nil,
							 @"Expected client_encoding to be UNICODE (was: %s).", clientEncoding);
		retval = [[[NSString alloc] initWithBytesNoCopy: escapedParameter length: strlen (escapedParameter)
											   encoding: NSUTF8StringEncoding freeWhenDone: YES] autorelease];
	}
	return retval;
}
@end


@implementation NSDictionary (PGTSAdditions)
- (NSString *) PGTSConnectionString
{
	NSMutableString* connectionString = [NSMutableString string];
	NSEnumerator* e = [self keyEnumerator];
	NSString* currentKey;
	NSString* format = @"%@ = '%@' ";
	while ((currentKey = [e nextObject]))
	{
        if ([kPGTSConnectionDictionaryKeys containsObject: currentKey])
            [connectionString appendFormat: format, currentKey, [self objectForKey: currentKey]];
	}
	return connectionString;
}	
@end


@implementation NSNumber (PGTSAdditions)
/**
 * Return the value as Oid.
 * \sa PGTSOidAsObject
 */
- (Oid) PGTSOidValue
{
    return [self unsignedIntValue];
}

- (id) PGTSConstantExpressionValue: (NSDictionary *) context
{
	id retval = self;
	if (0 == strcmp ("c", [self objCType]))
		retval = ([self boolValue] ? @"true" : @"false");
    return retval;
}
@end


@implementation PGTSAbstractClass
- (id) init
{
    NSString* reason = [NSString stringWithFormat: @"%@ is an abstract class", [self class]];
    [[NSException exceptionWithName: NSGenericException 
                             reason: reason
                           userInfo: nil] raise];
    return nil;
}
@end


@implementation PGTSFloat
@end


@implementation PGTSFloat (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    return [NSNumber numberWithFloat: strtof (value, NULL)];
}
@end


@implementation PGTSDouble
@end


@implementation PGTSDouble (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    return [NSNumber numberWithDouble: strtod (value, NULL)];
}
@end


@implementation PGTSBool
@end


@implementation PGTSBool (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    BOOL boolValue = (value [0] == 't' ? YES : NO);
    return [NSNumber numberWithBool: boolValue];
}
@end


@implementation PGTSPoint
@end


@implementation PGTSPoint (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    NSPoint retval = NSZeroPoint;
    NSString* pointString = [NSString stringWithUTF8String: value];
    NSScanner* pointScanner = [NSScanner scannerWithString: pointString];
    [pointScanner setScanLocation: 1];
	
#if CGFLOAT_IS_DOUBLE
    [pointScanner scanDouble: &(retval.x)];
#else
    [pointScanner scanFloat: &(retval.x)];
#endif
	
    [pointScanner setScanLocation: [pointScanner scanLocation] + 1];
	
#if CGFLOAT_IS_DOUBLE
    [pointScanner scanDouble: &(retval.y)];
#else
    [pointScanner scanFloat: &(retval.y)];
#endif
	
    return [NSValue valueWithPoint: retval];
}
@end


@implementation PGTSSize
@end


@implementation PGTSSize (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    NSPoint p = NSZeroPoint;
    [[PGTSPoint newForPGTSResultSet: set withCharacters: value type: typeInfo] getValue: &p];
    NSSize s;
    s.width = p.x;
    s.height = p.y;
    return [NSValue valueWithSize: s];
}
@end


#if 0
@implementation NSURL (PGTSAdditions)
#define SetIf( VALUE, KEY ) if ((VALUE)) [connectionDict setObject: VALUE forKey: KEY];
- (NSMutableDictionary *) PGTSConnectionDictionary
{
	NSMutableDictionary* connectionDict = nil;
	if (0 == [@"pgsql" caseInsensitiveCompare: [self scheme]])
	{
		connectionDict = [NSMutableDictionary dictionary];    
		
		NSString* relativePath = [self relativePath];
		if (1 <= [relativePath length])
			SetIf ([relativePath substringFromIndex: 1], kPGTSDatabaseNameKey);
		
		SetIf ([self host], kPGTSHostKey);
		SetIf ([self user], kPGTSUserNameKey);
		SetIf ([self password], kPGTSPasswordKey);
		SetIf ([self port], kPGTSPortKey);
	}
	return connectionDict;
}
@end
#endif


@implementation NSMutableData (PGTSPrivateAdditions)
- (void) PGTSAppendCString: (const char *) string
{
    [self appendBytes: string length: strlen (string)];
}
@end
