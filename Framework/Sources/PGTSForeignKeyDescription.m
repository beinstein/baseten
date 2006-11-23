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

#import <PGTS/PGTSForeignKeyDescription.h>
#import <PGTS/PGTSTableInfo.h>
#import <PGTS/PGTSFieldInfo.h>
#import <TSDataTypes/TSDataTypes.h>


static TSNonRetainedObjectSet* gForeignKeys;

@implementation PGTSForeignKeyDescription

+ (void) initialize
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        gForeignKeys = [[TSNonRetainedObjectSet alloc] init];
    }
}

- (NSArray *) sourceFields
{
    return sourceFields;
}

- (NSArray *) referenceFields
{
    return referenceFields;
}

- (PGTSTableInfo *) sourceTable
{
    return [[sourceFields objectAtIndex: 0] table];
}

- (PGTSTableInfo *) referenceTable
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
    }
    
    id anObject = nil;
    if ((anObject = [gForeignKeys member: self]))
    {
        [self release]; //This might remove anObject
        self = [anObject retain];
    }
    [gForeignKeys addObject: self];
    
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

@end
