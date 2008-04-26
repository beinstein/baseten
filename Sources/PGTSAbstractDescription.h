//
// PGTSAbstractDescription.h
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


@class PGTSConnection;
@class PGTSAbstractDescription;
@class PGTSDatabaseDescription;


inline
id PGTSNilReturn (id anObject)
{
	return [NSNull null] == anObject ? nil : anObject;
}


@protocol PGTSDescription
- (PGTSDatabaseDescription *) database;
- (PGTSConnection *) connection;
@end


@interface PGTSAbstractDescriptionProxy : NSProxy <PGTSDescription>
{
	PGTSConnection* mConnection; //Weak; connection owns self.
	PGTSAbstractDescription* mDescription;
	id mInvocationRecorder;
}
- (id) initWithConnection: (PGTSConnection *) connection
			  description: (PGTSAbstractDescription *) anObject;
- (id) performSynchronizedAndReturnObject;
- (void) performSynchronizedOnDescription: (NSInvocation *) invocation;
- (id) invocationRecorder;
@end


@interface PGTSAbstractDescription : NSObject <NSCopying, PGTSDescription>
{
    PGTSConnection* mConnection; //Weak
	PGTSAbstractDescriptionProxy* mProxy; //Weak;
	
    NSString* mName;
    unsigned int mHash;
}

+ (BOOL) accessInstanceVariablesDirectly;
- (NSString *) name;
- (void) setName: (NSString *) aString;
- (BOOL) isEqual: (id) anObject;
- (id) proxy;
- (Class) proxyClass;

//FIXME: these are private.
- (void) setConnection: (PGTSConnection *) aConnection;
- (void) setDescriptionProxy: (PGTSAbstractDescriptionProxy *) aProxy;
@end
