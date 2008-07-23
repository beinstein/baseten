//
// PGTSFunctions.m
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

#import <libgen.h>
#import <Foundation/Foundation.h>
#import <openssl/x509.h>
#import <openssl/ssl.h>
#import <Security/Security.h>
#import <BaseTen/postgresql/libpq-fe.h>
#import "PGTSFunctions.h"
#import "PGTSConstants.h"
#import "PGTSConnection.h"


/**
 * Return the value as an object
 * \sa PGTSOidValue
 */
id 
PGTSOidAsObject (Oid o)
{
    //Methods inherited from NSValue seem to return an NSValue instead of an NSNumber
    return [NSNumber numberWithUnsignedInt: o];
}


enum PGTSDeleteRule
PGTSDeleteRule (const unichar rule)
{
	enum PGTSDeleteRule deleteRule = kPGTSDeleteRuleUnknown;
	switch (rule)
	{
		case ' ':
			deleteRule = kPGTSDeleteRuleNone;
			break;
			
		case 'c':
			deleteRule = kPGTSDeleteRuleCascade;
			break;
			
		case 'n':
			deleteRule = kPGTSDeleteRuleSetNull;
			break;
			
		case 'd':
			deleteRule = kPGTSDeleteRuleSetDefault;
			break;
			
		case 'r':
			deleteRule = kPGTSDeleteRuleRestrict;
			break;
			
		case 'a':
			deleteRule = kPGTSDeleteRuleNone;
			break;
			
		default:
			deleteRule = kPGTSDeleteRuleUnknown;
			break;
	}	
	
	return deleteRule;
}
