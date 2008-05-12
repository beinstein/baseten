//
// Entity.m
// BaseTen Setup
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

#import "Entity.h"
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <PGTS/PGTS.h>


@implementation Entity

+ (void) initialize
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        [self setKeys: [NSArray arrayWithObject: @"alreadyExists"] triggerChangeNotificationsForDependentKey: 
            @"textColor"];
    }
}

- (id) init
{
    if ((self = [super init]))
    {
        alreadyExists = NO;
    }
    return self;
}

- (void) dealloc
{
    [schemaName release];
    [entityDescription release];
    [identifier release];
    
    [super dealloc];
}

- (NSEntityDescription *) entityDescription
{
    return entityDescription; 
}

- (void) setEntityDescription: (NSEntityDescription *) anEntityDescription
{
    if (entityDescription != anEntityDescription) {
        [entityDescription release];
        entityDescription = [anEntityDescription retain];
    }
}

- (BOOL) alreadyExists
{
    return alreadyExists;
}

- (void) setAlreadyExists: (BOOL) flag
{
    alreadyExists = flag;
}

- (id) identifier
{
    return identifier; 
}

- (void) setIdentifier: (id) anIdentifier
{
    if (identifier != anIdentifier) {
        [identifier release];
        identifier = [anIdentifier retain];
    }
}

- (BOOL) shouldImport
{
	return shouldImport;
}

- (void) setShouldImport: (BOOL) flag
{
	shouldImport = flag;
}

- (NSString *) schemaName
{
    return schemaName; 
}

- (void) setSchemaName: (NSString *) aSchemaName
{
    if (schemaName != aSchemaName) {
        [schemaName release];
        schemaName = [aSchemaName retain];
    }
}

- (NSArray *) attributes
{
    return [[entityDescription attributesByName] allValues];
}


@end
