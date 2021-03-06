/** 
   EOSQLExpression.m <title>EOSQLExpression Class</title>

   Copyright (C) 2000-2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Date: February 2000

   Author: Manuel Guesdon <mguesdon@orange-concept.com>
   Date: November 2001

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

#include <string.h>

#ifdef GNUSTEP
#include <Foundation/NSDebug.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSException.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef GNUSTEP
#include <GNUstepBase/GNUstep.h>
#include <GNUstepBase/GSObjCRuntime.h>
#include <GNUstepBase/NSDebug+GNUstepBase.h>
#include <GNUstepBase/NSObject+GNUstepBase.h>
#endif

#include <EOControl/EOFetchSpecification.h>
#include <EOControl/EOQualifier.h>
#include <EOControl/EOSortOrdering.h>
#include <EOControl/EODebug.h>
#include <EOControl/EONull.h>

#include <EOAccess/EOModel.h>
#include <EOAccess/EOEntity.h>
#include <EOAccess/EOAttribute.h>
#include <EOAccess/EORelationship.h>
#include <EOAccess/EOAdaptor.h>
#include <EOAccess/EOAdaptorContext.h>
#include <EOAccess/EOAdaptorChannel.h>
#include <EOAccess/EOJoin.h>
#include <EOAccess/EOSQLExpression.h>
#include <EOAccess/EOSQLQualifier.h>
#include <EOAccess/EOExpressionArray.h>

#include "EOPrivate.h"
#include "EOEntityPriv.h"
#include "EOAttributePriv.h"
#include "EOSQLExpressionPriv.h"


NSString *EOBindVariableNameKey = @"EOBindVariableNameKey";
NSString *EOBindVariableAttributeKey = @"EOBindVariableAttributeKey";
NSString *EOBindVariableValueKey = @"EOBindVariableValueKey";
NSString *EOBindVariablePlaceHolderKey = @"EOBindVariablePlaceHolderKey";
NSString *EOBindVariableColumnKey = @"EOBindVariableColumnKey";

@interface EOSQLExpression(Private)
+ (id)sqlExpressionWithEntity: (EOEntity *)entity;
@end

@implementation EOSQLExpression

+ (void) initialize
{
  static BOOL initialized=NO;
  if (!initialized)
    {
      GDL2_EOAccessPrivateInit();
    };
};

+ (id)sqlExpressionWithEntity: (EOEntity *)entity
{
  return [[[self alloc] initWithEntity: entity] autorelease];
}

- (id) initWithEntity: (EOEntity *)entity
{
  if ((self = [self init]))
    {
      ASSIGN(_entity, entity);

      _aliasesByRelationshipPath = [NSMutableDictionary new];
      [_aliasesByRelationshipPath setObject: @"t0"
                                  forKey: @""];
      _contextStack = [NSMutableArray new];
      [_contextStack addObject: @""];

      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"added '%@' (t0) in contextStack => %@",
                            @"",_contextStack);

/*NOT now  _listString = [NSMutableString new];
  _valueListString = [NSMutableString new];
  _joinClauseString = [NSMutableString new];
  _orderByString = [NSMutableString new];
  _bindings = [NSMutableArray new];
*/

      _alias++;
    }

  return self;
}

- (void)dealloc
{
  DESTROY(_aliasesByRelationshipPath);
  DESTROY(_entity);
  DESTROY(_listString);
  DESTROY(_valueListString);
  DESTROY(_whereClauseString);
  DESTROY(_joinClauseString);
  DESTROY(_orderByString);
  DESTROY(_bindings);
  DESTROY(_contextStack);
  DESTROY(_statement);

  [super dealloc];
}

+ (EOSQLExpression *)expressionForString: (NSString *)string
{
  EOSQLExpression *exp = [self sqlExpressionWithEntity: nil];

  ASSIGN(exp->_statement, string);

  return exp;
}

+ (EOSQLExpression *)insertStatementForRow: (NSDictionary *)row
				    entity: (EOEntity *)entity
{
  EOSQLExpression *sqlExpression;

  if (!entity)
    [NSException raise: NSInvalidArgumentException
                 format: @"EOSQLExpression: Entity of insertStatementForRow:entity: can't be the nil object"];

  sqlExpression = [self sqlExpressionWithEntity: entity];

  NSAssert(sqlExpression, @"No SQLExpression");

  [sqlExpression setUseAliases: NO];

  [sqlExpression prepareInsertExpressionWithRow: row];

  return sqlExpression;
}

+ (EOSQLExpression *)updateStatementForRow: (NSDictionary *)row
				 qualifier: (EOQualifier *)qualifier
				    entity: (EOEntity *)entity
{
  EOSQLExpression *sqlExpression;

  if(!row || ![row count])
    [NSException raise: NSInvalidArgumentException
		 format: @"EOSQLExpression: Row of updateStatementForRow:qualifier:entity: "
		 @"can't be the nil object or empty dictionary"];
  
  if (!qualifier)
    [NSException raise: NSInvalidArgumentException
		 format: @"EOSQLExpression: Qualifier of updateStatementForRow:qualifier:entity: "
		 @"can't be the nil object"];

  if (!entity)
    [NSException raise: NSInvalidArgumentException
		 format: @"EOSQLExpression: Entity of updateStatementForRow:qualifier:entity: "
		 @"can't be the nil object"];

  sqlExpression = [self sqlExpressionWithEntity: entity];

  NSAssert(sqlExpression, @"No SQLExpression");

  [sqlExpression setUseAliases: NO];

  [sqlExpression prepareUpdateExpressionWithRow: row
		 qualifier: qualifier];

  return sqlExpression;
}

+ (EOSQLExpression *)deleteStatementWithQualifier: (EOQualifier *)qualifier
					   entity: (EOEntity *)entity
{
  EOSQLExpression *sqlExpression;

  if (!qualifier)
    [NSException raise: NSInvalidArgumentException
		 format: @"EOSQLExpression: Qualifier of deleteStatementWithQualifier:entity: "
		 @"can't be the nil object"];

  if (!entity)
    [NSException raise: NSInvalidArgumentException
		 format: @"EOSQLExpression: Entity of deleteStatementWithQualifier:entity: "
		 @"can't be the nil object"];

  sqlExpression = [self sqlExpressionWithEntity: entity];

  [sqlExpression prepareDeleteExpressionForQualifier: qualifier];

  return sqlExpression;
}

+ (EOSQLExpression *)selectStatementForAttributes: (NSArray *)attributes
					     lock: (BOOL)flag
			       fetchSpecification: (EOFetchSpecification *)fetchSpecification
					   entity: (EOEntity *)entity
{
  EOSQLExpression *sqlExpression;

  if (!attributes || ![attributes count])
    [NSException raise: NSInvalidArgumentException
		 format: @"EOSQLExpression: Attributes of selectStatementForAttributes:lock:fetchSpecification:entity: "
		 @"can't be the nil object or empty array"];

  if (!fetchSpecification)
    [NSException raise: NSInvalidArgumentException
		 format: @"EOSQLExpression: FetchSpecification of selectStatementForAttributes:lock:fetchSpecification:entity: "
		 @"can't be the nil object"];
  
  if (!entity)
    [NSException raise: NSInvalidArgumentException
		 format: @"EOSQLExpression: Entity of selectStatementForAttributes:lock:fetchSpecification:entity: "
		 @"can't be the nil object"];

  sqlExpression = [self sqlExpressionWithEntity: entity];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlExpression=%@",
			sqlExpression);

  [sqlExpression setUseAliases: YES];
  [sqlExpression prepareSelectExpressionWithAttributes: attributes
		 lock: flag
		 fetchSpecification: fetchSpecification];

  return sqlExpression;
}

- (NSMutableDictionary *)aliasesByRelationshipPath
{
  return _aliasesByRelationshipPath;
}

- (EOEntity *)entity
{
  return _entity;
}

- (NSMutableString *)listString
{
  //OK
  if (!_listString)
    _listString = [NSMutableString new];

  return _listString;
}

- (NSMutableString *)valueList
{
  if (!_valueListString)
    _valueListString = [NSMutableString new];

  return _valueListString;
}

- (NSMutableString *)joinClauseString
{
  if (!_joinClauseString)
    _joinClauseString = [NSMutableString new];

  return _joinClauseString;
}

- (NSMutableString *)orderByString
{
  //OK
  if (!_orderByString)
    _orderByString = [NSMutableString new];

  return _orderByString;
}

- (NSString *)whereClauseString
{
  if (!_whereClauseString)
    _whereClauseString = [NSMutableString new];

  return _whereClauseString;
}

- (NSString *)statement
{
  return _statement;
}

- (void)setStatement:(NSString *)statement
{
  ASSIGN(_statement, statement);
}

