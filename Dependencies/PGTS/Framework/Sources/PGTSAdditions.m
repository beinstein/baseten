//
// PGTSAdditions.m
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

#import <stdlib.h>
#import <limits.h>
#import <PGTS/postgresql/libpq-fe.h> 
#import "PGTSAdditions.h"
#import "PGTSConnection.h"
#import "PGTSConstants.h"
#import "PGTSFunctions.h"
#import "PGTSTypeInfo.h"
#import "PGTSFieldInfo.h"
#import "PGTSDatabaseInfo.h"
#import "PGTSACLItem.h"
#import <Log4Cocoa/Log4Cocoa.h>


//A workaround for libpq versions earlier than 8.0.8 and 8.1.4
//#define PQescapeStringConn( conn, to, from, length, error ) PQescapeString( to, from, length )



//Same as with strtoull
long long
strtoll (const char * restrict nptr, char ** restrict endptr, int base);

//This really might not exist in 10.2.8
float
strtof (const char * restrict nptr, char ** restrict endptr);


@interface NSDictionary (PGTSAdditionsPrivate)
- (NSArray *) PGTSParameters1: (NSMutableArray *) parameters;
@end


@implementation NSObject (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    return nil;
}

- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
	if (NULL != length)
		*length = 0;
	return NULL;
}

- (NSString *) PGTSEscapedObjectParameter: (PGTSConnection *) connection
{
	NSString* rval = nil;
	int length = 0;
	char* charParameter = [self PGTSParameterLength: &length connection: connection];
	if (NULL != charParameter)
	{
		PGconn* pgConn = [connection pgConnection];
		char* escapedParameter = calloc (1 + 2 * length, sizeof (char));
		PQescapeStringConn (pgConn, escapedParameter, charParameter, length, NULL);
		const char* clientEncoding = PQparameterStatus (pgConn, "client_encoding");
		NSCAssert1 (0 == strcmp ("UNICODE", clientEncoding), @"Expected client_encoding to be UNICODE (was: %s).", clientEncoding);
		rval = [[[NSString alloc] initWithBytesNoCopy: escapedParameter length: strlen (escapedParameter)
											 encoding: NSUTF8StringEncoding freeWhenDone: YES] autorelease];
	}
	return rval;
}
@end


@implementation NSDictionary (PGTSAdditions)
/**
 * Read the bundled deserialization dictionary if needed.
 */
+ (id) PGTSDeserializationDictionary
{
    static BOOL initialized = NO;
    static NSMutableDictionary* dict = nil;
    if (NO == initialized)
    {
        NSString* path = [[[NSBundle bundleForClass: [PGTSConnection class]] resourcePath] 
            stringByAppendingString: @"/datatypeassociations.plist"];
        NSData* plist = [NSData dataWithContentsOfFile: path];
        NSAssert1 (nil != plist, @"datatypeassociations.plist was not found (looked from %@)", path);
        
        NSString* error = nil;
        dict = [[NSPropertyListSerialization propertyListFromData: plist mutabilityOption: NSPropertyListMutableContainers 
                                                           format: NULL errorDescription: &error] retain];
        NSAssert2 (nil != dict, @"Error creating PGTSDeserializationDictionary: %@ (file: %@)", error, path);
            
        NSArray* keys = [dict allKeys];
        TSEnumerate (key, e, [keys objectEnumerator])
        {
            Class class = NSClassFromString ([dict objectForKey: key]);
            if (Nil == class)
                [dict removeObjectForKey: key];
            else
                [dict setObject: class forKey: key];
        }

        initialized = YES;
    }
    return dict;
}

/**
 * Use the keys and values to form a connection string.
 */
- (NSString *) PGTSConnectionString
{
	NSMutableString* connectionString = [NSMutableString string];
	NSEnumerator* e = [self keyEnumerator];
	NSString* currentKey;
	NSString* format = @"%@ = '%@' ";
	while ((currentKey = [e nextObject]))
        if ([kPGTSConnectionDictionaryKeys containsObject: currentKey])
            [connectionString appendFormat: format, currentKey, [self objectForKey: currentKey]];
	return connectionString;
}

/**
 * Sort the fields by table.
 * \return An NSDictionary with PGTSTableInfo objects as keys. The values are also NSDictionaries
 *         which have PGTSFieldInfo objects as keys and their values as objects.
 */
