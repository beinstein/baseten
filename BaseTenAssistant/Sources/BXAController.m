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
#import "BXAGetInfoWindowController.h" //Patch by Tim Bedford 2008-08-11
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
//Patch by Tim Bedford 2008-08-11
#import <netinet/in.h>
#import <arpa/inet.h>
//End patch
#import <RegexKit/RegexKit.h>


extern NSNumber* BXACopyBundledVersionNumber ();


static NSString* kBXAControllerCtx = @"kBXAControllerCtx";
static NSString* kBXAControllerErrorDomain = @"kBXAControllerErrorDomain";


enum BXAControllerErrorCode
{
	kBXAControllerNoError = 0,
	kBXAControllerErrorNoBaseTenSchema,
	//Patch by Tim Bedford 2008-08-11
	kBXAControllerErrorNoBaseTenSchemaDefinition,
	kBXAControllerErrorCouldNotInstallBaseTenSchema,
	kBXAControllerErrorCouldNotConnect
	//End patch
};


//FIXME: come up with a way for the entities etc. to get an NSDocument or something if we want to be document based some day.
__strong static BXAController* gController = nil;


NSInvocation* MakeInvocation (id target, SEL selector)
{
	NSMethodSignature* sig = [target methodSignatureForSelector: selector];
	NSInvocation* retval = [NSInvocation invocationWithMethodSignature: sig];
	[retval setTarget: target];
	[retval setSelector: selector];
	return retval;
}


@implementation BXEntityDescription (BXAControllerAdditions)
+ (NSSet *) keyPathsForValuesAffectingCanSetPrimaryKey
{
	return [NSSet setWithObjects: @"isEnabled", nil];
}

- (BOOL) canSetPrimaryKey
{
	return ([self isView] && ![self isEnabled]);
}

+ (NSSet *) keyPathsForValuesAffectingCanEnableForAssistant
{
	return [NSSet setWithObject: @"primaryKeyFields"];
}

- (BOOL) canEnableForAssistant
{
	return (! [self isView] || 0 < [[self primaryKeyFields] count]);
}

+ (NSSet *) keyPathsForValuesAffectingEnabledForAssistant
{
	return [NSSet setWithObject: @"enabled"];
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
			*outError = [gController schemaInstallError];
	}
	return retval;
}

- (void) setEnabledForAssistant: (BOOL) aBool
{
	[gController process: aBool entity: self];
}

+ (NSSet *) keyPathsForValuesAffectingEnabledForAssistantV
{
	return [NSSet setWithObject: @"enabled"];
}

- (BOOL) isEnabledForAssistantV
{
	return [self isEnabled];
}

- (BOOL) validateEnabledForAssistantV: (id *) ioValue error: (NSError **) outError
{
	BOOL retval = YES;
	if ([self isView] && 0 == [[self primaryKeyFields] count])
	{
		if (ioValue)
			*ioValue = [NSNumber numberWithBool: NO];
	}
	else if (! [gController hasBaseTenSchema])
	{
		retval = NO;
		if (outError)
			*outError = [gController schemaInstallError];
	}
	return retval;
}

- (void) setEnabledForAssistantV: (BOOL) aBool
{
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
			*outError = [gController schemaInstallError];
	}
	return retval;
}
@end



@implementation BXAController

//Patch by Tim Bedford 2008-08-11
- (id) init
{
	if(![super init])
		return nil;
	
	mServiceBrowser = [[NSNetServiceBrowser alloc] init];
	[mServiceBrowser setDelegate:self];
	
	return self;
}
//End patch

- (NSError *) schemaInstallError
{
	NSError* error = nil;
	NSString* recoverySuggestion = NSLocalizedString(@"schemaInstallRecoverySuggestion", @"Recovery suggestion"); 	//Patch by Tim Bedford 2008-08-11
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  //Patch by Tim Bedford 2008-08-11
							  NSLocalizedString(@"schemaInstallErrorDescription", @""), NSLocalizedDescriptionKey,
							  NSLocalizedString(@"schemaInstallErrorReason", @""), NSLocalizedFailureReasonErrorKey,
							  recoverySuggestion, NSLocalizedRecoverySuggestionErrorKey,
							  [NSArray arrayWithObjects: NSLocalizedString(@"Install", @"Button label"), NSLocalizedString(@"Don't Install", @"Button label"), nil], NSLocalizedRecoveryOptionsErrorKey,
							  //End patch
							  gController, NSRecoveryAttempterErrorKey,
							  nil];
	error = [NSError errorWithDomain: kBXAControllerErrorDomain 
								code: kBXAControllerErrorNoBaseTenSchema 
							userInfo: userInfo];
	return error;	
}

- (BOOL) schemaInstallDenied
{
	return mDeniedSchemaInstall;
}

- (NSPredicate *) attributeFilterPredicate
{
	return [NSPredicate predicateWithFormat: @"value.isExcluded == false"];
}

