/** 
   EORelationship.m <title>EORelationship</title>

   Copyright (C) 2000-2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Date: February 2000

   Author: Manuel Guesdon <mguesdon@orange-concept.com>
   Date: October 2000

   $Revision$
   $Date$

   <abstract></abstract>

   This file is part of the GNUstep Database Library.

   <license>
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
   </license>
**/

#include "config.h"

RCS_ID("$Id$")

#ifdef GNUSTEP
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>
#else
#include <Foundation/Foundation.h>
#include <GNUstepBase/GNUstep.h>
#include <GNUstepBase/GSObjCRuntime.h>
#include <GNUstepBase/NSDebug+GNUstepBase.h>
#include <GNUstepBase/NSObject+GNUstepBase.h>
#endif

#include <EOControl/EOObserver.h>
#include <EOControl/EOMutableKnownKeyDictionary.h>
#include <EOControl/EONSAddOns.h>
#include <EOControl/EODebug.h>

#include <EOAccess/EOModel.h>
#include <EOAccess/EOAttribute.h>
#include <EOAccess/EOEntity.h>
#include <EOAccess/EOStoredProcedure.h>
#include <EOAccess/EORelationship.h>
#include <EOAccess/EOJoin.h>
#include <EOAccess/EOExpressionArray.h>

#include "EOPrivate.h"
#include "EOAttributePriv.h"
#include "EOEntityPriv.h"

@interface EORelationship (EORelationshipPrivate)
- (void)_setInverseRelationship: (EORelationship *)relationship;
@end


@implementation EORelationship

+ (void)initialize
{
  static BOOL initialized = NO;
  if (!initialized)
    {
      initialized = YES;

      GDL2_EOAccessPrivateInit();
    }
}

/*
 this is used for key-value observing.
 */

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey
{
  if ([theKey isEqualToString:@"joins"]) {
    return NO;
  } 
  return [super automaticallyNotifiesObserversForKey:theKey];
}

+ (id) relationshipWithPropertyList: (NSDictionary *)propertyList
                              owner: (id)owner
{
  return AUTORELEASE([[self alloc] initWithPropertyList: propertyList
				   owner: owner]);
}

+ (EOJoinSemantic) _joinSemanticForName:(NSString*) semanticName
{
  if ([semanticName isEqual: @"EOInnerJoin"])
    return EOInnerJoin;
  else if ([semanticName isEqual: @"EOFullOuterJoin"])
    return EOFullOuterJoin;
  else if ([semanticName isEqual: @"EOLeftOuterJoin"])
    return EOLeftOuterJoin;
  else if ([semanticName isEqual: @"EORightOuterJoin"])
    return EORightOuterJoin;
  else 
  {
    [NSException raise: NSInvalidArgumentException
                format: @"%s: Unknown joinSemantic '%@'", __PRETTY_FUNCTION__, semanticName];
    
  }
  // make the compiler happy
  return EOInnerJoin;
}

+ (NSString *) _nameForJoinSemantic:(EOJoinSemantic) semantic
{
  switch (semantic)
  {
    case EOInnerJoin:
      return @"EOInnerJoin";
      
    case EOFullOuterJoin:
      return @"EOFullOuterJoin";
      
    case EOLeftOuterJoin:
      return @"EOLeftOuterJoin";
      
    case EORightOuterJoin:
      return @"EORightOuterJoin";
  }
  
  [NSException raise: NSInvalidArgumentException
              format: @"%s: Unknown joinSemantic '%d'", __PRETTY_FUNCTION__, semantic];
  
  // make the compiler happy
  return nil;
  
}

- (id)init
{
//OK
  if ((self = [super init]))
    {
      /*
      _sourceNames = [NSMutableDictionary new];
      _destinationNames = [NSMutableDictionary new];
      _userInfo = [NSDictionary new];
      _sourceToDestinationKeyMap = [NSDictionary new];
      */
      _joins = [NSMutableArray new];

    }

  return self;
}

- (void)dealloc
{
  [self _flushCache];

  DESTROY(_name);
  DESTROY(_qualifier);
  DESTROY(_sourceNames);
  DESTROY(_destinationNames);
  DESTROY(_userInfo);
  DESTROY(_internalInfo);
  DESTROY(_docComment);
  DESTROY(_joins);
  DESTROY(_sourceToDestinationKeyMap);
  DESTROY(_sourceRowToForeignKeyMapping);

  DESTROY(_definitionArray);

  _entity = nil;
  _destination = nil;
  
  [super dealloc];
}

- (NSUInteger)hash
{
  return [_name hash];
}

- (id) initWithPropertyList: (NSDictionary *)propertyList
                      owner: (id)owner
{
  //Near OK
  if ((self = [self init]))
    {
      NSString *joinSemanticString = nil;
      EOModel *model;
      NSString* destinationEntityName = nil;
      EOEntity* destinationEntity = nil;
      NSString* deleteRuleString = nil;
      NSString* relationshipName;



      model = [owner model];
      relationshipName = [propertyList objectForKey: @"name"];

      /* so setName: can validate against the owner */
      [self setEntity: owner];
      [self setName: relationshipName]; 

      destinationEntityName = [propertyList objectForKey: @"destination"];

      if (destinationEntityName) //If not, this is because it's a definition
        {
          destinationEntity = [model entityNamed: destinationEntityName];

          _destination = destinationEntity;
        }

      [self setToMany: [[propertyList objectForKey: @"isToMany"]
			 isEqual: @"Y"]];
      [self setIsMandatory: [[propertyList objectForKey: @"isMandatory"]
			      isEqual:@"Y"]];
      [self setOwnsDestination: [[propertyList
				   objectForKey: @"ownsDestination"]
				  isEqual: @"Y"]];
      [self setPropagatesPrimaryKey: [[propertyList
					objectForKey: @"propagatesPrimaryKey"]
				       isEqual: @"Y"]];
      [self setIsBidirectional: [[propertyList objectForKey: @"isBidirectional"]
				  isEqual: @"Y"]];

      [self setUserInfo: [propertyList objectForKey: @"userInfo"]];

      if(!_userInfo)
        [self setUserInfo: [propertyList objectForKey: @"userDictionary"]];

      [self setInternalInfo: [propertyList objectForKey: @"internalInfo"]];
      [self setDocComment: [propertyList objectForKey: @"docComment"]];

      joinSemanticString = [propertyList objectForKey: @"joinSemantic"];
      if (joinSemanticString)
      {
        [self setJoinSemantic: [[self class] _joinSemanticForName:joinSemanticString]];        
      }
      else
      {
          if (destinationEntityName)
            {
              EOFLOGObjectLevelArgs(@"EORelationship", @"!joinSemanticString but destinationEntityName. entityName=%@ relationshipName=%@",
				    [(EOEntity*)owner name],
				    relationshipName);
              NSEmitTODO(); //TODO
              [self notImplemented: _cmd]; //TODO
            }
        }

      deleteRuleString = [propertyList objectForKey: @"deleteRule"];
      EOFLOGObjectLevelArgs(@"EORelationship", @"entityName=%@ relationshipName=%@ deleteRuleString=%@",
			    [(EOEntity*)owner name],
			    relationshipName,
			    deleteRuleString);

      if (deleteRuleString)
        {
          EODeleteRule deleteRule = [self _deleteRuleFromString:
					    deleteRuleString];
          EOFLOGObjectLevelArgs(@"EORelationship",
				@"entityName=%@ relationshipName=%@ deleteRule=%d",
				[(EOEntity*)owner name],
				relationshipName,
				(int)deleteRule);
          NSAssert2(deleteRule >= 0 && deleteRule <= 3,
		    @"Bad deleteRule numeric value: %@ (%d)",
		    deleteRuleString,
		    deleteRule);

          [self setDeleteRule: deleteRule];
        }
    }



  return self;
}