- (NSDictionary *) PGTSFieldsSortedByTable
{
    NSMutableDictionary* tables = [NSMutableDictionary dictionary];
    TSEnumerate (field, e, [self keyEnumerator])
    {
        PGTSTableInfo* table = [field table];
        NSMutableDictionary* fields = [tables objectForKey: table];
        if (nil == fields)
        {
            fields = [NSMutableDictionary dictionary];
            [tables setObject: fields forKey: table];
        }
        [fields setObject: [self objectForKey: field] forKey: field];
    }
    return tables;
}

/**
 * Use the keys and values to form a SET clause and append the values to an array.
 * \param parameters the value array
 */
- (NSString *) PGTSSetClauseParameters: (NSMutableArray *) parameters;
{
    return [[self PGTSParameters1: parameters] componentsJoinedByString: @", "];
}


/**
 * Use the keys and values to form a WHERE clause and append the values to an array.
 * \param parameters the value array
 */
- (NSString *) PGTSWhereClauseParameters: (NSMutableArray *) parameters
{
    return [[self PGTSParameters1: parameters] componentsJoinedByString: @" AND "];
}

@end


@implementation NSMutableDictionary (PGTSAdditions)
- (void) PGTSSetRow: (int) row resultSet: (PGTSResultSet *) res
{
    [res setValuesFromRow: row target: self nullPlaceholder: [NSNull null]];
}
@end


@implementation NSDictionary (PGTSAdditionsPrivate)
/**
 * Make a key-value-pair of each item in the dictionary.
 * Keys and values are presented as follows: "key" = $n, where n ranges from 1 to number of items
 */
- (NSArray *) PGTSParameters1: (NSMutableArray *) parameters
{
    NSMutableArray* fields = [NSMutableArray arrayWithCapacity: [self count]];
    //Postgres's indexing is one-based
    unsigned int i = [parameters count] + 1;
    TSEnumerate (field, e, [self keyEnumerator])
    {
        [parameters addObject: [self objectForKey: field]];
        [fields addObject: [NSString stringWithFormat: @"\"%@\" = $%u", field, i]];
        i++;
    }
    return fields;
}
@end


@implementation NSNotificationCenter (PGTSAdditions)
/**
 * Return the shared notification center that delivers notifications from the database.
 */
+ (NSNotificationCenter *) PGTSNotificationCenter
{
    static id sharedInstance = nil;
    if (!sharedInstance)
        sharedInstance = [[[self class] alloc] init];
    return sharedInstance;
}
@end


@implementation NSString (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    return [NSString stringWithUTF8String: value];
}

- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
	const char* clientEncoding = PQparameterStatus ([connection pgConnection], "client_encoding");
	NSCAssert1 (0 == strcmp ("UNICODE", clientEncoding), @"Expected client_encoding to be UNICODE (was: %s).", clientEncoding);
    const char* rval = [self UTF8String];
    if (NULL != length)
        *length = strlen (rval);
    return (char *) rval;
}

+ (NSString *) PGTSFieldAliases: (unsigned int) count
{
    return [self PGTSFieldAliases: count start: 1];
}

+ (NSString *) PGTSFieldAliases: (unsigned int) count start: (unsigned int) start
{
    NSString* rval = nil;
    if (0 >= count)
        rval = @"";
    else
    {
        rval = [NSMutableString stringWithCapacity: 3 * (count % 10) + 4 * ((count / 10) % 10)];
        for (unsigned int i = start; i <= count; i++)
            [(NSMutableString *) rval appendFormat: @"$%u,", i];
        [(NSMutableString *) rval deleteCharactersInRange: NSMakeRange ([rval length] - 1, 1)];
    }
    return rval;
}

/**
 * Escape the string for the SQL interpreter.
 */
- (NSString *) PGTSEscapedString: (PGTSConnection *) connection
{
    const char* from = [self UTF8String];
    size_t length = strlen (from);
    char* to = calloc (1 + 2 * length, sizeof (char));
    PQescapeStringConn ([connection pgConnection], to, from, length, NULL);
    NSString* rval = [NSString stringWithUTF8String: to];
    free (to);
    return rval;
}

/**
 * The number of parameters in a string.
 * Parameters are marked as follows: $n. The number of parameters is equal to the highest value of n.
 */
- (int) PGTSParameterCount
{
    NSScanner* scanner = [NSScanner scannerWithString: self];
    int paramCount = 0;
    while (NO == [scanner isAtEnd])
    {
        int foundCount = 0;
        [scanner scanUpToString: @"$" intoString: NULL];
        [scanner scanString: @"$" intoString: NULL];
        //The largest found number specifies the number of parameters
        if ([scanner scanInt: &foundCount])
            paramCount = MAX (foundCount, paramCount);
    }
    return paramCount;
}

