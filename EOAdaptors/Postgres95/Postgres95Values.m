/** 
   Postgres95Values.m

   Copyright (C) 2000-2002 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@rccr.cremona.it
   Date: February 2000

   $Revision$
   $Date$

   <abstract></abstract>

   This file is part of the GNUstep Database Library.

   <license>
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
   </license>
**/

static char rcsId[] = "$Id$";

#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#include <Foundation/NSException.h>

#import <EOAccess/EOAccess.h>
#import <EOAccess/EOAttribute.h>

#import <Postgres95EOAdaptor/Postgres95Adaptor.h>
#import <Postgres95EOAdaptor/Postgres95Channel.h>
#import <Postgres95EOAdaptor/Postgres95Values.h>


void __postgres95_values_linking_function (void)
{
}

//NSString *Postgres95CalendarFormat = @"%m-%d-%Y %H:%M:%S %Z";
NSString *Postgres95CalendarFormat = nil;

@implementation Postgres95Values


+ (id)newValueForBytes: (const void *)bytes
                length: (int)length
             attribute: (EOAttribute *)attribute
{
  switch ([attribute adaptorValueType])
    {
    case EOAdaptorNumberType:
      return [self newValueForNumberType: bytes
		   length: length
		   attribute: attribute];
    case EOAdaptorCharactersType:
      return [self newValueForCharactersType: bytes
		   length: length
		   attribute: attribute];
    case EOAdaptorBytesType:
      return [self newValueForBytesType: bytes
		   length: length
		   attribute: attribute];
    case EOAdaptorDateType:
      return [self newValueForDateType: bytes
		   length: length
		   attribute: attribute];
    }

    return nil;
}

/**
For efficiency reasons, the returned value is NOT autoreleased !
**/
+ (id)newValueForNumberType: (const void *)bytes
                     length: (int)length
                  attribute: (EOAttribute *)attribute
{
  NSString *str = [NSString stringWithCString:(char *)bytes 
                            length:length];
  id value = nil;

  if ([[attribute externalType] isEqualToString: @"bool"])
    {
      if (((char *)bytes)[0] == 't' && ((char *)bytes)[1] == 0)
	return [[NSNumber alloc] initWithBool:YES];
      if (((char *)bytes)[0] == 'f' && ((char *)bytes)[1] == 0)
	return [[NSNumber alloc] initWithBool:NO];
    }

  if ([[attribute valueClassName] isEqualToString: @"NSDecimalNumber"])
    value = [[NSDecimalNumber decimalNumberWithString: str] retain];
  else if ([[attribute valueType] isEqualToString: @"i"])
    value = [[NSNumber alloc] initWithInt: [str intValue]];
  else
    value = [[NSNumber alloc] initWithDouble: [str doubleValue]];

  return value;
}

/**
For efficiency reasons, the returned value is NOT autoreleased !
**/
+ (id)newValueForCharactersType: (const void *)bytes
                         length: (int)length
                      attribute: (EOAttribute *)attribute
{
  return [attribute newValueForBytes: bytes
		    length: length
		    encoding: [NSString defaultCStringEncoding]];
}

/**
For efficiency reasons, the returned value is NOT autoreleased !
**/
+ (id)newValueForBytesType: (const void *)bytes
                    length: (int)length
                 attribute: (EOAttribute *)attribute
{
  return [attribute newValueForBytes: bytes
		    length: length];
}


/**
For efficiency reasons, the returned value is NOT autoreleased !
**/
+ (id)newValueForDateType: (const void *)bytes
                   length: (int)length
                attribute: (EOAttribute *)attribute
{
  id d;
  NSString *str = [NSString stringWithCString: bytes length: length];
  NSString *format = [NSCalendarDate postgres95Format];

  d = [[[NSCalendarDate alloc] initWithString: str
			       calendarFormat: format]
	// TODO server TZ ?
	retain];

//  NSDebugMLLog(@"gsdb",@"str=%@ d=%@ format=%@",str,d,format);  
  NSDebugMLog(@"str=%@ d=%@ format=%@", str, d, format);  

  return d;
}


