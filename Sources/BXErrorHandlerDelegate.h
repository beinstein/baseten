//
// BXErrorHandlerDelegate.h
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

@class BXDatabaseContext;

/**
 * A protocol for an error handler delegate.
 * \ingroup BaseTen
 */
@interface NSObject (BXErrorHandlerDelegate)
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
@end