- (NSString *) PGTSQuotedString
{
    return [NSString stringWithFormat: @"\"%@\"", self];
}

@end


@implementation NSData (PGTSAdditions)
//TODO: -PGTSParameterLength:
//Should we use htonl?
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
	size_t resultLength = 0;
	unsigned char *unescaped = PQunescapeBytea((unsigned char*)value, &resultLength);
	
	if (NULL == unescaped)
	{
		log4Error (@"PQunescapeBytea failed for characters: %s", value); //FIXME: Handle error?
		return nil;
	}
	
    NSData *data = [[self class] dataWithBytes: unescaped length: resultLength];
	
	PQfreemem(unescaped);
	
	return data;
}

- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    const char* rval = [self bytes];
    if (NULL != length)
        *length = [self length];
    return (char *) rval;
}

@end


@interface NSArray (PGTSPrivateAdditions)
- (NSString *) PGTSParameter2: (PGTSConnection *) connection;
@end

@implementation NSArray (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    id rval = [NSMutableArray array];
    //Used with typeInfo: argument later
    PGTSTypeInfo* elementType = [[typeInfo database] typeInfoForTypeWithOid: [typeInfo elementOid]];
    if (nil != elementType)
    {
        char delimiter = [elementType delimiter];
        NSDictionary* deserializationDictionary = [[elementType connection] deserializationDictionary];
        if (nil == deserializationDictionary)
            deserializationDictionary = [NSDictionary PGTSDeserializationDictionary];
        Class elementClass = [deserializationDictionary objectForKey: [elementType name]];
        if (Nil == elementClass)
            elementClass = [NSData class];
        
        size_t length = strlen (value);
        unsigned int objectBaseIndex = 0;
        unsigned int i = 0;

        //First check if the array starts with a length (or whatever) specifier. If this is the case, skip it.
        if ('[' == value [i])
        {
            for (int j = i + 1; j < length; j++)
            {
                if (']' == value [j] && '=' == value [j + 1])
                {
                    i = j + 2;
                    objectBaseIndex = i;
                    break;
                }
            }
        }
        
        //Then check if the array starts and ends with { and }. If this is the case, remove them.
        //The database does not seem to tell about this beforehand.
        if ('{' == value [i] && '}' == value [length - 1])
        {
            i++;
            objectBaseIndex = i;
            length -= 1;
        }
        
        if (0 < (length - i))
        {
            while (i <= length)
            {
                if (delimiter == value [i] || i == length)
                {
                    if (i == objectBaseIndex)
                        [rval addObject: [NSNull null]];
                    else
                    {
                        unsigned int length = i - objectBaseIndex;
                        size_t size = (length + 1) * sizeof (char);
                        
                        char* objectData = malloc (size);
                        memcpy (objectData, &value [objectBaseIndex], size);
                        objectData [length] = '\0';
                        
                        id object = [elementClass newForPGTSResultSet: set withCharacters: objectData typeInfo: elementType];
                        [rval addObject: object];
                        
                        free (objectData);
                    }
                    objectBaseIndex = i + 1;
                }
                i++;
            }
        }
    }
    return rval;
}

- (NSString *) PGTSFieldnames: (PGTSConnection *) connection
{
    NSMutableArray* names = [NSMutableArray arrayWithCapacity: [self count]];
    TSEnumerate (currentName, e, [self objectEnumerator])
    {
        [names addObject: [NSString stringWithFormat: @"\"%@\"", [currentName PGTSEscapedString: connection]]];
    }
    return [names componentsJoinedByString: @","];
}

- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    return [[self PGTSParameter2: connection] PGTSParameterLength: length connection: connection];
}

- (NSString *) PGTSParameter2: (PGTSConnection *) connection
{
    //PostgreSQL array (hopefully) cannot contain other kinds of elements,
    //which is good, since the input syntax is not easy to produce using recursion
    NSString* rval = nil;
    if (0 == [self count])
        rval = @"{}";
    else if ([[self objectAtIndex: 0] isKindOfClass: [NSArray class]])
        rval = [[self valueForKey: @"PGTSParameter2"] componentsJoinedByString: @", "];
    else
    {
        NSMutableArray* components = [NSMutableArray arrayWithCapacity: [self count]];
        TSEnumerate (currentObject, e, [self objectEnumerator])
        {
            int length = 0;
            char* parameter = [currentObject PGTSParameterLength: &length connection: connection];
            char* escapedParameter = calloc (2 * length + 1, sizeof (char));
            PQescapeStringConn ([connection pgConnection], escapedParameter, parameter, length, NULL);
            [components addObject: [NSString stringWithUTF8String: escapedParameter]];
        }
        rval = [NSString stringWithFormat: @"{\"%@\"}", [components componentsJoinedByString: @"\", \""]];
    }
    return rval;
}
@end


