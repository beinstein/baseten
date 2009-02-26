//
// BXPGTransactionHandler.m
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

#import "PGTS.h"
#import "PGTSAdditions.h"
#import "PGTSHOM.h"
#import "PGTSOids.h"

#import "BXInterface.h"
#import "BXProbes.h"
#import "BXLogger.h"
#import "BXEnumerate.h"

#import "BXPGCertificateVerificationDelegate.h"
#import "BXPGTransactionHandler.h"
#import "BXPGAdditions.h"
#import "BXPGConnectionResetRecoveryAttempter.h"
#import "BXPGModificationHandler.h"
#import "BXPGLockHandler.h"
#import "BXPGClearLocksHandler.h"
#import "BXPGDatabaseDescription.h"
#import "BXPGInterface.h"
#import "BXPGCertificateVerificationDelegate.h"
#import "BXLocalizedString.h"

#import "BXEntityDescriptionPrivate.h"


NSString* kBXPGUserInfoKey = @"kBXPGUserInfoKey";
NSString* kBXPGDelegateKey = @"kBXPGDelegateKey";
NSString* kBXPGCallbackSelectorStringKey = @"kBXPGCallbackSelectorStringKey";


static NSString* 
SSLMode (enum BXSSLMode mode)
{
	NSString* retval = @"require";
	switch (mode) 
	{
		case kBXSSLModeDisable:
			retval = @"disable";
			break;
			
		case kBXSSLModePrefer:
		default:
			break;
	}
	return retval;
}


@interface BXPGResultSetPlaceholder : NSObject <BXPGResultSetPlaceholder>
{
	id mUserInfo;
	BOOL mDidSucceed;
}
- (void) setUserInfo: (id) anObject;
- (void) setQuerySucceeded: (BOOL) aBool;
- (BOOL) querySucceeded;
- (id) userInfo;
@end


@implementation BXPGResultSetPlaceholder
- (void) dealloc
{
	[mUserInfo release];
	[super dealloc];
}

- (void) setUserInfo: (id) anObject
{
	if (mUserInfo != anObject)
	{
		[mUserInfo release];
		mUserInfo = [anObject retain];
	}
}

- (void) setQuerySucceeded: (BOOL) aBool
{
	mDidSucceed = aBool;
}

- (BOOL) querySucceeded
{
	return mDidSucceed;
}

- (id) userInfo
{
	return mUserInfo;
}

- (NSError *) error
{
	return nil;
}
@end


@implementation BXPGTransactionHandler
- (BOOL) logsQueries
{
	return [mConnection logsQueries];
}

- (void) setLogsQueries: (BOOL) shouldLog
{
	[mConnection setLogsQueries: shouldLog];
}

- (void) sendPlaceholderResultTo: (id) receiver callback: (SEL) callback 
					   succeeded: (BOOL) didSucceed userInfo: (id) userInfo
{
	id arg = [[[BXPGResultSetPlaceholder alloc] init] autorelease];
	[arg setQuerySucceeded: didSucceed];
	[arg setUserInfo: userInfo];
	[receiver performSelector: callback withObject: arg];
}

- (void) forwardResult: (id) result
{
	ExpectV (result);
	
	NSDictionary* userInfoDict = [result userInfo];
	
	id receiver = [userInfoDict objectForKey: kBXPGDelegateKey];
	id receiverUserInfo = [userInfoDict objectForKey: kBXPGUserInfoKey];
	SEL callback = NSSelectorFromString ([userInfoDict objectForKey: kBXPGCallbackSelectorStringKey]);
	
	[result setUserInfo: receiverUserInfo];
	[receiver performSelector: callback withObject: result];
}

- (void) reloadDatabaseMetadata
{
	[mConnection reloadDatabaseDescription];
}

- (void) dealloc
{
	[mCertificateVerificationDelegate release];
	[mConnection release];
	[mObservedEntities release];
	[mObservers release];
	[mChangeHandlers release];
	[mLockHandlers release];
	[super dealloc];
}

