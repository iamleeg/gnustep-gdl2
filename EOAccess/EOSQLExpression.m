/** 
   EOSQLExpression.m <title>EOSQLExpression Class</title>

   Copyright (C) 2000-2002 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@rccr.cremona.it>
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

#include <string.h>

#import <Foundation/Foundation.h>

#import <Foundation/NSString.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSUtilities.h>
#import <Foundation/NSException.h>

#import <Foundation/NSException.h>

#import <EOAccess/EOEntity.h>
#import <EOAccess/EOAttribute.h>
#import <EOAccess/EOAttributePriv.h>
#import <EOAccess/EORelationship.h>
#import <EOAccess/EOAdaptor.h>
#import <EOAccess/EOAdaptorContext.h>
#import <EOAccess/EOAdaptorChannel.h>
#import <EOAccess/EOJoin.h>
#import <EOAccess/EOSQLExpression.h>
#import <EOAccess/EOSQLExpressionPriv.h>
#import <EOAccess/EOSQLQualifier.h>
#import <EOAccess/EOExpressionArray.h>
#import <EOAccess/EOSchemaGeneration.h>

#import <EOControl/EOQualifier.h>
#import <EOControl/EODebug.h>


NSString *EOBindVariableNameKey = @"EOBindVariableNameKey";
NSString *EOBindVariableAttributeKey = @"EOBindVariableAttributeKey";
NSString *EOBindVariableValueKey = @"EOBindVariableValueKey";
NSString *EOBindVariablePlaceHolderKey = @"EOBindVariablePlaceHolderKey";
NSString *EOBindVariableColumnKey = @"EOBindVariableColumnKey";


@implementation EOSQLExpression

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

+ insertStatementForRow: (NSDictionary *)row
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

+ updateStatementForRow: (NSDictionary *)row
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

+ deleteStatementWithQualifier: (EOQualifier *)qualifier
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

+ selectStatementForAttributes: (NSArray *)attributes
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
  NSEnumerator *relationshipEnum;
  NSString *relationshipPath;
  EOEntity *currentEntity;
  int i = 0;

  EOFLOGObjectFnStart();

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"entity=%@", entity);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"_aliasesByRelationshipPath=%@",
			_aliasesByRelationshipPath);

  relationshipEnum = [_aliasesByRelationshipPath keyEnumerator];
  while ((relationshipPath = [relationshipEnum nextObject]))
    {
      currentEntity = entity;

      if (i)
	[entitiesString appendString: @", "];

      if ([relationshipPath isEqualToString: @""])
        {
          NSString *externalName = [currentEntity externalName];

          EOFLOGObjectLevelArgs(@"EOSQLExpression",
				@"entity %p named %@: externalName=%@",
				currentEntity, [currentEntity name],
				externalName);

	  [entitiesString appendString: externalName];

	  if (_useAliases)
	    [entitiesString appendFormat: @" %@",
			    [_aliasesByRelationshipPath
			      objectForKey: relationshipPath]];
        }
      else
        {
	  NSEnumerator *defEnum = nil;
	  NSArray *defArray = nil;
	  NSString *relationshipString;
          NSString *externalName = nil;

	  defArray = [relationshipPath componentsSeparatedByString: @"."];
	  defEnum = [defArray objectEnumerator];
	      
	  while ((relationshipString = [defEnum nextObject]))
	    {
	      currentEntity = [[currentEntity
				 relationshipNamed: relationshipString]
				destinationEntity];
	    }

          externalName = [currentEntity externalName];

          EOFLOGObjectLevelArgs(@"EOSQLExpression",
				@"entity %p named %@: externalName=%@",
				currentEntity, [currentEntity name],
				externalName);

	  [entitiesString appendString: externalName];

	  if (_useAliases)
            {
              NSString *alias = [_aliasesByRelationshipPath
				  objectForKey: relationshipPath];

              [entitiesString appendFormat: @" %@",alias];

              EOFLOGObjectLevelArgs(@"EOSQLExpression",
				    @"appending alias %@ in entitiesString",
				    alias);
            }
        }

      i++;
    }

  EOFLOGObjectFnStop();

  return entitiesString;
}

- (void)prepareInsertExpressionWithRow: (NSDictionary *)row
{
  //OK
  EOEntity *rootEntity = nil;
  NSString *tableList = nil;
  NSEnumerator *rowEnum;
  NSString *attributeName;

  EOFLOGObjectFnStart();

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

  EOFLOGObjectFnStop();
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

  EOFLOGObjectFnStart();

  rowEnum = [row keyEnumerator];
  while ((attributeName = [rowEnum nextObject]))
    {
      id attribute = [_entity attributeNamed: attributeName];
      id value = [row objectForKey: attributeName];

      [self addUpdateListAttribute: attribute
            value: value];
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"qualifier=%@", qualifier);

  whereClauseString = [(<EOQualifierSQLGeneration>)qualifier sqlStringForSQLExpression: self];

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

  EOFLOGObjectFnStop();
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

  EOFLOGObjectFnStartOrCond(@"EOSQLExpression");

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

  EOFLOGObjectFnStopOrCond(@"EOSQLExpression");
}
*/