- (void) setupTableViews
{
	//Table headers
	{
		NSMutableDictionary* colours = [[MKCPolishedHeaderView darkColours] mutableCopy];
		[colours setObject: [colours objectForKey: kMKCEnabledColoursKey] forKey: kMKCSelectedColoursKey];
		
		NSRect headerRect = NSMakeRect (0.0, 0.0, 0.0, 23.0);
		headerRect.size.width = [mDBTableView bounds].size.width;
		MKCPolishedHeaderView* headerView = (id) [mDBTableView headerView];
		[headerView setFrame: headerRect];
		[headerView setColours: colours];
		[headerView setDrawingMask: kMKCPolishDrawBottomLine | 
		 kMKCPolishDrawLeftAccent | kMKCPolishDrawTopAccent | kMKCPolishDrawSeparatorLines];
		
		headerView = (id) [mDBSchemaView headerView];
		headerRect.size.width = [mDBSchemaView bounds].size.width;
		[headerView setColours: colours];
		[headerView setFrame: headerRect];
		[headerView setDrawingMask: kMKCPolishDrawBottomLine | kMKCPolishDrawTopAccent];
	}
	
	//Table corners
	{
		NSRect cornerRect = NSMakeRect (0.0, 0.0, 15.0, 23.0);
		MKCPolishedCornerView* otherCornerView = [[MKCPolishedCornerView alloc] initWithFrame: cornerRect];
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

- (BOOL) checkBaseTenSchema: (NSError **) error
{
	NSError* localError = nil;
	[self willChangeValueForKey: @"hasBaseTenSchema"];
	BXPGDatabaseDescription* db = [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] databaseDescription];
	BOOL retval = [db checkBaseTenSchema: &localError];
	[self didChangeValueForKey: @"hasBaseTenSchema"];

	if (! retval)
	{
		if (error)
			*error = localError;
		else
			[NSApp presentError: localError modalForWindow: mMainWindow delegate: nil didPresentSelector: NULL contextInfo: NULL];
	}
	
	return retval;
}


- (BOOL) canUpgradeSchema
{
	BOOL retval = NO;
	BXPGDatabaseDescription* db = [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] databaseDescription];
	NSNumber* currentVersion = [db schemaVersion];
	if (currentVersion && NSOrderedDescending == [mBundledSchemaVersionNumber compare: currentVersion])
		retval = YES;
	return retval;
}


//Patch by Tim Bedford 2008-08-11
- (BOOL) canImportDataModel
{
	return [mContext isConnected];
}

- (BOOL) canExportLog
{
	// Can't export an empty log
	return ([[mLogView textStorage] length] > 0);
}

- (void) awakeFromNib
{
	gController = self;
	mLastSelectedEntityWasView = YES;
	mBundledSchemaVersionNumber = BXACopyBundledVersionNumber ();

	//Patch by Tim Bedford 2008-08-11
	[mMainWindow setExcludedFromWindowsMenu:YES];
	
	// Bind the InspectorPanelController to the current entity selection
	BXAInspectorPanelController* inspector = [BXAInspectorPanelController inspectorPanelController];
	[inspector bindEntityToObject:mEntities withKeyPath:@"selection.value"];
	//End patch

	mReader = [[BXPGSQLScriptReader alloc] init];
	[mReader setDelegate: self];
	//FIXME: instead change the SQL script so that statements like CREATE LANGUAGE plpgsql don't produce errors (considering existence, not privileges).
	[mReader setIgnoresErrors: YES];	
	
	[[mContext class] setInterfaceClass: [BXAPGInterface class] forScheme: @"pgsql"];
	[mContext setDelegate: self];
	
	//Make main window's bottom edge lighter
	[mMainWindow setContentBorderThickness: 24.0 forEdge: NSMinYEdge];
	[mStatusTextField makeEtchedSmall:YES]; //Patch by Tim Bedford 2008-08-12

	[self setupTableViews];
	
	[mProgressIndicator setUsesThreadedAnimation: YES];	
	[mEntities addObserver: self forKeyPath: @"selection" 
				   options: NSKeyValueObservingOptionInitial
				   context: kBXAControllerCtx];
	
	[mProgressCancelButton setTarget: self];
	
	NSString* regex = @"Compilation failed for data model at path";
	mCompilationFailedRegex = [[RKRegex alloc] initWithRegexString: regex options: RKCompileNoOptions];
	regex = @"/([^/]+.xcdatamodel[d]?.+)$";
	mCompilationErrorRegex = [[RKRegex alloc] initWithRegexString: regex options: RKCompileNoOptions];
	
	//Set main window's position and display it.
	//Frame name format from NSWindow's documentation.
	NSString* key = @"NSWindow Frame mainWindow";
	NSString* frameString = [[NSUserDefaults standardUserDefaults] objectForKey: key];
	[mMainWindow setFrameAutosaveName: @"mainWindow"];
	if (! frameString)
		[mMainWindow center];
	[mMainWindow makeKeyAndOrderFront: nil];
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

//Patch by Tim Bedford 2008-08-11
- (void) displayConnectPanel
{	
	mServices = [[NSMutableArray alloc] init];
	[mServiceBrowser searchForServicesOfType:@"_postgresql._tcp" inDomain:@"local."];	
	[NSApp beginSheet: mConnectPanel modalForWindow: mMainWindow modalDelegate: self 
	   didEndSelector: NULL contextInfo: NULL];
}

- (void) hideConnectPanel
{
	mServices = nil;
	mSearching = NO;
	[mServiceBrowser stop];
	
	[NSApp endSheet: mConnectPanel];
	[mConnectPanel orderOut: nil];
}

- (void) finishDisconnect
{
	//End patch
	[mEntitiesBySchema setContent: nil];
	[mContext disconnect];
	[mStatusTextField setStringValue: NSLocalizedString(@"Not connected", @"Database status message")]; //Patch by Tim Bedford 2008-08-11
	[mStatusTextField makeEtchedSmall: YES];
	[self hideProgressPanel];
	
	[self displayConnectPanel]; //Patch by Tim Bedford 2008-08-11
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
			[entity setEnabled: !newState];
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
	//Patch by Tim Bedford 2008-08-11
	NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	[paragraphStyle setHeadIndent:(CGFloat)32.0];
	//End patch
	
	NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys:
						   paragraphStyle, NSParagraphStyleAttributeName, //Patch by Tim Bedford 2008-08-11
						   [NSColor colorWithDeviceRed: 233.0 / 255.0 green: 185.0 / 255.0 blue: 89.0 / 255.0 alpha: 1.0], NSForegroundColorAttributeName,
						   [NSFont fontWithName: @"Monaco" size: 11.0], NSFontAttributeName,
						   nil];
	[[mLogView textStorage] appendAttributedString: [[NSAttributedString alloc] initWithString: string attributes: attrs]];

	NSRange range = NSMakeRange ([[[mLogView textStorage] string] length], 0);
    [mLogView scrollRangeToVisible: range];
	
}

