//
// BXExport.h
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
// us at sales@karppinen.fi. Without an additional license, this software
// may be distributed only in compliance with the GNU General Public License.
//
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License, version 2.0,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
// $Id$
//


#ifndef BX_INTERNAL
#ifdef __cplusplus
#define BX_INTERNAL extern "C" __attribute__((visibility("hidden")))
#else
#define BX_INTERNAL extern     __attribute__((visibility("hidden")))
#endif
#endif


#ifndef BX_EXPORT
#ifdef __cplusplus
#define BX_EXPORT extern "C"   __attribute__((visibility("default")))
#else
#define BX_EXPORT extern       __attribute__((visibility("default")))
#endif
#endif


#ifndef BX_ANALYZER_NORETURN
#if __clang__
#define BX_ANALYZER_NORETURN   __attribute__((analyzer_noreturn))
#else
#define BX_ANALYZER_NORETURN
#endif
#endif


#ifndef BX_FORMAT_FUNCTION(X,Y)
#ifdef NS_FORMAT_FUNCTION
#define BX_FORMAT_FUNCTION(X,Y) NS_FORMAT_FUNCTION(X,Y)
#else
#define BX_FORMAT_FUNCTION(X,Y)
#endif
#endif


#ifndef BX_DEPRECATED_IN_1_8
#define BX_DEPRECATED_IN_1_8 DEPRECATED_ATTRIBUTE
#endif
