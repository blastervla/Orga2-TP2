#ifndef __UTILS__H__
#define __UTILS__H__

#include "libbmp.h"

#define SAT utils_saturate

BMP* openImg(char*);
uint8_t utils_saturate(int);

typedef struct bgra_t {
    unsigned char b, g, r, a;
} __attribute__((packed)) bgra_t;

#endif /* __UTILS__H__ */