- (void)prepareSelectExpressionWithAttributes: (NSArray *)attributes
                                         lock: (BOOL)lockFlag
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

  EOFLOGObjectFnStart();

  //OK
  for (i = 0; i < count; i++)
    {
      EOAttribute *attribute = [attributes objectAtIndex: i];

      if ([attribute isFlattened])
        {
          NSEmitTODO();  //TODO???
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

  restrictingQualifier = [_entity restrictingQualifier]; //OK //nil //TODO use it !! 

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

  rootEntity=[self _rootEntityForExpression];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"rootEntity=%@",
			[rootEntity name]);

  //Build Table List
  tableList = [self tableListWithRootEntity: rootEntity];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"tableList=%@", tableList);

  //Build LockClause
  if (lockFlag)
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
		    lock: lockFlag
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

  EOFLOGObjectFnStop();
}

- (NSString *)assembleJoinClauseWithLeftName: (NSString *)leftName
                                   rightName: (NSString *)rightName
                                joinSemantic: (EOJoinSemantic)semantic
{
  NSString *op = nil;
  NSString *joinClause = nil;

  EOFLOGObjectFnStart();

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

  EOFLOGObjectFnStop();

  return joinClause;
}

- (void)addJoinClauseWithLeftName: (NSString *)leftName
                        rightName: (NSString *)rightName
                     joinSemantic: (EOJoinSemantic)semantic
{
  NSString *joinClause = nil;

  EOFLOGObjectFnStart();

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

  EOFLOGObjectFnStop();
}

/** Build join expression for all used relationships (call this) after all other query parts construction) **/
- (void)joinExpression
{
  EOEntity *entity = nil;
  NSEnumerator *relationshipEnum;
  NSString *relationshipPath;

  EOFLOGObjectFnStart();

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

  EOFLOGObjectFnStop();
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

  EOFLOGObjectFnStart();

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
    [sqlString appendFormat: @" WHERE %@ AND %@",
               whereClause, joinClause];
  else if (whereClause || joinClause)
    [sqlString appendFormat: @" WHERE %@",
               (whereClause
                ? whereClause
                : joinClause)];
  if ([orderByClause length] > 0)
    [sqlString appendFormat: @" ORDER BY %@", orderByClause];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);
  EOFLOGObjectFnStop();

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
  NSString *valueSQLString;
  NSMutableString *listString;
  NSString *attributeSQLString;

  EOFLOGObjectFnStart();

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
          //TODO
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

  EOFLOGObjectFnStop();
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

  EOFLOGObjectFnStart();

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
      //TODO
    }

  listString = [self listString];
  sqlStringToAdd = [NSString stringWithFormat: @"%@ = %@",
			     attributeSQLString,
			     valueSQLString];

  [self appendItem: sqlStringToAdd
        toListString: listString];

  EOFLOGObjectFnStop();
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

  EOFLOGObjectFnStart();

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
				value, value, [EONull null], [EONull null]);

	  if ([value isEqual: [EONull null]])
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

  EOFLOGObjectFnStop();

  return formattedValue;
}

+ (NSString *)formatSQLString: (NSString *)sqlString
                       format: (NSString *)format
{
  NSString *formatted = nil;  

  EOFLOGObjectFnStart();

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

	  while ((s = strchr(p, '%')))
	    {
	      switch (*(s + 1))
		{
		case '%':
		  [str appendString: [NSString stringWithCString: p
					       length: s-p+1]];
		  break;
		case 'P':
		  if (s != p)
		    [str appendString: [NSString stringWithCString: p
						 length: s-p]];
		  [str appendString: sqlString];
		  break;
		default:
		  if (s != p)
		    [str appendString: [NSString stringWithCString: p
						 length: s-p]];
		  break;
		}

	      p = s + 2;
	    }

	  if (*p)
	    [str appendString: [NSString stringWithCString: p]];

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

  EOFLOGObjectFnStop();

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

  EOFLOGObjectFnStart();

  count = [qualifiers count];

  for (i = 0; i < count; i++)
    {
      EOKeyValueQualifier *kvQualifier = [qualifiers objectAtIndex: i];
      NSString *tmpSqlString = [self sqlStringForKeyValueQualifier:
				       kvQualifier];

      if (tmpSqlString)
        {
          if (!sqlString)
            sqlString = (NSMutableString*)[NSMutableString string];

          if (nb > 0)
	    [sqlString appendString: operation];

	  [sqlString appendString: tmpSqlString];
	  nb++;
        }
    }

  if (nb > 1)
    {
      [sqlString insertString: @"(" atIndex: 0];
      [sqlString appendString: @")"];
    }
  else if (nb == 0)
    sqlString = nil;

  EOFLOGObjectFnStop();

  return sqlString;
}

- (NSString *)sqlStringForConjoinedQualifiers: (NSArray *)qualifiers
{
  //OK
  NSString *sqlString;

  EOFLOGObjectFnStart();

  sqlString = [self sqlStringForArrayOfQualifiers: qualifiers
                    operation: @" AND "];

  EOFLOGObjectFnStop();

  return sqlString;
}

