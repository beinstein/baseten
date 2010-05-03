//
// NSString+PGTSAdditions.m
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

#import <stdlib.h>
#import <limits.h>
#import <BaseTen/libpq-fe.h>
#import "NSString+PGTSAdditions.h"
#import "PGTSConnection.h"


char *
PGTSCopyEscapedString (PGTSConnection *conn, const char *from)
{
	size_t length = strlen (from);
    char* to = (char *) calloc (1 + 2 * length, sizeof (char));
    PQescapeStringConn ([conn pgConnection], to, from, length, NULL);
	return to;
}


NSString* 
PGTSReformatErrorMessage (NSString* message)
{
	NSMutableString* result = [NSMutableString string];
	NSCharacterSet* skipSet = [NSCharacterSet characterSetWithCharactersInString: @"\t"];
	NSCharacterSet* newlineSet = [NSCharacterSet characterSetWithCharactersInString: @"\n"];
	NSInteger i = 0;
	NSScanner* scanner = [NSScanner scannerWithString: message];
	[scanner setCharactersToBeSkipped: skipSet];
	
	while (1)
	{
		NSString* part = nil;
		if ([scanner scanUpToCharactersFromSet: newlineSet intoString: &part])
		{
			[scanner scanCharactersFromSet: newlineSet intoString: NULL];
			[result appendString: part];
			if (! i)
				[result appendString: @"."];
			
			i++;
		}
		
		if ([scanner isAtEnd])
			break;
		else
			[result appendString: @" "];
	}
	
	if (0 < [result length])
	{
		NSString* begin = [result substringToIndex: 1];
		begin = [begin uppercaseString];
		[result replaceCharactersInRange: NSMakeRange (0, 1) withString: begin];
	}
	
	return [[result copy] autorelease];
}


@implementation NSString (PGTSAdditions)
/**
 * \internal
 * \brief Escape the string for the SQL interpreter.
 */
- (NSString *) escapeForPGTSConnection: (PGTSConnection *) connection
{
    const char *from = [self UTF8String];
	char *to = PGTSCopyEscapedString (connection, from);
    NSString* retval = [NSString stringWithUTF8String: to];
    free (to);
    return retval;
}

- (NSString *) quotedIdentifierForPGTSConnection: (PGTSConnection *) connection
{
	return [NSString stringWithFormat: @"\"%@\"", [self escapeForPGTSConnection: connection]];
}
@end
