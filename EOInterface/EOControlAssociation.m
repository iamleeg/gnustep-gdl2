/**
   EOControlAssociation.m

   Copyright (C) 2004,2005 Free Software Foundation, Inc.

   Author: David Ayers <ayers@fsfe.org>

   This file is part of the GNUstep Database Library

   The GNUstep Database Library is free software; you can redistribute it 
   and/or modify it under the terms of the GNU Lesser General Public License 
   as published by the Free Software Foundation; either version 3, 
   or (at your option) any later version.

   The GNUstep Database Library is distributed in the hope that it will be 
   useful, but WITHOUT ANY WARRANTY; without even the implied warranty of 
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public License 
   along with the GNUstep Database Library; see the file COPYING. If not, 
   write to the Free Software Foundation, Inc., 
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA. 
*/

#ifdef GNUSTEP
#include <Foundation/NSString.h>

#include <AppKit/NSControl.h>
#else
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#endif

#include "EOControlAssociation.h"
#include "EODisplayGroup.h"
#include "SubclassFlags.h"
#include <Foundation/NSRunLoop.h>

@implementation EOControlAssociation : EOGenericControlAssociation

+ (BOOL)isUsableWithObject: (id)object
{
  return [object isKindOfClass: [NSControl class]];
}

+ (NSString *)displayName
{
  return @"EOControlAssoc";
}

- (void) establishConnection 
{
  [super establishConnection];
}

- (void) breakConnection
{
  [super breakConnection];
}

- (NSControl *)control
{
  return [self object];
}

- (EOGenericControlAssociation *)editingAssociation
{
  return self;
}

@end
