/** 
   EODatabaseChannel.m <title>EODatabaseChannel</title>

   Copyright (C) 2000-2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Date: June 2000

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
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSException.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSDebug.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef GNUSTEP
#include <GNUstepBase/GNUstep.h>
#include <GNUstepBase/NSDebug+GNUstepBase.h>
#include <GNUstepBase/NSObject+GNUstepBase.h>
#endif

#include <EOControl/EOEditingContext.h>
#include <EOControl/EOKeyValueCoding.h>
#include <EOControl/EOFetchSpecification.h>
#include <EOControl/EOClassDescription.h>
#include <EOControl/EOKeyGlobalID.h>
#include <EOControl/EOObjectStore.h>
#include <EOControl/EODebug.h>

#include <EOAccess/EODatabaseChannel.h>
#include <EOAccess/EODatabaseContext.h>
#include <EOAccess/EODatabase.h>

#include <EOAccess/EOAdaptor.h>
#include <EOAccess/EOAdaptorChannel.h>
#include <EOAccess/EOAdaptorContext.h>
#include <EOAccess/EOEntity.h>
#include <EOAccess/EOAttribute.h>
#include <EOAccess/EORelationship.h>
#include <EOAccess/EOModel.h>
#include <EOAccess/EOAccessFault.h>
#include <EOAccess/EOSQLExpression.h>
#include <EOAccess/EOSQLQualifier.h>

#include "EOPrivate.h"
#include "EOEntityPriv.h"
#include "EODatabaseContextPriv.h"
#include "EODatabaseChannelPriv.h"

@implementation EODatabaseChannel

+ (void)initialize
{
  static BOOL initialized=NO;
  if (!initialized)
    {
      initialized=YES;
      GDL2_EOAccessPrivateInit();
      [[NSNotificationCenter defaultCenter]
        addObserver: self
        selector: @selector(_registerDatabaseChannel:)
        name: EODatabaseChannelNeededNotification
        object: nil];
    }
}

+ (void)_registerDatabaseChannel: (NSNotification *)notification
{
  // TODO who release it ?
  [[EODatabaseChannel alloc] initWithDatabaseContext: [notification object]];
}

+ (EODatabaseChannel*)databaseChannelWithDatabaseContext: (EODatabaseContext *)databaseContext
{
  return [[[self alloc] initWithDatabaseContext: databaseContext] autorelease];
}

- (id) init
{
  [NSException raise: NSInvalidArgumentException
              format: @"Use initWithDatabaseContext to init an instance of class %@",
                      NSStringFromClass([self class])];
  
  return nil;
}

- (id) initWithDatabaseContext:(EODatabaseContext *)databaseContext
{
  if ((self = [super init]))
    {
      ASSIGN(_adaptorChannel, [[databaseContext adaptorContext]
				createAdaptorChannel]);
      
      if (!_adaptorChannel)
      {
        [NSException raise: NSInternalInconsistencyException
                    format: @"EODatabaseChannel is unable to obtain new channel from %@",
                            [databaseContext adaptorContext]];      
      } else {
        ASSIGN(_databaseContext, databaseContext);
      }
    }

  return self;
}

- (void)dealloc
{
  [_databaseContext unregisterChannel: self];

  DESTROY(_databaseContext);
  [_adaptorChannel closeChannel];

  DESTROY(_adaptorChannel);
  DESTROY(_currentEntity);
  DESTROY(_currentEditingContext);
  DESTROY(_fetchProperties);
  DESTROY(_fetchSpecifications);

  [super dealloc];
}

- (void)setCurrentEntity: (EOEntity *)entity
{
  //OK
  ASSIGN(_currentEntity, entity);
  [self setEntity: entity];
}

- (void) setEntity: (EOEntity *)entity
{
  //Near OK
  NSArray *relationships = [entity relationships];
  int i = 0;
  int count = [relationships count];

  EOFLOGObjectLevelArgs(@"gsdb", @"relationships=%@", relationships);

  for (i = 0; i < count; i++)
    {
      EORelationship *relationship = [relationships objectAtIndex:i];
      EOEntity *destinationEntity = [relationship destinationEntity];
      EOModel *destinationEntityModel = [destinationEntity model];
      EOEntity *entity = [relationship entity];
      EOModel *entityModel = [entity model];

      EOFLOGObjectLevelArgs(@"gsdb", @"relationship=%@", relationship);
      EOFLOGObjectLevelArgs(@"gsdb", @"destinationEntity=%@", [destinationEntity name]);

      NSAssert2(destinationEntity, @"No destinationEntity in relationship: %@ of entity %@",
                relationship, [entity name]); //TODO: flattened relationship

      EOFLOGObjectLevelArgs(@"gsdb", @"entity=%@", [entity name]);
      EOFLOGObjectLevelArgs(@"gsdb", @"destinationEntityModel=%p", destinationEntityModel);
      EOFLOGObjectLevelArgs(@"gsdb", @"entityModel=%p", entityModel);

      //If different: try to add destinationEntityModel
      if (destinationEntityModel != entityModel)
        {
          EOEditingContext *editingContext = [self currentEditingContext];
          //EODatabaseContext *databaseContext = [self databaseContext];
          EOObjectStore *rootObjectStore = [editingContext rootObjectStore];
          NSArray *cooperatingObjectStores =
	    [(EOObjectStoreCoordinator *)rootObjectStore
					 cooperatingObjectStores];
          int cosCount = [cooperatingObjectStores count];
          int i;

          for (i = 0; i < cosCount; i++)
            {
              id objectStore = [cooperatingObjectStores objectAtIndex: i];
              EODatabase *objectStoreDatabase = [objectStore database];
              BOOL modelOK = [objectStoreDatabase
			       addModelIfCompatible: destinationEntityModel];

              if (!modelOK)
                {
                  /*EODatabase *dbDatabase = [[[EODatabase alloc]
		    initWithModel: destinationEntityModel] autorelease];*/
                  [self notImplemented: _cmd]; //TODO: finish it
                }
            }
        }
    }
}

