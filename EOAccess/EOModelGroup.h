/* -*-objc-*-
   EOModelGroup.h

   Copyright (C) 2000,2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Date: February 2000

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

#ifndef __EOModelGroup_h__
#define __EOModelGroup_h__

#include <EOControl/EOObjectStoreCoordinator.h>

#include <EOAccess/EODefines.h>


@class NSArray;
@class NSDictionary;
@class NSMutableDictionary;
@class NSString;

@class EOModel;
@class EOEntity;
@class EORelationship;
@class EOGlobalID;
@class EOAttribute;
@class EOStoredProcedure;
@class EOFetchSpecification;


@interface EOModelGroup : NSObject
{
  NSMutableDictionary *_modelsByName;
  id _delegate;

  struct {
    unsigned int entityNamed:1;
    unsigned int relationshipForRow:1;
    unsigned int subEntityForEntity:1;
    unsigned int failedToLookupClassNamed:1;
    unsigned int classForObjectWithGlobalID:1;
    unsigned int _RESERVED:27;
  } _delegateRespondsTo;
}

+ (EOModelGroup *)defaultGroup;
+ (void)setDefaultGroup: (EOModelGroup *)group;

+ (EOModelGroup *)globalModelGroup;

+ (void)setDelegate: (id)delegate;
+ (id)delegate;

- (NSArray *)models;

- (NSArray *)modelNames;

- (EOModel *)modelNamed: (NSString *)name;

- (EOModel *)modelWithPath: (NSString *)path;

- (void)addModel: (EOModel *)model;

- (EOModel *)addModelWithFile: (NSString *)path;

- (void)removeModel: (EOModel *)model;

- (EOEntity *)entityNamed: (NSString *)entityName;

- (NSArray *)availablePrototypesForAdaptorName: (NSString *)adaptorName;
- (EOAttribute *)prototypeAttributeForAttribute: (EOAttribute *)attribute;

- (EOEntity *)entityForObject: (id)object;

- (void)loadAllModelObjects;

- (id)delegate;
- (void)setDelegate: (id)delegate;
- (EOFetchSpecification *)fetchSpecificationNamed: (NSString *)fetchSpecName 
                                      entityNamed: (NSString *)entityName;
 
- (EOStoredProcedure *)storedProcedureNamed: (NSString *)name;

@end

GDL2ACCESS_EXPORT NSString *EOModelAddedNotification;
GDL2ACCESS_EXPORT NSString *EOModelInvalidatedNotification;


@interface NSObject (EOModelGroupClassDelegation)

- (EOModelGroup *)defaultModelGroup;

@end

@interface NSObject (EOModelGroupDelegation)

- (EOModel *)modelGroup: (EOModelGroup *)group entityNamed: (NSString *)name;

- (EORelationship *)entity: (EOEntity *)entity
	relationshipForRow: (NSDictionary *)row
	      relationship: (EORelationship *)relationship;

- (EOEntity *)subEntityForEntity: (EOEntity *)entity
		      primaryKey: (NSDictionary *)primaryKey
			 isFinal: (BOOL *)flag;

- (Class)entity: (EOEntity *)entity
failedToLookupClassNamed: (NSString *)className;

- (Class)entity: (EOEntity *)entity
classForObjectWithGlobalID: (EOGlobalID *)globalID;

- (EOEntity *)relationship: (EORelationship *)relationship
failedToLookupDestinationNamed: (NSString *)entityName;

@end

@interface EOObjectStoreCoordinator (EOModelGroupSupport)

- (void)setModelGroup: (EOModelGroup *)group;
- (EOModelGroup *)modelGroup;

@end

#endif
