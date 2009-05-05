//
// BXEntityDescription+BXAAdditions.m
// BaseTen Assistant
//
// Copyright (C) 2006-2009 Marko Karppinen & Co. LLC.
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


#import <Foundation/Foundation.h>
#import <BaseTen/BaseTen.h>
#import "BXAController.h"


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
	return (0 < [[self primaryKeyFields] count]);
}

+ (NSSet *) keyPathsForValuesAffectingCanEnableForAssistantV
{
	return [NSSet setWithObject: @"primaryKeyFields"];
}

- (BOOL) canEnableForAssistantV
{
	return (0 < [[self primaryKeyFields] count] || [self isView]);
}

+ (NSSet *) keyPathsForValuesAffectingEnabledForAssistant
{
	return [NSSet setWithObject: @"enabled"];
}

- (BOOL) isEnabledForAssistant
{
	return [self isEnabled];
}

- (void) setEnabledForAssistant: (BOOL) aBool
{
	[[NSApp delegate] process: aBool entity: self];
}

- (BOOL) validateEnabledForAssistant: (id *) ioValue error: (NSError **) outError
{
	BOOL retval = YES;
	if ([self isView] && 0 == [[self primaryKeyFields] count])
	{
		if (ioValue)
			*ioValue = [NSNumber numberWithBool: NO];
	}
	else if (! [[NSApp delegate] hasBaseTenSchema])
	{
		retval = NO;
		if (outError)
			*outError = [[NSApp delegate] schemaInstallError];
	}
	return retval;
}
@end
