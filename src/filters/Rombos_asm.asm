extern malloc
extern free

global Rombos_asm
global Rombos_pclc_asm

;
; Pseudocódigo
; ------------
;
; size = 64
; 
; for i = 0 to height - 1:
;   for j = 0 to width - 1:
;       ii = ((size/2)-(i%size)) > 0 ? ((size/2)-(i%size)) : -((size/2)-(i%size))
;       jj = ((size/2)-(j%size)) > 0 ? ((size/2)-(j%size)) : -((size/2)-(j%size))
;
;       x = (ii+jj-(size/2)) > (size/16) ? 0 : 2*(ii+jj-(size/2))
;
;       dst[i][j].b = SAT(src[i][j].b + x)
;       dst[i][j].g = SAT(src[i][j].g + x)
;       dst[i][j].r = SAT(src[i][j].r + x)
;       dst[i][j].a = 255
;
; - Se que el ancho de la imagen es múltiplo de 8

%define SIZE 64
%define PIXEL_SIZE 4

section .rodata
; Mascaras para operar sobre los indices, cada uno es una double word,
; osea 32 bits o 4 bytes (8 hex c/u)
;         xmm{x} =     i_0   |     j_0   |     i_1   |     j_1
INITIAL_IDXS:   dd 0x00000000, 0x00000000, 0x00000000, 0x00000001   ; Estado inicial de los indices
INC_J:          dd 0x00000000, 0x00000002, 0x00000000, 0x00000002   ; Incrementa los j-es
INC_I:          dd 0x00000001, 0x00000000, 0x00000001, 0x00000000   ; Incrementa los i-es
NEG_XOR:        dd 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF   ; Máscara para negar con xor

; Mascaras para operar sobre los x-es
;         xmm{x} =   b  |    g  |    r  |    a 
ALPHA:  TIMES 2 dw 0x0000, 0x0000, 0x0000, 0x00FF   ; Poner en 255 el canal alpha 

;                           IMPLEMENTACIÓN NORMAL
;                           =====================
;
; Levanta de a dos pixeles, y no precalcula nada.

