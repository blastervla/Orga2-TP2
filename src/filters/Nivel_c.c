#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include "../tp2.h"
#include "../helper/utils.h"

void Nivel_c(
    uint8_t *src,
    uint8_t *dst,
    int width,
    int height,
    int src_row_size,
    int dst_row_size,
    int n)
{
    bgra_t (*src_matrix)[(src_row_size+3)/4] = (bgra_t (*)[(src_row_size+3)/4]) src;
    bgra_t (*dst_matrix)[(dst_row_size+3)/4] = (bgra_t (*)[(dst_row_size+3)/4]) dst;

    uint8_t mask = 1 << n;
    
    for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {

            dst_matrix[i][j].b = src_matrix[i][j].b & mask ? 255 : 0;
            dst_matrix[i][j].g = src_matrix[i][j].g & mask ? 255 : 0;
            dst_matrix[i][j].r = src_matrix[i][j].r & mask ? 255 : 0;
            dst_matrix[i][j].a = 255;
        }
    }
}
