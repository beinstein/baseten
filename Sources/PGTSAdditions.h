//
// PGTSAdditions.h
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
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
#import <BaseTen/postgresql/libpq-fe.h>

@class PGTSConnection;


#if defined(__cplusplus)

//FIXME: make some gc-compatible additions.

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
}

#endif


@interface NSNumber (PGTSAdditions)
- (Oid) PGTSOidValue;
@end


@interface NSString (PGTSAdditions)
- (int) PGTSParameterCount;
- (NSString *) PGTSEscapedString: (PGTSConnection *) connection;
+ (NSString *) PGTSFieldAliases: (unsigned int) count;
+ (NSString *) PGTSFieldAliases: (unsigned int) count start: (unsigned int) start;
@end


@interface NSObject (PGTSOptionalAdditions)
- (id) PGTSConstantExpressionValue: (NSDictionary *) context;
@end


@interface NSObject (PGTSAdditions)
- (NSString *) PGTSEscapedObjectParameter: (PGTSConnection *) connection;
- (NSString *) PGTSEscapedName: (PGTSConnection *) connection;
@end


@interface NSMutableData (PGTSPrivateAdditions)
- (void) PGTSAppendCString: (const char *) string;
@end


@interface NSDictionary (PGTSAdditions)
- (NSString *) PGTSConnectionString;
@end


@interface PGTSAbstractClass : NSObject
{
}
@end

@interface PGTSFloat : PGTSAbstractClass
{
}
@end

@interface PGTSDouble : PGTSAbstractClass
{
}
@end

@interface PGTSBool : PGTSAbstractClass
{
}
@end

@interface PGTSPoint : PGTSAbstractClass
{
}
@end

@interface PGTSSize : PGTSAbstractClass
{
}
@end
