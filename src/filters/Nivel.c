#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include "../tp2.h"

void Nivel_asm (uint8_t *src, uint8_t *dst, int width, int height,
                      int src_row_size, int dst_row_size, int n);

void Nivel_c   (uint8_t *src, uint8_t *dst, int width, int height,
                      int src_row_size, int dst_row_size, int n);

typedef void (Nivel_fn_t) (uint8_t*, uint8_t*, int, int, int, int, int);

typedef struct Nivel_params_t {
    int n;
} Nivel_params_t;

Nivel_params_t extra;

void leer_params_Nivel(configuracion_t *config, int argc, char *argv[]) {
    config->extra_config = &extra;
    extra.n = atoi(argv[argc - 1]);
    if( extra.n < 0 ) extra.n = 0;
    if( extra.n > 7 ) extra.n = 7;
}

void aplicar_Nivel(configuracion_t *config)
{
    Nivel_fn_t *Nivel = SWITCH_C_ASM( config, Nivel_c, Nivel_asm );
    buffer_info_t info = config->src;
    Nivel(info.bytes, config->dst.bytes, info.width, info.height, 
            info.row_size, config->dst.row_size, extra.n);
}

void liberar_Nivel(configuracion_t *config) {

}

void ayuda_Nivel()
{
    printf ( "       * Nivel\n" );
    printf ( "           Parámetros     : \n"
             "                         n = nivel de bit, número entero entre 0 y 7\n");
    printf ( "           Ejemplo de uso : \n"
             "                         Nivel -i c facil.bmp 5\n" );
}

DEFINIR_FILTRO(Nivel)


