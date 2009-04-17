//
// BXAInspectorPanelController.m
// BaseTen Assistant
//
// Author: Tim Bedford
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

#import "BXAGetInfoWindowController.h"
#import <BaseTen/BXEntityDescriptionPrivate.h>


__strong static NSString* kBXAInspectorPanelControllerKVOContext = @"kBXAInspectorPanelControllerKVOContext";


@implementation BXAInspectorPanelController
- (void) moveTableViewUp: (BOOL) moveUp
{
	CGFloat diff = 59.0;
	NSView* view = [[mAttributesTableView superview] superview];
	NSRect frame = [view frame];
	
	if (moveUp)
	{
		frame.origin.y += diff;
		frame.size.height -= diff;
		[view setFrame: frame];		
	}
	else
	{
		frame.origin.y -= diff;
		frame.size.height += diff;
		[view setFrame: frame];		
	}
}

#pragma mark Initialisation & Dealloc

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObject:@"entity"] triggerChangeNotificationsForDependentKey:@"entityTitle"];
	[self setKeys:[NSArray arrayWithObject:@"entity"] triggerChangeNotificationsForDependentKey:@"entityName"];
	[self setKeys:[NSArray arrayWithObject:@"entity"] triggerChangeNotificationsForDependentKey:@"entityIcon"];
}

+ (id) inspectorPanelController
{
	static BXAInspectorPanelController* sInspector;
	
	if(!sInspector)
	{
		sInspector = [[BXAInspectorPanelController alloc] init];
	}
	
	return sInspector;
}

- (id) init
{
	return [self initWithWindowNibName:@"InspectorPanel"];
}

- (id) initWithWindowNibName: (NSString *) nibName
{
	if(![super initWithWindowNibName: nibName])
		return nil;
	
	return self;
}

- (void) awakeFromNib
{
	[[self window] setContentView:mEntityAttributesView];
	
	// Set up default sort descriptors
	NSSortDescriptor* descriptor = [[mAttributesTableView tableColumnWithIdentifier:@"name"] sortDescriptorPrototype];
	NSArray* descriptors = [NSArray arrayWithObject:descriptor];
	[mAttributesTableView setSortDescriptors:descriptors];
	
	[self moveTableViewUp: NO];
	[self addObserver: self	forKeyPath: @"entity" 
			  options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial
			  context: kBXAInspectorPanelControllerKVOContext];
}


#pragma mark Accessors

@synthesize entity = mEntity;

- (NSPredicate *) attributeFilterPredicate
{
	return [NSPredicate predicateWithFormat: @"value.isExcluded == false"];
}

- (NSString *) entityTitle
{
	NSString* outTitle;
	
	if([self entity] == nil)
		outTitle = NSNoSelectionMarker;
	else if([[self entity] isView])
		outTitle = [NSString stringWithFormat:NSLocalizedString(@"ViewInfoTitleFormat", @"Title format"), [[self entity] name]];
	else
		outTitle = [NSString stringWithFormat:NSLocalizedString(@"TableInfoTitleFormat", @"Title format"), [[self entity] name]];
	
	return outTitle;
}

- (NSString *) entityName
{
	if([self entity] == nil)
		return NSNoSelectionMarker;
	else
		return [[self entity] name];
}

- (NSImage *) entityIcon
{
	NSImage* outImage = nil;
	
	if([[self entity] isView])
		outImage = [NSImage imageNamed:@"View16"];
	else
		outImage = [NSImage imageNamed:@"Table16"];
	
	return outImage;
}

- (BOOL) isWindowVisible
{
	return [[self window] isVisible];
}

- (IBAction) closeWindow: (id) sender;
{
	[[self window] performClose: sender];
}

- (void) bindEntityToObject: (id) observable withKeyPath: (NSString *) keypath
{
	[self unbind:@"entity"];
	[self bind:@"entity" toObject: observable withKeyPath: keypath options:nil];
}

- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object 
						 change: (NSDictionary *) change context: (void *) context
{
    if (context == kBXAInspectorPanelControllerKVOContext) 
	{
		BXEntityDescription* oldEntity = [change objectForKey: NSKeyValueChangeOldKey];
		BXEntityDescription* newEntity = [change objectForKey: NSKeyValueChangeNewKey];
		if ([NSNull null] == (id) oldEntity) oldEntity = nil;
		if ([NSNull null] == (id) newEntity) newEntity = nil;
		
		if ([oldEntity isView] && ![newEntity isView])
			[self moveTableViewUp: NO];
		else if (![oldEntity isView] && [newEntity isView])
			[self moveTableViewUp: YES];
	}
	else 
	{
		[super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
	}
}


@end