- (NSString *)lockClause
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSString *)tableListWithRootEntity: (EOEntity*)entity
{
//self useAliases //ret 1 for select,0 for insert
//enity externalName
//self sqlStringForSchemaObjectName:eznti extnam//not always
// insert: ret quotation_place ?? / select: ret quotation_place t0

  NSMutableString *entitiesString = [NSMutableString string];
  IMP entitiesStringAppendStringIMP = NULL;
  NSEnumerator *relationshipEnum = nil;
  NSString *relationshipPath = nil;
  EOEntity *currentEntity = nil;
  int i = 0;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"entity=%@", entity);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"_aliasesByRelationshipPath=%@",
			_aliasesByRelationshipPath);

  relationshipEnum = [_aliasesByRelationshipPath keyEnumerator];
  while ((relationshipPath = [relationshipEnum nextObject]))
    {
      currentEntity = entity;

      if (i)
	GDL2_AppendStringWithImp(entitiesString,
                                entitiesStringAppendStringIMP,@", ");
      else
        entitiesStringAppendStringIMP = [entitiesString methodForSelector:@selector(appendString:)];

      if ([relationshipPath isEqualToString: @""])
        {
          NSString *tableName = [currentEntity externalName];

	  tableName = [self sqlStringForSchemaObjectName: tableName];
          EOFLOGObjectLevelArgs(@"EOSQLExpression",
				@"entity %p named %@: "
				@"externalName=%@ tableName=%@",
				currentEntity, [currentEntity name],
				[currentEntity externalName], tableName);

          NSAssert1([[currentEntity externalName] length]>0,
		    @"No external name for entity %@",
                    [currentEntity name]);

	  GDL2_AppendStringWithImp(entitiesString,
                                  entitiesStringAppendStringIMP,tableName);

	  if (_flags.useAliases)
	    [entitiesString appendFormat: @" %@",
			    [_aliasesByRelationshipPath
			      objectForKey: relationshipPath]];
        }
      else
        {
	  NSEnumerator *defEnum = nil;
	  NSArray *defArray = nil;
	  NSString *relationshipString = nil;
          NSString *tableName = nil;

	  defArray = [relationshipPath componentsSeparatedByString: @"."];
	  defEnum = [defArray objectEnumerator];
	      
	  while ((relationshipString = [defEnum nextObject]))
	    {
              // use anyRelationshipNamed: to find hidden relationship too
              EORelationship *relationship=[currentEntity 
                                             anyRelationshipNamed: relationshipString];

              NSAssert2(relationship,@"No relationship named %@ in entity %@",
                        relationshipString,
                        [currentEntity name]);

              NSAssert2(currentEntity,@"No destination entity. Entity %@ relationship = %@",
                        [currentEntity name],
                        relationship);

	      currentEntity = [relationship destinationEntity];
	    }

          tableName = [currentEntity externalName];
	  tableName = [self sqlStringForSchemaObjectName: tableName];

          EOFLOGObjectLevelArgs(@"EOSQLExpression",
				@"entity %p named %@: "
				@"externalName=%@ tableName=%@",
				currentEntity, [currentEntity name],
				[currentEntity externalName], tableName);

          NSAssert1([[currentEntity externalName] length]>0,
		    @"No external name for entity %@",
                    [currentEntity name]);

	  GDL2_AppendStringWithImp(entitiesString,
                                  entitiesStringAppendStringIMP,tableName);

	  if (_flags.useAliases)
            {
              NSString *alias = [_aliasesByRelationshipPath
				  objectForKey: relationshipPath];

              GDL2_AppendStringWithImp(entitiesString,
                                  entitiesStringAppendStringIMP,@" ");
              GDL2_AppendStringWithImp(entitiesString,
                                  entitiesStringAppendStringIMP,alias);

              EOFLOGObjectLevelArgs(@"EOSQLExpression",
				    @"appending alias %@ in entitiesString",
				    alias);
            }
        }

      i++;
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression",
                        @"entitiesString=%@",
                        entitiesString);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return entitiesString;
}

- (void)prepareInsertExpressionWithRow: (NSDictionary *)row
{
  //OK
  EOEntity *rootEntity = nil;
  NSString *tableList = nil;
  NSEnumerator *rowEnum;
  NSString *attributeName;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"row=%@", row);

  NS_DURING //Debugging Purpose
    {
      rowEnum = [row keyEnumerator];
      while ((attributeName = [rowEnum nextObject]))
	{
	  EOAttribute *attribute = [_entity anyAttributeNamed: attributeName];
	  id rowValue = [row objectForKey: attributeName];

	  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attribute name=%@",
				attributeName);
	  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"rowValue=%@", rowValue);

/*NO: in addInsertListAttribute      id value=[self sqlStringForValue:rowValue 
                     attributeNamed:attributeName];*/

          [self addInsertListAttribute: attribute
		value: rowValue];
	}
    }
  NS_HANDLER
    {
      NSDebugMLog(@"EXCEPTION %@", localException);
      [localException raise];
    }
  NS_ENDHANDLER;

  NS_DURING //Debugging Purpose
    {
      rootEntity = [self _rootEntityForExpression];
      tableList = [self tableListWithRootEntity: _entity];

      ASSIGN(_statement, [self assembleInsertStatementWithRow: row
			       tableList: tableList
			       columnList: _listString
			       valueList: _valueListString]);
    }
  NS_HANDLER
    {
      NSDebugMLog(@"EXCEPTION %@", localException);
      [localException raise];
    }
  NS_ENDHANDLER;

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"_statement=%@", _statement);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");
}

- (void)prepareUpdateExpressionWithRow: (NSDictionary *)row
                             qualifier: (EOQualifier *)qualifier
{
  //OK
  EOEntity *rootEntity = nil;
  NSString *whereClauseString = nil;
  NSString *tableList = nil;
  NSString *statement = nil;
  NSEnumerator *rowEnum;
  NSString *attributeName;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  rowEnum = [row keyEnumerator];
  while ((attributeName = [rowEnum nextObject]))
    {
      id attribute = [_entity attributeNamed: attributeName];
      id value = [row objectForKey: attributeName];

      [self addUpdateListAttribute: attribute
            value: value];
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"qualifier=%@", qualifier);

  whereClauseString = [(id <EOQualifierSQLGeneration>)qualifier sqlStringForSQLExpression: self];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"whereClauseString=%@",
			whereClauseString);

  ASSIGN(_whereClauseString, whereClauseString);

  rootEntity = [self _rootEntityForExpression];
  tableList = [self tableListWithRootEntity: rootEntity];
  statement = [self assembleUpdateStatementWithRow: row
		    qualifier: qualifier
		    tableList: tableList
		    updateList: _listString
		    whereClause: whereClauseString];

  ASSIGN(_statement, statement);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");
}

- (void)prepareDeleteExpressionForQualifier: (EOQualifier *)qualifier
{
  ASSIGN(_whereClauseString, [(id)qualifier sqlStringForSQLExpression: self]);
  
  ASSIGN(_statement, [self assembleDeleteStatementWithQualifier: qualifier
			   tableList: [self tableListWithRootEntity: _entity]
			   whereClause: ([_whereClauseString length] ? 
					 _whereClauseString : nil)]);
}

/*
//TC:
- (void)prepareSelectExpressionWithAttributes:(NSArray *)attributes
                                         lock:(BOOL)flag
                           fetchSpecification:(EOFetchSpecification *)fetchSpecification
{
  NSEnumerator *attrEnum, *sortEnum;
  EOAttribute *attribute;
  EOSortOrdering *sort;
  NSString *tableList;
  NSString *lockClause = nil;
  NSArray *sortOrderings;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  // Turbocat (RawRow Additions)
  if ([fetchSpecification rawRowKeyPaths]) {

	// fill _aliasesByRelationshipPath before calling addSelectListAttribute

	NSEnumerator		*keyPathEnum = [[fetchSpecification rawRowKeyPaths] objectEnumerator];
	NSString			*keyPath;
	EOExpressionArray 	*expressionArray;

    while (keyPath = [keyPathEnum nextObject]) {
  		if([keyPath isNameOfARelationshipPath]) {

			// get relationships
			NSString	*newKeyPath = [keyPath stringByDeletingPathExtension];	// cut attributename

			if (![_aliasesByRelationshipPath objectForKey:newKeyPath]) {
            	//int    		count = [[_aliasesByRelationshipPath allKeys] count];
            	NSString	*prefix = [NSString stringWithFormat:@"t%d",_alias++];

				[_aliasesByRelationshipPath setObject:prefix forKey:newKeyPath];
			}
		}
	}
	//NSLog(@"_aliasesByRelationshipPath = %@", _aliasesByRelationshipPath);
  } // Turbocat (RawRow Additions)

  attrEnum = [attributes objectEnumerator];
  while((attribute = [attrEnum nextObject]))
    {
      [self addSelectListAttribute:attribute];
    }

  ASSIGN(_whereClauseString, [(id)[fetchSpecification qualifier]
				  sqlStringForSQLExpression:self]);

  sortOrderings = [fetchSpecification sortOrderings];

  sortEnum = [sortOrderings objectEnumerator];
  while((sort = [sortEnum nextObject]))
    [self addOrderByAttributeOrdering:sort];

  [self joinExpression];
  tableList = [self tableListWithRootEntity:_entity];
  if(flag) lockClause = [self lockClause];

  ASSIGN(_statement, [self assembleSelectStatementWithAttributes:attributes
			   lock:flag
			   qualifier:[fetchSpecification qualifier]
			   fetchOrder:sortOrderings
			   selectString:nil //TODO
			   columnList:_listString
			   tableList:tableList
			   whereClause:([_whereClauseString length] ?
					_whereClauseString : nil)
			   joinClause:([_joinClauseString length] ?
				       _joinClauseString : nil)
			   orderByClause:([_orderByString length] ?
					  _orderByString : nil)
			   lockClause:lockClause]);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");
}
*/