- (void)awakeWithPropertyList: (NSDictionary *)propertyList  //TODO
{
  //OK for definition
  NSString *definition;



  EOFLOGObjectLevelArgs(@"EORelationship", @"self=%@", self);

  definition = [propertyList objectForKey: @"definition"];

  EOFLOGObjectLevelArgs(@"EORelationship", @"definition=%@", definition);

  if (definition)
    {
      [self setDefinition: definition];
    }
  else
    {
      NSString *dataPath = [propertyList objectForKey: @"dataPath"];

      EOFLOGObjectLevelArgs(@"EORelationship", @"dataPath=%@", dataPath);

      if (dataPath)
        {
          NSEmitTODO(); //TODO
          [self notImplemented: _cmd]; // TODO
        }
      else
        {
          NSArray *joins = [propertyList objectForKey: @"joins"];
          int count = [joins count];

          EOFLOGObjectLevelArgs(@"EORelationship", @"joins=%@", joins);

          if (count > 0)
            {
              int i;

              for (i = 0; i < count; i++)
                {
                  NSDictionary *joinPList;
                  NSString *joinSemantic;
                  NSString *sourceAttributeName;
                  EOAttribute *sourceAttribute;
                  EOEntity *destinationEntity;
                  NSString *destinationAttributeName = nil;
                  EOAttribute *destinationAttribute = nil;
                  EOJoin *join = nil;

                  joinPList = [joins objectAtIndex: i];
                  joinSemantic = [joinPList objectForKey: @"joinSemantic"];

                  sourceAttributeName = [joinPList objectForKey:
						     @"sourceAttribute"];
                  sourceAttribute = [_entity attributeNamed:
					       sourceAttributeName];

                  NSAssert4(sourceAttribute, @"No sourceAttribute named \"%@\" in entity \"%@\" in relationship %@\nEntity: %@",
                            sourceAttributeName,
                            [_entity name],
                            self,
                            _entity);

                  destinationEntity = [self destinationEntity];
                  NSAssert3(destinationEntity,@"No destination entity for relationship named '%@' in entity named '%@': %@",
                            [self name],
                            [[self entity]name],
                            self);
                  destinationAttributeName = [joinPList
					       objectForKey:
						 @"destinationAttribute"];
                  destinationAttribute = [destinationEntity
					   attributeNamed:
					     destinationAttributeName];

                  NSAssert4(destinationAttribute, @"No destinationAttribute named \"%@\" in entity \"%@\" in relationship %@\nEntity: %@",
                            destinationAttributeName,
                            [destinationEntity name],
                            self,
                            destinationEntity);

                  NS_DURING
                    {
                      join = [EOJoin joinWithSourceAttribute: sourceAttribute
				     destinationAttribute: destinationAttribute];
                    }
                  NS_HANDLER
                    {
                      [NSException raise: NSInvalidArgumentException
                                   format: @"%@ -- %@ 0x%x: cannot create join for relationship '%@': %@", 
                                   NSStringFromSelector(_cmd), 
                                   NSStringFromClass([self class]), 
                                   self, 
                                   [self name], 
                                   [localException reason]];
                    }
                  NS_ENDHANDLER;

                  EOFLOGObjectLevelArgs(@"EORelationship", @"join=%@", join);

                  [self addJoin: join];
                }
            }
          /*
            NSArray *array;
            NSEnumerator *enumerator;
            EOModel *model = [_entity model];
            id joinPList;
            
            if(_destination)
            {
            id destinationEntityName = [_destination autorelease];
            
            _destination = [[model entityNamed:destinationEntityName] retain];
            if(!_destination)
            {
          NSEmitTODO();  //TODO
            [self notImplemented:_cmd]; // TODO
            }
            }
          */
        }
    }
  /* ??
  if(!(_destination || _definitionArray))
    {
          NSEmitTODO();  //TODO
      [self notImplemented:_cmd]; // TODO
    };
  */


}

- (void)encodeIntoPropertyList: (NSMutableDictionary *)propertyList
{
  NS_DURING //Just for debugging
    {
      //VERIFY
      [propertyList setObject: [self name]
                    forKey: @"name"];
      
      if ([self isFlattened])
        {
          NSString *definition = [self definition];
          NSAssert(definition,@"No definition");
          [propertyList setObject: definition
                        forKey: @"definition"];
        }
      else
        {
          [propertyList setObject: ([self isToMany] ? @"Y" : @"N")
                        forKey: @"isToMany"];
          if ([self destinationEntity])
            {
              NSAssert2([[self destinationEntity] name],
                        @"No entity name in relationship named %@ entity named %@",
                        [self name],
                        [[self entity]name]);
              [propertyList setObject: [[self destinationEntity] name] // if we put entity, it loops !!
                            forKey: @"destination"];  
            };
        }
      
      if ([self isMandatory])
      {
        [propertyList setObject: @"Y"
                         forKey: @"isMandatory"];
      }
      
      if ([self ownsDestination])
      {
        [propertyList setObject: @"Y"
                         forKey: @"ownsDestination"];
      }
      
      if ([self propagatesPrimaryKey])
      {
        [propertyList setObject: @"Y"
                         forKey: @"propagatesPrimaryKey"];
      }
      
      {
        int joinsCount = [_joins count];
        
        if (joinsCount > 0)
          {
            NSMutableArray *joinsArray = [NSMutableArray array];
            int i = 0;
            
            for(i = 0; i < joinsCount; i++)
              {
                NSMutableDictionary *joinDict = [NSMutableDictionary dictionary];
                EOJoin *join = [_joins objectAtIndex: i];
                
                NSAssert([[join sourceAttribute] name],
                         @"No source attribute name");

                [joinDict setObject: [[join sourceAttribute] name]
                          forKey: @"sourceAttribute"];

                NSAssert([[join destinationAttribute] name],
                         @"No destination attribute name");
                [joinDict setObject: [[join destinationAttribute] name]
                          forKey: @"destinationAttribute"];

                [joinsArray addObject: joinDict];
              }
            
            [propertyList setObject: joinsArray
                          forKey: @"joins"]; 
          }
        
        NSAssert([self joinSemanticString],
                 @"No joinSemanticString");
        [propertyList setObject: [self joinSemanticString]
                      forKey: @"joinSemantic"];
      }
    }
  NS_HANDLER
    {
      NSLog(@"exception in EORelationship encodeIntoPropertyList: self=%p class=%@",
	    self, [self class]);
      NSDebugMLog(@"exception in EORelationship encodeIntoPropertyList: self=%p class=%@",
	    self, [self class]);
      NSLog(@"exception=%@", localException);
      NSDebugMLog(@"exception=%@", localException);
      [localException raise];
    }
  NS_ENDHANDLER;
}

- (NSString *)description
{
  NSString *dscr = nil;

  NS_DURING //Just for debugging
    {
      dscr = [NSString stringWithFormat: @"<%s %p - name=%@ entity=%@ destinationEntity=%@ definition=%@",
		       object_getClassName(self),
		       (void*)self,
		       [self name],
		       [[self entity]name],
		       [[self destinationEntity] name],
		       [self definition]];

      dscr = [dscr stringByAppendingFormat: @" userInfo=%@",
                   [self userInfo]];
      dscr = [dscr stringByAppendingFormat: @" joinSemantic=%@",
              [[self class] _nameForJoinSemantic:_joinSemantic]];      
      dscr = [dscr stringByAppendingFormat: @" joins=%@",
                   [self joins]];
      dscr = [dscr stringByAppendingFormat: @" sourceAttributes=%@",
                   [self sourceAttributes]];
      dscr = [dscr stringByAppendingFormat: @" destinationAttributes=%@",
                   [self destinationAttributes]];

      /*TODO  dscr = [dscr stringByAppendingFormat:@" componentRelationships=%@",
        [self componentRelationships]];*/

      dscr = [dscr stringByAppendingFormat: @" isCompound=%s isFlattened=%s isToMany=%s isBidirectional=%s>",
		   ([self isCompound] ? "YES" : "NO"),
                   ([self isFlattened] ? "YES" : "NO"),
                   ([self isToMany] ? "YES" : "NO"),
                   ([self isBidirectional] ? "YES" : "NO")];
    }
  NS_HANDLER
    {
      NSLog(@"exception in EORelationship description: self=%p class=%@",
	    self, [self class]);
      NSDebugMLog(@"exception in EORelationship description: self=%p class=%@",
                  self, [self class]);
      NSLog(@"exception=%@", localException);
      NSDebugMLog(@"exception=%@", localException);

      [localException raise];
    }
  NS_ENDHANDLER;

  return dscr;
}

