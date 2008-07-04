//
// Controller.m
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


@class MKCAlternativeDataCellColumn;

#import <PGTS/PGTS.h>
#import <PGTS/PGTSAdditions.h>
#import <PGTS/PGTSFunctions.h>
#import <signal.h>
#import <stdio.h>
#import <unistd.h>
#import <sys/types.h>
#import <sys/stat.h>

#import "Controller.h"
#import "ImportController.h"
#import "Table.h"
#import "Entity.h"
#import "Schema.h"
#import "Constants.h"
#import "Additions.h"
#import "MKCPolishedHeaderView.h"
#import "MKCPolishedCornerView.h"
#import "MKCForcedSizeToFitButtonCell.h"
#import "MKCBackgroundView.h"


#define BX_CURRENT_VERSION_DEC        [NSDecimalNumber decimalNumberWithMantissa: 914 exponent: -3 isNegative: NO]
#define BX_COMPAT_VERSION_DEC         [NSDecimalNumber decimalNumberWithMantissa: 14 exponent: -2 isNegative: NO]


@interface NSArrayController (BaseTenSetupApplicationAdditions)
- (BOOL) MKCHasEmptySelection;
@end


@implementation Table (BaseTenSetupApplicationAdditions)
- (NSImage *) MKCImage
{
    id retval = nil;
    if ([self isView])
        retval = [NSImage imageNamed: @"View16"];
    else
        retval = [NSImage imageNamed: @"Table16"];
    return retval;
}

- (NSAttributedString *) MKCAttributedString
{
	return [[[NSAttributedString alloc] initWithString: [self name]] autorelease];
}
@end


@implementation Schema (BaseTenSetupApplicationAdditions)
- (NSImage *) MKCImage
{
	return [NSImage imageNamed: @"Schema16"];
}

- (NSAttributedString *) MKCAttributedString
{
	return [[[NSAttributedString alloc] initWithString: [self name]] autorelease];
}
@end


@implementation Entity (BaseTenSetupApplicationAdditions)
- (NSColor *) textColor
{
    NSColor* retval = nil;
    if (YES == alreadyExists)
        retval = [NSColor redColor];
    else
        retval = [NSColor blackColor];
    return retval;
}

- (NSColor *) selectedTextColor
{
    NSColor* retval = nil;
    if (YES == alreadyExists)
        retval = [NSColor redColor];
    else
        retval = [NSColor whiteColor];
    return retval;
}
@end


@implementation NSAttributeDescription (BaseTenSetupApplicationAdditions)

- (NSAttributedString *) MKCAttributedString
{
	return [[[NSAttributedString alloc] initWithString: [self name]] autorelease];
}

- (NSImage *) MKCImage
{
	return [NSImage imageNamed: @"Entity16"];
}

@end



@implementation NSArrayController (BaseTenSetupApplicationAdditions)
- (BOOL) MKCHasEmptySelection
{
    return NSNotFound == [self selectionIndex];
}
@end


/** This class could also be database independent */


@implementation Controller

- (id) init
{
    if ((self = [super init]))
    {
        mAwaken = NO;
    }
    return self;
}