- (void)setCurrentEditingContext: (EOEditingContext*)context
{
  if (context) {
    EOCooperatingObjectStore *cooperatingObjectStore = [self databaseContext];
    EOObjectStore *objectStore = [context rootObjectStore];
    
    [(EOObjectStoreCoordinator*)objectStore
     addCooperatingObjectStore: cooperatingObjectStore];
  }
  
  ASSIGN(_currentEditingContext, context);
}

- (void)selectObjectsWithFetchSpecification: (EOFetchSpecification *)fetchSpecification
			     editingContext: (EOEditingContext *)context
{
  //should be OK
  NSString *entityName = nil;
  EODatabase *database = nil;
  EOEntity *entity = nil;
  EOQualifier *qualifier = nil;
  EOQualifier *schemaBasedQualifier = nil;



  entityName = [fetchSpecification entityName];
  database = [_databaseContext database];

  EOFLOGObjectLevelArgs(@"gsdb", @"database=%@", database);

  entity = [database entityNamed: entityName];

  EOFLOGObjectLevelArgs(@"gsdb", @"entity name=%@", [entity name]);

  qualifier=[fetchSpecification qualifier];

  EOFLOGObjectLevelArgs(@"gsdb", @"qualifier=%@", qualifier);

  schemaBasedQualifier =
    [(id<EOQualifierSQLGeneration>)qualifier
				   schemaBasedQualifierWithRootEntity: entity];

  EOFLOGObjectLevelArgs(@"gsdb", @"schemaBasedQualifier=%@", schemaBasedQualifier);
  EOFLOGObjectLevelArgs(@"gsdb", @"qualifier=%@", qualifier);

  if (schemaBasedQualifier && schemaBasedQualifier != qualifier)
    {
      EOFetchSpecification *newFetch = nil;

      EOFLOGObjectLevelArgs(@"gsdb", @"fetchSpecification=%@", fetchSpecification);
      //howto avoid copy of uncopiable qualifiers (i.e. those who contains uncopiable key or value)

      EOFLOGObjectLevelArgs(@"gsdb", @"fetchSpecification=%@", fetchSpecification);

      newFetch = [[fetchSpecification copy] autorelease];
      EOFLOGObjectLevelArgs(@"gsdb", @"newFetch=%@", newFetch);

      [newFetch setQualifier: schemaBasedQualifier];
      EOFLOGObjectLevelArgs(@"gsdb", @"newFetch=%@", newFetch);

      fetchSpecification = newFetch;
    }

  EOFLOGObjectLevelArgs(@"gsdb", @"%@ -- %@ 0x%x: isFetchInProgress=%s",
	       NSStringFromSelector(_cmd),
	       NSStringFromClass([self class]),
	       self,
	       ([self isFetchInProgress] ? "YES" : "NO"));

  [self _selectWithFetchSpecification:fetchSpecification
        editingContext:context];


}

