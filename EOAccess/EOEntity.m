/**
   EOEntity.m <title>EOEntity Class</title>

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@rccr.cremona.it>
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

#import <ctype.h>

#import <Foundation/Foundation.h>
#import <Foundation/NSException.h>

#include <gnustep/base/GCObject.h>

#import <EOAccess/EOModel.h>
#import <EOAccess/EOEntity.h>
#import <EOAccess/EOEntityPriv.h>
#import <EOAccess/EOAttribute.h>
#import <EOAccess/EOAttributePriv.h>
#import <EOAccess/EORelationship.h>
#import <EOAccess/EOStoredProcedure.h>
#import <EOAccess/EOExpressionArray.h>

#import <EOControl/EOKeyValueCoding.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOKeyGlobalID.h>
#import <EOControl/EOEditingContext.h>
#import <EOControl/EONull.h>
#import <EOControl/EOMutableKnownKeyDictionary.h>
#import <EOControl/EONSAddOns.h>
#import <EOControl/EOCheapArray.h>
#import <EOControl/EODebug.h>


NSString *EOFetchAllProcedureOperation = @"EOFetchAllProcedureOperation";
NSString *EOFetchWithPrimaryKeyProcedureOperation = @"EOFetchWithPrimaryKeyProcedureOperation";
NSString *EOInsertProcedureOperation = @"EOInsertProcedureOperation";
NSString *EODeleteProcedureOperation = @"EODeleteProcedureOperation";
NSString *EONextPrimaryKeyProcedureOperation = @"EONextPrimaryKeyProcedureOperation";


@implementation EOEntity

+ (EOEntity *)entity
{
  return [[[self alloc] init] autorelease];
}

+ (EOEntity *)entityWithPropertyList: (NSDictionary *)propertyList
			       owner: (id)owner
{
  return [[[self alloc] initWithPropertyList: propertyList
			owner: owner] autorelease];
}

- (id)initWithPropertyList: (NSDictionary *)propertyList
                     owner: (id)owner
{
  [EOObserverCenter suppressObserverNotification];

  EOFLOGObjectLevelArgs(@"EOEntity", @"propertyList=%@", propertyList);

  NS_DURING
    {
      if ((self = [self init]))
        {
          NSArray *array = nil;
          NSString *tmpString = nil;
          id tmpObject = nil;
          
          [self setCreateMutableObjects: YES];

          ASSIGN(_name, [propertyList objectForKey: @"name"]);

          [self setExternalName: [propertyList objectForKey: @"externalName"]];
          [self setExternalQuery: [propertyList objectForKey: @"externalQuery"]];

          tmpString = [propertyList objectForKey: @"restrictingQualifier"];

          EOFLOGObjectLevelArgs(@"EOEntity",@"tmpString=%@",tmpString);

          if (tmpString)
            {
              EOQualifier *restrictingQualifier =
		[EOQualifier qualifierWithQualifierFormat: @"%@", tmpString];

              [self setRestrictingQualifier: restrictingQualifier];
            }

          tmpString = [propertyList objectForKey: @"mappingQualifier"];

          if (tmpString)
            {
              NSEmitTODO();  //TODO
            }

          [self setReadOnly: [[propertyList objectForKey: @"isReadOnly"]
			       boolValue]];
          [self setCachesObjects: [[propertyList objectForKey:
						   @"cachesObjects"]
				    boolValue]];
          tmpObject = [propertyList objectForKey: @"userInfo"];

          EOFLOGObjectLevelArgs(@"EOEntity", @"tmpObject=%@", tmpObject);
          /*NSAssert2((!tmpString || [tmpString isKindOfClass:[NSString class]]),
                    @"tmpString is not a NSString but a %@. tmpString:\n%@",
                    [tmpString class],
                    tmpString);
          */

          if (tmpObject)
            //[self setUserInfo:[tmpString propertyList]];
            [self setUserInfo: tmpObject];
          else
            {
              tmpObject = [propertyList objectForKey: @"userDictionary"];
              /*NSAssert2((!tmpString || [tmpString isKindOfClass:[NSString class]]),
                        @"tmpString is not a NSString but a %@ tmpString:\n%@",
                        [tmpString class],
                        tmpString);*/
              //[self setUserInfo:[tmpString propertyList]];
              [self setUserInfo: tmpObject];
            }

          tmpObject = [propertyList objectForKey: @"internalInfo"];

          EOFLOGObjectLevelArgs(@"EOEntity", @"tmpObject=%@ [%@]",
				tmpObject, [tmpObject class]);

          [self _setInternalInfo: tmpObject];
          [self setDocComment:[propertyList objectForKey:@"docComment"]];
          [self setClassName: [propertyList objectForKey: @"className"]];
          [self setIsAbstractEntity:
		  [[propertyList objectForKey: @"isAbstractEntity"] boolValue]];
      
          tmpString = [propertyList objectForKey: @"isFetchable"];

          if (tmpString)
            {
              NSEmitTODO();  //TODO
            }
          
          array = [propertyList objectForKey: @"attributes"];

          EOFLOGObjectLevelArgs(@"EOEntity", @"Attributes: %@", array);

          if ([array count] > 0)
            {
              ASSIGN(_attributes, array);
              _flags.attributesIsLazy = YES;
            }

          array = [propertyList objectForKey: @"attributesUsedForLocking"];
          EOFLOGObjectLevelArgs(@"EOEntity", @"attributesUsedForLocking: %@",
				array);
          if ([array count] > 0)
            {          
              ASSIGN(_attributesUsedForLocking, array);
              _flags.attributesUsedForLockingIsLazy = YES;
            }

          array = [[propertyList objectForKey: @"primaryKeyAttributes"] 
                    sortedArrayUsingSelector: @selector(compare:)];

          EOFLOGObjectLevelArgs(@"EOEntity", @"primaryKeyAttributes: %@",
				array);

          if ([array count] > 0)
            {
              ASSIGN(_primaryKeyAttributes, array);
              _flags.primaryKeyAttributesIsLazy = YES;
            }

          //Assign them to _classProperties, not _classPropertyNames, this will be build after
          array = [propertyList objectForKey: @"classProperties"];

          EOFLOGObjectLevelArgs(@"EOEntity", @"classProperties: %@", array);

          if ([array count] > 0)
            {
              ASSIGN(_classProperties, array);
              _flags.classPropertiesIsLazy = YES;
            }

          array = [propertyList objectForKey: @"relationships"];

          EOFLOGObjectLevelArgs(@"EOEntity", @"relationships: %@", array);

          if ([array count] > 0)
            {
              ASSIGN(_relationships, array);
              _flags.relationshipsIsLazy = YES;
            }

          array = [propertyList objectForKey: @"storedProcedureNames"];

          EOFLOGObjectLevelArgs(@"EOEntity",@"relationships: %@",array);
          if ([array count] > 0)
            {
              NSEmitTODO(); //TODO
            }

          tmpString = [propertyList objectForKey:
				      @"maxNumberOfInstancesToBatchFetch"];

          EOFLOGObjectLevelArgs(@"EOEntity", @"maxNumberOfInstancesToBatchFetch=%@ [%@]",
				tmpString, [tmpString class]);

          if (tmpString)
              [self setMaxNumberOfInstancesToBatchFetch: [tmpString intValue]];

          tmpString=[propertyList objectForKey:@"batchFaultingMaxSize"];
          if (tmpString)
            {
              NSEmitTODO();  //TODO
	      //[self setBatchFaultingMaxSize: [tmpString intValue]];
	    }

          tmpObject = [propertyList objectForKey:
				      @"fetchSpecificationDictionary"];

          EOFLOGObjectLevelArgs(@"EOEntity", @"fetchSpecificationDictionary=%@ [%@]",
				tmpObject, [tmpObject class]);

          if (tmpObject)
            {
              ASSIGN(_fetchSpecificationDictionary, tmpObject);
            }
          else
            {
              _fetchSpecificationDictionary = [NSDictionary new];

              EOFLOGObjectLevelArgs(@"EOEntity", @"Entity %@ - _fetchSpecificationDictionary %p [RC=%d]:%@",
                           [self name],
                           _fetchSpecificationDictionary,
                           [_fetchSpecificationDictionary retainCount],
                           _fetchSpecificationDictionary);
            }

          // load entity's FetchSpecifications
          {
            NSDictionary *plist;
            NSString *fileName;
            
            fileName = [NSString stringWithFormat: @"%@.fspec", _name];
            plist = [[NSString stringWithContentsOfFile:
				 [[(EOModel *)owner path]
				   stringByAppendingPathComponent: fileName]]
		      propertyList];
 	  
            if (plist) 
              {
                EOKeyValueUnarchiver *unarchiver;
                NSDictionary *variables;
                NSEnumerator *variablesEnum;
                id fetchSpecName;

                unarchiver = [[[EOKeyValueUnarchiver alloc]
				initWithDictionary:
				  [NSDictionary dictionaryWithObject: plist
						forKey: @"fspecs"]]
			       autorelease];

                variables = [unarchiver decodeObjectForKey: @"fspecs"];
                //NSLog(@"fspecs variables:%@",variables);
                
                [unarchiver finishInitializationOfObjects];
                [unarchiver awakeObjects];

		variablesEnum = [variables keyEnumerator];
		while ((fetchSpecName = [variablesEnum nextObject]))
		  {
		    id fetchSpec = [variables objectForKey: fetchSpecName];

		    //NSLog(@"fetchSpecName:%@ fetchSpec:%@", fetchSpecName, fetchSpec);

		    [self addFetchSpecification: fetchSpec
			  named: fetchSpecName];
		  }
	      }
          }

          [self setCreateMutableObjects: NO]; //?? TC say no, mirko yes 
        }  
    }
  NS_HANDLER
    {
      [EOObserverCenter enableObserverNotification];

      NSLog(@"exception in EOEntity initWithPropertyList:owner:");
      NSLog(@"exception=%@", localException);

/*      localException=ExceptionByAddingUserInfoObjectFrameInfo(localException,
                                                              @"In EOEntity initWithPropertyList:owner:");*/

      NSLog(@"exception=%@", localException);
      [localException raise];
    }
  NS_ENDHANDLER;

  [EOObserverCenter enableObserverNotification];

  return self;
}

- (void)awakeWithPropertyList: (NSDictionary *)propertyList
{
  //do nothing?
}

- (void)encodeIntoPropertyList: (NSMutableDictionary *)propertyList
{
  int i, count;

  if (_name)
    [propertyList setObject: _name
                  forKey: @"name"];
  if (_className)
    [propertyList setObject: _className
                  forKey: @"className"];
  if (_externalName)
    [propertyList setObject: _externalName
                  forKey: @"externalName"];
  if (_externalQuery)
    [propertyList setObject: _externalQuery
                  forKey: @"externalQuery"];
  if (_userInfo)
    [propertyList setObject: _userInfo
                  forKey: @"userInfo"];
  if (_docComment)
    [propertyList setObject: _docComment
                  forKey: @"docComment"];
  if (_batchCount)
    [propertyList setObject: [NSNumber numberWithInt: _batchCount]
                  forKey: @"maxNumberOfInstancesToBatchFetch"];

  if (_flags.cachesObjects)
    [propertyList setObject: [NSNumber numberWithBool: _flags.cachesObjects]
                  forKey: @"cachesObjects"];

  if ((count = [_attributes count]))
    {
      if (_flags.attributesIsLazy)
        [propertyList setObject: _attributes
                      forKey: @"attributes"];
      else
        {
          NSMutableArray *attributesPList = [NSMutableArray array];

          for (i = 0; i < count; i++)
            {
              NSMutableDictionary *attributePList = [NSMutableDictionary
						      dictionary];
              
              [[_attributes objectAtIndex: i]
                encodeIntoPropertyList: attributePList];
              [attributesPList addObject: attributePList];
            }

          [propertyList setObject: attributesPList
                        forKey: @"attributes"];
        }
    }
  
  if ((count = [_attributesUsedForLocking count]))
    {
      if (_flags.attributesUsedForLockingIsLazy)
        [propertyList setObject: _attributesUsedForLocking
                      forKey: @"attributesUsedForLocking"];
      else
        {
          NSMutableArray *attributesUsedForLockingPList = [NSMutableArray
							    array];

          for (i = 0; i < count; i++)
            {
              NSString *attributePList
                = [(EOAttribute *)[_attributesUsedForLocking objectAtIndex: i]
                                  name];

              [attributesUsedForLockingPList addObject: attributePList];
            }
          
          [propertyList setObject: attributesUsedForLockingPList
                        forKey: @"attributesUsedForLocking"];
        }
    }

  if ((count = [_classProperties count]))
    {
      if (_flags.classPropertiesIsLazy)
        [propertyList setObject: _classProperties
                      forKey: @"classProperties"];
      else
        {
          NSMutableArray *classPropertiesPList = [NSMutableArray array];
          
          for (i = 0; i < count; i++)
            {
              NSString *classPropertyPList
                = [(EOAttribute *)[_classProperties objectAtIndex: i]
                                  name];
              [classPropertiesPList addObject: classPropertyPList];
            }
          
          [propertyList setObject: classPropertiesPList
                        forKey: @"classProperties"];
        }
    }

  if ((count = [_primaryKeyAttributes count]))
    {
      if (_flags.primaryKeyAttributesIsLazy)
        [propertyList setObject: _primaryKeyAttributes
                      forKey: @"primaryKeyAttributes"];
      else
        {
          NSMutableArray *primaryKeyAttributesPList = [NSMutableArray array];

          for (i = 0; i < count; i++)
            {
              NSString *attributePList= [(EOAttribute *)[_primaryKeyAttributes
							  objectAtIndex: i]
                                                        name];

              [primaryKeyAttributesPList addObject: attributePList];
            }

          [propertyList setObject: primaryKeyAttributesPList
                        forKey: @"primaryKeyAttributes"];
        }
    }

  {
    NSArray *relsPlist = [self relationshipsPlist];

    if (relsPlist)
      {
        [propertyList setObject: relsPlist
                        forKey: @"relationships"];
      }
  }
}

- (id) init
{
  //OK
  if ((self = [super init]))
    {
    }

  return self;
}

- (void)dealloc
{
  DESTROY(_name);
  DESTROY(_className);
  DESTROY(_externalName);
  DESTROY(_externalQuery);
  DESTROY(_userInfo);
  DESTROY(_docComment);
  DESTROY(_primaryKeyAttributeNames);
  DESTROY(_classPropertyNames);
  DESTROY(_classDescription);
  DESTROY(_adaptorDictionaryInitializer);
  DESTROY(_snapshotDictionaryInitializer);
  DESTROY(_primaryKeyDictionaryInitializer);
  DESTROY(_propertyDictionaryInitializer);
  DESTROY(_snapshotToAdaptorRowSubsetMapping);
  DESTROY(_classForInstances);

  [super dealloc];
}