- (NSString *)sqlStringForDisjoinedQualifiers: (NSArray *)qualifiers
{
  //OK
  NSString *sqlString;

  EOFLOGObjectFnStart();

  sqlString = [self sqlStringForArrayOfQualifiers: qualifiers
		    operation: @" OR "];

  EOFLOGObjectFnStop();

  return sqlString;
}

- (NSString *)sqlStringForNegatedQualifier:(EOQualifier *)qualifier
{
  NSString *sqlQual;

  EOFLOGObjectFnStart();

  sqlQual = [(id)qualifier sqlStringForSQLExpression: self];
  if (sqlQual)
    sqlQual = [NSString stringWithFormat:@"not (%@)", sqlQual];

  EOFLOGObjectFnStop();    

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

  EOFLOGObjectFnStart();

  key = [qualifier key];//OK
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"key=%@", key);

  value = [qualifier value];//OK
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"value=%@", value);

  attributeSQLString = [self sqlStringForAttributeNamed: key];//OK

  NSAssert1(attributeSQLString, @"No sqlStringForAttributeNamed:%@", key);
  EOFLOGObjectLevelArgs(@"EOSQLExpression",@"attributeSQLString=%@",
			attributeSQLString);

  attribute = [_entity attributeForPath: key];
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attribute=%@", attribute);

  readFormat = [attribute readFormat];

  if (readFormat)
    {
      NSEmitTODO();  //TODO
    }

  valueSQLString = [self sqlStringForValue: value
			 attributeNamed: key];//OK
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"valueSQLString=%@",
			valueSQLString);
  selectorSQLString = [self sqlStringForSelector: [qualifier selector]
			    value: value];//OK //value ?? 

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"selectorSQLString=%@",
			selectorSQLString);

  //??
  if (sel_eq([qualifier selector], EOQualifierOperatorLike))
    valueSQLString = [[self class] sqlPatternFromShellPattern: valueSQLString];
  else if (sel_eq([qualifier selector], EOQualifierOperatorCaseInsensitiveLike))
    {      
      valueSQLString = [[self class] sqlPatternFromShellPattern: valueSQLString];
      //VERIFY
      attributeSQLString = [NSString stringWithFormat: @"UPPER(%@)",
				     attributeSQLString];
      valueSQLString = [NSString stringWithFormat: @"UPPER(%@)",
				 valueSQLString];
    }

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
  EOFLOGObjectFnStop();

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

  if (sel_eq(orderSelector, EOCompareAscending))
    orderStringFormat = @"(%@) asc";
  else if (sel_eq(orderSelector, EOCompareDescending))
    orderStringFormat = @"(%@) desc";
  else if (sel_eq(orderSelector, EOCompareCaseInsensitiveAscending))
    orderStringFormat = @"upper(%@) asc";
  else if (sel_eq(orderSelector, EOCompareCaseInsensitiveDescending))
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
  _useAliases = useAliases;
}

- (BOOL)useAliases
{
  return _useAliases;
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
  NSArray *keyParts;
  NSString *key = nil;
  EOEntity *entity=_entity;
  NSMutableArray *attributePath = nil;  
  int i, count;

  EOFLOGObjectFnStart();

  NSAssert(entity,@"no entity");
  NSAssert(name,@"no attribute name");
  NSAssert([name length]>0,@"attribute name is empty");  

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"name=%@", name);

  keyParts = [name componentsSeparatedByString:@"."];
  count = [keyParts count];

  for (i = 0; i < count - 1; i++)
    {
      EORelationship *rel;

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

  NSAssert4(attribute,
            @"no attribute named %@ in entity %@\nAttributesByName=%@\nattributes=%@",
            key,
            [entity name],
            [entity attributesByName],
            [entity attributes]);

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

  EOFLOGObjectFnStop();

  return sqlString;
}

- (NSString *)sqlStringForSelector: (SEL)selector
                             value: (id)value
{
  //seems OK
  if (sel_eq(selector, EOQualifierOperatorEqual))
    {
      if ([value isKindOfClass: [[EONull null] class]])
        return @"is";
      else
        return @"=";
    }
  else if (sel_eq(selector, EOQualifierOperatorNotEqual))
    {
      if ([value isKindOfClass: [[EONull null] class]])
        return @"is not";
      else
        return @"<>";
    }
  else if (sel_eq(selector, EOQualifierOperatorLessThan))
    return @"<";
  else if (sel_eq(selector, EOQualifierOperatorGreaterThan))
    return @">";
  else if (sel_eq(selector, EOQualifierOperatorLessThanOrEqualTo))
    return @"<=";
  else if (sel_eq(selector, EOQualifierOperatorGreaterThanOrEqualTo))
    return @">=";
  else if (sel_eq(selector, EOQualifierOperatorLike))
    return @"like";
  else if (sel_eq(selector, EOQualifierOperatorCaseInsensitiveLike))
    return @"like"; //same as sensitive
/*  //TODO else if(sel_eq(selector, EOQualifierOperatorContains))
    return @"like";*/
  else
    {
      [NSException raise: NSInternalInconsistencyException
                   format: @"EOSQLExpression: Unknown selector of sqlStringForSelector:value:"];
    }

  return nil;
}