//Patch by Tim Bedford 2008-08-11
- (void) finishExportLogWithURL: (NSURL *) URL
{
	NSData* data = [[[mLogView textStorage] string] dataUsingEncoding:NSUTF8StringEncoding];
	NSError* error;
	BOOL successful = [data writeToURL:URL options:0 error:&error];
	
	if(!successful)
	{
		NSAlert* alert = [NSAlert alertWithError:error];
		[alert runModal];
	}
}
//End patch

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

- (void) installBaseTenSchema: (NSInvocation *) callback error:(NSError **)error //Patch by Tim Bedford 2008-08-11
{
	NSError *outError = nil; //Patch by Tim Bedford 2008-08-11
	NSString* path = [[NSBundle mainBundle] pathForResource: @"BaseTenModifications" ofType: @"sql"];
	if (path)
	{
		NSURL* url = [NSURL fileURLWithPath: path];
		if ([mReader openFileAtURL: url])
		{	
			[self setProgressMin: 0.0 max: [mReader length]];
			[mProgressCancelButton setAction: @selector (cancelSchemaInstall:)];
			
			[self displayProgressPanel: NSLocalizedString(@"Installing BaseTen schema…", @"Progress panel message")]; //Patch by Tim Bedford 2008-08-11
			
			[mReader setDelegateUserInfo: callback];
			[mReader readAndExecuteAsynchronously];
		}
		else
		{
			outError = [NSError errorWithDomain:kBXAControllerErrorDomain code:kBXAControllerErrorCouldNotInstallBaseTenSchema userInfo:nil]; //Patch by Tim Bedford 2008-08-11
		}
	}
	else
	{
		outError = [NSError errorWithDomain:kBXAControllerErrorDomain code:kBXAControllerErrorNoBaseTenSchemaDefinition userInfo:nil]; //Patch by Tim Bedford 2008-08-11
	}
	
	*error = outError; //Patch by Tim Bedford 2008-08-11
}

- (void) finishUpgrading: (BOOL) status
{
	PGTSConnection* connection = [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] connection];

	if (status)
	{
		PGTSResultSet* res = nil;
		res = [connection executeQuery: @"INSERT INTO baseten.viewprimarykey SELECT * FROM baseten_viewprimarykey"];
		if (! [res querySucceeded])
			[NSApp presentError: [res error]];
		else
		{
			res = [connection executeQuery: @"SELECT baseten.prepareformodificationobserving (oid) FROM baseten_enabledoids"];
			if (! [res querySucceeded])
				[NSApp presentError: [res error]];
		}
	}
	
	//Clean up.
	[connection executeQuery: @"DROP TABLE baseten_viewprimarykey"];
	[connection executeQuery: @"DROP TABLE baseten_enabledoids"];
}

