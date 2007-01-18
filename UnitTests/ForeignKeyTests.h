//
// ForeignKeyTests.h
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

#import <SenTestingKit/SenTestingKit.h>
@class BXDatabaseContext;


@interface ForeignKeyTests : SenTestCase 
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

- (void) many: (BXEntityDescription *) manyEntity toOne: (BXEntityDescription *) oneEntity;
- (void) one: (BXEntityDescription *) oneEntity toMany: (BXEntityDescription *) manyEntity;
- (void) one: (BXEntityDescription *) entity1 toOne: (BXEntityDescription *) entity2;
- (void) many: (BXEntityDescription *) entity1 toMany: (BXEntityDescription *) entity2;
- (void) modMany: (BXEntityDescription *) manyEntity toOne: (BXEntityDescription *) oneEntity;
- (void) modOne: (BXEntityDescription *) oneEntity toMany: (BXEntityDescription *) manyEntity;
- (void) modOne: (BXEntityDescription *) entity1 toOne: (BXEntityDescription *) entity2;
- (void) MTMHelper: (BXEntityDescription *) entity;

@end
