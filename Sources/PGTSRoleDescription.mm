//
// PGTSRoleDescription.mm
// BaseTen
//
// Copyright (C) 2006-2009 Marko Karppinen & Co. LLC.
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


#import "PGTSRoleDescription.h"
#import "BXLogger.h"


using namespace PGTS;


@implementation PGTSRoleDescription
- (id) init
{
	if ((self = [super init]))
	{
		mMembersByOid = new OidMap ();
	}
	return self;
}

- (void) dealloc
{
	for (OidMap::const_iterator it = mMembersByOid->begin (); mMembersByOid->end () != it; it++)
		[it->second release];
	
	delete mMembersByOid;
    
	[super dealloc];
}

- (void) finalize
{
	delete mMembersByOid;
	[super finalize];
}

/** 
 * \brief Check if given role is member of self.
 */
- (BOOL) hasMember: (PGTSRoleDescription *) aRole
{
	ExpectR (aRole, NO);
	return (FindObject (mMembersByOid, [aRole oid]) ? YES : NO);
}

- (void) addMember: (PGTSRoleDescription *) aRole
{
	ExpectV (aRole);
	InsertConditionally (mMembersByOid, aRole);
}
@end
