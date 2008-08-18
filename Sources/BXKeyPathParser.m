//
// BXKeyPathParser.m
// BaseTen
//
// Copyright (C) 2008 Marko Karppinen & Co. LLC.
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

#import "BXKeyPathParser.h"


#define kStackDepth 16


struct component_retval_st
{
	NSString* cr_component;
	unichar* cr_position;
};


#define Check_Stack_Overflow() if (kStackDepth <= i) [NSException raise: NSInternalInconsistencyException format: @"State stack overflow."]
#define Check_Stack_Unferflow() if (i < 0) [NSException raise: NSInternalInconsistencyException format: @"State stack underflow."]

#define Set_State( STATE ) { i++; Check_Stack_Overflow (); stack [i] = STATE; }
#define Exit_State() { i--; Check_Stack_Unferflow (); }
#define Add_Character( CHARACTER ) { *bufferPtr = CHARACTER; bufferPtr++; }
	

static struct component_retval_st
KeyPathComponent (unichar* stringPtr, unichar* buffer, NSUInteger length)
{
	unichar current = 0;
	unichar stack [kStackDepth] = {};
	short i = 0;
	unichar* bufferPtr = buffer;
	
	//We accept all characters other than .'"\ in key path components.
	while (length > 0)
	{
		current = *stringPtr;
		switch (stack [i])
		{
			case 0:
			{
				switch (current)
				{
					case '.':
					{
						goto end;
						break;
					}
						
					case '"':
					case '\\':
					{
						Set_State (current);
						break;
					}
						
					default:
					{
						Add_Character (current);
						break;
					}
				}				
				break;
			}
			
			case '"':
			{
				switch (current)
				{
					case '"':
					{
						Exit_State ();
						break;
					}
						
					case '\\':
					{
						Set_State (current);
						break;
					}
						
					default:
					{
						Add_Character (current);
						break;
					}
				}
				break;
			}
				
			case '\\':
			{
				switch (current)
				{
					case '\\':
					case '"':
					case '.':
					{
						Add_Character (current);
						Exit_State ();
						break;
					}
						
					default:
					{
						[NSException raise: NSInvalidArgumentException format: @"Invalid character after escape: %d", current];
						break;
					}
				}
			}
				
			default:
			{
				[NSException raise: NSInternalInconsistencyException format: @"Invalid state: %d", stack [i]];
				break;
			}
		}
		
		stringPtr++;
		length--;
	}
	
end:
	if (buffer == bufferPtr)
		[NSException raise: NSInvalidArgumentException format: @"Component with zero length."];
	
	NSString* component = [NSString stringWithCharacters: buffer length: bufferPtr - buffer];
	struct component_retval_st retval = { component, stringPtr };
	return retval;
}


/**
 * \internal
 * A parser for key paths.
 * Accepts some malformed key paths but NSPredicate and other classes probably notice them, when
 * they get re-used.
 */
NSArray* 
BXKeyPathComponents (NSString* keyPath)
{
	NSMutableArray* retval = [NSMutableArray array];
		
	NSInteger length = [keyPath length];
	unichar* stringPtr = malloc (length * sizeof (unichar));
	unichar* buffer = malloc (length * sizeof (unichar));
	[keyPath getCharacters: stringPtr];
	
	while (length > 0)
	{
		struct component_retval_st cst = KeyPathComponent (stringPtr, buffer, length);
		length -= (cst.cr_position - stringPtr);
		stringPtr = cst.cr_position;
		
		NSString* component = cst.cr_component;
		[retval addObject: component];
	}
	
	if (buffer)
		free (buffer);
	
	if (stringPtr)
		free (stringPtr);
	
	if (! [retval count])
		retval = nil;
	return retval;
}