- (NSString *)name
{
  return _name;
}

/** Returns the relationship's source entity. **/
- (EOEntity *)entity
{
  return _entity;
}

/** Returns the relationship's destination entity (direct destination entity or 
destination entity of the last relationship in definition. **/
- (EOEntity *)destinationEntity
{
  //OK
  // May be we could cache destination ? Hard to do because klast relationship may have its destination entity change.
  EOEntity *destinationEntity = _destination;

  if (!destinationEntity)
    {
      if ([self isFlattened])
        {
          EORelationship *lastRelationship = [_definitionArray lastObject];

          destinationEntity = [lastRelationship destinationEntity];

          NSAssert3(destinationEntity, @"No destinationEntity in last relationship: %@ of relationship %@ in entity %@",
                    lastRelationship, self, [_entity name]);
        }
      else
        {
	  [self _joinsChanged];
	  destinationEntity = _destination;
	}
    }
  else if ([destinationEntity isKindOfClass: [NSString class]] == YES)
    destinationEntity = [[_entity model] 
			  entityNamed: (NSString*)destinationEntity];

  return destinationEntity;
}

- (BOOL) isParentRelationship
{
  BOOL isParentRelationship = NO;
  /*EOEntity *destinationEntity = [self destinationEntity];
    EOEntity *parentEntity = [_entity parentEntity];*///nil

  NSEmitTODO();  //TODO
  // [self notImplemented:_cmd]; //TODO...

  return isParentRelationship;
}

/** Returns YES when the relationship traverses at least two entities 
(exemple: aRelationship.anotherRelationship), NO otherwise. 
**/
- (BOOL)isFlattened
{
  if (_definitionArray)
    return [_definitionArray isFlattened];
  else
    return NO;
}

/** return YES if the relation if a to-many one, NO otherwise (please read books 
to know what to-many mean :-)  **/
- (BOOL)isToMany
{
  return _flags.isToMany;
}

/** Returns YES if the relationship have more than 1 join (i.e. join on more that one (sourceAttribute/destinationAttribute), NO otherwise (1 or less join) **/

- (BOOL)isCompound
{
  //OK
  return [_joins count] > 1;
}

- (NSArray *)joins
{
  return _joins;
}

- (NSArray *)sourceAttributes
{
  //OK
  if (!_sourceAttributes)
    {
      int i, count = [_joins count];

      _sourceAttributes = [NSMutableArray new];

      for (i = 0; i < count; i++)
        {
          EOJoin *join = [_joins objectAtIndex: i];
          [(NSMutableArray*)_sourceAttributes addObject:
			      [join sourceAttribute]];
        }
    }

  return _sourceAttributes;
}

- (NSArray *)destinationAttributes
{
  //OK
  if (!_destinationAttributes)
    {
      int i, count = [_joins count];

      _destinationAttributes = [NSMutableArray new];

      for (i = 0; i < count; i++)
        {
          EOJoin *join = [_joins objectAtIndex: i];

          [(NSMutableArray *)_destinationAttributes addObject:
			      [join destinationAttribute]];
        }
    }

  return _destinationAttributes;
}

- (EOJoinSemantic)joinSemantic
{
  return _joinSemantic;
}

/*
 this seems to be GNUstep only -- dw
 */

- (NSString*)joinSemanticString
{  
  return [[self class] _nameForJoinSemantic:[self joinSemantic]];
}

/**
 * Returns the array of relationships composing this flattend relationship.
 * Returns nil of the reciever isn't flattend.
 */
- (NSArray *)componentRelationships
{
  /* FIXME:TODO: Have this method deterimne the components dynamically
   without caching them in the ivar.  Possibly add some tracing code to
   see if caching the values can actually improve performance.
   (Unlikely that it's worth the trouble this may cause for entity
   edititng). */
  if (!_componentRelationships)
    {
      return _definitionArray; //OK ??????
      NSEmitTODO();  //TODO
      [self notImplemented: _cmd]; //TODO
    }

  return _componentRelationships;
}

- (NSDictionary *)userInfo
{
  return _userInfo;
}

- (NSString *)docComment
{
  return _docComment;
}

- (NSString *)definition
{
  //OK
  NSString *definition = nil;

  NS_DURING //Just for debugging
    {
      definition = [_definitionArray valueForSQLExpression: nil];
    }
  NS_HANDLER
    {
      NSLog(@"exception in EORelationship definition: self=%p class=%@",
	    self, [self class]);
      NSLog(@"exception in EORelationship definition: self=%@ _definitionArray=%@",
	    self, _definitionArray);
      NSLog(@"exception=%@", localException);

      [localException raise];
    }
  NS_ENDHANDLER;

  return definition;
}

/** Returns the value to use in an EOSQLExpression. **/
- (NSString*) valueForSQLExpression: (EOSQLExpression*)sqlExpression
{
  return [self name];
}

- (BOOL)referencesProperty: (id)property
{
  if (property == nil)
    return NO;  
  
  if ([self isFlattened])
  {
    return [_definitionArray referencesObject:property];
  }
  
  if (_joins) {
    NSEnumerator  *joinEnumer = [_joins objectEnumerator];
    EOJoin        *join;
    
    while ((join = [joinEnumer nextObject])) {
      if (([join sourceAttribute] == property) || ([join destinationAttribute] == property))
      {
        return YES;
      }
      
    }    
  }
  
  return NO;
}

- (EODeleteRule)deleteRule
{



  return _flags.deleteRule;
}

- (BOOL)isMandatory
{
  return _flags.isMandatory;
}

- (BOOL)propagatesPrimaryKey
{
  return _flags.propagatesPrimaryKey;
}

- (BOOL)isBidirectional
{
  return _flags.isBidirectional;
}

