/**
  EOModelerDocument.m <title>EOModelerDocument Class</title>
  
  Copyright (C) 2005 Free Software Foundation, Inc.
 
  Author: Matt Rice <ratmice@gmail.com>
  Date: April 2005
  
  This file is part of the GNUstep Database Library.
  
  <license>
  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 3 of the License, or (at your option) any later version.
 
  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.
 
  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
  </license>
**/

#include "EOModeler/EODefines.h"
#include "EOModeler/EOModelerDocument.h"
#include "EOModeler/EOModelerEditor.h"
#include "EOModeler/EOModelerApp.h"

#ifdef NeXT_GUI_LIBRARY
#include <AppKit/AppKit.h>
#else
#include <AppKit/NSMenuItem.h>
#include <AppKit/NSOpenPanel.h>
#endif

#include <EOInterface/EODisplayGroup.h>

#include <EOAccess/EOAdaptor.h>
#include <EOAccess/EOAttribute.h>
#include <EOAccess/EOEntity.h>
#include <EOAccess/EOModel.h>
#include <EOAccess/EOModelGroup.h>
#include <EOAccess/EORelationship.h>

#include <EOControl/EOEditingContext.h>

#ifdef NeXT_Foundation_LIBRARY
#include <Foundation/Foundation.h>
#else
#include <Foundation/NSAttributedString.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSUndoManager.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSValue.h>
#endif

#include <GNUstepBase/GNUstep.h>

@interface ConsistencyResults : NSObject 
+ (id) sharedConsistencyPanel;
- (int) showConsistencyCheckResults:(id)sender cancelButton:(BOOL)useCancel
showOnSuccess:(BOOL)flag;
@end

static Class      _defaultEditorClass;
static EOModelerEditor *_currentEditorForDocument;

/* FIXME we cross the library->application boundry whenever working
 * with the ConsistencyResults class which is declared in DBModeler
 * theres a few ways this is crossed:
 *
 * enabling/disabling the cancel button
 * appending text
 * avoiding running the panel if all checks pass.
 *
 * this could possibly be done with private methods in this class
 * called from the receiver of an EOMCheckConsistencyEndNotification 
 * on the notification -object (or something).
 */

/** Notification sent when beginning consistency checks.
  * The notifications object is the EOModelerDocument.
  * The receiver should call -appendConsistencyCheckErrorText:
  * on the notifications object for any consistency check failures */
NSString *EOMCheckConsistencyBeginNotification =
	@"EOMCheckConsistencyBeginNotification";

/** Notification sent when ending consistency checks.
  * The notifications object is the EOModelerDocument.
  * The receiver should call -appendConsistencyCheckSuccessText:
  * on the notifications object for any consistency checks that passed. */
NSString *EOMCheckConsistencyEndNotification =
	@"EOMCheckConsistencyEndNotification";

/** Notification sent when beginning EOModel consistency checks.
  * The notifications object is the EOModelerDocument.
  * The receiver should call -appendConsistencyCheckErrorText: 
  * on the notifications object for any consistency check failures
  * the userInfo dictionary contains an EOModel instance for the 
  * EOMConsistencyModelObjectKey key. */
NSString *EOMCheckConsistencyForModelNotification =
	@"EOMCheckConsistencyForModelNotification";
NSString *EOMConsistencyModelObjectKey = @"EOMConsistencyModelObjectKey";

@interface EOModelerApp (PrivateStuff)
- (void) _setActiveDocument:(EOModelerDocument *)newDocument;
@end

@interface NSArray (EOMAdditions)
- (id) firstSelectionOfClass:(Class)aClass;
@end
@implementation NSArray (EOMAdditions)
- (id) firstSelectionOfClass:(Class)aClass
{
  unsigned i, c;
  id obj = nil;
  for (i = 0, c = [self count]; i < c; i++)
    {
      obj = [self objectAtIndex:i];
      if ([obj isKindOfClass:aClass])
        {
          break;
        }

      if ([obj isKindOfClass:[NSArray class]])
        {
          int j, d;
          for (j = 0, d = [obj count]; j < d; j++)
            {
              id obj2 = [obj objectAtIndex:j];

              if ([obj2 isKindOfClass:aClass])
                {
                  obj = obj2;
                  break;
                }
            }
        }
    }

  if (![obj isKindOfClass:aClass])
    {
      return nil;
    }
  
  return obj;
}
@end