- (void)prepareSelectExpressionWithAttributes: (NSArray *)attributes
                                         lock: (BOOL)flag
                           fetchSpecification: (EOFetchSpecification *)fetchSpecification
{
  EOQualifier *fetchQualifier = nil;
  EOQualifier *restrictingQualifier = nil;
  NSString *whereClauseString = nil;
  NSArray *sortOrderings = nil;
  EOEntity *rootEntity = nil;
  NSString *tableList = nil;
  NSString *lockClauseString = nil;
  BOOL usesDistinct = NO;
  NSString *statement = nil;
  NSString *selectCommand = nil;
  //Add Attributes to listString
  int i, count = [attributes count];

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  //OK
  for (i = 0; i < count; i++)
    {
      EOAttribute *attribute = [attributes objectAtIndex: i];

      /* Add non-relationship definitions such as aggregates.  */
      if ([attribute isFlattened])
	{
	  NSMutableString *listString = [self listString];
	  NSString *definition = [attribute definition];

	  if (definition) 
	    {
	      NSRange range = [definition rangeOfString:@"."];

	      if (range.length == 0)
		{
		  [self appendItem: definition
			toListString: listString];
		}
	    }

          EOFLOGObjectLevelArgs(@"EOSQLExpression", @"flattened attribute=%@",
				attribute);
        }
      else
        [self addSelectListAttribute: attribute];

      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"_listString=%@",
			    _listString);
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"_listString=%@", _listString);

  fetchQualifier = [fetchSpecification qualifier]; //OK
  //call fetchSpecification -isDeep
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"fetchQualifier=%@",
			fetchQualifier);

  restrictingQualifier = [_entity restrictingQualifier]; 

  if (fetchQualifier && restrictingQualifier)
    {
      fetchQualifier = [[EOAndQualifier alloc] initWithQualifiers:fetchQualifier, restrictingQualifier, nil];
      AUTORELEASE(fetchQualifier);
    }
  else
    {
      fetchQualifier = fetchQualifier ? fetchQualifier : restrictingQualifier;
    }

  //Build Where Clause
  whereClauseString = [(id<EOQualifierSQLGeneration>)fetchQualifier sqlStringForSQLExpression: self];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"whereClauseString=%@",
			whereClauseString);
  ASSIGN(_whereClauseString, whereClauseString);

  //Build Ordering Clause
  sortOrderings = [fetchSpecification sortOrderings];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sortOrderings=%@",
			sortOrderings);

  if ([sortOrderings count] > 0)
    {
      int i, count = [sortOrderings count];

      for (i = 0; i < count; i++)
        {
          EOSortOrdering *order = [sortOrderings objectAtIndex: i];

          EOFLOGObjectLevelArgs(@"EOSQLExpression", @"order=%@", order);
          NSAssert3([order isKindOfClass: [EOSortOrdering class]],
                    @"order is not a EOSortOrdering but a %@: %p %@",
                    [order class],
                    order,
                    order);

          [self addOrderByAttributeOrdering: order];
        }
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"_listString=%@", _listString);
  [self joinExpression];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"_joinClauseString=%@",
			_joinClauseString);

  rootEntity = [self _rootEntityForExpression];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"rootEntity=%@",
			[rootEntity name]);

  //Build Table List
  tableList = [self tableListWithRootEntity: rootEntity];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"tableList=%@", tableList);

  //Build LockClause
  if (flag)
    lockClauseString = [self lockClause];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"lockClauseString=%@",
			lockClauseString);

  //Build UseDistinct Clause
  usesDistinct = [fetchSpecification usesDistinct];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"usesDistinct=%d", usesDistinct);

  if (usesDistinct)
    selectCommand = @"SELECT distinct ";
  else
    selectCommand = @"SELECT ";

  //Now Build Statement
  statement = [self assembleSelectStatementWithAttributes: attributes
		    lock: flag
		    qualifier: fetchQualifier
		    fetchOrder: sortOrderings
		    selectString: selectCommand
		    columnList: _listString
		    tableList: tableList
		    whereClause: ([_whereClauseString length] > 0
				  ? _whereClauseString : nil)
		    joinClause: ([_joinClauseString length] > 0
				 ? _joinClauseString : nil)
		    orderByClause: ([_orderByString length] > 0
				    ? _orderByString : nil)
		    lockClause: lockClauseString];
  ASSIGN(_statement, statement);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");
}

- (NSString *)assembleJoinClauseWithLeftName: (NSString *)leftName
                                   rightName: (NSString *)rightName
                                joinSemantic: (EOJoinSemantic)semantic
{
  NSString *op = nil;
  NSString *joinClause = nil;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"join parts=%@ %d %@",
			leftName,
			(int)semantic,
			rightName);
//call [self _sqlStringForJoinSemantic:semantic matchSemantic:2
//[self _sqlStringForJoinSemantic:semantic matchSemantic:3
//the 2 ret nil

  switch (semantic)
    {
    case EOInnerJoin:
      op = @"=";
      break;
    case EOLeftOuterJoin:
      op = @"*=";
      break;
    case EORightOuterJoin:
      op = @"=*";
      break;
    case EOFullOuterJoin:
      break;
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"op= '%@'", op);

  if (op)
    joinClause = [NSString stringWithFormat: @"%@ %@ %@", 
			   leftName,
			   op,
			   rightName]; //TODO

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"joinClause=%@", joinClause);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return joinClause;
}

- (void)addJoinClauseWithLeftName: (NSString *)leftName
                        rightName: (NSString *)rightName
                     joinSemantic: (EOJoinSemantic)semantic
{
  NSString *joinClause = nil;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"join parts=%@ %d %@",
			leftName,
			(int)semantic,
			rightName);

  joinClause = [self assembleJoinClauseWithLeftName: leftName
		     rightName: rightName
		     joinSemantic: semantic];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"joinClause=%@",
			joinClause);
  if (joinClause)
    {
      NSMutableString *joinClauseString = [self joinClauseString];

      if (![joinClauseString isEqualToString: @""])
	[joinClauseString appendString: @" AND "];

      [joinClauseString appendString: joinClause];
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"_joinClauseString=%@",
			_joinClauseString);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");
}

/** Build join expression for all used relationships (call this) after all other query parts construction) **/
- (void)joinExpression
{
  EOEntity *entity = nil;
  NSEnumerator *relationshipEnum;
  NSString *relationshipPath;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"_aliasesByRelationshipPath=%@",
			_aliasesByRelationshipPath);

  // Iterate on each used relationship
  relationshipEnum = [_aliasesByRelationshipPath keyEnumerator];
  while((relationshipPath = [relationshipEnum nextObject]))
    {
      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"relationshipPath=%@",
			    relationshipPath);

      // If this is not the base (root) one 
      if (![relationshipPath isEqualToString: @""])
        {
          EOQualifier *auxiliaryQualifier = nil;
          EORelationship *rel = nil;
          NSArray *joins = nil;
          int i, count=0;

          //Get the root entity if we haven't got it before
          if (!entity)
            entity=[self entity];

          // Get the relationship for this path (non flattened by design)
          rel = [entity relationshipForPath: relationshipPath];

          EOFLOGObjectLevelArgs(@"EOSQLExpression", @"rel=%@", rel);
          NSAssert2(rel, @"No relationship for path %@ in entity %@",
                    relationshipPath,
                    [entity name]);

          //Get the auxiliary qualifier for this relationship
          auxiliaryQualifier = [rel auxiliaryQualifier];

          if (auxiliaryQualifier)
            {
              NSEmitTODO();  //TODO
              [self notImplemented:_cmd]; 
            }

          // Get relationship joins
          joins = [rel joins];
          count = [joins count];
          EOFLOGObjectLevelArgs(@"EOSQLExpression", @"joins=%@", joins);

          // Iterate on each join
          for (i = 0; i < count; i++)
            {
              NSString *sourceRelationshipPath = nil;
              NSArray *sourceRelationshipPathArray;
              //Get the join
              EOJoin *join=[joins objectAtIndex:i];
              // Get source and destination attributes
              EOAttribute *sourceAttribute = [join sourceAttribute];
              EOAttribute *destinationAttribute = [join destinationAttribute];
              NSString *sourceAttributeAlias = nil;
              NSString *destinationAttributeAlias = nil;

              // Build the source relationshipPath
              sourceRelationshipPathArray =
		[relationshipPath componentsSeparatedByString: @"."];
              sourceRelationshipPathArray =
		[sourceRelationshipPathArray
		  subarrayWithRange:
		    NSMakeRange(0,[sourceRelationshipPathArray count] - 1)];  
              sourceRelationshipPath = [sourceRelationshipPathArray
					 componentsJoinedByString: @"."];

              // Get the alias for sourceAttribute
              sourceAttributeAlias = [self
				       _aliasForRelatedAttribute:
					 sourceAttribute
				       relationshipPath:
					 sourceRelationshipPath];

              // Get the alias for destinationAttribute
              destinationAttributeAlias =
		[self _aliasForRelatedAttribute: destinationAttribute
		      relationshipPath: relationshipPath];

              EOFLOGObjectLevelArgs(@"EOSQLExpression", @"addJoin=%@ %d %@",
				    sourceAttributeAlias,
				    (int)[rel joinSemantic],
				    destinationAttributeAlias);

              // Add to join clause
              [self addJoinClauseWithLeftName: sourceAttributeAlias
                    rightName: destinationAttributeAlias
                    joinSemantic: [rel joinSemantic]];
            }
        }
    }

  EOFLOGObjectFnStopCond(@"EOSQLExpression");
}