- (void)gcDecrementRefCountOfContainedObjects
{
  int where = 0;
  NSProcessInfo *_processInfo = [NSProcessInfo processInfo];
  NSMutableSet *_debugSet = [_processInfo debugSet];

  [_debugSet addObject: @"gsdb"];

  EOFLOGObjectFnStart();
  EOFLOGObjectFnStart();

  NS_DURING
    {
      where = 1;
      [_model gcDecrementRefCount];

      where = 2;
      EOFLOGObjectLevelArgs(@"EOEntity", @"attributes gcDecrementRefCount");
      if (!_flags.attributesIsLazy)
        [(id)_attributes gcDecrementRefCount];

      where = 3;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"propertiesToFault gcDecrementRefCount");
      [(id)_attributesByName gcDecrementRefCount];

      where = 4;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"attributesToFetch gcDecrementRefCount class=%@",
			    [_attributesToFetch class]);
      NSAssert3(!_attributesToFetch
		|| [_attributesToFetch isKindOfClass: [NSArray class]],
                @"entity %@ attributesToFetch is not an NSArray but a %@\n%@",
                [self name],
                [_attributesToFetch class],
                _attributesToFetch);

      [(id)_attributesToFetch gcDecrementRefCount];

      NSAssert3(!_attributesToFetch
		|| [_attributesToFetch isKindOfClass: [NSArray class]],
                @"entity %@ attributesToFetch is not an NSArray but a %@\n%@",
                [self name],
                [_attributesToFetch class],
                _attributesToFetch);

      where = 5;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"attributesToSave gcDecrementRefCount (class=%@)",
			    [_attributesToSave class]);
      [(id)_attributesToSave gcDecrementRefCount];

      where = 6;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"propertiesToFault gcDecrementRefCount");
      [(id)_propertiesToFault gcDecrementRefCount];

      where = 7;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"rrelationships gcDecrementRefCount");
      if (!_flags.relationshipsIsLazy)
        [(id)_relationships gcDecrementRefCount];

      where = 8;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"relationshipsByName gcDecrementRefCount");
      [(id)_relationshipsByName gcDecrementRefCount];

      where = 9;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"primaryKeyAttributes gcDecrementRefCount");
      if (!_flags.primaryKeyAttributesIsLazy)
        [(id)_primaryKeyAttributes gcDecrementRefCount];

      where = 10;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"classProperties gcDecrementRefCount");
      if (!_flags.classPropertiesIsLazy)
        [(id)_classProperties gcDecrementRefCount];

      where = 11;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"attributesUsedForLocking (%@) gcDecrementRefCount",
			    [_attributesUsedForLocking class]);
      if (!_flags.attributesUsedForLockingIsLazy)
        [(id)_attributesUsedForLocking gcDecrementRefCount];

      where = 12;
      EOFLOGObjectLevelArgs(@"EOEntity", @"subEntities gcDecrementRefCount");
      [(id)_subEntities gcDecrementRefCount];

      where = 13;
      EOFLOGObjectLevelArgs(@"EOEntity", @"dbSnapshotKeys gcDecrementRefCount");
      [(id)_dbSnapshotKeys gcDecrementRefCount];

      where = 14;
      EOFLOGObjectLevelArgs(@"EOEntity", @"_parent gcDecrementRefCount");
      [_parent gcDecrementRefCount];
    }
  NS_HANDLER
    {
      NSLog(@"====>WHERE=%d %@ (%@)", where, localException,
	    [localException reason]);
      NSDebugMLog(@"attributesToFetch gcDecrementRefCount class=%@",
		  [_attributesToFetch class]);

      [localException raise];
    }
  NS_ENDHANDLER;

  EOFLOGObjectFnStop();

  [_debugSet removeObject: @"gsdb"];
}

- (BOOL)gcIncrementRefCountOfContainedObjects
{
  int where = 0;
  NSProcessInfo *_processInfo = [NSProcessInfo processInfo];
  NSMutableSet *_debugSet = [_processInfo debugSet];

  [_debugSet addObject: @"gsdb"];

  EOFLOGObjectFnStart();
  
  if (![super gcIncrementRefCountOfContainedObjects])
    {
      EOFLOGObjectFnStop();
      [_debugSet removeObject: @"gsdb"];

      return NO;
    }
  NS_DURING
    {
      where = 1;
      EOFLOGObjectLevelArgs(@"EOEntity", @"model gcIncrementRefCount");
      [_model gcIncrementRefCount];

      where = 2;
      EOFLOGObjectLevelArgs(@"EOEntity", @"attributes gcIncrementRefCount");
      if (!_flags.attributesIsLazy)
        [(id)_attributes gcIncrementRefCount];

      where = 3;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"attributesByName gcIncrementRefCount");
      [(id)_attributesByName gcIncrementRefCount];

      where = 4;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"attributesToFetch gcIncrementRefCount");
      NSAssert3(!_attributesToFetch
		|| [_attributesToFetch isKindOfClass: [NSArray class]],
                @"entity %@ attributesToFetch is not an NSArray but a %@\n%@",
                [self name],
                [_attributesToFetch class],
                _attributesToFetch);

      [(id)_attributesToFetch gcIncrementRefCount];

      NSAssert3(!_attributesToFetch
		|| [_attributesToFetch isKindOfClass: [NSArray class]],
                @"entity %@ attributesToFetch is not an NSArray but a %@\n%@",
                [self name],
                [_attributesToFetch class],
                _attributesToFetch);

      where = 5;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"attributesToSave gcIncrementRefCount");
      [(id)_attributesToSave gcIncrementRefCount];

      where = 6;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"propertiesToFault gcIncrementRefCount");
      [(id)_propertiesToFault gcIncrementRefCount];

      where = 7;
      EOFLOGObjectLevelArgs(@"EOEntity", @"relationships gcIncrementRefCount");
      if (!_flags.relationshipsIsLazy)
        [(id)_relationships gcIncrementRefCount];

      where = 8;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"relationshipsByName gcIncrementRefCount");
      [(id)_relationshipsByName gcIncrementRefCount];

      where = 9;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"primaryKeyAttributes gcIncrementRefCount");
      if (!_flags.primaryKeyAttributesIsLazy)
        [(id)_primaryKeyAttributes gcIncrementRefCount];

      where = 10;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"classProperties gcIncrementRefCount");
      if (!_flags.classPropertiesIsLazy)
        [(id)_classProperties gcIncrementRefCount];

      where = 11;
      EOFLOGObjectLevelArgs(@"EOEntity",
			    @"attributesUsedForLocking gcIncrementRefCount");
      if (!_flags.attributesUsedForLockingIsLazy)
        [(id)_attributesUsedForLocking gcIncrementRefCount];

      where = 12;
      EOFLOGObjectLevelArgs(@"EOEntity", @"subEntities gcIncrementRefCount");
      [(id)_subEntities gcIncrementRefCount];

      where = 13;
      EOFLOGObjectLevelArgs(@"EOEntity", @"dbSnapshotKeys gcIncrementRefCount");
      [(id)_dbSnapshotKeys gcIncrementRefCount];

      where = 14;
      EOFLOGObjectLevelArgs(@"EOEntity", @"parent gcIncrementRefCount");
      [_parent gcIncrementRefCount];

      where = 15;
      [_model gcIncrementRefCountOfContainedObjects];

      where = 16;
      EOFLOGObjectLevelArgs(@"EOEntity", @"attributes gcIncrementRefCountOfContainedObjects");
      if (!_flags.attributesIsLazy)
        [(id)_attributes gcIncrementRefCountOfContainedObjects];

      where = 17;
      EOFLOGObjectLevelArgs(@"EOEntity", @"attributesByName gcIncrementRefCountOfContainedObjects");
      [(id)_attributesByName gcIncrementRefCountOfContainedObjects];

      where = 18;
      EOFLOGObjectLevelArgs(@"EOEntity", @"attributesToFetch gcIncrementRefCountOfContainedObjects");
      [(id)_attributesToFetch gcIncrementRefCountOfContainedObjects];

      where = 19;
      EOFLOGObjectLevelArgs(@"EOEntity", @"attributesToSave gcIncrementRefCountOfContainedObjects (class=%@)",
			    [_attributesToSave class]);
      [(id)_attributesToSave gcIncrementRefCountOfContainedObjects];

      where = 20;
      EOFLOGObjectLevelArgs(@"EOEntity", @"propertiesToFault gcIncrementRefCountOfContainedObjects");
      [(id)_propertiesToFault gcIncrementRefCountOfContainedObjects];

      where = 21;
      EOFLOGObjectLevelArgs(@"EOEntity", @"rrelationships gcIncrementRefCountOfContainedObjects");
      if (!_flags.relationshipsIsLazy)
        [(id)_relationships gcIncrementRefCountOfContainedObjects];

      where = 22;
      EOFLOGObjectLevelArgs(@"EOEntity", @"relationshipsByName gcIncrementRefCountOfContainedObjects");
      [(id)_relationshipsByName gcIncrementRefCountOfContainedObjects];

      where = 23;
      EOFLOGObjectLevelArgs(@"EOEntity", @"primaryKeyAttributes gcIncrementRefCountOfContainedObjects");
      if (!_flags.primaryKeyAttributesIsLazy)
        [(id)_primaryKeyAttributes gcIncrementRefCountOfContainedObjects];

      where = 24;
      EOFLOGObjectLevelArgs(@"EOEntity", @"classProperties gcIncrementRefCountOfContainedObjects");
      if (!_flags.classPropertiesIsLazy)
        [(id)_classProperties gcIncrementRefCountOfContainedObjects];

      where = 25;
      EOFLOGObjectLevelArgs(@"EOEntity", @"attributesUsedForLocking (%@) gcIncrementRefCountOfContainedObjects",
			    [_attributesUsedForLocking class]);
      if (!_flags.attributesUsedForLockingIsLazy)
        [(id)_attributesUsedForLocking gcIncrementRefCountOfContainedObjects];

      where = 26;
      EOFLOGObjectLevelArgs(@"EOEntity", @"subEntities gcIncrementRefCountOfContainedObjects");
      [(id)_subEntities gcIncrementRefCountOfContainedObjects];

      where = 27;
      EOFLOGObjectLevelArgs(@"EOEntity", @"dbSnapshotKeys gcIncrementRefCountOfContainedObjects");
      [(id)_dbSnapshotKeys gcIncrementRefCountOfContainedObjects];

      where = 28;
      EOFLOGObjectLevelArgs(@"EOEntity", @"_parent gcIncrementRefCountOfContainedObjects");
      [_parent gcIncrementRefCountOfContainedObjects];

      where = 29;
    }
  NS_HANDLER
    {
      NSLog(@"====>WHERE=%d %@ (%@)", where, localException,
	    [localException reason]);
      NSDebugMLog(@"attributes gcIncrementRefCountOfContainedObjects=%@",
		  [_attributes class]);
      NSDebugMLog(@"_attributes classes %@",
		  [_attributes resultsOfPerformingSelector: @selector(class)]);

      [localException raise];
    }
  NS_ENDHANDLER;

  EOFLOGObjectFnStop();

  [_debugSet removeObject: @"gsdb"];

  return YES;
}

- (unsigned)hash
{
  return [_name hash];
}

- (NSString*)description
{
  NSString *dscr = nil;

  dscr = [NSString stringWithFormat: @"<%s %p - name=%@ className=%@ externalName=%@ externalQuery=%@",
		   object_get_class_name(self),
		   (void*)self,
		   _name,
		   _className,
		   _externalName,
		   _externalQuery];

  dscr = [dscr stringByAppendingFormat:@" userInfo=%@",
	       _userInfo];
  dscr = [dscr stringByAppendingFormat:@" primaryKeyAttributeNames=%@ classPropertyNames=%@>",
	       [self primaryKeyAttributeNames],
	       [self classPropertyNames]];

  NSAssert4(!_attributesToFetch
	    || [_attributesToFetch isKindOfClass:[NSArray class]],
            @"entity %@ attributesToFetch %p is not an NSArray but a %@\n%@",
            [self name],
            _attributesToFetch,
            [_attributesToFetch class],
            _attributesToFetch);

  return dscr;
}

- (EOQualifier *)restrictingQualifier
{
  return _restrictingQualifier;
}

- (NSString *)name
{
  return _name;
}

- (EOModel *)model
{
  return _model;
}

- (NSDictionary *)userInfo
{
  return _userInfo;
}

- (NSString *)docComment
{
  return _docComment;
}

- (BOOL)isReadOnly
{
  return _flags.isReadOnly;
}

- (NSString *)externalQuery
{
  return _externalQuery;
}

- (NSString *)externalName
{
  EOFLOGObjectLevelArgs(@"EOEntity", @"entity %p (%@): external name=%@",
			self, [self name], _externalName);

  return _externalName;
}

- (NSString *)className
{
  return _className;
} 

- (NSArray *)attributesUsedForLocking
{
  //OK
  if (_flags.attributesUsedForLockingIsLazy)
    {
      int count = [_attributesUsedForLocking count];

      EOFLOGObjectLevelArgs(@"EOEntity", @"Lazy _attributesUsedForLocking=%@",
			    _attributesUsedForLocking);

      if (count > 0)
        {
          int i = 0;
          NSArray *attributesUsedForLocking = _attributesUsedForLocking;

          _attributesUsedForLocking = [GCMutableArray new];
          _flags.attributesUsedForLockingIsLazy = NO;

          for (i = 0; i < count; i++)
            {
              NSString *attributeName = [attributesUsedForLocking
					  objectAtIndex: i];
              EOAttribute *attribute = [self attributeNamed: attributeName];

              NSAssert1(attribute,
                        @"No attribute named %@ to use for locking",
                        attribute);

              if ([self isValidAttributeUsedForLocking: attribute])
                [_attributesUsedForLocking addObject: attribute];
              else
                {
		  NSEmitTODO(); //TODO
                  [self notImplemented: _cmd]; //TODO
                }
            }

          EOFLOGObjectLevelArgs(@"EOEntity", @"_attributesUsedForLocking class=%@",
				[_attributesUsedForLocking class]);          

          DESTROY(attributesUsedForLocking);

          [self _setIsEdited]; //To Clean Buffers
        }
      else
        _flags.attributesUsedForLockingIsLazy = NO;
    }

  return _attributesUsedForLocking;
}

- (NSArray *)classPropertyNames
{
  //OK
  EOFLOGObjectFnStart();

  if (!_classPropertyNames)
    {
      NSArray *classProperties = [self classProperties];

      NSAssert2(!classProperties
		|| [classProperties isKindOfClass: [NSArray class]],
                @"classProperties is not an NSArray but a %@\n%@",
                [classProperties class],
                classProperties);

      ASSIGN(_classPropertyNames,
	     [classProperties resultsOfPerformingSelector: @selector(name)]);
    }

  NSAssert4(!_attributesToFetch
	    || [_attributesToFetch isKindOfClass: [NSArray class]],
            @"entity %@ attributesToFetch %p is not an NSArray but a %@\n%@",
            [self name],
            _attributesToFetch,
            [_attributesToFetch class],
            _attributesToFetch);

  EOFLOGObjectFnStop();

  return _classPropertyNames;
}

- (NSArray *)classProperties
{
  //OK
  EOFLOGObjectFnStart();

  if (_flags.classPropertiesIsLazy)
    {
      int count = [_classProperties count];

      EOFLOGObjectLevelArgs(@"EOEntity", @"Lazy _classProperties=%@",
			    _classProperties);

      if (count > 0)
        {
          NSArray *classPropertiesList = _classProperties;
          int i;

          _classProperties = [GCMutableArray new];
          _flags.classPropertiesIsLazy = NO;

          for (i = 0; i < count; i++)
            {
              NSString *classPropertyName = [classPropertiesList
					      objectAtIndex: i];
              id classProperty = [self attributeNamed: classPropertyName];

              if (!classProperty)
                  classProperty = [self relationshipNamed: classPropertyName];

              NSAssert2(classProperty,
                        @"No attribute or relationship named %@ to use as classProperty in entity %@",
                        classPropertyName,
                        self);

              if ([self isValidClassProperty: classProperty])
                [_classProperties addObject: classProperty];
              else
                {
                  //TODO
                  NSAssert2(NO, @"not valid class prop %@ in %@",
			    classProperty, [self name]);
                }
            }

          DESTROY(classPropertiesList);

          [_classProperties sortUsingSelector: @selector(eoCompareOnName:)]; //Very important to have always the same order.
          [self _setIsEdited]; //To Clean Buffers
        }
      else
        _flags.classPropertiesIsLazy = NO;
    }

  EOFLOGObjectFnStop();

  return _classProperties;
}

- (NSArray*)primaryKeyAttributes
{
  //OK
  if (_flags.primaryKeyAttributesIsLazy)
    {
      int count = [_primaryKeyAttributes count];

      EOFLOGObjectLevelArgs(@"EOEntity", @"Lazy _primaryKeyAttributes=%@",
			    _primaryKeyAttributes);

      if (count > 0)
        {
          int i = 0;
          NSArray *primaryKeyAttributes = _primaryKeyAttributes;

          _primaryKeyAttributes = [GCMutableArray new];
          _flags.primaryKeyAttributesIsLazy = NO;

          for (i = 0; i < count; i++)
            {
              NSString *attributeName = [primaryKeyAttributes objectAtIndex: i];
              EOAttribute *attribute = [self attributeNamed: attributeName];

              NSAssert3(attribute,
                        @"In entity %@: No attribute named %@ to use for locking (attributes: %@)",
                        [self name],
                        attributeName,
                        [_attributes resultsOfPerformingSelector: @selector(name)]);

              if ([self isValidPrimaryKeyAttribute: attribute])
                [_primaryKeyAttributes addObject: attribute];
              else
                {
                  NSAssert2(NO, @"not valid pk attribute %@ in %@",
			    attribute, [self name]);
                }
            }

          DESTROY(primaryKeyAttributes);

          [_primaryKeyAttributes sortUsingSelector: @selector(eoCompareOnName:)]; //Very important to have always the same order.
          [self _setIsEdited]; //To Clean Buffers
        }
      else
        _flags.primaryKeyAttributesIsLazy = NO;
    }

  return _primaryKeyAttributes;
}

