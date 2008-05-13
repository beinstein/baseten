//
// BXDatabaseObjectID.m
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

#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXDatabaseAdditions.h"
#import "BXEntityDescription.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseContext.h"
#import "BXInterface.h"
#import "BXAttributeDescription.h"
#import "BXDatabaseObject.h"
#import "BXDatabaseObjectPrivate.h"
#import "BXAttributeDescriptionPrivate.h"

#import <Log4Cocoa/Log4Cocoa.h>
#import <MKCCollections/MKCCollections.h>


/**
 * A unique identifier for a database object.
 * This class is not thread-safe, i.e. 
 * if methods of a BXDatabaseObjectID instance will be called from 
 * different threads the result is undefined.
 * \ingroup BaseTen
 */
@implementation BXDatabaseObjectID

+ (NSURL *) URIRepresentationForEntity: (BXEntityDescription *) anEntity primaryKeyFields: (NSDictionary *) pkeyDict
{
    NSURL* databaseURI = [anEntity databaseURI];
    NSMutableArray* parts = [NSMutableArray arrayWithCapacity: [pkeyDict count]];
    
    //If the pkey fields are unknown, we have to trust the user on this one.
    NSArray* keys = nil;
    if ([anEntity primaryKeyFields])
    {
        NSMutableArray* temp = [NSMutableArray array];
        TSEnumerate (currentKey, e, [[anEntity primaryKeyFields] objectEnumerator])
        {
            if ([currentKey isPrimaryKey])
                [temp addObject: [currentKey name]];
        }
        [temp sortUsingSelector: @selector (compare:)];
        keys = temp;
    }
    else
    {
        keys = [pkeyDict keysSortedByValueUsingSelector: @selector (compare:)];
    }
    
    TSEnumerate (currentKey, e, [keys objectEnumerator])
    {
        id currentValue = [pkeyDict objectForKey: currentKey];
        log4AssertValueReturn ([NSNull null] != currentValue, nil, @"A pkey value was NSNull. Entity: %@", anEntity);
        
        NSString* valueForURL = @"";
        char argtype = 'd';
        //NSStrings and NSNumbers get a special treatment
        if ([currentValue isKindOfClass: [NSString class]])
        {
            valueForURL = [currentValue stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
            argtype = 's';
        }
        else if ([currentValue isKindOfClass: [NSNumber class]])
        {
            valueForURL = [currentValue stringValue];
            argtype = 'n';
        }
        else
        {
            //Just use NSData
            valueForURL = [NSString BXURLEncodedData: [NSArchiver archivedDataWithRootObject: currentValue]];            
        }
        
        [parts addObject: [NSString stringWithFormat: @"%@,%c=%@", 
            [currentKey stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding],
            argtype, valueForURL]];
    }
    
    NSString* absolutePath = [[NSString stringWithFormat: @"/%@/%@/%@?",
        [databaseURI path],
        [[anEntity schemaName] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding],
        [[anEntity name] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]] stringByStandardizingPath];
    absolutePath = [absolutePath stringByAppendingString: [parts componentsJoinedByString: @"&"]];
    
    NSURL* URIRepresentation = [[NSURL URLWithString: absolutePath relativeToURL: databaseURI] absoluteURL];
    return URIRepresentation;
}

+ (BOOL) parseURI: (NSURL *) anURI
           entity: (NSString **) outEntityName
           schema: (NSString **) outSchemaName
 primaryKeyFields: (NSDictionary **) outPkeyDict
{
    //FIXME: URI validation?
    NSString* absoluteURI = [anURI absoluteString];
    NSString* query = [anURI query];
    NSString* path = [anURI path];
    
    NSArray* pathComponents = [path pathComponents];
    unsigned int count = [pathComponents count];
    NSString* tableName = [pathComponents objectAtIndex: count - 1];
    NSString* schemaName = [pathComponents objectAtIndex: count - 2];
    NSString* dbAddress = [absoluteURI substringToIndex: [absoluteURI length] - ([tableName length] + 1 + [query length])];
    //FIXME: object address and context address should be compared.
    dbAddress = nil; //Suppress a warning
        
	NSMutableDictionary* pkeyDict = [NSMutableDictionary dictionary];
	NSScanner* queryScanner = [NSScanner scannerWithString: query];
	while (NO == [queryScanner isAtEnd])
	{
		NSString* key = nil;
		NSString* type = nil;
		id value = nil;
		
		[queryScanner scanUpToString: @"," intoString: &key];
		[queryScanner scanString: @"," intoString: NULL];
		[queryScanner scanUpToString: @"=" intoString: &type];
		[queryScanner scanString: @"=" intoString: NULL];
		
		unichar c = [type characterAtIndex: 0];
		switch (c)
		{
			case 's':
				[queryScanner scanUpToString: @"&" intoString: &value];
				value = [value stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
				break;
			case 'n':
			{
				NSDecimal dec;
				[queryScanner scanDecimal: &dec];
				value = [NSDecimalNumber decimalNumberWithDecimal: dec];
				break;
			}
			case 'd':
			{
				NSString* encodedString = nil;
				[queryScanner scanUpToString: @"&" intoString: &encodedString];
				NSData* archivedData = [encodedString BXURLDecodedData];
				value = [NSUnarchiver unarchiveObjectWithData: archivedData];
				break;
			}
			default:
                goto bail;
                break;
		}	
		[pkeyDict setObject: value forKey: key];
		
		[queryScanner scanUpToString: @"&" intoString: NULL];
		[queryScanner scanString: @"&" intoString: NULL];
	}
    
    if (NULL != outEntityName) *outEntityName = tableName;
    if (NULL != outSchemaName) *outSchemaName = schemaName;
    if (NULL != outPkeyDict) *outPkeyDict = pkeyDict;
    
	return YES;
	
bail:
	{
		return NO;
	}
}

/** 
 * Create an object identifier from an NSURL.
 * \note This is not the designated initializer.
 */
- (id) initWithURI: (NSURL *) anURI context: (BXDatabaseContext *) context error: (NSError **) error
{
    NSString* entityName = nil;
    NSString* schemaName = nil;
    NSDictionary* pkeyDict = nil;

    if ([[self class] parseURI: anURI entity: &entityName
                        schema: &schemaName primaryKeyFields: &pkeyDict])
    {
        BXEntityDescription* entity = [context entityForTable: entityName inSchema: schemaName error: error];
        [[self class] verifyPkey: pkeyDict entity: entity];
        self = [self initWithEntity: entity objectURI: anURI];
    }
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"<%@ (%p) %@>", [self class], self, [self URIRepresentation]];
}

- (void) dealloc
{
    if (YES == mRegistered)
        [mEntity unregisterObjectID: self];
    
    [mURIRepresentation release];
    [mEntity release];
    [super dealloc];
}

/** The entity of the receiver. */
- (BXEntityDescription *) entity
{
    return mEntity;
}

/** URI representation of the receiver. */
- (NSURL *) URIRepresentation
{
    return mURIRepresentation;
}

- (unsigned int) hash
{
    if (0 == mHash)
    {
        mHash = [mURIRepresentation BXHash];
    }
    return mHash;
}

/** 
 * An NSPredicate for this object ID.
 * The predicate can be used to fetch the object from the database, for example.
 */
- (NSPredicate *) predicate
{
    NSPredicate* retval = nil;
    NSDictionary* pkeyFValues = nil;
    BOOL ok = [[self class] parseURI: mURIRepresentation entity: NULL schema: NULL primaryKeyFields: &pkeyFValues];
    if (ok)
    {
        NSDictionary* attributes = [mEntity attributesByName];
        NSMutableArray* predicates = [NSMutableArray arrayWithCapacity: [pkeyFValues count]];
    
        TSEnumerate (currentKey, e, [pkeyFValues keyEnumerator])
        {
            NSExpression* rhs = [NSExpression expressionForConstantValue: [pkeyFValues objectForKey: currentKey]];
            NSExpression* lhs = [NSExpression expressionForConstantValue: [attributes objectForKey: currentKey]];
            NSPredicate* predicate = 
                [NSComparisonPredicate predicateWithLeftExpression: lhs
                                                   rightExpression: rhs
                                                          modifier: NSDirectPredicateModifier
                                                              type: NSEqualToPredicateOperatorType
                                                           options: 0];
            [predicates addObject: predicate];
        }
        
        if (0 < [predicates count])
            retval = [NSCompoundPredicate andPredicateWithSubpredicates: predicates];
    }
    
    return retval;
}

- (BOOL) isEqual: (id) anObject
{
    BOOL retval = NO;
    if (NO == [anObject isKindOfClass: [BXDatabaseObjectID class]])
        retval = [super isEqual: anObject];
    else
    {
        BXDatabaseObjectID* anId = (BXDatabaseObjectID *) anObject;
        if (0 == anId->mHash || 0 == mHash || anId->mHash == mHash)
        {
            retval = [mURIRepresentation isEqual: anId->mURIRepresentation];
        }
    }
    return retval;
}

@end


@implementation BXDatabaseObjectID (NSCopying)
/** Retain on copy. */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}

