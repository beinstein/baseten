/*

File: Sticky.m

Abstract: An NSManagedObject subclass that represents a sticky

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

#import "Sticky.h"
#import "StickiesAppDelegate.h"

NSString *windowFrameKey = @"windowFrameAsString";

static NSNib *stickyNib;

@implementation Sticky

+ (void)initialize 
{ 
    stickyNib = [[NSNib alloc] initWithNibNamed:@"Sticky" bundle:nil];
}

// Set up the sticky's window from the sticky nib file
- (void)setupSticky 
{
	if(stickyWindow != nil)
		return;
	
	[stickyNib instantiateNibWithOwner:self topLevelObjects:nil]; 
    NSAssert(stickyWindow != nil && contents != nil, @"IBOutlets were not set correctly in Sticky.nib");
    
    [stickyController setContent: self];
    
	[stickyWindow setDelegate:self];
    
    // Register for KVO on the sticky's frame rect so that the window will redraw if we change the frame
    [self addObserver:self
           forKeyPath:windowFrameKey
              options:NSKeyValueObservingOptionNew
              context:NULL];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context 
{
    // If the value of a sticky's frame changes in the managed object, we update the window to match
    if ([keyPath isEqual:windowFrameKey]) {
        NSRect newFrame = NSRectFromString([change objectForKey:NSKeyValueChangeNewKey]);
        // Don't setFrame if the frame hasn't changed; this prevents infinite recursion
        if (! NSEqualRects([stickyWindow frame], newFrame)) {
            [stickyWindow setFrame:newFrame display:YES];
        }
    }
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	[self setupSticky];
	
	[stickyWindow setFrame:NSRectFromString([self valueForKey:windowFrameKey]) display:YES];
 	[stickyWindow makeKeyAndOrderFront:self];
}

- (void)awakeFromInsert
{ 
	[super awakeFromInsert]; 
	[self setupSticky];

	[self rememberWindowFrame];  // Need to get an initial value for the window size and location into the database.    
	[stickyWindow makeKeyAndOrderFront:self];
}

// Destroy the sticky
- (BOOL)windowShouldClose:(id)sender
{
    [stickyController setContent: nil];
	[[NSApp delegate] removeSticky:self];
	return YES;
}

- (void)rememberWindowFrame
{
	[self setValue:NSStringFromRect([stickyWindow frame]) forKey:windowFrameKey];
}

- (void)windowDidMove:(NSNotification *)aNotification
{
    [self rememberWindowFrame];
}

- (void)windowDidResize:(NSNotification *)aNotification 
{
    [self rememberWindowFrame];
}

@end
