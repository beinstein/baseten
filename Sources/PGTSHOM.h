//
// PGTSHOM.h
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


@class PGTSInvocationRecorderHelper;


@interface PGTSInvocationRecorder : NSObject
{
	PGTSInvocationRecorderHelper* mHelper;
	NSInvocation** mOutInvocation;
}
- (void) setTarget: (id) target;
- (NSInvocation *) invocation;
- (id) record;
- (id) recordWithTarget: (id) target;
- (id) recordWithTarget: (id) target outInvocation: (NSInvocation **) outInvocation;
+ (id) recordWithTarget: (id) target outInvocation: (NSInvocation **) outInvocation;
@end


@interface NSSet (PGTSHOM)
- (id) PGTSAny;
- (id) PGTSDo;
- (id) PGTSCollect;
- (id) PGTSCollectReturning: (Class) aClass;
- (id) PGTSSelectFunction: (int (*)(id)) fptr;
- (id) PGTSSelectFunction: (int (*)(id, void*)) fptr argument: (void *) arg;
- (id) PGTSVisit: (id) visitor;
@end


@interface NSArray (PGTSHOM)
- (NSArray *) PGTSReverse;

- (id) PGTSAny;
- (id) PGTSDo;
- (id) PGTSCollect;
- (id) PGTSCollectReturning: (Class) aClass;
- (id) PGTSSelectFunction: (int (*)(id)) fptr;
- (id) PGTSSelectFunction: (int (*)(id, void*)) fptr argument: (void *) arg;
/**
 * \internal
 * Visit each item.
 * The first parameter after self and _cmd will be replaced with the visited object.
 * \param visitor The object that will be called.
 * \return An invocation recorder.
 */
- (id) PGTSVisit: (id) visitor;
@end


@interface NSDictionary (PGTSHOM)
- (id) PGTSAny;
- (id) PGTSDo;
- (id) PGTSCollect;
- (id) PGTSKeyCollect;
- (id) PGTSVisit: (id) visitor;
- (id) PGTSValueSelectFunction: (int (*)(id)) fptr;
- (id) PGTSValueSelectFunction: (int (*)(id, void*)) fptr argument: (void *) arg;
@end