- (void) awakeFromNib
{    
    if (NO == mAwaken)
    {
        mAwaken = YES;
        
        [[mTableEnabledColumn dataCell] setSendsActionOnEndEditing: YES];
        
		//Make main window's bottom edge lighter
		[mMainWindow setContentBorderThickness: 24.0 forEdge: NSMinYEdge];
		
        //Toolbar
		{
			[mToolbar setBackgroundColor: [NSColor colorWithCalibratedRed: 214.0 / 255.0 green: 221.0 / 255.0 blue: 229.0 / 255.0 alpha: 1.0]];
			NSMutableParagraphStyle* paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
			[paragraphStyle setAlignment: NSCenterTextAlignment];
			NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
										paragraphStyle, NSParagraphStyleAttributeName,
										[NSFont systemFontOfSize: [NSFont smallSystemFontSize]], NSFontAttributeName,
										nil];

			const int count = 3; //Remember to set this when changing the arrays below.
			id targets [] = {self, mInspectorWindow, mLogWindow};
			SEL actions [] = {@selector (importDataModel:), @selector (MKCToggle:), @selector (MKCToggle:)};
			NSString* labels [] = {@"Import Data Model", @"Inspector", @"Log"};
			NSString* imageNames [] = {@"ImportModel32", @"Inspector32", @"Log32"};
			NSAttributedString* attributedTitles [count];
			CGFloat widths [count];
			
			//Calculate text dimensions
			CGFloat height = 0.0;
			for (int i = 0; i < count; i++)
			{
				attributedTitles [i] = [[[NSAttributedString alloc] initWithString: labels [i] attributes: attributes] autorelease];
				NSSize size = [attributedTitles [i] size];
				widths [i] = MAX (size.width, 32.0) + 5.0; //5.0 px padding to make text fit
				height = MAX (height, size.height);
			}
			height += 33.0; //Image maximum height
			CGFloat xPosition = 12.0; //Left margin
			
			for (int i = 0; i < count; i++)
			{
				NSButton* button = [[NSButton alloc] init];
				[mToolbar addSubview: button];
				[button release];
				
				[button setButtonType: NSMomentaryPushInButton];
				[button setBezelStyle: NSShadowlessSquareBezelStyle];
				[button setBordered: NO];
				[button setImagePosition: NSImageAbove];
				[[button cell] setHighlightsBy: NSPushInCellMask];
				[button setTarget: targets [i]];
				[button setAction: actions [i]];
				[button setAttributedTitle: attributedTitles [i]];
				[button setImage: [NSImage imageNamed: imageNames [i]]];				
				switch (i)
				{
					case 2:
						[button setFrame: NSMakeRect ([mToolbar bounds].size.width - (widths [i] + 10.0), 3.0, widths [i], height)];
						[button setAutoresizingMask: NSViewMinXMargin];
						break;
					default:
						[button setFrame: NSMakeRect (xPosition, 3.0, widths [i], height)];
						break;
				}
				xPosition += widths [i] + 13.0;
			}
		}
         
		//Table headers
        {
            NSRect headerRect = NSMakeRect (0.0, 0.0, 0.0, 23.0);
            headerRect.size.width = [mDBTableView bounds].size.width;
            MKCPolishedHeaderView* headerView = [[[MKCPolishedHeaderView alloc] initWithFrame: headerRect] autorelease];
			[headerView setColours: [MKCPolishedHeaderView darkColours]];
            [headerView setDrawingMask: kMKCPolishDrawBottomLine | 
                kMKCPolishDrawLeftAccent | kMKCPolishDrawTopAccent | kMKCPolishDrawSeparatorLines];
            [mDBTableView setHeaderView: headerView];
            
            headerView = [[[MKCPolishedHeaderView alloc] initWithFrame: headerRect] autorelease];
            headerRect.size.width = [mDBSchemaView bounds].size.width;
            [headerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopAccent];
            [mDBSchemaView setHeaderView: headerView];
        }
         
		//Table corners
        {
            NSRect cornerRect = NSMakeRect (0.0, 0.0, 15.0, 23.0);
            MKCPolishedCornerView* otherCornerView = [[[MKCPolishedCornerView alloc] initWithFrame: cornerRect] autorelease];
            [otherCornerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopAccent];
            [mDBTableView setCornerView: otherCornerView];
            
            mCornerView = [[MKCPolishedCornerView alloc] initWithFrame: cornerRect];
            [mCornerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopAccent];
            [mCornerView setDrawsHandle: YES];
            [mDBSchemaView setCornerView: mCornerView];
        }
                
        {
            NSButtonCell* enabledButtonCell = [mTableEnabledColumn dataCell];
            [enabledButtonCell setAction: @selector (changeObservingStatus:)];
            [enabledButtonCell setTarget: self];
            
            mInspectorButtonCell = [[MKCForcedSizeToFitButtonCell alloc] initTextCell: @"Setup..."];
            [mInspectorButtonCell setButtonType: NSMomentaryPushInButton];
            [mInspectorButtonCell setBezelStyle: NSRoundedBezelStyle];
            [mInspectorButtonCell setControlSize: NSMiniControlSize];
            [mInspectorButtonCell setFont: [NSFont systemFontOfSize: 
                [NSFont systemFontSizeForControlSize: NSMiniControlSize]]];
            [mInspectorButtonCell setTarget: mInspectorWindow];
            [mInspectorButtonCell setAction: @selector (makeKeyAndOrderFront:)];
        }
        
        [mTableController addObserver: self forKeyPath: @"selection.isView" 
                             options: NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                             context: NULL];

        
        [mStatusTextField makeEtchedSmall: YES];
        [mProgressIndicator setUsesThreadedAnimation: YES];
    }    
}

- (void) dealloc
{
    [mConnection release];
    [mConnectionDict release];
    [mCornerView release];
    [mInspectorButtonCell release];
    
    [super dealloc];
}

- (void) setConnection: (PGTSConnection *) aConnection
{
    if (mConnection != aConnection) 
    {
        [mConnection release];
        mConnection = [aConnection retain];
    }
}

/** 
 * Handle error in version check.
 * We don't know what is going on but allow the user to replace the schema. 
 */