- (void) upgradeBaseTenSchema
{
	PGTSConnection* connection = [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] connection];
	[connection executeQuery: @"CREATE TEMPORARY TABLE baseten_viewprimarykey AS SELECT * FROM baseten.viewprimarykey"];
	NSError* error; //Patch by Tim Bedford 2008-08-11
	NSString* query = 
	@"CREATE TEMPORARY TABLE baseten_enabledoids AS "
	@" SELECT oid FROM pg_class WHERE baseten.isobservingcompatible (oid) = true";
	[connection executeQuery: query];
	
	//Patch by Tim Bedford 2008-08-11
	[self installBaseTenSchema: MakeInvocation (self, @selector (finishUpgrading:)) error:&error];
	//FIXME: handle the error.
	//End patch
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

- (void) finishedImporting
{
	NSDictionary* entities = [mContext entitiesBySchemaAndName: YES error: NULL];
	[mEntitiesBySchema setContent: entities];
}

- (BOOL) canRemoveSchema
{
	return [[[(BXPGInterface *) [mContext databaseInterface] transactionHandler] 
			 databaseDescription] hasBaseTenSchema];
}
@end


@implementation BXAController (ProgressPanel)
- (void) setProgressMin: (double) min max: (double) max
{
	[mProgressIndicator setIndeterminate: NO];
	[mProgressIndicator setMinValue: min];
	[mProgressIndicator setMaxValue: max];
	[mProgressIndicator setDoubleValue: min];
}

- (void) setProgressValue: (double) value
{
	[mProgressIndicator setDoubleValue: value];
}

- (void) advanceProgress
{
	[mProgressIndicator incrementBy: 1.0];
}

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
	[self setProgressMin: 0.0 max: 0.0];
	[mProgressPanel displayIfNeeded];
    [NSApp endSheet: mProgressPanel];
    [mProgressPanel orderOut: nil];
	[mProgressIndicator setIndeterminate: YES];
}

@end


@implementation BXAController (Delegation)
- (void) alertDidEnd: (NSAlert *) alert returnCode: (int) returnCode contextInfo: (void *) ctx
{
	[NSApp stopModalWithCode: returnCode];
}

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
			
			if ([lineString isMatchedByRegex: mCompilationFailedRegex])
				continue;
			
			[lineString getCapturesWithRegexAndReferences: mCompilationErrorRegex, @"${1}", &lineString, nil];
			
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


- (void) databaseContextConnectionSucceeded: (BXDatabaseContext *) ctx
{
	[self setProgressMin: 0.0 max: 0.0];
	[mProgressIndicator setIndeterminate: YES];
	
	//Patch by Tim Bedford 2008-08-11
	[mStatusTextField setObjectValue: [NSString stringWithFormat: NSLocalizedString(@"ConnectedToFormat", @"Database status message format"),
									  [mContext databaseURI]]];
	[mStatusTextField makeEtchedSmall:YES];
	[self displayProgressPanel:NSLocalizedString(@"Reading data model", @"Progress panel message")];
	[self hideProgressPanel];
	//End patch

	NSDictionary* entities = [mContext entitiesBySchemaAndName: YES error: NULL];
	[mEntitiesBySchema setContent: entities];
	
	BXPGInterface* interface = (id) [mContext databaseInterface];
	[mReader setConnection: [[interface transactionHandler] connection]];
	
	if ([self checkBaseTenSchema: NULL] && [self canUpgradeSchema])
	{
		//Patch by Tim Bedford 2008-08-11
		NSString* message = NSLocalizedString(@"schemaUpgradeMessage", @"Alert message");
		NSAlert* alert = [NSAlert alertWithMessageText: NSLocalizedString(@"Upgrade BaseTen schema?", "Alert message") 
										 defaultButton: NSLocalizedString(@"Upgrade", @"Default button label")
									   alternateButton: NSLocalizedString(@"Don't Upgrade", @"Button label")
						  //End patch
										   otherButton: nil 
							 informativeTextWithFormat: message];
		[alert beginSheetModalForWindow: mMainWindow modalDelegate: self 
						 didEndSelector: @selector (alertDidEnd:returnCode:contextInfo:) contextInfo: NULL];
		NSInteger returnCode = [NSApp runModalForWindow: mMainWindow];
		
		if (NSAlertDefaultReturn == returnCode)
			[self upgradeBaseTenSchema];
	}
}


