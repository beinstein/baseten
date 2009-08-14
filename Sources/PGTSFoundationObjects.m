//
// PGTSFoundationObjects.m
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


#import <BaseTen/libpq-fe.h>
#import "PGTSFoundationObjects.h"
#import "PGTSConnection.h"
#import "PGTSConnectionPrivate.h"
#import "PGTSTypeDescription.h"
#import "PGTSTableDescription.h"
#import "PGTSColumnDescription.h"
#import "PGTSDatabaseDescription.h"
#import "PGTSResultSet.h"
#import "BXLogger.h"
#import "BXEnumerate.h"


@implementation NSObject (PGTSFoundationObjects)
+ (id) copyForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) type columnIndex: (int) columnIndex
{
	return [self copyForPGTSResultSet: set withCharacters: value type: type];
}

+ (id) copyForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    BXLogWarning (@"Returning nil from NSObject's implementation for type %@ (%p).", [typeInfo name], typeInfo);
    return nil;
}

- (id) PGTSParameter: (PGTSConnection *) connection
{
	return self;
}

- (const char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    BXLogWarning (@"Returning NULL from NSObject's implementation for %@.", [self class]);
	if (length)
		*length = 0;
	return NULL;
}

- (BOOL) PGTSIsBinaryParameter
{
    return NO;
}

- (BOOL) PGTSIsCollection
{
	return NO;
}

- (id) PGTSExpressionOfType: (NSAttributeType) attrType
{
	return nil;
}
@end


@implementation NSExpression (PGTSFoundationObjects)
- (BOOL) PGTSIsCollection
{
	BOOL retval = NO;
	if ([self expressionType] == NSConstantValueExpressionType)
		retval = [[self constantValue] PGTSIsCollection];
	return retval;
}
@end


@implementation NSString (PGTSFoundationObjects)
+ (id) copyForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    return [[[[NSString alloc] initWithUTF8String: value] decomposedStringWithCanonicalMapping] retain];
}

- (const char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    if (connection)
    {
        const char* clientEncoding = PQparameterStatus ([connection pgConnection], "client_encoding");
		BXAssertValueReturn (clientEncoding && 0 == strcmp ("UNICODE", clientEncoding), NULL,
							 @"Expected client_encoding to be UNICODE (was: %s).", clientEncoding);
    }
	else
	{
        BXLogWarning (@"Connection pointer was nil.");
	}
	NSString* decomposed = [self decomposedStringWithCanonicalMapping];
    const char* retval = [decomposed UTF8String];
    if (NULL != length)
        *length = strlen (retval);
    return retval;
}

- (id) PGTSExpressionOfType: (NSAttributeType) attrType
{
	NSMutableString* retval = [NSMutableString stringWithString: self];
	[retval replaceOccurrencesOfString: @"'" withString: @"\\'" options: 0 range: NSMakeRange (0, [retval length])];
	[retval insertString: @"'" atIndex: 0];
	[retval appendString: @"'"];
	return retval;
}
@end


@implementation NSData (PGTSFoundationObjects)
+ (id) copyForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
	//All columns are currently fetched in text format but according to the manual only bytea is escaped.
	//Bit and varbit seem to return bit strings as their name indicates, rather than octet strings.

	NSData* retval = nil;
	
	NSString* name = [typeInfo name];
	if ([@"bytea" isEqualToString: name])
	{
		size_t resultLength = 0;
		unsigned char *unescaped = PQunescapeBytea ((const unsigned char *) value, &resultLength);
		if (unescaped)
		{
			retval = [[self alloc] initWithBytes: unescaped length: resultLength];
			PQfreemem (unescaped);
		}
		else
		{
			BXLogWarning (@"PQunescapeBytea failed for characters: %s.", value);
		}		
	}
	else
	{
		retval = [[self alloc] initWithBytes: value length: strlen (value)];
	}
	return retval;
}

- (const char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    const char* retval = [self bytes];
    if (NULL != length)
        *length = [self length];
    return retval;
}

- (BOOL) PGTSIsBinaryParameter
{
    return YES;
}
@end


@implementation NSArray (PGTSFoundationObjects)
static inline size_t
UnescapePGArray (char* dst, const char* const src_, size_t length)
{
    const char* const end = src_ + length;
    const char* src = src_;
    char c = '\0';
    while (src < end)
    {
        c = *src;
        switch (c)
        {
            case '\\':
                src++;
                c = *src;
                length--;
                //Fall through.
            default:
                *dst = c;
                src++;
                dst++;
        }
    }
    return length;
}