- (void) handleVersionCheckError: (PGTSResultSet *) res
{
    NSString* messageFormat = @"The following error occured: %@ Would you like the schema to be replaced with the "
    "version provided with this application? This removes observing information and should be done when there are no "
    "BaseTen clients connected.";
    NSAlert* alert = [NSAlert alertWithMessageText: @"Database error" defaultButton: @"OK" alternateButton: @"Cancel"
                                       otherButton: nil informativeTextWithFormat: messageFormat, [res errorMessage]];
    [alert beginSheetModalForWindow: mMainWindow modalDelegate: self 
                     didEndSelector: @selector (alertAlterDidEnd:returnCode:contextInfo:)
                        contextInfo: (void *) 0]; //Require the ALTER
}

/**
 * Check schema version.
 * First we check that the schema compatibility version. If it's lower than ours, allow the user to ALTER but refuse to connect
 * if they fail to comply. If it's higher, don't allow the modification but refuse to connect anyway.
 * If the compatibility version matched, check the schema version. If it's lower than ours, allow the user to update, but allow the
 * connection to be made in any case.
 */
- (BOOL) versionCheck
{
    BOOL retval = NO;
    BOOL allowConnect = YES;
    unsigned int updateOnlyIfNeeded = 0;
    PGTSResultSet* res = nil;
    NSString* message = nil;
    
    if (NO == [[mConnection databaseInfo] schemaExists: @"baseten"])
    {
        message = @"The schema required by BaseTen could not be found. Would you like the schema to be installed?";
    }
    else
    {
        //Compatibility version
        res = [mConnection executeQuery: @"SELECT baseten.CompatibilityVersion () AS version;"];    
        if (NO == [res querySucceeded])
        {
            allowConnect = NO;
            [self handleVersionCheckError: res];
        }
        else
        {
            [res advanceRow];
            NSDecimalNumber* compatVersion = [res valueForKey: @"version"];
            NSComparisonResult result = [compatVersion compare: BX_COMPAT_VERSION_DEC];
            if (NSOrderedAscending == result)
            {
                message = @"Your BaseTen schema compatibility version is smaller than what this application is capable of handling. "
                "Would you like the schema to be replaced with the version provided with this application? This should be done "
                "when there are no BaseTen clients connected.";
            }
            else if (NSOrderedDescending == result)
            {
                message = @"Your BaseTen schema compatibility version is larger than what this application is capable of handling. "
                "Connection cannot be made.";
                allowConnect = NO;
            }
            else
            {
                //Version
                res = [mConnection executeQuery: @"SELECT baseten.Version () AS version;"];
                if (NO == [res querySucceeded])
                {
                    allowConnect = NO;
                    [self handleVersionCheckError: res];
                }
                else
                {
                    [res advanceRow];
                    NSDecimalNumber* version = [res valueForKey: @"version"];
                    if (NSOrderedAscending == [version compare: BX_CURRENT_VERSION_DEC])
                    {
                        message = @"Your database seems to be out of date. Would you like the BaseTen schema "
                        "to be replaced with the version provided with this application? This should be done "
                        "when there are no BaseTen clients connected.";
                        updateOnlyIfNeeded = 1;
                    }
                    else
                    {
                        //Connection can be made without bothering the user
                        retval = YES;
                    }
                }
            }
        }
    }
    
    if (NO == retval)
    {
        SEL didEndSelector = @selector (alertAlterDidEnd:returnCode:contextInfo:);
        NSString* alternateButton = @"Cancel";
        if (NO == allowConnect)
        {
            didEndSelector = NULL;
            alternateButton = nil;
        }
        
        NSAlert* alert = [NSAlert alertWithMessageText: @"Database warning" defaultButton: @"OK" alternateButton: alternateButton 
                                           otherButton: nil informativeTextWithFormat: @"%@", message];
        [alert beginSheetModalForWindow: mMainWindow modalDelegate: self didEndSelector: didEndSelector contextInfo: (void *) updateOnlyIfNeeded];
    }
    
    return retval;
}

- (void) setConnectionDict: (NSDictionary *) aConnectionDict
{
    if (mConnectionDict != aConnectionDict) {
        [mConnectionDict release];
        mConnectionDict = [aConnectionDict retain];
    }
}

- (char *) storePassword
{
    char* format = "/tmp/pgpass.XXXXXX";
    size_t size = strlen (format) + 1;
    char* name = malloc (size);
    int descriptor = -1;
    BOOL ok = NO;
    
    strlcpy (name, format, size);
    if (-1 != (descriptor = mkstemp (name)))
    {
        if (0 == fchmod (descriptor, S_IRUSR + S_IWUSR))
        {
            FILE* file = NULL;
            if ((file = fdopen (descriptor, "w+")))
            {
                int size = fprintf (file, "*:*:*:*:%s\n", [[mConnectionDict valueForKey: kPGTSPasswordKey] UTF8String]);
                if (0 < size)
                    ok = YES;
                fclose (file);
            }
        }
        close (descriptor);
    }
    
    if (NO == ok)
    {
        unlink (name);
        if (NULL != name)
        {
            free (name);
            name = NULL;
        }
    }
    
    return (name);
}