- (BOOL)isReciprocalToRelationship: (EORelationship *)relationship
{
  //Should be OK
  //Ayers: Review
  BOOL isReciprocal = NO;
  EOEntity *entity;
  EOEntity *relationshipDestinationEntity = nil;



  entity = [self entity]; //OK
  relationshipDestinationEntity = [relationship destinationEntity];

  EOFLOGObjectLevelArgs(@"EORelationship", @"entity %p name=%@",
			entity, [entity name]);
  EOFLOGObjectLevelArgs(@"EORelationship",
			@"relationshipDestinationEntity %p name=%@",
			relationshipDestinationEntity,
			[relationshipDestinationEntity name]);

  if (entity == relationshipDestinationEntity) //Test like that ?
    {
      if ([self isFlattened]) //OK
        {
          if ([relationship isFlattened]) //OK
            {
              //Now compare each components in reversed order 
              NSArray *selfComponentRelationships =
		[self componentRelationships];
              NSArray *relationshipComponentRelationships =
		[relationship componentRelationships];
              int selfComponentRelationshipsCount =
		[selfComponentRelationships count];
              int relationshipComponentRelationshipsCount =
		[relationshipComponentRelationships count];

              //May be we can imagine that they may not have the same number of components //TODO
              if (selfComponentRelationshipsCount
		  == relationshipComponentRelationshipsCount) 
                {
                  int i, j;
                  BOOL foundEachInverseComponent = YES;

                  for(i = (selfComponentRelationshipsCount - 1), j = 0;
		      foundEachInverseComponent && i >= 0;
		      i--, j++)
                    {
                      EORelationship *selfRel =
			[selfComponentRelationships objectAtIndex: i];
                      EORelationship *relationshipRel =
			[relationshipComponentRelationships objectAtIndex: j];

                      foundEachInverseComponent =
			[selfRel isReciprocalToRelationship: relationshipRel];
                    }

                  if (foundEachInverseComponent)
                    isReciprocal = YES;
                }
            }
          else
            {
              //Just do nothing and try another relationship.
              // Is it the good way ?
              /*
              NSEmitTODO(); //TODO
              NSDebugMLog(@"entity %p name=%@ self name=%@ relationship name=%@ relationshipDestinationEntity %p name=%@",
                          entity, [entity name],
                          [self name],
                          [relationship name],
                          relationshipDestinationEntity,
                          [relationshipDestinationEntity name]);
              [self notImplemented: _cmd]; //TODO
              */
            }
        }
      else
        {
          //WO doens't test inverses entity 
          EOEntity *relationshipEntity = [relationship entity];
          EOEntity *destinationEntity = [self destinationEntity];

          EOFLOGObjectLevelArgs(@"EORelationship",
				@"relationshipEntity %p name=%@",
				relationshipEntity, [relationshipEntity name]);
          EOFLOGObjectLevelArgs(@"EORelationship",
				@"destinationEntity %p name=%@",
				destinationEntity, [destinationEntity name]);

          if (relationshipEntity == destinationEntity)
            {
              NSArray *joins = [self joins];
              NSArray *relationshipJoins = [relationship joins];
              int joinsCount = [joins count];
              int relationshipJoinsCount = [relationshipJoins count];

              EOFLOGObjectLevelArgs(@"EORelationship",
				    @"joinsCount=%d,relationshipJoinsCount=%d",
				    joinsCount, relationshipJoinsCount);

              if (joinsCount == relationshipJoinsCount)
                {
                  BOOL foundEachInverseJoin = YES;
                  int iJoin;

                  for (iJoin = 0;
		       foundEachInverseJoin && iJoin < joinsCount;
		       iJoin++)
                    {                  
                      EOJoin *join = [joins objectAtIndex: iJoin];
                      int iRelationshipJoin;
                      BOOL foundInverseJoin = NO;

                      EOFLOGObjectLevelArgs(@"EORelationship", @"%d join=%@",
					    iJoin, join);

                      for (iRelationshipJoin = 0;
			   !foundInverseJoin && iRelationshipJoin < joinsCount;
			   iRelationshipJoin++)
                        {
                          EOJoin *relationshipJoin =
			    [relationshipJoins objectAtIndex:iRelationshipJoin];

                          EOFLOGObjectLevelArgs(@"EORelationship",
						@"%d relationshipJoin=%@",
						iRelationshipJoin,
						relationshipJoin);

                          foundInverseJoin = [relationshipJoin
					       isReciprocalToJoin: join];

                          EOFLOGObjectLevelArgs(@"EORelationship",
						@"%d foundInverseJoin=%s",
						iRelationshipJoin,
						(foundInverseJoin ? "YES" : "NO"));
                        }

                      if (!foundInverseJoin)
                        foundEachInverseJoin = NO;

                      EOFLOGObjectLevelArgs(@"EORelationship",
					    @"%d foundEachInverseJoin=%s",
					    iJoin,
					    (foundEachInverseJoin ? "YES" : "NO"));
                    }

                  EOFLOGObjectLevelArgs(@"EORelationship",
					@"foundEachInverseJoin=%s",
					(foundEachInverseJoin ? "YES" : "NO"));

                  if (foundEachInverseJoin)
                    isReciprocal = YES;
                }
            }
        }
    }



  return isReciprocal;
}

/** "Search only already created inverse relationship in destination entity 
relationships. Nil if none" **/
- (EORelationship *)inverseRelationship
{
  //OK


  if (!_inverseRelationship)
    {
      EOEntity *destinationEntity;
      NSArray *destinationEntityRelationships;

      destinationEntity = [self destinationEntity];
      NSDebugLog(@"destinationEntity name=%@", [destinationEntity name]);

      destinationEntityRelationships = [destinationEntity relationships];

      NSDebugLog(@"destinationEntityRelationships=%@",
		 destinationEntityRelationships);

      if ([destinationEntityRelationships count] > 0)
        {
          int i, count = [destinationEntityRelationships count];

          for (i = 0; !_inverseRelationship && i < count; i++)
            {
              EORelationship *testRelationship =
		[destinationEntityRelationships objectAtIndex: i];

              NSDebugLog(@"testRelationship=%@", testRelationship);

              if ([self isReciprocalToRelationship: testRelationship])
                {
                  ASSIGN(_inverseRelationship, testRelationship);
                }
            }
        }

      NSDebugLog(@"_inverseRelationship=%@", _inverseRelationship);
    }



  return _inverseRelationship;
}

- (EORelationship *) _makeFlattenedInverseRelationship
{
  //OK
  EORelationship *inverseRelationship = nil;
  NSMutableString *invDefinition = nil;
  NSString *name = nil;
  int i, count;



  NSAssert([self isFlattened], @"Not Flatten Relationship");
  EOFLOGObjectLevel(@"EORelationship", @"add joins");

  count = [_definitionArray count];

  for (i = count - 1; i >= 0; i--)
    {
      EORelationship *rel = [_definitionArray objectAtIndex: i];
      EORelationship *invRel = [rel anyInverseRelationship];
      NSString *invRelName = [invRel name];

      if (invDefinition)
        {
          if (i < (count - 1))
            [invDefinition appendString: @"."];

	  [invDefinition appendString: invRelName];
        }
      else
        invDefinition = [NSMutableString stringWithString: invRelName];
    }

  inverseRelationship = [[EORelationship new] autorelease];
  [inverseRelationship setEntity: [self destinationEntity]];

  name = [NSString stringWithFormat: @"_eofInv_%@_%@",
		   [_entity name],
		   _name];
  [inverseRelationship setName: name]; 
  [inverseRelationship setDefinition: invDefinition]; 

  EOFLOGObjectLevel(@"EORelationship", @"add inverse rel");

  [(NSMutableArray*)[[self destinationEntity] _hiddenRelationships]
		    addObject: inverseRelationship]; //not very clean !!!
  EOFLOGObjectLevel(@"EORelationship", @"set inverse rel");

  [inverseRelationship _setInverseRelationship: self];



  return inverseRelationship;
}

- (EORelationship*) _makeInverseRelationship
{
  //OK
  EORelationship *inverseRelationship;
  NSString *name;
  NSArray *joins = nil;
  unsigned int i, count;



  NSAssert(![self isFlattened], @"Flatten Relationship");

  inverseRelationship = [[EORelationship new] autorelease];

  name = [NSString stringWithFormat: @"_eofInv_%@_%@",
		   [_entity name],
		   _name];
  [inverseRelationship setName: name]; 

  joins = [self joins];
  count = [joins count];

  EOFLOGObjectLevel(@"EORelationship", @"add joins");

  for (i = 0; i < count; i++)
    {
      EOJoin *join = [joins objectAtIndex: i];
      EOAttribute *sourceAttribute = [join sourceAttribute];
      EOAttribute *destinationAttribute = [join destinationAttribute];
      EOJoin *inverseJoin = [EOJoin joinWithSourceAttribute:
				      destinationAttribute //inverse souce<->destination attributes
				    destinationAttribute: sourceAttribute];

      [inverseRelationship addJoin: inverseJoin];
    }

  EOFLOGObjectLevel(@"EORelationship",@"add inverse rel");

  [(NSMutableArray*)[[self destinationEntity] _hiddenRelationships]
		    addObject: inverseRelationship]; //not very clean !!!

  EOFLOGObjectLevel(@"EORelationship", @"set inverse rel");

  [inverseRelationship _setInverseRelationship: self];

  /* call this last to avoid calls to [_destination _setIsEdited] */
  [inverseRelationship setEntity: _destination];


  return inverseRelationship;
}

- (EORelationship*) hiddenInverseRelationship
{
  //OK


  if (!_hiddenInverseRelationship)
    {
      if ([self isFlattened]) 
        _hiddenInverseRelationship = [self _makeFlattenedInverseRelationship];
      else
        _hiddenInverseRelationship = [self _makeInverseRelationship];
    }



  return _hiddenInverseRelationship;
}

- (EORelationship *)anyInverseRelationship
{
  //OK
  EORelationship *inverseRelationship = [self inverseRelationship];

  if (!inverseRelationship)
      inverseRelationship = [self hiddenInverseRelationship];

  return inverseRelationship;
}

- (unsigned int)numberOfToManyFaultsToBatchFetch
{
  return _batchCount;
}

- (BOOL)ownsDestination
{
  return _flags.ownsDestination;
}

- (EOQualifier *)qualifierWithSourceRow: (NSDictionary *)sourceRow
{
  [self notImplemented: _cmd];//TODO
  return nil;
}

@end /* EORelationship */


@implementation EORelationship (EORelationshipEditing)

