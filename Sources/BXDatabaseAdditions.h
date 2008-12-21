//
// BXDatabaseAdditions.h
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


@class BXDatabaseObjectID;
@class BXAttributeDescription;
@class BXEntityDescription;
@class BXDatabaseContext;


#define BXLocalizedString( KEY, VALUE, COMMENT ) \
    ((id) NSLocalizedStringWithDefaultValue( KEY, nil, [NSBundle bundleForClass:[BXDatabaseContext class]], VALUE, COMMENT ) ?: [NSNull null])

#define BXSafeObj( OBJECT )  ( (void *) OBJECT ?: [NSNull null] )

#define BXSafeCFRelease( CF_VAL ) ( NULL != CF_VAL ? CFRelease( CF_VAL ) : NULL )

#import <BaseTen/BXConstants.h>


@interface NSURL (BXDatabaseAdditions)
- (unsigned int) BXHash;
- (NSURL *) BXURIForHost: (NSString *) host 
				database: (NSString *) dbName 
				username: (NSString *) username 
				password: (id) password;
@end


@interface NSString (BXDatabaseAdditions)
+ (NSString *) BXURLEncodedData: (id) data;
+ (NSString *) BXURLDecodedData: (id) data;
- (NSData *) BXURLDecodedData;
- (NSData *) BXURLEncodedData;
- (NSString *) BXURLEncodedString;
- (NSString *) BXURLDecodedString;
- (NSString *) BXAttributeName;
@end


@interface NSData (BXDatabaseAdditions)
- (NSData *) BXURLEncodedData;
- (NSData *) BXURLDecodedData;
@end


@interface NSPredicate (BXDatabaseAdditions)
- (BOOL) BXEvaluateWithObject: (id) anObject substitutionVariables: (NSMutableDictionary *) dictionary;
@end


@interface NSError (BXDatabaseAdditions)
- (NSException *) BXExceptionWithName: (NSString *) aName;
@end


@interface NSArray (BXDatabaseAdditions)
- (NSMutableArray *) BXFilteredArrayUsingPredicate: (NSPredicate *) predicate 
											others: (NSMutableArray *) otherArray
							 substitutionVariables: (NSMutableDictionary *) variables;
@end


@interface NSObject (BXDatabaseAdditions)
- (BOOL) BXIsRelationshipProxy;
@end


@interface NSProxy (BXDatabaeAdditions)
- (BOOL) BXIsRelationshipProxy;
@end