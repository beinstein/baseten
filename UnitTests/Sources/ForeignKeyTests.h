//
// ForeignKeyTests.h
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
#import "BXTestCase.h"
@class BXDatabaseContext;


@interface ForeignKeyTests : BXDatabaseTestCase 
{
    BXEntityDescription* mTest1;
    BXEntityDescription* mTest2;
    BXEntityDescription* mOtotest1;
    BXEntityDescription* mOtotest2;
    BXEntityDescription* mMtmtest1;
    BXEntityDescription* mMtmtest2;
    
    BXEntityDescription* mTest1v;
    BXEntityDescription* mTest2v;
    BXEntityDescription* mOtotest1v;
    BXEntityDescription* mOtotest2v;
    BXEntityDescription* mMtmtest1v;
    BXEntityDescription* mMtmtest2v;
	BXEntityDescription* mMtmrel1;
}

- (void) many: (BXEntityDescription *) manyEntity toOne: (BXEntityDescription *) oneEntity;
- (void) one: (BXEntityDescription *) oneEntity toMany: (BXEntityDescription *) manyEntity;
- (void) one: (BXEntityDescription *) entity1 toOne: (BXEntityDescription *) entity2;
- (void) many: (BXEntityDescription *) entity1 toMany: (BXEntityDescription *) entity2;
- (void) MTMHelper: (BXEntityDescription *) entity;
@end
