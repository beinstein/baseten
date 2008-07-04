//
// MKCAlternativeDataCellColumn.m
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
// $Id: MKCAlternativeDataCellColumn.m 241 2008-02-22 16:08:56Z tuukka.norri@karppinen.fi $
//

#import "MKCAlternativeDataCellColumn.h"

@interface NSObject (MKCAlternativeDataCellColumnAdditions)
- (id) MKCTableView: (NSTableView *) tableView 
  dataCellForColumn: (MKCAlternativeDataCellColumn *) aColumn
                row: (int) rowIndex;
@end


@implementation MKCAlternativeDataCellColumn

- (id) dataCellForRow: (int) rowIndex
{
    id retval = nil;
    if (-1 == rowIndex)
        retval = [super dataCell];
    else
    {
        id tableView = [self tableView];
        retval = [[tableView delegate] MKCTableView: tableView dataCellForColumn: self row: rowIndex];
        if (nil == retval)
            retval = [super dataCellForRow: rowIndex];
    }
    return retval;
}

@end
