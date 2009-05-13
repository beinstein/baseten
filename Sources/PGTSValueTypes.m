//
// PGTSValueTypes.m
// BaseTen
//
// Copyright (C) 2008-2009 Marko Karppinen & Co. LLC.
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


#import "PGTSValueTypes.h"
#import "PGTSTypeDescription.h"
#import "PGTSResultSet.h"


@implementation PGTSFloat
+ (id) copyForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    return [[NSNumber alloc] initWithFloat: strtof (value, NULL)];
}
@end


@implementation PGTSDouble
+ (id) copyForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    return [[NSNumber alloc] initWithDouble: strtod (value, NULL)];
}
@end


@implementation PGTSBool
+ (id) copyForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    BOOL boolValue = (value [0] == 't' ? YES : NO);
    return [[NSNumber alloc] initWithBool: boolValue];
}
@end


@implementation PGTSPoint
+ (id) copyForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    NSPoint retval = NSZeroPoint;
    NSString* pointString = [NSString stringWithUTF8String: value];
    NSScanner* pointScanner = [NSScanner scannerWithString: pointString];
    [pointScanner setScanLocation: 1];
	
#if CGFLOAT_IS_DOUBLE
    [pointScanner scanDouble: &(retval.x)];
#else
    [pointScanner scanFloat: &(retval.x)];
#endif
	
    [pointScanner setScanLocation: [pointScanner scanLocation] + 1];
	
#if CGFLOAT_IS_DOUBLE
    [pointScanner scanDouble: &(retval.y)];
#else
    [pointScanner scanFloat: &(retval.y)];
#endif
	
    return [[NSValue valueWithPoint: retval] retain];
}
@end
