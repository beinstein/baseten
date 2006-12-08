//
// BXDatabaseContextInspector.m
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
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

#import "BXDatabaseContextInspector.h"
#import <BaseTen/BaseTen.h>


@implementation BXDatabaseContextInspector

- (id) init
{
    self = [super init];
    [NSBundle loadNibNamed: @"DatabaseCtxInspector" owner: self];
    return self;
}

- (void) revert: (id) sender
{
    BXDatabaseContext* ctx = [self object];
    //NSLog (@"revert: %p", ctx);

    [databaseURIField setObjectValue: [ctx databaseURI]];
    [logsQueriesButton setState: ([ctx logsQueries])];
    [autocommitsButton setState: ([ctx autocommits])];
    
    [super revert: sender];
}

- (IBAction) setAutocommit: (id) sender
{
    id ctx = [self object];
    NSUndoManager* undoManager = [[self window] undoManager];
    [undoManager beginUndoGrouping];
    [[undoManager prepareWithInvocationTarget: self] setAutocommit: nil];
    [[undoManager prepareWithInvocationTarget: autocommitsButton] setState: [ctx autocommits]];
    [undoManager endUndoGrouping];
    [ctx setAutocommits: (NSOnState == [autocommitsButton state])];
}

- (IBAction) setLogQueries: (id) sender
{
    id ctx = [self object];
    NSUndoManager* undoManager = [[self window] undoManager];
    [undoManager beginUndoGrouping];
    [[undoManager prepareWithInvocationTarget: self] setLogQueries: nil];
    [[undoManager prepareWithInvocationTarget: logsQueriesButton] setState: [ctx logsQueries]];
    [undoManager endUndoGrouping];
    [ctx setLogsQueries: (NSOnState == [logsQueriesButton state])];
}

- (IBAction) setURLFromTextField: (id) sender
{
    id ctx = [self object];
    NSURL* newURI = nil;
    NSString* old = [[ctx databaseURI] absoluteString];
    
    NSString* string = [databaseURIField objectValue];
    if (0 < [string length])
        newURI = [NSURL URLWithString: string];
    
    BOOL succeeded = NO;
    
    @try
    {
        [ctx setDatabaseURI: newURI];
        succeeded = YES;
    }
    @catch (NSException* e)
    {
        NSAlert* alert = [NSAlert alertWithMessageText: @"Unsupported scheme"
                                         defaultButton: @"OK"
                                       alternateButton: nil 
                                           otherButton: nil 
                             informativeTextWithFormat: @"Unsupported URL scheme: %@", [newURI scheme]];
        [alert beginSheetModalForWindow: window modalDelegate: self 
                         didEndSelector: @selector (alertDidEnd:returnCode:contextInfo:) contextInfo: NULL];
    }
    
    if (succeeded)
    {
        NSUndoManager* undoManager = [[self window] undoManager];
        [undoManager beginUndoGrouping];
        [[undoManager prepareWithInvocationTarget: self] setURLFromTextField: nil];
        [[undoManager prepareWithInvocationTarget: databaseURIField] setObjectValue: old];
        [undoManager endUndoGrouping];
    }
}

- (void) alertDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void  *) contextInfo
{
    [self revert: nil];
}

@end


@interface BXDatabaseContext (BXDatabaseContextInspectorAdditions)
- (NSString *) inspectorClassName;
@end


@implementation BXDatabaseContext (BXDatabaseContextInspectorAdditions)
- (NSString *) inspectorClassName
{
    return NSStringFromClass([BXDatabaseContextInspector class]);
}
@end