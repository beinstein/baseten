//
// PGTSConstants.m
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
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
#import <PGTS/PGTSConstants.h>


NSDictionary* kPGTSDefaultConnectionDictionary    = nil;
NSArray* kPGTSConnectionDictionaryKeys            = nil;

NSString* const kPGTSHostKey                      = @"host";
NSString* const kPGTSHostAddressKey               = @"hostaddr";
NSString* const kPGTSPortKey                      = @"port";
NSString* const kPGTSDatabaseNameKey              = @"dbname";
NSString* const kPGTSUserNameKey                  = @"user";
NSString* const kPGTSPasswordKey                  = @"password";
NSString* const kPGTSConnectTimeoutKey            = @"connect_timeout";
NSString* const kPGTSOptionsKey                   = @"options";
NSString* const kPGTSSSLModeKey                   = @"sslmode";
NSString* const kPGTSServiceNameKey               = @"service"; 

NSString* const kPGTSRetrievedResultNotification  = @"kPGTSRetrievedResultNotification";
NSString* const kPGTSNotificationNameKey		  = @"kPGTSNotificationNameKey";
NSString* const kPGTSBackendPIDKey    = @"Backend PID";
NSString* const kPGTSNotificationExtraKey         = @"Extra parameters";
NSString* const kPGTSWillDisconnectNotification   = @"kPGTSWillDisconnectNotification";
NSString* const kPGTSDidDisconnectNotification    = @"kPGTSDidDisconnectNotification";
NSString* const kPGTSNotice                       = @"kPGTSNotice";
NSString* const kPGTSNoticeMessageKey             = @"kPGTSNoticeMessageKey";
NSString* const kPGTSConnectionPoolItemDidRemoveConnectionNotification = 
    @"kPGTSConnectionPoolItemWillRemoveConnectionNotification";
NSString* const kPGTSConnectionPoolItemDidAddConnectionNotification =
    @"kPGTSConnectionPoolItemDidAddConnectionNotification";
NSString* const kPGTSRowKey                       = @"kPGTSRowsKey";
NSString* const kPGTSRowsKey                      = @"kPGTSRowsKey";
NSString* const kPGTSTableKey                     = @"kPGTSTableKey";

NSString* const kPGTSConnectionKey                = @"kPGTSConnectionKey";
NSString* const kPGTSConnectionDelegateKey        = @"kPGTSConnectionDelegateKey";

NSString* const kPGTSFieldnameKey                 = @"kPGTSFieldnameKey";
NSString* const kPGTSFieldKey                     = @"kPGTSFieldKey";
NSString* const kPGTSKeyFieldKey                  = @"kPGTSKeyFieldKey";
NSString* const kPGTSValueKey                     = @"kPGTSValueKey";
NSString* const kPGTSRowIndexKey                  = @"kPGTSRowIndexKey";
NSString* const kPGTSResultSetKey                 = @"kPGTSResultSetKey";
NSString* const kPGTSDataSourceKey                = @"kPGTSDataSourceKey";

NSString* const kPGTSNoKeyFieldsException         = @"kPGTSNoKeyFieldsException";
NSString* const kPGTSNoKeyFieldException          = @"kPGTSNoKeyFieldException";
NSString* const kPGTSFieldNotFoundException       = @"kPGTSFieldNotFoundException";
NSString* const kPGTSNoPrimaryKeyException        = @"kPGTSNoPrimaryKeyException";
NSString* const kPGTSQueryFailedException         = @"kPGTSQueryFailedException";
NSString* const kPGTSConnectionFailedException    = @"kPGTSConnectionFailedException";

NSString* const kPGTSModificationNameKey          = @"kPGTSModificationNameKey";
NSString* const kPGTSInsertModification           = @"kPGTSInsertModification";
NSString* const kPGTSUpdateModification           = @"kPGTSUpdateModification";
NSString* const kPGTSDeleteModification           = @"kPGTSDeleteModification";

NSString* const kPGTSRowShareLock                 = @"kPGTSRowShareLock";
NSString* const kPGTSLockedForUpdate              = @"kPGTSLockedForUpdate";
NSString* const kPGTSLockedForDelete              = @"kPGTSLockedForDelete";
NSString* const kPGTSUnlockedRowsNotification     = @"kPGTSUnlockedRowsNotification";

NSString* const kPGTSUnsupportedPredicateOperatorTypeException = @"kPGTSUnsupportedPredicateOperatorTypeException";
NSString* const kPGTSParametersKey = @"kPGTSParametersKey";
NSString* const kPGTSParameterIndexKey = @"kPGTSParameterIndexKey";
NSString* const kPGTSExpressionParametersVerbatimKey = @"kPGTSExpressionParametersVerbatimKey";

NSString* const kPGTSErrorDomain                  = @"kPGTSErrorDomain";

NSString* const kPGTSErrorSeverity                = @"kPGTSErrorSeverity";
NSString* const kPGTSErrorSQLState                = @"kPGTSErrorSQLState";
NSString* const kPGTSErrorPrimaryMessage          = @"kPGTSErrorPrimaryMessage";
NSString* const kPGTSErrorDetailMessage           = @"kPGTSErrorDetailMessage";
NSString* const kPGTSErrorHint                    = @"kPGTSErrorHint";
NSString* const kPGTSErrorInternalQuery           = @"kPGTSErrorInternalQuery";
NSString* const kPGTSErrorContext                 = @"kPGTSErrorContext";
NSString* const kPGTSErrorSourceFile              = @"kPGTSErrorSourceFile";
NSString* const kPGTSErrorSourceFunction          = @"kPGTSErrorSourceFunction";
NSString* const kPGTSErrorStatementPosition       = @"kPGTSErrorStatementPosition";
NSString* const kPGTSErrorInternalPosition        = @"kPGTSErrorInternalPosition";
NSString* const kPGTSErrorSourceLine              = @"kPGTSErrorSourceLine";


/** Declared in PGTSConnectionDelegate.h */
SEL kPGTSSentQuerySelector                  = NULL;
SEL kPGTSFailedToSendQuerySelector          = NULL;
SEL kPGTSAcceptCopyingDataSelector          = NULL;
SEL kPGTSReceivedDataSelector               = NULL;
SEL kPGTSReceivedResultSetSelector          = NULL;
SEL kPGTSReceivedErrorSelector              = NULL;
SEL kPGTSReceivedNoticeSelector             = NULL;

SEL kPGTSConnectionFailedSelector           = NULL;
SEL kPGTSConnectionEstablishedSelector      = NULL;
SEL kPGTSStartedReconnectingSelector        = NULL;
SEL kPGTSDidReconnectSelector               = NULL;
