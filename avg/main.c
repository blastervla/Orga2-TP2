#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include "utils.h"
#include "libbmp.h"

int main(int argc, char** argv) {
    if (argc != 3) {
    /* argv {
    *  - bin:   ./main
     * - arg1:  img/puente.bmp
     * - arg2:  img/pepe.bmp
     * */
        printf("Error: Missing files \n"
               " - Example:    %s img1.bmp img2.bmp\n" , argv[0]);
        return 0;
    }
    BMP *_src_img_1, *_src_img_2;
    _src_img_1 = openImg(argv[1]);
    _src_img_2 = openImg(argv[2]);

    if (!sameSize(_src_img_1, _src_img_2)) {
        printf("ERROR: Both images must be the same size\n");
        return EXIT_FAILURE;
    }
    uint32_t width = bmp_width(_src_img_1);
    uint32_t height = bmp_height(_src_img_1);

    unsigned char (*_src_matrix_1)[width] = (unsigned char (*)[width]) bmp_data(_src_img_1);
    unsigned char (*_src_matrix_2)[width] = (unsigned char (*)[width]) bmp_data(_src_img_2);

    uint32_t count = 0;
    uint32_t max = 0;
    uint32_t min = 255;
    for (int i = 0; i < height; ++i) {
        for (int j = 0; j < width; ++j) {
            int d = _src_matrix_1[i][j] - _src_matrix_2[i][j];
            if (max < abs(d)) max = abs(d);
            if (min > abs(d)) min = abs(d);
            count = count + abs(d);
        }
    }
    double total_avg = (double) count / (width * height);
    printf("The average difference between pixels is: %lf\n", total_avg);
    printf("Min: %u, Max: %u", min, max);
    return 0;
}