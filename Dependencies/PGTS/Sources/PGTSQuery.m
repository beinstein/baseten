//
// PGTSQuery.m
// BaseTen
//
// Copyright (C) 2008 Marko Karppinen & Co. LLC.
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

#import "PGTSQuery.h"
#import "PGTSFoundationObjects.h"
#import "PGTSConnection.h"
#import "PGTSConnectionPrivate.h"
#import "PGTSProbes.h"


@implementation PGTSQuery

- (int) sendQuery: (PGTSConnection *) connection
{
	return 0;
}

@end


@implementation PGTSAbstractParameterQuery
- (NSArray *) parameters
{
	return mParameters;
}

- (void) setParameters: (NSArray *) anArray
{
	if (mParameters != anArray)
	{
		[mParameters release];
		mParameters = [anArray retain];
	}
}

- (int) parameterCount
{
	return [mParameters count];
}
@end


@implementation PGTSParameterQuery

- (NSString *) query
{
	return mQuery;
}

- (void) setQuery: (NSString *) aString
{
	if (mQuery != aString)
	{
		[mQuery release];
		mQuery = [aString copy];
	}
}

- (int) sendQuery: (PGTSConnection *) connection
{    
    int retval = 0;
	int nParams = [self parameterCount];
    const char** paramValues  = calloc (nParams, sizeof (char *));
    Oid*   paramTypes   = calloc (nParams, sizeof (Oid));
    int*   paramLengths = calloc (nParams, sizeof (int));
    int*   paramFormats = calloc (nParams, sizeof (int));

    for (int i = 0; i < nParams; i++)
    {
        id parameter = [mParameters objectAtIndex: i];
        int length = 0;
        const char* value = [parameter PGTSParameterLength: &length connection: connection];

        paramTypes   [i] = InvalidOid;
        paramValues  [i] = value;
        paramLengths [i] = length;
        paramFormats [i] = [parameter PGTSIsBinaryParameter];
    }

    retval = PQsendQueryParams ([connection pgConnection], [mQuery UTF8String], nParams, paramTypes,
                            	paramValues, paramLengths, paramFormats, 0);
	
    NSLog (@"sendquery: %@ %@", mQuery, mParameters);
	if (PGTS_SEND_QUERY_ENABLED ())
	{
		char* query_s = strdup ([mQuery UTF8String] ?: "");
		char* params_s = strdup ([[mParameters description] UTF8String] ?: "");
		PGTS_SEND_QUERY (self, retval, query_s, params_s);
		free (query_s);
		free (params_s);
	}

    free (paramTypes);
    free (paramValues);
    free (paramLengths);
    free (paramFormats);

    return retval;
}

@end