@implementation EOModelerDocument 



- (BOOL) validateMenuItem:(NSMenuItem <NSMenuItem>*)menuItem
{
  NSArray *selection = [[EOMApp currentEditor] selectionPath];

  
    
  if ([[menuItem title] isEqualToString:@"Add attribute"])
    return ([selection firstSelectionOfClass:[EOEntity class]] != nil);
  else if ([[menuItem title] isEqualToString:@"Add relationship"])
    return ([selection firstSelectionOfClass:[EOEntity class]] != nil);
  else if ([[menuItem title] isEqual:@"delete"])
    return ([[selection lastObject] count]) ? YES : NO;
    // see -delete:
    //return ([[selection lastObject] count] || [selection count] > 2) ? YES : NO;
  
  return YES;
}

- (id)initWithModel:(EOModel*)model
{
  if ((self = [super init]))
    {
      _model = RETAIN(model);
      [[EOModelGroup defaultGroup] addModel:model];
      _userInfo = nil;
      _editors = [[NSMutableArray alloc] init];
      _editingContext = [[EOEditingContext alloc] init];
      // why insert the model into the EC? -- dw
      //      [_editingContext insertObject:model];
    }
  return self;
}

- (void) dealloc
{
  [[_editingContext undoManager] removeAllActionsWithTarget:_editingContext];
  
  [[EOModelGroup defaultGroup] removeModel:_model];
  RELEASE(_model);
  RELEASE(_userInfo);
  RELEASE(_editors);
  RELEASE(_editingContext);
  [super dealloc];
}

- (EOAdaptor *)adaptor
{
  NS_DURING
    NS_VALUERETURN([EOAdaptor adaptorWithModel:_model], EOAdaptor *);
  NS_HANDLER
    return nil;
  NS_ENDHANDLER

  return nil;
}

- (EOModel *)model;
{
  return _model;
}

- (EOEditingContext *)editingContext
{
  return _editingContext;
}

- (BOOL) isDirty
{
  return NO; /* FIXME*/
}

- (BOOL) prepareToSave
{
  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DisableConsistencyCheckOnSave"] == NO)
    {
      NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

      [center postNotificationName:EOMCheckConsistencyBeginNotification
                        object:self];
      [center postNotificationName:EOMCheckConsistencyForModelNotification
  	                object:self
		      userInfo:[NSDictionary dictionaryWithObject:[self model]
		                          forKey:EOMConsistencyModelObjectKey]];
      [center postNotificationName:EOMCheckConsistencyEndNotification
		        object:self];

      if ([[NSClassFromString(@"ConsistencyResults") sharedConsistencyPanel]
		      showConsistencyCheckResults:self
                                     cancelButton:YES
                                    showOnSuccess:NO] == NSRunAbortedResponse)
	return NO;
    }

  return YES;
}

- (NSString *)documentPath
{
  return [[[EOMApp activeDocument] model] path];
}

- (BOOL)saveToPath:(NSString *)path
{
  NSString *ext = [path pathExtension];
  if (!([ext isEqual:@"eomodeld"] || [ext isEqual:@"eomodel"]))
    path = [path stringByAppendingPathExtension:@"eomodeld"];
  NS_DURING
    [_model writeToFile: path];
    NS_VALUERETURN(YES, BOOL);
  NS_HANDLER
       NSRunAlertPanel(@"Error",
		       @"Save failed: %@",
		       @"Ok",
		       NULL,
		       NULL,
		       [localException reason]);
    return NO;
  NS_ENDHANDLER

  return NO;
}

- (BOOL)checkCloseDocument
{
  /* FIXME */
  return NO;
}

- (void)activate
{
  [EOMApp _setActiveDocument: self];
  [[_editors objectAtIndex:0] activate];
}

/* Editors stuff */

- (NSArray *)editors
{
  return [NSArray arrayWithArray:_editors];
}

- (void)addEditor:(EOModelerEditor *)editor
{
  /* check if we already have an editor object? */
  [_editors addObject:editor];
}

- (void) closeEditor:(EOModelerEditor *)editor
{
  /* call checkCloseEditor */
}

- (BOOL)checkCloseEditor:(EOModelerEditor *)editor
{
  /* FIXME call consistency checker */
  return NO;
}