- (NSException *)validateName: (NSString *)name
{
  //Seems OK
  const char *p, *s = [name cString];
  int exc = 0;
  NSArray *storedProcedures = nil;

  if ([_name isEqual:name]) return nil;
  if (!name || ![name length])
    exc++;
  if (!exc)
    {
      p = s;
      while (*p)
        {
          if(!isalnum(*p) &&
             *p != '@' && *p != '#' && *p != '_' && *p != '$')
            {
              exc++;
              break;
            }
          p++;
        }
      if (!exc && *s == '$')
        exc++;
  
    if (exc)
      return [NSException exceptionWithName: NSInvalidArgumentException
                         reason: [NSString stringWithFormat: @"%@ -- %@ 0x%x: argument \"%@\" contains invalid char '%c'", 
					  NSStringFromSelector(_cmd),
					  NSStringFromClass([self class]),
					  self,
                                         name,
					 *p]
                        userInfo: nil];
      
      if ([[self entity] _hasAttributeNamed: name])
        exc++;
      else if ([[self entity] anyRelationshipNamed: name])
        exc++;
      else if ((storedProcedures = [[[self entity] model] storedProcedures]))
        {
          NSEnumerator *stEnum = [storedProcedures objectEnumerator];
          EOStoredProcedure *st;
          
          while ((st = [stEnum nextObject]))
            {
              NSEnumerator *attrEnum;
              EOAttribute  *attr;
              
              attrEnum = [[st arguments] objectEnumerator];
              while ((attr = [attrEnum nextObject]))
                {
                  if ([name isEqualToString: [attr name]])
                    {
                      exc++;
                      break;
                    }
                }
                if (exc)
                  break;
            }
        }
    }

  if (exc)
    {
      return [NSException exceptionWithName: NSInvalidArgumentException
                         reason: [NSString stringWithFormat: @"%@ -- %@ 0x%x: \"%@\" already used in the model",
                                 NSStringFromSelector(_cmd),
                                 NSStringFromClass([self class]),
                                 self,
                                 name]
                        userInfo: nil];
    }

  return nil;
}

- (void)setToMany: (BOOL)flag
{
  //OK
  if ([self isFlattened])
    [NSException raise: NSInvalidArgumentException
                 format: @"%@ -- %@ 0x%x: receiver is a flattened relationship",
                 NSStringFromSelector(_cmd),
                 NSStringFromClass([self class]),
                 self];

  if (_flags.isToMany != flag)
    {
      [self willChange];
      [_entity _setIsEdited];
      _flags.isToMany = flag;
    }
}

- (void)setName: (NSString *)name
{
  //OK
  [[self validateName: name] raise];
  [self willChange];
  [_entity _setIsEdited];

  ASSIGNCOPY(_name, name);
}

- (void)setDefinition: (NSString *)definition
{
  //Near OK


  EOFLOGObjectLevelArgs(@"EORelationship", @"definition=%@", definition);

  [self _flushCache];
  [self willChange];

  if (definition)
    {
      _flags.isToMany = NO;

      NSAssert1(_entity,@"No entity for relationship %@",
                self);

      ASSIGN(_definitionArray, [_entity _parseRelationshipPath: definition]);

      EOFLOGObjectLevelArgs(@"EORelationship", @"_definitionArray=%@", _definitionArray);
      EOFLOGObjectLevelArgs(@"EORelationship", @"[self definition]=%@", [self definition]);

      _destination = nil;

      {        
        //TODO VERIFY
        //TODO better ?
        int i, count = [_definitionArray count];

        EOFLOGObjectLevelArgs(@"EORelationship", @"==> _definitionArray=%@",
			      _definitionArray);

        for (i = 0; !_flags.isToMany && i < count; i++)
          {
            EORelationship *rel = [_definitionArray objectAtIndex: i];

            if ([rel isKindOfClass: [EORelationship class]])
              {
                if ([rel isToMany])
                  _flags.isToMany = YES;
            }
          else
            break;
        }
      }

    }
  else /* definition == nil */
    {
      DESTROY(_definitionArray);
    }
  /* Ayers: Not sure what justifies this. */
  [_entity _setIsEdited];


}

/**
 * <p>Sets the entity of the reciever.</p>
 * <p>If the receiver already has an entity assigned to it the old relationship
 * will will be removed first.</p>
 * <p>This method is used by [EOEntity-addRelationship:] and
 * [EOEntity-removeRelationship:] which should be used for general relationship
 * manipulations.  This method should only be useful
 * when creating flattend relationships programmatically.</p>
 */
- (void)setEntity: (EOEntity *)entity
{
  //OK
  if (entity != _entity)
    {
      [self _flushCache];
      [self willChange];

      if (_entity)
	{
	  NSString *relationshipName;
	  EORelationship *relationship;

	  /* Check if we are still in the entities arrays to
	     avoid recursive loop when removeRelationship:
	     calls this method.  */
	  relationshipName = [self name];
	  relationship = [_entity relationshipNamed: relationshipName];
          if (self == relationship)
	    {
	      [_entity removeRelationship: self];
	    }
	}
      _entity = entity;
    }
  /* This method is used by EOEntity's remove/addRelatinship: and is not
     responsible for calling _setIsEdited on the entity.  */
}

- (void)setUserInfo: (NSDictionary *)dictionary
{
  //OK
  [self willChange];
  ASSIGN(_userInfo, dictionary);
  /* Ayers: Not sure what justifies this. */
  [_entity _setIsEdited];
}

- (void)setInternalInfo: (NSDictionary *)dictionary
{
  //OK
  [self willChange];
  ASSIGN(_internalInfo, dictionary);
  /* Ayers: Not sure what justifies this. */
  [_entity _setIsEdited];
}

- (void)setDocComment: (NSString *)docComment
{
  //OK
  [self willChange];
  ASSIGNCOPY(_docComment, docComment);
  /* Ayers: Not sure what justifies this. */
  [_entity _setIsEdited];
}

- (void)setPropagatesPrimaryKey: (BOOL)flag
{
  //OK
  if (_flags.propagatesPrimaryKey != flag)
    [self willChange];

  _flags.propagatesPrimaryKey = flag;
}

- (void)setIsBidirectional: (BOOL)flag
{
  //OK
  if (_flags.isBidirectional != flag)
    [self willChange];

  _flags.isBidirectional = flag;
}

- (void)setOwnsDestination: (BOOL)flag
{
  if (_flags.ownsDestination != flag)
    [self willChange];

  _flags.ownsDestination = flag;
}

