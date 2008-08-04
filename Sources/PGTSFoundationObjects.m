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

#import <BaseTen/postgresql/libpq-fe.h>
#import "PGTSFoundationObjects.h"
#import "PGTSConnection.h"
#import "PGTSConnectionPrivate.h"
#import "PGTSFunctions.h"
#import "PGTSTypeDescription.h"
#import "PGTSDatabaseDescription.h"
#import "PGTSAdditions.h"
#import "PGTSResultSet.h"
#import "BXLogger.h"


@implementation NSObject (PGTSFoundationObjects)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    NSLog (@"Warning: returning a nil from NSObject's implementation.");
    return nil;
}

- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
	if (NULL != length)
		*length = 0;
	return NULL;
}

- (BOOL) PGTSIsBinaryParameter
{
    return NO;
}
@end


@implementation NSString (PGTSFoundationObjects)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    return [NSString stringWithUTF8String: value];
}

- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    if (nil == connection)
        BXLogWarning (@"Connection pointer was nil.");
    else
    {
        const char* clientEncoding = PQparameterStatus ([connection pgConnection], "client_encoding");
		BXAssertValueReturn (0 == strcmp ("UNICODE", clientEncoding), NULL,
							 @"Expected client_encoding to be UNICODE (was: %s).", clientEncoding);
    }
    const char* retval = [self UTF8String];
    if (NULL != length)
        *length = strlen (retval);
    return (char *) retval;
}
@end


@implementation NSData (PGTSFoundationObjects)
//FIXME: Should we use htonl?
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
	size_t resultLength = 0;
	unsigned char *unescaped = PQunescapeBytea ((unsigned char*) value, &resultLength);
	
	if (NULL == unescaped)
	{
		BXLogError (@"PQunescapeBytea failed for characters: %s", value); //FIXME: Handle error?
		return nil;
	}
	
    NSData *data = [[self class] dataWithBytes: unescaped length: resultLength];
	PQfreemem (unescaped);
	return data;
}

- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    const char* rval = [self bytes];
    if (NULL != length)
        *length = [self length];
    return (char *) rval;
}

- (BOOL) PGTSIsBinaryParameter
{
    return YES;
}
@end


@interface NSArray (PGTSPrivateAdditions)
- (NSString *) PGTSParameter2: (PGTSConnection *) connection;
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

+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) current type: (PGTSTypeDescription *) typeInfo
{
    id retval = [NSMutableArray array];
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
        char* endings = NULL;
        asprintf (&endings, "%c\0\0", [elementType delimiter]);
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
                    object = [elementClass newForPGTSResultSet: set withCharacters: elementData type: elementType];
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
        free (endings);
    }
    return retval;
}

