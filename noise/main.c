#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

#include "libbmp.h"
#include "utils.h"

double box_muller_sample();
void aplicar_ruido(BMP*, double, double, char*);

int main(int argc, char** argv) {
    if (argc != 3) {
        /* argv {
        *  - bin:   ./main
         * - arg1:  img/puente.bmp
         * - arg2:  img/pepe.bmp
         * */
        printf("Error: Missing files \n"
               " - Example:    %s img.bmp imgId\n", argv[0]);
        return EXIT_SUCCESS;
    }

    /* Dada una imagen pasada como argumento, queremos generar un suite de imagenes
     * con niveles de ruido incrementales.
     * */
    BMP *src_img = openImg(argv[1]);

    double sds [28] = {
        1, 3.345, 7.299, 8.117, 9.992, 12.421, 15.015,
        18.299, 21.112, 24.577, 28.333, 33.001, 38.720, 46.209,
        51.108, 59.662, 65.390, 71.152, 79.788, 88.100, 95.078,
        103.511, 110.009, 119.392, 125.176, 127.233, 133.006, 138.812};

    for (int i = 0; i < 28; ++i) {
        aplicar_ruido(src_img, 0, sds[i], argv[2]);
    }
    return EXIT_SUCCESS;
}

double box_muller_sample() {
    double p = ((double) rand())/RAND_MAX;
    return sqrt((-2) * log(p)) * cos(2 * M_PI * p);
    //double p_1 = mu + sigma * sqrt((-2) * log(p)) * sin(2 * M_PI * p);
}
void aplicar_ruido(BMP* src_img, double mu, double sd, char* id) {
    uint32_t width = bmp_width(src_img);
    uint32_t height = bmp_height(src_img);

    unsigned char * data32 = (unsigned char *)src_img->data;

    //  s ->  [
    //          [a, b, c],
    //          [d, e, f],
    //          [g, h, i],
    //          [j, k, l]
    //      ]
    // s[i] V 0 < i < height
    //      y s[i][j] V 0 < j < width

    for (uint32_t i = 0; i < height; ++i) {
        for (uint32_t j = 0; j < width; ++j) {
            double p = mu + sd * box_muller_sample();
            unsigned char *p_s = &data32[(i*width+j)*4];

            p_s[0] = SAT(p_s[0] + p);
            p_s[1] = SAT(p_s[1] + p);
            p_s[2] = SAT(p_s[2] + p);
        }
    }

    char * a = malloc(snprintf(NULL, 0, "noise_M_%d_SD_%d_%s", (int)mu, (int)sd, id) + 1);
    sprintf(a, "noise_M_%d_SD_%d_%s", (int)mu, (int)sd, id);
    bmp_save(a, src_img);
    free(a);
}