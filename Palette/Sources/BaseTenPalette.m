//
// BaseTenPalette.m
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

#import "BaseTenPalette.h"
#import <BaseTen/BaseTen.h>
#import <BaseTenAppKit/BaseTenAppKit.h>
#import <ExceptionHandling/NSExceptionHandler.h>
#import <Foundation/NSDebug.h>

NSImage* gBXArrayControllerImage = nil;
NSImage* gBXDatabaseContextImage = nil;


@implementation BaseTenPalette

+(NSImage *) imageFromPaletteBundleWithName:(NSString *)name
{
	NSBundle *paletteBundle = [NSBundle bundleForClass:[self class]];
	
	if (nil == paletteBundle)
	{
		NSLog(@"+[%@ %@] ERROR! paletteBundle is nil", [self className], NSStringFromSelector(_cmd));
		return nil;
	}
	
	// FIXME! This hard-coded stuff needs to be changed. -[NSBundle pathForResource:ofType:] returned nil, so I couldn't use that.
	NSString *path = [[paletteBundle bundlePath] stringByAppendingFormat:@"/Contents/Resources/%@.png", name];
	
	return [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
}

+(void) initialize
{
	if([self class] != [BaseTenPalette class])
		return;
	
    if (nil == gBXArrayControllerImage)
        gBXArrayControllerImage = [[self imageFromPaletteBundleWithName: @"BXArrayController"] retain];
    if (nil == gBXDatabaseContextImage)
        gBXDatabaseContextImage = [[self imageFromPaletteBundleWithName: @"BXDatabaseObject"] retain];
}

- (void) finishInstantiate
{
#if 0
    NSSetUncaughtExceptionHandler (&TSExceptionHandler);
    NSExceptionHandler* e = [NSExceptionHandler defaultExceptionHandler];
    [e setExceptionHandlingMask: NSLogAndHandleEveryExceptionMask];
#endif    
    
    /* `finishInstantiate' can be used to associate non-view objects with
     * a view in the palette's nib.  For example:
     *   [self associateObject:aNonUIObject ofType:
     *                withView:aView];
     */
    
    context = [[BXDatabaseContext alloc] init];
    arrayController = [[BXSynchronizedArrayController alloc] init];
    
    [self associateObject: context ofType: IBObjectPboardType withView: contextButton];
    [self associateObject: arrayController ofType: IBObjectPboardType withView: arrayControllerButton];
}

- (void) dealloc
{
    [context release];
    [arrayController release];
    [super dealloc];
}

@end


@implementation BXSynchronizedArrayController (IBAdditions)
- (NSImage *) imageForViewer
{
    return gBXArrayControllerImage;
}
@end


@implementation BXDatabaseContext (IBAdditions)
- (NSImage *) imageForViewer
{
    return gBXDatabaseContextImage;
}
@end