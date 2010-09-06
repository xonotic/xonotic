#ifndef __D0_H__
#define __D0_H__

#include <unistd.h> // size_t

#define D0_EXPORT __attribute__((__visibility__("default")))
#define D0_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#define D0_BOOL int

extern void *(*d0_malloc)(size_t len);
extern void (*d0_free)(void *p);

#endif
