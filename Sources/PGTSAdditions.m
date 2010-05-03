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
#import <BaseTen/libpq-fe.h>
#import "PGTSAdditions.h"
#import "PGTSConnection.h"
#import "PGTSConstants.h"
#import "PGTSTypeDescription.h"
#import "PGTSConnectionPrivate.h"
#import "PGTSFoundationObjects.h"
#import "NSString+PGTSAdditions.h"
#import "BXLogger.h"


@implementation NSObject (PGTSAdditions)
- (NSString *) PGTSEscapedName: (PGTSConnection *) connection
{
	NSString* name = [[self description] escapeForPGTSConnection: connection];
	return [NSString stringWithFormat: @"\"%@\"", name];
}

- (NSString *) PGTSEscapedObjectParameter: (PGTSConnection *) connection
{
	NSString* retval = nil;
	size_t length = 0;
	const char* charParameter = [[self PGTSParameter: connection] PGTSParameterLength: &length connection: connection];
	if (charParameter)
	{
		PGconn* pgConn = [connection pgConnection];
		char* escapedParameter = (char *) calloc (1 + 2 * length, sizeof (char));
		PQescapeStringConn (pgConn, escapedParameter, charParameter, length, NULL);
		const char* clientEncoding = PQparameterStatus (pgConn, "client_encoding");
		BXAssertValueReturn (clientEncoding && 0 == strcmp ("UNICODE", clientEncoding), nil,
							 @"Expected client_encoding to be UNICODE (was: %s).", clientEncoding);
		retval = [[[NSString alloc] initWithBytesNoCopy: escapedParameter length: strlen (escapedParameter)
											   encoding: NSUTF8StringEncoding freeWhenDone: YES] autorelease];
	}
	return retval;
}
@end


@implementation NSNumber (PGTSAdditions)
- (id) PGTSConstantExpressionValue: (NSDictionary *) context
{
	id retval = self;
	if (0 == strcmp ("c", [self objCType]))
		retval = ([self boolValue] ? @"true" : @"false");
    return retval;
}
@end