+ (void) initialize
{
	if ([self class] != [Controller class])
		return;

	static BOOL tooLate = NO;
	if (! tooLate)
	{
		tooLate = YES;
		NSDictionary *initialUserDefaults = [NSDictionary dictionaryWithObjectsAndKeys: NSUserName(), @"username", nil];
		[[NSUserDefaults standardUserDefaults] registerDefaults: initialUserDefaults];
	}
}

- (NSString *) inspectorTitle
{
    NSString* retval = @"Inspector";
    id selection = [mTableController selectedObjects];
    if (0 < [selection count])
    {
        Table* selectedTable = [selection objectAtIndex: 0];
        if ([selectedTable isView])
            retval = @"View Inspector";
        else
            retval = @"Table Inspector";
    }
    return retval;
}

- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object
                         change: (NSDictionary *) change context: (void *) context
{
    //isView
    static BOOL old = YES;
    static BOOL new = NO;
    
    if ([mTableController MKCHasEmptySelection])
        new = NO;
    else
        new = [[[mTableController selection] valueForKey: @"isView"] boolValue];
       
    if ((old || new) && (!old || !new))
    {
        NSView* scrollView = [[mInspectorTable superview] superview];
        NSRect frame = [scrollView frame];
        NSRect largeFrame = frame;
        NSSize size = frame.size;
        
        if (YES == new && NO == old)
            size.height -= 75.0;
        else if (NO == new && YES == old)
        {
            size.height += 75.0;
            largeFrame.size = size;
        }
        
        frame.size = size;
        [scrollView setFrame: frame];
        [[scrollView superview] setNeedsDisplayInRect: largeFrame];
    }
    
    old = new;
}

- (void) continueTermination
{
	[self hideProgressPanel];
	//[NSApp replyToApplicationShouldTerminate: YES];
	[NSApp terminate: nil];
}

- (void) continueDisconnect
{
	[mStatusTextField setStringValue: @"Not connected."];
	[mStatusTextField makeEtchedSmall: YES];
	[self hideProgressPanel];
	[self setConnection: nil];
	[self reload: nil];
	[NSApp beginSheet: mConnectPanel modalForWindow: mMainWindow modalDelegate: self 
	   didEndSelector: NULL contextInfo: NULL];	
}

@end


@implementation Controller (IBActions)

- (IBAction) clearLog: (id) sender
{
    [[[mLogView textStorage] mutableString] setString: @""];    
}

- (IBAction) terminate: (id) sender
{
    [mConnectPanel orderOut: nil];
    [self hideProgressPanel];
        
    mTerminating = YES;
    //[NSApp terminate: nil];
    [self disconnect: nil];
}

- (IBAction) connect: (id) sender
{
    NSMutableDictionary* aDict = [NSMutableDictionary dictionary];
	
	[aDict setObject: [mHostCell objectValue] ? [mHostCell objectValue] : @"" forKey: kPGTSHostKey];
	[aDict setObject: [mPortCell objectValue] ? [mPortCell objectValue] : @"" forKey: kPGTSPortKey];
	[aDict setObject: [mDBNameCell objectValue] ? [mDBNameCell objectValue] : @"" forKey: kPGTSDatabaseNameKey];
	[aDict setObject: [mUserNameCell objectValue] ? [mUserNameCell objectValue] : @"" forKey: kPGTSUserNameKey];
	[aDict setObject: [mPasswordField objectValue] ? [mPasswordField objectValue] : @"" forKey: kPGTSPasswordKey];
	
    [self setConnectionDict: aDict];
    [NSApp endSheet: mConnectPanel];
    [mConnectPanel orderOut: nil];
    
    PGTSConnection* conn = [PGTSConnection connection];
    [conn setDelegate: self];
    [conn setConnectionDictionary: mConnectionDict];
    [conn setLogsQueries: NO];
    [self setConnection: conn];
    
    [self displayProgressPanel: @"Connecting..."];
    [conn connectAsync];
}

- (IBAction) disconnect: (id) sender
{
	if (nil == mConnection)
	{
		if (mTerminating)
			[self continueTermination];
		else
			[self continueDisconnect];
	}
	else
	{
		[self displayProgressPanel: @"Refreshing caches..."];
		[mConnection sendQuery: @"SELECT baseten.refreshcaches ();"];
	}	
}