- (PGTSConnection *) connection
{
	return mConnection;
}

- (void) setInterface: (BXPGInterface *) interface
{
	mInterface = interface;
}

- (BXPGInterface *) interface
{
	return mInterface;
}

- (BOOL) connected
{
	return (CONNECTION_OK == [mConnection connectionStatus]);
}

- (BXPGDatabaseDescription *) databaseDescription
{
	return (id) [mConnection databaseDescription];
}

- (BOOL) isAsync
{
	return mAsync;
}

- (BOOL) isSSLInUse
{
	return ([mConnection SSLStruct] ? YES : NO);
}

- (void) markLocked: (BXEntityDescription *) entity 
	  relationAlias: (NSString *) alias
		 fromClause: (NSString *) fromClause
		whereClause: (NSString *) whereClause 
		 parameters: (NSArray *) parameters
		 willDelete: (BOOL) willDelete
{
	[super doesNotRecognizeSelector: _cmd];
}

- (void) markLocked: (BXEntityDescription *) entity 
	  relationAlias: (NSString *) alias
		 fromClause: (NSString *) fromClause
		whereClause: (NSString *) whereClause 
		 parameters: (NSArray *) parameters
		 willDelete: (BOOL) willDelete
		 connection: (PGTSConnection *) connection 
   notifyConnection: (PGTSConnection *) notifyConnection
{
	ExpectV (entity);
	ExpectV (whereClause);
	
	if (PQTRANS_INTRANS == [connection transactionStatus])
	{
		NSString* funcname = [[mLockHandlers objectForKey: entity] lockFunctionName];
		
		//Lock type
		NSString* format = @"SELECT %@ ('U', %u, %@) FROM %@ WHERE %@";
		if (willDelete)
			format = @"SELECT %@ ('D', %u, %@) FROM %@ WHERE %@";
		
		//Table
		NSError* localError = nil;
		BXPGTableDescription* table = [mInterface tableForEntity: entity];
		BXAssertVoidReturn (table, @"Expected to get a table description. Error: %@", localError);

		//Get and sort the primary key fields.
		NSArray* pkeyFields = [[[[table primaryKey] columns] allObjects] sortedArrayUsingSelector: @selector (indexCompare:)];
		BXAssertVoidReturn (nil != pkeyFields, @"Expected to know the primary key.");
		NSArray* pkeyNames = (id) [[pkeyFields PGTSCollect] name];
		NSArray* attrs = [[entity attributesByName] objectsForKeys: pkeyNames notFoundMarker: [NSNull null]];
		ExpectV (! [attrs containsObject: [NSNull null]]);
		NSString* fieldList = BXPGReturnList (attrs, alias, YES);
		
		//Execute the query.
		NSString* query = [NSString stringWithFormat: format, funcname, 0, fieldList, fromClause, whereClause];
		[notifyConnection sendQuery: query delegate: nil callback: NULL parameterArray: parameters]; 			
	}
}

- (BOOL) canSend: (NSError **) outError
{
	ExpectR (outError, NO);
	BOOL retval = [mConnection canSend];
	if (! retval)
	{
		NSString* title = BXLocalizedString (@"networkError", @"Network Error", @"Title for a sheet");
		NSString* description = BXLocalizedString (@"networkErrorDescription", 
												   @"The database server can no longer be reached.", 
												   @"Explanation");
		
		NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										 description, NSLocalizedFailureReasonErrorKey,
										 description, NSLocalizedRecoverySuggestionErrorKey,
										 title, NSLocalizedDescriptionKey,
										 [mInterface databaseContext], kBXDatabaseContextKey,
										 nil];
		
		NSError* error = [NSError errorWithDomain: kBXErrorDomain code: kBXErrorGenericNetworkError userInfo: userInfo];
		*outError = error;
	}
	return retval;
}

#pragma mark Connecting

