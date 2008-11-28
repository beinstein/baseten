//
// BXObjectStatusToColorTransformer.m
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

#import "BXObjectStatusToColorTransformer.h"
#import <BaseTen/BXDatabaseObject.h>


/**
 * \brief Transforms an object status to a colour.
 *
 * Presently, grey corresponds to a locked object and red to a deleted object.
 * \ingroup value_transformers
 */
@implementation BXObjectStatusToColorTransformer

+ (Class) transformedValueClass
{
    return [NSColor class];
}

+ (BOOL) allowsReverseTransformation
{
    return NO;
}

- (id) transformedValue: (NSValue *) objectStatus
{
    id rval = nil;
    enum BXObjectLockStatus status = kBXObjectNoLockStatus;
    [objectStatus getValue: &status];
    
    switch (status)
    {
        case kBXObjectLockedStatus:
            rval = [NSColor grayColor];
            break;
        case kBXObjectDeletedStatus:
            rval = [NSColor redColor];
            break;
        case kBXObjectNoLockStatus:
        default:
            rval = [NSColor blackColor];
    }
    
    return rval;
}

@end