- (void)addJoin: (EOJoin *)join
{
  EOAttribute *sourceAttribute = nil;
  EOAttribute *destinationAttribute = nil;
  

  
  EOFLOGObjectLevelArgs(@"EORelationship", @"Add join: %@\nto %@", join, self);
  
  if ([self isFlattened] == YES)
    [NSException raise: NSInvalidArgumentException
                format: @"%@ -- %@ 0x%x: receiver is a flattened relationship",
     NSStringFromSelector(_cmd),
     NSStringFromClass([self class]),
     self];
  else
  {
    EOEntity *destinationEntity = [self destinationEntity];
    EOEntity *sourceEntity = [self entity];
    
    EOFLOGObjectLevelArgs(@"EORelationship", @"destinationEntity=%@", destinationEntity);
    
    if (!destinationEntity)
    {
#warning checkme: do we need this? -- dw
      //NSEmitTODO(); //TODO
      //EOFLOGObjectLevelArgs(@"EORelationship", @"self=%@", self);
      //TODO ??
    };
    
    sourceAttribute = [join sourceAttribute];
    
    NSAssert3(sourceAttribute, @"No source attribute in join %@ in relationship %@ of entity %@",
              join,
              self,
              sourceEntity);
    
    destinationAttribute = [join destinationAttribute];
    
    NSAssert3(destinationAttribute, @"No destination attribute in join %@ in relationship %@ of entity %@",                
              join,
              self,
              sourceEntity);
    
    if ([sourceAttribute isFlattened] == YES
        || [destinationAttribute isFlattened] == YES)
      [NSException raise: NSInvalidArgumentException
                  format: @"%@ -- %@ 0x%x: join's attributes are flattened",
       NSStringFromSelector(_cmd),
       NSStringFromClass([self class]),
       self];
    else
    {
      EOEntity *joinDestinationEntity = [destinationAttribute entity];
      EOEntity *joinSourceEntity = [sourceAttribute entity];
      
      /*          if (destinationEntity && ![[destinationEntity name] isEqual:[joinSourceEntity name]])
       {
       [NSException raise:NSInvalidArgumentException
       format:@"%@ -- %@ 0x%x: join source entity (%@) is not equal to last join entity (%@)",
       NSStringFromSelector(_cmd),
       NSStringFromClass([self class]),
       self,
       [joinSourceEntity name],
       [destinationEntity name]];
       }*/
      
      if (sourceEntity
          && ![[joinSourceEntity name] isEqual: [sourceEntity name]])
        [NSException raise: NSInvalidArgumentException
                    format: @"%@ -- %@ 0x%x (%@): join source entity (%@) is not equal to relationship entity (%@)",
         NSStringFromSelector(_cmd),
         NSStringFromClass([self class]),
         self,
         [self name],
         [joinSourceEntity name],
         [sourceEntity name]];
      else if (destinationEntity
               && ![[joinDestinationEntity name]
                    isEqual: [destinationEntity name]])
        [NSException raise: NSInvalidArgumentException
                    format: @"%@ -- %@ 0x%x (%@): join destination entity (%@) is not equal to relationship destination entity (%@)",
         NSStringFromSelector(_cmd),
         NSStringFromClass([self class]),
         self,
         [self name],
         [joinDestinationEntity name],
         [destinationEntity name]];
      else
      {
        if ([_sourceAttributes count])
        {
          EOAttribute *sourceAttribute = [join sourceAttribute];
          EOAttribute *destinationAttribute;
          
          destinationAttribute = [join destinationAttribute];
          
          if (([_sourceAttributes indexOfObject: sourceAttribute]
               != NSNotFound)
              && ([_destinationAttributes
                   indexOfObject: destinationAttribute]
                  != NSNotFound))
            [NSException raise: NSInvalidArgumentException
                        format: @"%@ -- %@ 0x%x: TODO",
             NSStringFromSelector(_cmd),
             NSStringFromClass([self class]),
             self];
        }
        
        [self _flushCache];
        // do we still need willChange when we are not putting EORelationships into ECs? -- dw
        [self willChange];
        // needed for KV bbserving
        [self willChangeValueForKey:@"joins"];
        
        EOFLOGObjectLevel(@"EORelationship", @"really add");
        EOFLOGObjectLevelArgs(@"EORelationship", @"XXjoins %p class%@",
                              _joins, [_joins class]);
        
        if (!_joins)
          _joins = [NSMutableArray new];
        
        [(NSMutableArray *)_joins addObject: join];      
        
        EOFLOGObjectLevelArgs(@"EORelationship", @"XXjoins %p class%@",
                              _joins, [_joins class]);
        
        EOFLOGObjectLevel(@"EORelationship", @"added");
        
        [self _joinsChanged];
        [self didChangeValueForKey:@"joins"];

        /* Ayers: Not sure what justifies this. */
        [_entity _setIsEdited];
      }
    }
  }
  

}

- (void)removeJoin: (EOJoin *)join
{


  [self _flushCache];

  if ([self isFlattened] == YES)
    [NSException raise: NSInvalidArgumentException
                 format: @"%@ -- %@ 0x%x: receiver is a flattened relationship",
                 NSStringFromSelector(_cmd),
                 NSStringFromClass([self class]),
                 self];
  else
    {
      [self willChangeValueForKey:@"joins"];

      [self willChange];
      [(NSMutableArray *)_joins removeObject: join];

          /*NO: will be recomputed      [(NSMutableArray *)_sourceAttributes
            removeObject:[join sourceAttribute]];
            [(NSMutableArray *)_destinationAttributes
            removeObject:[join destinationAttribute]];
          */

      EOFLOGObjectLevelArgs(@"EORelationship", @"XXjoins %p class%@",
		       _joins, [_joins class]);

      [self _joinsChanged];

      /* Ayers: Not sure what justifies this. */
      [_entity _setIsEdited];
      [self didChangeValueForKey:@"joins"];
    }


}

- (void)setJoinSemantic: (EOJoinSemantic)joinSemantic
{
  //OK
  [self willChange];
  _joinSemantic = joinSemantic;
}

- (void)beautifyName
{
  /*+ Make the name conform to the Next naming style
    NAME -> name, FIRST_NAME -> firstName +*/
  NSArray  *listItems;
  NSString *newString = [NSString string];
  int	    anz, i;

  EOFLOGObjectFnStartOrCond2(@"ModelingClasses", @"EORelationship");
  
  /* Makes the receiver's name conform to a standard convention. Names that 
conform to this style are all lower-case except for the initial letter of 
each embedded word other than the first, which is upper case. Thus, "NAME" 
becomes "name", and "FIRST_NAME" becomes "firstName".*/
  
  if ((_name) && ([_name length] > 0))
    {
      listItems = [_name componentsSeparatedByString: @"_"];
      newString = [newString stringByAppendingString:
			       [[listItems objectAtIndex: 0] lowercaseString]];
      anz = [listItems count];

      for (i = 1; i < anz; i++)
	{
	  newString = [newString stringByAppendingString:
				   [[listItems objectAtIndex: i]
				     capitalizedString]];
	}

    // Exception abfangen
    NS_DURING
      {
        [self setName:newString];
      }
    NS_HANDLER
      {
        NSLog(@"%@ in Class: EORlationship , Method: beautifyName >> error : %@",
	      [localException name], [localException reason]);
      }
    NS_ENDHANDLER;
  }
  
  EOFLOGObjectFnStopOrCond2(@"ModelingClasses", @"EORelationship");
}

- (void)setNumberOfToManyFaultsToBatchFetch: (unsigned int)size
{
  [self willChange];
  _batchCount = size;
}

- (void)setDeleteRule: (EODeleteRule)deleteRule
{
  NSAssert1(deleteRule >= 0 && deleteRule <= 3,
	    @"Bad deleteRule numeric value: %d",
            deleteRule);

  [self willChange];
  _flags.deleteRule = deleteRule;
}

- (void)setIsMandatory: (BOOL)isMandatory
{
  //OK
  [self willChange];
  _flags.isMandatory = isMandatory;
}

@end

@implementation EORelationship (EORelationshipValueMapping)

/**
 * If the reciever is a manditory relationship, this method
 * returns an exception if the value pointed to by VALUEP is
 * either nil or the EONull instance for to-one relationships
 * or an empty NSArray for to-many relationships.  Otherwise
 * it returns nil.  EOClassDescription adds further information
 * to this exception before it gets passed to the application or
 * user.
 */
- (NSException *)validateValue: (id*)valueP
{
  //OK
  NSException *exception = nil;



  NSAssert(valueP, @"No value pointer");

  if ([self isMandatory])
    {
      BOOL isToMany = [self isToMany];

      if ((isToMany == NO && _isNilOrEONull(*valueP))
	  || (isToMany == YES && [*valueP count] == 0))
        {
          EOEntity *destinationEntity = [self destinationEntity];
          EOEntity *entity = [self entity];

          exception = [NSException validationExceptionWithFormat:
				     @"The %@ property of %@ must have a %@ assigned",
				   [self name],
				   [entity name],
				   [destinationEntity name]];
        }
    }



  return exception;
}

@end

@implementation EORelationship (EORelationshipPrivate)

/*
  This method is private to GDL2 to allow the inverse relationship
  to be set from the original relationship.  It exists to avoid the
  ASSIGN(inverseRelationship->_inverseRelationship, self);
  and to insure that associations will be updated if we ever display
  inverse relationships in DBModeler.
*/
- (void)_setInverseRelationship: (EORelationship*)relationship
{
  [self willChange];
  ASSIGN(_inverseRelationship,relationship);
}

@end

@implementation EORelationship (EORelationshipXX)

