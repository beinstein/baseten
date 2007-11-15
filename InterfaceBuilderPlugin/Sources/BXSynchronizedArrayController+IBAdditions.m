//
// BXSynchronizedArrayController+IBAdditions.m
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://www.karppinen.fi/baseten/licensing/ or by contacting
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

#import "BXSynchronizedArrayController+IBAdditions.h"
#import "BXSynchronizedArrayControllerInspector.h"


@implementation BXSynchronizedArrayController (IBAdditions)

- (void) ibPopulateKeyPaths: (NSMutableDictionary *) keyPaths
{
    [super ibPopulateKeyPaths: keyPaths];
    
    [[keyPaths objectForKey: IBAttributeKeyPaths] addObjectsFromArray: [NSArray arrayWithObjects:
        @"tableName", @"schemaName", @"databaseObjectClassName", @"fetchesOnConnect", @"fetchPredicate", nil]];
    [[keyPaths objectForKey: IBToOneRelationshipKeyPaths] addObjectsFromArray: [NSArray arrayWithObjects:
        @"databaseContext", @"modalWindow", nil]];
}

- (void) ibPopulateAttributeInspectorClasses: (NSMutableArray *) classes
{
    [super ibPopulateAttributeInspectorClasses: classes];
    [classes addObject: [BXSynchronizedArrayControllerInspector class]];
}

#if 0
//FIXME: move alert stuff elsewhere.
- (void) alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[alert release];
}
#endif

- (void) setIBFetchPredicate: (NSString *) predicateString
{
	@try
	{
		NSPredicate* predicate = nil;
		
		if ([predicateString length] > 0)
			predicate = [NSPredicate predicateWithFormat:predicateString];
		
		[self setFetchPredicate: predicate];
	}
	@catch (NSException* e)
	{
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  [e reason], NSLocalizedRecoverySuggestionErrorKey, 
								  NSLocalizedString (@"NSPredicate parse error", nil), NSLocalizedDescriptionKey, 
								  nil];
		NSError* error = [NSError errorWithDomain: NSCocoaErrorDomain code: 1 userInfo: userInfo];
		
		error = nil;
#if 0
		//FIXME: move alert stuff elsewhere.
		NSAlert* alert = [[NSAlert alertWithError: error] retain];
		[alert beginSheetModalForWindow: [self window] 
                          modalDelegate: self 
                         didEndSelector: @selector (alertDidEnd:returnCode:contextInfo:) 
                            contextInfo: NULL];
#endif
	}
}

- (NSString *) IBFetchPredicate
{
	return [[self fetchPredicate] predicateFormat];
}

@end