- (EOModelerEditor *) addDefaultEditor
{
  EOModelerEditor *defaultEditor;
  
  defaultEditor = [[_defaultEditorClass alloc] initWithDocument:self];
  [self addEditor: defaultEditor];
  _currentEditorForDocument = defaultEditor;
  RELEASE(defaultEditor);
  return defaultEditor;
}

- (void)addEntity:(id)sender
{
  unsigned entityNumber;
  EOEntity *newEntity = [[EOEntity alloc] init];
  NSArray *entities = [_model entities];
  unsigned i,c;
  
  if (![_editors containsObject:[EOMApp currentEditor]])
    {
      [[NSException exceptionWithName:NSInternalInconsistencyException
	      		       reason:@"current editor not in edited document"
			       userInfo:nil] raise]; 
      return; 
    }
  
  c = [entities count];
  entityNumber = c;

  /* look for the largest NNNN in entity named "EntityNNNN" 
   * or the total number of entities in this model whichever is greater.
   */
  for (i = 0; i < c; i++)
     {
       NSString *name = [[entities objectAtIndex:i] name];

       if ([name hasPrefix:@"Entity"])
	 {
	   NSRange range;
	   unsigned tmp;
	   
	   name = [name substringFromIndex:6];
           range = [name rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
	   if (!(range.location == NSNotFound) && !(range.length == 0))
	     continue;
	   range = [name rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]];
	   if (!(range.location == NSNotFound) && !(range.length == 0))
	     {
		tmp = [name intValue];
		entityNumber = (entityNumber < ++tmp) ? tmp : entityNumber;
	     }
	 }
     }
   
  [newEntity setName: entityNumber
	  	      ? [NSString stringWithFormat: @"Entity%i", entityNumber]
		      : @"Entity"];
  [newEntity setClassName:@"EOGenericRecord"];
  [_editingContext insertObject:newEntity];
  [_model addEntity:AUTORELEASE(newEntity)];

  /* FIXME -parentEditor  */
  [(EOModelerCompoundEditor *)[EOMApp currentEditor] setSelectionWithinViewedObject:[NSArray arrayWithObject:newEntity]];
}

- (void)addAttribute:(id)sender
{
  EOAttribute *attrb;
  EOModelerCompoundEditor *currEd;
  unsigned int attributeNumber;
  EOEntity *entityObject;
  NSArray *attributes;
  int i,c;

  /* FIXME -parentEditor  */
  currEd = (EOModelerCompoundEditor *)[EOMApp currentEditor];

  /* the currentEditor must be in this document */
  if (![_editors containsObject:currEd])
    {
      [[NSException exceptionWithName:NSInternalInconsistencyException
	      reason:@"current editor not in edited document"
	      userInfo:nil] raise]; 
      return; 
    }
 
  entityObject = [[currEd selectionPath] firstSelectionOfClass:[EOEntity class]];

  attributes = [entityObject attributes];
  c = [attributes count];
  attributeNumber = c;
  
  /* look for the largest NNNN in attribute named "AttributeNNNN" 
   * or the total number of attributes in this entity whichever is greater.
   */
  for (i = 0; i < c; i++)
     {
       NSString *name = [[attributes objectAtIndex:i] name];

       if ([name hasPrefix:@"Attribute"])
         {
           NSRange range;
           unsigned tmp;

           name = [name substringFromIndex:9];
           range = [name rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
           if (!(range.location == NSNotFound) && !(range.length == 0))
             continue;
           range = [name rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]];
           if (!(range.location == NSNotFound) && !(range.length == 0))
             {
                tmp = [name intValue];
                attributeNumber = (attributeNumber < ++tmp) ? tmp : attributeNumber;
             }
         }
     }

  attrb = [[EOAttribute alloc] init];   
  [attrb setName: attributeNumber
	  	  ? [NSString stringWithFormat: @"Attribute%i",
	  					attributeNumber]
		  : @"Attribute"]; 
  [entityObject addAttribute:attrb];
  [_editingContext insertObject:attrb];
  
  if ([[[EOMApp currentEditor] selectionWithinViewedObject] count]
      && [[[[EOMApp currentEditor] selectionWithinViewedObject] objectAtIndex:0] isKindOfClass:[EOEntity class]])
    [currEd viewSelectedObject];
  
  [currEd setSelectionWithinViewedObject:[NSArray arrayWithObject:attrb]];
  [currEd activateSelection];
}