- (NSString *)sqlStringForValue: (id)value
                 attributeNamed: (NSString*)attributeName
{
  EOAttribute *attribute;
  NSString *sqlString = nil;

  EOFLOGObjectFnStart();

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

  EOFLOGObjectFnStop();
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);

  return sqlString;
}

- (NSString *)sqlStringForAttribute: (EOAttribute *)anAttribute
{
  NSString *sqlString = nil;

  EOFLOGObjectFnStart();

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"anAttribute=%@\nisFlattened=%s\n_definitionArray=%@\n_definitionArray count=%d",
			anAttribute,
			([anAttribute isFlattened] ? "YES" : "NO"),
			[anAttribute _definitionArray],
			[[anAttribute _definitionArray]count]);

  if ([anAttribute isFlattened])
    {
      sqlString = [self sqlStringForAttributePath:
			  [anAttribute _definitionArray]];

      NSAssert1(sqlString, @"No sqlString for flattened attribute: %@",
		anAttribute);
    }
//mirko:
/*
else if([anAttribute isDerived] == YES)
    return [anAttribute definition];
*/
  else
    {
      if (![self useAliases])//OK
        {
          sqlString = [anAttribute columnName];
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
                      EOFLOGObjectLevelArgs(@"EOSQLExpression",
					    @"relationshipString=%@",
					    relationshipString);

                      currentEntity = [[currentEntity
                                         relationshipNamed: relationshipString]
                                        destinationEntity];
                    } // TODO entity
                }

              attrArray = [currentEntity attributes];
              EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attrArray=%@",
				    attrArray);

              if (attrArray)
                {
                  if ([attrArray containsObject: anAttribute])
                    {
                      NSString *columnName = [anAttribute columnName];

                      if (!columnName)
                        {
                          NSEmitTODO();  //TODO what to do when there's no column name (definition only like "((firstName || ' ') || lastName)") ?

                          EOFLOGObjectLevelArgs(@"EOSQLExpression",
						@"anAttribute=%@",
						anAttribute);
                          EOFLOGObjectLevelArgs(@"EOSQLExpression",
						@"columnName=%@", columnName);
                          EOFLOGObjectLevelArgs(@"EOSQLExpression",
						@"attrArray=%@", attrArray);
                          EOFLOGObjectLevelArgs(@"EOSQLExpression",
						@"relationshipPath=%@",
						relationshipPath);
                        }

                      NSAssert1(columnName, @"No columnName for attribute %@",
				anAttribute);

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

      NSAssert1(sqlString, @"No SQLString for attribute %@", anAttribute);
    }

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"sqlString=%@", sqlString);
  EOFLOGObjectFnStop();

  return sqlString;
}

- (NSString *)sqlStringForAttributePath: (NSArray *)path
{
  NSString *sqlString = nil;

  if (!_useAliases)
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
              if (i > 0) 
                [relationshipPathString appendString: @"."];

              [relationshipPathString
		appendString: [(EORelationship *)[path objectAtIndex:i]
						 name]];
            }

          //TODO
          //call attribute      _definitionArray 
          sqlString = [self _aliasForRelatedAttribute: [path lastObject] 
			    relationshipPath: relationshipPathString];

          NSAssert2(sqlString,
		    @"No sqlString for path: %@ (lastObject=%@) (_useAliases)",
                    path,
                    [path lastObject]);
        }
    }

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
  const char *s, *p, *init = [pattern cString];
  NSMutableString *str = [NSMutableString stringWithCapacity:
					    [pattern length]];

  for (s = p = init; *s; s++)
    {
      switch (*s)
        {
	case '*':
	  if (s != p)
	    [str appendString: [NSString stringWithCString: p
					 length: s-p]];
	  [str appendString: @"%"];
	  p = s+1;
	  break;
	case '?':
	  if (s != p)
	    [str appendString:[NSString stringWithCString: p
					length: s-p]];
	  [str appendString: @"_"];
	  p = s+1;
	  break;
	case '%':
	  if (s != p)
	    [str appendString:[NSString stringWithCString: p
					length: s-p]];
	  
	  if (s != init && *(s-1) == '[' && *(s+1) == ']')
	    {
	      [str appendString: @"%]"];
	      p = s+2; s++;
	    }
	  else
	    {
	      [str appendString: @"[%]"];
	      p = s+1;
	    }
	  break;
	case '_':
	  if (s != p)
	    [str appendString:[NSString stringWithCString: p
					length: s-p]];
	  
	  if (s != init && *(s-1) == '[' && *(s+1) == ']')
	    {
	      [str appendString: @"_]"];
	      p = s+2; p++;
	    }
	  else
	    {
	      [str appendString: @"[_]"];
	      p = s+1;
	    }
	  break;
        }
    }

  if (*p)
    [str appendString: [NSString stringWithCString: p]];

  return str;
}

