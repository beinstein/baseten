//
// BXPGFromItem.m
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
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

#import "BXPGFromItem.h"


@implementation BXPGFromItem
- (void) dealloc
{
	[mAlias release];
	[super dealloc];
}

- (NSString *) alias
{
	return mAlias;
}

- (void) setAlias: (NSString *) aString
{
	if (mAlias != aString)
	{
		[mAlias release];
		mAlias = [aString retain];
	}
}

- (BXEntityDescription *) entity
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}
@end


@implementation BXPGRelationshipFromItem
- (void) dealloc
{
	[mRelationship release];
	[mPrevious release];
	[super dealloc];
}

- (void) setRelationship: (BXRelationshipDescription *) aRel
{
	if (mRelationship != aRel)
	{
		[mRelationship release];
		mRelationship = [aRel retain];
	}
}

- (BXRelationshipDescription *) relationship
{
	return mRelationship;
}

- (BXPGFromItem *) previous
{
	return mPrevious;
}

- (void) setPrevious: (BXPGFromItem *) anItem
{
	if (mPrevious != anItem)
	{
		[mPrevious release];
		mPrevious = [anItem retain];
	}
}

- (BXEntityDescription *) entity
{
	return [mRelationship destinationEntity];
}

- (NSString *) BXPGVisitFromItem: (id <BXPGFromItemVisitor>) visitor
{
	return [visitor visitRelationshipJoinItem: self];
}
@end


@implementation BXPGPrimaryRelationFromItem
- (void) dealloc
{
	[mEntity release];
	[super dealloc];
}

- (BXEntityDescription *) entity
{
	return mEntity;
}

- (void) setEntity: (BXEntityDescription *) anEntity
{
	if (mEntity != anEntity)
	{
		[mEntity release];
		mEntity = [anEntity retain];
	}
}

- (NSString *) BXPGVisitFromItem: (id <BXPGFromItemVisitor>) visitor
{
	return [visitor visitPrimaryRelation: self];
}
@end


@implementation BXPGHelperTableRelationshipFromItem
- (void) dealloc
{
	[mHelperAlias release];
	[super dealloc];
}

- (NSString *) helperAlias
{
	return mHelperAlias;
}

- (void) setHelperAlias: (NSString *) aString
{
	if (mHelperAlias != aString)
	{
		[mHelperAlias release];
		mHelperAlias = [aString retain];
	}
}
@end