- (void) databaseContext: (BXDatabaseContext *) ctx failedToConnect: (NSError *) dbError
{
	[self hideProgressPanel];
	
	//Patch by Tim Bedford 2008-08-11
	// Display error
	NSDictionary* errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							   NSLocalizedString(@"CouldntConnectDescription", @""), NSLocalizedDescriptionKey,
							   NSLocalizedString(@"CouldntConnectRecoverySuggestion", @""), NSLocalizedRecoverySuggestionErrorKey, nil];
	NSError* error = [NSError errorWithDomain: kBXAControllerErrorDomain code: kBXAControllerErrorCouldNotConnect userInfo: errorInfo];
	NSAlert* alert = [NSAlert alertWithError: error];

	[alert beginSheetModalForWindow: mMainWindow modalDelegate: self didEndSelector: @selector(alertDidEnd:returnCode:contextInfo:) contextInfo: nil];
	[NSApp runModalForWindow: mMainWindow];

	// Reopen connection sheet
	[self displayConnectPanel];
	//End patch
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
	//Patch by Tim Bedford 2008-08-11
	SEL action = [menuItem action];
    BOOL retval;
	
	if([mMainWindow attachedSheet] == nil)
	{
		retval = YES; // YES by default
		if(action == @selector(upgradeSchema:))
			retval = [self canUpgradeSchema];
		else if(action == @selector(removeSchema:))
			retval = [self canRemoveSchema];
		else if(action == @selector(exportLog:))
			retval = [self canExportLog];
		else if(action == @selector(importDataModel:))
			retval = [self canImportDataModel];
		else if(action == @selector(disconnect:) || action == @selector(reload:))
			retval = ([mContext isConnected] && ![mProgressPanel isVisible]);
		else if(action == @selector(getInfo:))
			retval = ([[mEntities selectedObjects] count] > 0);
		else if(action == @selector(toggleMainWindow:))
		{
			if([mMainWindow isVisible])
				[menuItem setTitle:NSLocalizedString(@"Hide Main Window", @"MenuItem title")];
			else
				[menuItem setTitle:NSLocalizedString(@"Show Main Window", @"MenuItem title")];
		}
		else if(action == @selector(toggleInspector:))
		{
			if([[BXAGetInfoWindowController inspectorPanelController] isWindowVisible])
				[menuItem setTitle:NSLocalizedString(@"Hide Inspector", @"MenuItem title")];
			else
				[menuItem setTitle:NSLocalizedString(@"Show Inspector", @"MenuItem title")];
		}
	}
	else
	{
		retval = NO; // NO by default when a sheet is displayed
		if(action == @selector(chooseBonjourService:))
			retval = YES;
		else if(action == @selector(terminate:) && [mMainWindow attachedSheet] == (NSWindow*)mConnectPanel)
			retval = YES; // Enable quit if the connect panel up because a quit button is available on the dialogue
	}
	//End patch
    return retval;
}


//Patch by Tim Bedford 2008-08-11
-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	SEL action = [toolbarItem action];
	BOOL retval = YES;
	
	if(action == @selector(importDataModel:))
		retval = [self canImportDataModel];
	else if(action == @selector(getInfo:))
		retval = ([[mEntities selectedObjects] count] > 0);
	else if(action == @selector(exportLog:))
		retval = [self canExportLog];
	
	return retval;
}
//End patch


- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
	[mMainWindow makeKeyAndOrderFront: nil];
	
	//Patch by Tim Bedford 2008-08-11
	// This seems a bit strange, but by sending a disconnect message the status text is set to "Not connected"
	// it then automatically displays the connect panel
	//End patch
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
				NSError* installError; //Patch by Tim Bedford 2008-08-11
				NSInvocation* recoveryInvocation = MakeInvocation (delegate, didRecoverSelector);
				[recoveryInvocation setArgument: &contextInfo atIndex: 3];
				
				if (0 == recoveryOptionIndex)
				{
					//Patch by Tim Bedford 2008-08-11
					[self installBaseTenSchema: recoveryInvocation error:&installError];
					//FIXME: handle the error.
					//End patch
				}
				else
				{
					BOOL status = NO;
					mDeniedSchemaInstall = YES;
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
					//Patch by Tim Bedford 2008-08-11
					NSError* installError;
					[self installBaseTenSchema: MakeInvocation (NSApp, @selector (stopModalWithCode:)) error:&installError];
					if(!installError)
					{
						retval = [NSApp runModalForWindow: mMainWindow];
					}
					else
					{
						//FIXME: handle the error.
					}
					//End patch
				}
				else
				{
					mDeniedSchemaInstall = YES;
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
	if (recoveryInvocation)
	{
		[recoveryInvocation setArgument: &status atIndex: 2];
		[recoveryInvocation invoke];
	}
}

- (void) SQLScriptReaderSucceeded: (BXPGSQLScriptReader *) reader userInfo: (id) userInfo
{
	[self hideProgressPanel];
	
	BOOL status = [self checkBaseTenSchema: NULL];
	
	InvokeRecoveryInvocation (userInfo, status);
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
	[self setProgressValue: (double) position];
}

- (void) disconnectAfterRefresh: (PGTSResultSet *) res
{
	[self hideProgressPanel];
	[mProgressCancelButton setEnabled: YES];
	if ([res querySucceeded])
		[self finishDisconnect]; //Patch by Tim Bedford 2008-08-11
	else
	{
		[NSApp presentError: [res error] modalForWindow: mMainWindow delegate: nil 
		 didPresentSelector: NULL contextInfo: NULL];
	}
}

