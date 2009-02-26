//
// PGTSCollections.h
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

#import <Foundation/Foundation.h>
#import <BaseTen/BXExport.h>


#if defined(__cplusplus)
#import <BaseTen/PGTSScannedMemoryAllocator.h>
#import <list>
#import <tr1/unordered_set>
#import <tr1/unordered_map>
namespace PGTS 
{
	struct ObjectHash
	{
		size_t operator() (const id anObject) const { return [anObject hash]; }
	};
	
	template <typename T>
	struct ObjectCompare
	{
		bool operator() (const T x, const T y) const { return ([x isEqual: y] ? true : false); }
	};
	
	template <>
	struct ObjectCompare <NSString *>
	{
		bool operator() (const NSString* x, const NSString* y) const { return ([x isEqualToString: y] ? true : false); }
	};
	
	template <typename T>
	id FindObject (T *container, typename T::key_type key)
	{
		id retval = nil;
		if (container)
		{
			typename T::const_iterator it = container->find (key);
			if (container->end () != it)
				retval = it->second;
		}
		return retval;
	}
	
	struct RetainingIdPair
	{
		id first;
		id second;
		
		explicit RetainingIdPair (id a, id b)
		: first ([a retain]), second ([b retain]) {}
		
		RetainingIdPair (const RetainingIdPair& p)
		: first ([p.first retain]), second ([p.second retain]) {}
		
		~RetainingIdPair ()
		{
			[first release];
			[second release];
		}
						
		struct Hash 
		{
			size_t operator() (const RetainingIdPair& p) const { return ([p.first hash] ^ [p.second hash]); }
		};
	};
	
	inline bool operator== (const RetainingIdPair& a, const RetainingIdPair& b)
	{
		return ([a.first isEqual: b.first] && [a.second isEqual: b.second]);
	}	
	
		
	typedef std::list <id, PGTS::scanned_memory_allocator <id> > IdList;
	
	typedef std::tr1::unordered_set <id,
		PGTS::ObjectHash, 
		PGTS::ObjectCompare <id>, 
		PGTS::scanned_memory_allocator <id> > 
		IdSet;
	
	typedef std::tr1::unordered_set  <RetainingIdPair,
		RetainingIdPair::Hash,
		std::equal_to <RetainingIdPair>,
		PGTS::scanned_memory_allocator <RetainingIdPair> >
		RetainingIdPairSet;
	
	typedef std::tr1::unordered_map <id, id, 
		PGTS::ObjectHash, 
		PGTS::ObjectCompare <id>, 
		PGTS::scanned_memory_allocator <std::pair <const id, id> > >
		IdMap;
	
	typedef std::tr1::unordered_map <NSInteger, id, 
		std::tr1::hash <NSInteger>, 
		std::equal_to <NSInteger>, 
		PGTS::scanned_memory_allocator <std::pair <const NSInteger, id> > > 
		IndexMap;	
}

#define PGTS_IdList PGTS::IdList
#define PGTS_IdSet PGTS::IdSet
#define PGTS_IdMap PGTS::IdMap
#define PGTS_IndexMap PGTS::IndexMap
#define PGTS_RetainingIdPairSet PGTS::RetainingIdPairSet

#else
#define PGTS_IdList void
#define PGTS_IdSet void
#define PGTS_IdMap void
#define PGTS_IndexMap void
#define PGTS_RetainingIdPairSet void
#endif


BX_EXPORT id PGTSSetCreateMutableWeakNonretaining ();
BX_EXPORT id PGTSSetCreateMutableStrongRetainingForNSRD (); //Has a better comparison function for NSRelationshipDescription.
BX_EXPORT id PGTSDictionaryCreateMutableWeakNonretainedObjects ();