- (id) mutableCopyWithZone: (NSZone *) zone
{
    return [[[self class] allocWithZone: zone]
        initWithEntity: mEntity objectURI: mURIRepresentation];
}
@end


@implementation BXDatabaseObjectID (PrivateMethods)

+ (void) verifyPkey: (NSDictionary *) pkeyDict entity: (BXEntityDescription *) entity
{
    NSArray* pkeyFields = [entity primaryKeyFields];
    if (nil != pkeyFields)
    {
        log4AssertVoidReturn ([pkeyFields count] <= [pkeyDict count],
                              @"Expected to have received values for all primary key fields.");
        TSEnumerate (currentAttribute, e, [pkeyFields objectEnumerator])
        {
            log4AssertVoidReturn (nil != [pkeyDict objectForKey: [currentAttribute name]], 
                                  @"Primary key not included: %@ given: %@", currentAttribute, pkeyDict);
        }
    }
}

/** 
 * \internal
 * \name Creating object IDs */
//@{
/** A convenience method. */
+ (id) IDWithEntity: (BXEntityDescription *) aDesc primaryKeyFields: (NSDictionary *) pkeyFValues
{
    NSArray* keys = [pkeyFValues allKeys];
    TSEnumerate (currentKey, e, [keys objectEnumerator])
    {
        log4AssertValueReturn ([currentKey isKindOfClass: [NSString class]],
                               nil, @"Expected to receive only NSStrings as keys. Keys: %@", keys);
    }
    [self verifyPkey: pkeyFValues entity: aDesc];

    NSURL* uri = [[self class] URIRepresentationForEntity: aDesc primaryKeyFields: pkeyFValues];
    log4AssertValueReturn (nil != uri, nil, @"Expected to have received an URI.");
    return [[[self class] alloc] initWithEntity: aDesc objectURI: uri];
}