- (NSString *)assembleInsertStatementWithRow: (NSDictionary *)row
                                   tableList: (NSString *)tableList
                                  columnList: (NSString *)columnList
                                   valueList: (NSString *)valueList
{
  //OK
  if (columnList)
    return [NSString stringWithFormat: @"INSERT INTO %@ (%@) VALUES (%@)",
		     tableList, columnList, valueList];
  else
    return [NSString stringWithFormat: @"INSERT INTO %@ VALUES (%@)",
		     tableList, valueList];
}

- (NSString *)assembleUpdateStatementWithRow: (NSDictionary *)row
                                   qualifier: (EOQualifier *)qualifier
                                   tableList: (NSString *)tableList
                                  updateList: (NSString *)updateList
                                 whereClause: (NSString *)whereClause
{
  return [NSString stringWithFormat: @"UPDATE %@ SET %@ WHERE %@",
		   tableList, updateList, whereClause];
}

- (NSString *)assembleDeleteStatementWithQualifier: (EOQualifier *)qualifier
                                         tableList: (NSString *)tableList
                                       whereClause: (NSString *)whereClause
{
  return [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@",
		   tableList, whereClause];
}

- (NSString *)assembleSelectStatementWithAttributes: (NSArray *)attributes
                                               lock: (BOOL)lock
                                          qualifier: (EOQualifier *)qualifier
                                         fetchOrder: (NSArray *)fetchOrder
                                       selectString: (NSString *)selectString
                                         columnList: (NSString *)columnList
                                          tableList: (NSString *)tableList
                                        whereClause: (NSString *)whereClause
                                         joinClause: (NSString *)joinClause
                                      orderByClause: (NSString *)orderByClause
                                         lockClause: (NSString *)lockClause
{ //TODO selectString ??
  NSMutableString *sqlString;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attributes=%@", attributes);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"qualifier=%@", qualifier);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"fetchOrder=%@", fetchOrder);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"selectString=%@", selectString);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"columnList=%@", columnList);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"tableList=%@", tableList);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"whereClause=%@", whereClause);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"joinClause=%@", joinClause);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"orderByClause=%@", orderByClause);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"lockClause=%@", lockClause);

  sqlString = [NSMutableString stringWithFormat: @"SELECT %@ FROM %@",
			       columnList, tableList];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);

  if ([lockClause length] > 0)
    [sqlString appendFormat: @" %@", lockClause];

  if ([whereClause length] == 0)
    whereClause = nil;

  if ([joinClause length] == 0)
    joinClause = nil;

  if (whereClause && joinClause)
    [sqlString appendFormat: @" WHERE (%@) AND (%@)",
               whereClause, joinClause];
  else if (whereClause || joinClause)
    [sqlString appendFormat: @" WHERE %@",
               (whereClause
                ? whereClause
                : joinClause)];
  if ([orderByClause length] > 0)
    [sqlString appendFormat: @" ORDER BY %@", orderByClause];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);
  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return sqlString;
}

- (void)addSelectListAttribute: (EOAttribute *)attribute
{
  //OK
  NSMutableString *listString;
  NSString *string;
  NSString *sqlStringForAttribute = [self sqlStringForAttribute:attribute];

  NSAssert1(sqlStringForAttribute,@"No sqlString for attribute: %@",attribute);

  string = [[self class] formatSQLString: sqlStringForAttribute
			 format: [attribute readFormat]];
  listString = [self listString];

  [self appendItem: string
        toListString: listString];
}

- (void)addInsertListAttribute: (EOAttribute *)attribute
                         value: (NSString *)value
{
  //OK
  NSMutableString *valueList=nil;
  NSString *writeFormat=nil;
  NSString *valueSQLString=nil;
  NSMutableString *listString;
  NSString *attributeSQLString=nil;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attribute name=%@",
			[attribute name]);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"value=%@", value);

  listString = [self listString];

  NS_DURING // debug purpose
    {
      attributeSQLString = [self sqlStringForAttribute: attribute];
      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attributeSQLString=%@",
			    attributeSQLString);
    }
  NS_HANDLER
    {
      NSDebugMLog(@"EXCEPTION %@", localException);
      [localException raise];
    }
  NS_ENDHANDLER;

  NS_DURING // debug purpose
    {
      [self appendItem: attributeSQLString
            toListString: listString];

      valueSQLString = [self sqlStringForValue: value
                           attributeNamed: [attribute name]];

      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"valueSQLString=%@",
			    valueSQLString);
    }
  NS_HANDLER
    {
      NSDebugMLog(@"EXCEPTION %@", localException);
      [localException raise];
    }
  NS_ENDHANDLER;

  NS_DURING // debug purpose
    {
      writeFormat = [attribute writeFormat];
      if ([writeFormat length] > 0)
        {
          NSEmitTODO();  //TODO
          NSDebugMLog(@"writeFormat '%@' not yet handled",writeFormat);
        }

      valueList = [self valueList];
      [self appendItem: valueSQLString
            toListString: valueList];
    }
  NS_HANDLER
    {
      NSDebugMLog(@"EXCEPTION %@", localException);
      [localException raise];
    }
  NS_ENDHANDLER;

  EOFLOGObjectFnStopCond(@"EOSQLExpression");
}

- (void)addUpdateListAttribute: (EOAttribute *)attribute
                         value: (NSString *)value
{
  //OK
  NSString *sqlStringToAdd;
  NSMutableString *listString;
  NSString *attributeSQLString;
  NSString *valueSQLString;
  NSString *writeFormat;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  attributeSQLString = [self sqlStringForAttribute: attribute];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attributeSQLString=%@",
			attributeSQLString);

  valueSQLString = [self sqlStringForValue: value
                       attributeNamed: [attribute name]];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"valueSQLString=%@",
			valueSQLString);

  writeFormat = [attribute writeFormat];

  if ([writeFormat length] > 0)
    {
      NSEmitTODO();  //TODO
      NSDebugMLog(@"writeFormat '%@' not yet handled",writeFormat);
    }

  listString = [self listString];
  sqlStringToAdd = [NSString stringWithFormat: @"%@ = %@",
			     attributeSQLString,
			     valueSQLString];

  [self appendItem: sqlStringToAdd
        toListString: listString];

  EOFLOGObjectFnStopCond(@"EOSQLExpression");
}

+ (NSString *)formatStringValue: (NSString *)string
{
  NSString *formatted;

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @" string=%@", string);

  if (string == nil)
    [NSException raise: NSInternalInconsistencyException
		 format: @"EOSQLExpression: Argument of formatStringValue: "
		 @"can't be a nil object"];

  formatted = [NSString stringWithFormat: @"%@%@%@", @"'", string, @"'"];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @" formatted=%@", formatted);

  return formatted;
}

+ (NSString *)formatValue: (id)value
             forAttribute: (EOAttribute *)attribute
{
//mirko new:return [value sqlString];
  NSString *formattedValue = nil;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @" value=%@ class=%@",
			value, [value class]);

  NS_DURING //debug purpose
    {
      if (!value)
	formattedValue = @"NULL";
      else
	{
	  NSString *string;

	  string = [value sqlString];

	  EOFLOGObjectLevelArgs(@"EOSQLExpression", @" value %p=%@ null %p=%@",
				value, value, GDL2_EONull, GDL2_EONull);

	  if (value == GDL2_EONull)
	    formattedValue = string;
	  else
	    formattedValue = [self formatSQLString: [self formatStringValue:
							    string]
				   format: [attribute readFormat]];
	}
    }
  NS_HANDLER
    {
      NSDebugMLog(@"EXCEPTION %@", localException);
      [localException raise];
    }
  NS_ENDHANDLER;

  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return formattedValue;
}

