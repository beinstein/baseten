//
// BXAPGInterface.m
// BaseTen Assistant
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

#import "BXAPGInterface.h"
#import "BXAController.h"
#import <BaseTen/PGTSQuery.h>


#ifdef BXA_ENABLE_TRACE
static void
LogSocketCallback (CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
	NSString* logString = [[NSString alloc] initWithData: (NSData *) data encoding: NSUTF8StringEncoding];
	[(id) info logAppend: logString];
}
#endif



@implementation BXAPGInterface

@synthesize controller = mController;


#ifdef BXA_ENABLE_TRACE
- (FILE *) traceFile
{
	return NULL;
}


//FIXME: move this inside a method.
{
	int socketVector [2] = {};
	socketpair (AF_UNIX, SOCK_STREAM, 0, socketVector);
	CFSocketContext ctx = {0, mController, NULL, NULL, NULL};
	
	mTraceInput = fdopen (socketVector [0], "w");		
	mTraceOutput = CFSocketCreateWithNative (NULL, socketVector [1], kCFSocketDataCallBack, &LogSocketCallback, &ctx);
	mTraceSource = CFSocketCreateRunLoopSource (NULL, mTraceOutput, -1);
	CFRunLoopAddSource (CFRunLoopGetCurrent (), mTraceSource, kCFRunLoopCommonModes);
	
	[(BXPGInterface *) [mContext databaseInterface] setTraceFile: mTraceInput];
}
#endif


- (void) connection: (PGTSConnection *) connection sentQueryString: (const char *) queryString
{
	[mController logAppend: [NSString stringWithCString: queryString encoding: NSUTF8StringEncoding]];
	[mController logAppend: @"\n"];
}

- (void) connection: (PGTSConnection *) connection sentQuery: (PGTSQuery *) query
{
	[mController logAppend: [query query]];
	[mController logAppend: @"\n"];
}

- (void) connection: (PGTSConnection *) connection receivedResultSet: (PGTSResultSet *) res
{
}

- (BOOL) logsQueries
{
	return YES;
}
@end
