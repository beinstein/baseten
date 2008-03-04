//
// MKCPolishedHeaderView.h
// BaseTen Setup
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
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
// $Id: MKCPolishedHeaderView.h 246 2008-03-04 11:53:29Z tuukka.norri@karppinen.fi $
//

#import <Cocoa/Cocoa.h>


extern NSString* kMKCGradientKey;
extern NSString* kMKCTopAccentColourKey;
extern NSString* kMKCLeftAccentColourKey;
extern NSString* kMKCLeftLineColourKey;
extern NSString* kMKCRightLineColourKey;
extern NSString* kMKCTopLineColourKey;
extern NSString* kMKCBottomLineColourKey;
extern NSString* kMKCRightAccentColourKey;
extern NSString* kMKCSeparatorLineColourKey;


enum MKCPolishDrawingMask {
    kMKCPolishDrawingMaskEmpty   = 0,
    kMKCPolishDrawTopLine        = 1 << 1,
    kMKCPolishDrawBottomLine     = 1 << 2,
    kMKCPolishDrawLeftLine       = 1 << 3,
    kMKCPolishDrawRightLine      = 1 << 4,
    kMKCPolishDrawTopAccent      = 1 << 5,
    kMKCPolishDrawLeftAccent     = 1 << 8,
    kMKCPolishDrawRightAccent    = 1 << 9,
    kMKCPolishDrawSeparatorLines = 1 << 10,
    MKCPolishDrawAllLines = (kMKCPolishDrawTopLine | 
                             kMKCPolishDrawBottomLine | 
                             kMKCPolishDrawLeftLine | 
                             kMKCPolishDrawRightLine | 
                             kMKCPolishDrawTopAccent | 
                             kMKCPolishDrawLeftAccent | 
                             kMKCPolishDrawRightAccent | 
                             kMKCPolishDrawSeparatorLines),
    kMKCPolishDrawingMaskInvalid = 1 << 31
};


void
MKCDrawPolishInRect (NSRect rect, NSDictionary* colours, enum MKCPolishDrawingMask mask);


@interface MKCPolishedHeaderView : NSTableHeaderView 
{
    id mHeaderFields;
    NSDictionary* mColours;
    enum MKCPolishDrawingMask mDrawingMask;
}

+ (NSDictionary *) darkColours;
+ (NSDictionary *) lightColours;
+ (NSDictionary *) testColours;

- (NSDictionary *) colours;
- (void) setColours: (NSDictionary *) aColours;
- (enum MKCPolishDrawingMask) drawingMask;
- (void) setDrawingMask: (enum MKCPolishDrawingMask) aDrawingMask;

@end
