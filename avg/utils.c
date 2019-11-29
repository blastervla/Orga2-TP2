#include "utils.h"

BMP* openImg(char* file) {
    BMP* _img_src;
    if ((_img_src = bmp_read(file)) == 0) {
        // fprintf(stderr, "Error: File could not be open properly\n");
        exit( EXIT_FAILURE );
    }
    if (bmp_compression(_img_src) != BI_RGB) {
        fprintf(stderr, "Error: file is compressed\n");
        exit(EXIT_FAILURE);
    }
    if (bmp_bit_count(_img_src) == 24) {
        bmp_convert_24_to_32_bpp(_img_src);
    }
    return _img_src;
}

uint8_t sameSize(BMP* img1, BMP* img2) {
    return (bmp_width(img1) == bmp_width(img2)) && (bmp_height(img1) == bmp_height(img2));
}
