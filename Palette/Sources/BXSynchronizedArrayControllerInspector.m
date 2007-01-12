//
// BXSynchronizedArrayControllerInspector.m
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

#import "BXSynchronizedArrayControllerInspector.h"
#import <BaseTenAppKit/BaseTenAppKit.h>
#import <BaseTen/BaseTen.h>
#import <BaseTen/BXDatabaseAdditions.h>


@class BXDatabaseContext;

static NSArray* gManuallyNotifiedKeys;


@implementation BXSynchronizedArrayControllerInspector

- (NSString *) predicateSafeStringFromViewString:(NSString *)string
{
	NSMutableString* predicateString = [NSMutableString stringWithString:string];
	[predicateString replaceOccurrencesOfString: @"%" withString: @"\%" options:0 range:NSMakeRange(0, [predicateString length])];
	return predicateString;
}

+ (void) initialize
{
	if ([self class] == [BXSynchronizedArrayControllerInspector class])
    {
        static BOOL tooLate = NO;
        if (NO == tooLate)
        {
            tooLate = YES;
            
            NSArray* keys = [NSArray arrayWithObjects: @"tableName", @"schemaName", nil];
            [self setKeys: keys triggerChangeNotificationsForDependentKey: @"customClassName"];
            
            gManuallyNotifiedKeys = [[NSArray alloc] initWithObjects:
                @"object", @"tableName", @"schemaName", @"customClassName", @"fetchesOnAwake",
                @"avoidsEmptySelection", @"preservesSelection", @"selectsInsertedObjects",
                @"alwaysUsesMultipleValuesMarker", @"clearsFilterPredicateOnInsertion", 
                nil];
        }
	}
}

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString *)theKey 
{
    BOOL automatic = NO;
    if (NO == [gManuallyNotifiedKeys containsObject: theKey])
        automatic = [super automaticallyNotifiesObserversForKey: theKey];
    
    return automatic;
}

- (id) init
{
    self = [super init];
    [NSBundle loadNibNamed: @"DBSyncArrayControllerInspector" owner: self];
    return self;
}

- (BXDatabaseContext *) dbContext
{
    id rval = nil;
    NSArray* connectors = [[NSApp activeDocument] connectorsForSource: [self object]];
    TSEnumerate (currentConn, e, [connectors objectEnumerator])
    {
        if ([@"databaseContext" isEqualToString: [currentConn label]])
        {
            rval = [currentConn destination];
            break;
        }
    }
    return rval;
}

- (void) revert: (id) sender
{
    TSEnumerate (currentKey, e, [gManuallyNotifiedKeys objectEnumerator])
    {
        [self willChangeValueForKey: currentKey];
        [self didChangeValueForKey: currentKey];
    }
    
    //FIXME: what if the user changes the database URL in the context?
    BXDatabaseContext* dbContext = [self dbContext];
    NSString* warning = @"DatabaseContext is nil.";
    BOOL ok = NO;
    if (nil != dbContext)
    {
        warning = @"Database URI is not set.";
        if (nil != [dbContext databaseURI])
            ok = YES;
    }
    
    [contextWarningField setStringValue: warning];
	
	NSString *predicateString = [[[self object] fetchPredicate] predicateFormat];
	if (nil == predicateString)
		predicateString = @"";
	[fetchPredicateTextView setString:predicateString];
	
    [fetchesOnAwakeButton setEnabled: ok];
	
    [contextWarningField setHidden: ok];
    [schemaNameField setEnabled: ok];
    [tableNameField setEnabled: ok];
	[customClassNameField setEnabled: ok];
	[setPredicateButton setEnabled: ok];
	[fetchPredicateTextView setEditable: ok];
	[fetchPredicateTextView setSelectable: ok];
	if (ok)
		[fetchPredicateTextView setTextColor:[NSColor blackColor]];
	else
		[fetchPredicateTextView setTextColor:[NSColor grayColor]];
	
    [super revert: sender];
}

- (NSString *) tableName
{
    return [[self object] tableName];
}

