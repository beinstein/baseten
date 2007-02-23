//
// BXPolicyDelegate.h
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

#import <BaseTen/BXConstants.h>
#import <Security/Security.h>

/**
 * A protocol for SSL connection delegate.
 * In the future the delegate might have influence on other policies.
 */
@interface NSObject (BXPolicyDelegate)
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

