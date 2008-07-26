//
// BXDatabaseContextDelegateProtocol.h
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
#import <Security/Security.h>
#import <BaseTen/BXConstants.h>


@class BXDatabaseContext;


@protocol BXDatabaseContextDelegate <NSObject>

//Optional section of the protocol either as an interface or @optional.
#if __MAC_OS_X_VERSION_10_5 <= __MAC_OS_X_VERSION_MAX_ALLOWED
@optional
#else
@end
@interface NSObject (BXDatabaseContextDelegate)
#endif

- (void) BXDatabaseContextConnectionSucceeded: (BXDatabaseContext *) ctx;
- (void) BXDatabaseContext: (BXDatabaseContext *) ctx failedToConnect: (NSError *) error;
- (void) BXDatabaseContextConnectionFailureAlertDismissed: (BXDatabaseContext *) ctx;

/**
 * Handle an error.
 * Various methods in BXDatabaseContext have an NSError** parameter. In addition,
 * the context has an errorHandlerDelegate outlet. If no error handler has been 
 * set, the database context will handle errors itself. 
 * 
 * When the NSError** parameter has been supplied to the methods, no action 
 * will be taken and the error is assumed to have been handled. If the parameter
 * is NULL and an error occurs, a BXException named \c kBXExceptionUnhandledError
 * will be thrown.
 *
 * \param context			The database context from which the error originated.
 * \param anError			The error.
 * \param willBePassedOn	Whether the calling method's NSError** parameter was set or not.
 */
- (void) BXDatabaseContext: (BXDatabaseContext *) context 
				  hadError: (NSError *) anError 
			willBePassedOn: (BOOL) willBePassedOn;

- (void) BXDatabaseContext: (BXDatabaseContext *) context lostConnection: (NSError *) error;

/**
 * Policy for invalid trust.
 * The server certificate will be verified using the system keychain. On failure this 
 * method will be called. The delegate may then accept or deny the certificate or, in
 * case the application has been linked to the BaseTenAppKit framework, ask the context
 * to display a trust panel to the user.
 * \param ctx     The database context making the connection
 * \param trust   A trust created from the certificate
 * \param result  Initial verification result
 */
- (enum BXCertificatePolicy) BXDatabaseContext: (BXDatabaseContext *) ctx 
                            handleInvalidTrust: (SecTrustRef) trust 
                                        result: (SecTrustResultType) result;

/**
 * Secure connection mode for the context.
 * The mode may be one of require, disable and prefer. In prefer mode,
 * a secure connection will be attempted. If this fails for other reason
 * than a certificate verification problem, an insecure connection
 * will be tried.
 */
- (enum BXSSLMode) BXSSLModeForDatabaseContext: (BXDatabaseContext *) ctx;

@end