- (IBAction) reload: (id) sender
{
	[mTableController setContent: nil];
    NSString* query = 
    @"SELECT c.oid, baseten.IsObservingCompatible (c.oid) AS prepared, c.relname AS name, "
    " n.nspname AS \"schemaName\", c.relkind "
    " FROM pg_class c, pg_namespace n "
    " WHERE c.relnamespace = n.oid "
    " AND (c.relkind = 'r' OR c.relkind = 'v') "
    " AND n.nspname NOT IN ('pg_toast', 'pg_temp_1', 'pg_catalog', 'information_schema', 'pg_temp_2', 'baseten')"
    " ORDER BY c.relname ASC ";
    PGTSResultSet* res = [mConnection executeQuery: query];
    NSMutableDictionary* schemas = [NSMutableDictionary dictionary];
    while (([res advanceRow]))
    {
        Table* table = [[Table alloc] init];
        [table setPrepared: [[res valueForKey: @"prepared"] boolValue]];
        [table setName: [res valueForKey: @"name"]];
        [table setOid: [[res valueForKey: @"oid"] PGTSOidValue]];
        [table setView: ('v' == [[res valueForKey: @"relkind"] characterAtIndex: 0] ? YES : NO)];
        
        NSString* schemaName = [res valueForKey: @"schemaName"];
        Schema* schema = [schemas objectForKey: schemaName];
        if (nil == schema)
        {
            schema = [[Schema alloc] init];
            [schema setName: schemaName];
            [schemas setObject: schema forKey: schemaName];
            [schema release];
        }
        [schema addTable: table];        
        [table release];
    }
    [mSchemaController setContent: [schemas allValues]];
}

- (IBAction) changeObservingStatusByBinding: (id) sender
{
    //We need this because the action gets invoked after the KVC call.
    Table* selection = [[mTableController arrangedObjects] objectAtIndex: [mDBTableView selectedRow]];
    BOOL prepared = [selection prepared];
    [selection setPrepared: !prepared];
    [self changeObservingStatus: nil];
}

- (IBAction) reloadTables: (id) sender
{
    [mDBTableView reloadData];
}

- (IBAction) changeObservingStatus: (id) sender
{
    [self willChangeValueForKey: @"allowSettingPrimaryKey"];
    
    Table* selection = [[mTableController arrangedObjects] objectAtIndex: [mDBTableView selectedRow]];
    BOOL prepared = [selection prepared];
    NSString* query = nil;
    if (YES == prepared)
        query = @"SELECT baseten.CancelModificationObserving ($1)";
    else
        query = @"SELECT baseten.PrepareForModificationObserving ($1)";
    
    id oid = [selection valueForKey: @"oid"];
    [self logAppend: [query stringByAppendingFormat: @" -- (%@)\n", oid]];
    PGTSResultSet* res = [mConnection executeQuery: query parameters: oid];
    
    [self didChangeValueForKey: @"allowSettingPrimaryKey"];

    if (YES == [res querySucceeded])
    {
        [selection setPrepared: !prepared];
        [mDBTableView reloadData];
    }
    else
    {
        NSAlert* alert = [NSAlert alertWithMessageText: @"Unable to modify" defaultButton: @"OK" alternateButton: nil 
                                           otherButton: nil informativeTextWithFormat: @"%@", [res errorMessage]];
        [alert beginSheetModalForWindow: mMainWindow modalDelegate: nil
                         didEndSelector: NULL contextInfo: NULL];
    }    
}

- (IBAction) importDataModel: (id) sender
{
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection: NO];
    [openPanel setCanChooseDirectories: NO];
    [openPanel setCanChooseFiles: YES];
    [openPanel setResolvesAliases: YES];
    [openPanel beginSheetForDirectory: nil file: nil types: [NSArray arrayWithObjects: @"xcdatamodel", @"mom", nil]
                       modalForWindow: mMainWindow modalDelegate: self 
                       didEndSelector: @selector (panelOpenDidEnd:returnCode:contextInfo:) contextInfo: NULL];
}

@end


@implementation Controller (Delegation)

- (NSRect) splitView: (NSSplitView *) splitView additionalEffectiveRectOfDividerAtIndex: (NSInteger) dividerIndex
{
	NSRect retval = NSZeroRect;
	if (0 == dividerIndex)
	{
		retval = [splitView convertRect: [mCornerView bounds] fromView: mCornerView];
	}
	return retval;
}

- (void) PGTSConnectionEstablished: (PGTSConnection *) aConnection
{
    NSString* host = [aConnection host];
    if (nil == host || [host isEqualToString: @""])
        host = @"localhost";
    [mStatusTextField setStringValue: [NSString stringWithFormat: @"Connected to %@ on %@.",
        [aConnection databaseName], host]];
    [mStatusTextField makeEtchedSmall: YES];
        
    [mConnectPanel orderOut: nil];
    [self hideProgressPanel];
    if (YES == [self versionCheck])
    {
        [self setConnectionDict: nil];
        [self reload: nil];
    }
}

