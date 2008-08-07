//
// BXDatabaseContext+IBAdditions.m
// BaseTen
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

#import "BXDatabaseContext+IBAdditions.h"
#import "BXDatabaseContextInspector.h"
#import "BXIBPlugin.h"
#import <BaseTen/BXDatabaseAdditions.h>


@implementation BXDatabaseContext (IBAdditions)

- (void) ibDidAddToDesignableDocument: (IBDocument *) document
{
	[self setConnectsOnAwake: YES];
}

- (void) ibPopulateKeyPaths: (NSMutableDictionary *) keyPaths
{
    [super ibPopulateKeyPaths: keyPaths];
    
    [[keyPaths objectForKey: IBAttributeKeyPaths] addObjectsFromArray: [NSArray arrayWithObjects:
        @"databaseURI", @"autocommits", @"connectsOnAwake", nil]];
    [[keyPaths objectForKey: IBToOneRelationshipKeyPaths] addObjectsFromArray: [NSArray arrayWithObjects:
        @"policyDelegate", @"modalWindow", nil]];
}

- (void) ibPopulateAttributeInspectorClasses: (NSMutableArray *) classes
{
    [super ibPopulateAttributeInspectorClasses: classes];
    [classes addObject: [BXDatabaseContextInspector class]];
}

- (NSString *) IBDatabaseURI
{
	return [[self databaseURI] absoluteString];
}

- (BOOL) validateIBDatabaseURI: (id *) ioValue error: (NSError **) outError 
{
    BOOL succeeded = NO;
	id givenURI = *ioValue;
    NSURL* newURI = nil;

	//FIXME: move validation to BXDatabaseContext.
	if (nil == givenURI)
		succeeded = YES;
	else
	{
		NSString* errorMessage = nil;
		
		if ([givenURI isKindOfClass: [NSURL class]])
		{
			newURI = givenURI;
		}
		else if ([givenURI isKindOfClass: [NSString class]])
		{
		    if (0 < [givenURI length])
				newURI = [NSURL URLWithString: givenURI];
			else
			{
				succeeded = YES;
				goto bail;
			}
		}
		else
		{
			errorMessage = @"Expected to receive either an NSString or an NSURL.";
			goto bail;
		}
		
		if (nil == newURI)
		{
			errorMessage = @"The URI was malformed.";
			goto bail;
		}
		if (! [@"pgsql" isEqualToString: [newURI scheme]])
		{
			errorMessage = @"The only supported scheme is pgsql.";
			goto bail;
		}
		NSArray* pathComponents = [[newURI path] pathComponents];
		//The first path component is the initial slash.
		if ([pathComponents count] < 2 || [@"/" isEqualToString: [pathComponents objectAtIndex: 1]])
		{
			errorMessage = @"The URI path should contain the database name.";
			goto bail;
		}
		if (2 < [pathComponents count])
		{
			errorMessage = @"The URI path should only contain the database name.";
			goto bail;
		}		
		succeeded = YES;

		bail:
		if (succeeded)
			*ioValue = newURI;
		else if (NULL != outError)
		{
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
	            @"", NSLocalizedFailureReasonErrorKey,
	            BXSafeObj (errorMessage), NSLocalizedRecoverySuggestionErrorKey,
				nil];
			NSError* error = [NSError errorWithDomain: kBXErrorDomain 
												 code: kBXErrorMalformedDatabaseURI 
											 userInfo: userInfo];
			*outError = error;
		}
	}
	
	return succeeded;
}

- (void) setIBDatabaseURI: (NSURL *) anURI
{
	[self setDatabaseURI: anURI];
}

- (NSImage *) ibDefaultImage
{
	NSString* path = [[NSBundle bundleForClass: [BXIBPlugin class]] pathForImageResource: @"BXDatabaseObject"];
	return [[[NSImage alloc] initByReferencingFile: path] autorelease];
}

@end