- (NSArray *)primaryKeyAttributeNames
{
  //OK
  if (!_primaryKeyAttributeNames)
    {
      NSArray *primaryKeyAttributes = [self primaryKeyAttributes];
      NSArray *primaryKeyAttributeNames = [primaryKeyAttributes
					    resultsOfPerformingSelector:
					      @selector(name)];

      primaryKeyAttributeNames = [primaryKeyAttributeNames sortedArrayUsingSelector: @selector(compare:)]; //Not necessary: they are already sorted
      ASSIGN(_primaryKeyAttributeNames, primaryKeyAttributeNames);
    }

  return _primaryKeyAttributeNames;
}

- (NSArray *)relationships
{
  //OK
  if (_flags.relationshipsIsLazy)
    {
      int count = 0;

      EOFLOGObjectLevelArgs(@"EOEntity", @"START construct relationships on %p",
			    self);

      count = [_relationships count];
      EOFLOGObjectLevelArgs(@"EOEntity", @"Lazy _relationships=%@",
			    _relationships);

      if (count > 0)
        {
          int i = 0;
          NSArray *relationshipPLists = _relationships;
          NSDictionary *attributesByName = nil;

          DESTROY(_relationshipsByName);

          _relationships = [GCMutableArray new];
          _relationshipsByName = [GCMutableDictionary new];

          if (!_flags.attributesIsLazy)
            {
              attributesByName = [self attributesByName];
              NSAssert2((!attributesByName
			 || [attributesByName isKindOfClass:
						[NSDictionary class]]),
                        @"attributesByName is not a NSDictionary but a %@. attributesByName [%p]",
                        [attributesByName class],
                        attributesByName);
            }

          _flags.relationshipsIsLazy = NO;
          [EOObserverCenter suppressObserverNotification];

          NS_DURING
            {
              NSArray *relNames = nil;

              for (i = 0; i < count; i++)
                {
                  NSDictionary *attrPList = [relationshipPLists
					      objectAtIndex: i];
                  EORelationship *relationship = nil;
                  NSString *relationshipName = nil;

                  EOFLOGObjectLevelArgs(@"EOEntity", @"attrPList: %@",
					attrPList);

                  relationship = [EORelationship
				   relationshipWithPropertyList: attrPList
				   owner: self];

                  relationshipName = [relationship name];

                  EOFLOGObjectLevelArgs(@"EOEntity", @"relationshipName: %@",
					relationshipName);

                  if ([attributesByName objectForKey: relationshipName])
                    {
                      [NSException raise: NSInvalidArgumentException
                                   format: @"%@ -- %@ 0x%x: \"%@\" already used in the model as attribute",
                                   NSStringFromSelector(_cmd),
                                   NSStringFromClass([self class]),
                                   self,
                                   relationshipName];
                    }

                  if ([_relationshipsByName objectForKey: relationshipName])
                    {
                      [NSException raise: NSInvalidArgumentException
                                   format: @"%@ -- %@ 0x%x: \"%@\" already used in the model",
                                   NSStringFromSelector(_cmd),
                                   NSStringFromClass([self class]),
                                   self,
                                   relationshipName];
                    }

                  EOFLOGObjectLevelArgs(@"EOEntity", @"Add rel %p",
					relationship);
                  EOFLOGObjectLevelArgs(@"EOEntity", @"Add rel=%@",
					relationship);

                  [_relationships addObject: relationship];
                  [_relationshipsByName setObject: relationship
                                        forKey: relationshipName];
                }

              EOFLOGObjectLevelArgs(@"EOEntity", @"Rels added");

              [self _setIsEdited];//To Clean Buffers
              relNames = [_relationships
			   resultsOfPerformingSelector: @selector(name)];

              EOFLOGObjectLevelArgs(@"EOEntity", @"relNames=%@", relNames);

              count = [relNames count];
              EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p rel count=%d",
				    self, count);

              NSAssert(count == [relationshipPLists count],
		       @"Error during attribute creations");
              {
                int pass = 0;

                //We'll first awake non flattened relationships
                for (pass = 0; pass < 2; pass++)
                  {
                    for (i = 0; i < count; i++)
                      {
                        NSString *relName = [relNames objectAtIndex: i];
                        NSDictionary *relPList = [relationshipPLists
						   objectAtIndex: i];
                        EORelationship *relationship = [self relationshipNamed:
							       relName];

                        EOFLOGObjectLevelArgs(@"EOEntity", @"relName=%@",
					      relName);

                        if ((pass == 0
			     && ![relPList objectForKey: @"definition"]) 
                            || (pass == 1
				&& [relPList objectForKey: @"definition"]))
                          {
                            EOFLOGObjectLevelArgs(@"EOEntity", @"XXX REL: self=%p AWAKE relationship=%@",
						  self, relationship);

                            [relationship awakeWithPropertyList: relPList];
                          }
                      }
                  }
              }
            }
          NS_HANDLER
            {
              EOFLOGObjectLevelArgs(@"EOEntity", @"localException=%@",
				    localException);

              DESTROY(relationshipPLists);

              [EOObserverCenter enableObserverNotification];
              [localException raise];
            }
          NS_ENDHANDLER;

          DESTROY(relationshipPLists);

          [EOObserverCenter enableObserverNotification];
        }
      else
        _flags.relationshipsIsLazy = NO;

      EOFLOGObjectLevelArgs(@"EOEntity", @"STOP construct relationships on %p",
			    self);
    }

  return _relationships;
}

- (NSArray *)attributes
{
  //OK
  if (_flags.attributesIsLazy)
    {
      int count = 0;

      EOFLOGObjectLevelArgs(@"EOEntity", @"START construct attributes on %p",
			    self);

      count = [_attributes count];
      EOFLOGObjectLevelArgs(@"EOEntity", @"Entity %@: Lazy _attributes=%@",
			    [self name],
			    _attributes);

      if (count > 0)
        {
          int i = 0;
          NSArray *attributePLists = _attributes;
          NSDictionary *relationshipsByName = nil;

          DESTROY(_attributesByName);

          _attributes = [GCMutableArray new];
          _attributesByName = [GCMutableDictionary new];

          NSAssert2((!_attributesByName
		     || [_attributesByName isKindOfClass:
					     [NSDictionary class]]),
                    @"_attributesByName is not a NSDictionary but a %@. _attributesByName [%p]",
                    [_attributesByName class],
                    _attributesByName);

          if (!_flags.relationshipsIsLazy)
            relationshipsByName = [self relationshipsByName];

          _flags.attributesIsLazy = NO;

          [EOObserverCenter suppressObserverNotification];

          NS_DURING
            {
              NSArray *attrNames = nil;

              for (i = 0; i < count; i++)
                {
                  NSDictionary *attrPList = [attributePLists objectAtIndex: i];
                  EOAttribute *attribute = [EOAttribute
					     attributeWithPropertyList:
					       attrPList
					     owner: self];
                  NSString *attributeName = [attribute name];

                  EOFLOGObjectLevelArgs(@"EOEntity", @"XXX 1 ATTRIBUTE: attribute=%@",
					attribute);

                  if ([_attributesByName objectForKey: attributeName])
                    {
                      [NSException raise: NSInvalidArgumentException
                                   format: @"%@ -- %@ 0x%x: \"%@\" already used in the model as attribute",
                                   NSStringFromSelector(_cmd),
                                   NSStringFromClass([self class]),
                                   self,
                                   attributeName];
                    }

                  if ([relationshipsByName objectForKey: attributeName])
                    {
                      [NSException raise: NSInvalidArgumentException
                                   format: @"%@ -- %@ 0x%x: \"%@\" already used in the model",
                                   NSStringFromSelector(_cmd),
                                   NSStringFromClass([self class]),
                                   self,
                                   attributeName];
                    }

                  EOFLOGObjectLevelArgs(@"EOEntity", @"Add attribute: %@",
					attribute);

                  [_attributes addObject: attribute];
                  [_attributesByName setObject: attribute
				     forKey: attributeName];
                }

              EOFLOGObjectLevelArgs(@"EOEntity", @"_attributesByName class=%@",
				    [_attributesByName class]);
              NSAssert2((!_attributesByName
			 || [_attributesByName isKindOfClass:
						 [NSDictionary class]]),
                        @"_attributesByName is not a NSDictionary but a %@. _attributesByName [%p]",
                        [_attributesByName class],
                        _attributesByName);

              EOFLOGObjectLevelArgs(@"EOEntity", @"_attributes [%p]=%@",
				    _attributes, _attributes);
              EOFLOGObjectLevelArgs(@"EOEntity", @"_attributesByName class=%@",
				    [_attributesByName class]);
              EOFLOGObjectLevelArgs(@"EOEntity", @"_attributesByName [%p]",
				    _attributesByName);
              EOFLOGObjectLevelArgs(@"EOEntity", @"_attributesByName class=%@",
				    [_attributesByName class]);
              //TODO[self _setIsEdited];//To Clean Buffers
              EOFLOGObjectLevelArgs(@"EOEntity", @"_attributesByName [%p]",
				    _attributesByName);
              EOFLOGObjectLevelArgs(@"EOEntity", @"_attributesByName class=%@",
				    [_attributesByName class]);

              NSAssert2((!_attributesByName
			 || [_attributesByName isKindOfClass:
						 [NSDictionary class]]),
                        @"_attributesByName is not a NSDictionary but a %@. _attributesByName [%p]",
                        [_attributesByName class],
                        _attributesByName);

              attrNames = [_attributes resultsOfPerformingSelector:
					 @selector(name)];
              NSAssert2((!_attributesByName
			 || [_attributesByName isKindOfClass:
						 [NSDictionary class]]),
                        @"_attributesByName is not a NSDictionary but a %@. _attributesByName [%p]",
                        [_attributesByName class],
                        _attributesByName);

              EOFLOGObjectLevelArgs(@"EOEntity", @"attrNames [%p]=%@",
				    attrNames, attrNames);

              count = [attrNames count];
              EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p Attributes count=%d",
				    self, count);
              NSAssert(count == [attributePLists count],
		       @"Error during attribute creations");
              EOFLOGObjectLevelArgs(@"EOEntity", @"attributePLists=%@",
				    attributePLists);
              EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p attributePLists count=%d",
				    self, [attributePLists count]);

              {
                int pass = 0;

                //We'll first awake non derived/flattened attributes
                for (pass = 0; pass < 2; pass++)
                  {
                    for (i = 0; i < count; i++)
                      {
                        NSString *attrName = [attrNames objectAtIndex: i];
                        NSDictionary *attrPList = [attributePLists
						    objectAtIndex: i];
                        EOAttribute *attribute = nil;

                        EOFLOGObjectLevelArgs(@"EOEntity", @"XXX attrName=%@",
					      attrName);

                        if ((pass == 0 &&
			     ![attrPList objectForKey: @"definition"]) 
                            || (pass == 1
				&& [attrPList objectForKey: @"definition"]))
                          {
                            attribute = [self attributeNamed: attrName];
                            EOFLOGObjectLevelArgs(@"EOEntity", @"XXX 2A ATTRIBUTE: self=%p AWAKE attribute=%@",
						  self, attribute);

                            [attribute awakeWithPropertyList: attrPList];
                            EOFLOGObjectLevelArgs(@"EOEntity", @"XXX 2B ATTRIBUTE: self=%p attribute=%@",
						  self, attribute);
                          }
                      }
                  }
              }
              NSAssert2((!_attributesByName
			 || [_attributesByName isKindOfClass:
						 [NSDictionary class]]),
                        @"_attributesByName is not a NSDictionary but a %@. _attributesByName [%p]",
                        [_attributesByName class],
                        _attributesByName);
            }
          NS_HANDLER
            {
              DESTROY(attributePLists);
              [EOObserverCenter enableObserverNotification];
              [localException raise];
            }
          NS_ENDHANDLER;

          DESTROY(attributePLists);

          [EOObserverCenter enableObserverNotification];
          [_attributes sortUsingSelector: @selector(eoCompareOnName:)];//Very important to have always the same order.
        }
      else
        _flags.attributesIsLazy = NO;

      EOFLOGObjectLevelArgs(@"EOEntity", @"STOP construct attributes on %p",
			    self);
    }

  return _attributes;
}

- (BOOL)cachesObjects
{
  return _flags.cachesObjects;
}

- (EOQualifier *)qualifierForPrimaryKey: (NSDictionary *)row
{
  //OK
  EOQualifier *qualifier = nil;
  NSArray *primaryKeyAttributeNames = [self primaryKeyAttributeNames];
  int count = [primaryKeyAttributeNames count];

  if (count == 1)
    {
      //OK
      NSString *key = [primaryKeyAttributeNames objectAtIndex: 0];
      id value = [row objectForKey: key];

      qualifier = [EOKeyValueQualifier qualifierWithKey: key
				       operatorSelector:
					 EOQualifierOperatorEqual
				       value: value];
    }
  else
    {
      //Seems OK
      NSMutableArray *array = [NSMutableArray arrayWithCapacity: count];
      int i;

      for (i = 0; i < count; i++)
	{
	  NSString *key = [primaryKeyAttributeNames objectAtIndex: i];
          id value = [row objectForKey: key];

	  [array addObject: [EOKeyValueQualifier qualifierWithKey: key
						 operatorSelector:
						   EOQualifierOperatorEqual
						 value: value]];
	}

      qualifier = [EOAndQualifier qualifierWithQualifierArray: array];
    }

  return qualifier;
}

- (BOOL)isQualifierForPrimaryKey: (EOQualifier *)qualifier
{
  int count = [[self primaryKeyAttributeNames] count];

  if (count == 1)
    {
      if ([qualifier isKindOfClass: [EOKeyValueQualifier class]] == YES)
	return YES;
      else
	return NO;
    }
  else
    {
    }

  //TODO
  NSEmitTODO();  //TODO
  [self notImplemented:_cmd];

  return NO;
}

- (EOAttribute *)attributeNamed: (NSString *)attributeName
{
  //OK
  EOAttribute *attribute = nil;
  NSDictionary *attributesByName = nil;

  EOFLOGObjectFnStart();

  attributesByName = [self attributesByName];

  EOFLOGObjectLevelArgs(@"EOEntity", @"attributesByName [%p] (%@)",
			attributesByName,
			[attributesByName class]);
  NSAssert2((!attributesByName
	     || [attributesByName isKindOfClass: [NSDictionary class]]),
            @"attributesByName is not a NSDictionary but a %@. attributesByName [%p]",
            [attributesByName class],
            attributesByName);
  //  EOFLOGObjectLevelArgs(@"EOEntity",@"attributesByName=%@",attributesByName);

  attribute = [attributesByName objectForKey: attributeName];

  EOFLOGObjectFnStop();

  return attribute;
}

/** returns attribute named attributeName (no relationship) **/
- (EOAttribute *)anyAttributeNamed: (NSString *)attributeName
{
  EOAttribute *attr;
  NSEnumerator *attrEnum;

  attr = [self attributeNamed:attributeName];

  //VERIFY
  if (!attr)
    {
      attrEnum = [[self primaryKeyAttributes] objectEnumerator];

      while ((attr = [attrEnum nextObject]))
        {
	  if ([[attr name] isEqual: attributeName])
	    return attr;
        }
    }

  return attr;
}

- (EORelationship *)relationshipNamed: (NSString *)relationshipName
{
  //OK
  return [[self relationshipsByName] objectForKey: relationshipName];
}