//Patch by Tim Bedford 2008-08-11
- (void) finishTermination
{
	[mServiceBrowser stop];
	
	if([mMainWindow attachedSheet] == mConnectPanel)
	{
		[NSApp endSheet:mConnectPanel];
		[mConnectPanel orderOut: nil];
	}
	
	[NSApp terminate: nil];
}
//End patch

- (void) terminateAfterRefresh: (PGTSResultSet *) res
{
	[self hideProgressPanel];
	[self finishTermination]; //Patch by Tim Bedford 2008-08-11
}

- (void) refreshCaches: (BOOL) terminate
{
	SEL callback = @selector (disconnectAfterRefresh:);
	if (terminate)
		callback = @selector (terminateAfterRefresh:);
	
	PGTSConnection* connection = [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] connection];
	[mProgressCancelButton setEnabled: NO];
	[self displayProgressPanel: NSLocalizedString(@"Refreshing caches", @"Progress panel message")]; //Patch by Tim Bedford 2008-08-11
	[connection sendQuery: @"SELECT baseten.refreshcaches ();" delegate: self callback: callback];
}
@end


//Patch by Tim Bedford 2008-08-11
@implementation BXAController (NSSplitViewDelegate)

- (float)splitView:(NSSplitView *)splitView constrainMinCoordinate:(float)proposedCoordinate ofSubviewAt:(int)index
{
	return proposedCoordinate + 128.0f;
}

- (float)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(float)proposedCoordinate ofSubviewAt:(int)index
{
	return proposedCoordinate - 128.0f;
}

- (void)splitView:(NSSplitView*)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	// Force the width of the left subview to remain constant when the splitview is resized
	NSRect newFrame = [sender frame]; // get the new size of the whole splitView
	NSView *left = [[sender subviews] objectAtIndex:0];
	NSRect leftFrame = [left frame];
	NSView *right = [[sender subviews] objectAtIndex:1];
	NSRect rightFrame = [right frame];
	
	CGFloat dividerThickness = [sender dividerThickness];
	
	leftFrame.size.height = newFrame.size.height;
	
	rightFrame.size.width = newFrame.size.width - leftFrame.size.width - dividerThickness;
	rightFrame.size.height = newFrame.size.height;
	rightFrame.origin.x = leftFrame.size.width + dividerThickness;
	
	[left setFrame:leftFrame];
	[right setFrame:rightFrame];
}

@end


@implementation BXAController (NSSavePanelDelegate)

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if(returnCode == NSOKButton)
	{
		[self finishExportLogWithURL:[sheet URL]];
	}
}

@end


@implementation BXAController (NetServiceMethods)

- (void)applyNetService:(NSNetService*)netService
{
	struct sockaddr* socketAddress;
	
	for(int index = 0; index < [[netService addresses] count]; index++)
	{
		socketAddress = (struct sockaddr*)[[[netService addresses] objectAtIndex:index] bytes];
		
		// Only continue if this is an IPv4 address
		if(socketAddress && socketAddress->sa_family == AF_INET)
		{
			char buffer[256];
			uint16_t port;
			
			if(inet_ntop(AF_INET, &((struct sockaddr_in*)socketAddress)->sin_addr, buffer, sizeof(buffer)))
			{
				port = ntohs(((struct sockaddr_in*)socketAddress)->sin_port);
				
				[mHostCell setStringValue:[NSString stringWithCString:buffer encoding:NSUTF8StringEncoding]];
				[mPortCell setIntValue:port];
				
				break;
			}
		}
	}
}

// UI update code
- (void)updateBonjourUI
{
	// Also update any UI that lists available services
	NSMenu* menu = [mBonjourPopUpButton menu];
	NSMenuItem* menuItem = nil;
	NSInteger count = [[menu itemArray] count];
	
	// Remove any current menu items (except the first one which is used for the popup button label)
	
	while(--count > 0)
	{
		[menu removeItemAtIndex:count];
	}
	
	if([mServices count])
	{
		// Add a menu item for each PostgreSQL service found
		count = 0;
		for(NSNetService* netService in mServices)
		{
			menuItem = [[NSMenuItem alloc] initWithTitle:[netService name] action:@selector(chooseBonjourService:) keyEquivalent:@""];
			[menuItem setTag:count];
			[menuItem setTarget:self];
			
			[menu addItem:menuItem];
			count++;
		}
	}
	else
	{
		// Add a disabled menu item indicating that no services were found
		[menu addItemWithTitle:NSLocalizedString(@"No services found", @"Service popup menu") action:nil keyEquivalent:@""];
	}
}

// Error handling code
- (void)handleNetServiceBrowserError:(NSNumber *)error
{
    NSLog(@"An error occurred. Error code = %d", [error intValue]);
}