@implementation NSDate (PGTSAdditions)
- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    return [[self descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S.%F"
                                       timeZone: [NSTimeZone localTimeZone]
                                         locale: nil] PGTSParameterLength: length connection: connection];
}

+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    NSMutableString* dateString = [NSMutableString stringWithUTF8String: value];
    switch ([dateString length])
    {
        //PostgreSQL seems to count significant numbers in its timestamp,
        //which Foundation is unable to interpret
        case 19:
            [dateString appendString: @".00"];
        case 22:
            [dateString appendString: @"0"];
        case 23:
        default:
            break;
    }
    id rval = [NSCalendarDate dateWithString: dateString
                              calendarFormat: @"%Y-%m-%d %H:%M:%S.%F"];
    NSAssert (nil != rval, @"Failed matching string to date format");
    return [NSDate dateWithTimeIntervalSinceReferenceDate: [rval timeIntervalSinceReferenceDate]];
}
@end


@implementation NSCalendarDate (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    id rval;
    NSString* dateString = [NSString stringWithUTF8String: value];
    switch ([dateString length])
    {
        case 10:
            rval = [[self class] dateWithString:dateString calendarFormat:@"%Y-%m-%d"];
            break;
        default:
        {
            
            rval = [[self class] dateWithString: dateString
                                 calendarFormat: @"%Y-%m-%d %H:%M:%S.%F+%z"];
        }
    }
    NSAssert1 (nil != rval, @"Failed matching string %@ to date format.", dateString);
    return rval;
}

- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    NSString* description = [self descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S%z"];
    return [description PGTSParameterLength: length connection: connection];
}
@end


@implementation NSDecimalNumber (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    NSDecimal decimal;
    NSString* stringValue = [NSString stringWithUTF8String: value];
    NSScanner* scanner = [NSScanner scannerWithString: stringValue];
    [scanner scanDecimal: &decimal];
    return [NSDecimalNumber decimalNumberWithDecimal: decimal];
}
@end


@implementation NSNumber (PGTSAdditions)
- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    return [[self description] PGTSParameterLength: length connection: connection];
}

+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    return [NSNumber numberWithLongLong: strtoll (value, NULL, 10)];
}

/**
 * Return the value as Oid.
 * \sa PGTSOidAsObject
 */
- (Oid) PGTSOidValue
{
    return [self unsignedIntValue];
}

- (id) PGTSConstantExpressionValue: (NSDictionary *) context
{
    return self;
}
@end

@implementation PGTSAbstractClass
- (id) init
{
    NSString* reason = [NSString stringWithFormat: @"%@ is an abstract class", [self class]];
    [[NSException exceptionWithName: NSGenericException 
                             reason: reason
                           userInfo: nil] raise];
    return nil;
}
@end

@implementation PGTSFloat
@end

@implementation PGTSFloat (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    return [NSNumber numberWithFloat: strtof (value, NULL)];
}
@end

@implementation PGTSDouble
@end

@implementation PGTSDouble (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    return [NSNumber numberWithDouble: strtod (value, NULL)];
}
@end

@implementation PGTSBool
@end

@implementation PGTSBool (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    BOOL boolValue = (value [0] == 't' ? YES : NO);
    return [NSNumber numberWithBool: boolValue];
}
@end

@implementation PGTSPoint
@end

@implementation PGTSPoint (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    NSPoint returnPoint;
    NSString* pointString = [NSString stringWithUTF8String: value];
    NSScanner* pointScanner = [NSScanner scannerWithString: pointString];
    [pointScanner setScanLocation: 1];
    [pointScanner scanFloat: &(returnPoint.x)];
    [pointScanner setScanLocation: [pointScanner scanLocation] + 1];
    [pointScanner scanFloat: &(returnPoint.y)];
    return [NSValue valueWithPoint: returnPoint];
}
@end

@implementation PGTSSize
@end