- (EORelationship *)anyRelationshipNamed: (NSString *)relationshipNamed
{
  EORelationship *rel;
  NSEnumerator *relEnum = nil;

  rel = [self relationshipNamed: relationshipNamed];

  //VERIFY
  if (!rel)
    {
      EORelationship *tmpRel = nil;

      relEnum = [_hiddenRelationships objectEnumerator];

      while (!rel && (tmpRel = [relEnum nextObject]))
        {
	  if ([[tmpRel name] isEqual: relationshipNamed])
	    rel = tmpRel;
        }
    }

  return rel;
}

- (NSArray *)fetchSpecificationNames
{
  return _fetchSpecificationNames;
}

- (EOFetchSpecification *)fetchSpecificationNamed: (NSString *)fetchSpecName
{
  return [_fetchSpecificationDictionary objectForKey: fetchSpecName];
}

- (NSArray *)attributesToFetch
{
  //OK
  NSAssert3(!_attributesToFetch 
	    | [_attributesToFetch isKindOfClass: [NSArray class]],
            @"entity %@ attributesToFetch %p is not an NSArray but a %@",
            [self name],
            _attributesToFetch,
            [_attributesToFetch class]);

  return [self _attributesToFetch];
}

- (NSDictionary *)primaryKeyForRow: (NSDictionary *)row
{
  NSMutableDictionary *dict = nil;
  int i, count;
  NSArray *primaryKeyAttributes = [self primaryKeyAttributes];

  count = [primaryKeyAttributes count];
  dict = [NSMutableDictionary dictionaryWithCapacity: count];

  for (i = 0; i < count; i++)
    {
      EOAttribute *attr = [primaryKeyAttributes objectAtIndex: i];
      id value = [row objectForKey: [attr name]];

      if (!value)
        value = [EONull null];

      [dict setObject: value
	    forKey: [attr name]];
    }

  return dict;
}

- (BOOL)isValidAttributeUsedForLocking: (EOAttribute *)anAttribute
{
  if (!([anAttribute isKindOfClass: [EOAttribute class]]
	&& [[self attributesByName] objectForKey: [anAttribute name]]))
    return NO;

  if ([anAttribute isDerived])
    return NO;

  return YES;
}

- (BOOL)isValidPrimaryKeyAttribute: (EOAttribute *)anAttribute
{
  if (!([anAttribute isKindOfClass: [EOAttribute class]]
	&& [[self attributesByName] objectForKey: [anAttribute name]]))
    return NO;

  if ([anAttribute isDerived])
    return NO;

  return YES;
}

- (BOOL)isPrimaryKeyValidInObject: (id)object
{
  NSArray *primaryKeyAttributeNames = nil;
  NSString *key = nil;
  id value = nil;
  int i, count;
  BOOL isValid = YES;

  primaryKeyAttributeNames = [self primaryKeyAttributeNames];
  count = [primaryKeyAttributeNames count];

  for (i = 0; isValid && i < count; i++)
    {
      key = [primaryKeyAttributeNames objectAtIndex: i];

      NS_DURING
	{
          value = [object valueForKey: key];
          if (value == nil || value == [EONull null])
            isValid = NO;
	}
      NS_HANDLER
	{
	  isValid = NO;
	}
      NS_ENDHANDLER;
    }
  
  return isValid;
}

- (BOOL)isValidClassProperty:aProperty
{
  id thePropertyName;

  if (!([aProperty isKindOfClass: [EOAttribute class]]
	|| [aProperty isKindOfClass: [EORelationship class]]))
    return NO;

  thePropertyName = [(EOAttribute *)aProperty name];

  if ([[self attributesByName] objectForKey: thePropertyName]
      || [[self relationshipsByName] objectForKey: thePropertyName])
    return YES;

  return NO;
}

- (NSArray *)subEntities
{
  return _subEntities;
}

- (EOEntity *)parentEntity
{
  return _parent;
}

- (BOOL)isAbstractEntity
{
  return _flags.isAbstractEntity;
}


- (unsigned int)maxNumberOfInstancesToBatchFetch
{
  return _batchCount;
}

- (BOOL)isPrototypeEntity
{
  [self notImplemented:_cmd];
  return NO; // TODO
}

@end


@implementation EOEntity (EOEntityEditing)

- (void)setUserInfo: (NSDictionary *)dictionary
{
  //OK
  [self willChange];
  ASSIGN(_userInfo, dictionary);
  [self _setIsEdited];
}

- (void)_setInternalInfo: (NSDictionary *)dictionary
{
  //OK
  [self willChange];
  ASSIGN(_internalInfo, dictionary);
  [self _setIsEdited];
}

- (void)setDocComment: (NSString *)docComment
{
  //OK
  [self willChange];
  ASSIGN(_docComment, docComment);
  [self _setIsEdited];
}

- (BOOL)setClassProperties: (NSArray *)properties
{
  int i, count = [properties count];

  for (i = 0; i < count; i++)
    if (![self isValidClassProperty: [properties objectAtIndex:i]])
      return NO;

  DESTROY(_classProperties);
  if ([properties isKindOfClass:[GCArray class]]
      || [properties isKindOfClass: [GCMutableArray class]])
    _classProperties = [[GCMutableArray alloc] initWithArray: properties];
  else
    _classProperties = [[GCMutableArray alloc] initWithArray: properties]; //TODO

  [self _setIsEdited]; //To clean cache

  return YES;
}

- (BOOL)setPrimaryKeyAttributes: (NSArray *)keys
{
  int i, count = [keys count];

  for (i = 0; i < count; i++)
    if (![self isValidPrimaryKeyAttribute: [keys objectAtIndex:i]])
      return NO;

  DESTROY(_primaryKeyAttributes);

  if ([keys isKindOfClass:[GCArray class]]
      || [keys isKindOfClass: [GCMutableArray class]])
    _primaryKeyAttributes = [[GCMutableArray alloc] initWithArray: keys];
  else
    _primaryKeyAttributes = [[GCMutableArray alloc] initWithArray: keys]; // TODO
  
  [self _setIsEdited];//To clean cache

  return YES;
}

- (BOOL)setAttributesUsedForLocking: (NSArray *)attributes
{
  int i, count = [attributes count];

  for (i = 0; i < count; i++)
    if (![self isValidAttributeUsedForLocking: [attributes objectAtIndex: i]])
      return NO;

  DESTROY(_attributesUsedForLocking);
  
  if ([attributes isKindOfClass: [GCArray class]]   // TODO
      || [attributes isKindOfClass: [GCMutableArray class]])
    _attributesUsedForLocking = [[GCMutableArray alloc]
				  initWithArray: attributes];
  else
    _attributesUsedForLocking = [[GCMutableArray alloc]
				  initWithArray: attributes];
  
  [self _setIsEdited]; //To clean cache

  return YES;
}

- (NSException *)validateName: (NSString *)name
{
  const char *p, *s = [name cString];
  int exc = 0;
  NSArray *storedProcedures;

  if (!name || ![name length]) exc++;
  if (!exc)
    {
      p = s;
      while (*p)
        {
	  if (!isalnum(*p) &&
	     *p != '@' && *p != '#' && *p != '_' && *p != '$')
            {
	      exc++;
	      break;
            }
	  p++;
        }
      if (!exc && *s == '$') exc++;
      
      if ([self attributeNamed: name]) exc++;
      else if ([self relationshipNamed: name]) exc++;
      else if ((storedProcedures = [[self model] storedProcedures]))
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

	      if (exc) break;
            }
        }
    }

    if (exc)
      return [NSException exceptionWithName: NSInvalidArgumentException
			  reason: [NSString stringWithFormat:@"%@ -- %@ 0x%x: argument \"%@\" contains invalid chars",
					    NSStringFromSelector(_cmd),
					    NSStringFromClass([self class]),
					    self,
					    name]
			  userInfo: nil];
    else
      return nil;
}

- (void)setName: (NSString *)name
{
  if ([_model entityNamed: name])
    [NSException raise: NSInvalidArgumentException
                 format: @"%@ -- %@ 0x%x: \"%@\" already used in the model",
                 NSStringFromSelector(_cmd),
                 NSStringFromClass([self class]),
                 self,
                 name];

  ASSIGN(_name, name);
}

- (void)setExternalName: (NSString *)name
{
  //OK
  EOFLOGObjectLevelArgs(@"EOEntity", @"entity %p (%@): external name=%@",
			self, [self name], name);

  [self willChange];
  ASSIGN(_externalName,name);
  [self _setIsEdited];
}

- (void)setExternalQuery: (NSString *)query
{
  //OK
  [self willChange];
  ASSIGN(_externalQuery, query);
  [self _setIsEdited];
}

- (void)setRestrictingQualifier: (EOQualifier *)qualifier
{
  ASSIGN(_restrictingQualifier, qualifier);
}

- (void)setReadOnly: (BOOL)flag
{
  //OK
  _flags.isReadOnly = flag;
}

- (void)setCachesObjects: (BOOL)flag
{
  //OK
  _flags.cachesObjects = flag;
}

- (void)addAttribute: (EOAttribute *)attribute
{
  NSString *attributeName = [attribute name];

  if ([[self attributesByName] objectForKey: attributeName])
    [NSException raise: NSInvalidArgumentException
                 format: @"%@ -- %@ 0x%x: \"%@\" already used in the model",
                 NSStringFromSelector(_cmd),
                 NSStringFromClass([self class]),
                 self,
                 attributeName];
  
  if ([[self relationshipsByName] objectForKey: attributeName])
    [NSException raise: NSInvalidArgumentException
                 format: @"%@ -- %@ 0x%x: \"%@\" already used in the model as relationship",
                 NSStringFromSelector(_cmd),
                 NSStringFromClass([self class]),
                 self,
                 attributeName];
  
  if ([self createsMutableObjects])
    [(GCMutableArray *)_attributes addObject: attribute];
  else
    _attributes = [[[_attributes autorelease]
		     arrayByAddingObject: attribute] retain];

  [self _setIsEdited]; //To clean caches
  [attribute setParent: self];
}

- (void)removeAttribute: (EOAttribute *)attribute
{
  if (attribute)
    {
      [attribute setParent: nil];
      NSEmitTODO();  //TODO

      //TODO
      if ([self createsMutableObjects])
	[(GCMutableArray *)_attributes removeObject: attribute];
      else
        {
	  _attributes = [[_attributes autorelease] mutableCopy];
	  [(GCMutableArray *)_attributes removeObject: attribute];
	  _attributes = [[_attributes autorelease] copy];
        }
      [self _setIsEdited];//To clean caches
    }
}

- (void)addRelationship: (EORelationship *)relationship
{
  NSString *relationshipName = [relationship name];

  if ([[self attributesByName] objectForKey: relationshipName])
    [NSException raise: NSInvalidArgumentException
                 format: @"%@ -- %@ 0x%x: \"%@\" already used in the model as attribute",
                 NSStringFromSelector(_cmd),
                 NSStringFromClass([self class]),
                 self,
                 relationshipName];

  if ([[self relationshipsByName] objectForKey: relationshipName])
    [NSException raise: NSInvalidArgumentException
                 format: @"%@ -- %@ 0x%x: \"%@\" already used in the model",
                 NSStringFromSelector(_cmd),
                 NSStringFromClass([self class]),
                 self,
                 relationshipName];

  if ([self createsMutableObjects])
    [(GCMutableArray *)_relationships addObject: relationship];
  else
    _relationships = [[[_relationships autorelease]
			arrayByAddingObject: relationship] retain];
  
  [relationship setEntity: self];
  [self _setIsEdited];//To clean caches
}

- (void)removeRelationship: (EORelationship *)relationship
{
  NSEmitTODO();  //TODO

  //TODO
  if (relationship)
    {
      [relationship setEntity:nil];

      if ([self createsMutableObjects])
	[(GCMutableArray *)_relationships removeObject: relationship];
      else
        {
	  _relationships = [[_relationships autorelease] mutableCopy];
	  [(GCMutableArray *)_relationships removeObject: relationship];
	  _relationships = [[_relationships autorelease] copy];
        }
      [self _setIsEdited];//To clean caches
    }
}

- (void)addFetchSpecification: (EOFetchSpecification *)fetchSpec
			named: (NSString *)name
{
  [_fetchSpecificationDictionary setObject: fetchSpec forKey: name];
  ASSIGN(_fetchSpecificationNames, [[_fetchSpecificationDictionary allKeys]
				     sortedArrayUsingSelector:
				       @selector(compare:)]);
}

- (void)removeFetchSpecificationNamed: (NSString *)name
{
  [_fetchSpecificationDictionary removeObjectForKey:name];
  ASSIGN(_fetchSpecificationNames, [[_fetchSpecificationDictionary allKeys]
				     sortedArrayUsingSelector:
				       @selector(compare:)]);
}

- (void)setClassName:(NSString *)name
{
  //OK
  [self willChange];  

  if (!name)
    {
      NSLog(@"Entity %@ has no class name. Use EOGenericRecord", [self name]);
      name = @"EOGenericRecord";
    }
  ASSIGN(_className, name);
  [self _setIsEdited];
}

- (void)addSubEntity: (EOEntity *)child
{
  [_subEntities addObject: child];
  [child setParentEntity: self];
}

- (void)removeSubEntity: (EOEntity *)child
{
  [child setParentEntity: nil];
  [_subEntities removeObject: child];
}

- (void)setIsAbstractEntity: (BOOL)f
{
  //OK
  _flags.isAbstractEntity = f;
}

- (void)setMaxNumberOfInstancesToBatchFetch: (unsigned int)size
{
  _batchCount = size;
}

@end


@implementation EOEntity (EOModelReferentialIntegrity)

- (BOOL)referencesProperty: property
{
  NSEnumerator *enumerator;
  EORelationship *rel;
  EOAttribute *attr;

  enumerator = [[self attributes] objectEnumerator];
  while ((attr = [enumerator nextObject]))
    {
      if ([attr isFlattened] && [[attr realAttribute] isEqual: property])
	return YES;
    }

  enumerator = [[self relationships] objectEnumerator];
  while ((rel = [enumerator nextObject]))
    {
      if ([rel referencesProperty: property])
	return YES;
    }

  return NO;
}

- (NSArray *)externalModelsReferenced
{
  NSEmitTODO();  //TODO
  return nil; // TODO
}

@end


@implementation EOEntity (EOModelBeautifier)

- (void)beautifyName
{
  //VERIFY
  NSString *name = [self name];

  [self setName: name];
  
  [[self attributes] makeObjectsPerformSelector: @selector(beautifyName)];
  [[self relationships] makeObjectsPerformSelector: @selector(beautifyName)];
  [[self flattenedAttributes] makeObjectsPerformSelector: @selector(beautifyName)];

//Turbocat:
/*
// Make the entity name and all of its components conform
//     to the Next naming style
//     NAME -> name, FIRST_NAME -> firstName +
     NSArray		*listItems;
     NSString	*newString=[NSString string];
     int			anz,i;
     
   EOFLOGObjectFnStartOrCond2(@"ModelingClasses",@"EOEntity");
 
     // Makes the receiver's name conform to a standard convention. Names that conform to this style are all lower-case except for the initial letter of each embedded word other than the first, which is upper case. Thus, "NAME" becomes "name", and "FIRST_NAME" becomes "firstName".
 
     if ((_name) && ([_name length]>0)) {
         listItems=[_name componentsSeparatedByString:@"_"];
         newString=[newString stringByAppendingString:[[listItems objectAtIndex:0] lowercaseString]];
         anz=[listItems count];
         for (i=1; i < anz; i++) {
             newString=[newString stringByAppendingString:[[listItems objectAtIndex:i] capitalizedString]];
         }
 
 //#warning ergaenzen um alle components (attributes, ...)
 
         // Exception abfangen
         NS_DURING
             [self setName:newString];
         NS_HANDLER
             NSLog(@"%@ in Class: EOEntity , Method: beautifyName >> error : %@",[localException name],[localException reason]);
         NS_ENDHANDLER
     }
 
   EOFLOGObjectFnStopOrCond2(@"ModelingClasses",@"EOEntity");
*/
}

@end

