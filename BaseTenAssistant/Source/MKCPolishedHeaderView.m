//
// MKCPolishedHeaderView.m
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
// $Id: MKCPolishedHeaderView.m 246 2008-03-04 11:53:29Z tuukka.norri@karppinen.fi $
//

#import "MKCPolishedHeaderView.h"
#import "Additions.h"
#import "MKCPolishedHeaderCell.h"
#import <BaseTen/BXDatabaseAdditions.h>
#import <MKCCollections/MKCCollections.h>


NSString* kMKCGradientKey            = @"kMKCGradientKey";
NSString* kMKCTopAccentColourKey     = @"kMKCTopAccentColourKey";
NSString* kMKCLeftAccentColourKey    = @"kMKCLeftAccentColourKey";
NSString* kMKCLeftLineColourKey      = @"kMKCLeftLineColourKey";
NSString* kMKCRightLineColourKey     = @"kMKCRightLineColourKey";
NSString* kMKCTopLineColourKey       = @"kMKCTopLineColourKey";
NSString* kMKCRightAccentColourKey   = @"kMKCRightAccentColourKey";
NSString* kMKCBottomLineColourKey    = @"kMKCBottomLineColourKey";
NSString* kMKCSeparatorLineColourKey = @"kMKCSeparatorLineColourKey";


void
MKCDrawPolishInRect (NSRect rect, NSDictionary* colours, enum MKCPolishDrawingMask mask)
{
    NSCAssert (nil != colours, @"Expected colours not to be nil.");
    
    float width = rect.size.width;
    BOOL isFlipped = [[NSGraphicsContext currentContext] isFlipped];
    
    if (0.0 < width)
    {
        NSRect drawingRect = NSZeroRect;
        
        if (kMKCPolishDrawBottomLine & mask)
        {
            NSDivideRect (rect, &drawingRect, &rect, 1.0, (isFlipped ? NSMaxYEdge: NSMinYEdge));
            [[colours objectForKey: kMKCBottomLineColourKey] set];
            NSRectFill (drawingRect);
        }
        
        if (kMKCPolishDrawTopLine & mask)
        {
            NSDivideRect (rect, &drawingRect, &rect, 1.0, (isFlipped ? NSMinYEdge : NSMaxYEdge));
            [[colours objectForKey: kMKCTopLineColourKey] set];
            NSRectFill (drawingRect);
        }
        
        if (kMKCPolishDrawTopAccent & mask)
        {
            NSDivideRect (rect, &drawingRect, &rect, 1.0, (isFlipped ? NSMinYEdge : NSMaxYEdge));
            [[colours objectForKey: kMKCTopAccentColourKey] set];
            NSRectFill (drawingRect);
        }
        
        NSGradient* gradient = [colours objectForKey: kMKCGradientKey];
        [gradient drawInRect: rect angle: (isFlipped ? 90.0 : 270.0)];
    }
}


@implementation MKCPolishedHeaderView

+ (NSDictionary *) darkColours
{
    NSGradient* gradient = [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithDeviceRed: 191.0 / 255.0 green: 194.0 / 255.0 blue: 191.0 / 255.0 alpha: 1.0]
                                                      endingColor: [NSColor colorWithDeviceRed: 147.0 / 255.0 green: 148.0 / 255.0 blue: 148.0 / 255.0 alpha: 1.0]] autorelease];
    return [NSDictionary dictionaryWithObjectsAndKeys:
        gradient, kMKCGradientKey,
        [NSColor colorWithDeviceWhite: 62.0  / 255.0 alpha: 1.0], kMKCBottomLineColourKey,
        [NSColor colorWithDeviceWhite: 224.0 / 255.0 alpha: 1.0], kMKCTopAccentColourKey,
        [NSColor colorWithDeviceWhite: 62.0  / 255.0 alpha: 1.0], kMKCTopLineColourKey,
        [NSColor colorWithDeviceWhite: 127.0 / 255.0 alpha: 1.0], kMKCLeftLineColourKey,
        [NSColor colorWithDeviceWhite: 127.0 / 255.0 alpha: 1.0], kMKCRightAccentColourKey,
        [NSColor colorWithDeviceWhite: 127.0 / 255.0 alpha: 1.0], kMKCSeparatorLineColourKey,
        [NSColor colorWithDeviceWhite: 224.0 / 255.0 alpha: 1.0], kMKCLeftAccentColourKey,
        nil];
}

+ (NSDictionary *) lightColours
{
    NSGradient* gradient = [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithDeviceWhite: 254.0 / 255.0 alpha: 1.0]
                                                      endingColor: [NSColor colorWithDeviceRed: 211.0 / 255.0 green: 211.0 / 255.0 blue: 210.0 / 255.0 alpha: 1.0]] autorelease];
    NSColor* borderColour = [NSColor colorWithDeviceWhite: 141.0 / 255.0 alpha: 1.0];
    return [NSDictionary dictionaryWithObjectsAndKeys:
        gradient, kMKCGradientKey,
        borderColour, kMKCTopLineColourKey,
        borderColour, kMKCBottomLineColourKey,
        borderColour, kMKCLeftLineColourKey,
		[NSColor colorWithDeviceWhite: 190.0 / 255.0 alpha: 1.0], kMKCRightLineColourKey,
        [NSColor whiteColor], kMKCLeftAccentColourKey,
        [NSColor blueColor], kMKCRightAccentColourKey,
        nil];    
}

