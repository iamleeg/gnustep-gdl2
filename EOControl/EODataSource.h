/* -*-objc-*-
   EODataSource.h

   Copyright (C) 2000,2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Date: July 2000

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

#ifndef __EODataSource_h__
#define __EODataSource_h__

#ifdef GNUSTEP
#include <Foundation/NSObject.h>
#else
#include <Foundation/Foundation.h>
#endif

@class NSArray;
@class NSDictionary;
@class NSString;

@class EOEditingContext;
@class EOClassDescription;


@interface EODataSource : NSObject 

- (id)createObject;
- (void)insertObject: (id)object;
- (void)deleteObject: (id)object;
- (NSArray *)fetchObjects;

- (EOEditingContext *)editingContext;

- (void)qualifyWithRelationshipKey: (NSString *)key ofObject: (id)sourceObject;
- (EODataSource *)dataSourceQualifiedByKey: (NSString *)key;

- (EOClassDescription *)classDescriptionForObjects;

- (NSArray *)qualifierBindingKeys;
- (void)setQualifierBindings: (NSDictionary *)bindings;
- (NSDictionary *)qualifierBindings;

@end

#endif