- (id)fetchObject
{
  //seems OK
  EODatabase *database=nil;
  id object = nil;
  
  database = [_databaseContext database];
  
  if (![self isFetchInProgress])
  {    
    [NSException raise: NSInvalidArgumentException
                format: @"%@ -- %@ 0x%x: no fetch in progress",
     NSStringFromSelector(_cmd),
     NSStringFromClass([self class]),
     self];      
  }
  else
  {
    NSArray *propertiesToFetch=nil;
    NSDictionary *row =nil;
    
    NSAssert(_currentEditingContext, @"No current editing context");
    NSAssert(_adaptorChannel,@"No adaptor channel");
    
    propertiesToFetch = [self _propertiesToFetch];
    
    row = [_adaptorChannel fetchRowWithZone: NULL];
    
    if (!row)
    {
      //TODO
      //VERIFY
      /*
       if no more obj:
       if transactionNestingLevel
       adaptorContext transactionDidCommit
       */
      
      return nil;
    }
    else if([[_fetchSpecifications lastObject] fetchesRawRows])  // Testing against only one should be enough
    {
      object = [NSDictionary dictionaryWithDictionary:row];
    }
    else
    {
      BOOL isObjectNew = YES; //TODO used to avoid double fetch. We should see how to do when isRefreshingObjects == YES
      EOGlobalID *gid;
      NSDictionary *snapshot = nil;
      
      NSAssert(_currentEntity, @"Not current Entity");
      
      gid = [_currentEntity globalIDForRow: row
                                   isFinal: YES];//OK
      
      object = [_currentEditingContext objectForGlobalID: gid]; //OK //nil
      
      if (object)
        isObjectNew = NO;
      
      NSAssert(_databaseContext,@"No database context");
      
      snapshot = [_databaseContext snapshotForGlobalID: gid]; //OK
      
      if (snapshot)
      {        
        //mirko:
        if((_delegateRespondsTo.shouldUpdateSnapshot == NO
            && ([self isLocking] == YES
                || [self isRefreshingObjects] == YES))
           || (_delegateRespondsTo.shouldUpdateSnapshot == YES
               && (row = (id)[_delegate databaseContext: _databaseContext
                            shouldUpdateCurrentSnapshot: snapshot
                                            newSnapshot: row
                                               globalID: gid
                                        databaseChannel: self])))
        { // TODO delegate not correct !
          
          [_databaseContext recordSnapshot: row
                               forGlobalID: gid];
          isObjectNew = YES; //TODO
        }
      }
      else
      {
        NSAssert(database, @"No database-context database");
        
        [database recordSnapshot: row
                     forGlobalID: gid];
      }
      
      //From mirko
      if ([self isRefreshingObjects] == YES)
      {
        [[NSNotificationCenter defaultCenter]
         postNotificationName: EOObjectsChangedInStoreNotification
         object: _databaseContext
         userInfo: [NSDictionary dictionaryWithObject:
                    [NSArray arrayWithObject:gid]
                                               forKey: EOUpdatedKey]]; //OK ?
      }
      
      if (!object)
      {
        EOClassDescription *entityClassDescripton = [_currentEntity classDescriptionForInstances];
        
        object = [entityClassDescripton createInstanceWithEditingContext: _currentEditingContext
                                                                globalID: gid
                                                                    zone: NULL];
        
        NSAssert1(object, @"No Object. entityClassDescripton=%@", entityClassDescripton);
        
        EOEditingContext_recordObjectGlobalIDWithImpPtr(_currentEditingContext,
                                                        NULL,object,gid);
      }
      else if (object && [EOFault isFault: object])
      {
        EOAccessFaultHandler *handler = (EOAccessFaultHandler *)
        [EOFault handlerForFault: object];
        EOKeyGlobalID *handlerGID = (EOKeyGlobalID *)[handler globalID];
        
        isObjectNew = YES; //TODO
        [handlerGID isFinal]; //YES //TODO
        [EOFault clearFault: object];
        
        /*mirko:
         [_databaseContext _removeBatchForGlobalID:gid
         fault:obj];
         
         [EOFault clearFault:obj];
         */
      }
      
      if (isObjectNew) //TODO
      {
        if ((!object) || ([object isKindOfClass:[EOCustomObject class]] == NO)) {
          [NSException raise: NSInternalInconsistencyException
                      format: @"%s:%d cannot initialize nil/non EOCustomObject object!", __FILE__, __LINE__];      
        }
        [EOObserverCenter suppressObserverNotification];
        
        NS_DURING
        {          
          [_currentEditingContext initializeObject: object
                                      withGlobalID: gid
                                    editingContext: _currentEditingContext];
        }
        NS_HANDLER
        {
          [EOObserverCenter enableObserverNotification];
          [localException raise];
        }
        NS_ENDHANDLER;
        
        [EOObserverCenter enableObserverNotification];
        
        if ((!object) || ([object isKindOfClass:[EOCustomObject class]] == NO)) {
          [NSException raise: NSInternalInconsistencyException
                      format: @"%s:%d cannot initialize nil/non EOCustomObject object!", __FILE__, __LINE__];      
        }
        
        [object awakeFromFetchInEditingContext: _currentEditingContext];

      }
    }
  }
  
  return object;
}

