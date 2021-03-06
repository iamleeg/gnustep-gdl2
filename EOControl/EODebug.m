/* EODebug.m - <title>debug</title>

   Copyright (C) 1999-2002,2003,2004,2005 Free Software Foundation, Inc.
   
   Written by:	Manuel Guesdon <mguesdon@orange-concept.com>
   Date: 		Jan 1999

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
#include <Foundation/NSThread.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSDebug.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef GNUSTEP
#include <GNUstepBase/GNUstep.h>
#include <GNUstepBase/NSDebug+GNUstepBase.h>
#endif

#import <Foundation/NSObjCRuntime.h>

#include <unistd.h>

#include <EOControl/EODebug.h>


#define USTART	NSAutoreleasePool* arp=[NSAutoreleasePool new];
#define USTOP	DESTROY(arp);


#ifdef DEBUG

void 
EOFLogC_(const char *file, int line, const char *string)
{
  int len = 0;

  if ([NSThread isMultiThreaded])
    {
      fprintf(stderr, "%s PID=(%d) ",
              [[[NSThread currentThread] description] cStringUsingEncoding:NSUTF8StringEncoding],
	      (int)getpid());
    }

  fprintf(stderr, "File %s: %d. ", file, line);
  fprintf(stderr, string, NULL);  // the NULL makes the compiler happy -- dw

  len = strlen(string);

  if (len <= 0 || string[len-1] != '\n')
    {
      fprintf(stderr, "\n");
    }

  fflush(stderr);
}

#endif

#ifdef DEBUG

static NSString *
objectDescription(id object)
{
  NSString *description = nil;

  if ([object respondsToSelector: @selector(description)])
    {
      NS_DURING
	description = [object description];
      NS_HANDLER
	description 
	  = [NSString stringWithFormat:@"[%s:%p]: description raised",
		      GSClassNameFromObject(object), object];
      NS_ENDHANDLER;
    }

  return description;
}

static NSString *
IVarInString(const char* _type, void* _value)
{
  if (_type && _value)
    {
      switch (*_type)
	{
	case _C_ID:
	  {
	    id *pvalue = (id*)_value;
	    return [NSString stringWithFormat:
			       @"object:%ld Class:%s Description:%@",
			     (long)(*pvalue),
			     [*pvalue class],
			     objectDescription(*pvalue)];
	  }
	  break;
	case _C_CLASS:
	  {
	    Class *pvalue = (Class*)_value;
	    return [NSString stringWithFormat: @"Class:%s",
			     class_getName(*pvalue)];
	  }
	  break;
	case _C_SEL:
	  {
	    SEL *pvalue = (SEL*)_value;
	    return [NSString stringWithFormat: @"SEL:%s",
			     sel_getName(*pvalue)];
	  }
	  break;
	case _C_CHR:
	  {
	    char *pvalue = (char*)_value;
	    return [NSString stringWithFormat: @"CHAR:%c",
			     *pvalue];
	  }
	  break;
	case _C_UCHR:
	  {
	    unsigned char *pvalue = (unsigned char*)_value;
	    return [NSString stringWithFormat: @"UCHAR:%d",
			     (int)*pvalue];
	  }
	  break;
	case _C_SHT:
	  {
	    short *pvalue = (short*)_value;
	    return [NSString stringWithFormat: @"SHORT:%d",
			     (int)*pvalue];
	  }
	  break;
	case _C_USHT:
	  {
	    unsigned short *pvalue = (unsigned short*)_value;
	    return [NSString stringWithFormat: @"USHORT:%d",
			     (int)*pvalue];
	  }
	  break;
	case _C_INT:
	  {
	    int *pvalue = (int*)_value;
	    return [NSString stringWithFormat: @"INT:%d",
			     *pvalue];
	  }
	  break;
	case _C_UINT:
	  {
	    unsigned int *pvalue = (unsigned int*)_value;
	    return [NSString stringWithFormat: @"UINT:%u",
			     *pvalue];
	  }
	  break;
	case _C_LNG:
	  {
	    long *pvalue = (long*)_value;
	    return [NSString stringWithFormat: @"LONG:%ld",
			     *pvalue];
	  }
	  break;
	case _C_ULNG:
	  {
	    unsigned long *pvalue = (unsigned long*)_value;
	    return [NSString stringWithFormat: @"ULONG:%lu",
			     *pvalue];
	  }
	  break;
	case _C_FLT:
	  {
	    float *pvalue = (float*)_value;
	    return [NSString stringWithFormat: @"FLOAT:%f",
			     (double)*pvalue];
	  }
	  break;
	case _C_DBL:
	  {
	    double *pvalue = (double*)_value;
	    return [NSString stringWithFormat: @"DOUBLE:%f",
			     *pvalue];
	  }
	  break;
	case _C_VOID:
	  {
	    void *pvalue = (void*)_value;
	    return [NSString stringWithFormat: @"VOID:*%lX",
			     (unsigned long)pvalue];
	  }
	  break;
	case _C_CHARPTR:
	  {
	    char *pvalue = (void*)_value;
	    return [NSString stringWithFormat: @"CHAR*:%s",
			     pvalue];
	  }
	  break;
	case _C_PTR:
	  {
	    return [NSString stringWithFormat: @"PTR"];
	  }
	  break;
	case _C_STRUCT_B:
	  {
	    return [NSString stringWithFormat: @"STRUCT"];
	  }
	  break;
	default:
	  return [NSString stringWithFormat: @"Unknown"];
	}
    }
  else
    return @"NULL type or NULL pValue";
}

static NSString *
TypeToNSString(const char* _type)
{
  if (_type)
    {
      switch (*_type)
	{
	case _C_ID:
	  { // '@'
	    const char *t = _type + 1;

	    if (*t == '"')
	      {
		const char *start = t + 1;

		do
		  {
		    t++;
		  }
		while ((*t != '"') && (*t != '\0'));

		return [[NSString stringWithCString: start
				  length: (t - start)]
			 stringByAppendingString: @" *"];
	      }
	    else
	      return @"id";
	  };
	  break;
	case _C_CLASS:    return @"Class";
	case _C_SEL:      return @"SEL";
	case _C_CHR:      return @"char";
	case _C_UCHR:     return @"unsigned char";
	case _C_SHT:      return @"short";
	case _C_USHT:     return @"unsigned short";
	case _C_INT:      return @"int";
	case _C_UINT:     return @"unsigned int";
	case _C_LNG:      return @"long";
	case _C_ULNG:     return @"unsigned long";
#ifdef _C_LNG_LNG
	case _C_LNG_LNG:  return @"long long";
	case _C_ULNG_LNG: return @"unsigned long long";
#endif
	case _C_FLT:      return @"float";
	case _C_DBL:      return @"double";
	case _C_VOID:     return @"void";
	case _C_CHARPTR:  return @"char *";
	case _C_PTR:
	  return [NSString stringWithFormat: @"%@ *",
			   TypeToNSString(_type + 1)];
	  break;
	case _C_STRUCT_B:
	  {
	    NSString *structName = nil;
	    const char *t = _type + 1;

	    if (*t == '?')
	      structName = @"?";
	    else
	      {
		const char *beg = t;

		while ((*t != '=') && (*t != '\0') && (*t != _C_STRUCT_E))
		  t++;
		structName = [NSString stringWithCString:beg length:(t - beg)];
	      }

	    return [NSString stringWithFormat: @"struct %@ {...}", structName];
	  }

	default:
	  return [NSString stringWithFormat: @"%s", _type];
	}
    }
  else
    return @"NULL type";
}

static void 
DumpIVar(id object, Ivar ivar, int deep)
{
  if (ivar && object && deep >= 0)
  {
    void *pValue = ((void*)object) + ivar_getOffset(ivar);
    const char *type = ivar_getTypeEncoding(ivar);
    NSString *pType = TypeToNSString(type);
    NSString *pIVar = IVarInString(type, pValue);
    
    NSDebugFLog(@"IVar %s type:%@ value:%@\n",
                ivar_getName(ivar),
                pType,
                pIVar);
    
    if (deep > 0 && type && *type == _C_ID && pValue)
    {
      EOFLogDumpObject_(NULL, 0, *((id*)pValue), deep);
    }
  }
}

//Dump object 
void 
EOFLogDumpObject_(const char *file, int line, id object, int deep)
{
  USTART
  
  if (object && deep > 0)
  {
    Class class = [object class];
    
    if (class)
    {
      NSDebugFLog(@"--%s %d [%d] Dumping object %p of Class %s Description:%@\n",
                  (file && isalpha(*file) && line >= 0
                   && line<=20000) ? file :"",
                  line,
                  deep,
                  (void*)object,
                  class_getName(class),
                  objectDescription(object));
      while (class)
        {
          unsigned int ivarCount;
          Ivar *ivars = class_copyIvarList(class, &ivarCount);

          class = class_getSuperclass(class);
          
          if (ivars)
            {
              int   i;
              
              for (i = 0; i < ivarCount; i++)
                {
                  DumpIVar(object, ivars[i], deep-1);
                }
            }
          free(ivars);
        }
    }
  }
  
  USTOP
}

void 
EOFLogAssertGood_(const char *file, int line, id object)
{
#ifndef GNUSTEP
#warning EOFLogDumpObject_() is not ported to your platform
#else
  if (object)
    {
      if (object_getClass(object) == ((Class)0xdeadface))
	{
	  NSLog(@"DEAD FACE: object %p isa=%p in %s at %d\n",
		(void*)object,
		(void*)object_getClass(object),
		file,
		line);
	  NSCParameterAssert(object_getClass(object) == (Class)0xdeadface);
	}
    }
  else
    {
      NSLog(@"NULL: object %p in %s at %d\n",
	    (void*)object,
	    file,
	    line);
      NSCParameterAssert(object);
    }
#endif
}

#endif
