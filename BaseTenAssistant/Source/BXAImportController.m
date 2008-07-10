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


@implementation BXAImportController
@synthesize objectModel = mModel, schemaName = mSchemaName;
- (void) showPanelAttachedTo: (NSWindow *) aWindow
{
	[self loadWindow];
	
	NSMutableArray* configurations = [[mModel configurations] mutableCopy];
	[configurations insertObject: @"Default Configuration" atIndex: 0]; //FIXME: localization.
	[self willChangeValueForKey: @"entitiesForSelectedConfiguration"];
	[mConfigurations setContent: configurations];		
	[self didChangeValueForKey: @"entitiesForSelectedConfiguration"];
	
	[self selectedConfiguration: nil];
	[NSApp beginSheet: [self window] modalForWindow: aWindow modalDelegate: nil didEndSelector: NULL contextInfo: NULL];
}
@end


@implementation BXAImportController (IBActions)
- (IBAction) acceptImport: (id) sender
{
	NSWindow* panel = [self window];
	[NSApp endSheet: panel];
	[panel orderOut: nil];
}

- (IBAction) cancelImport: (id) sender
{
	NSWindow* panel = [self window];
	[NSApp endSheet: panel];
	[panel orderOut: nil];
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