- (BOOL)isFetchInProgress
{
  return [_adaptorChannel isFetchInProgress];
}

- (void)cancelFetch
{


  [self _cancelInternalFetch];

  //TODO VERIFY - NO ??!!
  [_adaptorChannel cancelFetch];
  [_fetchProperties removeAllObjects];
  [_fetchSpecifications removeAllObjects];


}

- (EODatabaseContext *)databaseContext
{
  return _databaseContext;
}

- (EOAdaptorChannel *)adaptorChannel
{
  return _adaptorChannel;
}

- (BOOL)isRefreshingObjects
{
  return _isRefreshingObjects;
}

- (void)setIsRefreshingObjects: (BOOL)yn
{
  _isRefreshingObjects = yn;
}

- (BOOL)isLocking
{
  return _isLocking;
}

- (void)setIsLocking: (BOOL)isLocking
{
  _isLocking = isLocking;
}

- (void)setDelegate: delegate
{
  _delegate = delegate;

  _delegateRespondsTo.shouldSelectObjects = 
    [delegate respondsToSelector:@selector(databaseContext:shouldSelectObjectsWithFetchSpecification:databaseChannel:)];
  _delegateRespondsTo.didSelectObjects = 
    [delegate respondsToSelector:@selector(databaseContext:didSelectObjectsWithFetchSpecification:databaseChannel:)];
  _delegateRespondsTo.shouldUsePessimisticLock = 
    [delegate respondsToSelector:@selector(databaseContext:shouldUsePessimisticLockWithFetchSpecification: databaseChannel:)];
  _delegateRespondsTo.shouldUpdateSnapshot = 
    [delegate respondsToSelector:@selector(databaseContext:shouldUpdateCurrentSnapshot:newSnapshot:globalID:databaseChannel:)];
}

- delegate
{
  return _delegate;
}


@end

@implementation EODatabaseChannel (EODatabaseChannelPrivate)
- (NSArray*) _propertiesToFetch
{
  //OK
  NSArray *attributesToFetch=nil;



  attributesToFetch = [_currentEntity _attributesToFetch];

  NSAssert(_currentEntity, @"No current Entity");



  return attributesToFetch;
}

-(void)_setCurrentEntityAndRelationshipWithFetchSpecification: (EOFetchSpecification *)fetch
{
  //OK
  NSString *entityName = [fetch entityName];
  EODatabase *database = [_databaseContext database];
  EOEntity *entity = [database entityNamed: entityName];

  NSAssert1(entity, @"No Entity named %@", entityName);

  [self setCurrentEntity: entity];
}

