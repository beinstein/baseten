//
// BXAttributeDescription.m
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

#import "BXPropertyDescription.h"
#import "BXAttributeDescription.h"
#import "BXAttributeDescriptionPrivate.h"
#import "BXEntityDescription.h"
#import "BXRelationshipDescription.h"
#import "BXPropertyDescriptionPrivate.h"
#import "PGTSCollections.h"
#import "BXLogger.h"


@class BXRelationshipDescription;


/**
 * \brief An attribute description contains information about a column in a specific entity.
 * \note This class's documented methods are thread-safe. Creating objects, however, is not.
 * \note For this class to work in non-GC applications, the corresponding database context must be retained as well.
 * \ingroup descriptions
 */
@implementation BXAttributeDescription
- (void) finalize
{
	if (mRelationshipsUsing)
		CFRelease (mRelationshipsUsing);
	[super finalize];
}

- (void) dealloc
{
	if (mRelationshipsUsing)
		CFRelease (mRelationshipsUsing);
	
	[mDatabaseTypeName release];
	[super dealloc];
}

#if 0
- (id) initWithCoder: (NSCoder *) decoder
{
	if ((self = [super initWithCoder: decoder]))
	{
		[self setPrimaryKey: [decoder decodeBoolForKey: @"isPrimaryKey"]];
		//FIXME: excludedByDefault
		[self setExcluded: [decoder decodeBoolForKey: @"isExcluded"]];
		mRelationshipsUsing = PGTSSetCreateMutableStrongRetainingForNSRD ();
	}
	return self;
}

- (void) encodeWithCoder: (NSCoder *) coder
{
	[coder encodeBool: [self isPrimaryKey] forKey: @"isPrimaryKey"];
	//FIXME: excludedByDefault
	[coder encodeBool: [self isExcluded] forKey: @"isExcluded"];
	[super encodeWithCoder: coder];
}
#endif

/** \brief Whether the attribute is part of the primary key of its entity. */
- (BOOL) isPrimaryKey
{
	return (mFlags & kBXPropertyPrimaryKey ? YES : NO);
}

/** 
 * \brief Whether the attribute will be excluded from fetches and queried only when needed. 
 * \see BXDatabaseContext::executeFetchForEntity:withPredicate:excludingFields:error:
 */
- (BOOL) isExcluded
{
	return (mFlags & kBXPropertyExcluded ? YES : NO);
}

/** \brief Name of the attribute's database type. */
- (NSString *) databaseTypeName
{
	return mDatabaseTypeName;
}

/** \brief Class of fetched objects. */
- (Class) attributeValueClass
{
	return mAttributeClass;
}

/** \brief Class name of fetched values. */
- (NSString *) attributeValueClassName
{
	return NSStringFromClass (mAttributeClass);
}

- (enum BXPropertyKind) propertyKind
{
	return kBXPropertyKindAttribute;
}

/** \brief Whether this attribute is an array or not. */
- (BOOL) isArray
{
	return (kBXPropertyIsArray & mFlags ? YES : NO);
}
@end


@implementation BXAttributeDescription (PrivateMethods)
/** 
 * \internal
 * \name Creating an attribute description
 */
//@{
- (id) initWithName: (NSString *) name entity: (BXEntityDescription *) entity
{
	if ((self = [super initWithName: name entity: entity]))
	{
		mRelationshipsUsing = PGTSSetCreateMutableStrongRetainingForNSRD ();
	}
	return self;
}

/**
 * \internal
 * \brief Create an attribute description.
 * \param       aName       Name of the attribute
 * \param       anEntity    The entity which contains the attribute.
 * \return                  The attribute description.
 */
+ (id) attributeWithName: (NSString *) aName entity: (BXEntityDescription *) anEntity
{
    return [[[self alloc] initWithName: aName entity: anEntity] autorelease];
}
//@}

- (void) setArray: (BOOL) isArray
{
	if (isArray)
		mFlags |= kBXPropertyIsArray;
	else
		mFlags &= ~kBXPropertyIsArray;
}

- (void) setPrimaryKey: (BOOL) aBool
{
	[mEntity willChangeValueForKey: @"primaryKeyFields"];
	if (aBool)
	{
		mFlags |= kBXPropertyPrimaryKey;
		mFlags &= ~kBXPropertyExcluded;
	}
	else
	{
		mFlags &= ~kBXPropertyPrimaryKey;
	}
	[mEntity didChangeValueForKey: @"primaryKeyFields"];
}

- (void) setExcluded: (BOOL) aBool
{
	if (![self isPrimaryKey])
	{
		if (aBool)
			mFlags |= kBXPropertyExcluded;
		else
			mFlags &= ~kBXPropertyExcluded;
	}
}

- (void) setExcludedByDefault: (BOOL) aBool
{
	if (![self isPrimaryKey])
	{
		if (aBool)
			mFlags |= kBXPropertyExcludedByDefault;
		else
			mFlags &= ~kBXPropertyExcludedByDefault;
	}
}

- (void) resetAttributeExclusion
{
	if (kBXPropertyExcludedByDefault & mFlags)
		mFlags |= kBXPropertyExcluded;
	else
		mFlags &= ~kBXPropertyExcluded;
}

- (void) setAttributeValueClass: (Class) aClass
{
	mAttributeClass = aClass;
}

- (void) setDatabaseTypeName: (NSString *) typeName
{
	if (mDatabaseTypeName != typeName)
	{
		[mDatabaseTypeName release];
		mDatabaseTypeName = [typeName retain];
	}
}

- (void) addDependentRelationship: (BXRelationshipDescription *) rel
{
	ExpectV (mRelationshipsUsing);
	@synchronized (mRelationshipsUsing)
	{
		ExpectV ([rel destinationEntity]);
		if ([[rel entity] isEqual: [self entity]])
		{
			[mRelationshipsUsing addObject: rel];
		}
		else
		{
			BXLogError (@"Tried to add a relationship doesn't correspond to current attribute. Attribute: %@ relationship: %@", self, rel);
		}
	}	
}

- (void) removeDependentRelationship: (BXRelationshipDescription *) rel
{
	@synchronized (mRelationshipsUsing)
	{
		[mRelationshipsUsing removeObject: rel];
	}
}

- (NSSet *) dependentRelationships
{
	id retval = nil;
	@synchronized (mRelationshipsUsing)
	{
		retval = [[mRelationshipsUsing copy] autorelease];
	}
	return retval;
}
@end
