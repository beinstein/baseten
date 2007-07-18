//
// BXManyToManyRelationshipDescription.m
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
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

#import <Log4Cocoa/Log4Cocoa.h>

#import "BXManyToManyRelationshipDescription.h"
#import "BXRelationshipDescriptionPrivate.h"
#import "BXDatabaseObject.h"
#import "BXForeignKeyPrivate.h"
#import "BXDatabaseAdditions.h"
#import "BXDatabaseContextPrivate.h"


@implementation BXManyToManyRelationshipDescription

- (void) dealloc
{
	[mDstForeignKey release];
	[mHelperEntity release];
	[super dealloc];
}

- (BXForeignKey *) srcForeignKey
{
	return [self foreignKey];
}

- (BXForeignKey *) dstForeignKey
{
	return mDstForeignKey;
}

- (void) setSrcForeignKey: (BXForeignKey *) aKey
{
	[self setForeignKey: aKey];
}

- (void) setDstForeignKey: (BXForeignKey *) aKey
{
	if (mDstForeignKey != aKey)
	{
		[mDstForeignKey release];
		mDstForeignKey = [aKey retain];
	}
}

- (void) setHelperEntity: (BXEntityDescription *) anEntity
{
	if (mHelperEntity != anEntity)
	{
		[mHelperEntity release];
		mHelperEntity = [anEntity retain];
	}
}

- (id) targetForObject: (BXDatabaseObject *) aDatabaseObject error: (NSError **) error
{
	log4AssertValueReturn (NULL != error, nil , @"Expected error to be set.");
	log4AssertValueReturn (nil != aDatabaseObject, nil, @"Expected aDatabaseObject not to be nil.");
	log4AssertValueReturn ([[self entity] isEqual: [aDatabaseObject entity]], nil,
						  @"Expected aDatabaseObject entity to match. Self: %@ aDatabaseObject: %@", self, aDatabaseObject);	

	BXEntityDescription* targetEntity = mHelperEntity;

	//Make some key arrays for use with queries.
	NSArray* srcHelperKeyNames = [[self srcForeignKey] srcFieldNames];
	NSArray* dstHelperKeyNames = [[self dstForeignKey] srcFieldNames];
	NSArray* srcObjectKeyNames = [[self srcForeignKey] dstFieldNames];
	NSArray* dstObjectKeyNames = [[self dstForeignKey] dstFieldNames];	
	
	NSDictionary* helperAttributes = [mHelperEntity attributesByName];
	NSArray* srcValues = [aDatabaseObject valuesForKeys: srcObjectKeyNames];
	NSArray* srcHelperKeys = [helperAttributes objectsForKeys: srcHelperKeyNames notFoundMarker: nil];
	NSArray* dstHelperKeys = [helperAttributes objectsForKeys: dstHelperKeyNames notFoundMarker: nil];
	NSArray* dstObjectKeys = [[[self destinationEntity] attributesByName] objectsForKeys: dstObjectKeyNames notFoundMarker: nil];
	NSPredicate* helperSrcPredicate = [NSPredicate BXAndPredicateWithProperties: srcHelperKeys
															 matchingProperties: srcValues
																		   type: NSEqualToPredicateOperatorType];
	NSPredicate* helperDstPredicate = [NSPredicate BXAndPredicateWithProperties: dstHelperKeys
															 matchingProperties: dstObjectKeys
																		   type: NSEqualToPredicateOperatorType];
	NSPredicate* predicate = [NSCompoundPredicate andPredicateWithSubpredicates: 
		[NSArray arrayWithObjects: helperSrcPredicate, helperDstPredicate, nil]];
	
	//FIXME: should returnedClass be self-updating?
	NSSet* res = [[aDatabaseObject databaseContext] executeFetchForEntity: targetEntity
															withPredicate: predicate 
														  returningFaults: YES
														  excludingFields: nil
															returnedClass: [NSMutableSet class]
																	error: error];
	
	return res;
}

- (void) setTarget: (id) target
		 forObject: (BXDatabaseObject *) aDatabaseObject
			 error: (NSError **) error
{
	log4AssertVoidReturn (NULL != error, @"Expected error to be set.");
	log4AssertVoidReturn (nil != aDatabaseObject, @"Expected aDatabaseObject not to be nil.");
	log4AssertVoidReturn ([[self entity] isEqual: [aDatabaseObject entity]], 
						  @"Expected aDatabaseObject entity to match. Self: %@ aDatabaseObject: %@", self, aDatabaseObject);	
	
	NSString* name = [self name];
		
	//Compare collection to cached values.
	NSSet* oldObjects = [aDatabaseObject primitiveValueForKey: name];
	NSMutableSet* removedObjects = [[oldObjects mutableCopy] autorelease];
	[removedObjects minusSet: target];
	NSMutableSet* addedObjects = [[target mutableCopy] autorelease];
	[addedObjects minusSet: oldObjects];
	
	//Make some key arrays for use with queries.
	NSArray* srcHelperKeyNames = [[self srcForeignKey] srcFieldNames];
	NSArray* srcObjectKeyNames = [[self srcForeignKey] dstFieldNames];
	NSArray* dstHelperKeyNames = [[self dstForeignKey] srcFieldNames];
	
	//First remove old objects from the relationship, then add new ones.
	//FIXME: this could be configurable by the user unless we want to look for
	//       non-empty or maximum size constraints, which are likely CHECK clauses.
	//FIXME: these should be inside a transaction. Use the undo manager?
	[target willChangeValueForKey: name];

	BXDatabaseContext* context = [aDatabaseObject databaseContext];
	
	//Remove all objects from current object's set.
	NSArray* values = [aDatabaseObject valuesForKeys: srcObjectKeyNames];
	NSArray* srcHelperProperties = [[mHelperEntity attributesByName] objectsForKeys: srcHelperKeyNames notFoundMarker: nil];
	NSPredicate* predicate = [NSPredicate BXAndPredicateWithProperties: srcHelperProperties
													matchingProperties: values
																  type: NSEqualToPredicateOperatorType];
	[context executeDeleteFromEntity: mHelperEntity
					   withPredicate: predicate 
							   error: error];
	
	if (nil == *error)
	{
		//Add objects to current object's set.
		NSDictionary* srcHelperValues = [NSDictionary dictionaryWithObjects: values forKeys: srcHelperKeyNames];
		NSArray* dstHelperProperties = [[[self destinationEntity] attributesByName] objectsForKeys: dstHelperKeyNames notFoundMarker: nil];
		
		TSEnumerate (currentObject, e, [addedObjects objectEnumerator])
		{
			NSArray* dstHelperValues = [(BXDatabaseObject *) currentObject valuesForKeys: dstHelperValues];
			NSMutableDictionary* values = [NSMutableDictionary dictionaryWithObjects: dstHelperValues forKeys: dstHelperProperties];
			[values addEntriesFromDictionary: srcHelperValues];
			
			[context createObjectForEntity: mHelperEntity
						   withFieldValues: values 
									 error: error];
			if (nil != *error)
				break;
		}
	}
	
	[target didChangeValueForKey: name];		
}

@end
