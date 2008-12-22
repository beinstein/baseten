//
// PGTSForeignKeyDescription.m
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

#import "PGTSForeignKeyDescription.h"
#import "PGTSTableDescription.h"
#import "PGTSFieldDescription.h"


@implementation PGTSForeignKeyDescriptionProxy
@end


@implementation PGTSForeignKeyDescription

//FIXME: dealloc is missing.

- (NSArray *) sourceFields
{
    return mSourceFields;
}

- (NSArray *) referenceFields
{
    return mReferenceFields;
}

#if 0
- (PGTSTableDescription *) sourceTable
{
    return [[mSourceFields objectAtIndex: 0] table];
}

- (PGTSTableDescription *) referenceTable
{
    return [[mReferenceFields objectAtIndex: 0] table];
}
#endif

- (id) initWithName: (NSString *) aName 
	   sourceFields: (NSArray *) sFields 
	referenceFields: (NSArray *) rFields
{
    if ((self = [super init]))
    {
        mHash = 0;
        mName = [aName copy];
        mSourceFields = [sFields copy];
        mReferenceFields = [rFields copy];
		mDeleteRule = kPGTSDeleteRuleUnknown;
    }
    return self;
}

- (unsigned int) hash
{
    if (0 == mHash)
    {
        mHash = ([super hash] ^ [mSourceFields hash] ^ [mReferenceFields hash]);
    }
    return mHash;
}

- (enum PGTSDeleteRule) deleteRule
{
	return mDeleteRule;
}

- (void) setDeleteRule: (const unichar) rule
{
	mDeleteRule = PGTSDeleteRule (rule);
}

- (Class) proxyClass
{
	return [PGTSForeignKeyDescriptionProxy class];
}
@end