- (NSArray*) _intermediateAttributes
{
  //Verify !!
  NSMutableArray *intermediateAttributes;
  EORelationship *rel;
  NSArray *joins;

  //all this works on flattened and non flattened relationship.
  intermediateAttributes = [NSMutableArray array];
  rel = [self firstRelationship];
  joins = [rel joins];
  //??
  [intermediateAttributes addObjectsFromArray:
			    [joins resultsOfPerformingSelector:
				     @selector(destinationAttribute)]];

  rel = [self lastRelationship];
  joins = [rel joins];
  //  attribute = [joins sourceAttribute];
  //??
  [intermediateAttributes addObjectsFromArray:
			    [joins resultsOfPerformingSelector:
				     @selector(sourceAttribute)]];

  return [NSArray arrayWithArray: intermediateAttributes];
}

/** Return the last relationship if self is flattened, self otherwise.
**/
- (EORelationship*) lastRelationship
{
  EORelationship *lastRel;

  if ([self isFlattened])
    {
      NSAssert(!_definitionArray || [_definitionArray count] > 0,
               @"Definition array is empty");

      lastRel = [[self _definitionArray] lastObject];
    }
  else
    lastRel = self;

  return lastRel;
}

/** Return the 1st relationship if self is flattened, self otherwise.
**/
- (EORelationship*) firstRelationship
{
  EORelationship *firstRel;

  if ([self isFlattened])
    {
      NSAssert(!_definitionArray || [_definitionArray count] > 0,
               @"Definition array is empty");

      firstRel = [[self _definitionArray] objectAtIndex: 0];
    }
  else
    firstRel = self;

  return firstRel;
}

- (EOEntity*) intermediateEntity
{
  //TODO verify
  id intermediateEntity = nil;

  if ([self isToManyToOne])
    {
      int i, count = [_definitionArray count];

      for (i = (count - 1); !intermediateEntity && i >= 0; i--)
        {
          EORelationship *rel = [_definitionArray objectAtIndex: i];

          if ([rel isToMany])
            intermediateEntity = [rel destinationEntity];
        }
    }

  return intermediateEntity;
}

- (BOOL) isMultiHop
{
  //TODO verify
  BOOL isMultiHop = NO;

  if ([self isFlattened])
    {
      isMultiHop = YES;
    }

  return isMultiHop;
}

- (void) _setSourceToDestinationKeyMap: (id)param0
{
  [self notImplemented: _cmd]; // TODO
}

- (id) qualifierForDBSnapshot: (id)param0
{
  return [self notImplemented: _cmd]; // TODO
}

- (id) primaryKeyForTargetRowFromSourceDBSnapshot: (id)param0
{
  return [self notImplemented:_cmd]; // TODO
}

/** Return relationship path (like toRel1.toRel2) if self is flattened, slef name otherwise.
**/
- (NSString*)relationshipPath
{
  //Seems OK
  NSString *relationshipPath = nil;



  if ([self isFlattened])
    {
      int i, count = [_definitionArray count];

      for (i = 0; i < count; i++)
        {
          EORelationship *relationship = [_definitionArray objectAtIndex: i];
          NSString *relationshipName = [relationship name];

          if (relationshipPath)
            [(NSMutableString*)relationshipPath appendString: @"."];
          else
            relationshipPath = [NSMutableString string];

          [(NSMutableString*)relationshipPath appendString: relationshipName];
        }
    }
  else
    relationshipPath = [self name];



  return relationshipPath;
}

-(BOOL)isToManyToOne
{
  BOOL isToManyToOne = NO;



  if ([self isFlattened])
    {
      BOOL isToMany = YES;
      int count = [_definitionArray count];

      if (count >= 2)
        {
          EORelationship *firstRelationship = [_definitionArray
						objectAtIndex: 0];

          isToMany = [firstRelationship isToMany];

          if (!isToMany)
            {
              if ([firstRelationship isParentRelationship])
                {
                  NSEmitTODO();  //TODO
                  EOFLOGObjectLevelArgs(@"EORelationship", @"self=%@", self);
                  EOFLOGObjectLevelArgs(@"EORelationship", @"firstRelationship=%@",
			       firstRelationship);

                  [self notImplemented: _cmd]; //TODO
                }
            }

          if (isToMany)
            {
              EORelationship *secondRelationship = [_definitionArray
						     objectAtIndex: 1];

              if (![secondRelationship isToMany])
                {
                  EORelationship *invRel = [secondRelationship
					     anyInverseRelationship];

                  if (invRel)
                    secondRelationship = invRel;

                  isToManyToOne = YES;

                  if ([secondRelationship isParentRelationship])
                    {
                      NSEmitTODO();  //TODO
                      EOFLOGObjectLevelArgs(@"EORelationship", @"self=%@", self);
                      EOFLOGObjectLevelArgs(@"EORelationship", @"secondRelationship=%@",
				   secondRelationship);

                      [self notImplemented: _cmd]; //TODO
                    }
                }
            }
        }
    }



  return isToManyToOne;
}

-(NSDictionary*)_sourceToDestinationKeyMap
{
  //OK


  if (!_sourceToDestinationKeyMap)
    {
      NSString *relationshipPath = [self relationshipPath];

      ASSIGN(_sourceToDestinationKeyMap,
	     [_entity _keyMapForRelationshipPath: relationshipPath]);
    }



  return _sourceToDestinationKeyMap;
}

- (BOOL)foreignKeyInDestination
{
  NSArray *destAttributes = nil;
  NSArray *primaryKeyAttributes = nil;
  NSUInteger destAttributesCount = 0;
  NSUInteger primaryKeyAttributesCount = 0;
  BOOL foreignKeyInDestination = NO;



  destAttributes = [self destinationAttributes];
  primaryKeyAttributes = [[self destinationEntity] primaryKeyAttributes];

  destAttributesCount = [destAttributes count];
  primaryKeyAttributesCount = [primaryKeyAttributes count];

  EOFLOGObjectLevelArgs(@"EORelationship", @"destAttributes=%@",
			destAttributes);
  EOFLOGObjectLevelArgs(@"EORelationship", @"primaryKeyAttributes=%@",
			primaryKeyAttributes);

  if (destAttributesCount > 0 && primaryKeyAttributesCount > 0)
    {
      NSUInteger i;

      for (i = 0;
	   !foreignKeyInDestination && i < destAttributesCount;
	   i++)
	{
	  EOAttribute *attribute = [destAttributes objectAtIndex: i];
	  NSUInteger pkAttrIndex = [primaryKeyAttributes
			      indexOfObjectIdenticalTo: attribute];

	  foreignKeyInDestination = (pkAttrIndex == NSNotFound);
	}
    }



  EOFLOGObjectLevelArgs(@"EORelationship", @"foreignKeyInDestination=%s",
			(foreignKeyInDestination ? "YES" : "NO"));

  return foreignKeyInDestination;
}

@end

@implementation EORelationship (EORelationshipPrivate2)

- (BOOL) isPropagatesPrimaryKeyPossible
{
/*
  NSArray* joins=[self joins];
  NSArray* joinsSourceAttributes=[joins resultsOfPerformingSelector:@selector(sourceAttribute)];
  NSArray* joinsDestinationAttributes=[joins resultsOfPerformingSelector:@selector(destinationAttribute)];

joinsSourceAttributes names
sortedArrayUsingSelector:compare:

result count

joinsDestinationAttributes names
sortedArrayUsingSelector:compare:
inverseRelationship
inv entity [EOEntity]:
inv ventity primaryKeyAttributeNames
count
dest entity
dst entity primaryKeyAttributeNames 

*/


  [self notImplemented: _cmd]; // TODO



  return NO;
};

- (id) qualifierOmittingAuxiliaryQualifierWithSourceRow: (id)param0
{
  return [self notImplemented: _cmd]; // TODO
}

- (id) auxiliaryQualifier
{
  return nil; //[self notImplemented:_cmd]; // TODO
}

- (void) setAuxiliaryQualifier: (id)param0
{
  [self notImplemented:_cmd]; // TODO
}

/** Return dictionary of key/value for destination object of source row/object **/
- (EOMutableKnownKeyDictionary *) _foreignKeyForSourceRow: (NSDictionary*)row
{
  EOMutableKnownKeyDictionary *foreignKey = nil;
  EOMKKDSubsetMapping *sourceRowToForeignKeyMapping = nil;



  sourceRowToForeignKeyMapping = [self _sourceRowToForeignKeyMapping];

  EOFLOGObjectLevelArgs(@"EORelationship", @"self=%@",self);
  EOFLOGObjectLevelArgs(@"EORelationship", @"sourceRowToForeignKeyMapping=%@",
	       sourceRowToForeignKeyMapping);

  foreignKey = [EOMutableKnownKeyDictionary dictionaryFromDictionary: row
					    subsetMapping:
					      sourceRowToForeignKeyMapping];

  EOFLOGObjectLevelArgs(@"EORelationship", @"row=%@\nforeignKey=%@", row, foreignKey);



  return foreignKey;
}

