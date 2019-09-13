#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include "../tp2.h"
#include "../helper/utils.h"

void Rombos_c(
    uint8_t *src,
    uint8_t *dst,
    int width,
    int height,
    int src_row_size,
    int dst_row_size)
{
    bgra_t (*src_matrix)[(src_row_size+3)/4] = (bgra_t (*)[(src_row_size+3)/4]) src;
    bgra_t (*dst_matrix)[(dst_row_size+3)/4] = (bgra_t (*)[(dst_row_size+3)/4]) dst;

    for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            
            int size = 64;
            int ii = ((size>>1)-(i%size)) > 0 ? ((size>>1)-(i%size)) : -((size>>1)-(i%size));
            int jj = ((size>>1)-(j%size)) > 0 ? ((size>>1)-(j%size)) : -((size>>1)-(j%size));
            int x = (ii+jj-(size>>1)) > (size>>4) ? 0 : 2*(ii+jj-(size>>1));
            
            dst_matrix[i][j].b = SAT(src_matrix[i][j].b + x);
            dst_matrix[i][j].g = SAT(src_matrix[i][j].g + x);
            dst_matrix[i][j].r = SAT(src_matrix[i][j].r + x);
            dst_matrix[i][j].a = 255;
        }
    }

}
