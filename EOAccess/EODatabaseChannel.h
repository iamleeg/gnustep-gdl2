/* -*-objc-*-
   EODatabaseChannel.h

   Copyright (C) 2000-2002,2003,2004,2005 Free Software Foundation, Inc.

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

#ifndef __EODatabaseChannel_h__
#define __EODatabaseChannel_h__


#ifdef GNUSTEP
#include <Foundation/NSObject.h>
#else
#include <Foundation/Foundation.h>
#endif


@class NSMutableArray;

@class EOEntity;
@class EOAdaptorChannel;
@class EORelationship;
@class EODatabaseContext;
@class EOEditingContext;
@class EOFetchSpecification;


@interface EODatabaseChannel : NSObject
{
  EODatabaseContext *_databaseContext;
  id _delegate;
  EOAdaptorChannel *_adaptorChannel;
  EOEntity *_currentEntity;
  EOEditingContext *_currentEditingContext;
  NSMutableArray *_fetchProperties;
  NSMutableArray *_fetchSpecifications;
  BOOL _isLocking;
  BOOL _isRefreshingObjects;

  struct {
    unsigned int shouldSelectObjects:1;
    unsigned int didSelectObjects:1;
    unsigned int shouldUsePessimisticLock:1;
    unsigned int shouldUpdateSnapshot:1;
    unsigned int _reserved:28;
  } _delegateRespondsTo;
}

+ (EODatabaseChannel *)databaseChannelWithDatabaseContext: (EODatabaseContext *)databaseContext;

- (id)initWithDatabaseContext: (EODatabaseContext *)databaseContext;

- (void)setCurrentEntity: (EOEntity *)entity;
- (void)setEntity: (EOEntity *)entity;

- (void)setCurrentEditingContext: (EOEditingContext *)context;

- (void)selectObjectsWithFetchSpecification: (EOFetchSpecification *)fetchSpecification
                             editingContext: (EOEditingContext *)context;

- (id)fetchObject;

- (BOOL)isFetchInProgress;

- (void)cancelFetch;

- (EODatabaseContext *)databaseContext;

- (EOAdaptorChannel *)adaptorChannel;

- (BOOL)isRefreshingObjects;
- (void)setIsRefreshingObjects: (BOOL)yn;

- (BOOL)isLocking;
- (void)setIsLocking: (BOOL)isLocking;

- (void)setDelegate: (id)delegate;
- (id)delegate;

@end

#endif /* __EODatabaseChannel_h__ */
