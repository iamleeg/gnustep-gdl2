/** 
   EODatabaseChannel.m <title>EODatabaseChannel</title>

   Copyright (C) 2000-2002 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@rccr.cremona.it>
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

#import <Foundation/Foundation.h>

#import <EOAccess/EOAccess.h>
#import <EOAccess/EODatabaseChannel.h>
#import <EOAccess/EODatabaseChannelPriv.h>
#import <EOAccess/EODatabaseContext.h>
#import <EOAccess/EODatabaseContextPriv.h>
#import <EOAccess/EODatabase.h>

#import <EOAccess/EOAdaptor.h>
#import <EOAccess/EOAdaptorChannel.h>
#import <EOAccess/EOEntity.h>
#import <EOAccess/EOAttribute.h>
#import <EOAccess/EORelationship.h>
#import <EOAccess/EOModel.h>
#import <EOAccess/EOAccessFault.h>

#import <EOControl/EOEditingContext.h>
#import <EOControl/EOKeyValueCoding.h>
#import <EOControl/EOFetchSpecification.h>
#import <EOControl/EOClassDescription.h>
#import <EOControl/EOGlobalID.h>
#import <EOControl/EOObjectStore.h>

@implementation EODatabaseChannel

+ (void)load
{
  [[NSNotificationCenter defaultCenter]
    addObserver: self
    selector: @selector(_registerDatabaseChannel:)
    name: EODatabaseChannelNeededNotification
    object: nil];
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

- (id) initWithDatabaseContext:(EODatabaseContext *)databaseContext
{
  if ((self = [super init]))
    {
      ASSIGN(_databaseContext, databaseContext);
      ASSIGN(_adaptorChannel, [[_databaseContext adaptorContext]
				createAdaptorChannel]);
//TODO NO<<<<
      [_adaptorChannel openChannel];
      
      _fetchProperties = [NSMutableArray new];
      _fetchSpecifications = [NSMutableArray new];
//NO>>>>>>>      
      [_databaseContext registerChannel: self];//should be in caller
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

  NSDebugMLLog(@"gsdb", @"relationships=%@", relationships);

  for (i = 0; i < count; i++)
    {
      EORelationship *relationship = [relationships objectAtIndex:i];
      EOEntity *destinationEntity = [relationship destinationEntity];
      EOModel *destinationEntityModel = [destinationEntity model];
      EOEntity *entity = [relationship entity];
      EOModel *entityModel = [entity model];

      NSDebugMLLog(@"gsdb", @"relationship=%@", relationship);
      NSDebugMLLog(@"gsdb", @"destinationEntity=%@", [destinationEntity name]);

      NSAssert2(destinationEntity, @"No destinationEntity in relationship: %@ of entity %@",
                relationship, [entity name]); //TODO: flattened relationship

      NSDebugMLLog(@"gsdb", @"entity=%@", [entity name]);
      NSDebugMLLog(@"gsdb", @"destinationEntityModel=%p", destinationEntityModel);
      NSDebugMLLog(@"gsdb", @"entityModel=%p", entityModel);

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
  //OK
  EOCooperatingObjectStore *cooperatingObjectStore = [self databaseContext];
  EOObjectStore *objectStore = [context rootObjectStore];

  [(EOObjectStoreCoordinator*)objectStore
			      addCooperatingObjectStore: cooperatingObjectStore];

  ASSIGN(_currentEditingContext, context);
}

- (void)selectObjectsWithFetchSpecification: (EOFetchSpecification *)fetch
			     editingContext: (EOEditingContext *)context
{
  //should be OK
  NSString *entityName = nil;
  EODatabase *database = nil;
  EOEntity *entity = nil;
  EOQualifier *qualifier = nil;
  EOQualifier *schemaBasedQualifier = nil;

  EOFLOGObjectFnStart();

  entityName = [fetch entityName];
  database = [_databaseContext database];

  NSDebugMLLog(@"gsdb", @"database=%@", database);

  entity = [database entityNamed: entityName];

  NSDebugMLLog(@"gsdb", @"entity name=%@", [entity name]);

  qualifier=[fetch qualifier];

  NSDebugMLLog(@"gsdb", @"qualifier=%@", qualifier);

  schemaBasedQualifier =
    [(id<EOQualifierSQLGeneration>)qualifier
				   schemaBasedQualifierWithRootEntity: entity];

  NSDebugMLLog(@"gsdb", @"schemaBasedQualifier=%@", schemaBasedQualifier);
  NSDebugMLLog(@"gsdb", @"qualifier=%@", qualifier);

  if (schemaBasedQualifier && schemaBasedQualifier != qualifier)
    {
      EOFetchSpecification *newFetch = nil;

      NSDebugMLLog(@"gsdb", @"fetch=%@", fetch);
      //howto avoid copy of uncopiable qualifiers (i.e. those who contains uncopiable key or value)

      NSDebugMLLog(@"gsdb", @"fetch=%@", fetch);

      newFetch = [[fetch copy] autorelease];
      NSDebugMLLog(@"gsdb", @"newFetch=%@", newFetch);

      [newFetch setQualifier: schemaBasedQualifier];
      NSDebugMLLog(@"gsdb", @"newFetch=%@", newFetch);

      fetch = newFetch;
    }

  NSDebugMLLog(@"gsdb", @"%@ -- %@ 0x%x: isFetchInProgress=%s",
	       NSStringFromSelector(_cmd),
	       NSStringFromClass([self class]),
	       self,
	       ([self isFetchInProgress] ? "YES" : "NO"));

  [self _selectWithFetchSpecification:fetch
        editingContext:context];

  EOFLOGObjectFnStop();
}

- (id)fetchObject
{
  //seems OK
  EODatabase *database=nil;
  id object = nil;

  EOFLOGObjectFnStart();

  database = [_databaseContext database];

  if (![self isFetchInProgress])
    {
      NSLog(@"No Fetch in progress");
      NSDebugMLog(@"No Fetch in progress");

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

      NSDebugMLLog(@"gsdb", @"Will fetchRow");

      row = [_adaptorChannel fetchRowWithZone: NULL];

      NSDebugMLLog(@"gsdb", @"row=%@", row);
      //NSDebugMLog(@"TEST attributesToFetch=%@", [_currentEntity attributesToFetch]);

      if (!row)
        {
          //TODO
          //VERIFY
          /*
            if no more obj:
            if transactionNestingLevel
            adaptorContext transactionDidCommit
          */
        }
      else
        {
          BOOL isObjectNew = YES; //TODO used to avoid double fetch. We should see how to do when isRefreshingObjects == YES
          EOGlobalID *gid;
          NSDictionary *snapshot = nil;

          NSAssert(_currentEntity, @"Not current Entity");

          gid = [_currentEntity globalIDForRow: row
				isFinal: YES];//OK

          NSDebugMLLog(@"gsdb",@"gid=%@",gid);
          //NSDebugMLog(@"TEST attributesToFetch=%@",[_currentEntity attributesToFetch]);

          object = [_currentEditingContext objectForGlobalID: gid]; //OK //nil

          NSDebugMLLog(@"gsdb",@"object=%@",object);

          if (object)
            isObjectNew = NO;

          NSAssert(_databaseContext,@"No database context");

          snapshot = [_databaseContext snapshotForGlobalID: gid]; //OK

          NSDebugMLLog(@"gsdb", @"snapshot=%@", snapshot);
          //NSDebugMLog(@"TEST attributesToFetch=%@", [_currentEntity attributesToFetch]);

          if (snapshot)
            {
              NSDebugMLLog(@"gsdb", @"_delegateRespondsTo.shouldUpdateSnapshot=%d",
                           (int)_delegateRespondsTo.shouldUpdateSnapshot);
              NSDebugMLLog(@"gsdb", @"[self isLocking]=%d",
                           (int)[self isLocking]);
              NSDebugMLLog(@"gsdb", @"[self isRefreshingObjects]=%d",
                           (int)[self isRefreshingObjects]);

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
                  NSDebugMLLog(@"gsdb", @"Updating Snapshot=%@", snapshot);
                  NSDebugMLLog(@"gsdb", @"row=%@", row);                  

                  [_databaseContext recordSnapshot: row
                                    forGlobalID: gid];
                  isObjectNew = YES; //TODO
                }
            }
          else
            {
              //NSDebugMLog(@"TEST attributesToFetch=%@", [_currentEntity attributesToFetch]);
              NSDebugMLLog(@"gsdb", @"database class=%@", [database class]);

              NSAssert(database, @"No database-context database");

              [database recordSnapshot: row
                        forGlobalID: gid];
            }

          NSDebugMLLog(@"gsdb", @"[self isRefreshingObjects]=%d",
                       (int)[self isRefreshingObjects]);

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

              //NSDebugMLog(@"TEST attributesToFetch=%@", [_currentEntity attributesToFetch]);
              NSDebugMLLog(@"gsdb", @"object=%@", object);
              NSAssert1(object, @"No Object. entityClassDescripton=%@", entityClassDescripton);

              [_currentEditingContext recordObject: object
                                      globalID: gid];
            }
          else if (object && [EOFault isFault: object])
            {
              EOAccessFaultHandler *handler = [EOFault handlerForFault: object];
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
              [EOObserverCenter suppressObserverNotification];

              NS_DURING
                {
                  NSDebugMLLog(@"gsdb", @"Initialize %p", object);

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
              [object awakeFromFetchInEditingContext: _currentEditingContext];
            }
        }
    }

  EOFLOGObjectFnStop();

  return object;
};

