//
// TSRunloopMessenger.m
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

#import "TSRunloopMessenger.h"

/*
 * struct message
 */
struct message
{
	NSConditionLock		* resultLock;
	NSInvocation			* invocation;
};

extern void sendData( NSData * aData, NSPort * aPort );


@implementation TSRunloopMessenger

- (id)target:(id)aTarget;
{
	return [[[TSRunloopMessengerForwardingProxy alloc] _initWithTarget:aTarget withOwner:self withResult:NO] autorelease];
}

/*
 * target:withResult:
 */
- (id)target:(id)aTarget withResult:(BOOL)aResultFlag;
{
	return [[[TSRunloopMessengerForwardingProxy alloc] _initWithTarget:aTarget withOwner:self withResult:aResultFlag] autorelease];
}

- (void)messageInvocation:(NSInvocation *)anInvocation withResult:(BOOL)aResultFlag
{
	struct message		* theMessage;
	NSMutableData		* theData;
	NSConditionLock		* theLock;
	
	[anInvocation retainArguments];
	
	theData = [NSMutableData dataWithLength:sizeof(struct message)];
	theMessage = (struct message *)[theData mutableBytes];
	
	theMessage->invocation = (id) CFRetain (anInvocation);		// will be released by handlePortMessage
	if (aResultFlag)
	{
		theLock = [[NSConditionLock alloc] initWithCondition: NO];
		theMessage->resultLock = theLock;
	}
	else
	{
		theMessage->resultLock = nil;
	}
	
	sendData( theData, port );
	
	if( aResultFlag )
	{
		[theMessage->resultLock lockWhenCondition:YES];
		[theMessage->resultLock unlock];
		[theMessage->resultLock release];
	}
}

- (void)handlePortMessage:(NSPortMessage *)aPortMessage
{
	struct message 	* theMessage;
	NSData				* theData;
	void					handlePerformSelectorMessage( struct message * aMessage );
	void					handleInvocationMessage( struct message * aMessage );
	
	theData = [[aPortMessage components] lastObject];
	
	theMessage = (struct message *)[theData bytes];
	
	[theMessage->invocation invoke];
	if( theMessage->resultLock )
	{
		[theMessage->resultLock lock];
		[theMessage->resultLock unlockWithCondition:YES];
	}
	
	CFRelease (theMessage->invocation);	// to balance messageInvocation:withResult:
}

@end


@implementation TSRunloopMessengerForwardingProxy

- (id)_initWithTarget:(id)aTarget withOwner:(NDRunLoopMessenger *)anOwner withResult:(BOOL)aFlag
{
	if( aTarget && anOwner )
	{
		targetObject = aTarget;
		owner = [anOwner retain];
		withResult = aFlag;
	}
	else
	{
		[self release];
		self = nil;
	}
    
	return self;
}

- (void) dealloc
{
	[owner release];
    owner = nil;
    targetObject = nil;
    [super dealloc];
}

@end