section .text
Rombos_asm:
    ; Rombos_asm(
    ;   uint8_t *src,       rdi
    ;   uint8_t *dst,       rsi
    ;   int width,          edx
    ;   int height,         ecx
    ;   int src_row_size,   r8
    ;   int dst_row_size    r9
    ; )

    ; La idea es levantar de a dos pixeles, y operar sobre sus índices % size
    ; en paralelo, algo así como:
    ;
    ;                   pixel_0     |       pixel_1
    ;   xmm{x} =  i_0 % s | j_0 % s | i_1 % s | j_1 % s
    ;
    ; Donde
    ;
    ;   i = fila
    ;   j = columna
    ;
    ; Para evitar tener que calcular el módulo, les voy sumando 1 y los llevo
    ; a 0 cuando lleguen a su máximo (64).
    ;
    ; Dos cosas usadas en todas las iteraciones son size/2 y los índices, los
    ; guardo en dos registros para ahorrar computo.

    ; Preparo las mascaras para poder reiniciar los índices
    ; Muevo size a xmm15
    mov r10d, SIZE              ; r10 = size     
    movd xmm15, r10d            ; xmm15[31:0] = size
    pshufd xmm15, xmm15, 0x00   ; xmm15 = size | size | size | size
    ; Muevo height a xmm14
    movd xmm14, ecx             ; xmm14[32:0] = height
    pshufd xmm14, xmm14, 0x00   ; xmm14 = h | h | h | h
    ; Muevo width a xmm13
    movd xmm13, edx             ; xmm13[32:0] = width
    pshufd xmm13, xmm13, 0x00   ; xmm13 = w | w | w | w

    ; Me quedo con los minimos
    pminud xmm14, xmm15         ; xmm14[i] = min{size, height}
    pminud xmm13, xmm15         ; xmm13[i] = min{size, width}

    ; Muevo size/2 a xmm0
    movdqu xmm0, xmm15      ; xmm0 = size | size | size | size
    ; Divido size por 2 shifteando a la derecha
    psrld xmm0, 1           ; xmm0 = s/2  | s/2  | s/2  | s/2

    ; Muevo los índices iniciales a xmm1
    ; TODO: usar align y mvdqa
    movdqu xmm1, [INITIAL_IDXS] ; xmm1 = i_0 % s | j_0 %s | i_1 %s | j_1 % s
                                ;      =     0   |    0   |    0   |    1

    ; Precargo máscaras
    movdqu xmm12, [NEG_XOR]
    movdqu xmm10, [INC_J]
    movdqu xmm9,  [INC_I]
    movdqu xmm8,  [ALPHA]

    ; Inicializo los offsets / contadores
    xor r9, r9      ; r9 = 0, lo uso como bytes_row_actual
    xor r10, r10    ; r10 = 0, lo uso como offset de src y dst
    ; El ultimo offset que voy a usar va a ser
    ;
    ;   max_offset = height * width - 2 (ya que avanzo de a 2 pixeles)
    ;
    ; edx = width
    ; ecx = height
    ; Los multiplico usando `mul` en 64 bits, y como son de 32 el resultado
    ; me queda en rax
    mov eax, edx        ; eax = width
    mul rcx             ; rax = rax * rcx = width * height
    mov r11, rax        ; r11 = siguiente a max_offset

    .loop:
        ; Quiero calcular los ii-es y jj-es
        ;
        ;   ii = ((s/2) - (i % s)) > 0 ? ((s/2) - (i % s)) : -((s/2) - (i % s))
        ;      = abs(s/2 - i % s)
        ;   jj = abs(s/2 - j % s)
        ;
        ; Donde abs es el valor absoluto

        movdqu xmm2, xmm0   ; xmm2 = s/2 | s/2 | s/2 | s/2
        psubd xmm2, xmm1    ; xmm2 = s/2 - i_0 | s/2 - j_0 | s/2 - i_1 | s/2 - j_1
        ; Si quedo algo negativo, quiero que sea positivo.
        pabsd xmm2, xmm2

        ; Tengo lo que quería en xmm2
        ; xmm2 = abs(s/2 - i_0%s) | abs(s/2 - j_0%s) | abs(s/2 - i_1%s) | abs(s/2 - j_1%s)
        ;      = ii_0 | jj_0 | ii_1 | jj_1

        ; Quiero calcular los x-es
        ;
        ;   x = (ii+jj - (s/2)) > (s/16) ? 0 : 2*(ii+jj - (s/2))
        ;
        ; Y noto que es lo mismo que multiplicar por dos siempre, y hacer
        ;
        ;   x_0 = 2*(ii+jj - (s/2)) > (s/8) ? 0 : 2*(ii+jj - (s/2))

                            ; xmm2 =       ii_0        |       jj_0        |       ii_1        |       jj_1
        phaddd xmm2, xmm2   ; xmm2 =    ii_0 + jj_0    |    ii_1 + jj_1    |    ii_0 + jj_0    |    ii_1 + jj_1
        psubd xmm2, xmm0    ; xmm2 =  ii_0+jj_0 - s/2  |  ii_1+jj_1 - s/2  |  ii_0+jj_0 - s/2  |  ii_1+jj_1 - s/2 
        pslld xmm2, 1       ; xmm2 = 2*(ii_0+jj_0-s/2) | 2*(ii_1+jj_1-s/2) | 2*(ii_0+jj_0-s/2) | 2*(ii_1+jj_1-s/2)
        ; Quiero llevar a 0 los que sean mayores a s/8
        movdqu xmm3, xmm0   ; xmm3 = s/2 | s/2 | s/2 | s/2
        psrld xmm3, 2       ; xmm3 = s/8 | s/8 | s/8 | s/8
        movdqu xmm4, xmm2   ; xmm4 = 2*(ii_0+jj_0-s/2) | 2*(ii_1+jj_1-s/2) | 2*(ii_0+jj_0-s/2) | 2*(ii_1+jj_1-s/2)
        pcmpgtd xmm2, xmm3  ; xmm2[i] = FFFFFFFF    si 2*(ii_x+jj_x-s/2) > s/8
                            ;           00000000    si no
        ; Tengo FF donde quiero que quede 0 y 0 donde quiero que quede lo mismo.
        ; Debería negarlo y luego hacer un and.
        ; Con un ANDN logro eso
        pandn xmm2, xmm4    ; xmm2[i] = 0           si era mayor a s/8
                            ;           lo mismo    si no

        ; Tengo en xmm2 lo que quería
        ; xmm2 = x_0 | x_1 | x_0 | x_1
        
        ; Quiero sumarlos a los canales de sus respectivos pixeles.
        ; Al levantarlos, cada canal es de 1 byte y son enteros sin signos, y
        ; las x-es son signadas. Necesito pasarlas a la misma representación.
        ; Empaqueto las x-es de dw a w, y desempaqueto los pixeles de b a w.
        ; 
        ; De esa forma los pixeles quedan así:
        ; (menos a más significativo de izquierda a derecha) 
        ;
        ;   xmm{x} =           p_0          ||          p_1
        ;          =  b_0 | g_0 | r_0 | a_0 || b_1 | g_1 | r_1 | a_1
        ;
        ; xmm2 = x_0 | x_1 | x_0 | x_1
        ; Empaqueto a word
        packssdw xmm2, xmm2 ; xmm2 = x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1
        ; Están desordenados, necesito agruparlos en la parte baja según
        ; a que pixel tienen que sumarse
                                        ;        b_0 | g_0 | r_0 | a_0 | b_1 | g_1 | r_1 | a_1
                                        ; xmm2 = x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1
        pshuflw xmm2, xmm2, 0b00000000  ; xmm2 = x_0 | x_0 | x_0 | x_0 | x_0 | x_1 | x_0 | x_1
        pshufhw xmm2, xmm2, 0b01010101  ; xmm2 = x_0 | x_0 | x_0 | x_0 | x_1 | x_1 | x_1 | x_1

        ; Recuerdo que
        ;
        ;   rdi = src
        ;   rsi = dst
        ;
        ; Levanto los pixeles
        movq xmm3, [rdi + r10 * PIXEL_SIZE] ; xmm3[0:63] = b_0 | g_0 | r_0 | a_0 | b_1 | g_1 | r_1 | a_1
        ; Desempaqueto a word solo la parte baja
        pxor xmm7, xmm7                     ; xmm7[0:63] =  0  |  0  |  0  |  0  |  0  |  0  |  0  |  0
        punpcklbw xmm3, xmm7                ; xmm3 =    b_0    |    g_0    |    r_0    | a_0 |    b_1    |    g_1    |    r_1    | a_1
        paddsw xmm3, xmm2                   ; xmm3 = b_0 + x_0 | g_0 + x_0 | r_0 + x_0 |  _  | b_1 + x_1 | g_1 + x_1 | r_1 + x_1 |  _

        ; Pongo el canal alpha en 255
                                ; xmm8 = 0000 | 0000 | 0000 | 00FF | 0000 | 0000 | 0000 | 00FF
        por xmm3, xmm8          ; xmm3 =  __  |  __  |  __  |  FF  |  __  |  __  |  __  |  FF

        ; Empaqueto de word a byte
        packuswb xmm3, xmm3      ; xmm3[0:63] = b_0 + x_0 | g_0 + x_0 | r_0 + x_0 | FF | b_1 + x_1 | g_1 + x_1 | r_1 + x_1 | FF
        ; Escribo el resultado
        movq [rsi + r10 * PIXEL_SIZE], xmm3
        
        ; Quiero avanzar los indices que están en xmm1
        ;
        ;   xmm1 = i_0 % s | j_0 % s | i_1 % s | j_1 % s
        ;
        ; los j-es serían del "ciclo intero", mientras que los i-es del "externo"
        ; Para incrementar los indices mod s, incremento y después comparo 
        ; con s. Si es mayor, entonces lo vuelvo a 0 (i.e wraparound).
        ; Tengo que incrementar los i solo cuando hacen wraparound los j.

        ; Incremento los j-es
                            ; xmm10 =  0  |     2   |  0  |     2
        paddd xmm1, xmm10   ; xmm1  = i_0 | j_0 + 2 | i_1 | j_1 + 2

        ; Reseteo los que se pasaron
        ; mod con el mínimo entre width y size, está en xmm13
        ; Por lo general va a ser size entonces por conveniencia lo comento así
        movdqu xmm3, xmm13      ; xmm3 = s | s | s | s
        movdqu xmm4, xmm13      ; xmm4 = s | s | s | s

        pcmpgtd xmm4, xmm1      ; xmm4[i] = 0xFFFFFFFF si xmm1[i] < s
                                ;           0x00000000 si no
                                ; xmm12 = FFFFFFFF | FFFFFFFF | ... | ...
        pxor xmm4, xmm12        ; xmm4[i] = 0xFFFFFFFF si xmm1[i] >= s
                                ;           0x00000000 si no

        pand xmm3, xmm4         ; xmm3[i] = size    si se paso
                                ;           0       sino

        psubd xmm1, xmm3        ; xmm1 = i_0 | j_0 + 2 % s | i_1 | j_1 + 2 % s

        ; Incremento los i-es
        ; Solo debería hacerlo si llegue al final de la fila
        ; Avanzo la cantidad de bytes leidos de la columna actual
        add r9, 8             ; col += 2 * PIXEL_SIZE = 8
        ; Si pase el final, lo vuelvo a 0 e incremento i
        cmp r9, r8            ; cmp bytes_row_actual src_row_size
        jb .dont_inc_row
        xor r9, r9            ; bytes_row_actual = 0

                            ; xmm9 = 1 | 0 | 1 | 0
        paddd xmm1, xmm9    ; xmm1 = i_0 + 1 | j_0 + 2 % s | i_1 + 1 | j_1 + 2 % s

        ; Resto size a los que se pasaron
        ; Mod con el minimo entre height y size, está en xmm14
        ; Por lo general va a ser size entonces por conveniencia lo comento así
        movdqu xmm3, xmm13      ; xmm3 = s | s | s | s
        movdqu xmm4, xmm13      ; xmm4 = s | s | s | s

        pcmpgtd xmm4, xmm1      ; xmm4[i] = 0xFFFFFFFF si xmm1[i] < s
                                ;           0x00000000 si no
                                ; xmm12 = FFFFFFFF | FFFFFFFF | ... | ...
        pxor xmm4, xmm12        ; xmm4[i] = 0xFFFFFFFF si xmm1[i] >= s
                                ;           0x00000000 si no

        pand xmm3, xmm4         ; xmm3[i] = size    si se paso
                                ;           0       sino

        psubd xmm1, xmm3        ; xmm1 = i_0 + 1 % s | j_0 + 2 % s | i_1 + 1 % s | j_1 + 2 % s
        .dont_inc_row:

        ; Avanzo el offset
        add r10, 2             ; offset += 2 (leo de a dos pixeles)

        ; Si no termine, sigo ciclando
        cmp r10, r11        ; cmp offset, max_offset
        jne .loop

    ; Termine     
