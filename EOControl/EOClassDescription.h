/* 
   EOClassDescription.h

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

#ifndef __EOClassDescription_h__
#define __EOClassDescription_h__

#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSException.h>

@class NSDictionary;
@class NSFormatter;
@class EOEditingContext;
@class EOGlobalID;
@class EORelationship;

typedef enum
{
  EODeleteRuleNullify = 0,
  EODeleteRuleCascade,
  EODeleteRuleDeny,
  EODeleteRuleNoAction
} EODeleteRule;

@interface EOClassDescription : NSObject

+ (void)registerClassDescription: (EOClassDescription *)description
                        forClass: (Class)aClass;

+ (void)invalidateClassDescriptionCache;

+ (EOClassDescription *)classDescriptionForClass: (Class)aClass;

+ (EOClassDescription *)classDescriptionForEntityName: (NSString *)entityName;

+ (void)setClassDelegate: (id)delegate;
+ (id)classDelegate;

// Must be implemented by subclasses.
- (NSString *)entityName;

- (id)createInstanceWithEditingContext: (EOEditingContext *)editingContext
			      globalID: (EOGlobalID *)globalID
				  zone: (NSZone *)zone;

- (void)awakeObject: (id)object
fromInsertionInEditingContext: (EOEditingContext *)editingContext;

- (void)awakeObject: (id)object
fromFetchInEditingContext: (EOEditingContext *)editingContext;

- (void)propagateDeleteForObject: (id)object
		  editingContext: (EOEditingContext *)editingContext;

- (NSArray *)attributeKeys;
- (NSArray *)toOneRelationshipKeys;
- (NSArray *)toManyRelationshipKeys;
- (EORelationship *)relationshipNamed: (NSString *)relationshipName;
- (EORelationship *)anyRelationshipNamed: (NSString *)relationshipNamed;

- (NSString *)inverseForRelationshipKey: (NSString *)relationshipKey;

- (EODeleteRule)deleteRuleForRelationshipKey: (NSString *)relationshipKey;

- (BOOL)ownsDestinationObjectsForRelationshipKey: (NSString *)relationshipKey;

- (EOClassDescription *)classDescriptionForDestinationKey: (NSString *)detailKey;

- (NSFormatter *)defaultFormatterForKey: (NSString *)key;

- (NSString *)displayNameForKey: (NSString *)key;

- (NSString *)userPresentableDescriptionForObject: (id)anObject;

- (NSException *)validateValue: (id *)valueP forKey: (NSString *)key;

- (NSException *)validateObjectForSave: (id)object;

- (NSException *)validateObjectForDelete: (id)object;

@end


@interface NSObject (EOInitialization)

- initWithEditingContext: (EOEditingContext *)ec
	classDescription: (EOClassDescription *)classDesc
		globalID: (EOGlobalID *)globalID;

@end

@interface NSObject (EOClassDescriptionPrimitives)

- (EOClassDescription *)classDescription;

- (NSString *)entityName;
- (NSArray *)attributeKeys;
- (NSArray *)toOneRelationshipKeys;
- (NSArray *)toManyRelationshipKeys;
- (NSString *)inverseForRelationshipKey: (NSString *)relationshipKey;
- (EODeleteRule)deleteRuleForRelationshipKey: (NSString *)relationshipKey;
- (BOOL)ownsDestinationObjectsForRelationshipKey: (NSString *)relationshipKey;
- (EOClassDescription *)classDescriptionForDestinationKey: (NSString *)detailKey;

- (NSString *)userPresentableDescription;

- (NSException *)validateValue: (id *)valueP forKey: (NSString *)key;

- (NSException *)validateForSave;

- (NSException *)validateForDelete;

- (void)awakeFromInsertionInEditingContext: (EOEditingContext *)editingContext;

- (void)awakeFromFetchInEditingContext: (EOEditingContext *)editingContext;

@end

// Notifications:

extern NSString *EOClassDescriptionNeededNotification;
extern NSString *EOClassDescriptionNeededForClassNotification;

extern NSString *EOClassDescriptionNeededForEntityNameNotification;


@interface NSArray(EOShallowCopy)

- (NSArray *)shallowCopy;

@end

@interface NSObject (EOClassDescriptionExtras)

- (NSDictionary *)snapshot;

- (void)updateFromSnapshot: (NSDictionary *)snapshot;

- (BOOL)isToManyKey: (NSString *)key;

- (NSException *)validateForInsert;
- (NSException *)validateForUpdate;

- (NSArray *)allPropertyKeys;

- (void)clearProperties;

- (void)propagateDeleteWithEditingContext: (EOEditingContext *)editingContext;

- (NSString *)eoShallowDescription;
- (NSString *)eoDescription;

@end

@interface NSObject (EOKeyRelationshipManipulation)

- (void)addObject: object toPropertyWithKey: (NSString *)key;

- (void)removeObject: object fromPropertyWithKey: (NSString *)key;

- (void)addObject: object toBothSidesOfRelationshipWithKey: (NSString *)key;
- (void)removeObject: object
fromBothSidesOfRelationshipWithKey: (NSString *)key;

@end

// Validation exceptions (with name EOValidationException)
extern NSString *EOValidationException;
extern NSString *EOAdditionalExceptionsKey;
extern NSString *EOValidatedObjectUserInfoKey;
extern NSString *EOValidatedPropertyUserInfoKey;

@interface NSException (EOValidationError)

+ (NSException *)validationExceptionWithFormat: (NSString *)format, ...;
+ (NSException *)aggregateExceptionWithExceptions: (NSArray *)subexceptions;
- (NSException *)exceptionAddingEntriesToUserInfo: (NSDictionary *)additions;

@end

@interface NSObject (EOClassDescriptionClassDelegate)

- (BOOL)shouldPropagateDeleteForObject: (id)object
		      inEditingContext: (EOEditingContext *)ec
		    forRelationshipKey: (NSString *)key;

@end


@interface NSObject (_EOValueMerging)

- (void)mergeValue: (id)value forKey: (id)key;
- (void)mergeChangesFromDictionary: (NSDictionary *)changes;
- (NSDictionary *)changesFromSnapshot: (NSDictionary *)snapshot;
- (void)reapplyChangesFromSnapshot: (NSDictionary *)changes;

@end

@interface NSObject (_EOEditingContext)
-(EOEditingContext*)editingContext;
@end

#endif