@end
/*
@implementation NSString (Postgres95ValueCreation)


For efficiency reasons, the returned value is NOT autoreleased !

- stringValueForPostgres95Type:(NSString*)type
  attribute:(EOAttribute*)attribute
{
if ([type isEqual:@"bytea"])
    return [[NSData alloc]initWithBytes:[self cString]
      length:[self cStringLength]]
      stringValueForPostgres95Type:type
               attribute:attribute];
    else
      return [[[[EOQuotedExpression alloc]
                 initWithExpression:self
                 quote:@"'"
                 escape:@"\\'"]
                autorelease]
               expressionValueForContext:nil];
    return nil;
}

@end // NSString (Postgres95ValueCreation)



@implementation NSNumber (Postgres95ValueCreation)

- stringValueForPostgres95Type:(NSString*)type
  attribute:(EOAttribute*)attribute;
{
    if ([[attribute externalType] isEqualToString:@"bool"])
	return [self boolValue] ? @"'t'" : @"'f'";

    return [self description];
}

@end // NSNumber (Postgres95ValueCreation)


@implementation NSData (Postgres95ValueCreation)


- stringValueForPostgres95Type:(NSString*)type
  attribute:(EOAttribute*)attribute
{
    if ([[attribute externalType] isEqualToString:@"bytea"]) {
	const char* bytes = [self bytes];
	int length = [self length];
	int final_length;
	char *description, *temp;
	int i;
    
	if (!length)
	    return @"''";

	final_length = 4 + 2 * length + 1;
	description = Malloc (final_length);
	temp = description + 3;
    
	description[0] = 0;
	strcat (description, "'0x");
	for (i = 0; i < length; i++, temp += 2)
	    sprintf (temp, "%02X", (unsigned char)bytes[i]);
	temp[0] = '\'';
	temp[1] = 0;
	
	return [[[NSString alloc] 
		initWithCStringNoCopy:description
		length:final_length-1
		freeWhenDone:YES]
	    autorelease];
    }
    
    return [[NSString stringWithCString:[self bytes] length:[self length]]
	    stringValueForPostgres95Type:type attribute:attribute];
}

@end // NSData (Postgres95ValueCreation)

*/
@implementation NSCalendarDate (Postgres95ValueCreation)
/*
- stringValueForPostgres95Type:(NSString*)type
  attribute:(EOAttribute*)attribute
{
    NSString* externalType = [attribute externalType];
	if (!CALENDAR_FORMAT)
	  [NSCalendarDate setPostgres95Format:[NSString stringWithCString:"%b %d %Y %I:%M%p %Z"]];
  
    if ([externalType isEqualToString:@"abstime"]) {
	id tz = [attribute serverTimeZone];
	id date;

	if (tz) {
	    date = [[self copy] autorelease];
	    [date setTimeZone:tz];
	}
	else
	    date = self;

	return [NSString stringWithFormat:@"'%@'",
		    [date descriptionWithCalendarFormat:CALENDAR_FORMAT]];
    }

    THROW([[DataTypeMappingNotSupportedException alloc]
	    initWithFormat:@"Postgres95 cannot map NSCalendarDate in "
			    @"attribute %@ to external type %@",
			    [attribute name], externalType]);
    return nil;
}
*/

+ (NSString*)postgres95Format
{
  if (!Postgres95CalendarFormat)
    //Mirko: @"%d/%m/%Y %H:%M:%S.00 %Z"
    [NSCalendarDate setPostgres95Format: [NSString stringWithCString: "%m-%d-%Y %H:%M:%S %Z"]]; //"%b %d %Y %I:%M%p %Z"]];

  return Postgres95CalendarFormat;
}

+ (void)setPostgres95Format: (NSString*)_format
{
  ASSIGN(Postgres95CalendarFormat, _format); 
}


@end // NSCalendarDate (Postgres95ValueCreation)

/*
@implementation EONull (Postgres95ValueCreation)

- stringValueForPostgres95Type:(NSString*)type
  attribute:(EOAttribute*)attribute
{
    return @"NULL";
}

@end


@implementation NSObject (Postgres95ValueCreation)

- stringValueForPostgres95Type:(NSString*)type
  attribute:(EOAttribute*)attribute
{
    if ([self respondsToSelector:@selector(stringForType:)])
	return [[self stringForType:[attribute valueType]]
		    stringValueForPostgres95Type:type attribute:attribute];
    else if ([self respondsToSelector:@selector(dataForType:)])
	return [[self dataForType:[attribute valueType]]
		    stringValueForPostgres95Type:type attribute:attribute];
    else
	THROW([[DataTypeMappingNotSupportedException alloc]
		initWithFormat:@"Postgres95 cannot map value class %@ "
		@"because its instances does not responds to either "
		@" `stringForType:' or `dataForType:'. ",
		NSStringFromClass([self class])]);
    return nil;
}

@end // NSObject (Postgres95ValueCreation)
*/