+ (NSString *)sqlPatternFromShellPattern: (NSString *)pattern
                     withEscapeCharacter: (unichar)escapeCharacter
{
  const char *s, *p, *init = [pattern cString];
  NSMutableString *str = [NSMutableString stringWithCapacity:
					    [pattern length]];

  for (s = p = init; *s; s++)
    {
      switch (*s)
        {
	case '*':
	  if (s != p)
	    [str appendString: [NSString stringWithCString: p
					 length: s-p]];
	  [str appendString: @"%"];
	  p = s+1;
	  break;
	case '?':
	  if (s != p)
	    [str appendString: [NSString stringWithCString: p
					 length: s-p]];
	  [str appendString: @"_"];
	  p = s+1;
	  break;
	case '%':
	  if (s != p)
	    [str appendString:[NSString stringWithCString: p
					length: s-p]];
	  
	  if (s != init && *(s-1) == '[' && *(s+1) == ']')
	    {
	      [str appendString: @"%]"];
	      p = s+2; s++;
	    }
	  else
	    {
	      [str appendString: @"[%]"];
	      p = s+1;
	    }
	  break;
	case '_':
	  if (s != p)
	    [str appendString:[NSString stringWithCString: p
					length: s-p]];
	  
	  if (s != init && *(s-1) == '[' && *(s+1) == ']')
	    {
	      [str appendString: @"_]"];
	      p = s+2; p++;
	    }
	  else
	    {
	      [str appendString: @"[_]"];
	      p = s+1;
	    }
	  break;
        }
    }

  if (*p)
    [str appendString:[NSString stringWithCString:p]];

  return str;
}