ret

;                       IMPLEMENTACIÓN "EFICIENTE"
;                       ==========================
;
; Levanta de a dos pixeles, pero precalcula lo necesario con los índices y lo
; guarda en memoria. 
; Inicialmente se podría pensar que como tiene que levantarlos de memoria, que
; sería más eficiente. Pero como son pocos calculos, probablemente entran todos 
; en el caché L1 y luego es rápido de ir a buscar, entonces vale la pena.
;
; Como se hacen 4 a la vez, los x-es calculados tienen la siguiente pinta:
;
;   xmm2 = x_0 | x_0 | x_0 | x_0 | x_1 | x_1 | x_1 | x_1
;
; Los almaceno de forma tal que lo único que se tenga que hacer dentro del
; ciclo sea levantar dos celdas seguidas, según corresponda a cada i y j.
; Para eso, uso una matriz cuadrada de tamaño SIZE, con celdas de 8 bytes
; Voy a necesitar
;   (SIZE^2 * 8) bytes 
;       = 64^2 * 8 bytes
;       = 32 KB

%define PCLC_SIZE       32768
%define PCLC_ROW_SIZE   64
%define PCLC_CELL_SIZE  8

Rombos_pclc_asm:
    ; Rombos_pclc(
    ;   uint8_t *src,       rdi
    ;   uint8_t *dst,       rsi
    ;   int width,          edx
    ;   int height,         ecx
    ;   int src_row_size,   r8
    ;   int dst_row_size    r9
    ; )

    push rbx    ; width
    push r12    ; height
    push r13    ; j
    push r14    ; i
    push r15    ; Para usar de puntero a inicio de PCLC

    mov rbx, rdx    ; rbx = width
    mov r12, rcx    ; r12 = height
    xor r13, r13    ; r13 = i
    xor r14, r14    ; r14 = j

    ; Temporalmente me guardo los parámetros de entrada en la pila para después
    ; reestablecerlos
    push rdi
    push rsi
    push rdx
    push rcx
    push r8
    push r9 ; Alineado a 16

    mov rdi, PCLC_SIZE
    call malloc     ; rax = puntero al comienzo de mi matriz de precalculo
    mov r15, rax    ; r15 = pcalc start

    ; Reestablezco registros
    pop r9
    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi

    ; Muevo size a xmm15
    mov r10d, SIZE              ; r10 = size     
    movd xmm15, r10d            ; xmm15[31:0] = size
    pshufd xmm15, xmm15, 0x00   ; xmm15 = size | size | size | size

    ; Muevo size/2 a xmm0
    movdqu xmm0, xmm15      ; xmm0 = size | size | size | size
    ; Divido size por 2 shifteando a la derecha
    psrld xmm0, 1           ; xmm0 = s/2  | s/2  | s/2  | s/2

    ; Precargo máscaras
    movdqu xmm12, [NEG_XOR]
    movdqu xmm10, [INC_J]
    movdqu xmm9,  [INC_I]
    movdqu xmm8,  [ALPHA]

    ; Voy a mantener los índices en dos lugares, 
    ;  - En registros normales para indexar en la matriz
    ;  - En registros xmm para realizar los cálculos

    ; Muevo los índices iniciales a xmm1
    movdqu xmm1, [INITIAL_IDXS] ; xmm1 = i_0 % s | j_0 %s | i_1 %s | j_1 % s
                                ;      =     0   |    0   |    0   |    1

    ; Precalculo
    ; ----------

    .pclc_loop:
        ; Quiero calcular los ii-es y jj-es
        ;
        ;   ii = ((s/2) - (i % s)) > 0 ? ((s/2) - (i % s)) : -((s/2) - (i % s))
        ;      = abs(s/2 - i % s)
        ;   jj = abs(s/2 - j % s)
        ;

        movdqu xmm2, xmm0   ; xmm2 =        s/2       |        s/2       |        s/2       |        s/2
        psubd xmm2, xmm1    ; xmm2 =     s/2 - i_0    |     s/2 - j_0    |     s/2 - i_1    |     s/2 - j_1
        pabsd xmm2, xmm2    ; xmm2 = abs(s/2 - i_0%s) | abs(s/2 - j_0%s) | abs(s/2 - i_1%s) | abs(s/2 - j_1%s)
        ; Tengo en xmm2 lo que quería
        ; xmm2 = ii_0 | jj_0 | ii_1 | jj_1

        ; Quiero calcular los x-es
        ;
        ;   x = (ii+jj - (s/2)) > (s/16) ? 0 : 2*(ii+jj - (s/2))
        ;
        ; Y noto que es lo mismo que multiplicar por dos siempre, y hacer
        ;
        ;   x_0 = 2*(ii+jj - (s/2)) > (s/8) ? 0 : 2*(ii+jj - (s/2))

                            ; xmm2 =       ii_0        |       jj_0        |       ii_1        |       jj_1
        phaddd xmm2, xmm2   ; xmm2 =    ii_0 + jj_0    |    ii_1 + jj_1    |    ii_0 + jj_0    |    ii_1 + jj_1
        psubd xmm2, xmm0    ; xmm2 =  ii_0+jj_0 - s/2  |  ii_1+jj_1 - s/2  |  ii_0+jj_0 - s/2  |  ii_1+jj_1 - s/2 
        pslld xmm2, 1       ; xmm2 = 2*(ii_0+jj_0-s/2) | 2*(ii_1+jj_1-s/2) | 2*(ii_0+jj_0-s/2) | 2*(ii_1+jj_1-s/2)
        ; Quiero llevar a 0 los que sean mayores a s/8
        movdqu xmm3, xmm0   ; xmm3 = s/2 | s/2 | s/2 | s/2
        psrld xmm3, 2       ; xmm3 = s/8 | s/8 | s/8 | s/8
        movdqu xmm4, xmm2   ; xmm4 = 2*(ii_0+jj_0-s/2) | 2*(ii_1+jj_1-s/2) | 2*(ii_0+jj_0-s/2) | 2*(ii_1+jj_1-s/2)
        pcmpgtd xmm2, xmm3  ; xmm2[i] = FFFFFFFF    si 2*(ii_x+jj_x-s/2) > s/8
                            ;           00000000    si no
        ; Tengo FF donde quiero que quede 0 y 0 donde quiero que quede lo mismo.
        ; Debería negarlo y luego hacer un and.
        ; Con un ANDN logro eso
        pandn xmm2, xmm4    ; xmm2[i] = 0           si era mayor a s/8
                            ;           lo mismo    si no

        ; Tengo en xmm2 lo que quería
        ; xmm2 = x_0 | x_1 | x_0 | x_1
        
        ; Quiero sumarlos a los canales de sus respectivos pixeles.
        ; Al levantarlos, cada canal es de 1 byte y son enteros sin signos, y
        ; las x-es son signadas. Necesito pasarlas a la misma representación.
        ; Empaqueto las x-es de dw a w, y desempaqueto los pixeles de b a w.
        ; 
        ; De esa forma los pixeles quedan así:
        ; (menos a más significativo de izquierda a derecha) 
        ;
        ;   xmm{x} =           p_0          ||          p_1
        ;          =  b_0 | g_0 | r_0 | a_0 || b_1 | g_1 | r_1 | a_1
        ;
        ; xmm2 = x_0 | x_1 | x_0 | x_1
        ; Empaqueto a word
        packssdw xmm2, xmm2 ; xmm2 = x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1
        ; Están desordenados, necesito agruparlos en la parte baja según
        ; a que pixel tienen que sumarse
                                        ;        b_0 | g_0 | r_0 | a_0 | b_1 | g_1 | r_1 | a_1
                                        ; xmm2 = x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1
        pshuflw xmm2, xmm2, 0b00000000  ; xmm2 = x_0 | x_0 | x_0 | x_0 | x_0 | x_1 | x_0 | x_1
        pshufhw xmm2, xmm2, 0b01010101  ; xmm2 = x_0 | x_0 | x_0 | x_0 | x_1 | x_1 | x_1 | x_1

        ; Lo guardo en pclc
        ;   
        ;   pos = pcalc_start + cell_size * i * row_size
        ;                     + cell_size * j
        ;       = pclc_start + cell_size * (i * row_size + j)
        ;
        ; Calculo el offset
        mov rax, PCLC_ROW_SIZE          ; rax = row_size
        mul r13                         ; rax = row_size * i
        add rax, r14                    ; rax = row_size * i + j
        lea rax, [rax * PCLC_CELL_SIZE] ; rax = (row_size * i + j) * cell_size
        ; Escribo en pclc
        movdqu [r15 + rax], xmm2

        ; Incremento los índices
        ; Incremento j por 2
        add r14, 2          ; j += 2
        paddd xmm1, xmm10   ; xmm1 = i_0 | j_0 + 2 | i_1 | j_1 + 2
        ; Si me pasé de size, lo vuelvo a 0 e incremento i
        cmp r14, SIZE       ; cmp j, 64
        jb .not_inc_i
        xor r14, r14        ; j = 0
        psubd xmm1, xmm15   ; xmm1 = i_0 | j_0 - size | i_1 | j_1 - size
        inc r13             ; i++
        paddd xmm1, xmm9    ; xmm1 = i_0 + 1 | j_0 | i_1 + 1 | j_1
        .not_inc_i:

        ; Si me pasé con i, termine
        cmp r13, SIZE   ; cmp i, 64
        jb .pclc_loop   ; if i < 64 goto loop 

    ; Procesamiento de la imagen
    ; --------------------------

    ; El ultimo offset que voy a usar va a ser
    ;
    ;   max_offset = height * width - 2 (ya que avanzo de a 2 pixeles)
    ;
    ; rbx = width
    ; r12 = height
    ; Los multiplico usando `mul` en 64 bits, y como son de 32 el resultado
    ; me queda en rax
    mov eax, ebx        ; eax = width
    mul r12             ; rax = width * height
    mov r11, rax        ; r11 = siguiente a max_offset

    ; Para reiniciar los índices, ahora tengo
    ;   r12 = height
    ;   rbx = width
    ; Me quedo con
    ;   r12 = min{size, height}
    ;   rbx = min{size, width}
    ; Muevo height a xmm14
    movd xmm14, r12d            ; xmm14[32:0] = height
    ; Muevo width a xmm13
    movd xmm13, ebx             ; xmm13[32:0] = width
    ; Me quedo con los minimos
    pminud xmm14, xmm15         ; xmm14[32:0] = min{size, height}
    pminud xmm13, xmm15         ; xmm13[32:0] = min{size, width}
    ; Los muevo devuelta
    movd r12d, xmm14            ; ecx = min{size, height}
    movd ebx, xmm13             ; edx = min{size, width}

    ; Inicializo los contadores
    xor r9,  r9     ; r9  = 0 (bytes_row_actual)
    xor r10, r10    ; r10 = 0 (offset de src y dst)
    xor r13, r13    ; r13 = i (indice en pclc)
    xor r14, r14    ; r14 = j (indice en pclc)

    .loop:
        ; Levanto en xmm2 los calculos para los indices
        ;   
        ;   pos = pcalc_start + cell_size * i * row_size
        ;                     + cell_size * j
        ;
        ; Calculo el offset
        mov rax, PCLC_ROW_SIZE          ; rax = row_size
        mul r13                         ; rax = row_size * i
        add rax, r14                    ; rax = row_size * i + j
        lea rax, [rax * PCLC_CELL_SIZE] ; rax = (row_size * i + j) * cell_size
        ; Levanto
        movdqu xmm2, [r15 + rax]

        ; Recuerdo que
        ;
        ;   rdi = src
        ;   rsi = dst
        ;
        ; Levanto los pixeles
        movq xmm3, [rdi + r10 * PIXEL_SIZE] ; xmm3[0:63] = b_0 | g_0 | r_0 | a_0 | b_1 | g_1 | r_1 | a_1
        ; Desempaqueto a word solo la parte baja
        pxor xmm7, xmm7                     ; xmm7[0:63] =  0  |  0  |  0  |  0  |  0  |  0  |  0  |  0
        punpcklbw xmm3, xmm7                ; xmm3 =    b_0    |    g_0    |    r_0    | a_0 |    b_1    |    g_1    |    r_1    | a_1
        paddsw xmm3, xmm2                   ; xmm3 = b_0 + x_0 | g_0 + x_0 | r_0 + x_0 |  _  | b_1 + x_1 | g_1 + x_1 | r_1 + x_1 |  _

        ; Pongo el canal alpha en 255
                                ; xmm8 = 0000 | 0000 | 0000 | 00FF | 0000 | 0000 | 0000 | 00FF
        por xmm3, xmm8          ; xmm3 =  __  |  __  |  __  |  FF  |  __  |  __  |  __  |  FF

        ; Empaqueto de word a byte
        packuswb xmm3, xmm3      ; xmm3[0:63] = b_0 + x_0 | g_0 + x_0 | r_0 + x_0 | FF | b_1 + x_1 | g_1 + x_1 | r_1 + x_1 | FF
        ; Escribo el resultado
        movq [rsi + r10 * PIXEL_SIZE], xmm3
        
        ; Quiero incrementar i y j
        ; los j-es serían del "ciclo intero", mientras que los i-es del "externo"
        ; Para incrementar los indices mod s, incremento y después comparo 
        ; con s. Si es mayor, entonces lo vuelvo a 0 (i.e wraparound).
        ; Tengo que incrementar los i solo cuando hacen wraparound los j.

        ; Tengo
        ;   ecx = min{size, height}
        ;   edx = min{size, width}

        ; Incremento j
        add r14, 2      ; j += 2
        ; Lo reseteo si se pasó, mod con el mínimo entre width y size, en rbx
        ; Por lo general va a ser size entonces por conveniencia lo comento así
        cmp r14, rbx    ; cmp j, size
        jb .dont_reset_col
        xor r14, r14    ; j = 0
        .dont_reset_col:

        ; Incremento i, solo debería hacerlo si llegue al final de la fila
        ; Avanzo la cantidad de bytes leidos de la columna actual
        add r9, 8           ; col += 2 * PIXEL_SIZE = 8
        ; Si pase el final, lo vuelvo a 0 e incremento i
        cmp r9, r8          ; cmp bytes_row_actual src_row_size
        jb .dont_inc_row
        xor r9, r9          ; bytes_row_actual = 0
        inc r13             ; i++
        ; Lo reseteo si se pasó, mod con el minimo entre height y size, en r12
        cmp r13, r12        ; cmp i, size
        jb .dont_inc_row
        xor r13, r13
        .dont_inc_row:

        ; Avanzo el offset
        add r10, 2             ; offset += 2 (leo de a dos pixeles)

        ; Si no termine, sigo ciclando
        cmp r10, r11        ; cmp offset, max_offset
        jne .loop

    ; Hago free de lo precalculado
    mov rdi, r15
    call free

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
ret

