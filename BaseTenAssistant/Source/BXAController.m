//
// BXAController.m
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


#import "BXAController.h"
#import "BXAImportController.h"
#import "BXAPGInterface.h"
#import "Additions.h"

#import "MKCBackgroundView.h"
#import "MKCPolishedHeaderView.h"
#import "MKCPolishedCornerView.h"
#import "MKCForcedSizeToFitButtonCell.h"
#import "MKCAlternativeDataCellColumn.h"
#import "MKCStackView.h"

#import <BaseTen/BXEntityDescriptionPrivate.h>
#import <BaseTen/BXPGInterface.h>
#import <BaseTen/BXDatabaseContextPrivate.h>
#import <BaseTen/BXAttributeDescriptionPrivate.h>
#import <BaseTen/BXPGTransactionHandler.h>
#import <BaseTen/BXPGDatabaseDescription.h>


#import <sys/socket.h>


static NSString* kBXAControllerCtx = @"kBXAControllerCtx";
static NSString* kBXAControllerErrorDomain = @"kBXAControllerErrorDomain";


enum BXAControllerErrorCode
{
	kBXAControllerNoError = 0,
	kBXAControllerErrorNoBaseTenSchema
};


//FIXME: come up with a way for the entities etc. to get an NSDocument or something if we want to be document based some day.
__strong static BXAController* gController = nil;


static NSError*
SchemaInstallError ()
{
	NSString* recoverySuggestion = @"BaseTen requires various functions and tables. They will be installed in a separate schema.";
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  @"Enabling a view or table requires the BaseTen schema", NSLocalizedDescriptionKey,
							  @"Enabling a view or table requires the BaseTen schema", NSLocalizedFailureReasonErrorKey,
							  recoverySuggestion, NSLocalizedRecoverySuggestionErrorKey,
							  [NSArray arrayWithObjects: @"Install", @"Don't install", nil], NSLocalizedRecoveryOptionsErrorKey,
							  gController, NSRecoveryAttempterErrorKey,
							  nil];
	NSError* error = [NSError errorWithDomain: kBXAControllerErrorDomain 
										 code: kBXAControllerErrorNoBaseTenSchema 
									 userInfo: userInfo];
	return error;	
}


NSInvocation* MakeInvocation (id target, SEL selector)
{
	NSMethodSignature* sig = [target methodSignatureForSelector: selector];
	NSInvocation* retval = [NSInvocation invocationWithMethodSignature: sig];
	[retval setTarget: target];
	[retval setSelector: selector];
	return retval;
}


@implementation BXEntityDescription (BXAControllerAdditions)
- (BOOL) canEnableForAssistant
{
	return ([self isView] || [gController hasBaseTenSchema]);
}

- (BOOL) isEnabledForAssistant
{
	return [self isEnabled];
}

- (BOOL) validateEnabledForAssistant: (id *) ioValue error: (NSError **) outError
{
	BOOL retval = YES;
	if (! ([gController hasBaseTenSchema]))
	{
		retval = NO;
		if (outError)
			*outError = SchemaInstallError ();
	}
	return retval;
}

- (void) setEnabledForAssistant: (BOOL) aBool
{
	NSLog (@"setting enabling");
	[gController process: aBool entity: self];
}

- (BOOL) isEnabledForAssistantV
{
	return [self isEnabled];
}

- (BOOL) validateEnabledForAssistantV: (id *) ioValue error: (NSError **) outError
{
	BOOL retval = YES;
	if ([self isView])
	{
		if (ioValue)
			*ioValue = [NSNumber numberWithBool: NO];
	}
	else if (! [gController hasBaseTenSchema])
	{
		retval = NO;
		if (outError)
			*outError = SchemaInstallError ();
	}
	return retval;
}

- (void) setEnabledForAssistantV: (BOOL) aBool
{
	NSLog (@"setting enabling");
	[gController process: aBool entity: self];
}

+ (NSSet *) keyPathsForValuesAffectingAllowsSettingPrimaryKey
{
	return [NSSet setWithObjects: @"isView", @"isEnabled", nil];
}

