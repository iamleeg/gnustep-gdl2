/* 
   EOAdaptorPriv.h

   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@rccr.cremona.it>
   Date: Nov 2002

   This file is part of the GNUstep Database Library.

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
*/

#ifndef __EOAdaptorPriv_h__
#define __EOAdaptorPriv_h__


@interface EOAdaptor(EOAdaptorPrivate)

- (void) _requestConcreteImplementationForSelector: (SEL)param0;
- (void) _unregisterAdaptorContext: (EOAdaptorContext*)adaptorContext;
- (void) _registerAdaptorContext: (EOAdaptorContext*)adaptorContext;

@end


#endif /* __EOAdaptorPriv_h__ */