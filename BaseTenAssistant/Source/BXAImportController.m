//
// BXAImportController.m
// BaseTen Assistant
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

#import "BXAImportController.h"
#import "MKCPolishedHeaderView.h"
#import "MKCPolishedCornerView.h"

static NSString* kBXAShouldImportKey = @"kBXAShouldImportKey";


@interface NSEntityDescription (BXAImportControllerAdditions)
- (BOOL) shouldImportBXA;
- (void) setShouldImportBXA: (BOOL) flag;
@end


@implementation NSEntityDescription (BXAImportControllerAdditions)
- (BOOL) shouldImportBXA
{
	return [[[self userInfo] objectForKey: kBXAShouldImportKey] boolValue];
}

- (void) setShouldImportBXA: (BOOL) flag
{
	NSMutableDictionary* userInfo = [[self userInfo] mutableCopy];
	[userInfo setObject: [NSNumber numberWithBool: flag] forKey: kBXAShouldImportKey];
	[self setUserInfo: userInfo];
}
@end



@implementation BXAImportController
@synthesize objectModel = mModel, schemaName = mSchemaName;

- (void) windowDidLoad
{
    NSDictionary* lightColours = [MKCPolishedHeaderView lightColours];
	[mLeftHeaderView setColours: lightColours];
	[mLeftHeaderView setDrawingMask: kMKCPolishDrawLeftAccent | kMKCPolishDrawBottomLine | 
	 kMKCPolishDrawTopLine | kMKCPolishDrawSeparatorLines];
	
	[mRightHeaderView setColours: lightColours];
	[mRightHeaderView setDrawingMask: kMKCPolishDrawLeftLine | kMKCPolishDrawTopLine | kMKCPolishDrawBottomLine];
	
    {
        NSRect cornerRect = NSMakeRect (0.0, 0.0, 15.0, 20.0);
        MKCPolishedCornerView* cornerView = [[[MKCPolishedCornerView alloc] initWithFrame: cornerRect] autorelease];
        [cornerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopLine | kMKCPolishDrawRightLine];
        [cornerView setColours: lightColours];
        [mTableView setCornerView: cornerView];
        
        cornerRect.size.width -= 5.0;
        cornerView = [[[MKCPolishedCornerView alloc] initWithFrame: cornerRect] autorelease];
        [cornerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopLine | kMKCPolishDrawRightLine];
        [cornerView setColours: lightColours];
        [mFieldView setCornerView: cornerView];
    }
    
    {
        NSColor* lightBackgroundColor = [NSColor colorWithDeviceWhite: 222.0 / 255.0 alpha: 1.0];
        [[self window] setBackgroundColor: lightBackgroundColor];
    }
	
	NSMutableArray* configurations = [[mModel configurations] mutableCopy];
	[configurations insertObject: @"Default Configuration" atIndex: 0]; //FIXME: localization.
	[self willChangeValueForKey: @"entitiesForSelectedConfiguration"];
	[mConfigurations setContent: configurations];		
	[self didChangeValueForKey: @"entitiesForSelectedConfiguration"];
	
	[self selectedConfiguration: nil];	
}

- (void) showPanelAttachedTo: (NSWindow *) aWindow
{
	[NSApp beginSheet: [self window] modalForWindow: aWindow modalDelegate: nil didEndSelector: NULL contextInfo: NULL];
}

- (void) endSheet
{
	NSWindow* panel = [self window];
	[NSApp endSheet: panel];
	[panel orderOut: nil];
}
@end


@implementation BXAImportController (IBActions)
- (IBAction) acceptImport: (id) sender
{
	[self endSheet];
}

- (IBAction) cancelImport: (id) sender
{
	[self endSheet];
}

- (IBAction) dryRun: (id) sender
{
}

- (IBAction) selectedConfiguration: (id) sender
{
	NSArray* content = nil;
	if (0 == [sender indexOfSelectedItem])
		content = [mModel entities];
	else
	{
		NSMenuItem* selectedItem = [sender selectedItem];
		NSString* title = [selectedItem title];
		content = [mModel entitiesForConfiguration: title];
	}
	
	[mEntities setContent: content];
}
@end