+ (NSSet *) keyPathsForValuesAffectingAllowsEnabling
{
	return [NSSet setWithObjects: @"isView", @"primaryKeyFields", nil];
}

- (BOOL) allowsEnabling
{
	BOOL retval = YES;
	if ([self isView])
		retval = (0 < [[self primaryKeyFields] count]);
	return retval;
}
@end


@implementation BXAttributeDescription (BXAControllerAdditions)
- (BOOL) isPrimaryKeyForAssistant
{
	return [self isPrimaryKey];
}

- (void) setPrimaryKeyForAssistant: (BOOL) aBool
{
	NSLog (@"setPrimaryKey: %d", aBool);
	[gController process: aBool attribute: self];
}

- (BOOL) validatePrimaryKeyForAssistant: (id *) ioValue error: (NSError **) outError
{
	BOOL retval = YES;
	if (! [gController hasBaseTenSchema])
	{
		retval = NO;
		
		if (ioValue)
			*ioValue = [NSNumber numberWithBool: NO];
				
		if (outError)
			*outError = SchemaInstallError ();
	}
	return retval;
}
@end


@implementation BXAController
- (NSPredicate *) attributeFilterPredicate
{
	return [NSPredicate predicateWithFormat: @"value.isExcluded == false"];
}

- (void) setupTableViews
{
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
		mInspectorButtonCell = [[MKCForcedSizeToFitButtonCell alloc] initTextCell: @"Setup..."];
		[mInspectorButtonCell setButtonType: NSMomentaryPushInButton];
		[mInspectorButtonCell setBezelStyle: NSRoundedBezelStyle];
		[mInspectorButtonCell setControlSize: NSMiniControlSize];
		[mInspectorButtonCell setFont: [NSFont systemFontOfSize: 
										[NSFont systemFontSizeForControlSize: NSMiniControlSize]]];
		[mInspectorButtonCell setTarget: mInspectorWindow];
		[mInspectorButtonCell setAction: @selector (makeKeyAndOrderFront:)];
	}
}

- (void) setupToolbar
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
		
		//Bindings
		switch (i)
		{
		}
		
		//Position
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


- (void) awakeFromNib
{
	gController = self;
	mLastSelectedEntityWasView = YES;

	mReader = [[BXPGSQLScriptReader alloc] init];
	[mReader setDelegate: self];
	//FIXME: instead change the SQL script so that statements like CREATE LANGUAGE plpgsql don't produce errors (considering existence, not privileges).
	[mReader setIgnoresErrors: YES];	
	
	[[mContext class] setInterfaceClass: [BXAPGInterface class] forScheme: @"pgsql"];
	
	//Make main window's bottom edge lighter
	[mMainWindow setContentBorderThickness: 24.0 forEdge: NSMinYEdge];

	[self setupToolbar];
	[self setupTableViews];
	
	[mProgressIndicator setUsesThreadedAnimation: YES];
	
	NSNotificationCenter* nc = [mContext notificationCenter];
	[nc addObserver: self selector: @selector (connected:) name: kBXConnectionSuccessfulNotification object: nil];
	[nc addObserver: self selector: @selector (failedToConnect:) name: kBXConnectionFailedNotification object: nil];
	
	[mEntities addObserver: self forKeyPath: @"selection" 
				   options: NSKeyValueObservingOptionInitial
				   context: kBXAControllerCtx];
	
	[mProgressCancelButton setTarget: self];
}


- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object 
						 change: (NSDictionary *) change context: (void *) context
{
    if (context == kBXAControllerCtx) 
	{
		//selection.[...].isView might give us an NSStateMarker, which we don't want.
		BOOL currentIsView = NO;
		NSArray* selectedEntities = [mEntities selectedObjects];
		if (0 < [selectedEntities count])
			currentIsView = [[[selectedEntities objectAtIndex: 0] value]isView];
		
		NSView* scrollView = [[mAttributeTable superview] superview];
		NSRect frame = [scrollView frame];			
		if (mLastSelectedEntityWasView && !currentIsView)
		{
			frame.size.height += 75.0;
			[scrollView setFrame: frame];
		}
		else if (!mLastSelectedEntityWasView && currentIsView)
		{
			frame.size.height -= 75.0;
			[scrollView setFrame: frame];
		}
		mLastSelectedEntityWasView = currentIsView;
	}
	else 
	{
		[super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
	}
}


- (void) continueDisconnect
{	
	[mContext disconnect];
	[mStatusTextField setStringValue: @"Not connected."];
	[mStatusTextField makeEtchedSmall: YES];
	[self hideProgressPanel];
	[NSApp beginSheet: mConnectPanel modalForWindow: mMainWindow modalDelegate: self 
	   didEndSelector: NULL contextInfo: NULL];	
}


- (BOOL) allowEnablingForRow: (NSInteger) rowIndex
{
	BOOL retval = NO;
	if (-1 != rowIndex)
	{
		retval = YES;
		BXEntityDescription* entity = [[[mEntities arrangedObjects] objectAtIndex: rowIndex] value];
		if ([entity isView])
		{
			if (! [[entity primaryKeyFields] count])
				retval = NO;
		}	
	}
	return retval;
}


- (BOOL) hasBaseTenSchema
{
	return [[[(BXPGInterface *) [mContext databaseInterface] transactionHandler] 
			 databaseDescription] hasBaseTenSchema];
}


- (NSWindow *) mainWindow
{
	return mMainWindow;
}


- (void) process: (BOOL) newState entity: (BXEntityDescription *) entity
{	
	if (![entity isView] || [[entity primaryKeyFields] count])
	{
		NSError* localError = nil;
		NSArray* entityArray = [NSArray arrayWithObject: entity];
		[(BXPGInterface *) [mContext databaseInterface] process: newState entities: entityArray error: &localError];
		if (localError)
		{
			[entity setIsEnabled: !newState];
			[NSApp presentError: localError modalForWindow: mMainWindow delegate: nil didPresentSelector: NULL contextInfo: NULL];
		}
	}
}

- (void) process: (BOOL) newState attribute: (BXAttributeDescription *) attribute
{
	NSError* localError = nil;
	NSArray* attributeArray = [NSArray arrayWithObject: attribute];
	[(BXPGInterface *) [mContext databaseInterface] process: newState primaryKeyFields: attributeArray error: &localError];
	if (localError)
	{
		[attribute setPrimaryKey: !newState];
		[NSApp presentError: localError modalForWindow: mMainWindow delegate: nil didPresentSelector: NULL contextInfo: NULL];
	}
}

- (void) logAppend: (NSString *) string
{
	NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:
						   [NSColor colorWithDeviceRed: 233.0 / 255.0 green: 185.0 / 255.0 blue: 89.0 / 255.0 alpha: 1.0], NSForegroundColorAttributeName,
						   [NSFont fontWithName: @"Monaco" size: 11.0], NSFontAttributeName,
						   nil];
	[[mLogView textStorage] appendAttributedString: [[[NSAttributedString alloc] initWithString: string attributes: attrs] autorelease]];

	NSRange range = NSMakeRange ([[[mLogView textStorage] string] length], 0);
    [mLogView scrollRangeToVisible: range];
	
}
@end


@implementation BXAController (ProgressPanel)
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
	[mProgressIndicator setIndeterminate: YES];
}

- (void) importModelAtURL: (NSURL *) URL
{
	if (! mImportController)
	{
		mImportController = [[BXAImportController alloc] initWithWindowNibName: @"Import"];
		[mImportController setDatabaseContext: mContext];
	}
	
	NSManagedObjectModel* model = [[NSManagedObjectModel alloc] initWithContentsOfURL: URL];
	[mImportController setObjectModel: model];
	[mImportController setController: self];
	[mImportController showPanel];	
}

- (void) compileAndImportModelAtURL: (NSURL *) URL
{
	if (! mCompiler)
	{
		mCompiler = [[BXDataModelCompiler alloc] init];
		[mCompiler setDelegate: self];
	}
	[mCompiler setModelURL: URL];
	[mCompiler compileDataModel];
}

