/*

File: StickyTitleBarView.m

Abstract: An NSView subclass for the title bar of a sticky

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Computer, Inc. ("Apple") in consideration of your agreement to the
following terms, and your use, installation, modification or
redistribution of this Apple software constitutes acceptance of these
terms.  If you do not agree with these terms, please do not use,
install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software. 
Neither the name, trademarks, service marks or logos of Apple Computer,
Inc. may be used to endorse or promote products derived from the Apple
Software without specific prior written permission from Apple.  Except
as expressly stated in this notice, no other rights or licenses, express
or implied, are granted by Apple herein, including but not limited to
any patent rights that may be infringed by your derivative works or by
other works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright © 2005 Apple Computer, Inc., All Rights Reserved

*/

#import "StickyTitleBarView.h"

// This should be calculated, not hard-wired, but this simplifies the example code
const NSRect closeBox = {3, 2, 8, 8};

@implementation StickyTitleBarView

- (id)initWithFrame:(NSRect)frame 
{
	self = [super initWithFrame:frame];
	if (self) {
		mouseInCloseBox = trackingCloseBoxHit = NO;
    }
	return self;
}

- (void)drawRect:(NSRect)rect 
{
	NSRect border = [self bounds];
	[[NSColor yellowColor] set];
	NSRectFill(border);
	[[NSColor brownColor] set];
	NSFrameRect(border);
	mouseInCloseBox ? NSRectFill(closeBox): NSFrameRect(closeBox); 
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent { return YES; }

- (BOOL)mouseDownCanMoveWindow { return NO; }

- (void)mouseDown:(NSEvent *)theEvent
{
	if (mouseInCloseBox = NSPointInRect([self convertPoint:[theEvent locationInWindow] fromView:nil], closeBox)) {
		trackingCloseBoxHit = YES;		
		[self setNeedsDisplayInRect:closeBox];
    }
    else if ([theEvent clickCount] > 1) {
		[[self window] miniaturize:self];
		return;
    }
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint windowOrigin;
	NSWindow *window = [self window];
	
	if (trackingCloseBoxHit) {
		mouseInCloseBox = NSPointInRect([self convertPoint:[theEvent locationInWindow] fromView:nil], closeBox);
		[self setNeedsDisplayInRect:closeBox];
		return;
    }
	
	windowOrigin = [window frame].origin;
	
    [window setFrameOrigin:NSMakePoint(windowOrigin.x + [theEvent deltaX], windowOrigin.y - [theEvent deltaY])];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if(NSPointInRect([self convertPoint:[theEvent locationInWindow] fromView:nil], closeBox)) {
		[self tryToCloseWindow];
		return;
    }
	trackingCloseBoxHit = NO;
	[self setNeedsDisplayInRect:closeBox];
}

- (void)tryToCloseWindow
{
	id delegate;
	id window;
	if (window = [self window])
		if (delegate = [window delegate])
			if ([delegate respondsToSelector:@selector(windowShouldClose:)])
					if (![delegate windowShouldClose:window])
						return;  // Delegate exists, and it vetoed closing the window.
									
	[window close];	// Otherwise, close the window.
}

@end
