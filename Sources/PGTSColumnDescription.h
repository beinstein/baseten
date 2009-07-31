//
// PGTSColumnDescription.h
// BaseTen
//
// Copyright (C) 2006-2009 Marko Karppinen & Co. LLC.
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

#import <Foundation/Foundation.h>
#import <BaseTen/postgresql/libpq-fe.h>
#import "PGTSAbstractDescription.h"


@class PGTSTypeDescription;
@class PGTSConnection;


@interface PGTSColumnDescription : PGTSAbstractDescription
{
    NSInteger mIndex;
	NSString* mDefaultValue;
    PGTSTypeDescription* mType;
	BOOL mIsNotNull;
	BOOL mIsInherited;
}

- (NSString *) quotedName: (PGTSConnection *) connection;
- (NSComparisonResult) indexCompare: (PGTSColumnDescription *) aField;
- (PGTSTypeDescription *) type;

- (NSInteger) index;
- (PGTSTypeDescription *) type;
- (NSString *) defaultValue;
- (BOOL) isNotNull;
- (BOOL) isInherited;

//Thread un-safe methods.
- (void) setIndex: (NSInteger) anIndex;
- (void) setType: (PGTSTypeDescription *) anOid;
- (void) setDefaultValue: (NSString *) defaultExpression;
- (void) setNotNull: (BOOL) aBool;
- (void) setInherited: (BOOL) aBool;

//Stubs for sub classes' methods.
- (BOOL) requiresDocuments;
- (void) setRequiresDocuments: (BOOL) aBool;

@end


@interface PGTSXMLColumnDescription : PGTSColumnDescription
{
	BOOL mRequiresDocuments;
}
- (BOOL) requiresDocuments;
//Thread un-safe methods.
- (void) setRequiresDocuments: (BOOL) aBool;
@end
