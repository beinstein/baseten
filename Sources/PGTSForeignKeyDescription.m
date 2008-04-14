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
#import "PGTSTableInfo.h"
#import "PGTSFieldInfo.h"
#import "PGTSFunctions.h"


static enum PGTSDeleteRule
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


@implementation PGTSForeignKeyDescription

- (NSArray *) sourceFields
{
    return sourceFields;
}

- (NSArray *) referenceFields
{
    return referenceFields;
}

- (PGTSTableDescription *) sourceTable
{
    return [[sourceFields objectAtIndex: 0] table];
}

- (PGTSTableDescription *) referenceTable
{
    return [[referenceFields objectAtIndex: 0] table];
}

- (id) initWithConnection: (PGTSConnection *) aConnection 
                     name: (NSString *) aName 
             sourceFields: (NSArray *) sFields 
          referenceFields: (NSArray *) rFields
{
    if ((self = [super initWithConnection: aConnection]))
    {
        hash = 0;
        name = [aName copy];
        sourceFields = [sFields copy];
        referenceFields = [rFields copy];
		deleteRule = kPGTSDeleteRuleUnknown;
    }
    return self;
}

- (unsigned int) hash
{
    if (0 == hash)
    {
        hash = ([super hash] ^ [sourceFields hash] ^ [referenceFields hash]);
    }
    return hash;
}

- (enum PGTSDeleteRule) deleteRule
{
	return deleteRule;
}

- (void) setDeleteRule: (const unichar) rule
{
	deleteRule = PGTSDeleteRule (rule);
}

@end