- (void) _buildNodeList:(id) param0
             withParent:(id) param1
{
  //TODO
  [self notImplemented: _cmd];
}

- (id) currentEditingContext
{
  return _currentEditingContext;
}

- (void) _cancelInternalFetch
{
  //OK


  if ([_adaptorChannel isFetchInProgress])
    {
      [_adaptorChannel cancelFetch];
    }


}

- (void) _closeChannel
{
  //TODO
  [self notImplemented: _cmd];
}

- (void) _openChannel
{
  //TODO
  [self notImplemented: _cmd];
}

- (void)_selectWithFetchSpecification: (EOFetchSpecification *)fetch
		       editingContext: (EOEditingContext *)context
{
  NSArray *propertiesToFetch = nil;
  EOUpdateStrategy updateStrategy = EOUpdateWithOptimisticLocking;
  BOOL fetchLocksObjects = NO;
  BOOL refreshesRefetchedObjects = NO;
  NSString *entityName = nil;
  EODatabase *database = nil;
  EOEntity *entity = nil;
  NSArray *primaryKeyAttributes = nil;
  NSDictionary *hints = nil;
  EOModel *model = nil;
  EOModelGroup *modelGroup = nil;
  EOQualifier *qualifier = nil;
  EOStoredProcedure *storedProcedure = nil;
  id customQueryExpressionHint = nil;//TODO
  EOSQLExpression *customQueryExpression = nil;//TODO
  NSString *storedProcedureName = nil;

  BOOL isDeep = NO;
  NSArray *subEntities = nil;
  NSDictionary *_hints = nil;



  _hints = [fetch _hints];

  customQueryExpressionHint = [_hints objectForKey: EOCustomQueryExpressionHintKey];//TODO use it

  if (customQueryExpressionHint)
    {
      EOAdaptorContext *adaptorContext = nil;
      EOAdaptor *adaptor = nil;
      Class expressionClass = Nil;

      EOFLOGObjectLevelArgs(@"gsdb", @"customQueryExpressionHint=%@", customQueryExpressionHint);

      adaptorContext = [_databaseContext adaptorContext];

      EOFLOGObjectLevelArgs(@"gsdb", @"adaptorContext=%p", adaptorContext);

      adaptor = [adaptorContext adaptor];

      EOFLOGObjectLevelArgs(@"gsdb", @"adaptor=%p", adaptor);
      EOFLOGObjectLevelArgs(@"gsdb", @"adaptor=%@", adaptor);
      EOFLOGObjectLevelArgs(@"gsdb", @"adaptor class=%@", [adaptor class]);

      //TODO VERIFY
      expressionClass = [adaptor expressionClass];
      EOFLOGObjectLevelArgs(@"gsdb", @"expressionClass=%@", expressionClass);

      customQueryExpression = [expressionClass expressionForString:
						 customQueryExpressionHint];

      EOFLOGObjectLevelArgs(@"gsdb", @"customQueryExpression=%@", customQueryExpression);
    }

  [self setCurrentEditingContext: context]; //OK even if customQueryExpressionHintKey
  [self _setCurrentEntityAndRelationshipWithFetchSpecification: fetch];

  isDeep = [fetch isDeep]; //ret 1

  if (!customQueryExpressionHint)
    {
      subEntities = [entity subEntities];
      EOFLOGObjectLevelArgs(@"gsdb", @"subEntities=%@", subEntities);
      
      //Strange
      {
        NSMutableArray *array = nil;

        array = [NSMutableArray arrayWithCapacity: 8];

        if ([subEntities count] > 0 && isDeep)
          {
            //??
            NSEnumerator *subEntitiesEnum = [subEntities objectEnumerator];
            id subEntity = nil;

            while ((subEntity = [subEntitiesEnum nextObject]))
              {
                EOFetchSpecification *fetchSubEntity;
                
                fetchSubEntity = [fetch copy];
                [fetchSubEntity setEntityName: [entity name]];
                
                [array addObjectsFromArray:
			 [context objectsWithFetchSpecification:
				    fetchSubEntity]];
                [fetchSubEntity release];
              }
          }
      }
    }

  propertiesToFetch = [self _propertiesToFetch];
  updateStrategy = [_databaseContext updateStrategy];//Ret 0
  fetchLocksObjects = [fetch locksObjects];
  refreshesRefetchedObjects = [fetch refreshesRefetchedObjects];
  entityName = [fetch entityName];
  database = [_databaseContext database];
  entity = [database entityNamed:entityName];
  primaryKeyAttributes = [entity primaryKeyAttributes];
  hints = [fetch hints]; // ret {} 
  storedProcedureName = [hints objectForKey: EOStoredProcedureNameHintKey];//TODO use it
  model = [entity model];
  modelGroup = [model modelGroup]; //ret nil
  //TODO if model gr
  qualifier = [fetch qualifier]; //<EOAndQualifier> //Can be nil

  if (customQueryExpression)
    {
      [_adaptorChannel evaluateExpression: customQueryExpression];

      NSAssert([propertiesToFetch count] > 0, @"No properties to fetch");

      [_adaptorChannel setAttributesToFetch: propertiesToFetch];
    }
  else
    {
      storedProcedure = [entity storedProcedureForOperation:
				  @"EOFetchWithPrimaryKeyProcedure"];

      if (storedProcedure)
        {
          NSEmitTODO();  //TODO

          [self notImplemented: _cmd];
        }

      NSAssert([propertiesToFetch count] > 0, @"No properties to fetch");

      EOFLOGObjectLevelArgs(@"gsdb", @"%@ -- %@ 0x%x: isFetchInProgress=%s",
		   NSStringFromSelector(_cmd),
		   NSStringFromClass([self class]),
		   self,
		   ([self isFetchInProgress] ? "YES" : "NO"));

      [_adaptorChannel selectAttributes: propertiesToFetch
                       fetchSpecification: fetch
                       lock: fetchLocksObjects
                       entity: entity];
    }

  EOFLOGObjectLevelArgs(@"gsdb", @"%@ -- %@ 0x%x: isFetchInProgress=%s",
	       NSStringFromSelector(_cmd),
	       NSStringFromClass([self class]),
	       self,
	       ([self isFetchInProgress] ? "YES" : "NO"));

//TODO: verify
// (stephane@sente.ch) Uncommented end to allow rawRow fetches
  if([_databaseContext updateStrategy] == EOUpdateWithPessimisticLocking
     && ![[_databaseContext adaptorContext] transactionNestingLevel])
    [NSException raise:NSInvalidArgumentException
                 format:@"%@ -- %@ 0x%x: no transaction in progress",
                 NSStringFromSelector(_cmd),
                 NSStringFromClass([self class]),
                 self];

  if(_delegateRespondsTo.shouldSelectObjects)
    {
      if(![_delegate databaseContext:_databaseContext
		     shouldSelectObjectsWithFetchSpecification:fetch
		     databaseChannel:self])
        [NSException raise:EOGeneralDatabaseException
                     format:@"%@ -- %@ 0x%x: delegate refuses to select objects",
                     NSStringFromSelector(_cmd),
                     NSStringFromClass([self class]),
                     self];
    };

  [_fetchSpecifications addObject:fetch];

//  [self setCurrentEntity:[[_databaseContext database]
//			   entityNamed:[fetch entityName]]];//done
//  [self setCurrentEditingContext:context];//done

  [self setIsLocking:([_databaseContext updateStrategy] ==
		      EOUpdateWithPessimisticLocking ?
		      YES :
		      [fetch locksObjects])];
  [self setIsRefreshingObjects:[fetch refreshesRefetchedObjects]];

//  attributesToFetch = [_currentEntity attributesToFetch];//done

//  EOFLOGObjectLevelArgs(@"gsdb",@"[_adaptorChannel class]: %@",[_adaptorChannel class]);
//  [_adaptorChannel selectAttributes:attributesToFetch
//		   fetchSpecification:fetch
//		   lock:_isLocking
//		   entity:_currentEntity];//done

  [_fetchProperties addObjectsFromArray:[self _propertiesToFetch]];

  if(_delegateRespondsTo.didSelectObjects)
    [_delegate databaseContext:_databaseContext
	       didSelectObjectsWithFetchSpecification:fetch
	       databaseChannel:self];



}

@end /* EODatabaseChannel */
