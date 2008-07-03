//
// PGTSScannedMemoryAllocator.h
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


#ifndef PGTS_SCANNED_MEMORY_ALLOCATOR_H
#define PGTS_SCANNED_MEMORY_ALLOCATOR_H

#import <Foundation/Foundation.h>
#import <new>
#import <limits>


namespace PGTS 
{
	template <typename T> class scanned_memory_allocator {
	public:
		typedef T                 value_type;
		typedef value_type*       pointer;
		typedef const value_type* const_pointer;
		typedef value_type&       reference;
		typedef const value_type& const_reference;
		typedef std::size_t       size_type;
		typedef std::ptrdiff_t    difference_type;
		
		template <typename U> struct rebind { typedef scanned_memory_allocator <U> other; };
		
		explicit scanned_memory_allocator () {}
		scanned_memory_allocator (const scanned_memory_allocator&) {}
		template <typename U> scanned_memory_allocator (const scanned_memory_allocator <U> &) {}
		~scanned_memory_allocator () {}
		
		pointer address (reference x) const { return &x; }
		const_pointer address (const_reference x) const { return x; }
		
		pointer allocate (size_type n, const_pointer = 0) 
		{
			void* p = NULL;
			
			//Symbol existence verification requires NULL != -like comparison.
			if (NULL != NSAllocateCollectable)
				p = NSAllocateCollectable (n * sizeof (T), NSScannedOption | NSCollectorDisabledOption);
			else
				p = malloc (n * sizeof (T));
			
			if (! p)
				throw std::bad_alloc ();
			return static_cast <pointer> (p);
		}
		
		void deallocate (pointer p, size_type n) 
		{
			free (p);
		}
		
		size_type max_size () const 
		{
			return std::numeric_limits <size_type>::max () / sizeof (T);
		}
		
		void construct (pointer p, const value_type& x) 
		{ 
			new (p) value_type (x); 
		}
		
		void destroy (pointer p) 
		{ 
			p->~value_type (); 
		}
		
	private:
		void operator= (const scanned_memory_allocator&);
	};
	
	
	template <> class scanned_memory_allocator <void>
	{
		typedef void        value_type;
		typedef void*       pointer;
		typedef const void* const_pointer;
		
		template <typename U> 
		struct rebind { typedef scanned_memory_allocator <U> other; };
	};
	
	
	template <typename T> inline bool 
	operator== (const scanned_memory_allocator <T> &, const scanned_memory_allocator <T> &)
	{
		return true;
	}
	
	
	template <typename T> inline bool 
	operator!= (const scanned_memory_allocator <T> &, const scanned_memory_allocator <T> &) 
	{
		return false;
	}
}	
	
#endif //PGTS_SCANNED_MEMORY_ALLOCATOR_H
