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

uint8_t utils_saturate(int a) {
    if(a > 255) {
        return 255;
    } else {
        if(a < 0 ) {
            return 0;
        } else {
            return a;
        }
    }
}