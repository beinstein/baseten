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
// $Id$
//

#import "MKCPolishedHeaderView.h"
#import "Additions.h"
#import "MKCPolishedHeaderCell.h"
#import <BaseTen/BXEnumerate.h>
#import <BaseTen/BXLogger.h>

NSString* kMKCEnabledColoursKey		 = @"kMKCEnabledColoursKey";
NSString* kMKCDisabledColoursKey	 = @"kMKCDisabledColoursKey";
NSString* kMKCSelectedColoursKey	 = @"kMKCSelectedColoursKey";

NSString* kMKCGradientKey            = @"kMKCGradientKey";
NSString* kMKCTopAccentColourKey     = @"kMKCTopAccentColourKey";
NSString* kMKCLeftAccentColourKey    = @"kMKCLeftAccentColourKey";
NSString* kMKCLeftLineColourKey      = @"kMKCLeftLineColourKey";
NSString* kMKCRightLineColourKey     = @"kMKCRightLineColourKey";
NSString* kMKCTopLineColourKey       = @"kMKCTopLineColourKey";
NSString* kMKCRightAccentColourKey   = @"kMKCRightAccentColourKey";
NSString* kMKCBottomLineColourKey    = @"kMKCBottomLineColourKey";
NSString* kMKCSeparatorLineColourKey = @"kMKCSeparatorLineColourKey";

static NSString* kKVObservingContext = @"kKVObservingContext";


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

BOOL
MKCShouldDrawEnabled (NSWindow* window)
{
#if 0
	BOOL isNonActivating = ([window styleMask] & NSNonactivatingPanelMask ? YES : NO);
	BOOL retval = ([NSApp isActive] && ([window isMainWindow] || (isNonActivating && [window isKeyWindow])));
#endif
	BOOL retval = ([NSApp isActive] && [window isKeyWindow]);
	return retval;
}



@implementation MKCPolishedHeaderView

+ (NSDictionary *) darkColours
{
	//Patch by Tim Bedford 2008-08-11
    //NSGradient* gradient = [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithDeviceRed: 191.0 / 255.0 green: 194.0 / 255.0 blue: 191.0 / 255.0 alpha: 1.0]
    //                                                  endingColor: [NSColor colorWithDeviceRed: 167.0 / 255.0 green: 148.0 / 255.0 blue: 148.0 / 255.0 alpha: 1.0]] autorelease];

	NSGradient* gradient = [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithDeviceRed: 191.0 / 255.0 green: 194.0 / 255.0 blue: 191.0 / 255.0 alpha: 1.0]
														  endingColor: [NSColor colorWithDeviceRed: 148.0 / 255.0 green: 148.0 / 255.0 blue: 148.0 / 255.0 alpha: 1.0]] autorelease];
	//End patch

	NSDictionary* enabled = [NSDictionary dictionaryWithObjectsAndKeys:
							 gradient, kMKCGradientKey,
							 [NSColor colorWithDeviceWhite: 62.0  / 255.0 alpha: 1.0], kMKCBottomLineColourKey,
							 [NSColor colorWithDeviceWhite: 224.0 / 255.0 alpha: 1.0], kMKCTopAccentColourKey,
							 [NSColor colorWithDeviceWhite: 62.0  / 255.0 alpha: 1.0], kMKCTopLineColourKey,
							 [NSColor colorWithDeviceWhite: 127.0 / 255.0 alpha: 1.0], kMKCLeftLineColourKey,
							 [NSColor colorWithDeviceWhite: 127.0 / 255.0 alpha: 1.0], kMKCRightAccentColourKey,
							 [NSColor colorWithDeviceWhite: 127.0 / 255.0 alpha: 1.0], kMKCSeparatorLineColourKey,
							 [NSColor colorWithDeviceWhite: 224.0 / 255.0 alpha: 1.0], kMKCLeftAccentColourKey,
							 nil];
	
	NSMutableDictionary* selected = [[enabled mutableCopy] autorelease];