@implementation EOEntity (MethodSet11)

- (NSException *)validateObjectForDelete: (id)object
{
//OK ??
  NSArray *relationships = nil;
  NSEnumerator *relEnum = nil;
  EORelationship *relationship = nil;
  NSMutableArray *expArray = nil;

  relationships = [self relationships];
  relEnum = [relationships objectEnumerator];

  while ((relationship = [relEnum nextObject]))
    {
//classproperties

//rien pour nullify
      if ([relationship deleteRule] == EODeleteRuleDeny)
        {
          if (!expArray)
            expArray = [NSMutableArray arrayWithCapacity:5];

          [expArray addObject:
                      [NSException validationExceptionWithFormat:
                                     @"delete operation for relationship key %@ refused",
                                   [relationship name]]];
        }
    }

  if (expArray)
    return [NSException aggregateExceptionWithExceptions:expArray];
  else
    return nil;
}

/** Retain an array of name of all EOAttributes **/
- (NSArray*) classPropertyAttributeNames
{
  //Should be OK
  if (!_classPropertyAttributeNames)
    {
      NSArray *classProperties = [self classProperties];
      int i, count = [classProperties count];
      Class attrClass = [EOAttribute class];

      _classPropertyAttributeNames = [NSMutableArray new]; //or GC ?

      for (i = 0; i < count; i++)
        {
          EOAttribute *property = [classProperties objectAtIndex: i];

          if ([property isKindOfClass: attrClass])
            [(NSMutableArray*)_classPropertyAttributeNames
			      addObject: [property name]];
        }

      EOFLOGObjectLevelArgs(@"EOEntity", @"_classPropertyAttributeNames=%@",
			    _classPropertyAttributeNames);
    }

  return _classPropertyAttributeNames;
}

- (NSArray*) classPropertyToManyRelationshipNames
{
  //Should be OK
  if (!_classPropertyToManyRelationshipNames)
    {
      NSArray *classProperties = [self classProperties];
      int i, count = [classProperties count];
      Class relClass = [EORelationship class];

      _classPropertyToManyRelationshipNames = [NSMutableArray new]; //or GC ?

      for (i = 0; i < count; i++)
        {
          EORelationship *property = [classProperties objectAtIndex: i];

          if ([property isKindOfClass: relClass]
	      && [property isToMany])
            [(NSMutableArray*)_classPropertyToManyRelationshipNames
			      addObject: [property name]];
        }
    }

  return _classPropertyToManyRelationshipNames;
}

- (NSArray*) classPropertyToOneRelationshipNames
{
  //Should be OK
  if (!_classPropertyToOneRelationshipNames)
    {
      NSArray *classProperties = [self classProperties];
      int i, count = [classProperties count];
      Class relClass = [EORelationship class];

      _classPropertyToOneRelationshipNames = [NSMutableArray new]; //or GC ?

      for (i = 0; i <count; i++)
        {
          EORelationship *property = [classProperties objectAtIndex: i];

          if ([property isKindOfClass: relClass]
	      && ![property isToMany])
            [(NSMutableArray*)_classPropertyToOneRelationshipNames
			      addObject: [property name]];
        }
    }

  return _classPropertyToOneRelationshipNames;
}

- (id) qualifierForDBSnapshot:(id)param0
{
  return [self notImplemented: _cmd]; //TODO
}

- (EOAttribute*) attributeForPath: (NSString*)path
{
  //OK
  EOAttribute *attribute = nil;
  NSArray *pathElements = nil;
  NSString *part = nil;
  EOEntity *entity = self;
  int i, count = 0;

  EOFLOGObjectFnStart();

  EOFLOGObjectLevelArgs(@"EOEntity", @"path=%@", path);

  pathElements = [path componentsSeparatedByString: @"."];
  EOFLOGObjectLevelArgs(@"EOEntity", @"pathElements=%@", pathElements);

  count = [pathElements count];

  for (i = 0; i < count - 1; i++)
    {      
      EORelationship *rel = nil;

      part = [pathElements objectAtIndex: i];
      EOFLOGObjectLevelArgs(@"EOEntity", @"i=%d part=%@", i, part);

      rel = [entity anyRelationshipNamed: part];

      NSAssert2(rel,
		@"no relationship named %@ in entity %@",
		part,
		[entity name]);
      EOFLOGObjectLevelArgs(@"EOEntity", @"i=%d part=%@ rel=%@",
			    i, part, rel);

      entity = [rel destinationEntity];
      EOFLOGObjectLevelArgs(@"EOEntity", @"entity name=%@", [entity name]);
    }

  part = [pathElements lastObject];
  EOFLOGObjectLevelArgs(@"EOEntity", @"part=%@", part);

  attribute = [entity anyAttributeNamed: part];
  EOFLOGObjectLevelArgs(@"EOEntity", @"resulting attribute=%@", attribute);

  EOFLOGObjectFnStop();

  return attribute;
}

- (EORelationship*) relationshipForPath: (NSString*)path
{
  //OK ?
  EORelationship *relationship = nil;
  EOEntity *entity = self;
  NSArray *pathElements = nil;
  int i, count;

  EOFLOGObjectFnStart();

  EOFLOGObjectLevelArgs(@"EOEntity", @"path=%@", path);

  pathElements = [path componentsSeparatedByString: @"."];
  count = [pathElements count];

  for (i = 0; i < count; i++)
    {
      NSString *part = [pathElements objectAtIndex: i];

      relationship = [entity anyRelationshipNamed: part];

      EOFLOGObjectLevelArgs(@"EOEntity", @"i=%d part=%@ rel=%@",
			    i, part, relationship);

      if (relationship)
        {
          entity = [relationship destinationEntity];
          EOFLOGObjectLevelArgs(@"EOEntity", @"entity name=%@", [entity name]);
        }
      else if (i < (count - 1)) // Not the last part
        {
          NSAssert2(relationship,
                    @"no relationship named %@ in entity %@",
                    part,
                    [entity name]);
        }
    }

  EOFLOGObjectFnStop();

  EOFLOGObjectLevelArgs(@"EOEntity", @"relationship=%@", relationship);

  return relationship;
}

- (void) _addAttributesToFetchForRelationshipPath: (NSString*)relPath
                                             atts: (NSMutableDictionary*)attributes
{
  NSArray *parts = nil;
  EORelationship *rel = nil;

  NSAssert([relPath length] > 0, @"Empty relationship path");

  //Verify when multi part path and not _relationshipPathIsToMany:path
  parts = [relPath componentsSeparatedByString: @"."];
  rel = [self relationshipNamed: [parts objectAtIndex: 0]];

  if (!rel)
    {
      NSEmitTODO();  //TODO
      //TODO
    }
  else
    {
      NSArray *joins = [rel joins];
      int i, count = [joins count];

      for (i = 0; i < count; i++)
        {
          EOJoin *join = [joins objectAtIndex: i];
          EOAttribute *attribute = [join sourceAttribute];

          [attributes setObject: attribute
                      forKey: [attribute name]];
        }
    }
}

- (NSArray*) dbSnapshotKeys
{
  //OK
  EOFLOGObjectFnStart();

  if (!_dbSnapshotKeys)
    {
      NSArray *attributesToFetch = [self _attributesToFetch];

      EOFLOGObjectLevelArgs(@"EOEntity", @"attributesToFetch=%@",
			    attributesToFetch);
      NSAssert3(!attributesToFetch
		|| [attributesToFetch isKindOfClass: [NSArray class]],
                @"entity %@ attributesToFetch is not an NSArray but a %@\n%@",
                [self name],
                [attributesToFetch class],
                attributesToFetch);

      ASSIGN(_dbSnapshotKeys,
             [GCArray arrayWithArray: [attributesToFetch
					resultsOfPerformingSelector:
					  @selector(name)]]);
    }

  EOFLOGObjectFnStop();

  return _dbSnapshotKeys;
}

- (NSArray*) flattenedAttributes
{
  //OK
  NSMutableArray *flattenedAttributes = [NSMutableArray array];
  NSArray *attributesToFetch = [self _attributesToFetch];
  int i, count = [attributesToFetch count];

  NSAssert3(!attributesToFetch
	    || [attributesToFetch isKindOfClass: [NSArray class]],
            @"entity %@ attributesToFetch is not an NSArray but a %@\n%@",
            [self name],
            [attributesToFetch class],
            attributesToFetch);

  for (i = 0; i < count; i++)
    {
      EOAttribute *attribute = [attributesToFetch objectAtIndex: i];

      if ([attribute isFlattened])
        [flattenedAttributes addObject: attribute];
    }

  return flattenedAttributes;
}

@end

@implementation EOEntity (EOStoredProcedures)

- (EOStoredProcedure *)storedProcedureForOperation: (NSString *)operation
{
  return [_storedProcedures objectForKey: operation];
}

- (void)setStoredProcedure: (EOStoredProcedure *)storedProcedure
              forOperation: (NSString *)operation
{
  [_storedProcedures setObject: storedProcedure
                     forKey: operation];
}

@end


@implementation EOEntity (EOPrimaryKeyGeneration)

- (NSString *)primaryKeyRootName
{
  if (_parent)
    return [_parent externalName];//mirko: [_parent primaryKeyRootName];

  return _externalName;
}

@end


@implementation EOEntity (EOEntityClassDescription)

- (EOClassDescription *)classDescriptionForInstances
{
  EOFLOGObjectFnStart();

//  EOFLOGObjectLevelArgs(@"EOEntity", @"in classDescriptionForInstances");
  EOFLOGObjectLevelArgs(@"EOEntity", @"_classDescription=%@",
			_classDescription);

  if (!_classDescription)
    {
      _classDescription = [EOEntityClassDescription
			    entityClassDescriptionWithEntity: self];

//NO ? NotifyCenter addObserver:EOEntityClassDescription selector:_eoNowMultiThreaded: name:NSWillBecomeMultiThreadedNotification object:nil
    }

  EOFLOGObjectFnStop();

  return _classDescription;
}

@end

@implementation EOEntity (EOEntityPrivate)

- (void)setCreateMutableObjects: (BOOL)flag
{
  if (_flags.createsMutableObjects == flag)
    return;

  _flags.createsMutableObjects = flag;

//TODO  NSEmitTODO();

  if (_flags.createsMutableObjects)
    {
      _attributes = [[_attributes autorelease] mutableCopy];
      _relationships = [[_relationships autorelease] mutableCopy];
    }
  else
    {
      _attributes = [[_attributes autorelease] copy];
      _relationships = [[_relationships autorelease] copy];
    }

  NSAssert4(!_attributesToFetch
	    || [_attributesToFetch isKindOfClass: [NSArray class]],
            @"entity %@ attributesToFetch %p is not an NSArray but a %@\n%@",
            [self name],
            _attributesToFetch,
            [_attributesToFetch class],
            _attributesToFetch);
}

- (BOOL)createsMutableObjects
{
  return _flags.createsMutableObjects;
}

- (void)setModel: (EOModel *)model
{
  EOFLOGObjectLevelArgs(@"EOEntity", @"setModel=%p", model);

  NSAssert4(!_attributesToFetch
	    || [_attributesToFetch isKindOfClass:[NSArray class]],
            @"entity %@ attributesToFetch %p is not an NSArray but a %@\n%@",
            [self name],
            _attributesToFetch,
            [_attributesToFetch class],
            _attributesToFetch);

  [self _setModel: model];
}

- (void)setParentEntity: (EOEntity *)parent
{
  ASSIGN(_parent, parent);
}

- (NSDictionary *)snapshotForRow: (NSDictionary *)aRow
{
  NSArray *array = [self attributesUsedForLocking];
  int i, n = [array count];
  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: n];
    
  for (i = 0; i < n; i++)
    {
      id key = [(EOAttribute *)[array objectAtIndex: i] name];

      [dict setObject: [aRow objectForKey:key] forKey: key];
    }

  return dict;
}

@end

@implementation EOEntity (EOEntityHidden)

/** Returns attributes by name (only attributes, not relationships) **/
- (NSDictionary*)attributesByName
{
  EOFLOGObjectFnStart();

  if (_attributesByName)
    {
      EOFLOGObjectLevelArgs(@"EOEntity", @"_attributesByName [%p] (%@)",
			    _attributesByName,
			    [_attributesByName class]);
      NSAssert2((!_attributesByName
		 || [_attributesByName isKindOfClass: [NSDictionary class]]),
                @"_attributesByName is not a NSDictionary but a %@. _attributesByName [%p]",
                [_attributesByName class],
                _attributesByName);
    }
  else
    {
      EOFLOGObjectLevelArgs(@"EOEntity", @"Will Rebuild attributes");

      [self attributes]; //To rebuild

      EOFLOGObjectLevelArgs(@"EOEntity", @"_attributesByName [%p] (%@)",
			    _attributesByName,
			    [_attributesByName class]);
      NSAssert2((!_attributesByName
		 || [_attributesByName isKindOfClass:[NSDictionary class]]),
                @"_attributesByName is not a NSDictionary but a %@. _attributesByName [%p]",
                [_attributesByName class],
                _attributesByName);
    }

  EOFLOGObjectFnStop();

  return _attributesByName;
}

- (NSDictionary*)relationshipsByName
{
  if (!_relationshipsByName)
    {
      [self relationships]; //To rebuild
    }
  return _relationshipsByName;
}

- (NSArray*) _allFetchSpecifications
{
  //OK
  NSDictionary *fetchSpecificationDictionary =
    [self _fetchSpecificationDictionary];
  NSArray *fetchSpecValues = [fetchSpecificationDictionary allValues];

  return fetchSpecValues;
}

- (NSDictionary*) _fetchSpecificationDictionary
{
  //OK
  return _fetchSpecificationDictionary;
}

- (void) _loadEntity
{
  //TODO
  [self notImplemented: _cmd];
}

- (id) parentRelationship
{
  //TODO
  return [self notImplemented: _cmd];
}

- (int) _numberOfRelationships
{
  //OK
  return [[self relationships] count];
}

- (BOOL) _hasReadOnlyAttributes
{
  //OK
  BOOL hasReadOnlyAttributes = NO;
  NSArray *attributes = [self attributes];
  int i, count=[attributes count];

  for (i = 0; !hasReadOnlyAttributes && i < count; i++)
    hasReadOnlyAttributes = [[attributes objectAtIndex: i] isReadOnly];

  return hasReadOnlyAttributes;
}

- (NSArray*) writableDBSnapshotKeys
{
  //OK
  NSMutableArray *writableDBSnapshotKeys = [NSMutableArray array];

  if (![self isReadOnly])
    {
      NSArray *attributesToFetch = [self _attributesToFetch];
      int i, count = [attributesToFetch count];

      NSAssert3(!attributesToFetch
		|| [attributesToFetch isKindOfClass: [NSArray class]],
                @"entity %@ attributesToFetch is not an NSArray but a %@\n%@",
                [self name],
                [attributesToFetch class],
                attributesToFetch);

      for (i = 0; i < count; i++)
        {
          EOAttribute *attribute = [attributesToFetch objectAtIndex: i];

          if (![attribute isReadOnly])
            [writableDBSnapshotKeys addObject: [attribute name]];
        }
    }

  return writableDBSnapshotKeys;
}

- (NSArray*) rootAttributesUsedForLocking
{
  //OK ?
  NSMutableArray *rootAttributesUsedForLocking = [NSMutableArray array];
  NSArray *attributesUsedForLocking = [self attributesUsedForLocking];
  int i, count = [attributesUsedForLocking count];

  for (i = 0; i < count; i++)
    {
      EOAttribute *attribute = [attributesUsedForLocking objectAtIndex: i];
      if (![attribute isDerived])
        [rootAttributesUsedForLocking addObject: attribute];
    }

  return rootAttributesUsedForLocking;
}

- (BOOL) isSubEntityOf: (id)param0
{
  //TODO
  [self notImplemented: _cmd];
  return NO;
}

- (id) initObject: (id)param0
   editingContext: (id)param1
         globalID: (id)param2
{
  //TODO
  return [self notImplemented: _cmd];
}

- (id) allocBiggestObjectWithZone: (NSZone*)zone
{
  //TODO
  return [self notImplemented: _cmd];
}