- (void) didDisconnect
{
	[mObservedEntities removeAllObjects];
	[mObservers removeAllObjects];
	[mChangeHandlers removeAllObjects];
	[mLockHandlers removeAllObjects];
}


static NSString*
ConnectionString (NSDictionary* connectionDict)
{
	NSMutableString* connectionString = [NSMutableString string];
	NSEnumerator* e = [connectionDict keyEnumerator];
	NSString* currentKey;
	NSString* format = @"%@ = '%@' ";
	while ((currentKey = [e nextObject]))
	{
		if ([kPGTSConnectionDictionaryKeys containsObject: currentKey])
			[connectionString appendFormat: format, currentKey, [connectionDict objectForKey: currentKey]];
	}
	return connectionString;
}


- (NSString *) connectionString
{
	BXDatabaseContext* ctx = [mInterface databaseContext];
	NSURL* databaseURI = [ctx databaseURI];
	NSMutableDictionary* connectionDict = [databaseURI BXPGConnectionDictionary];

	enum BXSSLMode sslMode = [ctx sslMode];
	[connectionDict setValue: SSLMode (sslMode) forKey: kPGTSSSLModeKey];
	
	[connectionDict setValue: @"10" forKey: kPGTSConnectTimeoutKey];
	
	return ConnectionString (connectionDict);
}


- (void) prepareForConnecting
{
	mSyncErrorPtr = NULL;
	mConnectionSucceeded = NO;
	
	if (! mCertificateVerificationDelegate)
	{
		mCertificateVerificationDelegate = [[BXPGCertificateVerificationDelegate alloc] init];
		[mCertificateVerificationDelegate setHandler: self];
	}	
	
	if (! mConnection)
	{
		mConnection = [[PGTSConnection alloc] init];
		[mConnection setDelegate: self];
		[mConnection setCertificateVerificationDelegate: mCertificateVerificationDelegate];
		[mConnection setLogsQueries: [mInterface logsQueries]];
	}	
}


- (void) refreshDatabaseDescription
{
	[mConnection reloadDatabaseDescription];
}


- (void) handleConnectionErrorFor: (PGTSConnection *) failedConnection
{
	ExpectV (mAsync || mSyncErrorPtr);

	NSError* error = [failedConnection connectionError];
	if (mAsync)
		[mInterface connectionFailed: error];
	else
		*mSyncErrorPtr = error;
}


- (NSError *) connectionError: (NSError *) error recoveryAttempterClass: (Class) aClass
{
	//FIXME: move (parts of) this to the context.
	
	BXPGConnectionRecoveryAttempter* attempter = [[[aClass alloc] init] autorelease];
	attempter->mHandler = self;
	
	NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject: attempter forKey: NSRecoveryAttempterErrorKey];
	[userInfo setObject: @"Database Error" forKey: NSLocalizedDescriptionKey]; //FIXME: localization.
	[userInfo setObject: @"Connection to the database was lost." forKey: NSLocalizedFailureReasonErrorKey];
	[userInfo setObject: @"Connection to the database was lost." forKey: NSLocalizedRecoverySuggestionErrorKey];
	if (error) [userInfo setObject: error forKey: NSUnderlyingErrorKey];
	
	NSArray* options = [NSArray arrayWithObjects: @"Try to Reconnect", @"Continue", nil]; //FIXME: localization.
	[userInfo setObject: options forKey: NSLocalizedRecoveryOptionsErrorKey];
	
	return [NSError errorWithDomain: kBXErrorDomain code: kBXErrorConnectionLost userInfo: userInfo];
}


- (void) handleSuccess
{
	mConnectionSucceeded = YES;
	if (mAsync)
	{
		[mInterface connectionSucceeded];
	}
	BXLogDebug (@"mConnection: %p", mConnection);
}


- (BOOL) connectSync: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (void) connectAsync
{
	[self doesNotRecognizeSelector: _cmd];
}