+ (id) copyForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) current type: (PGTSTypeDescription *) typeInfo
{
    id retval = [[NSMutableArray alloc] init];
    //Used with type: argument later
	PGTSConnection* connection = [set connection];
    PGTSTypeDescription* elementType = [[connection databaseDescription] typeWithOid: [typeInfo elementOid]];
    if (nil != elementType)
    {
        NSDictionary* deserializationDictionary = [connection deserializationDictionary];
        Class elementClass = [deserializationDictionary objectForKey: [elementType name]];
        if (Nil == elementClass)
            elementClass = [NSData class];
        
        //First check if the array starts with a range decoration. 
        //We don't do anything with them, at least yet, so we skip it.
        if ('[' == *current)
        {
            while ('\0' != current)
            {
                current++;
                if (']' == *current && '=' == *(current + 1))
                {
                    current += 2;
                    break;
                }
            }
        }
        
        //Check if the array is enclosed in curly braces. If this is the case, remove them.
        //Arrays should always have this decoration but possibly (?) sometimes don't.
        char endings [] = {[elementType delimiter], '\0', '\0'};
        if ('{' == *current)
        {
            current++;
            endings [1] = '}';
        }
        
        const char* element = NULL;
        const char* escaped = NULL;
        while (1)
        {
            //Mark the element beginning.
            if (NULL == element)
                element = current;
            
            //Remember the last escape character.
            if ('\\' == *current && current - 1 != escaped)
                escaped = current;
            
            if (strchr (endings, *current) && current != escaped)
            {
                const char* end = current;
                //Check for "value" -style element.
                if ('"' == *element)
                {
                    end--;
                    //Check for escaped quote before delimiter: "value1\","
                    //Also check for ending-in-element: "}"
                    if (element == end || end - 1 == escaped || '"' != *end)
                        goto continue_iteration;
                    
                    element++;
                }
                
                //Since we really are at the end of an element, create an object.
                id object = nil;
                if (element >= end)
                    object = [NSNull null];
                else
                {
                    //Make a copy and remove double-escapes.
                    //FIXME: hopefully malloc copes with requests for more than 0xffff bytes.
                    size_t last = end - element;
                    char* elementData = malloc (1 + last);
                    last = UnescapePGArray (elementData, element, last);
                    
                    //Add a terminating NUL so we get a C-string.
                    elementData [last] = '\0';
                    
                    //Create the object.
                    object = [[elementClass copyForPGTSResultSet: set withCharacters: elementData type: elementType] autorelease];
                    free (elementData);
                }
                [retval addObject: object];
                
                element = NULL;
                escaped = NULL;
                //Are we at the end?
                if (*current != endings [0])
                    break;
            }
            
continue_iteration:
                current++;
        }
    }
    return retval;
}

static inline void
AppendBytes (IMP impl, NSMutableData* target, const void* bytes, unsigned int length)
{
	(void)(void (*)(id, SEL, const void*, unsigned int)) impl (target, @selector (appendBytes:length:), bytes, length);
}

static inline void
EscapeAndAppendByte (IMP appendImpl, NSMutableData* target, const char* src)
{
    switch (*src)
    {
        case '\\':
        case '"':
            AppendBytes (appendImpl, target, "\\", 1);
            //Fall through.
        default:
            AppendBytes (appendImpl, target, src, 1);
    }
}

- (id) PGTSParameter: (PGTSConnection *) connection
{
    //We make use of UTF-8's ASCII-compatibility feature.
	id retval = nil;
    if (0 == [self count])
    {
		const char* emptyArray = "{}";
		retval = [NSData dataWithBytes: &emptyArray length: strlen (emptyArray)];
    }
    else
    {
        //Optimize a bit because we append each byte individually.
        NSMutableData* contents = [NSMutableData data];
        IMP impl = [contents methodForSelector: @selector (appendBytes:length:)];
        AppendBytes (impl, contents, "{", 1);
        BXEnumerate (currentObject, e, [self objectEnumerator])
        {
            if ([NSNull null] == currentObject)
			{
				const char* bytes = "null,";
                [contents appendBytes: bytes length: strlen (bytes)];
			}
            else
            {
                int length = -1;
                const char* value = [[currentObject PGTSParameter: connection] 
									 PGTSParameterLength: &length connection: connection];
                
                //Arrays can't have quotes around them.
                if ([currentObject isKindOfClass: [NSArray class]])
                {
                    AppendBytes (impl, contents, value, length);
                    AppendBytes (impl, contents, ",", 1);
                }
                else
                {
                    //If the length isn't known, wait for a NUL byte.
                    AppendBytes (impl, contents, "\"", 1);
                    if ([currentObject PGTSIsBinaryParameter] && -1 != length)
                    {
                        const char* end = value + length;
                        while (value < end)
                        {
                            EscapeAndAppendByte (impl, contents, value);
                            value++;
                        }
                    }
                    else
					{
                        while ('\0' != *value)
                        {
                            EscapeAndAppendByte (impl, contents, value);
                            value++;
                        }
                    }					
                    AppendBytes (impl, contents, "\"", 1);
                }
                AppendBytes (impl, contents, ",", 1);
            }
        }
		[contents replaceBytesInRange: NSMakeRange ([contents length] - 1, 1) withBytes: "}\0" length: 2]; 
		retval = contents;
    }
    return retval;
}