+ (NSDictionary *) testColours
{
    NSGradient* gradient = [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithDeviceWhite: 254.0 / 255.0 alpha: 1.0]
                                                      endingColor: [NSColor colorWithDeviceRed: 211.0 / 255.0 green: 211.0 / 255.0 blue: 210.0 / 255.0 alpha: 1.0]] autorelease];
    return [NSDictionary dictionaryWithObjectsAndKeys:
        gradient, kMKCGradientKey,
        [NSColor redColor], kMKCBottomLineColourKey,
        [NSColor yellowColor], kMKCTopAccentColourKey,
        [NSColor greenColor], kMKCTopLineColourKey,
        [NSColor purpleColor], kMKCLeftLineColourKey,
        [NSColor cyanColor], kMKCRightLineColourKey,
        [NSColor whiteColor], kMKCLeftAccentColourKey,
        [NSColor blueColor], kMKCRightAccentColourKey,
        [NSColor brownColor], kMKCSeparatorLineColourKey,
        nil];    
}

- (NSDictionary *) colours
{
    return mColours; 
}

- (void) setColours: (NSDictionary *) aColours
{
    if (mColours != aColours) 
    {
        [mColours release];
        mColours = [aColours retain];        
    }
}

- (id) initWithFrame: (NSRect) aRect
{
    if ((self = [super initWithFrame: aRect]))
    {
        mDrawingMask = kMKCPolishDrawingMaskInvalid;		
        [self setAutoresizesSubviews: YES];
    }
    return self;
}

- (void) dealloc
{
    [mColours release];
    [super dealloc];
}

- (NSRect) headerRectOfColumn: (int) columnIndex
{
    NSRect rect = [super headerRectOfColumn: columnIndex];
    NSAssert (rect.size.height == [self frame].size.height, @"Expected heights to match.");
    return rect;
}

- (int) columnAtPoint: (NSPoint) point
{
    return [super columnAtPoint: point];
}

- (void) drawRect: (NSRect) rect
{
    if (nil == mColours)
        [self setColours: [[self class] darkColours]];
    if (kMKCPolishDrawingMaskInvalid == mDrawingMask)
        [self setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopLine | kMKCPolishDrawTopAccent];
    
    float height = [self bounds].size.height;
    NSAssert (height >= 3.0, @"This view may not be shorter than 3.0 units.");
    
    NSRect polishRect = rect;
    polishRect.size.height = height;
    polishRect.origin.y = 0.0;
    MKCDrawPolishInRect (polishRect, mColours, mDrawingMask);

    NSTableView* tableView = [self tableView];
    NSArray* tableColumns = [tableView tableColumns];
			
    //NSRect headerFieldRect = NSZeroRect;
    for (int count = [tableView numberOfColumns], i = count - 1; i >= 0; i--)
    {
        NSRect columnHeaderRect = [self headerRectOfColumn: i];
        
        NSPoint end = columnHeaderRect.origin;
        end.x += columnHeaderRect.size.width - 1.0;
        end.y += columnHeaderRect.size.height - 1.0;
        if (kMKCPolishDrawSeparatorLines & mDrawingMask && i != count - 1 && NSPointInRect (end, rect))
        {
            [[mColours objectForKey: kMKCSeparatorLineColourKey] set];
            NSRectFill (NSMakeRect (end.x, 1.0, 1.0, height - 2.0));
        }
        
        if (kMKCPolishDrawLeftAccent & mDrawingMask)
        {
            [[mColours objectForKey: kMKCLeftAccentColourKey] set];
            NSRectFill (NSMakeRect (columnHeaderRect.origin.x, 1.0, 1.0, height - 2.0));
        }
        
        NSRect intersection = NSIntersectionRect (columnHeaderRect, rect);
        if (NO == NSIsEmptyRect (intersection))
        {
			//Calculate the field bounds.
			columnHeaderRect.origin.x += 5.0;
			columnHeaderRect.size.width -= 5.0;

			NSTableColumn* column = [tableColumns objectAtIndex: i];
			id headerCell = [column headerCell];
			if (! [headerCell isKindOfClass: [MKCPolishedHeaderCell class]])
			{
				NSString* title = [headerCell stringValue];
				headerCell = [[[MKCPolishedHeaderCell alloc] initTextCell: title] autorelease];
				[column setHeaderCell: headerCell];
				[headerCell makeEtchedSmall: NO];
			}
			[headerCell drawWithFrame: columnHeaderRect inView: self];
        }
    }
}

- (void) _drawHeaderFillerInRect: (NSRect) rect matchLastState: (char) flag
{
    MKCDrawPolishInRect (rect, mColours, mDrawingMask);
}

- (BOOL) isFlipped
{
    return NO;
}

- (enum MKCPolishDrawingMask) drawingMask
{
    return mDrawingMask;
}

- (void) setDrawingMask: (enum MKCPolishDrawingMask) aDrawingMask
{
    mDrawingMask = aDrawingMask;
}

@end
