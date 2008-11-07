//
// BXOneToOneRelationshipDescription.m
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


#import "BXOneToOneRelationshipDescription.h"
#import "BXDatabaseObject.h"
#import "BXForeignKey.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXLogger.h"


@implementation BXOneToOneRelationshipDescription

- (BOOL) isToMany
{
	return NO;
}

- (Class) fetchedClass
{
	return Nil;
}

- (NSPredicate *) predicateForRemoving: (id) target 
						databaseObject: (BXDatabaseObject *) databaseObject
{
	NSPredicate* retval = nil;	
	BXDatabaseObject* oldObject = [databaseObject primitiveValueForKey: [self name]];
	if (oldObject)
	{
		NSExpression* lhs = [NSExpression expressionForConstantValue: oldObject];
		NSExpression* rhs = [NSExpression expressionForEvaluatedObject];
		retval = [NSComparisonPredicate predicateWithLeftExpression: lhs rightExpression: rhs
														   modifier: NSDirectPredicateModifier 
															   type: NSEqualToPredicateOperatorType 
															options: 0];
	}
	return retval;
}

- (NSPredicate *) predicateForAdding: (id) target 
					  databaseObject: (BXDatabaseObject *) databaseObject
{
	
	NSPredicate* retval = nil;
	if (target)
	{
		NSExpression* lhs = [NSExpression expressionForConstantValue: target];
		NSExpression* rhs = [NSExpression expressionForEvaluatedObject];
		retval = [NSComparisonPredicate predicateWithLeftExpression: lhs rightExpression: rhs
														   modifier: NSDirectPredicateModifier 
															   type: NSEqualToPredicateOperatorType 
															options: 0];
	}
	return retval;
}

- (NSPredicate *) predicateForTarget: (BXDatabaseObject *) target
{
	BXDatabaseObjectID* objectID = [target objectID];
	NSPredicate* retval = [objectID predicate];
	return retval;
}


- (void) removeAttributeDependency
{
	if (! [self isInverse])
		[super removeAttributeDependency];
}


- (void) setAttributeDependency
{
	if (! [self isInverse])
		[super setAttributeDependency];
}

@end