- (BOOL)isFetchInProgress
{
  //NSDebugMLog(@"TEST attributesToFetch=%@", [_currentEntity attributesToFetch]);

  return [_adaptorChannel isFetchInProgress];
}

- (void)cancelFetch
{
  EOFLOGObjectFnStart();

  [self _cancelInternalFetch];

  //TODO VERIFY - NO ??!!
  [_adaptorChannel cancelFetch];
  [_fetchProperties removeAllObjects];
  [_fetchSpecifications removeAllObjects];

  EOFLOGObjectFnStop();
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

  EOFLOGObjectFnStart();

  attributesToFetch = [_currentEntity _attributesToFetch];

  NSAssert(_currentEntity, @"No current Entity");

  EOFLOGObjectFnStop();

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
  EOFLOGObjectFnStart();

  if ([_adaptorChannel isFetchInProgress])
    {
      [_adaptorChannel cancelFetch];
    }

  EOFLOGObjectFnStop();
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

  EOFLOGObjectFnStart();

  _hints = [fetch _hints];

  customQueryExpressionHint = [_hints objectForKey: @"EOCustomQueryExpressionHintKey"];//TODO use it

  if (customQueryExpressionHint)
    {
      EOAdaptorContext *adaptorContext = nil;
      EOAdaptor *adaptor = nil;
      Class expressionClass = Nil;

      NSDebugMLLog(@"gsdb", @"customQueryExpressionHint=%@", customQueryExpressionHint);

      adaptorContext = [_databaseContext adaptorContext];

      NSDebugMLLog(@"gsdb", @"adaptorContext=%p", adaptorContext);

      adaptor = [adaptorContext adaptor];

      NSDebugMLLog(@"gsdb", @"adaptor=%p", adaptor);
      NSDebugMLLog(@"gsdb", @"adaptor=%@", adaptor);
      NSDebugMLLog(@"gsdb", @"adaptor class=%@", [adaptor class]);

      //TODO VERIFY
      expressionClass = [adaptor expressionClass];
      NSDebugMLLog(@"gsdb", @"expressionClass=%@", expressionClass);

      customQueryExpression = [expressionClass expressionForString:
						 customQueryExpressionHint];

      NSDebugMLLog(@"gsdb", @"customQueryExpression=%@", customQueryExpression);
    }

  [self setCurrentEditingContext: context]; //OK even if customQueryExpressionHintKey
  [self _setCurrentEntityAndRelationshipWithFetchSpecification: fetch];

  isDeep = [fetch isDeep]; //ret 1

  if (!customQueryExpressionHint)
    {
      subEntities = [entity subEntities];
      NSDebugMLLog(@"gsdb", @"subEntities=%@", subEntities);
      
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
                
                fetchSubEntity = [[fetch copy] autorelease];
                [fetchSubEntity setEntityName: [entity name]];
                
                [array addObjectsFromArray:
			 [context objectsWithFetchSpecification:
				    fetchSubEntity]];
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
  storedProcedureName = [hints objectForKey: @"EOStoredProcedureNameHintKey"];//TODO use it
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

      NSDebugMLLog(@"gsdb", @"%@ -- %@ 0x%x: isFetchInProgress=%s",
		   NSStringFromSelector(_cmd),
		   NSStringFromClass([self class]),
		   self,
		   ([self isFetchInProgress] ? "YES" : "NO"));

      [_adaptorChannel selectAttributes: propertiesToFetch
                       fetchSpecification: fetch
                       lock: fetchLocksObjects
                       entity: entity];
    }

  NSDebugMLLog(@"gsdb", @"%@ -- %@ 0x%x: isFetchInProgress=%s",
	       NSStringFromSelector(_cmd),
	       NSStringFromClass([self class]),
	       self,
	       ([self isFetchInProgress] ? "YES" : "NO"));

//TODO: verify
/*
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

  [self setCurrentEntity:[[_databaseContext database]
			   entityNamed:[fetch entityName]]];//done
  [self setCurrentEditingContext:context];//done

  [self setIsLocking:([_databaseContext updateStrategy] ==
		      EOUpdateWithPessimisticLocking ?
		      YES :
		      [fetch locksObjects])];
  [self setIsRefreshingObjects:[fetch refreshesRefetchedObjects]];

  attributesToFetch = [_currentEntity attributesToFetch];//done

  NSDebugMLLog(@"gsdb",@"[_adaptorChannel class]: %@",[_adaptorChannel class]);
  [_adaptorChannel selectAttributes:attributesToFetch
		   fetchSpecification:fetch
		   lock:_isLocking
		   entity:_currentEntity];//done

  [_fetchProperties addObjectsFromArray:attributesToFetch];

  if(_delegateRespondsTo.didSelectObjects)
    [_delegate databaseContext:_databaseContext
	       didSelectObjectsWithFetchSpecification:fetch
	       databaseChannel:self];
*/

  EOFLOGObjectFnStop();
}

@end /* EODatabaseChannel */