- (void) disconnect
{
	[self doesNotRecognizeSelector: _cmd];
}


#pragma mark TransactionHelpers

- (NSString *) savepointQuery
{
    mSavepointIndex++;
    return [NSString stringWithFormat: @"SAVEPOINT BXPGSavepoint%u", mSavepointIndex];
}

- (NSString *) rollbackToSavepointQuery
{
	mSavepointIndex--;
    return [NSString stringWithFormat: @"ROLLBACK TO SAVEPOINT BXPGSavepoint%u", mSavepointIndex];
}

- (void) resetSavepointIndex
{
	mSavepointIndex = 0;
}

- (NSUInteger) savepointIndex
{
	return mSavepointIndex;
}


#pragma mark Transactions

- (void) beginIfNeededFor: (id) delegate callback: (SEL) callback userInfo: (id) userInfo
{
	PGTransactionStatusType status = [mConnection transactionStatus];
	switch (status) 
	{
		case PQTRANS_INTRANS:
            [self sendPlaceholderResultTo: delegate callback: callback succeeded: YES userInfo: userInfo];
			break;
			
		case PQTRANS_IDLE:
		{
			NSString* query = @"BEGIN";
            [mConnection sendQuery: query delegate: delegate callback: callback 
                    parameterArray: nil userInfo: userInfo];
			break;
		}
			
		default:
			[self sendPlaceholderResultTo: delegate callback: callback succeeded: NO userInfo: userInfo];
			//FIXME: set an error.
			break;
	}
}

- (BOOL) beginIfNeeded: (NSError **) outError
{
    ExpectR (outError, NO);
	BOOL retval = NO;
	PGTransactionStatusType status = [mConnection transactionStatus];
	switch (status) 
	{
		case PQTRANS_INTRANS:
			retval = YES;
			break;
			
		case PQTRANS_IDLE:
		{
			NSString* query = @"BEGIN";
            PGTSResultSet* res = [mConnection executeQuery: query];
				
            if ([res querySucceeded])
                retval = YES;
            else
                *outError = [res error];				

			break;
		}
			
		default:
			//FIXME: set an error.
			break;
	}
	return retval;
}


- (BOOL) save: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (BOOL) rollback: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (BOOL) savepointIfNeeded: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (BOOL) rollbackToLastSavepoint: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (BOOL) beginSubTransactionIfNeeded: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (void) beginAsyncSubTransactionFor: (id) delegate callback: (SEL) callback userInfo: (NSDictionary *) userInfo
{
	[self doesNotRecognizeSelector: _cmd];
}


- (BOOL) endSubtransactionIfNeeded: (NSError **) outError
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (void) rollbackSubtransaction
{
	[self doesNotRecognizeSelector: _cmd];
}


- (BOOL) autocommits
{
	return NO;
}


#pragma mark Observing


- (BOOL) observeIfNeeded: (BXEntityDescription *) entity error: (NSError **) error
{
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}