- (void) PGTSConnectionFailed: (PGTSConnection *) aConnection
{
    //Did the user disconnect on purpose?
    if (nil != mConnection)
    {
        NSAlert* alert = [NSAlert alertWithMessageText: @"Connection failed" defaultButton: @"OK" alternateButton: nil otherButton: nil
                             informativeTextWithFormat: @"%@", [aConnection errorMessage]];
        [self setConnection: nil];
        [self hideProgressPanel];
        [alert beginSheetModalForWindow: mMainWindow modalDelegate: self 
                         didEndSelector: @selector (alertConnectionFailedDidEnd:returnCode:contextInfo:)
                            contextInfo: NULL];
    }
}

- (void) PGTSConnection: (PGTSConnection *) connection receivedResultSet: (PGTSResultSet *) res
{
	//The only async query we are sending is for recreating the caches.
	if (mTerminating)
		[self continueTermination];
	else
		[self continueDisconnect];
}

- (void) panelOpenDidEnd: (NSOpenPanel *) panel returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    if (NSOKButton == returnCode)
    {
        if (nil == mImportController)
        {
            mImportController = [[ImportController alloc] init];
            [mImportController setConnection: mConnection];
            mImportController->mController = self;
            mImportController->mMainWindow = mMainWindow;
            [mImportController loadNibAndListen];
        }
        
        NSString* path = [[[panel URLs] objectAtIndex: 0] path];
        if ([path hasSuffix: @"mom"])
            [mImportController importModelAtPath: path];
        else
            [mImportController compileModelAtPath: path];
    }
}

- (void) alertConnectionFailedDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    [[alert window] orderOut: nil];
    [NSApp beginSheet: mConnectPanel modalForWindow: mMainWindow modalDelegate: self 
       didEndSelector: NULL contextInfo: NULL]; 
}

- (void) alertErrorDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    [[alert window] orderOut: nil];
	[self disconnect: nil];
}


- (void) alertAlterDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) alterOnlyIfNeeded
{
    [[alert window] orderOut: nil];
    if (NSAlertDefaultReturn != returnCode)
    {
        if (YES == (unsigned int) alterOnlyIfNeeded)
            [self reload: nil];
        else
            [self disconnect: nil];
    }
    else
    {
        //Remember the observed relations
        NSString* query = @"SELECT p.oid, p.relkind, p.nspname, p.relname, baseten.array_accum (p.attname) AS fields "
        "FROM pg_class c "
        "LEFT JOIN baseten.primarykey p ON c.oid = p.oid "
        "WHERE baseten.isobservingcompatible (c.oid) = true "
        "GROUP BY p.oid, p.relkind, p.nspname, p.relname "
        "ORDER BY oid ASC ";
        PGTSResultSet* res = [mConnection executeQuery: query];
        
        {
            NSBundle* mainBundle = [NSBundle mainBundle];
            NSString* psqlPath = [mainBundle pathForAuxiliaryExecutable: @"psql"];
            NSString* scriptPath = [mainBundle pathForResource: @"BaseTenModifications" ofType: @"sql"];
            
            NSAssert (nil != psqlPath, @"psql was not found in the bundle.");
            NSAssert (nil != scriptPath, @"BaseTenModifications.sql was not found in the bundle");
            
            //Write the password to a file only readable by this user
            char* pwFileName = [self storePassword];
            if (NULL != pwFileName)
            {
				NSArray* arguments = [NSArray arrayWithObjects:
                    @"-f", scriptPath,
					@"--variable", @"ON_ERROR_STOP",	 //Clears variable
					@"--variable", @"ON_ERROR_ROLLBACK", //Clears variable
#if 0
					@"--variable", @"VERBOSITY=verbose",
					@"--variable", @"ECHO=all",
#endif
                    nil];
				NSTask* task = [[NSTask alloc] init];
				NSMutableDictionary* environment = [NSMutableDictionary dictionaryWithDictionary:
													[[NSProcessInfo processInfo] environment]];
				NSPipe* pipe = [NSPipe pipe];
				
				[task setLaunchPath: psqlPath];
				[task setArguments: arguments];
				[environment addEntriesFromDictionary: [NSDictionary dictionaryWithObjectsAndKeys: 
                    [mConnectionDict valueForKey: kPGTSDatabaseNameKey], @"PGDATABASE",
                    [mConnectionDict valueForKey: kPGTSHostKey],         @"PGHOST",
                    [mConnectionDict valueForKey: kPGTSPortKey],         @"PGPORT",
                    [mConnectionDict valueForKey: kPGTSUserNameKey],     @"PGUSER",
                    [NSString stringWithUTF8String: pwFileName],        @"PGPASSFILE",
                    nil]];
                [task setEnvironment: environment];
				
				[task setStandardError: pipe];
				[task setStandardOutput: pipe];
                
                //Display the progress indicator to please the user
                [self displayProgressPanel: @"Sending commands..."];
                
                //Send the commands
				[task launch];
                [task waitUntilExit];
				
                //Remove the progress panel
                [self hideProgressPanel];
                
                //Remove the password file
                unlink (pwFileName);
                free (pwFileName);
      
				//Get the output
				NSData* outputData = [[pipe fileHandleForReading] readDataToEndOfFile];
                NSString* errorString = [[[NSString alloc] initWithData: outputData encoding: NSUTF8StringEncoding] autorelease];
                [self logAppend: errorString];
				
                if (0 != [task terminationStatus])
                {
                    NSAlert* alert = [NSAlert alertWithMessageText: @"Database error" defaultButton: @"OK" alternateButton: nil otherButton: nil 
                                         informativeTextWithFormat: @"Errors occured when processing SQL commands. Please check the log."];
                    [alert beginSheetModalForWindow: mMainWindow modalDelegate: self 
									 didEndSelector: @selector (alertErrorDidEnd:returnCode:contextInfo:) contextInfo: NULL];
                }
                else 
				{
					if (NO == [res isAtEnd])
					{
						//Prepare again for observing
						BOOL success = [res querySucceeded];
						if (YES == success)
						{
							NSString* query = @"BEGIN";
							[self logAppend: query];
							[mConnection executeQuery: query];
							while (([res advanceRow]))
							{
								unichar relkind = [[res valueForKey: @"relkind"] characterAtIndex: 0];
								if ('v' == relkind)
								{
									//For views, restore the primary keys
									NSArray* fields = [res valueForKey: @"fields"];
									NSString* query = @"INSERT INTO baseten.viewprimarykey (nspname, relname, attname) "
										"VALUES ($1, $2, $3)";
									NSString* nspname = [res valueForKey: @"nspname"];
									NSString* relname = [res valueForKey: @"relname"];
									TSEnumerate (attname, e, [fields objectEnumerator])
									{
										[self logAppend: [query stringByAppendingFormat: @" -- (%@, %@, %@)",
											nspname, relname, attname]];
										[mConnection executeQuery: query parameters: nspname, relname, attname];
									}
								}
								
								NSString* query = @"SELECT baseten.prepareformodificationobserving ($1)";
								id oid = [res valueForKey: @"oid"];
								[self logAppend: [query stringByAppendingFormat: @" -- (%@)", oid]];
								[mConnection executeQuery: query parameters: oid];
							}
							success = PQTRANS_INERROR != [mConnection transactionStatus];
							query = @"COMMIT";
							[self logAppend: query];
							PGTSResultSet* res = [mConnection executeQuery: query];
							success = success && [res querySucceeded];
						}
						
						if (NO == success)
						{
							NSString* message = @"The database was updated but the tables couldn't be re-enabled.";
							NSAlert* alert = [NSAlert alertWithMessageText: @"Database error" defaultButton: @"OK" 
														   alternateButton: nil otherButton: nil 
												 informativeTextWithFormat: message];
							[alert beginSheetModalForWindow: mMainWindow modalDelegate: nil
											 didEndSelector: NULL contextInfo: NULL];
						}
						
					}
					[self reload: nil];
				}
			}
        }
    }
    [self setConnectionDict: nil];
}