- (void)addRelationship:(id)sender
{
  EORelationship *newRel;
  EOEntity *srcEntity;
  EOModelerCompoundEditor *currentEditor;
  NSArray *relationships;
  int relationshipNum, i, c;

  /* FIXME -parentEditor  */
  currentEditor = (EOModelerCompoundEditor *)[EOMApp currentEditor];
  if (![_editors containsObject:currentEditor])
    {
      [[NSException  exceptionWithName:NSInternalInconsistencyException
	      	reason:@"currentEditor not in edited document exception"
		userInfo:nil] raise];
      return;
    }
  
  srcEntity = [[currentEditor selectionPath]
	  		firstSelectionOfClass:[EOEntity class]];
  relationships = [srcEntity relationships];
  c = [relationships count];
  relationshipNum = c;

  /* look for the largest NNNN in relationships named "RelationshipNNNN" 
   * or the total number of relationships in this attribute whichever is greater
   */
  for (i = 0; i < c; i++)
     {
       NSString *name = [[relationships objectAtIndex:i] name];

       if ([name hasPrefix:@"Relationship"])
         {
           NSRange range;
           unsigned tmp;

           name = [name substringFromIndex:12];
           range = [name rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
           if (!(range.location == NSNotFound) && !(range.length == 0))
             continue;
           range = [name rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]];
           if (!(range.location == NSNotFound) && !(range.length == 0))
             {
                tmp = [name intValue];
                relationshipNum = (relationshipNum < ++tmp) ? tmp : relationshipNum;
             }
         }
     }

  newRel = [[EORelationship alloc] init];  
  [newRel setName: relationshipNum
	  	   ? [NSString stringWithFormat:@"Relationship%i", relationshipNum]
		   : @"Relationship"];
  [srcEntity addRelationship:newRel];
  [_editingContext insertObject:newRel];
  
  if ([[[EOMApp currentEditor] selectionWithinViewedObject] count]
      && [[[[EOMApp currentEditor] selectionWithinViewedObject] objectAtIndex:0] isKindOfClass:[EOEntity class]])
    [currentEditor viewSelectedObject];

  [currentEditor setSelectionWithinViewedObject:[NSArray arrayWithObject:newRel]];
  [currentEditor activateSelection];
}

- (void)delete:(id)sender
{
  NSArray *objects = [[EOMApp currentEditor] selectionWithinViewedObject];
  NSMutableArray *tmp = [NSMutableArray array];
  NSArray *vop = [[EOMApp currentEditor] viewedObjectPath];
  unsigned i,c = [objects count];

  if (c == 0)
    {
      /*
       * if there is no selection delete the viewed object.
       */
      /*
         this is commented out (until we have undo working?) to prevent
         accidental deletion of entities
	 see also -validateMenuItem:
      id object;
      
      objects = [NSMutableArray arrayWithArray:[[EOMApp currentEditor] viewedObjectPath]];
      object = [objects lastObject];

      if ([object isKindOfClass:[EOAttribute class]])
        {
          [[object entity] removeAttribute:object];
        }
      else if ([object isKindOfClass:[EOEntity class]])
        {
          [[object model] removeEntity:object];
        }
      else if ([object isKindOfClass:[EORelationship class]])
        {
          [[object entity] removeRelationship: object];
        }
      [(NSMutableArray *)objects removeObjectAtIndex:[objects count] - 1];
      [[EOMApp currentEditor] setViewedObjectPath: objects];
      */
    }
  else 
    {
      for (i = 0, c = [objects count]; i < c; i++)
        {
          id object = [objects objectAtIndex:i];
	  NSArray *refs;
	  if ([object isKindOfClass:[EOAttribute class]]
	      || [object isKindOfClass:[EORelationship class]])
	    refs = [[[object entity] model] referencesToProperty:object];
	  else if ([object isKindOfClass:[EOEntity class]])
	    refs = [[object model] referencesToProperty:object]; 

	  if ([refs count])
	    {
	      NSMutableString *str;
	      unsigned i,c;
	      str = [NSMutableString stringWithFormat:@"object(%@) is referenced by other properties\n", [object name]];
	      for (i = 0, c = [refs count]; i < c; i++)
		{
		  id prop = [refs objectAtIndex:i];
		  NSString *tmp;
		  tmp=[NSString stringWithFormat:@"%@ of type %@\n",
					[prop name],
					[prop class]];
		  [str appendString:tmp];
		}
		  
	      NSRunAlertPanel(@"unable to remove property", str, @"ok", nil, nil);
	      return;
	    }
          else if ([object isKindOfClass:[EOAttribute class]])
 	    {
		[[object entity] removeAttribute:object];
  	    }
          else if ([object isKindOfClass:[EOEntity class]])
 	    {
	      [[object model] removeEntity:object];
 	    }
          else if ([object isKindOfClass:[EORelationship class]])
	    {
	      [[object entity] removeRelationship: object];
 	    }
        }
      c = [vop count] - 1;
      for (i = 0; i < c; i++)
	{
	  [tmp addObject: [vop objectAtIndex:i]];
	}
      [tmp addObject:[NSArray arrayWithObject:[vop lastObject]]];
      
      [[EOMApp currentEditor] setSelectionPath: tmp];

      /* FIXME -parentEditor  */
      [(EOModelerCompoundEditor *)[EOMApp currentEditor] activateSelection];
    }
}