- (void) setTableName: (NSString *) aName
{
    id object = [self object];
    NSUndoManager* undoManager = [[self window] undoManager];
	[undoManager setActionName: NSLocalizedString (@"Set Table Name", nil)];
	[[undoManager prepareWithInvocationTarget: self] setTableName: [object tableName]];
    [self willChangeValueForKey: @"tableName"];
    [object setTableName: aName];
    [self didChangeValueForKey: @"tableName"];
}

- (NSString *) schemaName
{
    return [[self object] schemaName];
}

- (void) setSchemaName: (NSString *) aName
{
    id object = [self object];
    NSUndoManager* undoManager = [[self window] undoManager];
	[undoManager setActionName: NSLocalizedString (@"Set Schema Name", nil)];
	[[undoManager prepareWithInvocationTarget: self] setSchemaName: [object schemaName]];
    [self willChangeValueForKey: @"schemaName"];
    [object setSchemaName: aName];
    [self didChangeValueForKey: @"schemaName"];
}

- (NSString *) customClassName
{
    return [[self object] databaseObjectClassName];
}

- (void) setCustomClassName: (NSString *) customClassName
{
    NSUndoManager* undoManager = [[self window] undoManager];
    id object = [self object];
	[undoManager setActionName: NSLocalizedString (@"Set Custom Class Name", nil)];
	[[undoManager prepareWithInvocationTarget: self] setCustomClassName: [object databaseObjectClassName]];
    [self willChangeValueForKey: @"customClassName"];
    [object setDatabaseObjectClassName: customClassName];
    [self didChangeValueForKey: @"customClassName"];
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[alert release];
}

- (IBAction) setPredicate:(id)sender
{
	NSString* predicateString = [self predicateSafeStringFromViewString: [fetchPredicateTextView string]];
	@try
	{
		NSPredicate* predicate = nil;
		
		if ([predicateString length] > 0)
			predicate = [NSPredicate predicateWithFormat:predicateString];
		
		[[self object] setFetchPredicate:predicate];
	}
	@catch (NSException* e)
	{
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            [e reason], NSLocalizedRecoverySuggestionErrorKey, 
            NSLocalizedString (@"NSPredicate parse error", nil), NSLocalizedDescriptionKey, 
            nil];
		NSError* error = [NSError errorWithDomain: NSCocoaErrorDomain code: 1 userInfo: userInfo];
		NSAlert* alert = [[NSAlert alertWithError: error] retain];
		[alert beginSheetModalForWindow: [self window] 
                          modalDelegate: self 
                         didEndSelector: @selector (alertDidEnd:returnCode:contextInfo:) 
                            contextInfo: NULL];
	}
}

#define GenericSetter( KEY, SETTER_NAME )                                                        \
- (void) SETTER_NAME: (BOOL) aVal                                                                \
{                                                                                                \
    id object = [self object];                                                                   \
    [[[[self window] undoManager] prepareWithInvocationTarget: self] SETTER_NAME: [object KEY]]; \
    [self willChangeValueForKey: @#KEY];                                                         \
    [object SETTER_NAME: aVal];                                                                  \
    [self didChangeValueForKey: @#KEY];                                                          \
}

#define GenericGetter( KEY )    \
- (BOOL) KEY                    \
{                               \
    return [[self object] KEY]; \
}

#define GenericAccessors( KEY, SETTER_NAME ) \
GenericGetter( KEY ); \
GenericSetter( KEY, SETTER_NAME );

GenericAccessors (avoidsEmptySelection, setAvoidsEmptySelection);
GenericAccessors (preservesSelection, setPreservesSelection);
GenericAccessors (selectsInsertedObjects, setSelectsInsertedObjects);
GenericAccessors (alwaysUsesMultipleValuesMarker, setAlwaysUsesMultipleValuesMarker);
GenericAccessors (clearsFilterPredicateOnInsertion, setClearsFilterPredicateOnInsertion);
GenericAccessors (fetchesOnAwake, setFetchesOnAwake);
@end


@interface BXSynchronizedArrayController (BXDatabaseContextInspectorAdditions)
- (NSString *) inspectorClassName;
@end


@implementation BXSynchronizedArrayController (BXDatabaseContextInspectorAdditions)
- (NSString *) inspectorClassName
{
    return NSStringFromClass([BXSynchronizedArrayControllerInspector class]);
}
@end