- (BOOL) validateMenuItem: (NSMenuItem *) menuItem
{
    BOOL retval = YES;
    switch ([menuItem tag])
    {
        case 1:
            if (nil == mConnection || YES == [mProgressPanel isVisible])
            {
                retval = NO;
                break;
            }
            //Fall through
            
        case 2:
            if (nil != [mMainWindow attachedSheet])
                retval = NO;
            break;
            
        default:
            break;
    }
    return retval;
}

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
	[mMainWindow makeKeyAndOrderFront: nil];
	[self disconnect: nil];
}

@end


@implementation Controller (ProgressPanel)
- (void) displayProgressPanel: (NSString *) message
{
    [mProgressField setStringValue: message];
    if (NO == [mProgressPanel isVisible])
    {
        [mProgressIndicator startAnimation: nil];
        [NSApp beginSheet: mProgressPanel modalForWindow: mMainWindow modalDelegate: self didEndSelector: NULL contextInfo: NULL];
    }
}

- (void) hideProgressPanel
{
    [NSApp endSheet: mProgressPanel];
    [mProgressPanel orderOut: nil];
}
@end


@implementation Controller (Logging)

- (void) logAppend: (NSString *) string
{
    string = [string stringByAppendingString: @"\n"];
	NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor colorWithDeviceRed: 233.0 / 255.0 green: 185.0 / 255.0 blue: 89.0 / 255.0 alpha: 1.0], NSForegroundColorAttributeName,
        [NSFont fontWithName: @"Monaco" size: 11.0], NSFontAttributeName,
        nil];
	[[mLogView textStorage] appendAttributedString: [[[NSAttributedString alloc] initWithString: string attributes: attrs] autorelease]];
}

@end


@implementation Controller (InspectorDataSource)

