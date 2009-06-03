//
// BXPGInterface.h
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
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXInterface.h>
#import <BaseTen/PGTSQuery.h>


@class BXPGTransactionHandler;
@class BXPGNotificationHandler;
@class BXPGDatabaseDescription;
@class BXPGQueryBuilder;
@class PGTSConnection;
@class BXPGTableDescription;
@class PGTSColumnDescription;
@class PGTSQuery;
@class PGTSResultSet;


BX_EXPORT NSString* BXPGReturnList (NSArray* attrs, NSString* alias, BOOL prependAlias);


@interface BXPGVersion : NSObject
{
}
+ (NSNumber *) currentVersionNumber;
+ (NSNumber *) currentCompatibilityVersionNumber;
@end



@interface BXPGInterface : NSObject <BXInterface> 
{
    BXDatabaseContext* mContext; //Weak
	BXPGTransactionHandler* mTransactionHandler;
	BXPGQueryBuilder* mQueryBuilder;
	
	//FIXME: this is a bit of a hack.
	BXEntityDescription* mCurrentlyChangedEntity;
	
	NSMutableSet* mLockedObjects;
	BOOL mLocking;
}

- (BXEntityDescription *) currentlyChangedEntity;
- (void) setCurrentlyChangedEntity: (BXEntityDescription *) entity;

- (BXPGTableDescription *) tableForEntity: (BXEntityDescription *) entity;
- (BXPGTableDescription *) tableForEntity: (BXEntityDescription *) entity 
							   inDatabase: (BXPGDatabaseDescription *) database;

- (BXDatabaseContext *) databaseContext;
- (void) setTransactionHandler: (BXPGTransactionHandler *) handler;
- (NSArray *) executeFetchForEntity: (BXEntityDescription *) entity withPredicate: (NSPredicate *) predicate 
					returningFaults: (BOOL) returnFaults class: (Class) aClass forUpdate: (BOOL) forUpdate error: (NSError **) error;
- (NSArray *) observedOids;
- (NSString *) insertQuery: (BXEntityDescription *) entity fieldValues: (NSDictionary *) fieldValues error: (NSError **) error;

- (NSString *) viewDefaultValue: (BXAttributeDescription *) attr error: (NSError **) error;
- (NSString *) recursiveDefaultValue: (NSString *) name entity: (BXEntityDescription *) entity error: (NSError **) error;

- (void) prepareForConnecting;
- (BXPGTransactionHandler *) transactionHandler;

//Some of the methods needed by BaseTen Assistant.
- (BOOL) process: (BOOL) shouldAdd primaryKeyFields: (NSArray *) attributeArray error: (NSError **) outError;
- (BOOL) process: (BOOL) shouldEnable entities: (NSArray *) entityArray error: (NSError **) outError;
- (BOOL) removePrimaryKeyForEntity: (BXEntityDescription *) viewEntity error: (NSError **) outError;

- (BOOL) hasBaseTenSchema;
- (NSNumber *) schemaVersion;
- (NSNumber *) schemaCompatibilityVersion;
- (NSNumber *) frameworkCompatibilityVersion;
- (BOOL) checkSchemaCompatibility: (NSError **) error;
@end


@interface BXPGInterface (ConnectionDelegate)
- (void) connectionSucceeded;
- (void) connectionFailed: (NSError *) error;
- (void) connectionLost: (BXPGTransactionHandler *) handler error: (NSError *) error;

- (FILE *) traceFile;
- (void) connection: (PGTSConnection *) connection sentQueryString: (const char *) queryString;
- (void) connection: (PGTSConnection *) connection sentQuery: (PGTSQuery *) query;
- (void) connection: (PGTSConnection *) connection receivedResultSet: (PGTSResultSet *) res;
@end


@interface BXPGInterface (Visitor) <PGTSQueryVisitor>
@end
