/* 
   EOAdaptor.h

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@rccr.cremona.it>
   Date: February 2000

   This file is part of the GNUstep Database Library.

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
*/

#ifndef __EOAdaptor_h__
#define __EOAdaptor_h__

#import <Foundation/NSObject.h>


@class NSMutableArray;
@class NSDictionary;
@class NSString;
@class NSNumber;

@class EOModel;
@class EOAttribute;
@class EOAdaptorContext;
@class EOLoginPanel;
@class EOEntity;

extern NSString *EOGeneralAdaptorException;


@interface EOAdaptor : NSObject
{
  EOModel *_model;//Not in EOFD

  NSString *_name;
  NSDictionary *_connectionDictionary;
  NSMutableArray *_contexts;	// values with contexts
  NSString *_expressionClassName;
  Class _expressionClass;
  id _delegate;	// not retained
  
  struct {
    unsigned processValue:1;
  } _delegateRespondsTo;
}

/* Creating an EOAdaptor */
+ (EOAdaptor *)adaptorWithModel: (EOModel *)model;
+ (EOAdaptor *)adaptorWithName: (NSString *)name;

+ (void)setExpressionClassName: (NSString *)sqlExpressionClassName
              adaptorClassName: (NSString *)adaptorClassName;
+ (EOLoginPanel *)sharedLoginPanelInstance;

+ (NSArray *)availableAdaptorNames;
+ (NSArray *)prototypes;

- initWithName:(NSString *)name;

/* Getting an adaptor's name */
- (NSString *)name;

/* Creating and removing an adaptor context */
- (EOAdaptorContext *)createAdaptorContext;
- (NSArray *)contexts;

/* Setting the model */
- (void)setModel: (EOModel*)aModel;//Not in EOFD
- (EOModel*)model;//Not in EOFD

/* Checking connection status */
- (BOOL)hasOpenChannels;

/* Getting adaptor-specific information */
- (Class)expressionClass;
- (Class)defaultExpressionClass;

/* Reconnection to database */
- (void)handleDroppedConnection;
- (BOOL)isDroppedConnectionException: (NSException *)exception;

/* Setting connection information */
- (void)setConnectionDictionary: (NSDictionary*)aDictionary;
- (NSDictionary *)connectionDictionary;
- (void)assertConnectionDictionaryIsValid;

- (BOOL)canServiceModel: (EOModel *)model;

- (NSStringEncoding)databaseEncoding;

- (id)fetchedValueForValue: (id)value
                 attribute: (EOAttribute *)attribute;
- (NSString *)fetchedValueForStringValue: (NSString *)value
			       attribute: (EOAttribute *)attribute;
- (NSNumber *)fetchedValueForNumberValue: (NSNumber *)value
                               attribute: (EOAttribute *)attribute;
- (NSCalendarDate *)fetchedValueForDateValue: (NSCalendarDate *)value
                                   attribute: (EOAttribute *)attribute;
- (NSData *)fetchedValueForDataValue: (NSData *)value
                           attribute: (EOAttribute *)attribute;

/* Setting the delegate */
- (id)delegate;
- (void)setDelegate: delegate;

@end /* EOAdaptor */


@interface EOAdaptor (EOAdaptorLoginPanel)

- (BOOL)runLoginPanelAndValidateConnectionDictionary;
- (NSDictionary *)runLoginPanel;

@end


@interface EOAdaptor (EOExternalTypeMapping)

+ (NSString *)internalTypeForExternalType: (NSString *)extType
                                    model: (EOModel *)model;
+ (NSArray *)externalTypesWithModel: (EOModel *)model;
+ (void)assignExternalTypeForAttribute: (EOAttribute *)attribute;
+ (void)assignExternalInfoForAttribute: (EOAttribute *)attribute;
+ (void)assignExternalInfoForEntity: (EOEntity *)entity;
+ (void)assignExternalInfoForEntireModel: (EOModel *)model;

@end


@interface EOAdaptor (EOSchemaGenerationExtensions)

- (void)dropDatabaseWithAdministrativeConnectionDictionary: (NSDictionary *)administrativeConnectionDictionary;
- (void)createDatabaseWithAdministrativeConnectionDictionary: (NSDictionary *)administrativeConnectionDictionary;

@end


@interface EOLoginPanel : NSObject

- (NSDictionary *)runPanelForAdaptor: (EOAdaptor *)adaptor validate: (BOOL)yn;
- (NSDictionary *)administraticeConnectionDictionaryForAdaptor: (EOAdaptor *)adaptor;

@end


@interface NSObject (EOAdaptorDelegate)

- (id)adaptor: (EOAdaptor *)adaptor
fetchedValueForValue: (id)value
    attribute: (EOAttribute *)attribute;
- (NSDictionary *)reconnectionDictionaryForAdaptor: (EOAdaptor *)adaptor;

@end /* NSObject (EOAdaptorDelegate) */


#endif /* __EOAdaptor_h__*/