- (NSMutableDictionary *)bindVariableDictionaryForAttribute: (EOAttribute *)attribute
                                                      value: value
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
- (NSString*) _aliasForRelationshipPath:(NSString*)relationshipPath//toLanguage
{
  //OK ?
  NSString *flattenRelPath;
  NSMutableString *mutableFlattenRelPath;
  NSString *alias = nil;
  NSMutableArray *pathElements;
  int count;

  EOFLOGObjectFnStart();

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
      NSString *tmpAlias;

      EOFLOGObjectLevelArgs(@"EOSQLExpression",@"count=%d flattenRelPath=%@",
			    count,
			    mutableFlattenRelPath);

      tmpAlias = [_aliasesByRelationshipPath objectForKey:
					       mutableFlattenRelPath];

      if (!tmpAlias)
        {
          tmpAlias = [NSString stringWithFormat: @"t%d", _alias++];

          EOFLOGObjectLevelArgs(@"EOSQLExpression", @"add alias %@ for %@",
				tmpAlias, mutableFlattenRelPath);

          [_aliasesByRelationshipPath setObject: tmpAlias
                                      forKey: [[mutableFlattenRelPath copy]
						autorelease]]; //immuable key !
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
  EOFLOGObjectFnStop();

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

  EOFLOGObjectFnStart();

  NSAssert(relationshipPath, @"No relationshipPath");
  NSAssert([relationshipPath length] > 0, @"Empty relationshipPath");

  pathElements = [relationshipPath componentsSeparatedByString: @"."];
  count = [pathElements count];

  for (i = 0; i < count; i++)
    {
      NSString *relPath = nil;
      NSString *part = [pathElements objectAtIndex: i];

      relationship = [entity anyRelationshipNamed: part];

      NSAssert2(relationship,
		@"no relationship named %@ in entity %@",
		part,
		[entity name]);

      EOFLOGObjectLevelArgs(@"EOSQLExpression", @"i=%d part=%@ rel=%@",
			    i, part, relationship);

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
  EOFLOGObjectFnStop();

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
  NSString *alias;
  NSString *relPathAlias;
  NSString *attributeColumnName;

  EOFLOGObjectFnStart();

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"attribute=%@", attribute);
  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"relationshipPath=%@",
			relationshipPath);

  relPathAlias = [self _aliasForRelationshipPath: relationshipPath]; //ret "t1"
  attributeColumnName = [attribute columnName]; // ret "label"
  attributeColumnName = [self sqlStringForSchemaObjectName:
				attributeColumnName]; // ret quoted columnName

  alias = [NSString stringWithFormat: @"%@.%@",
		    relPathAlias,
		    attributeColumnName];

  EOFLOGObjectLevelArgs(@"EOSQLExpression", @"alias=%@", alias);
  EOFLOGObjectFnStop();

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


@implementation NSObject (EOSQLFormatting)

- (NSString *)sqlString
{
  return [self description];
}

@end


NSString *EOCreateTablesKey = @"EOCreateTablesKey";
NSString *EODropTablesKey = @"EODropTablesKey";
NSString *EOCreatePrimaryKeySupportKey = @"EOCreatePrimaryKeySupportKey";
NSString *EODropPrimaryKeySupportKey = @"EODropPrimaryKeySupportKey";
NSString *EOPrimaryKeyContraintsKey = @"EOPrimaryKeyContraintsKey";
NSString *EOForeignKeyConstraintsKey = @"EOForeignKeyConstraintsKey";
NSString *EOCreateDatabaseKey = @"EOCreateDatabaseKey";
NSString *EODropDatabaseKey = @"EODropDatabaseKey";


@implementation EOSQLExpression (EOSchemaGeneration)

+ (NSArray *)foreignKeyConstraintStatementsForRelationship: (EORelationship *)relationship
{
  NSMutableArray *array, *sourceColumns, *destColumns;
  EOSQLExpression *sqlExpression;
  NSEnumerator *joinEnum;
  EOJoin *join;
  int num;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  array = [NSMutableArray arrayWithCapacity: 1];

  if ([[relationship entity] model]
      != [[relationship destinationEntity] model])
    {
      EOFLOGClassFnStopOrCond(@"EOSQLExpression");

      return array;
    }

  if ([relationship isToMany] == YES
      || [[relationship inverseRelationship] isToMany] == NO)
    {
      EOFLOGClassFnStopOrCond(@"EOSQLExpression");

      return array;
    }

  sqlExpression = [self sqlExpressionWithEntity: [relationship entity]];

  num = [[relationship joins] count];

  sourceColumns = [NSMutableArray arrayWithCapacity: num];
  destColumns   = [NSMutableArray arrayWithCapacity: num];

  joinEnum = [[relationship joins] objectEnumerator];
  while ((join = [joinEnum nextObject]))
    {
      [sourceColumns addObject: [join sourceAttribute]];
      [destColumns   addObject: [join destinationAttribute]];
    }

  [sqlExpression prepareConstraintStatementForRelationship: relationship
		 sourceColumns: sourceColumns
		 destinationColumns: destColumns];

  [array addObject: sqlExpression];

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return array;
}

// default implementation verifies that relationship joins on foreign key
// of destination and calls
// prepareConstraintStatementForRelationship:sourceColumns:destinationColumns:

+ (NSArray *)createTableStatementsForEntityGroup: (NSArray *)entityGroup
{
  EOSQLExpression *sqlExp;
  NSEnumerator *entityEnum, *attrEnum;
  EOAttribute *attr;
  EOEntity *entity;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  sqlExp = [self sqlExpressionWithEntity:[entityGroup objectAtIndex: 0]];

  entityEnum = [entityGroup objectEnumerator];
  while ((entity = [entityEnum nextObject]))
    {
      attrEnum = [[entity attributes] objectEnumerator];

      while ((attr = [attrEnum nextObject]))
	[sqlExp addCreateClauseForAttribute: attr];
    }

  [sqlExp setStatement: [NSString stringWithFormat:@"CREATE TABLE %@ (%@)",
				  [[entityGroup objectAtIndex: 0] externalName],
				  [self listString]]];

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return [NSArray arrayWithObject: sqlExp];
}

+ (NSArray *)dropTableStatementsForEntityGroup:(NSArray *)entityGroup
{
  NSArray *newArray = nil;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  newArray = [NSArray arrayWithObject:
		    [self expressionForString:
			    [NSString stringWithFormat: @"DROP TABLE %@",
				      [[entityGroup objectAtIndex: 0]
					externalName]]]];

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return newArray;
}

+ (NSArray *)primaryKeyConstraintStatementsForEntityGroup:(NSArray *)entityGroup
{
  EOSQLExpression *sqlExp;
  NSMutableString *listString;
  NSEnumerator    *attrEnum;
  EOAttribute     *attr;
  EOEntity        *entity;
  BOOL             first = YES;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  entity = [entityGroup objectAtIndex: 0];
  listString = [NSMutableString stringWithCapacity: 30];

  attrEnum = [[entity primaryKeyAttributes] objectEnumerator];
  while ((attr = [attrEnum nextObject]))
    {
      NSString *columnName = [attr columnName];

      if (!columnName || ![columnName length])
	continue;

      if (first == NO)
	[listString appendString: @", "];

      [listString appendString: columnName];
      first = NO;
    }

  if (first == YES)
    {
      EOFLOGClassFnStopOrCond(@"EOSQLExpression");

      return [NSArray array];
    }

  sqlExp = [self sqlExpressionWithEntity:[entityGroup objectAtIndex: 0]];

  [sqlExp setStatement: [NSString stringWithFormat:
				    @"ALTER TABLE %@ ADD PRIMARY KEY (%@)",
				  [entity externalName],
				  listString]];

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return [NSArray arrayWithObject: sqlExp];
}

+ (NSArray *)primaryKeySupportStatementsForEntityGroup: (NSArray *)entityGroup
{
  NSArray *newArray = nil;
  NSString *seqName = nil;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  seqName = [NSString stringWithFormat: @"%@_SEQ",
		      [[entityGroup objectAtIndex: 0]
				  primaryKeyRootName]];

  newArray = [NSArray arrayWithObject:
		    [self expressionForString:
			    [NSString stringWithFormat: @"CREATE SEQUENCE %@",
				      seqName]]];
                                      
  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return newArray;
}

+ (NSArray *)dropPrimaryKeySupportStatementsForEntityGroup: (NSArray *)entityGroup
{
  NSArray *newArray = nil;
  NSString *seqName = nil;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  seqName = [NSString stringWithFormat: @"%@_SEQ",
				[[entityGroup objectAtIndex: 0]
				  primaryKeyRootName]];

  newArray = [NSArray arrayWithObject:
		    [self expressionForString:
			    [NSString stringWithFormat: @"DROP SEQUENCE %@",
				      seqName]]];

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return newArray;
}

+ (NSArray *)createTableStatementsForEntityGroups: (NSArray *)entityGroups
{
  NSMutableArray *array;
  NSEnumerator   *groupsEnum;
  NSArray        *group;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  array = [NSMutableArray arrayWithCapacity: [entityGroups count]];

  groupsEnum = [entityGroups objectEnumerator];
  while ((group = [groupsEnum nextObject]))
    {
      [array addObjectsFromArray:
	       [self createTableStatementsForEntityGroup: group]];
    }

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return array;
}

+ (NSArray *)dropTableStatementsForEntityGroups: (NSArray *)entityGroups
{
  NSMutableArray *array;
  NSEnumerator   *groupsEnum;
  NSArray        *group;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  array = [NSMutableArray arrayWithCapacity: [entityGroups count]];

  groupsEnum = [entityGroups objectEnumerator];
  while ((group = [groupsEnum nextObject]))
    {
      [array addObjectsFromArray:
	       [self dropTableStatementsForEntityGroup: group]];
    }

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return array;
}

+ (NSArray *)primaryKeyConstraintStatementsForEntityGroups: (NSArray *)entityGroups
{
  NSMutableArray *array;
  NSEnumerator   *groupsEnum;
  NSArray        *group;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  array = [NSMutableArray arrayWithCapacity: [entityGroups count]];

  groupsEnum = [entityGroups objectEnumerator];
  while ((group = [groupsEnum nextObject]))
    {
      [array addObjectsFromArray:
	       [self primaryKeyConstraintStatementsForEntityGroup: group]];
    }

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return array;
}

+ (NSArray *)primaryKeySupportStatementsForEntityGroups: (NSArray *)entityGroups
{
  NSMutableArray *array;
  NSEnumerator   *groupsEnum;
  NSArray        *group;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  array = [NSMutableArray arrayWithCapacity: [entityGroups count]];

  groupsEnum = [entityGroups objectEnumerator];
  while ((group = [groupsEnum nextObject]))
    {
      [array addObjectsFromArray:
	       [self primaryKeySupportStatementsForEntityGroup: group]];
    }

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return array;
}

+ (NSArray *)dropPrimaryKeySupportStatementsForEntityGroups: (NSArray *)entityGroups
{
  NSMutableArray *array;
  NSEnumerator   *groupsEnum;
  NSArray        *group;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  array = [NSMutableArray arrayWithCapacity: [entityGroups count]];

  groupsEnum = [entityGroups objectEnumerator];
  while ((group = [groupsEnum nextObject]))
    {
      [array addObjectsFromArray:
	       [self dropPrimaryKeySupportStatementsForEntityGroup: group]];
    }

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return array;
}

+ (void)appendExpression: (EOSQLExpression *)expression
		toScript: (NSMutableString *)script
{
  EOFLOGClassFnStartOrCond(@"EOSQLExpression");
  
  [script appendFormat:@"%@;\n", [expression statement]];
  
  EOFLOGClassFnStopOrCond(@"EOSQLExpression");
}


+ (NSString *)schemaCreationScriptForEntities: (NSArray *)entities
				      options: (NSDictionary *)options
{
  NSMutableString *script = [NSMutableString stringWithCapacity:50];
  NSEnumerator    *arrayEnum;
  EOSQLExpression *sqlExp;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  arrayEnum = [[self schemaCreationStatementsForEntities: entities
		     options: options] objectEnumerator];

  while ((sqlExp = [arrayEnum nextObject]))
    [self appendExpression: sqlExp toScript: script];

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return script;
}

struct _schema
{
  NSString *key;
  NSString *value;
  SEL       selector;
};

+ (NSArray *)schemaCreationStatementsForEntities: (NSArray *)entities
					 options: (NSDictionary *)options
{
  NSMutableArray *array = [NSMutableArray arrayWithCapacity: 5];
  NSMutableArray *groups = [NSMutableArray arrayWithCapacity: 5];
  NSMutableArray *group;
  NSString       *externalName;
  EOEntity       *entity;
  int             i, h, count;
  struct _schema  defaults[] = {
    {EOCreateTablesKey           , @"YES",
     @selector(createTableStatementsForEntityGroups:)},
    {EODropTablesKey             , @"YES",
     @selector(dropTableStatementsForEntityGroups:)},
    {EOCreatePrimaryKeySupportKey, @"YES",
     @selector(primaryKeySupportStatementsForEntityGroups:)},
    {EODropPrimaryKeySupportKey  , @"YES",
     @selector(dropPrimaryKeySupportStatementsForEntityGroups:)},
    {EOPrimaryKeyContraintsKey   , @"YES",
     @selector(primaryKeyConstraintStatementsForEntityGroups:)},
    {EOForeignKeyConstraintsKey  , @"NO",
     @selector(foreignKeyConstraintStatementsForRelationship:)},
    {nil, nil},
  };

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  count = [entities count];

  for (i = 0; i < count; i++)
    {
      entity = [entities objectAtIndex: i];
      externalName = [entity externalName];

      group = [NSMutableArray arrayWithCapacity: 1];
      [groups addObject: group];
      [group addObject: entity];

      for (h = i + 1; h < count; h++)
	{
	  if ([[[entities objectAtIndex: h] externalName]
		isEqual: externalName])
	    [group addObject: [entities objectAtIndex: h]];
	}
    }

  for (i = 0; defaults[i].key != nil; i++)
    {
      NSString *value;

      value = [options objectForKey: defaults[i].key];

      if (!value)
	value = defaults[i].value;

      if ([value isEqual: @"YES"] == YES)
	{
	  [array addObjectsFromArray:
		   [self performSelector: defaults[i].selector
			 withObject: groups]];
	}
    }

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");

  return array;
}

- (NSString *)columnTypeStringForAttribute:(EOAttribute *)attribute
{
  NSString *extType = [attribute externalType];
  int precision = [attribute precision];
  int scale = [attribute scale];

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  if (precision)
    {
      EOFLOGClassFnStopOrCond(@"EOSQLExpression");
      return [NSString stringWithFormat:@"%@(%d, %d)", extType, precision,
		       scale];
    }
  else if ([attribute width])
    {
      EOFLOGClassFnStopOrCond(@"EOSQLExpression");
      return [NSString stringWithFormat: @"%@(%d)", extType, scale];
    }
  else
    {
      EOFLOGClassFnStopOrCond(@"EOSQLExpression");
      return [NSString stringWithFormat: @"%@", extType];
    }
}

- (NSString *)allowsNullClauseForConstraint: (BOOL)allowsNull
{
  if (allowsNull == NO)
    return @"NOT NULL";

  return nil;
}

- (void)addCreateClauseForAttribute: (EOAttribute *)attribute
{
  NSString *columnType;
  NSString *allowsNull;
  NSString *str;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  columnType = [self columnTypeStringForAttribute: attribute];
  allowsNull = [self allowsNullClauseForConstraint: [attribute allowsNull]];

  if (allowsNull)
    str = [NSString stringWithFormat: @"%@ %@ %@", [attribute columnName],
		    columnType, allowsNull];
  else
    str = [NSString stringWithFormat: @"%@ %@", [attribute columnName],
		    allowsNull];

  [self appendItem:str toListString: _listString];

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");
}

- (void)prepareConstraintStatementForRelationship: (EORelationship *)relationship
				    sourceColumns: (NSArray *)sourceColumns
			       destinationColumns: (NSArray *)destinationColumns
{
  NSMutableString *sourceString, *destinationString;
  NSEnumerator    *attrEnum;
  EOAttribute     *attr;
  NSString        *name, *str;
  BOOL             first = YES;

  EOFLOGClassFnStartOrCond(@"EOSQLExpression");

  name = [NSString stringWithFormat: @"%@_%@_FK", [_entity externalName],
		   [relationship name]];

  sourceString = [NSMutableString stringWithCapacity: 30];

  attrEnum = [sourceColumns objectEnumerator];
  while ((attr = [attrEnum nextObject]))
    {
      NSString *columnName = [attr columnName];

      if (!columnName || ![columnName length])
	continue;

      if (first == NO)
	[sourceString appendString: @", "];

      [sourceString appendString: columnName];
      first = NO;
    }

  first = YES;
  destinationString = [NSMutableString stringWithCapacity: 30];

  attrEnum = [destinationColumns objectEnumerator];
  while ((attr = [attrEnum nextObject]))
    {
      NSString *columnName = [attr columnName];

      if (!columnName || ![columnName length])
	continue;

      if (first == NO)
	[destinationString appendString: @", "];

      [destinationString appendString: columnName];
      first = NO;
    }

  str = [NSString stringWithFormat: @"ALTER TABLE %@ ADD CONSTRAINT %@ FOREIGN KEY (%@) REFERENCES %@ (%@)",
		  [_entity externalName],
		  name,
		  sourceString,
		  [[relationship destinationEntity] externalName],
		  destinationString];

  ASSIGN(_statement, str);

  EOFLOGClassFnStopOrCond(@"EOSQLExpression");
}

// Assembles an adaptor specific constraint statement for relationship.

+ (NSArray *)createDatabaseStatementsForConnectionDictionary: (NSDictionary *)connectionDictionary
			  administrativeConnectionDictionary: (NSDictionary *)administrativeConnectionDictionary
{
  [self subclassResponsibility: _cmd];
  return nil;
}

+ (NSArray *)dropDatabaseStatementsForConnectionDictionary: (NSDictionary *)connectionDictionary
			administrativeConnectionDictionary: (NSDictionary *)administrativeConnectionDictionary
{
  [self subclassResponsibility: _cmd];
  return nil;
}

+ (EOSQLExpression *)selectStatementForContainerOptions
{
  [self notImplemented: _cmd];
  return nil;
}

@end