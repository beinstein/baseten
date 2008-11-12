//
// PGTSCFScannedMemoryAllocator.h
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

#import "PGTSCFScannedMemoryAllocator.h"
#import "PGTSScannedMemoryAllocator.h"


static CFAllocatorRef gAllocator;


static void*
AllocateScanned (CFIndex allocSize, CFOptionFlags hint, void *info)
{
	return NSAllocateCollectable (allocSize, NSScannedOption | NSCollectorDisabledOption);
}


static void*
ReallocateScanned (void *ptr, CFIndex newsize, CFOptionFlags hint, void *info)
{
	return NSReallocateCollectable (ptr, newsize, NSScannedOption | NSCollectorDisabledOption);
}


static void
DeallocateScanned (void *ptr, void *info)
{
	free (ptr);
}


CFAllocatorRef 
PGTSScannedMemoryAllocator ()
{
	if (! gAllocator)
	{
		if (PGTS::scanned_memory_allocator_env::allocate_scanned)
		{
			CFAllocatorContext ctx = {
				0,		//Version
				NULL,	//Info
				NULL,	//Retain ctx
				NULL,	//Release ctx
				NULL,	//Copy ctx description
				&AllocateScanned,
				&ReallocateScanned,
				&DeallocateScanned,
				NULL	//CFAllocatorPreferredSizeCallBack
			};
			gAllocator = CFAllocatorCreate (NULL, &ctx);
		}
		else
		{
			gAllocator = kCFAllocatorDefault; 
		}
	}
	return gAllocator;
}


CFSetCallBacks 
PGTSScannedSetCallbacks ()
{
	CFSetCallBacks callbacks = kCFTypeSetCallBacks;
	if (PGTS::scanned_memory_allocator_env::allocate_scanned)
	{
		callbacks.retain = NULL;
		callbacks.release = NULL;
	}
	return callbacks;
}