+ (NSString *)formatSQLString: (NSString *)sqlString
                       format: (NSString *)format
{
  NSString *formatted = nil;  

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @" sqlString=%@ format=%@",
			sqlString, format);
  NSAssert1([sqlString length] > 0, @"No sqlString (%p)", sqlString);

  NS_DURING //debug purpose
    {
      if (!format)
	formatted = sqlString;
      else
	{
	  const char *p = [format cString];
	  char *s;
	  NSMutableString *str = [NSMutableString stringWithCapacity:
						    [format length]];
          IMP appendStringIMP = [str methodForSelector:@selector(appendString:)];

	  while ((s = strchr(p, '%')))
	    {
	      switch (*(s + 1))
		{
		case '%':
		  GDL2_AppendStringWithImp(str,appendStringIMP,
                                          GDL2_StringWithCStringAndLength(p,s-p+1));
		  break;
		case 'P':
		  if (s != p)
		    GDL2_AppendStringWithImp(str,appendStringIMP,
                                            GDL2_StringWithCStringAndLength(p,s-p));
		  [str appendString: sqlString];
		  break;
		default:
		  if (s != p)
		    GDL2_AppendStringWithImp(str,appendStringIMP,
                                            GDL2_StringWithCStringAndLength(p,s-p));
		  break;
		}

	      p = s + 2;
	    }

	  if (*p)
	    GDL2_AppendStringWithImp(str,appendStringIMP,[NSString stringWithCString: p]);

	  formatted = str;
	}
    }
  NS_HANDLER
    {
      NSDebugMLog(@"EXCEPTION %@", localException);
      [localException raise];
    }
  NS_ENDHANDLER;

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @" formatted=%@", formatted);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return formatted;
}

//operation must have space before and after. Example: @" AND "
- (NSString*) sqlStringForArrayOfQualifiers: (NSArray*)qualifiers
                                  operation: (NSString*)operation
{
  //OK
  NSMutableString *sqlString = nil;
  int i, count;
  int nb=0;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"operation=%@ qualifiers=%@",
                        operation, qualifiers);

  count = [qualifiers count];

  for (i = 0; i < count; i++)
    {
      NSString *tmpSqlString=nil;

      EOQualifier<EOQualifierSQLGeneration> *qualifier 
	= [qualifiers objectAtIndex: i];

      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"qualifier=%@",
                            qualifier);

      tmpSqlString=[qualifier sqlStringForSQLExpression:self];

      EOFLOGObjectLevelArgs(@"EOSQLExpression", 
			    @"qualifier=%@ tmpSqlString=%@",
                            qualifier, tmpSqlString);

      if (tmpSqlString)
        {
          if (!sqlString)
            sqlString = (NSMutableString*)[NSMutableString string];

          if (nb > 0)
	    [sqlString appendString: operation];

	  [sqlString appendString: tmpSqlString];
	  nb++;

          EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@",
                                sqlString);
        }
    }

  if (nb > 1)
    {
      [sqlString insertString: @"(" atIndex: 0];
      [sqlString appendString: @")"];
    }
  else if (nb == 0)
    sqlString = nil;

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"operation=%@ qualifiers=%@ count=%d nb=%d sqlString=%@",
                        operation, qualifiers, count, nb, sqlString);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return sqlString;
}

- (NSString *)sqlStringForConjoinedQualifiers: (NSArray *)qualifiers
{
  //OK
  NSString *sqlString;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  sqlString = [self sqlStringForArrayOfQualifiers: qualifiers
                    operation: @" AND "];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return sqlString;
}

- (NSString *)sqlStringForDisjoinedQualifiers: (NSArray *)qualifiers
{
  //OK
  NSString *sqlString;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  sqlString = [self sqlStringForArrayOfQualifiers: qualifiers
		    operation: @" OR "];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return sqlString;
}

- (NSString *)sqlStringForNegatedQualifier:(EOQualifier *)qualifier
{
  NSString *sqlQual = nil;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  sqlQual = [(id)qualifier sqlStringForSQLExpression: self];
  if (sqlQual)
    sqlQual = [NSString stringWithFormat:@"not (%@)", sqlQual];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlQual=%@", sqlQual);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");    

  return sqlQual;
}

- (NSString *)sqlStringForKeyValueQualifier: (EOKeyValueQualifier *)qualifier
{
  //Near OK
  NSString* sqlString=nil;
  NSString* valueSQLString=nil;
  NSString* selectorSQLString=nil;
  NSString *key = nil;
  id value=nil;
  NSString* attributeSQLString=nil;
  EOAttribute* attribute=nil;
  NSString* readFormat=nil;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"qualifier=%@", qualifier);

  NSAssert2([qualifier isKindOfClass:[EOKeyValueQualifier class]],
            @"qualifier is not a EOKeyValueQualifier but a %@: %@",
            [qualifier class],
            qualifier);

  key = [qualifier key];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"key=%@", key);
  NSAssert1([key length]>0,
           @"No key in EOKeyValueQualifier: %@",qualifier);

  value = [qualifier value];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"value=%@", value);

  attributeSQLString = [self sqlStringForAttributeNamed: key];

  NSAssert1(attributeSQLString, @"No sqlStringForAttributeNamed:%@", key);
  EOFLOGObjectLevelArgs(@"EOSQLExpression",@"attributeSQLString=%@",
			attributeSQLString);

  attribute = [_entity attributeForPath: key];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attribute=%@", attribute);
  NSAssert3(attribute,
            @"No attribute forKeyPath: '%@' in entity named '%@' in EOKeyValueQualifier: %@",
            key,_entity,qualifier);

  readFormat = [attribute readFormat];

  if (readFormat)
    {
      NSEmitTODO();  //TODO
      NSDebugMLog(@"readFormat '%@' not yet handled",readFormat);
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"valueSQLString=%@ qualifier=%@ [qualifier selector]=%p %@",
			valueSQLString,
                        qualifier,
                        [qualifier selector],
                        NSStringFromSelector([qualifier selector]));

  selectorSQLString = [self sqlStringForSelector: [qualifier selector]
			    value: value];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"selectorSQLString=%@",
			selectorSQLString);

  if (sel_isEqual([qualifier selector], EOQualifierOperatorLike))
    {
      value = [[self class] sqlPatternFromShellPattern: value];
      valueSQLString = [self sqlStringForValue: value
                             attributeNamed: key];
    }
  else if (sel_isEqual([qualifier selector], EOQualifierOperatorCaseInsensitiveLike))
    {      
      value = [[self class] sqlPatternFromShellPattern: value];

      valueSQLString = [self sqlStringForValue: value
                             attributeNamed: key];

      attributeSQLString = [NSString stringWithFormat: @"UPPER(%@)",
				     attributeSQLString];
      valueSQLString = [NSString stringWithFormat: @"UPPER(%@)",
				 valueSQLString];
    }
  else
    valueSQLString = [self sqlStringForValue: value
                           attributeNamed: key];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attributeSQLString=%@",
			attributeSQLString);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"selectorSQLString=%@",
			selectorSQLString);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"valueSQLString=%@",
			valueSQLString);

  sqlString = [NSString stringWithFormat: @"%@ %@ %@",
			attributeSQLString,
			selectorSQLString,
			valueSQLString];
  /*
  NSString* sqlString = [NSString stringWithFormat: @"%@ %@ %@",
                                  [[self class] formatSQLString:
				     [self sqlStringForAttributeNamed:key]
				  format:
				     [[_entity attributeNamed:key]
				       readFormat]],
		   selString,
		   valueString];
*/

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return sqlString; //return someting like t1.label = 'XXX'
}

- (NSString *)sqlStringForKeyComparisonQualifier: (EOKeyComparisonQualifier *)qualifier
{
  return [NSString stringWithFormat:@"%@ %@ %@",
		   [[self class] formatSQLString:
				   [self sqlStringForAttributeNamed:
					   [qualifier leftKey]]
				 format:
				   [[_entity attributeNamed:
					       [qualifier leftKey]]
				     readFormat]],
		   [self sqlStringForSelector:[qualifier selector] value:nil],
		   [[self class] formatSQLString:
				   [self sqlStringForAttributeNamed:
					   [qualifier rightKey]]
				 format:[[_entity attributeNamed:
						    [qualifier rightKey]]
					  readFormat]]];
}

- (NSString *)sqlStringForValue:(NSString *)valueString
	 caseInsensitiveLikeKey:(NSString *)keyString
{
  [self notImplemented:_cmd]; //TODO
  return nil;
}

