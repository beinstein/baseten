//
// MKCPolishedCornerView.m
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

#import "MKCPolishedCornerView.h"
#import "MKCPolishedHeaderView.h"


@implementation MKCPolishedCornerView

- (void) stateChanged: (NSNotification *) notification
{
	[self setNeedsDisplay: YES];
}

- (id) initWithFrame: (NSRect) frame
{
    if ((self = [super initWithFrame: frame]))
    {
		NSWindow* window = [self window];
		NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
		[nc addObserver: self selector: @selector (stateChanged:) name: NSApplicationDidBecomeActiveNotification object: NSApp];
		[nc addObserver: self selector: @selector (stateChanged:) name: NSApplicationDidResignActiveNotification object: NSApp];
		[nc addObserver: self selector: @selector (stateChanged:) name: NSWindowDidBecomeKeyNotification object: window];
		[nc addObserver: self selector: @selector (stateChanged:) name: NSWindowDidResignKeyNotification object: window];
    }
    return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
    [mColours release];
    [super dealloc];
}

- (void) drawRect: (NSRect) rect
{
    if (nil == mColours)
        [self setColours: [MKCPolishedHeaderView darkColours]];
	
	NSDictionary* enabledColours = nil;
	if (MKCShouldDrawEnabled ([self window]))
		enabledColours = [mColours objectForKey: kMKCEnabledColoursKey];
	else
		enabledColours = [mColours objectForKey: kMKCDisabledColoursKey];

    NSRect bounds = [self bounds];
    float height = bounds.size.height;
    NSRect polishRect = rect;
    polishRect.size.height = height;
    polishRect.origin.y = 0.0;
    MKCDrawPolishInRect (polishRect, enabledColours, mDrawingMask);

    //Lines at the end
    if (kMKCPolishDrawRightAccent & mDrawingMask)
    {
        NSRect endRect = bounds;
        endRect.origin.x = bounds.size.width - 2.0;
        endRect.origin.y += 1.0;
        endRect.size.width = 1.0;
        endRect.size.height -= 2.0;
        NSRect intersection = NSIntersectionRect (endRect, rect);
        if (NO == NSIsEmptyRect (intersection))
        {
            [[enabledColours objectForKey: kMKCRightLineColourKey] set];
            NSRectFill (intersection);
        }
    }
    
    if (kMKCPolishDrawRightLine & mDrawingMask)
    {
        NSRect endRect = bounds;
        endRect.origin.x = bounds.size.width - 1.0;
        endRect.origin.y += 1.0;
        endRect.size.width = 1.0;
        endRect.size.height -= 2.0;
        NSRect intersection = NSIntersectionRect (endRect, rect);
        if (NO == NSIsEmptyRect (intersection))
        {
            [[enabledColours objectForKey: kMKCRightLineColourKey] set];
            NSRectFill (intersection);
        }
    }
    
    if (mDrawsHandle)
    {
        NSRect bottomDarkLine = NSMakeRect (1.0, 6.0, 1.0, 6.0);
        NSRect topDarkLine = NSMakeRect (1.0, 12.0, 1.0, 4.0);
        NSRect whiteLine = NSMakeRect (2.0, 5.0, 1.0, 10.0);

        NSColor* bottomDarkColor = [NSColor colorWithDeviceWhite: 91.0 / 255.0 alpha: 1.0];
        NSColor* topDarkColor = [NSColor colorWithDeviceWhite: 97.0 / 255.0 alpha: 1.0];
        NSColor* whiteColor = [NSColor whiteColor];
        
        for (int i = 0; i < 3; i++)
        {
            NSRect intersection = NSZeroRect;
            
            intersection = NSIntersectionRect (rect, bottomDarkLine);
            if (NO == NSIsEmptyRect (intersection))
            {
                [bottomDarkColor set];
                NSRectFill (intersection);
            }
            
            intersection = NSIntersectionRect (rect, topDarkLine);
            if (NO == NSIsEmptyRect (intersection))
            {
                [topDarkColor set];
                NSRectFill (intersection);
            }
            
            intersection = NSIntersectionRect (rect, whiteLine);
            if (NO == NSIsEmptyRect (whiteLine))
            {
                [whiteColor set];
                NSRectFill (intersection);
            }
            
            bottomDarkLine.origin.x += 3.0;
            topDarkLine.origin.x += 3.0;
            whiteLine.origin.x += 3.0;
        }
    }
}

- (BOOL) drawsHandle
{
    return mDrawsHandle;
}

- (void) setDrawsHandle: (BOOL) flag
{
    mDrawsHandle = flag;
}

- (NSRect) handleRect
{
    return NSMakeRect (1.0, 6.0, 8.0, 10.0);
}

- (BOOL) isFlipped
{
    return NO;
}

- (NSDictionary *) colours
{
    return mColours; 
}

- (void) setColours: (NSDictionary *) aColours
{
    if (mColours != aColours) {
        [mColours release];
        mColours = [aColours retain];
    }
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
