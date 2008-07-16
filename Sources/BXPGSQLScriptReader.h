//
// BXPGSQLScriptReader.h
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
#import <stdio.h>

@class PGTSConnection;
@class PGTSResultSet;
@class BXPGSQLScanner;
@class BXPGSQLScriptReader;
@protocol BXPGSQLScannerDelegate;


@protocol BXPGSQLScriptReaderDelegate <NSObject>
- (void) SQLScriptReaderSucceeded: (BXPGSQLScriptReader *) reader userInfo: (id) userInfo;
- (void) SQLScriptReader: (BXPGSQLScriptReader *) reader failed: (PGTSResultSet *) res userInfo: (id) userInfo;
- (void) SQLScriptReader: (BXPGSQLScriptReader *) reader advancedToPosition: (off_t) position userInfo: (id) userInfo;
@end



#define BXPGSQLScannerBufferSize 1024

@interface BXPGSQLScriptReader : NSObject 
{
	char mBuffer [BXPGSQLScannerBufferSize];
	off_t mFileSize;

	FILE* mFile;
	PGTSConnection* mConnection;
	BXPGSQLScanner* mScanner;
	id <BXPGSQLScriptReaderDelegate> mDelegate;
	id mDelegateUserInfo;
	
	BOOL mCanceling;
	BOOL mIgnoresErrors;
}
- (void) setConnection: (PGTSConnection *) connection;
- (void) setDelegate: (id <BXPGSQLScriptReaderDelegate>) anObject;
- (void) setDelegateUserInfo: (id) anObject;
- (void) setIgnoresErrors: (BOOL) flag;

- (BOOL) openFileAtURL: (NSURL *) fileURL;
- (off_t) length;
- (void) readAndExecuteAsynchronously;
- (void) cancel;

- (void) setScanner: (BXPGSQLScanner *) scanner;
@end