- (void)addOrderByAttributeOrdering:(EOSortOrdering *)sortOrdering
{
  SEL orderSelector = NULL;
  NSString *orderStringFormat = nil;
  NSString *keyString = nil;
  id key = nil;

  orderSelector = [sortOrdering selector];

  if (sel_isEqual(orderSelector, EOCompareAscending))
    orderStringFormat = @"(%@) asc";
  else if (sel_isEqual(orderSelector, EOCompareDescending))
    orderStringFormat = @"(%@) desc";
  else if (sel_isEqual(orderSelector, EOCompareCaseInsensitiveAscending))
    orderStringFormat = @"upper(%@) asc";
  else if (sel_isEqual(orderSelector, EOCompareCaseInsensitiveDescending))
    orderStringFormat = @"upper(%@) desc";

  key = [sortOrdering key];

  NSAssert1(key,
            @"Key in sort ordering",
            sortOrdering);

  keyString = [self sqlStringForAttributeNamed: key];//TODO VERIFY
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"keyString=%@", keyString);

  NSAssert1(keyString,
            @"No sql string for key named \"%@\"",
            key);

  [self appendItem: [NSString stringWithFormat: orderStringFormat,
			      keyString]
	toListString: [self orderByString]];
}

+ (BOOL)useQuotedExternalNames
{
  return [[NSUserDefaults standardUserDefaults]
	   boolForKey: @"EOAdaptorQuotesExternalNames"];
}

+ (void)setUseQuotedExternalNames:(BOOL)flag
{
  NSString *yn = (flag ? @"YES" : @"NO");

  [[NSUserDefaults standardUserDefaults]
    setObject: yn forKey: @"EOAdaptorQuotesExternalNames"];
}

- (NSString *)externalNameQuoteCharacter
{
  if ([[self class] useQuotedExternalNames])
    return @"\"";

  return @"";
}

- (void)setUseAliases: (BOOL)useAliases
{
  _flags.useAliases = useAliases;
}

- (BOOL)useAliases
{
  return _flags.useAliases;
}

- (NSString *)sqlStringForSchemaObjectName: (NSString *)name
{
  //OK
  NSString *quote = [self externalNameQuoteCharacter];
  
  return [NSString stringWithFormat:@"%@%@%@", quote, name, quote];
}

- (NSString *)sqlStringForAttributeNamed: (NSString *)name
{
  //OK
  EOAttribute *attribute = nil;
  NSString *sqlString = nil;
  NSArray *keyParts = nil;
  NSString *key = nil;
  EOEntity *entity=_entity;
  NSMutableArray *attributePath = nil;  
  int i, count;
  EORelationship *rel = nil;


  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  NSAssert(entity,@"no entity");
  NSAssert(name,@"no attribute name");
  NSAssert([name length]>0,@"attribute name is empty");  

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"name=%@", name);

  keyParts = [name componentsSeparatedByString:@"."];
  count = [keyParts count];

  for (i = 0; i < count - 1; i++)
    {
      key = [keyParts objectAtIndex: i];

      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"keyPart=%@", key);

      rel = [entity anyRelationshipNamed: key];

      NSAssert2(rel,
		@"no relationship named %@ in entity %@",
		key,
		[entity name]);

      if (attributePath)
        [attributePath addObject: rel];
      else
        attributePath = [NSMutableArray arrayWithObject: rel];      

      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"rel=%@", rel);

      entity = [rel destinationEntity];
      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"entity name=%@",
			    [entity name]);
    }

  key = [keyParts lastObject];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"key=%@", key);

  attribute = [entity anyAttributeNamed: key];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attribute=%@", attribute);

  if (!attribute)
    {
      rel = [entity anyRelationshipNamed: key];
      if (rel)
        NSAssert4(attribute,
                  @"no attribute named %@ (only a relationship) in entity %@\nAttributesByName=%@\nattributes=%@",
                  key,
                  [entity name],
                  [entity attributesByName],
                  [entity attributes]);
      else
        NSAssert4(attribute,
                  @"no attribute nor relationship named %@ in entity %@\nAttributesByName=%@\nattributes=%@",
                  key,
                  [entity name],
                  [entity attributesByName],
                  [entity attributes]);
    };

  if (attributePath)
    {
      [attributePath addObject: attribute];
      sqlString = [self sqlStringForAttributePath: attributePath];

      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);
      NSAssert1(sqlString,
                @"no sql string for attribute path %@",
                attributePath);
      NSAssert1([sqlString length],
                @"empty sql string for attribute path %@",
                attributePath);
    }
  else
    {
      sqlString = [self sqlStringForAttribute: attribute];

      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);
      NSAssert1(sqlString,
                @"no sql string for attribute %@",
                attribute);
      NSAssert1([sqlString length],
                @"empty sql string for attribute %@",
                attribute);
    }

  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return sqlString;
}

- (NSString *)sqlStringForSelector: (SEL)selector
                             value: (id)value
{
  //seems OK
  if (sel_isEqual(selector, EOQualifierOperatorEqual))
    {
      if (value==GDL2_EONull)
        return @"is";
      else
        return @"=";
    }
  else if (sel_isEqual(selector, EOQualifierOperatorNotEqual))
    {
      if (value==GDL2_EONull)
        return @"is not";
      else
        return @"<>";
    }
  else if (sel_isEqual(selector, EOQualifierOperatorLessThan))
    return @"<";
  else if (sel_isEqual(selector, EOQualifierOperatorGreaterThan))
    return @">";
  else if (sel_isEqual(selector, EOQualifierOperatorLessThanOrEqualTo))
    return @"<=";
  else if (sel_isEqual(selector, EOQualifierOperatorGreaterThanOrEqualTo))
    return @">=";
  else if (sel_isEqual(selector, EOQualifierOperatorLike))
    return @"like";
  else if (sel_isEqual(selector, EOQualifierOperatorCaseInsensitiveLike))
    return @"like"; //same as sensitive
/*  //TODO else if(sel_isEqual(selector, EOQualifierOperatorContains))
    return @"like";*/
  else
    {
      [NSException raise: NSInternalInconsistencyException
                   format: @"EOSQLExpression: Unknown selector of sqlStringForSelector:value: '%@'",NSStringFromSelector(selector)];
    }

  return nil;
}

- (NSString *)sqlStringForValue: (id)value
                 attributeNamed: (NSString*)attributeName
{
  EOAttribute *attribute;
  NSString *sqlString = nil;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"value=%@", value);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attributeName=%@",
			attributeName);

  attribute = [_entity attributeForPath: attributeName];

  NSAssert2(attribute,
	    @"No attribute for path \"%@\" in entity \"%@\"",
	    attributeName,
            [_entity name]);

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attribute=%@", attribute);

  if ([self shouldUseBindVariableForAttribute: attribute]
      || [self mustUseBindVariableForAttribute: attribute])
    {
      //TODO verify
      NSDictionary *binding;

      binding = [self bindVariableDictionaryForAttribute: attribute
		      value: value];
      [_bindings addObject: binding];
      
      sqlString = [binding objectForKey: EOBindVariablePlaceHolderKey];
    }
  else
    {
      //attr externalType 
      EOFLOGObjectLevelArgs(@"EOSQLExpression", @" value=%@ class=%@",
			    value, [value class]);
      EOFLOGObjectLevelArgs(@"EOSQLExpression", @" self %@ class=%@",
			    self, [self class]);
      //call attribute entity
      //call entity model

      sqlString = [[self class] formatValue: value
				forAttribute: attribute]; //??
      EOFLOGObjectLevelArgs(@"EOSQLExpression", @" sqlString=%@", sqlString);

      NSAssert4([sqlString length] > 0,
		@"No sqlString (%p) for value '%@' (class %@) for Attribute '%@'",
                sqlString, value, [value class], attribute);

      //??? Mirko:
      sqlString = [[self class] formatSQLString: sqlString
				format: [attribute readFormat]];
    }

  EOFLOGObjectFnStopCond(@"EOSQLExpression");
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);

  return sqlString;
}

- (NSString *)sqlStringForAttribute: (EOAttribute *)attribute
{
  NSString *sqlString = nil;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attribute=%@",
			attribute);

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sFlattened=%s",
			([attribute isFlattened] ? "YES" : "NO"));

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"_definitionArray=%@",
			[attribute _definitionArray]);

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"_definitionArray count=%d",
			[[attribute _definitionArray]count]);

  if ([attribute isFlattened])
    {
      sqlString = [self sqlStringForAttributePath:
			  [attribute _definitionArray]];

      NSAssert1(sqlString, @"No sqlString for flattened attribute: %@",
		attribute);
    }
