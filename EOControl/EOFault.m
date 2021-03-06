/** 
   EOFault.m <title>EOFault Class</title>

   Copyright (C) 1996-2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Date: 1996

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Date: June 2000

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
#include <Foundation/NSObject.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef GNUSTEP
#include <GNUstepBase/GNUstep.h>
#include <GNUstepBase/GSObjCRuntime.h>
#include <GNUstepBase/NSDebug+GNUstepBase.h>
#endif

#include <objc/Protocol.h>

#include <EOControl/EOFault.h>
#include <EOControl/EOKeyGlobalID.h>
#include <EOControl/EOEditingContext.h>
#include <EOControl/EODebug.h>

#include <limits.h>

/*
 * EOFault class
 */

@implementation EOFault

static Class EOFaultClass = NULL;

+ (void)initialize
{
  if (EOFaultClass == NULL)
    {
      EOFaultClass = [EOFault class];
    }
}

+ (Class)superclass
{
  return GSObjCSuper(self);
}

+ (Class)class
{
  return self;
}

+ self
{
  return self;
}

+ (id)retain
{
  return self;
}

+ (void)release
{
  return;
}

+ (id)autorelease
{
  return self;
}

+ (NSUInteger)retainCount
{
  return UINT_MAX;
}

+ (BOOL)isKindOfClass: (Class)aClass
{
  if (aClass == EOFaultClass)
    return YES;

  return NO;
}

+ (void)doesNotRecognizeSelector: (SEL)selector
{
  [NSException raise: NSInvalidArgumentException
	       format: @"%@ -- %@ 0x%x: selector \"%@\" not recognized",
	       NSStringFromSelector(_cmd),
	       NSStringFromClass([self class]),
	       self,
	       NSStringFromSelector(selector)];
}

+ (BOOL)respondsToSelector: (SEL)selector
{
  return (GSGetMethod(self, selector, NO, YES) != (GSMethod)0);
}

/**
 * Returns a pointer to the C function implementing the method used
 * to respond to messages with selector by instances of the receiving
 * class.
 * <br />Raises NSInvalidArgumentException if given a null selector.
 *
 * It's a temporary fix to support NSAutoreleasePool optimization
 */
+ (IMP) instanceMethodForSelector: (SEL)selector
{
  if (selector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];
  /*
   *	Since 'self' is an class, get_imp() will get the instance method.
   */
  return class_getMethodImplementation((Class)self, selector);
}

// Fault class methods

+ (void)makeObjectIntoFault: (id)object
                withHandler: (EOFaultHandler *)handler
{
  if (object)
    {
      EOFault *fault = object;
      NSUInteger refs;

      NSAssert(handler, @"No Handler");

      refs = [object retainCount];
      
      [handler setTargetClass: [object class]
               extraData: fault->_handler];
      fault->isa = self;
      fault->_handler = [handler retain];
      
      while (refs-- > 0)
        [fault retain];
    }
}

+ (BOOL)isFault: (id)object
{
  //See also EOPrivat.h
//  NSDebugFLLog(@"gsdb",@"object=%p",object);

  if (object == nil)
    return NO;
  else
    return ((EOFault *)object)->isa == self;
}

+ (void)clearFault: (id)fault
{
  EOFaultHandler * handler;
  EOFault        * aFault = (EOFault *)fault;
  NSUInteger       refs = 0;
    
  if ([EOFaultClass isFault:fault] == NO)
  {
    [NSException raise:NSInvalidArgumentException
                format:@"%s -- object %@ of class %@ is not a fault object", 
     __PRETTY_FUNCTION__, 
     fault,
     [fault class]];
  } else {
    handler = aFault->_handler;
    
    [handler faultWillFire: fault];
    
    // this will transfer our fault instance into an EO
    aFault->isa = [handler targetClass];
    aFault->_handler = [handler extraData];
    
    // get the extra references to add them later to the EO
    refs = [handler extraRefCount];
    
    [handler autorelease];
    
    // add up extra references to the EO
    while (refs-- > 0) {        
      [aFault retain];
    }
  }
  
}

+ (EOFaultHandler *)handlerForFault:(id)fault
{
  BOOL isFault = [EOFaultClass isFault: fault];

  NSDebugFLLog(@"gsdb", @"object %p is%s a fault", fault,
	       (isFault ? "" : " not"));

  if (isFault)
    return ((EOFault *)fault)->_handler;
  else
    return nil;
}