- (Class) _biggestClass
{
  //OK
  Class biggestClass = Nil;

  biggestClass = [self classForObjectWithGlobalID: nil];

  return biggestClass;
}

- (NSArray*) relationshipsPlist
{
  //OK
  NSMutableArray *relsPlist;

  if (_flags.relationshipsIsLazy)
    {
      relsPlist = _relationships;
    }
  else
    {
      NSArray *relationships;
      int relCount;

      relsPlist = [NSMutableArray array];
      relationships = [self relationships];
      relCount = [relationships count];

      if (relCount > 0)
        {
          int i;

          for (i = 0; i < relCount; i++)
            {
              NSMutableDictionary *relPlist = [NSMutableDictionary dictionary];
              EORelationship *rel = [relationships objectAtIndex: i];

              [rel encodeIntoPropertyList: relPlist];
              [relsPlist addObject: relPlist];
            }
        }
    }

  return relsPlist;
}

- (id) rootParent
{
  id prevParent = self;
  id parent = self;

  while (parent)
  {
    prevParent = parent;
    parent = [prevParent parentEntity];
  }

  return prevParent;
}

- (void) _setParent: (id)param0
{
  //TODO
  [self notImplemented: _cmd];
}

- (NSArray*) _hiddenRelationships
{
  //OK
  if (!_hiddenRelationships)
    _hiddenRelationships = [NSMutableArray new];

  return _hiddenRelationships;
}

- (NSArray*) _propertyNames
{
  //OK
  NSMutableArray *propertyNames = nil;
  NSArray *attributes = [self attributes];
  NSArray *attributeNames = [attributes resultsOfPerformingSelector:
					  @selector(name)];
  NSArray *relationships = [self relationships];
  NSArray *relationshipNames = [relationships resultsOfPerformingSelector:
						@selector(name)];

  propertyNames = [NSMutableArray arrayWithArray: attributeNames];
  [propertyNames addObjectsFromArray: relationshipNames];

  return propertyNames;
}

- (id) _flattenAttribute: (id)param0
        relationshipPath: (id)param1
       currentAttributes: (id)param2
{
  //TODO
  return [self notImplemented: _cmd];
}

- (NSString*) snapshotKeyForAttributeName: (NSString*)attributeName
{
  NSString *attName = [self _flattenedAttNameToSnapshotKeyMapping];

  if (attName)
    {
      NSEmitTODO(); //TODO
      [self notImplemented: _cmd];
    }
  else
      attName = attributeName; //TODO-VERIFY

  return attName;
}

- (id) _flattenedAttNameToSnapshotKeyMapping
{
  //  NSArray *attributesToSave = [self _attributesToSave];

  //NSEmitTODO(); //TODO

  return nil; //[self notImplemented:_cmd]; //TODO
}

- (EOMKKDSubsetMapping*) _snapshotToAdaptorRowSubsetMapping
{
  if (!_snapshotToAdaptorRowSubsetMapping)
    {
      EOMKKDInitializer *snapshotDictionaryInitializer =
	[self _snapshotDictionaryInitializer];
      EOMKKDInitializer *adaptorDictionaryInitializer =
	[self _adaptorDictionaryInitializer];
      EOMKKDSubsetMapping *subsetMapping =
	[snapshotDictionaryInitializer 
	  subsetMappingForSourceDictionaryInitializer: adaptorDictionaryInitializer];

      ASSIGN(_snapshotToAdaptorRowSubsetMapping,subsetMapping);
    }

  return  _snapshotToAdaptorRowSubsetMapping;
}

- (EOMutableKnownKeyDictionary*) _dictionaryForPrimaryKey
{
  //OK
  EOMKKDInitializer *primaryKeyDictionaryInitializer =
    [self _primaryKeyDictionaryInitializer];
  EOMutableKnownKeyDictionary *dictionaryForPrimaryKey =
    [EOMutableKnownKeyDictionary dictionaryWithInitializer:
				   primaryKeyDictionaryInitializer];

  return dictionaryForPrimaryKey;
}

- (EOMutableKnownKeyDictionary*) _dictionaryForProperties
{
  //OK
  EOMKKDInitializer *propertyDictionaryInitializer = nil;
  EOMutableKnownKeyDictionary *dictionaryForProperties = nil;

  EOFLOGObjectFnStart();

  propertyDictionaryInitializer = [self _propertyDictionaryInitializer];

  EOFLOGObjectLevelArgs(@"EOEntity", @"propertyDictionaryInitializer=%@",
			propertyDictionaryInitializer);

  dictionaryForProperties = [EOMutableKnownKeyDictionary
			      dictionaryWithInitializer:
				propertyDictionaryInitializer];

  EOFLOGObjectLevelArgs(@"EOEntity", @"dictionaryForProperties=%@",
			dictionaryForProperties);

  EOFLOGObjectFnStop();

  return dictionaryForProperties;
}

- (NSArray*) _relationshipsToFaultForRow: (NSDictionary*)row
{
  NSMutableArray *rels = [NSMutableArray array];
  NSArray *classProperties = [self classProperties];
  int i, count = [classProperties count];

  for (i = 0; i < count; i++)
    {
      EORelationship *classProperty = [classProperties objectAtIndex: i];

      if ([classProperty isKindOfClass: [EORelationship class]])
        {
          EORelationship *relsubs = [classProperty
				      _substitutionRelationshipForRow: row];

          [rels addObject: relsubs];
        }
    }

  return rels;
}

- (NSArray*) _classPropertyAttributes
{
  //OK
  //IMPROVE We can improve this by caching the result....
  NSMutableArray *classPropertyAttributes = [NSMutableArray array];
  //Get classProperties (EOAttributes + EORelationships)
  NSArray *classProperties = [self classProperties];
  int i, count = [classProperties count];

  for (i = 0; i < count; i++)
    {
      id object = [classProperties objectAtIndex: i];

      if ([object isKindOfClass: [EOAttribute class]])
        [classPropertyAttributes addObject: object];
    }

  return classPropertyAttributes;
}

- (NSArray*) _attributesToSave
{
  //Near OK
  EOFLOGObjectLevelArgs(@"EOEntity",
			@"START Entity _attributesToSave entityname=%@",
			[self name]);

  if (!_attributesToSave)
    {
      NSMutableArray *attributesToSave = [GCMutableArray array];
      NSArray *attributesToFetch = [self _attributesToFetch];
      int i, count = [attributesToFetch count];

      NSAssert3(!attributesToFetch
		|| [attributesToFetch isKindOfClass: [NSArray class]],
                @"entity %@ attributesToFetch is not an NSArray but a %@\n%@",
                [self name],
                [_attributesToFetch class],
                _attributesToFetch);

      for (i = 0; i < count; i++)
        {
          EOAttribute *attribute = [attributesToFetch objectAtIndex: i];
          BOOL isFlattened = [attribute isFlattened]; 

          if (!isFlattened)
            [attributesToSave addObject: attribute];
        }
      ASSIGN(_attributesToSave, attributesToSave);
    }

  EOFLOGObjectLevelArgs(@"EOEntity", @"STOP Entity _attributesToSave entityname=%@ attrs:%@",
			[self name], _attributesToSave);

  return _attributesToSave;
}

//sorted by name attributes
- (NSArray*) _attributesToFetch
{
  //Seems OK
  EOFLOGObjectLevelArgs(@"EOEntity",
			@"START Entity _attributesToFetch entityname=%@",
			[self name]);
  EOFLOGObjectLevelArgs(@"EOEntity", @"AttributesToFetch:%p",
			_attributesToFetch);
  EOFLOGObjectLevelArgs(@"EOEntity", @"AttributesToFetch:%@",
			_attributesToFetch);

  NSAssert2(!_attributesToFetch
	    || [_attributesToFetch isKindOfClass: [NSArray class]],
            @"entity %@ attributesToFetch is not an NSArray but a %@",
            [self name],
            [_attributesToFetch class]);

  if (!_attributesToFetch)
    {
      NSMutableDictionary *attributesDict = [NSMutableDictionary dictionary];
      NS_DURING
        {
          int iArray = 0;
          NSArray *arrays[] = { [self attributesUsedForLocking],
                                [self primaryKeyAttributes],
                                [self classProperties],
                                [self relationships] };

          _attributesToFetch = [[GCMutableArray array] retain];
          
          EOFLOGObjectLevelArgs(@"EOEntity", @"Entity %@ - _attributesToFetch %p [RC=%d]:%@",
                                [self name],
                                _attributesToFetch,
                                [_attributesToFetch retainCount],
                                _attributesToFetch);
          
          for (iArray = 0; iArray < 4; iArray++)
            {
              int i, count = 0;
              
              EOFLOGObjectLevelArgs(@"EOEntity", @"Entity %@ - arrays[iArray]:%@",
                                    [self name], arrays[iArray]);

              count = [arrays[iArray] count];
              
              for (i = 0; i < count; i++)
                {
                  id property = [arrays[iArray] objectAtIndex: i];
                  NSString *propertyName = [(EOAttribute*)property name];
                  
                  //VERIFY
                  EOFLOGObjectLevelArgs(@"EOEntity",
                                        @"propertyName=%@ - property=%@",
                                        propertyName, property);
                  
                  if ([property isKindOfClass: [EOAttribute class]])
                    {
		      EOAttribute *attribute = property;

                      if ([attribute isFlattened])
                        {
                          attribute = [[attribute _definitionArray]
					objectAtIndex: 0];
                          propertyName = [attribute name];
                        }
                    }
                  
                  if ([property isKindOfClass: [EORelationship class]])
                    {
                      [self _addAttributesToFetchForRelationshipPath:
                              [(EORelationship*)property relationshipPath]
                        atts: attributesDict];
                    }
                  else if ([property isKindOfClass: [EOAttribute class]])
                    {
                      [attributesDict setObject: property
                                      forKey: propertyName];
                    }
                  else
                    {
                      NSEmitTODO();  //TODO
                    }
                }
            }
        }
      NS_HANDLER
        {
          NSDebugMLog(@"Exception: %@",localException);
          [localException raise];
        }
      NS_ENDHANDLER;
      NS_DURING
        {
          NSDebugMLog(@"Attributes to fetch classes %@",
                      [_attributesToFetch resultsOfPerformingSelector:
                                            @selector(class)]);
          
          [_attributesToFetch addObjectsFromArray: [attributesDict allValues]];
          
          NSDebugMLog(@"Attributes to fetch classes %@",
                      [_attributesToFetch resultsOfPerformingSelector:
                                            @selector(class)]);
          
          [_attributesToFetch sortUsingSelector: @selector(eoCompareOnName:)]; //Very important to have always the same order.
        }
      NS_HANDLER
        {
          NSDebugMLog(@"Exception: %@",localException);
          [localException raise];
        }
      NS_ENDHANDLER;
    };

  NSAssert3(!_attributesToFetch
	    || [_attributesToFetch isKindOfClass: [NSArray class]],
            @"Entity %@: _attributesToFetch is not an NSArray but a %@\n%@",
            [self name],
            [_attributesToFetch class],
            _attributesToFetch);

  EOFLOGObjectLevelArgs(@"EOEntity", @"Stop Entity %@ - _attributesToFetch %p [RC=%d]:%@",
			[self name],
			_attributesToFetch,
			[_attributesToFetch retainCount],
			_attributesToFetch);

  return _attributesToFetch;
}

- (EOMKKDInitializer*) _adaptorDictionaryInitializer
{
  //OK
  EOFLOGObjectLevelArgs(@"EOEntity", @"Start _adaptorDictionaryInitializer=%@",
			_adaptorDictionaryInitializer);

  if (!_adaptorDictionaryInitializer)
    {
      NSArray *attributesToFetch = [self _attributesToFetch];
      NSArray *attributeToFetchNames = [attributesToFetch
					 resultsOfPerformingSelector:
					   @selector(name)];

      EOFLOGObjectLevelArgs(@"EOEntity", @"attributeToFetchNames=%@",
			    attributeToFetchNames);

      NSAssert3(!attributesToFetch
		|| [attributesToFetch isKindOfClass: [NSArray class]],
                @"entity %@ attributesToFetch is not an NSArray but a %@\n%@",
                [self name],
                [attributesToFetch class],
                attributesToFetch);
      NSAssert1([attributesToFetch count] > 0,
		@"No Attributes to fetch in entity %@", [self name]);
      NSAssert1([attributeToFetchNames count] > 0,
		@"No Attribute names to fetch in entity %@", [self name]);

      EOFLOGObjectLevelArgs(@"EOEntity", @"entity named %@: attributeToFetchNames=%@",
			    [self name],
			    attributeToFetchNames);

      ASSIGN(_adaptorDictionaryInitializer,
	     [EOMutableKnownKeyDictionary initializerFromKeyArray:
					    attributeToFetchNames]);

      EOFLOGObjectLevelArgs(@"EOEntity", @"entity named %@ _adaptorDictionaryInitializer=%@",
			    [self name],
			    _adaptorDictionaryInitializer);
    }

  EOFLOGObjectLevelArgs(@"EOEntity", @"Stop _adaptorDictionaryInitializer=%p",
			_adaptorDictionaryInitializer);
  EOFLOGObjectLevelArgs(@"EOEntity", @"Stop _adaptorDictionaryInitializer=%@",
			_adaptorDictionaryInitializer);

  return _adaptorDictionaryInitializer;
}

- (EOMKKDInitializer*) _snapshotDictionaryInitializer
{
  if (!_snapshotDictionaryInitializer)
    {
      NSArray *dbSnapshotKeys = [self dbSnapshotKeys];

      ASSIGN(_snapshotDictionaryInitializer,
	     [EOMutableKnownKeyDictionary initializerFromKeyArray:
					    dbSnapshotKeys]);
    }

  return _snapshotDictionaryInitializer;
}

- (EOMKKDInitializer*) _primaryKeyDictionaryInitializer
{
  //OK
  if (!_primaryKeyDictionaryInitializer)
    {
      NSArray *primaryKeyAttributeNames = [self primaryKeyAttributeNames];

      NSAssert1([primaryKeyAttributeNames count] > 0,
		@"No primaryKeyAttributeNames in entity %@", [self name]);

      EOFLOGObjectLevelArgs(@"EOEntity", @"entity named %@: primaryKeyAttributeNames=%@",
			    [self name],
			    primaryKeyAttributeNames);

      _primaryKeyDictionaryInitializer = [EOMKKDInitializer
					   newWithKeyArray:
					     primaryKeyAttributeNames];

      EOFLOGObjectLevelArgs(@"EOEntity", @"entity named %@: _primaryKeyDictionaryInitializer=%@",
			    [self name],
			    _primaryKeyDictionaryInitializer);
    }

  return _primaryKeyDictionaryInitializer;
}

- (EOMKKDInitializer*) _propertyDictionaryInitializer
{
  //OK
  // If not already built, built it
  if (!_propertyDictionaryInitializer)
    {
      // Get class properties (EOAttributes + EORelationships)
      NSArray *classProperties = [self classProperties];
      NSArray *classPropertyNames =
	[classProperties resultsOfPerformingSelector: @selector(name)];

      EOFLOGObjectLevelArgs(@"EOEntity", @"entity %@ classPropertyNames=%@",
			    [self name], classPropertyNames);

      NSAssert1([classProperties count] > 0,
		@"No classProperties in entity %@", [self name]);
      NSAssert1([classPropertyNames count] > 0,
		@"No classPropertyNames in entity %@", [self name]);

      //Build the multiple known key initializer
      _propertyDictionaryInitializer = [EOMKKDInitializer
					 newWithKeyArray: classPropertyNames];
    }

  return _propertyDictionaryInitializer;
}

- (void) _setModel: (EOModel *)model
{
  EOFLOGObjectFnStart();

  EOFLOGObjectLevelArgs(@"EOEntity", @"_setModel=%p", model);
  ASSIGN(_model, model);

  EOFLOGObjectFnStop();
}

