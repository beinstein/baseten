//
// PGTSConstants.h
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

#if defined(PGTS_EXPORT)
#undef PGTS_EXPORT
#endif

#if defined(__cplusplus)
#define PGTS_EXPORT extern "C"
#else
#define PGTS_EXPORT extern
#endif

#define kPGTSPUBLICOid InvalidOid


PGTS_EXPORT NSDictionary* kPGTSDefaultConnectionDictionary;

PGTS_EXPORT NSString* const kPGTSHostKey;
PGTS_EXPORT NSString* const kPGTSHostAddressKey;
PGTS_EXPORT NSString* const kPGTSPortKey;
PGTS_EXPORT NSString* const kPGTSDatabaseNameKey;
PGTS_EXPORT NSString* const kPGTSUserNameKey;
PGTS_EXPORT NSString* const kPGTSPasswordKey;
PGTS_EXPORT NSString* const kPGTSConnectTimeoutKey;
PGTS_EXPORT NSString* const kPGTSOptionsKey;
PGTS_EXPORT NSString* const kPGTSSSLModeKey;
PGTS_EXPORT NSString* const kPGTSServiceNameKey;
PGTS_EXPORT NSArray* kPGTSConnectionDictionaryKeys;

PGTS_EXPORT NSString* const kPGTSRetrievedResultNotification;
PGTS_EXPORT NSString* const kPGTSBackendPIDKey;
PGTS_EXPORT NSString* const kPGTSNotificationExtraKey;
PGTS_EXPORT NSString* const kPGTSWillDisconnectNotification;
PGTS_EXPORT NSString* const kPGTSDidDisconnectNotification;
PGTS_EXPORT NSString* const kPGTSNotice;
PGTS_EXPORT NSString* const kPGTSNoticeMessageKey;
PGTS_EXPORT NSString* const kPGTSConnectionPoolItemDidRemoveConnectionNotification;
PGTS_EXPORT NSString* const kPGTSConnectionPoolItemDidAddConnectionNotification;
PGTS_EXPORT NSString* const kPGTSRowKey;
PGTS_EXPORT NSString* const kPGTSRowsKey;
PGTS_EXPORT NSString* const kPGTSTableKey;

PGTS_EXPORT NSString* const kPGTSConnectionKey;
PGTS_EXPORT NSString* const kPGTSConnectionDelegateKey;

PGTS_EXPORT NSString* const kPGTSFieldnameKey;
PGTS_EXPORT NSString* const kPGTSFieldKey;
PGTS_EXPORT NSString* const kPGTSValueKey;
PGTS_EXPORT NSString* const kPGTSRowIndexKey;
PGTS_EXPORT NSString* const kPGTSResultSetKey;
PGTS_EXPORT NSString* const kPGTSDataSourceKey;

PGTS_EXPORT NSString* const kPGTSNoKeyFieldsException;
PGTS_EXPORT NSString* const kPGTSNoKeyFieldException;
PGTS_EXPORT NSString* const kPGTSFieldNotFoundException;
PGTS_EXPORT NSString* const kPGTSNoPrimaryKeyException;
PGTS_EXPORT NSString* const kPGTSQueryFailedException;
PGTS_EXPORT NSString* const kPGTSConnectionFailedException;

PGTS_EXPORT NSString* const kPGTSModificationNameKey;
PGTS_EXPORT NSString* const kPGTSInsertModification;
PGTS_EXPORT NSString* const kPGTSUpdateModification;
PGTS_EXPORT NSString* const kPGTSDeleteModification;

PGTS_EXPORT NSString* const kPGTSLockedForUpdate;
PGTS_EXPORT NSString* const kPGTSLockedForDelete;
PGTS_EXPORT NSString* const kPGTSUnlockedRowsNotification;
PGTS_EXPORT NSString* const kPGTSRowShareLock;

PGTS_EXPORT NSString* const kPGTSUnsupportedPredicateOperatorTypeException;
PGTS_EXPORT NSString* const kPGTSParametersKey;
PGTS_EXPORT NSString* const kPGTSParameterIndexKey;
PGTS_EXPORT NSString* const kPGTSExpressionParametersVerbatimKey;

PGTS_EXPORT NSString* const kPGTSErrorSeverity;
PGTS_EXPORT NSString* const kPGTSErrorSQLState;
PGTS_EXPORT NSString* const kPGTSErrorPrimaryMessage;
PGTS_EXPORT NSString* const kPGTSErrorDetailMessage;
PGTS_EXPORT NSString* const kPGTSErrorHint;
PGTS_EXPORT NSString* const kPGTSErrorInternalQuery;
PGTS_EXPORT NSString* const kPGTSErrorContext;
PGTS_EXPORT NSString* const kPGTSErrorSourceFile;
PGTS_EXPORT NSString* const kPGTSErrorSourceFunction;
PGTS_EXPORT NSString* const kPGTSErrorStatementPosition;
PGTS_EXPORT NSString* const kPGTSErrorInternalPosition;
PGTS_EXPORT NSString* const kPGTSErrorSourceLine;
    

PGTS_EXPORT NSString* const kPGTSErrorDomain;
enum PGTSErrors
{
    kPGTSUnsuccessfulQueryError = 1
};
/* See PGTSConnectionDelegate.h */

enum PGTSACLItemPrivilege
{
    kPGTSPrivilegeNone            = 0,
	//1 << 0 missing
    kPGTSPrivilegeSelect          = 1 << 1,
    kPGTSPrivilegeSelectGrant     = 1 << 2,
    kPGTSPrivilegeUpdate          = 1 << 3,
    kPGTSPrivilegeUpdateGrant     = 1 << 4,
    kPGTSPrivilegeInsert          = 1 << 5,
    kPGTSPrivilegeInsertGrant     = 1 << 6,
    kPGTSPrivilegeDelete          = 1 << 7,
    kPGTSPrivilegeDeleteGrant     = 1 << 8,
    kPGTSPrivilegeReferences      = 1 << 9,
    kPGTSPrivilegeReferencesGrant = 1 << 10,
    kPGTSPrivilegeTrigger         = 1 << 11,
    kPGTSPrivilegeTriggerGrant    = 1 << 12,
    kPGTSPrivilegeExecute         = 1 << 13,
    kPGTSPrivilegeExecuteGrant    = 1 << 14,
    kPGTSPrivilegeUsage           = 1 << 15,
    kPGTSPrivilegeUsageGrant      = 1 << 16,
    kPGTSPrivilegeCreate          = 1 << 17,
    kPGTSPrivilegeCreateGrant     = 1 << 18,
    kPGTSPrivilegeConnect         = 1 << 19,
    kPGTSPrivilegeConnectGrant    = 1 << 20,
    kPGTSPrivilegeTemporary       = 1 << 21,
    kPGTSPrivilegeTemporaryGrant  = 1 << 22
};

enum PGTSDeleteRule
{
	kPGTSDeleteRuleUnknown		  = 0,
	kPGTSDeleteRuleNone,
	kPGTSDeleteRuleNoAction,
	kPGTSDeleteRuleRestrict,
	kPGTSDeleteRuleCascade,
	kPGTSDeleteRuleSetNull,
	kPGTSDeleteRuleSetDefault
};