#if 0
	gradient = [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithDeviceRed: 130.0 / 255.0 green: 147.0 / 255.0 blue: 166.0 / 255.0 alpha: 1.0]
											  endingColor: [NSColor colorWithDeviceRed: 67.0 / 255.0 green: 90.0 / 255.0 blue: 115.0 / 255.0 alpha: 1.0]] autorelease];
#endif
	gradient = [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithDeviceRed: 194.0 / 255.0 green: 207.0 / 255.0 blue: 221.0 / 255.0 alpha: 1.0]
											  endingColor: [NSColor colorWithDeviceRed: 125.0 / 255.0 green: 147.0 / 255.0 blue: 178.0 / 255.0 alpha: 1.0]] autorelease];
	[selected setObject: gradient forKey: kMKCGradientKey];

	NSMutableDictionary* disabled = [[enabled mutableCopy] autorelease];
	gradient = [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithDeviceWhite: 219.0 / 255.0 alpha: 1.0] 
											  endingColor: [NSColor colorWithDeviceWhite: 187.0 / 255.0 alpha: 1.0]] autorelease];
	[disabled setObject: gradient forKey: kMKCGradientKey];
    return [NSDictionary dictionaryWithObjectsAndKeys:
			enabled, kMKCEnabledColoursKey,
			disabled, kMKCDisabledColoursKey,
			selected, kMKCSelectedColoursKey,
			nil];
}

+ (NSDictionary *) lightColours
{
    NSGradient* gradient = [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithDeviceWhite: 254.0 / 255.0 alpha: 1.0]
                                                      endingColor: [NSColor colorWithDeviceRed: 211.0 / 255.0 green: 211.0 / 255.0 blue: 210.0 / 255.0 alpha: 1.0]] autorelease];
    NSColor* borderColour = [NSColor colorWithDeviceWhite: 141.0 / 255.0 alpha: 1.0];
    NSDictionary* enabled = [NSDictionary dictionaryWithObjectsAndKeys:
							 gradient, kMKCGradientKey,
							 borderColour, kMKCTopLineColourKey,
							 borderColour, kMKCBottomLineColourKey,
							 borderColour, kMKCLeftLineColourKey,
							 [NSColor colorWithDeviceWhite: 190.0 / 255.0 alpha: 1.0], kMKCRightLineColourKey,
							 [NSColor whiteColor], kMKCLeftAccentColourKey,
							 [NSColor blueColor], kMKCRightAccentColourKey,
							 nil];    
	NSDictionary* disabled = enabled;
	NSDictionary* selected = enabled;
	return [NSDictionary dictionaryWithObjectsAndKeys:
			enabled, kMKCEnabledColoursKey,
			disabled, kMKCDisabledColoursKey,
			selected, kMKCSelectedColoursKey,
			nil];
	
}