+ (Class)targetClassForFault: (id)fault
{
  if ([EOFaultClass isFault:fault])
    return [((EOFault *)fault)->_handler targetClass];
  else
    return nil;
}


// Fault Instance methods

- (Class) superclass
{
  return [[_handler targetClass] superclass];
}

- (Class)class
{
  return [_handler targetClass];
}

- (BOOL)isKindOfClass: (Class)aClass
{
  Class class;
  BOOL koc=NO;

  class = [_handler targetClass];

  for (; !koc && class != Nil; class = GSObjCSuper(class))
    if (class == aClass)
      koc = YES;

  return koc;
}

- (BOOL)isMemberOfClass: (Class)aClass
{
  return [_handler targetClass] == aClass;
}

- (BOOL)conformsToProtocol: (Protocol *)protocol
{
  return class_conformsToProtocol([_handler targetClass], protocol);
}

- (BOOL)respondsToSelector: (SEL)selector
{
  return class_respondsToSelector([_handler targetClass], selector);
}

- (NSMethodSignature *)methodSignatureForSelector: (SEL)selector
{
  NSMethodSignature *sig;

  NSDebugFLLog(@"gsdb", @"START self=%p", self);
  NSDebugFLLog(@"gsdb", @"_handler=%p", _handler);

  sig = [_handler methodSignatureForSelector: selector
		  forFault: self];

  NSDebugFLLog(@"gsdb", @"STOP self=%p", self);

  return sig;
}

- retain
{
  [_handler incrementExtraRefCount];

  return self;
}

- (void)release
{
  if ([_handler decrementExtraRefCountIsZero]) 
  {
    [self dealloc];
  }
}

- autorelease
{
  [NSAutoreleasePool addObject: self];

  return self;
}

- (NSUInteger)retainCount
{
  return [_handler extraRefCount];
}

- (NSString *)description
{
  return [_handler descriptionForObject: self];
}

- (NSString *)descriptionWithIndent: (NSUInteger)level
{
  return [self description];
}

- (NSString *)descriptionWithLocale: (NSDictionary *)locale
{
  //OK
  return [self description];
}

- (NSString *)descriptionWithLocale: (NSDictionary *)locale
                             indent: (NSUInteger)level
{
  return [self description];
}

- (NSString *)eoDescription
{
  return [self description];
}

- (NSString *)eoShallowDescription
{
  return [self description];
}

- (EOKeyGlobalID *)globalID
{
  if ([_handler respondsToSelector: @selector(globalID)])
    return [(id)_handler globalID];
  else
    {
      [_handler completeInitializationOfObject: self];
      return [self globalID];
    }
}

- (EOEditingContext *)editingContext
{
  return [_handler editingContext];
}

/*
- (EOKeyGlobalID *)sourceGlobalID;
- (NSString *)relationshipName;
*/

- (void)dealloc
{
  [EOFaultClass clearFault: self];
  
  NSAssert([EOFaultClass isFault:self]==NO, @"Object is a Fault not an EO");
  [self dealloc];
}

- (NSZone *)zone
{
  return NSZoneFromPointer(self);
}

- (BOOL)isProxy
{
  return NO;
}

- (id)self
{
  [_handler completeInitializationOfObject: self];

  return self;
}

- (void)doesNotRecognizeSelector: (SEL)selector
{
  [NSException raise: NSInvalidArgumentException
               format: @"%@ -- %@ 0x%x: selector \"%@\" not recognized",
               NSStringFromSelector(_cmd),
               NSStringFromClass([self class]),
               self,
               NSStringFromSelector(selector)];
}

- (void)forwardInvocation: (NSInvocation *)invocation
{
  NSDebugFLLog(@"gsdb",@"invocation selector=%@ target: %p",
               NSStringFromSelector([invocation selector]),
               [invocation target]);

  if ([_handler shouldPerformInvocation: invocation])
    [_handler completeInitializationOfObject: self];

  [invocation invoke];
}

- (NSUInteger)hash
{
  NSUInteger hash;
  EOFaultHandler *handler;
  Class fault;

  fault = isa;
  handler = _handler;

  isa = [handler targetClass];
  _handler = [handler extraData];

  hash = [self hash];

  isa = fault;
  _handler = handler;

  return hash;
}

@end
