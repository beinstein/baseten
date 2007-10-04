//
// BXDatabaseAdditions.h
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
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

#undef TSEnumerate
#define TSEnumerate( LOOP_VAR, ENUMERATOR_VAR, ENUMERATION )  \
for (id ENUMERATOR_VAR = ENUMERATION, LOOP_VAR = [ENUMERATOR_VAR nextObject]; \
     nil != LOOP_VAR; LOOP_VAR = [ENUMERATOR_VAR nextObject])

#define BXLocalizedString( KEY, VALUE, COMMENT ) \
    ((void *) NSLocalizedStringWithDefaultValue( KEY, nil, [NSBundle bundleForClass:[BXDatabaseContext class]], VALUE, COMMENT ) ?: [NSNull null])

#define BXSafeObj( OBJECT )  ( (void *) OBJECT ?: [NSNull null] )

#define BXHandleError( ERROR, LOCAL_ERROR ) \
    if ( nil != LOCAL_ERROR && NULL != error ) { *(NSError **)ERROR = LOCAL_ERROR;  }

#define BXSafeCFRelease( CF_VAL ) ( NULL != CF_VAL ? CFRelease( CF_VAL ) : NULL )

@class BXDatabaseObjectID;
@class BXAttributeDescription;
@class BXEntityDescription;

enum BXModificationType;

@interface NSURL (BXDatabaseAdditions)
- (unsigned int) BXHash;
- (NSURL *) BXURIForHost: (NSString *) host 
				database: (NSString *) dbName 
				username: (NSString *) username 
				password: (id) password;
@end


@interface NSString (BXDatabaseAdditions)
+ (NSString *) BXURLEncodedData: (NSData *) data;
- (NSData *) BXURLDecodedData;
- (NSArray *) BXKeyPathComponentsWithQuote: (NSString *) quoteString;
@end


@interface NSData (BXDatabaseAdditions)
- (NSData *) BXURLEncodedData;
- (NSData *) BXURLDecodedData;
@end


@interface NSPredicate (BXDatabaseAdditions)
+ (NSPredicate *) BXAndPredicateWithProperties: (NSArray *) properties
							matchingProperties: (NSArray *) otherProperties
										  type: (NSPredicateOperatorType) type;
+ (NSPredicate *) BXOrPredicateWithProperties: (NSArray *) properties
                            matchingProperties: (NSArray *) otherProperites
                                          type: (NSPredicateOperatorType) type;
+ (NSArray *) BXSubpredicatesForProperties: (NSArray *) properties
						matchingProperties: (NSArray *) otherProperties
									  type: (NSPredicateOperatorType) type;
- (NSArray *) BXEntities;
- (NSSet *) BXEntitySet;
- (BOOL) BXEvaluateWithObject: (id) anObject;
@end


@interface NSCompoundPredicate (BXDatabaseAdditions)
- (NSSet *) BXEntitySet;
@end


@interface NSMutableSet (BXDatabaseAdditions)
- (id) BXConditionalAdd: (id) anObject;
@end


@interface NSError (BXDatabaseAdditions)
- (NSException *) BXExceptionWithName: (NSString *) aName;
@end


@interface NSDictionary (BXDatabaseAdditions)
- (NSDictionary *) BXSubDictionaryExcludingKeys: (NSArray *) keys;
- (NSDictionary *) BXTranslateUsingKeys: (NSDictionary *) translationDict;
@end


@interface NSExpression (BXDatabaseAdditions)
- (BXEntityDescription *) BXEntity;
- (BXAttributeDescription *) BXAttribute;
@end


@interface NSArray (BXDatabaseAdditions)
- (BOOL) BXContainsObjectsInArray: (NSArray *) anArray;
- (NSMutableArray *) BXFilteredArrayUsingPredicate: (NSPredicate *) predicate others: (NSMutableArray *) otherArray;
+ (NSArray *) BXNullArray: (unsigned int) count;
@end


@interface NSSet (BXDatabaseAdditions)
- (NSPredicate *) BXOrPredicateForObjects;
@end


@interface NSMutableDictionary (BXDatabaseAdditions)
- (void) BXSetModificationType: (enum BXModificationType) aType forKey: (BXDatabaseObjectID *) aKey;
- (enum BXModificationType) BXModificationTypeForKey: (BXDatabaseObjectID *) aKey;
@end