- (BOOL) observeIfNeeded: (BXEntityDescription *) entity connection: (PGTSConnection *) connection error: (NSError **) error
{
	ExpectR (error, NO);
	ExpectR (entity, NO);
	
	BOOL retval = NO;
	
	if ([mObservedEntities containsObject: entity])
		retval = YES;
	else
	{
		if (! mObservedEntities)
			mObservedEntities = [[NSMutableSet alloc] init];
		if (! mObservers)
			mObservers = [[NSMutableDictionary alloc] init];
		if (! mChangeHandlers)
			mChangeHandlers = [[NSMutableDictionary alloc] init];
		if (! mLockHandlers)
			mLockHandlers = [[NSMutableDictionary alloc] init];
		
		BXPGDatabaseDescription* database = (id) [connection databaseDescription];
		BXPGTableDescription* table = [mInterface tableForEntity: entity inDatabase: database];
		if (table && [self addClearLocksHandler: connection error: error])
		{
			//Start listening to notifications and get the notification names.
			id oid = PGTSOidAsObject ([table oid]);
			NSString* query = 
			@"SELECT "
			@" CURRENT_TIMESTAMP::TIMESTAMP WITHOUT TIME ZONE AS ts, "
			@" null AS relid, "
			@" null AS n_name, "
			@" null AS fn_name, "
			@" null AS t_name "
			@"UNION ALL "
			@"SELECT null, m.* FROM baseten.mod_observe ($1) m "
			@"UNION ALL "
			@"SELECT null, l.* FROM baseten.lock_observe ($1) l";
			PGTSResultSet* res = [connection executeQuery: query parameters: oid];
			if ([res querySucceeded] && 3 == [res count])
			{
				[res advanceRow];
				NSDate* lastCheck = [res valueForKey: @"ts"];
				
				{
					[res advanceRow];
					NSString* notificationName = [res valueForKey: @"n_name"];
					BXPGModificationHandler* handler = [[[BXPGModificationHandler alloc] init] autorelease];
					
					[handler setInterface: mInterface];
					[handler setConnection: connection];
					[handler setLastCheck: lastCheck];
					[handler setEntity: entity];
					[handler setNotificationName: notificationName];
					[handler setOid: [[res valueForKey: @"relid"] PGTSOidValue]];
					[handler prepare];
					
					[mObservers setObject: handler forKey: notificationName];
					[mChangeHandlers setObject: handler forKey: entity];
				}
				
				{
					[res advanceRow];
					NSString* notificationName = [res valueForKey: @"n_name"];
					NSString* functionName = [res valueForKey: @"fn_name"];
					NSString* tableName = [res valueForKey: @"t_name"];
					BXPGLockHandler* handler = [[[BXPGLockHandler alloc] init] autorelease];
					
					[handler setInterface: mInterface];
					[handler setConnection: connection];
					[handler setLastCheck: lastCheck];
					[handler setEntity: entity];
					[handler setNotificationName: notificationName];
					[handler setLockFunctionName: functionName];
					[handler setLockTableName: tableName];
					[handler prepare];
					
					[mObservers setObject: handler forKey: notificationName];
					[mLockHandlers setObject: handler forKey: entity];
				}
								
				[mObservedEntities addObject: entity];			
				retval = YES;
			}
			else
			{
				*error = [res error];
			}
		}
	}
	
	//Inheritance.
	BXEnumerate (currentEntity, e, [[entity inheritedEntities] objectEnumerator])
	{
		if (! retval)
			break;
		retval = [self observeIfNeeded: currentEntity connection: connection error: error];
	}
	
    return retval;
}


- (BOOL) addClearLocksHandler: (PGTSConnection *) connection 
						error: (NSError **) outError
{
	ExpectR (outError, NO);
	
	BOOL retval = NO;
	NSString* nname = [BXPGClearLocksHandler notificationName];
	if ([mObservers objectForKey: nname])
		retval = YES;
	else
	{
		NSString* query = [NSString stringWithFormat: @"LISTEN %@", [nname BXPGEscapedName: connection]];
		PGTSResultSet* res = [connection executeQuery: query];
		if ([res querySucceeded])
		{
			BXPGClearLocksHandler* handler = [[[BXPGClearLocksHandler alloc] init] autorelease];
			[handler setInterface: mInterface];
			[handler setConnection: connection];
			[handler prepare];
			[mObservers setObject: handler forKey: nname];
			
			retval = YES;
		}
		else
		{
			*outError = [res error];
		}
	}
	return retval;
}


- (void) checkSuperEntities: (BXEntityDescription *) entity connection: (PGTSConnection *) connection
{
	BXEnumerate (superEntity, e, [[entity inheritedEntities] objectEnumerator])
		[[mChangeHandlers objectForKey: superEntity] checkModifications: 0];
}


- (void) checkSuperEntities: (BXEntityDescription *) entity
{
	[self doesNotRecognizeSelector: _cmd];
}