//mirko:
/*
else if([attribute isDerived] == YES)
    return [attribute definition];
*/
  else
    {
      if (![self useAliases])//OK
        {
          sqlString = [attribute columnName];
          EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);
        }
      else
        {
          //TODO VERIFY en select: return  t0.abbrev
          NSEnumerator *relationshipEnum;
          NSEnumerator *defEnum = nil;
          NSArray *defArray, *attrArray = nil;
          NSString *relationshipPath;
          NSString *relationshipString = nil;
          EOEntity *currentEntity = nil;

          relationshipEnum = [_aliasesByRelationshipPath keyEnumerator];
          while ((relationshipPath = [relationshipEnum nextObject]))
            {
              currentEntity = _entity;
              EOFLOGObjectLevelArgs(@"EOSQLExpression",@"relationshipPath=%@",relationshipPath);
              
              if (![relationshipPath isEqualToString: @""])
                {
                  defArray = [relationshipPath componentsSeparatedByString:
						 @"."];
                  defEnum = [defArray objectEnumerator];

                  while ((relationshipString = [defEnum nextObject]))
                    {
                      // use anyRelationshipNamed: to find hidden relationship too
                      EORelationship *relationship=[currentEntity
                                                     anyRelationshipNamed: relationshipString];

                      EOFLOGObjectLevelArgs(@"EOSQLExpression",
					    @"relationshipString=%@",
					    relationshipString);

                      NSAssert2(relationship,
                                @"No relationship named %@ in entity %@",
                                relationshipString,
                                [currentEntity name]);

                      NSAssert2(currentEntity,
                                @"No destination entity. Entity %@ relationship = %@",
                                [currentEntity name],
                                relationship);

                      currentEntity = [relationship destinationEntity];
                    } // TODO entity
                }

              attrArray = [currentEntity attributes];
              EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attrArray=%@",
				    attrArray);

              if (attrArray)
                {
                  if ([attrArray containsObject: attribute])
                    {
                      NSString *columnName = [attribute columnName];

                      EOFLOGObjectLevelArgs(@"EOSQLExpression",
					    @"columnName=%@", columnName);

                      if (!columnName)
                        {
                          NSEmitTODO();  //TODO what to do when there's no column name (definition only like "((firstName || ' ') || lastName)") ?

                          EOFLOGObjectLevelArgs(@"EOSQLExpression",
						@"attribute=%@",
						attribute);
                          EOFLOGObjectLevelArgs(@"EOSQLExpression",
						@"columnName=%@", columnName);
                          EOFLOGObjectLevelArgs(@"EOSQLExpression",
						@"attrArray=%@", attrArray);
                          EOFLOGObjectLevelArgs(@"EOSQLExpression",
						@"relationshipPath=%@",
						relationshipPath);
                        }

                      NSAssert1(columnName, @"No columnName for attribute %@",
				attribute);

                      sqlString = [NSString stringWithFormat: @"%@.%@",
					    [_aliasesByRelationshipPath
					      objectForKey: relationshipPath],
					    columnName];
                      EOFLOGObjectLevelArgs(@"EOSQLExpression",
					    @"sqlString=%@", sqlString);
                    }
                }
            }

          EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@",
				sqlString);
        }

      NSAssert1(sqlString, @"No SQLString for attribute %@", attribute);
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);
  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return sqlString;
}

- (NSString *)sqlStringForAttributePath: (NSArray *)path
{
  NSString *sqlString = nil;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"path=%@", path);

  if (!_flags.useAliases)
    {
      sqlString = [(EOAttribute *)[path lastObject] columnName];

      NSAssert2(sqlString,
		@"No sqlString for path: %@ (lastObject=%@) (!_useAliases)",
                path,
                [path lastObject]);
    }
  else
    {
      NSMutableString *relationshipPathString = [NSMutableString string];
      int i, count = [path count];
      
      if (count > 1)
        {
          for (i = 0; i < (count - 1); i++)
            {
              EORelationship* relationship = nil;
              if (i > 0) 
                [relationshipPathString appendString: @"."];

              relationship = [path objectAtIndex:i];
              EOFLOGObjectLevelArgs(@"EOSQLExpression", @"[path objectAtIndex:%d]=%@",
                                    i, relationship);

              NSAssert2([relationship isKindOfClass:[EORelationship class]],
                        @"'%@' is not a relationship but a %@",
                        relationship,
                        [relationship class]);

              [relationshipPathString appendString: [relationship name]];
            }

          EOFLOGObjectLevelArgs(@"EOSQLExpression", @"[path lastObject]=%@",
                                [path lastObject]);

          //TODO
          if ([[path lastObject] isDerived])
            {
              //call attribute      _definitionArray 
              NSEmitTODO();  //TODO
              [self notImplemented:_cmd]; 
            };

          sqlString = [self _aliasForRelatedAttribute: [path lastObject] 
			    relationshipPath: relationshipPathString];

          NSAssert2(sqlString,
		    @"No sqlString for path: %@ (lastObject=%@) (_useAliases)",
                    path,
                    [path lastObject]);
        }
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"path=%@ sqlString=%@", 
                        path, sqlString);

  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return sqlString;
}

- (void)appendItem: (NSString *)itemString
      toListString: (NSMutableString *)listString
{
  //OK
  NSAssert1(listString,@"No list string when appending %@",itemString);

  if (listString)
    {
#if 0
      str = [listString cString];
      while (*str)
        {
          if (!isspace(*str++))
            [listString appendString: @", "];
        }
#endif
      
      if ([listString length])
        [listString appendString: @", "];

      [listString appendString: itemString];
    }
}

+ (NSString *)sqlPatternFromShellPattern: (NSString *)pattern
{
  NSString* sqlPattern=nil;
  int patternLength=[pattern length];
  if (patternLength==0)
    sqlPattern=pattern;
  else
    {
      const char *s, *p, *init = [pattern cString];
      NSMutableString *str = [NSMutableString stringWithCapacity:
                                                patternLength];
      IMP appendStringIMP = [str methodForSelector:@selector(appendString:)];

      for (s = p = init; *s; s++)
        {
          switch (*s)
            {
            case '*':
              if (s != p)
                GDL2_AppendStringWithImp(str,appendStringIMP,
                                        GDL2_StringWithCStringAndLength(p,s-p));
              [str appendString: @"%"];
              p = s+1;
              break;
            case '?':
              if (s != p)
                GDL2_AppendStringWithImp(str,appendStringIMP,
                                        GDL2_StringWithCStringAndLength(p,s-p));
              GDL2_AppendStringWithImp(str,appendStringIMP,@"_");
              p = s+1;
              break;
            case '%':
              if (s != p)
                GDL2_AppendStringWithImp(str,appendStringIMP,
                                        GDL2_StringWithCStringAndLength(p,s-p));
              
              if (s != init && *(s-1) == '[' && *(s+1) == ']')
                {
                  GDL2_AppendStringWithImp(str,appendStringIMP,@"%]");
                  p = s+2; s++;
                }
              else
                {
                  GDL2_AppendStringWithImp(str,appendStringIMP,@"[%]");
                  p = s+1;
                }
              break;
            case '_':
              if (s != p)
                GDL2_AppendStringWithImp(str,appendStringIMP,
                                        GDL2_StringWithCStringAndLength(p,s-p));
              
              if (s != init && *(s-1) == '[' && *(s+1) == ']')
                {
                  GDL2_AppendStringWithImp(str,appendStringIMP,@"_]");
                  p = s+2; p++;
                }
              else
                {
                  GDL2_AppendStringWithImp(str,appendStringIMP,@"[_]");
                  p = s+1;
                }
              break;
            }
        }
      
      if (*p)
        GDL2_AppendStringWithImp(str,appendStringIMP,[NSString stringWithCString: p]);
      sqlPattern=str;
    };

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"pattern=%@ => %@",
			pattern,sqlPattern);

  return sqlPattern;
}

+ (NSString *)sqlPatternFromShellPattern: (NSString *)pattern
                     withEscapeCharacter: (unichar)escapeCharacter
{
  const char *s, *p, *init = [pattern cString];
  NSMutableString *str = [NSMutableString stringWithCapacity:
					    [pattern length]];
  IMP appendStringIMP = [str methodForSelector:@selector(appendString:)];

  for (s = p = init; *s; s++)
    {
      switch (*s)
        {
	case '*':
	  if (s != p)
	    GDL2_AppendStringWithImp(str,appendStringIMP,
                                    GDL2_StringWithCStringAndLength(p,s-p));
	  GDL2_AppendStringWithImp(str,appendStringIMP,@"%");
	  p = s+1;
	  break;
	case '?':
	  if (s != p)
	    GDL2_AppendStringWithImp(str,appendStringIMP,
                                    GDL2_StringWithCStringAndLength(p,s-p));
	  GDL2_AppendStringWithImp(str,appendStringIMP,@"_");
	  p = s+1;
	  break;
	case '%':
	  if (s != p)
	    GDL2_AppendStringWithImp(str,appendStringIMP,
                                    GDL2_StringWithCStringAndLength(p,s-p));
	  
	  if (s != init && *(s-1) == '[' && *(s+1) == ']')
	    {
	      GDL2_AppendStringWithImp(str,appendStringIMP,@"%]");
	      p = s+2; s++;
	    }
	  else
	    {
	      GDL2_AppendStringWithImp(str,appendStringIMP,@"[%]");
	      p = s+1;
	    }
	  break;
	case '_':
	  if (s != p)
	    GDL2_AppendStringWithImp(str,appendStringIMP,
                                    GDL2_StringWithCStringAndLength(p,s-p));
	  
	  if (s != init && *(s-1) == '[' && *(s+1) == ']')
	    {
	      GDL2_AppendStringWithImp(str,appendStringIMP,@"_]");
	      p = s+2; p++;
	    }
	  else
	    {
	      GDL2_AppendStringWithImp(str,appendStringIMP,@"[_]");
	      p = s+1;
	    }
	  break;
        }
    }

  if (*p)
    GDL2_AppendStringWithImp(str,appendStringIMP,[NSString stringWithCString:p]);

  return str;
}