- (int) numberOfRowsInTableView: (NSTableView *) aTableView
{
    int count = 0;
    if (mInspectorTable == aTableView)
    {
        id selection = [mTableController selectedObjects];
        if (0 < [selection count])
        {
            Table* selectedTable = [selection objectAtIndex: 0];
            PGTSTableInfo* table = [[mConnection databaseInfo] tableInfoForTableWithOid: [selectedTable oid]];
            count = [[table allFields] count];
        }
    }
    return count;
}

- (id) tableView: (NSTableView *) aTableView objectValueForTableColumn: (NSTableColumn *) aTableColumn row: (int) rowIndex
{
    id retval = nil;
    if (aTableView == mDBTableView)
    {
        if (aTableColumn == mTableEnabledColumn)
        {
            Table* currentTable = [[mTableController arrangedObjects] objectAtIndex: rowIndex];
            retval = [NSNumber numberWithBool: [currentTable prepared]]; 
        }
    }
    else
    {
        id selection = [mTableController selectedObjects];
        Table* selectedTable = [selection objectAtIndex: 0];
        PGTSTableInfo* table = [[mConnection databaseInfo] tableInfoForTableWithOid: [selectedTable oid]];
        
        id field = [table fieldInfoForFieldAtIndex: rowIndex + 1];
        if (mNameColumn == aTableColumn)
            retval = [field name];
        else if (mTypeColumn == aTableColumn)
            retval = [[field typeInfo] name];
        else if (mDetailColumn == aTableColumn)
        {
            PGTSIndexInfo* pkey = [table primaryKey];
            if ([[pkey fields] containsObject: field])
                retval = [NSNumber numberWithBool: YES];
            else
                retval = [NSNumber numberWithBool: NO];
        }
    }
    
    return retval;
}

- (void) tableViewSelectionDidChange: (NSNotification *) aNotification
{
    [self didChangeValueForKey: @"inspectorTitle"];
    [self didChangeValueForKey: @"allowSettingPrimaryKey"];
	[self didChangeValueForKey: @"allowEnabling"];
    
    [mInspectorTable reloadData];
}

- (BOOL) selectionShouldChangeInTableView: (NSTableView *) aTableView
{
    [self willChangeValueForKey: @"inspectorTitle"];
    [self willChangeValueForKey: @"allowSettingPrimaryKey"];
	[self willChangeValueForKey: @"allowEnabling"];
    return YES;
}

- (void) tableView: (NSTableView *) aTableView setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) aTableColumn row: (int) rowIndex
{
    if (mInspectorTable == aTableView)
    {
        //Only setting the primary key for views is allowed
        id selection = [mTableController selectedObjects];
        Table* selectedTable = [selection objectAtIndex: 0];
        PGTSTableInfo* table = [[mConnection databaseInfo] tableInfoForTableWithOid: [selectedTable oid]];
        
        NSString* query = nil;
        if (YES == [anObject boolValue])
            query = @"INSERT INTO \"baseten\".viewprimarykey (nspname, relname, attname) VALUES ($1, $2, $3)";
        else
            query = @"DELETE FROM \"baseten\".viewprimarykey WHERE (nspname = $1 AND relname = $2 AND attname = $3)";
		
		[self willChangeValueForKey: @"allowEnabling"];
        PGTSResultSet* res = [mConnection executeQuery: query parameters: [table schemaName], [table name], 
            [[table fieldInfoForFieldAtIndex: rowIndex + 1] name]];
        res = nil;
        
        [table setUniqueIndexes: nil];
		[self didChangeValueForKey: @"allowEnabling"];
    }
}

- (BOOL) allowSettingPrimaryKey
{
    BOOL retval = NO;
    id selection = [mTableController selectedObjects];
    if (0 < [selection count])
    {
        Table* selectedTable = [selection objectAtIndex: 0];
        if ([selectedTable isView] && NO == [selectedTable prepared])
            retval = YES;
    }
    return retval;
}

- (BOOL) allowEnabling
{
	return [self allowEnablingForRow: [mDBTableView selectedRow]];
}

- (BOOL) allowEnablingForRow: (NSInteger) rowIndex
{
	BOOL retval = NO;
	if (-1 != rowIndex)
	{
		retval = YES;
		Table* currentTable = [[mTableController arrangedObjects] objectAtIndex: rowIndex];
		if ([currentTable isView])
		{
			PGTSTableInfo* table = [[mConnection databaseInfo] tableInfoForTableWithOid: [currentTable oid]];
			if (nil == [table primaryKey])
				retval = NO;
		}	
	}
	return retval;
}

- (id) MKCTableView: (NSTableView *) tableView 
  dataCellForColumn: (MKCAlternativeDataCellColumn *) aColumn
                row: (int) rowIndex
{
    id retval = nil;
	if (NO == [self allowEnablingForRow: rowIndex])
		retval = mInspectorButtonCell;
    return retval;
}

@end
