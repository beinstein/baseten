//
// PGTSAbstractDescription.h
// BaseTen
//
// Copyright (C) 2006-2009 Marko Karppinen & Co. LLC.
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

#import <Foundation/Foundation.h>


@class PGTSDatabaseDescription;


@interface PGTSAbstractDescription : NSObject <NSCopying>
{
    NSString* mName;
    NSUInteger mHash;
}
+ (BOOL) accessInstanceVariablesDirectly;
- (NSString *) name;

//Thread un-safe methods.
- (void) setName: (NSString *) aName;
@end


#if defined (__cplusplus)
#import <BaseTen/PGTSCollections.h>
#import <BaseTen/PGTSOids.h>
namespace PGTS 
{
	//FIXME: this isn't very good but apparently partial function template specialization isn't easy.
	template <typename T> NSMutableDictionary*
	CreateCFMutableDictionaryWithNames (T *map)
	{
		NSMutableDictionary* retval = [[NSMutableDictionary alloc] initWithCapacity: map->size ()];
		for (typename T::const_iterator it = map->begin (), end = map->end (); end != it; it++)
		{
			id currentObject = it->second;
			[retval setObject: currentObject forKey: [currentObject name]];
		}
		
		return retval;				
	}
	
	void InsertConditionally (IdMap* map, PGTSAbstractDescription* description);
}
#endif