+ (NSDictionary *) testColours
{
    NSGradient* gradient = [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithDeviceWhite: 254.0 / 255.0 alpha: 1.0]
                                                      endingColor: [NSColor colorWithDeviceRed: 211.0 / 255.0 green: 211.0 / 255.0 blue: 210.0 / 255.0 alpha: 1.0]] autorelease];
    NSDictionary* enabled = [NSDictionary dictionaryWithObjectsAndKeys:
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
	NSDictionary* disabled = enabled;
	NSDictionary* selected = enabled;
	return [NSDictionary dictionaryWithObjectsAndKeys:
			enabled, kMKCEnabledColoursKey,
			disabled, kMKCDisabledColoursKey,
			selected, kMKCSelectedColoursKey,
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

- (void) stateChanged: (NSNotification *) notification
{
	[self setNeedsDisplay: YES];
}

- (void) awakeFromNib
{
	NSKeyValueObservingOptions options = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial;
	[[self tableView] addObserver: self forKeyPath: @"sortDescriptors" options: options context: kKVObservingContext];
	
	NSWindow* window = [self window];
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc addObserver: self selector: @selector (stateChanged:) name: NSApplicationDidBecomeActiveNotification object: NSApp];
	[nc addObserver: self selector: @selector (stateChanged:) name: NSApplicationDidResignActiveNotification object: NSApp];
	[nc addObserver: self selector: @selector (stateChanged:) name: NSWindowDidBecomeKeyNotification object: window];
	[nc addObserver: self selector: @selector (stateChanged:) name: NSWindowDidResignKeyNotification object: window];
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[[self tableView] removeObserver: self forKeyPath: @"sortDescriptors"];
    [mColours release];
    [super dealloc];
}

- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object change: (NSDictionary *) change context: (void *) context
{
    if (kKVObservingContext == context) 
	{
		if (mColumnSortedBy)
		{
			NSInteger index = [[[self tableView] tableColumns] indexOfObject: mColumnSortedBy];
			if (0 <= index)
				[self setNeedsDisplayInRect: [self headerRectOfColumn: index]];
		}
		
		mColumnSortedBy = nil;
		mReversedOrder = NO;
		
		NSArray* newDescs = [change objectForKey: NSKeyValueChangeNewKey];
		if (0 < [newDescs count])
		{
			NSSortDescriptor* d1 = [newDescs objectAtIndex: 0];
			NSSortDescriptor* d2 = [d1 reversedSortDescriptor];
			
			NSInteger i = 0;
			BXEnumerate (currentColumn, e, [[[self tableView] tableColumns] objectEnumerator])
			{
				NSSortDescriptor* currentDesc = [currentColumn sortDescriptorPrototype];
				if ([currentDesc isEqual: d1])
				{
					mColumnSortedBy = currentColumn;
					break;
				}
				else if ([currentDesc isEqual: d2])
				{
					mColumnSortedBy = currentColumn;
					mReversedOrder = YES;
					break;
				}
				i++;
			}
			if (i < [[[self tableView] tableColumns] count])
				[self setNeedsDisplayInRect: [self headerRectOfColumn: i]];
		}
	}
	else 
	{
		[super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
	}
}


- (NSRect) headerRectOfColumn: (NSInteger) columnIndex
{
    NSRect rect = [super headerRectOfColumn: columnIndex];
    BXAssertLog (rect.size.height == [self frame].size.height, @"Expected heights to match.");
    return rect;
}

- (NSInteger) columnAtPoint: (NSPoint) point
{
    return [super columnAtPoint: point];
}

- (void) drawRect: (NSRect) rect
{
    if (nil == mColours)
        [self setColours: [[self class] darkColours]];
    
    float height = [self bounds].size.height;
    BXAssertVoidReturn (height >= 3.0, @"This view may not be shorter than 3.0 units.");
    
	NSDictionary* enabledColours = nil;
	NSDictionary* selectedColours = nil;
	if (MKCShouldDrawEnabled ([self window]))
	{
		enabledColours = [mColours objectForKey: kMKCEnabledColoursKey];
		selectedColours = [mColours objectForKey: kMKCSelectedColoursKey];
	}
	else
	{
		enabledColours = [mColours objectForKey: kMKCDisabledColoursKey];
		selectedColours = [mColours objectForKey: kMKCDisabledColoursKey];
	}

	{
	    NSRect polishRect = rect;
	    polishRect.size.height = height;
	    //polishRect.origin.y = 0.0;
		if (! mColumnSortedBy)
		    MKCDrawPolishInRect (polishRect, enabledColours, mDrawingMask);
		else
		{
			NSInteger sortColumn = [[[self tableView] tableColumns] indexOfObject: mColumnSortedBy];
			NSRect sortColumnRect = [self headerRectOfColumn: sortColumn];
			if (NSContainsRect (sortColumnRect, polishRect))
			{
				//Fill only the sorting column.
				MKCDrawPolishInRect (polishRect, selectedColours, mDrawingMask);
			}
			else if (! NSIntersectsRect (sortColumnRect, polishRect))
			{
				//Fill other columns than the sorting column.
				MKCDrawPolishInRect (polishRect, enabledColours, mDrawingMask);
			}
			else
			{
				//Divide the area into three parts and fill them.
				if (polishRect.origin.x < sortColumnRect.origin.x)
				{
					NSRect leftPart = polishRect;
					leftPart.size.width = sortColumnRect.origin.x;
					MKCDrawPolishInRect (leftPart, enabledColours, mDrawingMask);
				}
				
				MKCDrawPolishInRect (sortColumnRect, selectedColours, mDrawingMask);
				
				float padding = sortColumnRect.origin.x + sortColumnRect.size.width;
				if (polishRect.origin.x + polishRect.size.width > padding)
				{
					NSRect rightPart = polishRect;
					rightPart.size.width += rightPart.origin.x;
					rightPart.size.width -= padding;
					rightPart.origin.x = padding;
					MKCDrawPolishInRect (rightPart, enabledColours, mDrawingMask);
				}
			}
		}
	}

    NSTableView* tableView = [self tableView];
    NSArray* tableColumns = [tableView tableColumns];
	
    for (int count = [tableView numberOfColumns], i = count - 1; i >= 0; i--)
    {
        NSRect columnHeaderRect = [self headerRectOfColumn: i];
		NSTableColumn* column = [tableColumns objectAtIndex: i];
        
        NSPoint end = columnHeaderRect.origin;
        end.x += columnHeaderRect.size.width - 1.0;
        end.y += columnHeaderRect.size.height - 1.0;
		
		NSDictionary* colours = nil;
		if (column == mColumnSortedBy)
			colours = selectedColours;
		else
			colours = enabledColours;
		
        if (kMKCPolishDrawSeparatorLines & mDrawingMask && 
			(i != count - 1 || column == mColumnSortedBy) && 
			NSPointInRect (end, rect))
        {
            [[colours objectForKey: kMKCSeparatorLineColourKey] set];
            NSRectFill (NSMakeRect (end.x, 1.0, 1.0, height - 2.0));
        }
        
        if (kMKCPolishDrawLeftAccent & mDrawingMask)
        {
			if (0 != i || ! (kMKCPolishNoLeftAccentForLeftmostColumn & mDrawingMask))
			{
	            [[colours objectForKey: kMKCLeftAccentColourKey] set];
	            NSRectFill (NSMakeRect (columnHeaderRect.origin.x, 1.0, 1.0, height - 2.0));
			}
        }
        
        NSRect intersection = NSIntersectionRect (columnHeaderRect, rect);
        if (NO == NSIsEmptyRect (intersection))
        {
			//Calculate the field bounds.
			columnHeaderRect.origin.x += 5.0;
			columnHeaderRect.size.width -= 5.0;

			id headerCell = [column headerCell];
			if (! [headerCell isKindOfClass: [MKCPolishedHeaderCell class]])
			{
				NSString* title = [headerCell stringValue];
				headerCell = [[[MKCPolishedHeaderCell alloc] initTextCell: title] autorelease];
				[column setHeaderCell: headerCell];
				[headerCell makeEtchedSmall: YES]; //Patch by Tim Bedford 2008-08-11
			}
			
			if (column == mColumnSortedBy)
				[headerCell drawSortIndicatorWithFrame: columnHeaderRect inView: self ascending: !mReversedOrder priority: 0];
			[headerCell drawWithFrame: columnHeaderRect inView: self];
        }
    }
}

- (void) _drawHeaderFillerInRect: (NSRect) rect matchLastState: (char) flag
{
    MKCDrawPolishInRect (rect, [mColours objectForKey: kMKCEnabledColoursKey], mDrawingMask);
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
