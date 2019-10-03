#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include "../tp2.h"

void Rombos_asm (uint8_t *src, uint8_t *dst, int width, int height,
                      int src_row_size, int dst_row_size);

void Rombos_c   (uint8_t *src, uint8_t *dst, int width, int height,
                      int src_row_size, int dst_row_size);

typedef void (Rombos_fn_t) (uint8_t*, uint8_t*, int, int, int, int);


void leer_params_Rombos(configuracion_t *config, int argc, char *argv[]) {

}

void aplicar_Rombos(configuracion_t *config)
{
    Rombos_fn_t *Rombos = SWITCH_C_ASM( config, Rombos_c, Rombos_asm );
    buffer_info_t info = config->src;
    Rombos(info.bytes, config->dst.bytes, info.width, info.height, 
            info.row_size, config->dst.row_size);
}

void liberar_Rombos(configuracion_t *config) {

}

void ayuda_Rombos()
{
    printf ( "       * Rombos\n" );
    printf ( "           Parámetros     : \n"
             "                         no tiene\n");
    printf ( "           Ejemplo de uso : \n"
             "                         Rombos -i c facil.bmp\n" );
}

DEFINIR_FILTRO(Rombos)