- (void) _setIsEdited
{
  EOFLOGObjectLevelArgs(@"EOEntity", @"START entity name=%@", [self name]);

  NSAssert4(!_attributesToFetch
	    || [_attributesToFetch isKindOfClass: [NSArray class]],
            @"entity %@ attributesToFetch %p is not an NSArray but a %@\n%@",
            [self name],
            _attributesToFetch,
            [_attributesToFetch class],
            _attributesToFetch);

  //Destroy cached ivar
  EOFLOGObjectLevelArgs(@"EOEntity", @"_classPropertyNames: void:%p [%p] %s",
			(void*)nil, (void*)_classPropertyNames,
			(_classPropertyNames ? "Not NIL" : "NIL"));
  DESTROY(_classPropertyNames);

  EOFLOGObjectLevelArgs(@"EOEntity", @"_primaryKeyAttributeNames: %p %s",
			(void*)_primaryKeyAttributeNames,
			(_primaryKeyAttributeNames ? "Not NIL" : "NIL"));
  DESTROY(_primaryKeyAttributeNames);

  EOFLOGObjectLevelArgs(@"EOEntity", @"_classPropertyAttributeNames: %p %s",
			_classPropertyAttributeNames,
			(_classPropertyAttributeNames ? "Not NIL" : "NIL"));
  DESTROY(_classPropertyAttributeNames);

  EOFLOGObjectLevelArgs(@"EOEntity", @"_classPropertyToOneRelationshipNames: %p %s",
			_classPropertyToOneRelationshipNames,
			(_classPropertyToOneRelationshipNames ? "Not NIL" : "NIL"));
  DESTROY(_classPropertyToOneRelationshipNames);

  EOFLOGObjectLevelArgs(@"EOEntity", @"_classPropertyToManyRelationshipNames: %p %s",
			_classPropertyToManyRelationshipNames,
			(_classPropertyToManyRelationshipNames ? "Not NIL" : "NIL"));
  DESTROY(_classPropertyToManyRelationshipNames);

  EOFLOGObjectLevelArgs(@"EOEntity", @"_attributesToFetch: %p %s",
			_attributesToFetch,
			(_attributesToFetch ? "Not NIL" : "NIL"));
  DESTROY(_attributesToFetch);

  EOFLOGObjectLevelArgs(@"EOEntity", @"_dbSnapshotKeys: %p %s",
			_dbSnapshotKeys, (_dbSnapshotKeys ? "Not NIL" : "NIL"));
  DESTROY(_dbSnapshotKeys);

  EOFLOGObjectLevelArgs(@"EOEntity", @"_attributesToSave: %p %s",
			_attributesToSave, (_attributesToSave ? "Not NIL" : "NIL"));
  DESTROY(_attributesToSave);

  EOFLOGObjectLevelArgs(@"EOEntity", @"_propertiesToFault: %p %s",
			_propertiesToFault, (_propertiesToFault ? "Not NIL" : "NIL"));
  DESTROY(_propertiesToFault);

  EOFLOGObjectLevelArgs(@"EOEntity", @"_adaptorDictionaryInitializer: %p %s",
			_adaptorDictionaryInitializer,
			(_adaptorDictionaryInitializer ? "Not NIL" : "NIL"));
  DESTROY(_adaptorDictionaryInitializer);

  EOFLOGObjectLevelArgs(@"EOEntity", @"_snapshotDictionaryInitializer: %p %s",
			_snapshotDictionaryInitializer,
			(_snapshotDictionaryInitializer ? "Not NIL" : "NIL"));
  DESTROY(_snapshotDictionaryInitializer);

  EOFLOGObjectLevelArgs(@"EOEntity",@"_primaryKeyDictionaryInitializer: %p %s",
			_primaryKeyDictionaryInitializer,
			(_primaryKeyDictionaryInitializer ? "Not NIL" : "NIL"));
  DESTROY(_primaryKeyDictionaryInitializer);

  EOFLOGObjectLevelArgs(@"EOEntity",@"_propertyDictionaryInitializer: %p %s",
			_propertyDictionaryInitializer,
			(_propertyDictionaryInitializer ? "Not NIL" : "NIL"));
  DESTROY(_propertyDictionaryInitializer);

  //TODO call _flushCache on each attr
  NSAssert4(!_attributesToFetch
	    || [_attributesToFetch isKindOfClass: [NSArray class]],
            @"entity %@ attributesToFetch %p is not an NSArray but a %@\n%@",
            [self name],
            _attributesToFetch,
            [_attributesToFetch class],
            _attributesToFetch);

  EOFLOGObjectLevelArgs(@"EOEntity", @"STOP%s", "");
}

@end

@implementation EOEntity (EOKeyGlobalID)

- (id) globalIDForRow: (NSDictionary*)row
              isFinal: (BOOL)isFinal
{
  EOKeyGlobalID *globalID = nil;
  NSArray *primaryKeyAttributeNames = nil;
  int count = 0;

  NSAssert([row count] > 0, @"Empty Row.");

  primaryKeyAttributeNames = [self primaryKeyAttributeNames];
  count = [primaryKeyAttributeNames count];  
  {
    id keyArray[count];
    int i;

    memset(keyArray, 0, sizeof(id) * count);

    for (i = 0; i < count; i++)
      keyArray[i] = [row objectForKey:
			   [primaryKeyAttributeNames objectAtIndex: i]];

    globalID = [EOKeyGlobalID globalIDWithEntityName: [self name]
			      keys: keyArray
			      keyCount: count
			      zone: [self zone]];
  }

  //NSEmitTODO();  //TODO
  //TODO isFinal  ??

  return globalID;
};

- (EOGlobalID *)globalIDForRow: (NSDictionary *)row
{
  EOGlobalID *gid = [self globalIDForRow: row
			  isFinal: NO];

  NSAssert(gid, @"No gid");
//TODO
/*
pas toutjur: la suite editingc objectForGlobalID:
EODatabaseContext snapshotForGlobalID:
  if no snpashot:
  {
database recordSnapshot:forGlobalID:
self classDescriptionForInstances
createInstanceWithEditingContext:globalID:zone:
  }
*/
  return gid;
}
                                                          
-(Class)classForObjectWithGlobalID: (EOKeyGlobalID*)globalID
{
  //near OK
  EOFLOGObjectFnStart();

  //TODO:use globalID ??
  if (!_classForInstances)
    {
      NSString *className;
      Class objectClass;

      className = [self className];
      EOFLOGObjectLevelArgs(@"EOEntity", @"className=%@", className);

      objectClass = NSClassFromString(className);

      if (!objectClass)
        {
          NSLog(@"Error: No class named %@", className);
        }
      else
        {
          EOFLOGObjectLevelArgs(@"EOEntity", @"objectClass=%@", objectClass);
          ASSIGN(_classForInstances, objectClass);
        }
    }

  EOFLOGObjectFnStop();

  return _classForInstances;
}

- (NSDictionary *)primaryKeyForGlobalID: (EOKeyGlobalID *)gid
{
  //OK
  NSMutableDictionary *dictionaryForPrimaryKey = nil;

  EOFLOGObjectFnStart();

  EOFLOGObjectLevelArgs(@"EOEntity", @"gid=%@", gid);

  if ([gid isKindOfClass: [EOKeyGlobalID class]]) //if ([gid isFinal])//?? or class test ??//TODO
    {
      NSArray *primaryKeyAttributeNames = [self primaryKeyAttributeNames];
      int count = [primaryKeyAttributeNames count];

      EOFLOGObjectLevelArgs(@"EOEntity", @"primaryKeyAttributeNames=%@",
			    primaryKeyAttributeNames);

      if (count > 0)
        {
          int i;
          id *gidkeyValues = [gid keyValues];

          if (gidkeyValues)
            {
              dictionaryForPrimaryKey = [self _dictionaryForPrimaryKey];

              NSAssert1(dictionaryForPrimaryKey,
			@"No dictionaryForPrimaryKey in entity %@",
                        [self name]);
              EOFLOGObjectLevelArgs(@"EOEntity", @"dictionaryForPrimaryKey=%@",
				    dictionaryForPrimaryKey);

              for (i = 0; i < count; i++)
                {
                  id key = [primaryKeyAttributeNames objectAtIndex: i];

                  [dictionaryForPrimaryKey setObject: gidkeyValues[i]
                                           forKey: key];
                }
            }
        }
    }
  else
    NSLog(@"EOEntity (%@): primaryKey is *nil* for globalID = %@", _name, gid);

  EOFLOGObjectLevelArgs(@"EOEntity", @"dictionaryForPrimaryKey=%@",
			dictionaryForPrimaryKey);

  EOFLOGObjectFnStop();

  return dictionaryForPrimaryKey;
}

@end

@implementation EOEntity (EOEntityRelationshipPrivate)

- (EORelationship*) _inverseRelationshipPathForPath: (NSString*)path
{
  //TODO
  return [self notImplemented: _cmd];
}

- (NSDictionary*) _keyMapForIdenticalKeyRelationshipPath: (NSString*)path
{
  NSDictionary *keyMap = nil;
  EORelationship *rel;
  NSMutableArray *sourceAttributeNames = [NSMutableArray array];
  NSMutableArray *destinationAttributeNames = [NSMutableArray array];
  NSArray *joins;
  int i, count = 0;

  //use path,not only one element ?
  rel = [self relationshipNamed: path];
  joins = [rel joins];
  count = [joins count];

  for (i = 0; i < count; i++)
    {
      EOJoin *join = [joins objectAtIndex: i];
      EOAttribute *sourceAttribute = [join sourceAttribute];
      EOAttribute *destinationAttribute =
	[self _mapAttribute:sourceAttribute 
	      toDestinationAttributeInLastComponentOfRelationshipPath: path];

      [sourceAttributeNames addObject: [sourceAttribute name]];
      [destinationAttributeNames addObject: [destinationAttribute name]];
    }

  keyMap = [NSDictionary dictionaryWithObjectsAndKeys:
			   sourceAttributeNames, @"sourceKeys",
			 destinationAttributeNames, @"destinationKeys",
			 nil, nil];
  //return something like {destinationKeys = (code); sourceKeys = (languageCode); }

  return keyMap;
}

- (EOAttribute*) _mapAttribute: (EOAttribute*)attribute
toDestinationAttributeInLastComponentOfRelationshipPath: (NSString*)path
{
  NSArray *components = nil;
  EORelationship *rel = nil;
  NSArray *sourceAttributes = nil;
  NSArray *destinationAttributes = nil;
  EOEntity *destinationEntity = nil;

  NSAssert(attribute, @"No attribute");
  NSAssert(path, @"No path");
  NSAssert([path length] > 0, @"Empty path");

  components = [path componentsSeparatedByString: @"."];
  NSAssert([components count] > 0, @"Empty components array");

  rel = [self relationshipNamed: [components lastObject]];
  sourceAttributes = [rel sourceAttributes];
  destinationAttributes = [rel destinationAttributes];
  destinationEntity = [rel destinationEntity];

  NSEmitTODO();  //TODO

  return [self notImplemented: _cmd];
}

- (BOOL) _relationshipPathIsToMany: (NSString*)relPath
{
  //Seems OK
  BOOL isToMany = NO;
  NSArray *parts = [relPath componentsSeparatedByString: @"."];
  EOEntity *entity = self;
  int i, count = [parts count];

  for (i = 0 ; !isToMany && i < count; i++) //VERIFY Stop when finding the 1st isToMany ?
    {
      EORelationship *rel = [entity relationshipNamed:
				      [parts objectAtIndex: i]];

      isToMany = [rel isToMany];

      if (!isToMany)
        entity = [rel destinationEntity];
    }

  return isToMany;
}

- (BOOL) _relationshipPathHasIdenticalKeys: (id)param0
{
  [self notImplemented: _cmd];
  return NO;
}

- (NSDictionary *)_keyMapForRelationshipPath: (NSString *)path
{
  //NearOK
  NSMutableArray *sourceKeys = [NSMutableArray array];
  NSMutableArray *destinationKeys = [NSMutableArray array];
  NSArray *attributesToFetch = [self _attributesToFetch]; //Use It !!
  EORelationship *relationship = [self anyRelationshipNamed: path]; //?? iterate on path ? //TODO

  NSEmitTODO();  //TODO

  if (relationship)
    {
      NSArray *joins = [relationship joins];
      int i, count = [joins count];

      for(i = 0; i < count; i++)
        {
          EOJoin *join = [joins objectAtIndex: i];
          EOAttribute *sourceAttribute = [join sourceAttribute];
          EOAttribute *destinationAttribute = [join destinationAttribute];

          [sourceKeys addObject: [sourceAttribute name]];
          [destinationKeys addObject: [destinationAttribute name]];
        }
    }

  return [NSDictionary dictionaryWithObjectsAndKeys:
                         sourceKeys, @"sourceKeys",
                       destinationKeys, @"destinationKeys",
                       nil];
//{destinationKeys = (code); sourceKeys = (countryCode); }
}

@end


@implementation EOEntity (EOEntitySQLExpression)

- (NSString*) valueForSQLExpression: (EOSQLExpression*)sqlExpression
{
  return [self notImplemented: _cmd]; //TODO
}

+ (NSString*) valueForSQLExpression: (EOSQLExpression*)sqlExpression
{
  return [self notImplemented: _cmd]; //TODO
}

@end

@implementation EOEntity (EOEntityPrivateXX)

- (EOExpressionArray*) _parseDescription: (NSString*)description
                                isFormat: (BOOL)isFormat
                               arguments: (char*)param2
{
// definition = "(((text(code) || ' ') || upper(abbreviation)) || ' ')";
  EOExpressionArray *expressionArray = nil;
  const char *s = NULL;
  const char *start = NULL;
  id objectToken = nil;
  id pool = nil;

  EOFLOGObjectFnStart();

  EOFLOGObjectLevelArgs(@"EOEntity", @"expression=%@", description);

  expressionArray = [[EOExpressionArray new] autorelease];
  s = [description cString];

  if (s)
    {
      pool = [NSAutoreleasePool new];
      NS_DURING
        {
          /* Divide the expression string in alternating substrings that obey the
             following simple grammar: 
             
             I = [a-zA-Z0-9@_#]([a-zA-Z0-9@_.#$])+
             O = \'.*\' | \".*\" | [^a-zA-Z0-9@_#]+
             S -> I S | O S | nothing
          */
          while (s && *s) 
            {
              /* Determines an I token. */
              if (isalnum(*s) || *s == '@' || *s == '_' || *s == '#') 
                {
                  EOExpressionArray *expr = nil;

                  start = s;

                  for (++s; *s; s++)
                    if (!isalnum(*s) && *s != '@' && *s != '_'
			&& *s != '.' && *s != '#' && *s != '$')
                      break;
              
                  objectToken = [NSString stringWithCString:start
                                          length: (unsigned)(s - start)];
              
                  expr = [self _parsePropertyName: objectToken];

                  if (expr)
                    objectToken = expr;

                  EOFLOGObjectLevelArgs(@"EOEntity", @"addObject:%@",
					objectToken);

                  [expressionArray addObject: objectToken];
                }
          
              /* Determines an O token. */
              start = s;
              for (; *s && !isalnum(*s) && *s != '@' && *s != '_' && *s != '#';
		  s++)
                {
                  if (*s == '\'' || *s == '"') 
                    {
                      char quote = *s;
                  
                      for (++s; *s; s++)
                        if (*s == quote)
                          break;
                        else if (*s == '\\')
                          s++; /* Skip the escaped characters */

                      if (!*s)
                        [NSException raise: NSInvalidArgumentException
                                     format: @"%@ -- %@ 0x%x: unterminated character string",
                                     NSStringFromSelector(_cmd),
                                     NSStringFromClass([self class]),
                                     self];
                    }
                }

              if (s != start)
                {
                  objectToken = [NSString stringWithCString: start
                                          length: (unsigned)(s - start)];

                  EOFLOGObjectLevelArgs(@"EOEntity", @"addObject:%@",
					objectToken);

                  [expressionArray addObject: objectToken];
                }
            }
        }
      NS_HANDLER
        {
          [localException retain];
          NSLog(@"exception in EOEntity _parseDescription:isFormat:arguments:");
          NSLog(@"exception=%@", localException);

          [pool release];//Release the pool !
          [localException autorelease];
          [localException raise];
        }
      NS_ENDHANDLER;
      [pool release];
    }

  // return nil if expressionArray is empty
  if ([expressionArray count] == 0)
    expressionArray = nil;
  // if expressionArray contains only one element and this element is a expressionArray, use it (otherwise, isFlatten will not be accurate)
  else if ([expressionArray count] == 1)
    {
      id expr = [expressionArray lastObject];

      if ([expr isKindOfClass: [EOExpressionArray class]])
        expressionArray = expr;
    }

  EOFLOGObjectLevelArgs(@"EOEntity",
			@"expressionArray=%@\nexpressionArray count=%d isFlattened=%s\n",
			expressionArray,
			[expressionArray count],
			([expressionArray isFlattened] ? "YES" : "NO"));

  return expressionArray;
}