static inline void
AppendBytes (IMP impl, NSMutableData* target, const void* bytes, unsigned int length)
{
    (void (*)(id, SEL, const void*, unsigned int)) impl (target, @selector (appendBytes:length:), bytes, length);
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

- (char *) PGTSParameterLength: (int *) outLength connection: (PGTSConnection *) connection
{
    //We make use of UTF-8's ASCII-compatibility feature.
    char* retval = NULL;
    if (0 == [self count])
    {
        retval = "{}";
        if (outLength)
            *outLength = 2;
    }
    else
    {
        //Optimize a bit because we append each byte individually.
        NSMutableData* contents = [NSMutableData data];
        IMP impl = [contents methodForSelector: @selector (appendBytes:length:)];
        AppendBytes (impl, contents, "{", 1);
        TSEnumerate (currentObject, e, [self objectEnumerator])
        {
            if ([NSNull null] == currentObject)
                [contents PGTSAppendCString: "null,"];
            else
            {
                int length = -1;
                char* value = [currentObject PGTSParameterLength: &length connection: connection];
                
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
                    if (-1 == length)
                    {
                        while ('\0' != *value)
                        {
                            EscapeAndAppendByte (impl, contents, value);
                            value++;
                        }
                    }
                    else
                    {
                        char* end = value + length;
                        while (value < end)
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
		retval = (char *) [contents bytes];
		if (outLength)
			*outLength = [contents length];
		
    }
    return retval;
}

@end


@implementation NSDate (PGTSFoundationObjects)
- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    NSMutableString* rval = [NSMutableString stringWithString: 
        [self descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S"
                                   timeZone: [NSTimeZone localTimeZone]
                                     locale: nil]];
    double integralPart = 0.0;
    double subseconds = modf ([self timeIntervalSinceReferenceDate], &integralPart);
    
    char* fractionalPart = NULL;
    asprintf (&fractionalPart, "%-.6f", fabs (subseconds));
    [rval appendFormat: @"%s", &fractionalPart [1]];
    free (fractionalPart);
    
    return [rval PGTSParameterLength: length connection: connection];
}

+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
	BXLogDebug (@"Given value: %s", value);
	
	size_t length = strlen (value) + 1;
    char* datetime = alloca (length);
	strlcpy (datetime, value, length);
	
    double interval = 0.0;
	char* subseconds = NULL;
	
    if ('.' == datetime [19])
    {
        datetime [19] = '\0';
        length = strlen (&datetime [20]) + 1;
        subseconds = alloca (2 + length);
        strlcpy (&subseconds [2], &datetime [20], length);
        subseconds [0] = '0';
        subseconds [1] = '.';
        interval = strtod (subseconds, NULL);
    }
    
    NSMutableString* dateString = [NSString stringWithUTF8String: datetime];
    id rval = [NSCalendarDate dateWithString: dateString
                              calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    rval = [NSDate dateWithTimeIntervalSinceReferenceDate: [rval timeIntervalSinceReferenceDate] + interval];
    BXAssertLog (nil != rval, @"Failed to match string to date format");
#ifndef L4_BLOCK_ASSERTIONS
	double integralPart = 0.0;
	BXAssertLog (NULL == subseconds || 0.0 < modf ([rval timeIntervalSince1970], &integralPart),
				   @"Expected date to have a fractional part (timestamp: %f, subseconds: %s)",
				   [rval timeIntervalSince1970], subseconds);
#endif
    return rval;
}
@end


@implementation NSCalendarDate (PGTSFoundationObjects)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    id rval = nil;
	size_t length = strlen (value);
    if (10 == length)
    {
        NSString* dateString = [NSString stringWithUTF8String: value];
        rval = [[self class] dateWithString: dateString calendarFormat: @"%Y-%m-%d"];
    }
    else
    {
        BOOL shouldContinue = YES;
        char tzmarker = '\0';
        char* timezone = NULL;
        char* subseconds = NULL;
		length++;
		char* datetime = alloca (length);
		strlcpy (datetime, value, length);
        
        switch (datetime [19])
        {
            case '+':
            case '-':
                tzmarker = datetime [19];
                timezone = &datetime [20];
                break;
            case '.':
            {
                subseconds = &datetime [20];
                
                unsigned int i = 0;
                while (isdigit (subseconds [i]))
                    i++;
                
                tzmarker = subseconds [i];
                subseconds [i] = '\0';
                timezone = &subseconds [i + 1];
                break;
            }
            default:
                shouldContinue = NO;
                break;
        }
        datetime [19] = '\0';
        
        if (YES == shouldContinue)
        {
            NSString* dateString = [NSString stringWithUTF8String: datetime];
            NSCalendarDate* date = [[self class] dateWithString: dateString
                                                 calendarFormat: @"%Y-%m-%d %H:%M:%S"];
            
            double interval = 0.0;
            if (NULL != subseconds)
            {
                size_t length = strlen (subseconds) + 1;
                char* subseconds2 = alloca (2 + length);
                strlcpy (&subseconds2 [2], subseconds, length);
                subseconds2 [0] = '0';
                subseconds2 [1] = '.';
                interval = strtod (subseconds2, NULL);
                date = [date addTimeInterval: interval];
            }
            
            if (NULL != timezone)
            {
                int secondsFromGMT = 0;
                char* minutes = NULL;
                if (':' == timezone [2])
                {
                    timezone [2] = '\0';
                    minutes = &timezone [3];
                    secondsFromGMT += 60 * strtol (minutes, NULL, 10);
                }                
                secondsFromGMT += 60 * 60 * strtol (timezone, NULL, 10);
                
                if ('-' == tzmarker)
                    secondsFromGMT *= -1;
                
                [date setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: secondsFromGMT]];
            }
            
            rval = date;
        }
    }
    
    BXAssertLog (nil != rval, @"Failed matching string %s to date format.", value);
    return rval;
}

- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    NSMutableString* rval = [NSMutableString stringWithString: [self descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S"]];
    double integralPart = 0.0;
    double subseconds = modf ([self timeIntervalSinceReferenceDate], &integralPart);
    
    char* fractionalPart = NULL;
    asprintf (&fractionalPart, "%-.6f", fabs (subseconds));
    [rval appendFormat: @"%s", &fractionalPart [1]];
    free (fractionalPart);
    
    int seconds = [[self timeZone] secondsFromGMT];
    [rval appendFormat: @"%+.2d:%.2d", seconds / (60 * 60), abs ((seconds % (60 * 60)) / 60)];
    return [rval PGTSParameterLength: length connection: connection];
}
@end


@implementation NSDecimalNumber (PGTSFoundationObjects)
+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    NSDecimal decimal;
    NSString* stringValue = [NSString stringWithUTF8String: value];
    NSScanner* scanner = [NSScanner scannerWithString: stringValue];
    [scanner scanDecimal: &decimal];
    return [NSDecimalNumber decimalNumberWithDecimal: decimal];
}
@end


@implementation NSNumber (PGTSFoundationObjects)
- (char *) PGTSParameterLength: (int *) length connection: (PGTSConnection *) connection
{
    return [[self description] PGTSParameterLength: length connection: connection];
}

+ (id) newForPGTSResultSet: (PGTSResultSet *) set withCharacters: (const char *) value type: (PGTSTypeDescription *) typeInfo
{
    return [NSNumber numberWithLongLong: strtoll (value, NULL, 10)];
}
@end
