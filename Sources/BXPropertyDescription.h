//
// BXPropertyDescription.h
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

#import <Foundation/Foundation.h>
#import <BaseTen/BXAbstractDescription.h>

@class BXEntityDescription;


enum BXPropertyFlag
{
	kBXPropertyNoFlag		= 0,
	kBXPropertyOptional		= 1 << 0,
	kBXPropertyPrimaryKey	= 1 << 1,
	kBXPropertyExcluded		= 1 << 2,
	kBXPropertyIsArray		= 1 << 3	
};

#ifdef __cplusplus
inline BXPropertyFlag operator |= (BXPropertyFlag x, BXPropertyFlag y) { return static_cast <BXPropertyFlag> (x | y); }
inline BXPropertyFlag operator &= (BXPropertyFlag x, BXPropertyFlag y) { return static_cast <BXPropertyFlag> (x & y); }
#endif 
	

/** \brief Property kind. */
enum BXPropertyKind
{
	kBXPropertyNoKind = 0, /**< Kind is unspecified. */
	kBXPropertyKindAttribute, /**< The property is an attribute. */
	kBXPropertyKindRelationship /**< The property is a relationship. */
};


@interface BXPropertyDescription : BXAbstractDescription <NSCopying> //, NSCoding>
{
    BXEntityDescription*  mEntity; //Weak
	enum BXPropertyFlag   mFlags;
}

- (BXEntityDescription *) entity;
- (BOOL) isOptional;
- (enum BXPropertyKind) propertyKind;
@end
