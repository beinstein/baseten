//
// BXPanel.m
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

#import "BXPanel.h"
#import <BaseTen/BXLogger.h>


@implementation BXPanel

- (void) dealloc
{
    [mDidEndInvocation release];
    [super dealloc];
}

- (void) beginSheetModalForWindow: (NSWindow *) docWindow modalDelegate: (id) modalDelegate 
				   didEndSelector: (SEL) didEndSelector contextInfo: (void *) contextInfo
{	    
	mPanelDelegate = modalDelegate;
    if (NULL != didEndSelector)
    {
		NSMethodSignature* signature = [mPanelDelegate methodSignatureForSelector: didEndSelector];
        BXAssertVoidReturn (5 == [signature numberOfArguments], @"Expected number of arguments to be 5, was %d",
							  [signature numberOfArguments]);
        
		NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: signature];
		[invocation setSelector: didEndSelector];
		[invocation setTarget: mPanelDelegate];
        //Return code is not yet known.
		[invocation setArgument: &contextInfo atIndex: 4];
        [self setDidEndInvocation: invocation];
    }
        
	[NSApp beginSheet: self modalForWindow: docWindow modalDelegate: self 
	   didEndSelector: @selector (sheetDidEnd:returnCode:contextInfo:) 
		  contextInfo: NULL];
}

- (void) setLeftOpenOnContinue: (BOOL) aBool
{
    mLeftOpenOnContinue = aBool;
}

- (IBAction) continue: (id) sender
{
    [self continueWithReturnCode: [sender tag]];
}

- (void) sheetDidEnd: (BXPanel *) panel returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    if (NO == mLeftOpenOnContinue)
        [self continueWithReturnCode: returnCode];
}

- (void) continueWithReturnCode: (int) returnCode;
{
    if (NULL != mDidEndInvocation)
	{		
		[mDidEndInvocation setArgument: &returnCode atIndex: 3];
		[[NSRunLoop currentRunLoop] performSelector: @selector (invoke) target: mDidEndInvocation
										   argument: nil order: UINT_MAX
											  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
	}
    
    if (NO == mLeftOpenOnContinue)
        [self end];
}

- (void) end
{
    [self setDidEndInvocation: nil];
    [NSApp endSheet: self];
    //Try to be cautious since we might get released when closed
    [[self retain] autorelease];
    [self orderOut: nil];    
}

- (void) setDidEndInvocation: (NSInvocation *) invocation
{
    if (mDidEndInvocation != invocation)
    {
        [mDidEndInvocation release];
        mDidEndInvocation = [invocation retain];
		[mDidEndInvocation setArgument: &self atIndex: 2];
    }
}

@end
