/**
    ResourceManager.h

    Author: Matt Rice <ratmice@gmail.com>
    Date: 2005, 2006

    This file is part of GDL2Palette.

    <license>
    GDL2Palette is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    GDL2Palette is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with GDL2Palette; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
    </license>
**/

#include <InterfaceBuilder/IBResourceManager.h>

@class EOEditingContext;
@class EOModelGroup;


@interface GDL2ResourceManager : IBResourceManager
{
  EOEditingContext *_defaultEditingContext;
  EOModelGroup *modelGroup;
}

@end