- (void) installBaseTenSchema: (NSInvocation *) callback
{
	NSString* path = [[NSBundle mainBundle] pathForResource: @"BaseTenModifications" ofType: @"sql"];
	if (path)
	{
		NSURL* url = [NSURL fileURLWithPath: path];
		if ([mReader openFileAtURL: url])
		{			
			[mProgressIndicator setIndeterminate: NO];
			[mProgressIndicator setMinValue: 0.0];
			[mProgressIndicator setMaxValue: [mReader length]];
			[mProgressCancelButton setAction: @selector (cancelSchemaInstall:)];
			
			[self displayProgressPanel: @"Installing BaseTen schema…"];
			
			[mReader setDelegateUserInfo: callback];
			[mReader readAndExecuteAsynchronously];
		}
		else
		{
			//FIXME: handle the error.
		}
	}
	else
	{
		//FIXME: handle the error.
	}
}

- (void) continueImport
{
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection: NO];
	[openPanel setCanChooseDirectories: NO];
	[openPanel setCanChooseFiles: YES];
	[openPanel setResolvesAliases: YES];
	NSArray* types = [NSArray arrayWithObjects: @"xcdatamodel", @"xcdatamodeld", @"mom", @"momd", nil];
	[openPanel beginSheetForDirectory: nil file: nil types: types modalForWindow: mMainWindow modalDelegate: self 
					   didEndSelector: @selector (importOpenPanelDidEnd:returnCode:contextInfo:) contextInfo: NULL];	
}
@end


@implementation BXAController (Delegation)
- (void) dataModelCompiler: (BXDataModelCompiler *) compiler finished: (int) exitStatus errorOutput: (NSFileHandle *) handle
{
	if (0 == exitStatus)
	{
		NSURL* modelURL = [mCompiler compiledModelURL];
		[self importModelAtURL: modelURL];
	}
	else
	{
		NSData* output = [handle availableData];
		const char* const bytes = [output bytes];
		const char* const outputEnd = bytes + [output length];
		const char* line = bytes;
		const char* end = memchr (line, '\n', outputEnd - line);
		
		while (end && line < outputEnd && end < outputEnd)
		{
			NSString* lineString = [[NSString alloc] initWithBytes: line length: end - line encoding: NSUTF8StringEncoding];
			line = end + 1;
			end = memchr (line, '\n', outputEnd - line);
			
			
			NSTextView* textView = [[NSTextView alloc] initWithFrame: NSZeroRect];
			[[[textView textStorage] mutableString] setString: lineString];
			//100000000 comes from the manual; it's the "allowed maximum size".
			[[textView textContainer] setContainerSize: NSMakeSize (100000000.0, 100000000.0)];
			[[textView textContainer] setWidthTracksTextView: YES];
			[textView setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
			[textView setVerticallyResizable: YES];
			[textView setEditable: NO];
			[textView setDrawsBackground: NO];
			[textView setTextContainerInset: NSMakeSize (10.0, 10.0)];
			[mMomcErrorView addViewToStack: textView];
		}
		[NSApp beginSheet: mMomcErrorPanel modalForWindow: mMainWindow modalDelegate: nil didEndSelector: NULL contextInfo: NULL];
	}
}


- (NSRect) splitView: (NSSplitView *) splitView additionalEffectiveRectOfDividerAtIndex: (NSInteger) dividerIndex
{
	NSRect retval = NSZeroRect;
	if (0 == dividerIndex)
	{
		retval = [splitView convertRect: [mCornerView bounds] fromView: mCornerView];
	}
	return retval;
}


- (void) connected: (NSNotification *) n
{
	[self hideProgressPanel];
	[mStatusTextField setObjectValue: [NSString stringWithFormat: @"Connected to %@.", [mContext databaseURI]]];
	NSDictionary* entities = [mContext entitiesBySchemaAndName: NULL];
	[mEntitiesBySchema setContent: entities];
	
	NSError* error = nil;
	BXPGInterface* interface = (id) [mContext databaseInterface];
	
	[mReader setConnection: [[interface transactionHandler] connection]];
	
	[self willChangeValueForKey: @"hasBaseTenSchema"];
	if (! [[[interface transactionHandler] databaseDescription] checkBaseTenSchema: &error])
		[NSApp presentError: error modalForWindow: mMainWindow delegate: nil didPresentSelector: NULL contextInfo: NULL];
	[self didChangeValueForKey: @"hasBaseTenSchema"];
}


- (void) failedToConnect: (NSNotification *) n
{
	[self hideProgressPanel];
}


- (id) MKCTableView: (NSTableView *) tableView 
  dataCellForColumn: (MKCAlternativeDataCellColumn *) aColumn
                row: (int) rowIndex
			current: (NSCell *) currentCell
{
    id retval = nil;
	if (NO == [self allowEnablingForRow: rowIndex])
		retval = mInspectorButtonCell;
		
    return retval;
}


- (BOOL) selectionShouldChangeInTableView: (NSTableView *) aTableView
{
	[self willChangeValueForKey: @"selectedEntityEnabled"];
	return YES;
}


- (void) tableViewSelectionDidChange: (NSNotification *) aNotification
{
	[self didChangeValueForKey: @"selectedEntityEnabled"];
}


- (BOOL) validateMenuItem: (NSMenuItem *) menuItem
{
    BOOL retval = YES;
    switch ([menuItem tag])
    {
		case 0:
			return retval;
			
        case 1: //Disconnect, Reload
            if (! [mContext isConnected] || YES == [mProgressPanel isVisible])
            {
                retval = NO;
                break;
            }
			
		case 2: //Quit
			break;
			
		case 3: //Import
			retval = [self hasBaseTenSchema];
			break;
			
    }
	if (nil != [mMainWindow attachedSheet])
		retval = NO;
	
    return retval;
}


- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
	[mMainWindow makeKeyAndOrderFront: nil];
	[self disconnect: nil];
}


