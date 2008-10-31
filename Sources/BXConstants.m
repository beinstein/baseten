//
// BXConstants.c
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

#import <BaseTen/BXConstants.h>

NSString* const kBXNoDatabaseURIException = @"kBXNoDatabaseURIException";
NSString* const kBXExceptionUnhandledError = @"kBXExceptionUnhandledError";
NSString* const kBXUnsupportedDatabaseException = @"kBXUnsupportedDatabaseException";
NSString* const kBXFailedToExecuteQueryException = @"kBXFailedToExecuteQueryException";
NSString* const kBXPGUnableToObserveModificationsException = @"kBXPGUnableToObserveModificationsException";
NSString* const kBXDatabaseContextKey = @"kBXContextKey";
NSString* const kBXURIKey = @"kBXURIKey";
NSString* const kBXObjectIDsKey = @"kBXObjectIDsKey";
NSString* const kBXLockNotification = @"kBXLockNotification";
NSString* const kBXUnlockNotification = @"kBXUnlockNotification";
NSString* const kBXObjectsKey = @"kBXObjectsKey";
NSString* const kBXEntityDescriptionKey = @"kBXEntityDescriptionKey";
NSString* const kBXContextKey = @"kBXContextKey";
NSString* const kBXErrorKey = @"kBXErrorKey";
NSString* const kBXObjectLockStatusKey = @"kBXObjectLockStatusKey";
NSString* const kBXObjectIDKey = @"kBXObjectIDKey";
NSString* const kBXPrimaryKeyFieldsKey = @"kBXPrimaryKeyFieldsKey";
NSString* const kBXConnectionSuccessfulNotification = @"kBXConnectionSuccessfulNotification";
NSString* const kBXConnectionFailedNotification = @"kBXConnectionFailedNotification";
NSString* const kBXConnectionSetupAlertDidEndNotification = @"kBXConnectionSetupAlertDidEndNotification";
NSString* const kBXGotDatabaseURINotification = @"kBXGotDatabaseURINotification";
NSString* const kBXAttributeKey = @"kBXAttributeKey";
NSString* const kBXUnknownPredicatesKey = @"kBXUnknownPredicatesKey";
NSString* const kBXRelationshipsKey = @"kBXRelationshipsKey";
NSString* const kBXPredicateKey = @"kBXPredicateKey";
NSString* const kBXOwnerObjectVariableName = @"BXOwnerObject";

NSString* const kBXInsertNotification = @"kBXInsertNotification";
NSString* const kBXInsertEarlyNotification = @"kBXInsertEarlyNotification";
NSString* const kBXUpdateNotification = @"kBXUpdateNotification";
NSString* const kBXUpdateEarlyNotification = @"kBXUpdateEarlyNotification";
NSString* const kBXDeleteNotification = @"kBXDeleteNotification";
NSString* const kBXDeleteEarlyNotification = @"kBXDeleteEarlyNotification";
NSString* const kBXEntityDescriptionWillDeallocNotification = @"kBXEntityDescriptionWillDeallocNotification";

NSString* const kBXErrorDomain = @"kBXErrorDomain";
NSString* const kBXErrorMessageKey = @"kBXErrorMessageKey";
NSString* const kBXObjectKey = @"kBXObjectKey";