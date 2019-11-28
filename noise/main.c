#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

#include "libbmp.h"
#include "utils.h"

double box_muller_sample();
void aplicar_ruido(BMP*, double, double, int, char*);

/*const double sds [28] = {
        1, 3.345, 7.299, 8.117, 9.992, 12.421, 15.015,
        18.299, 21.112, 24.577, 28.333, 33.001, 38.720, 46.209,
        51.108, 59.662, 65.390, 71.152, 79.788, 88.100, 95.078,
        103.511, 110.009, 119.392, 125.176, 127.233, 133.006, 138.812};

const double unif [50] = {
        6.952, 13.906, 15.596, 15.803, 15.985, 16.622, 16.726, 18.621, 21.535, 22.777,
        24.261, 25.114, 31.097, 35.832, 41.481, 44.736, 49.920, 50.739, 57.118, 59.416,
        59.912, 60.034, 60.562, 63.480, 69.240, 70.773, 70.946, 72.354, 73.609, 74.837,
        78.061, 81.886, 82.498, 84.287, 85.805, 89.056, 91.054, 91.935, 92.385, 93.294,
        96.290, 98.615, 99.562, 105.811, 106.263, 113.518, 114.365, 120.084, 121.305, 124.764
};*/

int main(int argc, char** argv) {
    if (argc != 5) {
        /* argv {
        *  - bin:   ./main
         * - arg1:  img/puente.bmp
         * - arg2:  img/pepe.bmp
         * */
        printf("Error: Missing files \n"
               " - Example:    %s img.bmp MAX_SD MAX_STEP output_folder\n", argv[0]);
        return EXIT_SUCCESS;
    }

    /* Dada una imagen pasada como argumento, queremos generar un suite de imagenes
     * con niveles de ruido incrementales.
     * */
    BMP *src_img = openImg(argv[1]);


    int max_step = 28;
    // (int) argv[2];
    int max_sd = 100;
    // (int) argv[3];
    for (int i = 0; i <= max_step; ++i) {
        aplicar_ruido(src_img, 0, i * (max_sd / max_step), i, argv[4]);
    }
    return EXIT_SUCCESS;
}

double box_muller_sample() {
    double p = ((double) rand())/RAND_MAX;
    return sqrt((-2) * log(p)) * cos(2 * M_PI * p);
    //double p_1 = mu + sigma * sqrt((-2) * log(p)) * sin(2 * M_PI * p);
}
void aplicar_ruido(BMP* src_img, double mu, double sd, int id, char* folder) {
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

    char * a = malloc(snprintf(NULL, 0, "%s/%d.bmp", folder, id) + 1);
    sprintf(a, "%s/%d.bmp", folder, id);
    bmp_save(a, src_img);
    free(a);
}