- (BOOL) PGTSIsCollection
{
	return YES;
}
@end


@implementation NSDecimalNumber (PGTSFoundationObjects)
+ (id) copyForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    NSDecimal decimal = {};
    NSString* stringValue = [NSString stringWithUTF8String: value];
    NSScanner* scanner = [NSScanner scannerWithString: stringValue];
    [scanner scanDecimal: &decimal];
    return [[NSDecimalNumber alloc] initWithDecimal: decimal];
}
@end


@implementation NSNumber (PGTSFoundationObjects)
- (id) PGTSParameter: (PGTSConnection *) connection
{
	return [self description];
}

+ (id) copyForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    return [[NSNumber alloc] initWithLongLong: strtoll (value, NULL, 10)];
}

- (id) PGTSExpressionOfType: (NSAttributeType) attrType
{
	id retval = self;
	if (NSBooleanAttributeType == attrType)
		retval = ([self boolValue] ? @"true" : @"false");
	return retval;
}
@end


@implementation NSSet (PGTSFoundationObjects)
- (BOOL) PGTSIsCollection
{
	return YES;
}

//FIXME: should we allow set parameters?
- (id) PGTSParameter: (PGTSConnection *) connection
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (const char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
	[self doesNotRecognizeSelector: _cmd];
	return NULL;
}
@end


@implementation NSXMLDocument (PGTSFoundationObjects)
+ (id) copyForPGTSResultSet: (PGTSResultSet *) result withCharacters: (const char *) value type: (PGTSTypeDescription *) type columnIndex: (int) columnIndex
{
	id retval = nil;
	BOOL shouldReturnDocument = NO;
	NSData* xmlData = [[[NSData alloc] initWithBytes: value length: strlen (value)] autorelease];
	PGresult* res = [result PGresult];
	Oid relid = PQftable (res, columnIndex);
	int attnum = PQftablecol (res, columnIndex);
	
	if (InvalidOid != relid)
	{
		PGTSDatabaseDescription* db = [[result connection] databaseDescription];
		PGTSTableDescription* rel = [db tableWithOid: relid];
		PGTSColumnDescription* column = [rel columnAtIndex: attnum];
		if ([column requiresDocuments])
			shouldReturnDocument = YES;
	}
	
	if (shouldReturnDocument)
	{
		NSError* error = nil;
		NSXMLDocument* document = [[NSXMLDocument alloc] initWithData: xmlData options: 0 error: &error];
		
		if (document)
			retval = document;
		else
			BXLogError (@"Unable to create XML document even though I was supposed to have received one. Error: %@.", error);
	}
	else
	{
		retval = [xmlData retain];
	}
	
	return retval;
}

- (id) PGTSParameter: (PGTSConnection *) connection
{
	return [self XMLStringWithOptions: NSXMLNodeCompactEmptyElement | NSXMLNodeUseDoubleQuotes];
}
@end


@implementation NSValue (PGTSFoundationObjects)
- (id) PGTSParameter: (PGTSConnection *) connection
{
	id retval = nil;
	if (0 == strcmp (@encode (NSPoint), [self objCType]))
	{
		NSPoint point = [self pointValue];
		retval = [NSString stringWithFormat: @"(%lf,%lf)", point.x, point.y];
	}
	else
	{
		retval = [super PGTSParameter: connection];
	}
	return retval;
}
@end


@implementation NSNull (PGTSFoundationObjects)
- (const char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
	if (length)
		*length = 0;
	return NULL;
}
@end