- (void)addFetchSpecification:(id)sender
{

}

- (void)addStoredProcedure:(id)sender
{

}

- (void)addArgument:(id)sender
{

}

- (BOOL)canFlattenSelectedAttribute;
{
  return NO;
  // no idea
}

- (void)flattenAttribute:(id)sender
{
  // likewise
}

- (void)save:(id)sender
{
  NSString *path;

  
  path = [_model path];
  
  if (!path)
    {
      [self saveAs:self];
    }
  else
    {
      if ([self prepareToSave] == NO)
        return;
      [self saveToPath:path];
    }
}

- (void)saveAs:(id)sender
{
  NSString *path; 
  id savePanel;
  int result;
  
  if ([self prepareToSave] == NO)
    return;

  savePanel = [NSSavePanel savePanel];
  result = [savePanel runModal];
  if (result == NSOKButton)
    {
      path = [savePanel filename];
      [self saveToPath: path];
    }
}

- (void)revertToSaved:(id)sender
{

}

-(void)close:(id)sender
{

}

- (void)undo:(id)sender
{

}

- (void)redo:(id)sender
{

}

/* consitency checking stuff */
- (void) appendConcistencyCheckErrorText: (NSAttributedString *)errorText
{

}
- (void) appendConcistencyCheckSuccessText: (NSAttributedString *)successText
{

}

+ (void)setDefaultEditorClass:(Class)editorClass
{
  _defaultEditorClass = editorClass;
}

+ (Class)defaultEditorClass
{
  return _defaultEditorClass;
}

- (void)setUserInfo:(NSDictionary*)dictionary
{
  ASSIGN(_userInfo,dictionary); //just a guess
}

- (NSDictionary *)userInfo
{
  return _userInfo;
}

- (void) windowDidBecomeKey:(NSNotification *)notif
{
  [self activate];
}

- (void) windowWillClose:(NSNotification *)notif
{
  if ([_editors containsObject:[EOMApp currentEditor]])
    {
      // Clear inspected object.
      [[EOMApp currentEditor] setSelectionPath:[NSArray array]];
      // No longer current editor
      [EOMApp setCurrentEditor:nil];
    }
  
  [EOMApp removeDocument:self];  
}

- (void) checkConsistency:(id)sender
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  
  [center postNotificationName:EOMCheckConsistencyBeginNotification
	  	object:self];
  [center postNotificationName:EOMCheckConsistencyForModelNotification
	  	object:self
		userInfo:[NSDictionary dictionaryWithObject:[self model]
	 				forKey:EOMConsistencyModelObjectKey]];
  [center postNotificationName:EOMCheckConsistencyEndNotification
	  	object:self];

  [[NSClassFromString(@"ConsistencyResults") sharedConsistencyPanel]
	   	  showConsistencyCheckResults:self 
	  			 cancelButton:NO
				showOnSuccess:YES];
}

- (void) appendConsistencyCheckErrorText:(NSAttributedString *)errorText
{
  [[NSClassFromString(@"ConsistencyResults") sharedConsistencyPanel]
	  appendConsistencyCheckErrorText:errorText];
}

- (void) appendConsistencyCheckSuccessText:(NSAttributedString *)successText
{
  [[NSClassFromString(@"ConsistencyResults") sharedConsistencyPanel]
	  appendConsistencyCheckSuccessText:successText];
}


@end