/** 
 * \internal
 * The designated initializer.
 */
- (id) initWithEntity: (BXEntityDescription *) anEntity objectURI: (NSURL *) anURI
{
    log4AssertValueReturn (nil != anEntity, nil, @"Expected entity not to be nil.");
    log4AssertValueReturn (nil != anURI, nil, @"Expected anURI not to be nil.");
    
    if ((self = [super init]))
    {
		{
			NSString* entityName = nil;
			NSString* schemaName = nil;
			log4AssertValueReturn ([[self class] parseURI: anURI entity: &entityName schema: &schemaName primaryKeyFields: NULL],
								   nil, @"Expected object URI to be parseable.");
			log4AssertValueReturn ([[anEntity name] isEqualToString: entityName], nil, @"Expected entity names to match.");
			log4AssertValueReturn ([[anEntity schemaName] isEqualToString: schemaName], nil, @"Expected schema names to match.");
		}
		
        mURIRepresentation = [anURI retain];
        mEntity = [anEntity retain];
        mRegistered = NO;
        mHash = 0;
    }
    return self;
}
//@}

- (id) init
{
    //We need either an URI or an entity and primary key fields
    [self release];
    return nil;
}

#if 0
- (BXDatabaseObjectID *) partialKeyForView: (BXEntityDescription *) view
{
    log4AssertValueReturn ([view isView], nil, @"Expected given entity (%@) to be a view.", view);
    
    NSArray* keys = [view primaryKeyFields];
    NSArray* myKeys = [[self entity] correspondingProperties: keys];
    NSArray* values = [self objectsForKeys: myKeys];
    return [[self class] IDWithEntity: view primaryKeyFields: [NSDictionary dictionaryWithObjects: values forKeys: keys]];
}
#endif

- (void) setStatus: (enum BXObjectDeletionStatus) status forObjectRegisteredInContext: (BXDatabaseContext *) context
{
	[[context registeredObjectWithID: self] setDeleted: status];
}

- (NSDictionary *) allValues
{
	NSDictionary* retval = nil;
	BOOL ok = [[self class] parseURI: mURIRepresentation
							  entity: NULL
							  schema: NULL
					primaryKeyFields: &retval];
	log4AssertLog (ok, @"Expected URI to have been parsed correctly: %@", mURIRepresentation);
	return retval;
}

- (void) setEntity: (BXEntityDescription *) entity
{
    log4AssertVoidReturn (NO == mRegistered, @"Expected object ID not to have been registered.");
    NSString* path = [NSString stringWithFormat: @"../%@/%@?%@", 
        [entity schemaName], [entity name], [mURIRepresentation query]];
    
    mHash = 0;
    NSURL* newURI = [NSURL URLWithString: path relativeToURL: mURIRepresentation];
    [mURIRepresentation release];
    mURIRepresentation = [[newURI absoluteURL] retain];
}

@end