- (void)handleNetServiceError:(NSNumber *)error withService:(NSNetService *)service
{
	NSLog(@"An error occurred with service %@.%@.%@, error code = %@",
		  [service name], [service type], [service domain], error);
}

@end


#if 0
@implementation BXAController (NetServiceBrowserDelegate)

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
    mSearching = YES;
    [self updateBonjourUI];
}

// Sent when browsing stops
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
    mSearching = NO;
    [self updateBonjourUI];
}

// Sent if browsing fails
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
			 didNotSearch:(NSDictionary *)errorDict
{
    mSearching = NO;
    [self handleNetServiceBrowserError:[errorDict objectForKey:NSNetServicesErrorCode]];
}

// Sent when a service appears
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
		   didFindService:(NSNetService *)aNetService
			   moreComing:(BOOL)moreComing
{
    [mServices addObject:aNetService];
	[aNetService setDelegate:self];
	
    if(!moreComing)
    {
        [self updateBonjourUI];
    }
}

// Sent when a service disappears
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
		 didRemoveService:(NSNetService *)aNetService
			   moreComing:(BOOL)moreComing
{
    [mServices removeObject:aNetService];
	
    if(!moreComing)
    {
        [self updateBonjourUI];
    }
}

@end


@implementation BXAController (NSNetServiceDelegate)

- (void)resolveNetServiceAtIndex:(NSInteger)index
{
	NSNetService* netService = (NSNetService*)[mServices objectAtIndex:index];
	[netService resolveWithTimeout:5];
}

- (void)netServiceDidResolveAddress:(NSNetService *)netService
{
	// We only resolve services when they are chosen by the user, so apply the service
	// as soon as it is resolved.
	[self applyNetService:netService];
}

- (void)netService:(NSNetService *)netService
	 didNotResolve:(NSDictionary *)errorDict
{
	[self handleNetServiceError:[errorDict objectForKey:NSNetServicesErrorCode] withService:netService];
}

@end
//End patch
#endif


@implementation BXAController (IBActions)
- (IBAction) reload: (id) sender
{
	BOOL ok = YES;
	NSError* error = nil;

	[mProgressCancelButton setEnabled: NO];
	[self displayProgressPanel: NSLocalizedString(@"Reloading", @"Progress panel message")]; //Patch by Tim Bedford 2008-08-11
	
	NSModalSession session = [NSApp beginModalSessionForWindow: mMainWindow];
	
	BXPGTransactionHandler* transactionHandler = [(BXPGInterface *) [mContext databaseInterface] transactionHandler];
	[transactionHandler refreshDatabaseDescription];
	
	ok = [self checkBaseTenSchema: &error];

	NSDictionary* entities = nil;
	if (ok)
	{
		entities = [mContext entitiesBySchemaAndName: YES error: &error];
		
		[self setProgressMin: 0.0 max: (double) [entities count]];
		for (NSArray* entityDict in [entities objectEnumerator])
		{
			for (BXEntityDescription* entity in [entityDict objectEnumerator])
			{				
				[self advanceProgress];
				[entity setValidated: NO];
				[mContext validateEntity: entity error: &error];
				
				if (error || NSRunContinuesResponse != [NSApp runModalSession: session])
				{
					ok = NO;
					break;
				}				
			}
		}
	}
	
	[NSApp endModalSession: session];
	[self hideProgressPanel];
	[mProgressCancelButton setEnabled: YES];
	
	if (ok)
		[mEntitiesBySchema setContent: entities];
	else
	{
		if (error)
			[NSApp presentError: error];
		[self finishDisconnect]; //Patch by Tim Bedford 2008-08-11
	}
}

- (IBAction) disconnect: (id) sender
{
	if ([self hasBaseTenSchema])
		[self refreshCaches: NO];
	else
		[self finishDisconnect]; //Patch by Tim Bedford 2008-08-11
}


- (IBAction) terminate: (id) sender
{
	if ([self hasBaseTenSchema])
		[self refreshCaches: YES]; // The YES refers to terminate after refresh. Method name could be a bit more descriptive //Patch by Tim Bedford 2008-08-11
	else
	{
		[self finishTermination]; //Patch by Tim Bedford 2008-08-11
	}
}


- (IBAction) cancelConnecting: (id) sender
{
	[self finishDisconnect]; //Patch by Tim Bedford 2008-08-11
}


//Patch by Tim Bedford 2008-08-11
- (IBAction) chooseBonjourService: (id) sender
{
	NSInteger index = [sender tag];
	if(index >= 0 && index < [mServices count])
	{
		NSNetService* netService = (NSNetService*)[mServices objectAtIndex:index];
		if([[netService addresses] count] == 0)
			[self resolveNetServiceAtIndex:index];
		else
			[self applyNetService:netService];
	}
}
//End patch


