//
// BXPGSQLScanner.h
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

#import <Foundation/Foundation.h>

#ifndef PSQLSCAN_H
typedef void* PsqlScanState;
#endif

#ifndef PQEXPBUFFER_H
typedef void* PQExpBuffer;
#endif


@class BXPGSQLScanner;

@protocol BXPGSQLScannerDelegate <NSObject>
- (const char *) nextLineForScanner: (BXPGSQLScanner *) scanner;
- (void) scanner: (BXPGSQLScanner *) scanner scannedQuery: (NSString *) query complete: (BOOL) isComplete;
- (void) scanner: (BXPGSQLScanner *) scanner scannedCommand: (NSString *) command options: (NSString *) options;
@end


@interface BXPGSQLScanner : NSObject 
{
	PsqlScanState mScanState;
    PQExpBuffer mQueryBuffer;
	const char* mCurrentLine;
	id <BXPGSQLScannerDelegate> mDelegate;
	BOOL mShouldStartScanning;
}
- (void) setDelegate: (id <BXPGSQLScannerDelegate>) anObject;
- (void) continueScanning;
@end