- (EOExpressionArray*) _parseRelationshipPath: (NSString*)path
{
  //Near OK quotationPlace.quotationPlaceLabels
  EOEntity *entity = self;
  EOExpressionArray *expressionArray = nil;
  NSArray *components = nil;
  int i, count = 0;

  EOFLOGObjectFnStart();

  EOFLOGObjectLevelArgs(@"EOEntity",@"self=%p (name=%@) path=%@",
               self,[self name],path);

  NSAssert1([path length] > 0, @"Path is empty (%p)", path);

  expressionArray = [EOExpressionArray expressionArrayWithPrefix: nil
				       infix: @"."
				       suffix: nil];

  EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p expressionArray=%@",
			self, expressionArray);

  components = [path componentsSeparatedByString: @"."];
  count = [components count];

  for (i = 0; i < count; i++)
    {
      NSString *part = [components objectAtIndex: i];
      EORelationship *relationship;

      NSAssert1([part length] > 0, @"part is empty (path=%@)", path);
      relationship = [entity anyRelationshipNamed: part];

      EOFLOGObjectLevelArgs(@"EOEntity", @"part=%@ relationship=%@",
			    part, relationship);

      if (relationship)
        {
          NSAssert2([relationship isKindOfClass: [EORelationship class]],
                    @"relationship is not a EORelationship but a %@. relationship:\n%@",
                    [relationship class],
                    relationship);

          if ([relationship isFlattened])
            {
              EOExpressionArray *definitionArray=[relationship _definitionArray];

              NSDebugMLog(@"entityName=%@ path=%@",[self name],path);
              NSDebugMLog(@"relationship=%@",relationship);
              NSDebugMLog(@"relationship definitionArray=%@",definitionArray);

              // For flattened relationships, we add relationship definition array
              [expressionArray addObjectsFromArray:definitionArray];

              // Use last relationship  to find destinationEntity,...
              relationship=[expressionArray lastObject];
            }
          else
            {
              [expressionArray addObject: relationship];
            }

          entity = [relationship destinationEntity];
        }
      else
        {
          NSDebugMLog(@"self %p name=%@: relationship \"%@\" used in \"%@\" doesn't exist in entity %@",
		      self,
                      [self name],
                      path,
                      part,
                      entity);

          //EOF don't throw exception. But we do !
          [NSException raise: NSInvalidArgumentException
                       format: @"%@ -- %@ 0x%x: relationship \"%@\" used in \"%@\" doesn't exist in entity %@",
                       NSStringFromSelector(_cmd),
                       NSStringFromClass([self class]),
                       self,
                       path,
                       part,
                       entity];
        }
    }
  EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p expressionArray=%@",
			self, expressionArray);

  // return nil if expressionArray is empty
  if ([expressionArray count] == 0)
    expressionArray = nil;
  // if expressionArray contains only one element and this element is a expressionArray, use it (otherwise, isFlatten will not be accurate)
  else if ([expressionArray count] == 1)
    {
      id expr = [expressionArray lastObject];

      if ([expr isKindOfClass: [EOExpressionArray class]])
        expressionArray = expr;
    }

  EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p expressionArray=%@",
			self, expressionArray);

  EOFLOGObjectFnStop();

  return expressionArray;
}

- (id) _parsePropertyName: (NSString*)propertyName
{
  EOEntity *entity = self;
  EOExpressionArray *expressionArray = nil;
  NSArray *components = nil;
  int i, count = 0;

  EOFLOGObjectFnStart();

  EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p self name=%@ propertyName=%@",
			self, [self name], propertyName);

  expressionArray = [EOExpressionArray expressionArrayWithPrefix: nil
				       infix: @"."
				       suffix: nil];

  EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p expressionArray=%@",
			self, expressionArray);

  components = [propertyName componentsSeparatedByString: @"."];
  count = [components count];

  for (i = 0; i < count; i++)
    {
      NSString *part = [components objectAtIndex: i];
      EORelationship *relationship = [entity anyRelationshipNamed: part];

      EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p entity name=%@ part=%@ relationship=%@ relationship name=%@",
			    self, [entity name], part, relationship,
			    [relationship name]);

      if (relationship)
        {
          NSAssert2([relationship isKindOfClass: [EORelationship class]],
                    @"relationship is not a EORelationship but a %@. relationship:\n%@",
                    [relationship class],
                    relationship);

          if ([relationship isFlattened])
            {
              NSEmitTODO();  //TODO
              [self notImplemented: _cmd];//TODO
            }
          else
            {
              EOFLOGObjectLevelArgs(@"EOEntity",@"self=%p expressionArray addObject=%@ (name=%@)",
				    self, relationship, [relationship name]);

              [expressionArray addObject: relationship];
            }

          entity = [relationship destinationEntity];
        }
      else
        {
          EOAttribute *attribute = [entity anyAttributeNamed: part];

          EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p entity name=%@ part=%@ attribute=%@ attribute name=%@",
				self, [entity name], part, attribute,
				[attribute name]);

          if (attribute)
            [expressionArray addObject: attribute];
          else if (i < (count - 1))
            {
              //EOF don't throw exception ? But we do !
              [NSException raise: NSInvalidArgumentException
                           format: @"%@ -- %@ 0x%x: attribute \"%@\" used in \"%@\" doesn't exist in entity %@",
                           NSStringFromSelector(_cmd),
                           NSStringFromClass([self class]),
                           self,
                           propertyName,
                           part,
                           entity];
            }
        }
    }

  EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p expressionArray=%@",
			self, expressionArray);
  // return nil if expression is empty

  if ([expressionArray count] == 0)
    expressionArray = nil;
  else if ([expressionArray count] == 1)
    expressionArray = [expressionArray objectAtIndex: 0];

  EOFLOGObjectLevelArgs(@"EOEntity", @"self=%p expressionArray=\"%@\"",
			self, expressionArray);

  EOFLOGObjectFnStop();

  return expressionArray;
}

@end

@implementation EOEntityClassDescription

+ (EOEntityClassDescription*)entityClassDescriptionWithEntity: (EOEntity *)entity
{
  return [[[self alloc] initWithEntity: entity] autorelease];
}

- (id)initWithEntity: (EOEntity *)entity
{
  if ((self = [super init]))
    {
      ASSIGN(_entity, entity);
    }

  return self;
}

- (void) dealloc
{
  //OK
  EOFLOGObjectLevelArgs(@"EOEntity", @"Deallocate EOEntityClassDescription %p",
			self);

  fflush(stdout);
  fflush(stderr);

  DESTROY(_entity);

  [super dealloc];
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"<%s %p - Entity: %@>",
                   object_get_class_name(self),
                   self,
                   [self entityName]];
}

- (EOEntity *)entity
{
  return _entity;
}

- (NSString *)entityName
{
  return [_entity name];
}

- (NSArray *)attributeKeys
{
  //OK
  return [_entity classPropertyAttributeNames];
}

- (void)awakeObject: (id)object
fromFetchInEditingContext: (EOEditingContext *)context
{
  //OK
  [super awakeObject: object
	 fromFetchInEditingContext: context];
  //nothing to do
}

- (void)awakeObject: (id)object
fromInsertionInEditingContext: (EOEditingContext *)anEditingContext
{
  //near OK
  [super awakeObject: object
         fromInsertionInEditingContext: anEditingContext];
  {
    NSArray *relationships = [_entity relationships];
    NSArray *classProperties = [_entity classProperties];//TODO use it !
    int i, count = [relationships count];

    for (i = 0; i < count; i++)
      {
        EORelationship *relationship = [relationships objectAtIndex: i];
        BOOL isToMany = [relationship isToMany];

        if (isToMany)
          {
            //Put an empty muable array [Ref: Assigns empty arrays to to-many relationship properties of newly inserted enterprise objects]
            [object takeStoredValue: [EOCheapCopyMutableArray array]
		    forKey: [relationship name]];
          }
        else //??
          {
            BOOL propagatesPrimaryKey = [relationship propagatesPrimaryKey];

            if (propagatesPrimaryKey)
              {
                int classPropIndex = [classProperties
				       indexOfObjectIdenticalTo: relationship];

                if (classPropIndex == NSNotFound)
                  {
		    NSEmitTODO(); //TODO
                    [self notImplemented: _cmd]; //TODO gid
                  }
                else
                  {
                    NSString *relationshipName = [relationship name];
                    id relationshipValue = [object valueForKey:
						     relationshipName];//nil

                    if (relationshipValue)
                      {
                        //Do nothing ??
			NSEmitTODO();  //TODO
                        [self notImplemented: _cmd];//TODO??
                      }
                    else
                      {
                        EOEntity *relationshipDestinationEntity =
			  [relationship destinationEntity];
                        EOClassDescription *classDescription =
			  [relationshipDestinationEntity
			    classDescriptionForInstances];

                        relationshipValue = [classDescription
					      createInstanceWithEditingContext:
						anEditingContext
					      globalID: nil
					      zone: NULL];

                        [object addObject: relationshipValue
                                toBothSidesOfRelationshipWithKey:
				  relationshipName];

                        [anEditingContext insertObject: relationshipValue];
                        /*
                          //Mirko code 
                          EOEntity *entityTo;
                    
                          objectTo = [object storedValueForKey:[relationship name]];
                          entityTo = [relationship destinationEntity];
                    
                          if ([relationship isMandatory] == YES && objectTo == nil)
                          {
                          EODatabaseOperation *opTo;
                          EOGlobalID *gidTo;
                    
                          objectTo = [[entityTo classDescriptionForInstances]
                          createInstanceWithEditingContext:context
                          globalID:nil
                          zone:NULL];
                    
                          gidTo = [entityTo globalIDForRow:newPK];
                    
                          opTo = [self _dbOperationWithGlobalID:gidTo
                          object:objectTo
                          entity:entityTo
                          operator:EODatabaseInsertOperator];
                          }
                    
                          if (objectTo && [entityTo
                          isPrimaryKeyValidInObject:objectTo] == NO)
                          {
                          pk = [[[entityTo primaryKeyAttributeNames] mutableCopy]
                          autorelease];
                          [pk removeObjectsInArray:[entityTo classPropertyNames]];
                    
                          pkObj = [[newPK mutableCopy] autorelease];
                          [pkObj removeObjectsForKeys:pk];
                    
                          [objectTo takeStoredValuesFromDictionary:pkObj];
                          }
                        */
                      }
                  }
              }
          }
      }
  }
}

- (EOClassDescription *)classDescriptionForDestinationKey: (NSString *)detailKey
{
  EOClassDescription *cd = nil;
  EOEntity *destEntity = nil;
  EORelationship *rel = nil;

  EOFLOGObjectFnStart();

  EOFLOGObjectLevelArgs(@"EOEntity", @"detailKey=%@", detailKey);
  EOFLOGObjectLevelArgs(@"EOEntity", @"_entity name=%@", [_entity name]);

  rel = [_entity relationshipNamed: detailKey];
  EOFLOGObjectLevelArgs(@"EOEntity", @"rel=%@", rel);

  destEntity = [rel destinationEntity];
  EOFLOGObjectLevelArgs(@"EOEntity", @"destEntity name=%@", [destEntity name]);

  cd = [destEntity classDescriptionForInstances];
  EOFLOGObjectLevelArgs(@"EOEntity", @"cd=%@", cd);

  EOFLOGObjectFnStop();

  return cd;
}

- (id)createInstanceWithEditingContext: (EOEditingContext *)editingContext
                              globalID: (EOGlobalID *)globalID
                                  zone: (NSZone *)zone
{
  id obj = nil;
  Class objectClass;

  EOFLOGObjectFnStart();

  NSAssert1(_entity, @"No _entity in %@", self);

  objectClass = [_entity classForObjectWithGlobalID: (EOKeyGlobalID*)globalID];
  EOFLOGObjectLevelArgs(@"EOEntity", @"objectClass=%p", objectClass);

  NSAssert2(objectClass, @"No objectClass for globalID=%@. EntityName=%@",
	    globalID, [_entity name]);

  if (objectClass)
    {
      EOFLOGObjectLevelArgs(@"EOEntity", @"objectClass=%@", objectClass);

      obj = [[objectClass allocWithZone:zone]
	      initWithEditingContext: editingContext
	      classDescription: self
	      globalID: globalID];
    }

  [obj autorelease];

  EOFLOGObjectFnStop();

  return obj;
}

- (NSFormatter *)defaultFormatterForKey: (NSString *)key
{
  [self notImplemented: _cmd];
  return nil;
}

- (NSFormatter *)defaultFormatterForKeyPath: (NSString *)keyPath
{
  [self notImplemented: _cmd];
  return nil; //TODO
}

- (EODeleteRule)deleteRuleForRelationshipKey: (NSString *)relationshipKey
{
  EORelationship *rel = nil;
  EODeleteRule deleteRule = 0;

  EOFLOGObjectFnStart();

  rel = [_entity relationshipNamed: relationshipKey];
  EOFLOGObjectLevelArgs(@"EOEntity", @"relationship %p=%@", rel, rel);

  deleteRule = [rel deleteRule];
  EOFLOGObjectLevelArgs(@"EOEntity", @"deleteRule=%d", (int)deleteRule);

  EOFLOGObjectFnStop();

  return deleteRule;
}

- (NSString *)inverseForRelationshipKey: (NSString *)relationshipKey
{
  //Near OK
  NSString *inverseName = nil;
  EORelationship *relationship = [_entity relationshipNamed: relationshipKey];
  NSArray *classProperties = [_entity classProperties];
  EOEntity *parentEntity = [_entity parentEntity];
  //TODO what if parentEntity
  EORelationship *inverseRelationship = [relationship inverseRelationship];

  if (inverseRelationship)
    {
      /*      EOEntity *inverseRelationshipEntity =
	[inverseRelationship entity];
      NSArray *inverseRelationshipClassProperties =
      [inverseRelationshipEntity classProperties];*/

      inverseName = [inverseRelationship name];
    }

  return inverseName;
}

- (BOOL)ownsDestinationObjectsForRelationshipKey: (NSString*)relationshipKey
{
  //OK
  return [[_entity relationshipNamed: relationshipKey] ownsDestination];
}

- (NSArray *)toManyRelationshipKeys
{
  //OK
  return [_entity classPropertyToManyRelationshipNames];
}

- (NSArray *)toOneRelationshipKeys
{
  //OK
  return [_entity classPropertyToOneRelationshipNames];
}

- (EORelationship *)relationshipNamed: (NSString *)relationshipName
{
  //OK
  return [_entity relationshipNamed:relationshipName];
}

- (EORelationship *)anyRelationshipNamed: (NSString *)relationshipName
{
  return [_entity anyRelationshipNamed:relationshipName];  
}

- (NSException *) validateObjectForDelete: (id)object
{
  return [_entity validateObjectForDelete:object];
}

- (NSException *)validateObjectForSave: (id)object
{
  return nil; //Does Nothing ? works is done in record
}

- (NSException *)validateValue: (id *)valueP
                        forKey: (NSString *)key
{
  NSException *exception = nil;
  EOAttribute *attr;
  EORelationship *relationship;

  NSAssert(valueP, @"No value pointer");

  attr = [_entity attributeNamed: key];

  if (attr)
    {
      exception = [attr validateValue: valueP];
    }
  else
    {
      relationship = [_entity relationshipNamed: key];

      if (relationship)
        {
          exception = [relationship validateValue: valueP];
        }
      else
        {
          NSEmitTODO();  //TODO
        }
    }

  return exception;
}

@end