- (NSArray *) observedOids
{
	NSMutableArray* retval = [NSMutableArray arrayWithCapacity: [mObservedEntities count]];
	BXEnumerate (currentEntity, e, [mObservedEntities objectEnumerator])
	{
		NSString* name = [currentEntity name];
		NSString* schemaName = [currentEntity schemaName];
		PGTSTableDescription* table = [[mConnection databaseDescription] table: name inSchema: schemaName];
		[retval addObject: PGTSOidAsObject ([table oid])];
	}
	return retval;
}

- (BOOL) usedPassword
{
	return [mConnection usedPassword];
}
@end


@implementation BXPGTransactionHandler (PGTSConnectionDelegate)
- (void) PGTSConnection: (PGTSConnection *) connection receivedNotice: (NSError *) notice
{
	//BXLogDebug (@"%p: %s", connection, message);
	if (BASETEN_RECEIVED_PG_NOTICE_ENABLED ())
	{
		NSString* message = [[notice userInfo] objectForKey: kPGTSErrorMessage];
		char* message_s = strdup ([message UTF8String]);
		BASETEN_RECEIVED_PG_NOTICE (connection, message_s);
		free (message_s);
	}
}

- (void) PGTSConnection: (PGTSConnection *) connection gotNotification: (PGTSNotification *) notification
{
	NSString* notificationName = [notification notificationName];
	BXLogDebug (@"Got notification (%p): %@", self, connection, notificationName);
	[[mObservers objectForKey: notificationName] handleNotification: notification];
}


- (void) PGTSConnectionLost: (PGTSConnection *) connection error: (NSError *) error
{
	[self doesNotRecognizeSelector: _cmd];
}


- (void) PGTSConnectionFailed: (PGTSConnection *) connection
{
	[self doesNotRecognizeSelector: _cmd];
}


- (void) PGTSConnectionEstablished: (PGTSConnection *) connection
{
	[self doesNotRecognizeSelector: _cmd];
}

- (FILE *) PGTSConnectionTraceFile: (PGTSConnection *) connection
{
	return [mInterface traceFile];
}

- (void) PGTSConnection: (PGTSConnection *) connection sentQueryString: (const char *) queryString
{
	[mInterface connection: connection sentQueryString: queryString];
}

- (void) PGTSConnection: (PGTSConnection *) connection sentQuery: (PGTSQuery *) query
{
	[mInterface connection: connection sentQuery: query];
}

- (void) PGTSConnection: (PGTSConnection *) connection receivedResultSet: (PGTSResultSet *) res
{
	[mInterface connection: connection receivedResultSet: res];
}

- (void) PGTSConnection: (PGTSConnection *) connection networkStatusChanged: (SCNetworkConnectionFlags) newFlags
{
	BXDatabaseContext* context = [mInterface databaseContext];
	[context networkStatusChanged: newFlags];
}
@end


@implementation BXPGTransactionHandler (BXPGTrustHandler)
- (BOOL) handleInvalidTrust: (SecTrustRef) trust result: (SecTrustResultType) result
{
	BOOL retval = NO;
	BXDatabaseContext* ctx = [mInterface databaseContext];
	if (mAsync)
	{
		CFRetain (trust);
		struct BXTrustResult trustResult = {trust, result};
		NSValue* resultValue = [NSValue valueWithBytes: &trustResult objCType: @encode (struct BXTrustResult)];				
		[ctx performSelectorOnMainThread: @selector (handleInvalidCopiedTrustAsync:) withObject: resultValue waitUntilDone: NO];
	}
	else
	{
		retval = [ctx handleInvalidTrust: trust result: result];
	}
	return retval;
}


- (void) handledTrust: (SecTrustRef) trust accepted: (BOOL) accepted
{
	if (! accepted)
	{
		[mCertificateVerificationDelegate setCertificates: nil];
	}
}
@end