- (EOMKKDSubsetMapping*) _sourceRowToForeignKeyMapping
{


  if (!_sourceRowToForeignKeyMapping)
    {
      NSDictionary *sourceToDestinationKeyMap;
      NSArray *sourceKeys;
      NSArray *destinationKeys;
      EOEntity *destinationEntity;
      EOMKKDInitializer *destinationDictionaryInitializer = nil;
      EOMKKDInitializer *adaptorDictionaryInitializer;
      EOMKKDSubsetMapping *sourceRowToForeignKeyMapping;

      sourceToDestinationKeyMap = [self _sourceToDestinationKeyMap];

      EOFLOGObjectLevelArgs(@"EORelationship", @"rel=%@ sourceToDestinationKeyMap=%@",
		   [self name], sourceToDestinationKeyMap);

      sourceKeys = [sourceToDestinationKeyMap objectForKey: @"sourceKeys"];
      EOFLOGObjectLevelArgs(@"EORelationship", @"rel=%@ sourceKeys=%@",
                            [self name], sourceKeys);

      destinationKeys = [sourceToDestinationKeyMap
			  objectForKey: @"destinationKeys"];
      EOFLOGObjectLevelArgs(@"EORelationship", @"rel=%@ destinationKeys=%@",
                            [self name], destinationKeys);

      destinationEntity = [self destinationEntity];

      destinationDictionaryInitializer = [destinationEntity _adaptorDictionaryInitializer];

      EOFLOGObjectLevelArgs(@"EORelationship", @"destinationEntity named %@  primaryKeyDictionaryInitializer=%@",
		   [destinationEntity name],
		   destinationDictionaryInitializer);

      adaptorDictionaryInitializer = [_entity _adaptorDictionaryInitializer];
      EOFLOGObjectLevelArgs(@"EORelationship",@"entity named %@ adaptorDictionaryInitializer=%@",
                  [_entity name],
                  adaptorDictionaryInitializer);

      sourceRowToForeignKeyMapping = 
      [destinationDictionaryInitializer subsetMappingForSourceDictionaryInitializer: adaptorDictionaryInitializer
                                                                         sourceKeys: sourceKeys
                                                                    destinationKeys: destinationKeys];
      
      ASSIGN(_sourceRowToForeignKeyMapping, sourceRowToForeignKeyMapping);

      EOFLOGObjectLevelArgs(@"EORelationship",@"%@ to %@: _sourceRowToForeignKeyMapping=%@",
		   [_entity name],
		   [destinationEntity name],
		   _sourceRowToForeignKeyMapping);
    }



  return _sourceRowToForeignKeyMapping;
}

- (NSArray*) _sourceAttributeNames
{
  //Seems OK
  return [[self sourceAttributes]
	   resultsOfPerformingSelector: @selector(name)];
}

- (EOJoin*) joinForAttribute: (EOAttribute*)attribute
{
  //OK
  EOJoin *join = nil;
  int i, count = [_joins count];

  for (i = 0; !join && i < count; i++)
    {
      EOJoin *aJoin = [_joins objectAtIndex: i];
      EOAttribute *sourceAttribute = [aJoin sourceAttribute];

      if ([attribute isEqual: sourceAttribute])
        join = aJoin;
    }

  return join;
}

- (void) _flushCache
{
  //VERIFY
  //[self notImplemented:_cmd]; // TODO
  DESTROY(_sourceAttributes);
  DESTROY(_destinationAttributes);
  DESTROY(_inverseRelationship);
  DESTROY(_hiddenInverseRelationship);
  DESTROY(_componentRelationships);
  _destination = nil;

}

- (EOExpressionArray*) _definitionArray
{
  return _definitionArray;
}

- (NSString*) _stringFromDeleteRule: (EODeleteRule)deleteRule
{
  NSString *deleteRuleString = nil;

  switch(deleteRule)
    {
    case EODeleteRuleNullify:
      deleteRuleString = @"";
      break;
    case EODeleteRuleCascade:
      deleteRuleString = @"";
      break;
    case EODeleteRuleDeny:
      deleteRuleString = @"";
      break;
    case EODeleteRuleNoAction:
      deleteRuleString = @"";
      break;
    default:
      [NSException raise: NSInvalidArgumentException
                   format: @"%@ -- %@ 0x%x: invalid deleteRule code for relationship '%@': %d", 
                   NSStringFromSelector(_cmd), 
                   NSStringFromClass([self class]), 
                   self, 
                   [self name], 
                   (int)deleteRule];
      break;
    }

  return deleteRuleString;
}

- (EODeleteRule) _deleteRuleFromString: (NSString*)deleteRuleString
{
  EODeleteRule deleteRule = 0;

  if ([deleteRuleString isEqualToString: @"EODeleteRuleNullify"])
    deleteRule = EODeleteRuleNullify;
  else if ([deleteRuleString isEqualToString: @"EODeleteRuleCascade"])
    deleteRule = EODeleteRuleCascade;
  else if ([deleteRuleString isEqualToString: @"EODeleteRuleDeny"])
    deleteRule = EODeleteRuleDeny;
  else if ([deleteRuleString isEqualToString: @"EODeleteRuleNoAction"])
    deleteRule = EODeleteRuleNoAction;
  else 
    [NSException raise: NSInvalidArgumentException
                 format: @"%@ -- %@ 0x%x: invalid deleteRule string for relationship '%@': %@", 
                 NSStringFromSelector(_cmd), 
                 NSStringFromClass([self class]), 
                 self, 
                 [self name], 
                 deleteRuleString];

  return deleteRule;
}

- (NSDictionary*) _rightSideKeyMap
{
  NSDictionary *keyMap = nil;

  NSEmitTODO();  //TODO

  [self notImplemented: _cmd]; // TODO

  if ([self isToManyToOne])
    {
      int count = [_definitionArray count];

      if (count >= 2) //??
        {
          EORelationship *rel0 = [_definitionArray objectAtIndex: 0];

          if ([rel0 isToMany]) //??
            {
              EOEntity *entity = [rel0 destinationEntity];
              EORelationship *rel1 = [_definitionArray objectAtIndex: 1];

              keyMap = [entity _keyMapForIdenticalKeyRelationshipPath:
				 [rel1 name]];
            }
        }
    }

  return keyMap;
}

- (NSDictionary *) _leftSideKeyMap
{
  NSDictionary *keyMap = nil;

  NSEmitTODO();  //TODO

  [self notImplemented: _cmd]; // TODO

  if ([self isToManyToOne])
    {
      int count = [_definitionArray count];

      if (count >= 2) //??
        {
          EORelationship *rel = [_definitionArray objectAtIndex: 0];

          if ([rel isToMany]) //??
            {
              EOEntity *entity = [rel entity];

              keyMap = [entity _keyMapForIdenticalKeyRelationshipPath:
				 [rel name]];
            }
        }
    }

  return keyMap;
}

- (EORelationship*)_substitutionRelationshipForRow: (NSDictionary*)row
{
  EOEntity *entity = [self entity];
  EOModel *model = [entity model];
  EOModelGroup *modelGroup = [model modelGroup];

  if (modelGroup)
    {
      //??
      //NSEmitTODO();  //TODO
    }

  return self;
}

- (void) _joinsChanged
{
  //VERIFIED DA 
  int count = [_joins count];




  EOFLOGObjectLevelArgs(@"EORelationship", @"_joinsChanged:%@\nin %@", _joins, self);

  if (count > 0)
    {
      EOJoin *join = [_joins objectAtIndex: 0];
      EOAttribute *destinationAttribute = [join destinationAttribute];
      EOEntity *destinationEntity = [destinationAttribute entity];

      _destination = destinationEntity;
    }
  else
    {
      _destination = nil;
    }


}

@end
