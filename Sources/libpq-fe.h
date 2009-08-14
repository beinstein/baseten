//
// libpq-fe.h
// BaseTen
//
// Copyright (C) 2009 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://www.karppinen.fi/baseten/licensing/ or by contacting
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

#if defined (__ppc__) && __ppc__
#include <BaseTen/postgresql/ppc/libpq-fe.h>
#elif defined (__ppc64__) && __ppc64__
#include <BaseTen/postgresql/ppc64/libpq-fe.h>
#elif defined (__i386__) && __i386__
#include <BaseTen/postgresql/i386/libpq-fe.h>
#elif defined (__x86_64__) && __x86_64__
#include <BaseTen/postgresql/x86_64/libpq-fe.h>
#elif defined (__arm__) && __arm__
#include <BaseTen/postgresql/arm/libpq-fe.h>
#else
#error "Unsupported architecture."
#endif