- (void) importOpenPanelDidEnd: (NSOpenPanel *) panel returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    if (NSOKButton == returnCode)
    {		
        NSURL* URL = [[panel URLs] objectAtIndex: 0];
		NSString* URLString = [URL path];
        if ([URLString hasSuffix: @".mom"] || [URLString hasSuffix: @".momd"])
		{
			//Delay a bit so the open panel gets removed.
			[[NSRunLoop currentRunLoop] performSelector: @selector (importModelAtURL:) target: self argument: URL 
												  order: NSUIntegerMax modes: [NSArray arrayWithObject: NSRunLoopCommonModes]];
		}
        else
		{
			[self compileAndImportModelAtURL: URL];
		}
    }
}

- (void) attemptRecoveryFromError: (NSError *) error 
					  optionIndex: (NSUInteger) recoveryOptionIndex 
						 delegate: (id) delegate 
			   didRecoverSelector: (SEL) didRecoverSelector 
					  contextInfo: (void *) contextInfo
{
	if ([error domain] != kBXAControllerErrorDomain)
		[self doesNotRecognizeSelector: _cmd];
	else
	{
		switch ([error code])
		{
			case kBXAControllerErrorNoBaseTenSchema:
			{
				NSInvocation* recoveryInvocation = MakeInvocation (delegate, didRecoverSelector);
				[recoveryInvocation setArgument: &contextInfo atIndex: 3];

				if (0 == recoveryOptionIndex)
					[self installBaseTenSchema: recoveryInvocation];					
				else
				{
					BOOL status = NO;
					[recoveryInvocation setArgument: &status atIndex: 2];
					[recoveryInvocation invoke];
				}
				
				break;
			}
				
			default:
				[self doesNotRecognizeSelector: _cmd];
				break;
		}
	}
}

- (BOOL) attemptRecoveryFromError: (NSError *) error optionIndex: (NSUInteger) recoveryOptionIndex
{
	BOOL retval = NO;
	if ([error domain] != kBXAControllerErrorDomain)
		[self doesNotRecognizeSelector: _cmd];
	else
	{
		switch ([error code])
		{
			case kBXAControllerErrorNoBaseTenSchema:
			{
				if (0 == recoveryOptionIndex)
				{
					[self installBaseTenSchema: MakeInvocation (NSApp, @selector (stopModalWithCode:))];
					retval = [NSApp runModalForWindow: mMainWindow];
				}
				break;
			}
			
			default:
				[self doesNotRecognizeSelector: _cmd];
				break;
		}
	}
	return retval;
}

