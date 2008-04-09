//
// PGTSQueryDescription.m
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

@implementation PGTSQueryDescription

- (PGTSQuery *) query
{
	return nil;
}

- (void) setQuery: (PGTSQuery *) aQuery
{
}

- (unsigned long) identifier
{
	return 0;
}

- (void) setIdentifier: (unsigned long) anIdentifier
{
}

- (BOOL) sent
{
	return NO;
}

- (BOOL) finished
{
	return YES;
}

- (void) connectionSentQuery: (PGTSConnection *) connection
{
}

- (void) connection: (PGTSConnection *) connection receivedResultSet: (PGTSResultSet *) result
{
}

- (void) connectionFinishedQuery: (PGTSConnection *) connection
{
}

@end


@implementation PGTSConcreteQueryDescription

- (PGTSQuery *) query
{
	return mQuery;
}

- (void) setQuery: (PGTSQuery *) aQuery
{
	if (mQuery != aQuery)
	{
		[mQuery release];
		mQuery = [aQuery retain];
	}
}

- (unsigned long) identifier
{
	return mIdentifier;
}

- (void) setIdentifier: (unsigned long) anIdentifier
{
	mIdentifier = anIdentifier;
}

- (BOOL) sent
{
	return mSent;
}

- (BOOL) finished
{
	return mFinished;
}

- (void) connectionSentQuery: (PGTSConnection *) connection
{
	mSent = YES;
}

- (void) connection: (PGTSConnection *) connection receivedResultSet: (PGTSResultSet *) result
{
	[result setIdentifier: mIdentifier];
	[mTarget performSelector: mCallback withObject: result];
}

- (void) connectionFinishedQuery: (PGTSConnection *) connection
{
	mFinished = YES;
}

@end
