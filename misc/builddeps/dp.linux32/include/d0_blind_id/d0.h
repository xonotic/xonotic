/*
 * FILE:	d0.h
 * AUTHOR:	Rudolf Polzer - divVerent@xonotic.org
 * 
 * Copyright (c) 2010, Rudolf Polzer
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTOR(S) ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTOR(S) BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $Format:commit %H$
 * $Id: 0f9b41999f2a57f07067272a8b89919394c4b04f $
 */

#ifndef __D0_H__
#define __D0_H__

#include <unistd.h> // size_t

#define D0_EXPORT __attribute__((__visibility__("default")))
#define D0_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#define D0_BOOL int

typedef void *(d0_malloc_t)(size_t len);
typedef void (d0_free_t)(void *p);
typedef void *(d0_createmutex_t)(void);
typedef void (d0_destroymutex_t)(void *);
typedef int (d0_lockmutex_t)(void *); // zero on success
typedef int (d0_unlockmutex_t)(void *); // zero on success

extern d0_malloc_t *d0_malloc;
extern d0_free_t *d0_free;
extern d0_createmutex_t *d0_createmutex;
extern d0_destroymutex_t *d0_destroymutex;
extern d0_lockmutex_t *d0_lockmutex;
extern d0_unlockmutex_t *d0_unlockmutex;

void d0_setmallocfuncs(d0_malloc_t *m, d0_free_t *f);
void d0_setmutexfuncs(d0_createmutex_t *c, d0_destroymutex_t *d, d0_lockmutex_t *l, d0_unlockmutex_t *u);
void d0_initfuncs(void); // initializes them, this needs to be only called internally once

extern const char *d0_bsd_license_notice;

#endif