- (NSMutableDictionary *)bindVariableDictionaryForAttribute: (EOAttribute *)attribute
                                                      value: (id)value
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL)shouldUseBindVariableForAttribute: (EOAttribute *)att
{
  return NO;
}

- (BOOL)mustUseBindVariableForAttribute: (EOAttribute *)att
{
  return NO;
}

+ (BOOL)useBindVariables
{
  return [[NSUserDefaults standardUserDefaults]
	   boolForKey: @"EOAdaptorUseBindVariables"];
}

+ (void)setUseBindVariables:(BOOL)flag
{
  NSString *yn = (flag ? @"YES" : @"NO");

  [[NSUserDefaults standardUserDefaults]
    setObject:yn forKey:@"EOAdaptorUseBindVariables"];
}

- (NSArray *)bindVariableDictionaries
{
  return _bindings;
}

- (void)addBindVariableDictionary:(NSMutableDictionary *)binding
{
  [_bindings addObject:binding];
}

@end /* EOSQLExpression */


@implementation EOSQLExpression (EOSQLExpressionPrivate)
- (EOEntity*)_rootEntityForExpression
{
  //return [self notImplemented:_cmd]; //TODO
  return _entity;
};

/** Return the alias (t0,t1,...) for the relationshipPath
This add a new alias if there not already one
This also add alias for all relationships used by relationshipPath (so joinExpression can build join expressions for really all used relationships)
All relationshipPaths in _aliasesByRelationshipPath are direct paths **/
- (NSString*) _aliasForRelationshipPath:(NSString*)relationshipPath
{
  //OK ?
  NSString *flattenRelPath;
  NSMutableString *mutableFlattenRelPath;
  NSString *alias = nil;
  NSMutableArray *pathElements;
  int count = 0;
  int contextStackCurrentIndex = 0;
  
  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  contextStackCurrentIndex = [_contextStack count];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"relationshipPath=%@",
			relationshipPath);
  NSAssert(relationshipPath, @"No relationshipPath");

  if ([relationshipPath length] == 0) // "" relationshipPath is handled by _aliasesByRelationshipPath lookup
    flattenRelPath = relationshipPath;
  else
    // Find real path
    flattenRelPath = [self _flattenRelPath: relationshipPath
			   entity: _entity];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"flattenRelPath=\"%@\"",
			flattenRelPath);

  mutableFlattenRelPath = [[flattenRelPath mutableCopy] autorelease];
  pathElements = [[[mutableFlattenRelPath componentsSeparatedByString: @"."]
		    mutableCopy] autorelease];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"pathElements=%@", pathElements);

  count = [pathElements count];

  while (count > 0)
    {
      NSString *tmpAlias = nil;

      EOFLOGObjectLevelArgs(@"EOSQLExpression",@"count=%d flattenRelPath=%@",
			    count,
			    mutableFlattenRelPath);

      tmpAlias = [_aliasesByRelationshipPath objectForKey:
					       mutableFlattenRelPath];

      if (!tmpAlias)
        {
          NSString* tmpRelPath=nil;
          tmpAlias = [NSString stringWithFormat: @"t%d", _alias++];

          EOFLOGObjectLevelArgs(@"EOSQLExpression", @"add alias %@ for %@",
				tmpAlias, mutableFlattenRelPath);

          tmpRelPath = [[mutableFlattenRelPath copy]
                         autorelease]; //immuable key !
          [_aliasesByRelationshipPath setObject: tmpAlias
                                      forKey: tmpRelPath]; 

          // Insert to ensure logical order (i.e. xx BEFORE xx.yy)
          [_contextStack insertObject:tmpRelPath
                         atIndex:contextStackCurrentIndex];
          EOFLOGObjectLevelArgs(@"EOSQLExpression", @"inserted '%@' (%@) in contextStack => %@",
                                tmpRelPath,tmpAlias,_contextStack);
        }

      if (!alias)
        alias = tmpAlias;
      if (count > 0)
        {
          NSString *part = [pathElements lastObject];

          if (count > 1 || [part length] > 0) //we may have only "" as original path
            [mutableFlattenRelPath deleteSuffix: part];

          if (count > 1)
            [mutableFlattenRelPath deleteSuffix: @"."];

          [pathElements removeLastObject];
        }

      count--;
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"alias=%@", alias);
  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return alias;
}

- (NSString*) _flattenRelPath: (NSString*)relationshipPath
                       entity: (EOEntity*)entity

{
  // near OK
  NSMutableString *flattenRelPath = [NSMutableString string];
  EORelationship *relationship = nil;
  NSArray *pathElements = nil;
  int i, count;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  NSAssert(relationshipPath, @"No relationshipPath");
  NSAssert([relationshipPath length] > 0, @"Empty relationshipPath");

  pathElements = [relationshipPath componentsSeparatedByString: @"."];
  count = [pathElements count];

  for (i = 0; i < count; i++)
    {
      NSString *relPath = nil;
      NSString *part = [pathElements objectAtIndex: i];

      // use anyRelationshipNamed: to find hidden relationship too
      relationship = [entity anyRelationshipNamed: part];
      NSAssert2(relationship,
		@"no relationship named %@ in entity %@",
		part,
		[entity name]);

      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"i=%d part=%@ rel=%@",
			    i, part, relationship);

      // We check if there's outer join has some adaptors may buld things 
      // differently in this case
      if (!_flags.hasOuterJoin && [relationship joinSemantic]!=EOInnerJoin)
        _flags.hasOuterJoin=YES;

      if ([relationship isFlattened])
        {
          NSString *definition = [relationship definition];

          EOFLOGObjectLevelArgs(@"EOSQLExpression",
				@"definition=%@ relationship=%@",
				definition,
				relationship);

          relPath = [self _flattenRelPath: definition
			  entity: entity];
        }
      else
        relPath = [relationship name];

      if (i > 0)
        [flattenRelPath appendString: @"."];

      [flattenRelPath appendString: relPath];

      entity = [relationship destinationEntity];
      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"entity name=%@",
			    [entity name]);
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"flattenRelPath=%@",
			flattenRelPath);
  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return flattenRelPath;
}

- (NSString*) _sqlStringForJoinSemantic: (EOJoinSemantic)joinSemantic
			  matchSemantic: (int)param1
{
  return [self notImplemented: _cmd]; //TODO
}

- (NSString*) _aliasForRelatedAttribute: (EOAttribute*)attribute
                       relationshipPath: (NSString*)relationshipPath

{
  NSString *alias = nil;
  NSString *relPathAlias = nil;
  NSString *attributeColumnName = nil;

  EOFLOGObjectFnStartCond(@"EOSQLExpression");

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attribute=%@", attribute);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"relationshipPath=%@",
			relationshipPath);

  relPathAlias = [self _aliasForRelationshipPath: relationshipPath]; //ret "t1"
  attributeColumnName = [attribute columnName]; // ret "label"
  attributeColumnName = [self sqlStringForSchemaObjectName:
				attributeColumnName]; // ret quoted columnName

  NSAssert1([relPathAlias length]>0,@"no relPathAlias or empty relPathAlias ('%@')",
            relPathAlias);
  NSAssert1([attributeColumnName length]>0,@"no attributeColumnName or empty attributeColumnName ('%@')",
            attributeColumnName);

  alias = [NSString stringWithFormat: @"%@.%@",
		    relPathAlias,
		    attributeColumnName];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"alias=%@", alias);
  EOFLOGObjectFnStopCond(@"EOSQLExpression");

  return alias;//Like t1.label
}

- (id) _entityForRelationshipPath: (id)param0
                           origin: (id)param1
{
  return [self notImplemented: _cmd]; //TODO
}

@end

@implementation NSString (EOSQLFormatting)

- (NSString *)sqlString
{
  return self;
}

@end


@implementation NSNumber (EOSQLFormatting)

- (NSString *)sqlString
{
  return [self stringValue];
}

@end

@implementation NSObject (EOSQLFormatting)

- (NSString *)sqlString
{
  return [self description];
}

@end

