//
// BXConstants.h
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

extern NSString* const kBXNoDatabaseURIException;
extern NSString* const kBXUnsupportedDatabaseException;
extern NSString* const kBXExceptionUnhandledError;
extern NSString* const kBXFailedToExecuteQueryException;
extern NSString* const kBXPGUnableToObserveModificationsException;
extern NSString* const kBXDatabaseContextKey;
extern NSString* const kBXURIKey;
extern NSString* const kBXObjectIDsKey;
extern NSString* const kBXInsertNotification;
extern NSString* const kBXDeleteNotification;
extern NSString* const kBXUpdateNotification;
extern NSString* const kBXLockNotification;
extern NSString* const kBXUnlockNotification;
extern NSString* const kBXObjectsKey;
extern NSString* const kBXEntityDescriptionKey;
extern NSString* const kBXContextKey;
extern NSString* const kBXErrorKey;
extern NSString* const kBXObjectKey;
extern NSString* const kBXEntityDescriptionKey;
extern NSString* const kBXObjectStatusKey;
extern NSString* const kBXObjectIDKey;
extern NSString* const kBXEntityDescriptionKey;
extern NSString* const kBXPrimaryKeyFieldsKey;
extern NSString* const kBXConnectionSuccessfulNotification;
extern NSString* const kBXConnectionFailedNotification;

extern NSString* const kBXErrorDomain;
extern NSString* const kBXErrorMessageKey;
enum BXError
{
    kBXErrorUnsuccessfulQuery = 1,
    kBXErrorConnectionFailed,
    kBXErrorNoPrimaryKey,
    kBXErrorNoTableForEntity,
    kBXErrorLockNotAcquired,
    kBXErrorNoDatabaseURI,
    kBXErrorObservingFailed,
	kBXErrorSSLConnectionFailed
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
    kBXRelationshipUndefined     = (1 << 0),
    kBXRelationshipOneToOne      = (1 << 1),
    kBXRelationshipOneToMany     = (1 << 2),
    kBXRelationshipManyToMany    = (1 << 3)
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
