section .text

global Bordes_asm

#define PIXEL_OFFSET_RED 0
#define PIXEL_OFFSET_GREEN 1
#define PIXEL_OFFSET_BLUE 2
#define PIXEL_OFFSET_ALPHA 3
#define PIXEL_SIZE 4
Bordes_asm:
;------------------------------------------------------------------------------;
;   Aridad:     void Bordes_asm (uint8_t *src, uint8_t *dst, int width,
;                       int height, int src_row_size, int dst_row_size);
;   
;   Descripción:

;
;   Parámetros:
;               rdi: unit8_t *src
;               rsi: uint8_t *dst
;               edx: int width
;               ecx: int height
;               r8d: src_row_size
;               r9d: dst_row_size
;------------------------------------------------------------------------------;

    push rbp
    mov rbp, rsp

    ;xor r10d, r10d
    ;xor r11d, r11d

;   Recorremos la matriz hasta llegar hasta el último pixel que tiene vecinos.
;   Este pixel es el (n-1, m-1).

    mov eax, edx
    mul ecx

;   En rax tenemos la ultima fila y columna. mul 32b --> 64b
    shl r8, 32
    shr r8, 32
    ;add r10d, ecx
    sub rax, r8
    sub rax, 1


 

    pxor xmm0, xmm0
    pxor xmm13, xmm13
    movdqu xmm15, 0x000000FF000000FF000000FF000000FF
    .ciclo:
        test rax, rax
        jz .fin

        movdqu xmm1, [rdi - r8 - 1]
        movdqu xmm2, [rdi - r8]
        movdqu xmm3, [rdi - r8 + 1]

        movdqu xmm4, [rdi - 1]
        ;movdqu xmm5, [rdi]
        movdqu xmm6, [rdi + 1]

        movdqu xmm7, [rdi + r8 - 1]
        movdqu xmm8, [rdi + r8]
        movdqu xmm9, [rdi + r8 + 1]

;   Podemos optimizar el uso de xmm1 y xmm9 pues para ambas matrices es
;   igual como se suma. Los unicos que cambian son xmm3 y xmm7. Los otros 
;   se usan solo en una matriz o en las dos pero con el mismo valor.

        movdqu xmm10, xmm3
        movdqu xmm11, xmm7

;   Vamos a sumar de a pares negativos/positivos asi minimizamos la cantidad
;   de registros a desempaquetar.

        psubb xmm3, xmm1

;   SI PODEMOS NEGAR EL XMM7 DE A PAQUETES DE BYTES, AHORRAMOS COPIAR EL
;   ALGUNO DE LO S DOS REGISTROS. LO HACEMOS SOBRE XMM7 PUES YA LO TENEMOS QUE
;   COPIAR PARA EL CALCULO DE GY.

        paddb -xmm7, xmm9

;   Usamos xmm7 pues ya lo copiamos a xmm11. A continuación usamos xmm6 pues
;   no lo necesitamos para calcular Gy.

        psubb xmm6, xmm4
        movdqu xmm12, xmm6

;   Desempaquetamos todos los canales a words para multiplicarlos por dos
;   y no perder información en el cálculo intermedio. xmm13 es un registro
;   auxiliar con 0.


;   Me parece que no es ni necesario pues no vamos a estar restando nada
;   después de esto. Entonces lo que nos estamos salvando al deempaquetar ahora
;   lo vamos a perder cuando lo empaquetemos.

;   LA SATURACIÓN ES AL FINAL DE LA SUMA GX, GY

;   No veo como shiftear bytes empaquetados por bits. Para arreglar eso sigo
;   desempaquetando y shifteando parte alta y baja.

        punpcklbw xmm6, xmm13
        punpckhbw xmm12, xmm13

;   psll xmm6, 1
        
        psllw xmm6, 1
        psllw xmm12, 1

;   signed porque puede dar negativo

        packsswb xmm6, xmm12

;   resultado Gx
;       no se si esto está bien, podemos perder alguna precision.
;       deberiamos satrurar solo al sumarlo con el resultado de gy.

        paddb xmm3, xmm7
        paddb xmm3, xmm6

        movdqu xmm0, xmm3

;   Calculo Gy

        psubb xmm11, xmm1
        psubb xmm9, xmm10

        psubb xmm8, xmm2
        movdqu xmm12, xmm8

        punpcklbw xmm8, xmm13
        punpckhbw xmm12, xmm13

        psllw xmm8, 1
        psllw xmm12, 1

        packuswb xmm8, xmm12

;   resultado Gx

        paddb xmm11, xmm9
        paddb xmm11, xmm8

        paddb xmm0, xmm11

;   Hay que setear el alpha a 255 con alguna mascara

        movdqu [rsi], xmm0

;   Si hacemos el empaquetado ahora los valores mayores a 255 van a saturar
;   a 255. Debemos sumar todos los registros acá , de forma desempaquetada
;   y solo empaquetarlos a lo último?

;       Seteamos el alpha.

        por xmm0, xmm15

        lea rdi, [rdi + PIXEL_SIZE*4]
        lea rsi, [rsi + PIXEL_SIZE*4]
        dec rax

        jmp .ciclo

    .fin:
        call llenarBordes
ret