- (IBAction) connect: (id) sender
{	
	NSString* username = [mUserNameCell objectValue];
	NSString* password = [mPasswordField objectValue];
	NSString* credentials = (0 < [password length] ? [NSString stringWithFormat: @"%@:%@", username, password] : username);
	
	NSString* host = [mHostCell objectValue];
	NSNumber* port = [mPortCell objectValue];
	NSString* target = ((port != nil) ? [NSString stringWithFormat: @"%@:%@", host, [port stringValue]] : host); //Patch by Tim Bedford 2008-08-11
	
	NSString* URIFormat = [NSString stringWithFormat: @"pgsql://%@@%@/%@", credentials, target, [mDBNameCell objectValue]];
	NSURL* connectionURI = [NSURL URLWithString: URIFormat];
	[mContext setDatabaseURI: connectionURI];
	[(id) [mContext databaseInterface] setController: self];
	
	[self hideConnectPanel]; //Patch by Tim Bedford 2008-08-11
    
	[mProgressCancelButton setAction: @selector (cancelConnecting:)];
    [self displayProgressPanel: NSLocalizedString(@"Connecting…", @"Progress panel message")]; //Patch by Tim Bedford 2008-08-11
		
	[mContext connectAsync];
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


//Patch by Tim Bedford 2008-08-11
- (IBAction) getInfo: (id) sender
{
	NSArray* selectedObjects = [mEntities selectedObjects];
	
	if([selectedObjects count] == 1)
	{
		BXEntityDescription* entity = (BXEntityDescription *)[[selectedObjects objectAtIndex:0] value];
		
		// Check if there is an info window for this entity already
		for(NSWindow* window in [NSApp windows])
		{
			NSWindowController* windowController = [window windowController];
			if([windowController isKindOfClass:[BXAGetInfoWindowController class]])
			{
				if([(BXAGetInfoWindowController *)windowController entity] == entity)
				{
					[window makeKeyAndOrderFront:self];
					return;
				}
			}
		}
		
		// Otherwise create a new one
		BXAGetInfoWindowController* getInfo = [BXAGetInfoWindowController getInfoWindowController];
		[getInfo setEntity:entity];
		[getInfo showWindow:self];
	}
}

- (IBAction) toggleMainWindow: (id) sender
{
	[mMainWindow MKCToggle: sender];
}

- (IBAction) toggleInspector: (id) sender
{
	BXAInspectorPanelController* inspector = [BXAInspectorPanelController inspectorPanelController];
	
	if([inspector isWindowVisible])
		[inspector closeWindow:self];
	else
		[inspector showWindow:self];
}

- (IBAction) exportLog: (id) sender
{
	NSSavePanel* savePanel = [NSSavePanel savePanel];
	
	[savePanel setTitle:NSLocalizedString(@"Export Log", @"Save panel title")];
	[savePanel setPrompt:NSLocalizedString(@"Export", @"Export button label")];
	[savePanel setRequiredFileType:@"sql"];
	[savePanel setCanSelectHiddenExtension:YES];
	
	if(![mLogWindow isVisible])
		[mLogWindow makeKeyAndOrderFront:self];
	[savePanel beginSheetForDirectory:nil
								 file:NSLocalizedString(@"LogExportDefaultName", @"Default log filename")
					   modalForWindow:mLogWindow
						modalDelegate:self
					   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
}
//End patch


- (IBAction) clearLog: (id) sender
{
    [[[mLogView textStorage] mutableString] setString: @""];    
}


- (IBAction) displayLogWindow: (id) sender
{
	[mLogWindow makeKeyAndOrderFront: nil];
}


- (IBAction) cancelSchemaInstall: (id) sender
{
	[mReader cancel];
}

- (IBAction) upgradeSchema: (id) sender
{
	[self upgradeBaseTenSchema];
}

- (IBAction) removeSchema: (id) sender
{
	PGTSConnection* connection = [[(BXPGInterface *) [mContext databaseInterface] transactionHandler] connection];
	PGTSResultSet* res = [connection executeQuery: @"DROP SCHEMA baseten CASCADE;"];
	if (! [res querySucceeded])
		[NSApp presentError: [res error] modalForWindow: mMainWindow delegate: nil didPresentSelector: NULL contextInfo: NULL];
	else
	{
		for (id pair in [mEntities arrangedObjects])
			[[pair value] setEnabled: NO];
	}
}

//Patch by Tim Bedford 2008-08-12
- (IBAction) openHelp: (id) sender
{
	// We use the sender's tag to form the help anchor. Anchors in the help book are in the form bxahelp###
	NSString *bookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	NSHelpManager* helpManager = [NSHelpManager sharedHelpManager];
	NSString* anchor = [NSString stringWithFormat:@"bxahelp%d", [sender tag]]; 
	
	[helpManager openHelpAnchor:anchor inBook:bookName];
}
//End patch

@end


@implementation NSArrayController (BaseTenSetupApplicationAdditions)
- (BOOL) MKCHasEmptySelection
{
    return NSNotFound == [self selectionIndex];
}
@end
