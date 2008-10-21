//
// BXPGExpressionVisitor.m
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

#import "BXDatabaseAdditions.h"
#import "PGTSHOM.h"
#import "BXAttributeDescription.h"
#import "BXPGFromItem.h"
#import "BXManyToManyRelationshipDescription.h"
#import "BXPGAdditions.h"


@implementation BXPGExpressionVisitor
- (id) init
{
	if ((self = [super init]))
	{
		mSQLExpression = [[NSMutableString alloc] init];
		mComponents = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[mSQLExpression release];
	[mComponents release];
	[mConnection release];
	[super dealloc];
}

- (void) reset
{
	[mComponents removeAllObjects];
	[mSQLExpression setString: @""];
}

- (void) setComponents: (NSArray *) anArray
{
	[mComponents removeAllObjects];
	[mComponents addObjectsFromArray: anArray];
}

- (PGTSConnection *) connection
{
	return mConnection;
}

- (void) setConnection: (PGTSConnection *) conn
{
	if (conn != mConnection)
	{
		[mConnection release];
		mConnection = [conn retain];
	}
}

- (NSString *) beginWithKeyPath: (NSArray *) components
{		
	NSAssert ([self relationAliasMapper], @"Expected to have a relation alias mapper.");
	NSAssert ([[self relationAliasMapper] primaryRelation], @"Expected to have a primary relation."); //FIXME: replace with our custom assertion.
	
	[self reset];
	[self setComponents: components];
	
	TSEnumerate (currentComponent, e, [components objectEnumerator])
		[currentComponent BXPGVisitKeyPathComponent: self];		
	
	return [[mSQLExpression copy] autorelease];
}
@end


@implementation BXPGExpressionVisitor (BXPGExpressionVisitor)
- (void) visitCountAggregate: (BXPGSQLFunction *) sqlFunction
{
	//We only need the first relationship for this.
	BXPGRelationAliasMapper* mapper = [self relationAliasMapper];
	[mapper resetCurrent];
	BXRelationshipDescription* rel = [mComponents objectAtIndex: 0];
	BXPGFromItem* leftJoin = [mapper addFromItemForRelationship: rel];
	[mSQLExpression setString: @""];
	[mSQLExpression appendFormat: @"COUNT (%@.*)", [leftJoin alias]];
}

- (void) visitArrayCountFunction: (BXPGSQLFunction *) sqlFunction
{
	[mSQLExpression setString: [NSString stringWithFormat: @"array_upper (%@, 1)", mSQLExpression]];
}

- (void) visitAttribute: (BXAttributeDescription *) attr
{
	BXPGFromItem* item = nil;
	BXPGFromItem* lastItem = [[self relationAliasMapper] previousFromItem];
	BXPGFromItem* primaryRelation = [[self relationAliasMapper] primaryRelation];
	if (lastItem && [[attr entity] isEqual: [lastItem entity]])
		item = lastItem;
	else if ([[attr entity] isEqual: [primaryRelation entity]])
		item = primaryRelation;
	else
	{
		[NSException raise: NSInternalInconsistencyException format: 
		 @"Tried to add an attribute the entity of which wasn't found in from items."];
	}
	
	[mSQLExpression setString: [item alias]];
	[mSQLExpression appendString: @".\""];
	[mSQLExpression appendString: [attr name]];
	[mSQLExpression appendString: @"\""];
}

- (void) visitRelationship: (BXRelationshipDescription *) rel
{
	[[self relationAliasMapper] addFromItemForRelationship: rel];
}

- (void) visitArrayAccumFunction: (BXPGSQLFunction *) sqlFunction
{
	[mSQLExpression setString: [NSString stringWithFormat: @"\"baseten\".array_accum (%@)", mSQLExpression]];
}
@end
