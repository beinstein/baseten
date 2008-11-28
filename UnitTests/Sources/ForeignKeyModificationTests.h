//
// ForeignKeyModificationTests.h
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

#import <SenTestingKit/SenTestingKit.h>
#import "TestLoader.h"
@class BXDatabaseContext;


@interface ForeignKeyModificationTests : BXTestCase 
{
    BXDatabaseContext* context;
    BXEntityDescription* test1;
    BXEntityDescription* test2;
    BXEntityDescription* ototest1;
    BXEntityDescription* ototest2;
    BXEntityDescription* mtmtest1;
    BXEntityDescription* mtmtest2;
    
    BXEntityDescription* test1v;
    BXEntityDescription* test2v;
    BXEntityDescription* ototest1v;
    BXEntityDescription* ototest2v;
    BXEntityDescription* mtmtest1v;
    BXEntityDescription* mtmtest2v;
	BXEntityDescription* mtmrel1;
}

- (void) modMany: (BXEntityDescription *) manyEntity toOne: (BXEntityDescription *) oneEntity;
- (void) modOne: (BXEntityDescription *) oneEntity toMany: (BXEntityDescription *) manyEntity;
- (void) modOne: (BXEntityDescription *) entity1 toOne: (BXEntityDescription *) entity2;
- (void) remove1: (BXEntityDescription *) oneEntity;
- (void) remove2: (BXEntityDescription *) oneEntity;
@end
