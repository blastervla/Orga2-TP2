#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include "../tp2.h"

void Bordes_asm (uint8_t *src, uint8_t *dst, int width, int height,
                      int src_row_size, int dst_row_size);

void Bordes_c   (uint8_t *src, uint8_t *dst, int width, int height,
                      int src_row_size, int dst_row_size);

typedef void (Bordes_fn_t) (uint8_t*, uint8_t*, int, int, int, int);


void leer_params_Bordes(configuracion_t *config, int argc, char *argv[]) {
    config->bits_src = 8;
    config->bits_dst = 8;
}

void aplicar_Bordes(configuracion_t *config)
{
    Bordes_fn_t *Bordes = SWITCH_C_ASM( config, Bordes_c, Bordes_asm );
    buffer_info_t info = config->src;
    Bordes(info.bytes, config->dst.bytes, info.width, info.height, 
            info.row_size, config->dst.row_size);
}

void liberar_Bordes(configuracion_t *config) {

}

void ayuda_Bordes()
{
    printf ( "       * Bordes\n" );
    printf ( "           Parámetros     : \n"
             "                         no tiene\n");
    printf ( "           Ejemplo de uso : \n"
             "                         Bordes -i c facil.bmp\n" );
}

DEFINIR_FILTRO(Bordes)