@implementation PGTSSize (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{
    NSPoint p = NSZeroPoint;
    [[PGTSPoint newForPGTSResultSet: set withCharacters: value typeInfo: typeInfo] getValue: &p];
    NSSize s;
    s.width = p.x;
    s.height = p.y;
    return [NSValue valueWithSize: s];
}
@end

@implementation PGTSACLItem (PGTSAdditions)
+ (id) newForPGTSResultSet: (PGTSResultSet *) res withCharacters: (char *) value typeInfo: (PGTSTypeInfo *) typeInfo
{        
    //Role and privileges are separated by an equals sign
    id rval = nil;
    char* grantingRole = value;
    char* role = strsep (&grantingRole, "=");
    char* privileges = strsep (&grantingRole, "/");
    
    //Zero-length but not NULL
    NSAssert (NULL != privileges && NULL != role && NULL != grantingRole, @"Unable to parse privileges.");
    
    //Role is zero-length if the privileges are for PUBLIC
    rval = [[[PGTSACLItem alloc] init] autorelease];
    if (0 != strlen (role))
    {
        PGTSDatabaseInfo* database = [[res connection] databaseInfo];
        
        //Remove "group " from beginning
        if (role == strstr (role, "group "))
            role = &role [6]; //6 == strlen ("group ");
        if (grantingRole == strstr (role, "group "))
            grantingRole = &grantingRole [6];
        
        [rval setRole: [database roleNamed: [NSString stringWithUTF8String: role]]];
        [rval setGrantingRole: [database roleNamed: [NSString stringWithUTF8String: grantingRole]]];
    }
    
    //Parse the privileges
    enum PGTSACLItemPrivilege userPrivileges = kPGTSPrivilegeNone;
    enum PGTSACLItemPrivilege grantOption = kPGTSPrivilegeNone;
    for (unsigned int i = 0, length = strlen (privileges); i < length; i++)
    {
        switch (privileges [i])
        {
            case 'r': //SELECT
                userPrivileges |= kPGTSPrivilegeSelect;
                grantOption = kPGTSPrivilegeSelectGrant;
                break;
            case 'w': //UPDATE
                userPrivileges |= kPGTSPrivilegeUpdate;
                grantOption = kPGTSPrivilegeUpdateGrant;
                break;
            case 'a': //INSERT
                userPrivileges |= kPGTSPrivilegeInsert;
                grantOption = kPGTSPrivilegeInsertGrant;
                break;
            case 'd': //DELETE
                userPrivileges |= kPGTSPrivilegeDelete;
                grantOption = kPGTSPrivilegeDeleteGrant;
                break;
            case 'x': //REFERENCES
                userPrivileges |= kPGTSPrivilegeReferences;
                grantOption = kPGTSPrivilegeReferencesGrant;
                break;
            case 't': //TRIGGER
                userPrivileges |= kPGTSPrivilegeTrigger;
                grantOption = kPGTSPrivilegeTriggerGrant;
                break;
            case 'X': //EXECUTE
                userPrivileges |= kPGTSPrivilegeExecute;
                grantOption = kPGTSPrivilegeExecuteGrant;
                break;
            case 'U': //USAGE
                userPrivileges |= kPGTSPrivilegeUsage;
                grantOption = kPGTSPrivilegeUsageGrant;
                break;
            case 'C': //CREATE
                userPrivileges |= kPGTSPrivilegeCreate;
                grantOption = kPGTSPrivilegeCreateGrant;
                break;
            case 'c': //CONNECT
                userPrivileges |= kPGTSPrivilegeConnect;
                grantOption = kPGTSPrivilegeConnectGrant;
                break;
            case 'T': //TEMPORARY
                userPrivileges |= kPGTSPrivilegeTemporary;
                grantOption = kPGTSPrivilegeTemporaryGrant;
                break;
            case '*': //Grant option
                userPrivileges |= grantOption;
                grantOption = kPGTSPrivilegeNone;
                break;
            default:
                break;
        }
    }
    [rval setPrivileges: userPrivileges];
    
    return rval;    
}
@end


@implementation NSURL (PGTSAdditions)
#define SetIf( VALUE, KEY ) if ((VALUE)) [connectionDict setObject: VALUE forKey: KEY];
- (NSMutableDictionary *) PGTSConnectionDictionary
{
	NSMutableDictionary* connectionDict = nil;
	if (0 == [@"pgsql" caseInsensitiveCompare: [self scheme]])
	{
		connectionDict = [NSMutableDictionary dictionary];    
		
		NSString* relativePath = [self relativePath];
		if (1 <= [relativePath length])
			SetIf ([relativePath substringFromIndex: 1], kPGTSDatabaseNameKey);
		
		SetIf ([self host], kPGTSHostKey);
		SetIf ([self user], kPGTSUserNameKey);
		SetIf ([self password], kPGTSPasswordKey);
		SetIf ([self port], kPGTSPortKey);
	}
	return connectionDict;
}
@end