//Works with any invocation as long as the first visible argument is the status.
static void
InvokeRecoveryInvocation (NSInvocation* recoveryInvocation, BOOL status)
{
	[recoveryInvocation setArgument: &status atIndex: 2];
	[recoveryInvocation invoke];
}

- (void) SQLScriptReaderSucceeded: (BXPGSQLScriptReader *) reader userInfo: (id) userInfo
{
	[mProgressIndicator setMaxValue: 0.0];
	[mProgressIndicator setDoubleValue: 0.0];
	[mProgressIndicator display];
	[self hideProgressPanel];
	
	InvokeRecoveryInvocation (userInfo, YES);
	[reader setDelegateUserInfo: nil];
}

- (void) SQLScriptReader: (BXPGSQLScriptReader *) reader failed: (PGTSResultSet *) res userInfo: (id) userInfo
{
	[self hideProgressPanel];
	
	InvokeRecoveryInvocation (userInfo, NO);
	[reader setDelegateUserInfo: nil];
	
	if (res)
	{
		[NSApp presentError: [res error] modalForWindow: mMainWindow delegate: nil 
		 didPresentSelector: NULL contextInfo: NULL];
	}
}

- (void) SQLScriptReader: (BXPGSQLScriptReader *) reader advancedToPosition: (off_t) position userInfo: (id) userInfo
{
	[mProgressIndicator setDoubleValue: (double) position];
}
@end


@implementation BXAController (IBActions)
- (IBAction) disconnect: (id) sender
{
	[self continueDisconnect];
}


- (IBAction) terminate: (id) sender
{
    [mConnectPanel orderOut: nil];
    [self hideProgressPanel];	
    [NSApp terminate: nil];
}


- (IBAction) connect: (id) sender
{	
	NSString* username = [mUserNameCell objectValue];
	NSString* password = [mPasswordField objectValue];
	NSString* credentials = (0 < [password length] ? [NSString stringWithFormat: @"%@:%@", username, password] : username);
	
	NSString* host = [mHostCell objectValue];
	id port = [mPortCell objectValue];
	NSString* target = (port ? [NSString stringWithFormat: @"%@:%@", host, port] : host);
	
	NSString* URIFormat = [NSString stringWithFormat: @"pgsql://%@@%@/%@", credentials, target, [mDBNameCell objectValue]];
	NSURL* connectionURI = [NSURL URLWithString: URIFormat];
	[mContext setDatabaseURI: connectionURI];
	[(id) [mContext databaseInterface] setController: self];
	
    [NSApp endSheet: mConnectPanel];
    [mConnectPanel orderOut: nil];
    
	[mProgressCancelButton setAction: @selector (cancelConnecting:)];
    [self displayProgressPanel: @"Connecting..."];
		
	[mContext connect];
}


- (IBAction) importDataModel: (id) sender
{
	//If we want some kind of a warning to be displayed if the user doesn't have the schema,
	//it should be done here.
	[self continueImport];
}


- (IBAction) dismissMomcErrorPanel: (id) sender
{
	[mMomcErrorPanel orderOut: nil];
	[mMomcErrorView removeAllViews];
	[NSApp endSheet: mMomcErrorPanel];
}


- (IBAction) clearLog: (id) sender
{
    [[[mLogView textStorage] mutableString] setString: @""];    
}


- (IBAction) displayLogWindow: (id) sender
{
	[mLogWindow makeKeyAndOrderFront: nil];
}


- (IBAction) cancelConnecting: (id) sender
{
	[self continueDisconnect];
}

- (IBAction) cancelSchemaInstall: (id) sender
{
	[mReader cancel];
}
@end


@implementation NSArrayController (BaseTenSetupApplicationAdditions)
- (BOOL) MKCHasEmptySelection
{
    return NSNotFound == [self selectionIndex];
}
@end
