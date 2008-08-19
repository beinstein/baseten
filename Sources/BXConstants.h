//
// BXConstants.h
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


#ifndef BX_EXPORT
#ifdef __cplusplus
#define BX_EXPORT extern "C"
#else
#define BX_EXPORT extern
#endif
#endif


BX_EXPORT NSString* const kBXNoDatabaseURIException;
BX_EXPORT NSString* const kBXUnsupportedDatabaseException;
BX_EXPORT NSString* const kBXExceptionUnhandledError;
BX_EXPORT NSString* const kBXFailedToExecuteQueryException;
BX_EXPORT NSString* const kBXPGUnableToObserveModificationsException;
BX_EXPORT NSString* const kBXDatabaseContextKey;
BX_EXPORT NSString* const kBXURIKey;
BX_EXPORT NSString* const kBXObjectIDsKey;
BX_EXPORT NSString* const kBXInsertNotification;
BX_EXPORT NSString* const kBXDeleteNotification;
BX_EXPORT NSString* const kBXUpdateNotification;
BX_EXPORT NSString* const kBXLockNotification;
BX_EXPORT NSString* const kBXUnlockNotification;
BX_EXPORT NSString* const kBXObjectsKey;
BX_EXPORT NSString* const kBXEntityDescriptionKey;
BX_EXPORT NSString* const kBXContextKey;
BX_EXPORT NSString* const kBXErrorKey;
BX_EXPORT NSString* const kBXObjectKey;
BX_EXPORT NSString* const kBXObjectLockStatusKey;
BX_EXPORT NSString* const kBXObjectIDKey;
BX_EXPORT NSString* const kBXPrimaryKeyFieldsKey;
BX_EXPORT NSString* const kBXConnectionSuccessfulNotification;
BX_EXPORT NSString* const kBXConnectionFailedNotification;
BX_EXPORT NSString* const kBXConnectionSetupAlertDidEndNotification;
BX_EXPORT NSString* const kBXGotDatabaseURINotification;
BX_EXPORT NSString* const kBXAttributeKey;
BX_EXPORT NSString* const kBXUnknownPredicatesKey;
BX_EXPORT NSString* const kBXRelationshipsKey;

BX_EXPORT NSString* const kBXErrorDomain;
BX_EXPORT NSString* const kBXErrorMessageKey;
enum BXError
{
	kBXErrorNone = 0,
    kBXErrorUnsuccessfulQuery,
    kBXErrorConnectionFailed,
    kBXErrorNoPrimaryKey,
    kBXErrorNoTableForEntity,
    kBXErrorLockNotAcquired,
    kBXErrorNoDatabaseURI,
    kBXErrorObservingFailed,
	kBXErrorObjectNotFound,
    kBXErrorMalformedDatabaseURI,
	kBXErrorAuthenticationFailed,
	kBXErrorNullConstraintNotSatisfied,
	kBXErrorSSLError,
	kBXErrorConnectionLost,
	kBXErrorUnknown,
	kBXErrorIncompleteDatabaseURI
};

enum BXModificationType
{
    kBXNoModification = 0,
    kBXInsertModification,
    kBXUpdateModification,
    kBXDeleteModification,
    kBXUndefinedModification
};

enum BXRelationshipType
{
    kBXRelationshipUndefined     = 0,
    kBXRelationshipOneToOne      = (1 << 0),
    kBXRelationshipOneToMany     = (1 << 1),
    kBXRelationshipManyToMany    = (1 << 2)
};

enum BXCertificatePolicy
{
	kBXCertificatePolicyUndefined			= 0,
	kBXCertificatePolicyAllow,
	kBXCertificatePolicyDeny,
	kBXCertificatePolicyDisplayTrustPanel
};

enum BXSSLMode
{
	kBXSSLModeUndefined	= 0,
	kBXSSLModeRequire,
	kBXSSLModeDisable,
	kBXSSLModePrefer
};

enum BXConnectionErrorHandlingState
{
	kBXConnectionErrorNone = 0,
	kBXConnectionErrorResolving,
	kBXConnectionErrorNoReconnect
};

enum BXEntityCapability
{
	kBXEntityCapabilityNone				= 0,
	kBXEntityCapabilityAutomaticUpdate	= (1 << 0),
	kBXEntityCapabilityRelationships	= (1 << 1)
};
