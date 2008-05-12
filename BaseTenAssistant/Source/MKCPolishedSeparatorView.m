//
// MKCPolishedSeparatorView.m
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
// $Id: MKCPolishedSeparatorView.m 241 2008-02-22 16:08:56Z tuukka.norri@karppinen.fi $
//

#import "MKCPolishedSeparatorView.h"


@implementation MKCPolishedSeparatorView

- (id) initWithFrame: (NSRect) frame 
{
    if ((self = [super initWithFrame: frame]))
    {
    }
    return self;
}

- (BOOL) isFlipped
{
    return YES;
}

- (void) drawRect: (NSRect) rect 
{
    NSRect intersection = NSZeroRect;

    NSRect topRect =  NSMakeRect (0.0, 0.0, 1.0, 1.0);
    if (NSIntersectsRect (rect, topRect))
    {
        [[NSColor blackColor] set];
        NSRectFill (topRect);
    }
    
    NSRect topRect2 = NSMakeRect (0.0, 1.0, 1.0, 21.0);
    if (NSIntersectsRect (rect, topRect2))
    {
        [[NSColor colorWithDeviceWhite: 127.0 / 255.0 alpha: 1.0] set];
        NSRectFill (topRect2);
    }
    
    NSRect topRect3 = NSMakeRect (0.0, 22.0, 1.0, 1.0);
    if (NSIntersectsRect (rect, topRect3))
    {
        [[NSColor colorWithDeviceWhite: 62.0 / 255.0 alpha: 1.0] set];
        NSRectFill (topRect3);
    }
    
    NSRect bottomRect = NSMakeRect (0.0, 23.0, 1.0, [self frame].size.height - 23.0);
    intersection = NSIntersectionRect (rect, bottomRect);
    if (NO == NSIsEmptyRect (intersection))
    {
        [[NSColor colorWithDeviceWhite: 178.0 / 255.0 alpha: 1.0] set];
        NSRectFill (intersection);
    }
}

@end
