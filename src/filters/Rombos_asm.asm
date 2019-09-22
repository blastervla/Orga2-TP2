global Rombos_asm
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
MOD_SIZE:       dd SIZE,       SIZE,       SIZE,       SIZE         ; Máscara para hacer % size con cmp
NEG_XOR:        dd 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF   ; Máscara para negar con xor
INC_ALL:        dd 0x00000001, 0x00000001, 0x00000001, 0x00000001   ; Máscara para sumar 1 a todos

; Mascaras para operar sobre los x-es
;         xmm{x} =   b  |    g  |    r  |    a 
ALPHA:  TIMES 2 dw 0x0000, 0x0000, 0x0000, 0xFF00   ; Poner en 255 el canal alpha 

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

    ; Muevo size/2 a xmm0
    mov r10d, SIZE              ; r10 = size     
    movd xmm0, r10d             ; xmm0[31:0] = size
    ; Hago broadcast de size
    pshufd xmm0, xmm0, 0x00     ; xmm0 = size | size | size | size
    ; Divido size por 2 shifteando a la derecha
    psrld xmm0, 1               ; xmm0 = s/2  | s/2  | s/2  | s/2

    ; Muevo los índices iniciales a xmm1
    ; TODO: usar align y mvdqa
    movdqu xmm1, [INITIAL_IDXS] ; xmm1 = i_0 % s | j_0 %s | i_1 %s | j_1 % s
                                ;      =     0   |    0   |    0   |    1

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
        ; Para esto, invierto el signo en complemento a dos, es decir, 
        ; niego (xor) y luego sumo 1.
        ; Veo cuales son negativos
        pxor xmm3, xmm3     ; xmm3 = 0 | 0 | 0 | 0
        pcmpgtd xmm3, xmm2  ; xmm3[i] > xmm2[i] <=> xmm2[i] < 0
                            ; xmm3[i] = 0xFFFFFFFF si xmm2[i] < 0 (negativo)
                            ;           0x00000000 si no          (positivo)
        ; Invierto el signo de los que son negativos, a los que no, voy a estar
        ; haciendo xor con 0 y sumando 0, lo cual no los altera.
        movdqu xmm4, [NEG_XOR]  ; xmm4 = FFFFFFFF | FFFFFFFF | FFFFFFFF | FFFFFFFF
        pand xmm4, xmm3         ; xmm4[i] tiene Fs para los neg. y 0s para los pos.
        pxor xmm2, xmm4         ; xmm2[i] tiene el inverso para los negativos y lo mismo para positivos
        
        movdqu xmm4, [INC_ALL]  ; xmm4 = 1 | 1 | 1 | 1
        pand xmm4, xmm3         ; xmm4[i] tiene 1 para los neg. y 0 para los pos.
        paddd xmm2, xmm4        ; xmm2[i] tiene lo que había mas uno o lo mismo
    
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
        pcmpgtd xmm3, xmm2  ; xmm3[i] = FFFFFFFF    si s/8 > 2*(ii_x+jj_x-s/2)
                            ;           00000000    si no
        ; Tengo 0 donde quiero que quede 0 y 1 donde quiero que quede lo mismo.
        ; Con un AND logro eso
        pand xmm2, xmm3     ; xmm2[i] = 0           si era mayor a s/8
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
        pxor xmm8, xmm8                     ; xmm8[0:63] =  0  |  0  |  0  |  0  |  0  |  0  |  0  |  0
        punpcklbw xmm3, xmm8                ; xmm3 = b_0 | g_0 | r_0 | a_0 | b_1 | g_1 | r_1 | a_1
        paddsw xmm3, xmm2                   ; xmm3 = b_0 + x_0 | g_0 + x_0 | r_0 + x_0 | FF  | b_1 + x_1 | g_1 + x_1 | r_1 + x_1 | FF  || ... || ... 

        ; Pongo el canal alpha en 255
        movdqu xmm8, [ALPHA]    ; xmm8 = 0000 | 0000 | 0000 | 00FF | 0000 | 0000 | 0000 | 00FF
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
        movdqu xmm2, [INC_J]    ; xmm2 = 0 | 2 | 0 | 2
        paddd xmm1, xmm2        ; xmm1 = i_0 | j_0 + 2 | i_1 | j_1 + 2

        ; Reseteo los que se pasaron
        movdqu xmm4, [MOD_SIZE] ; xmm4 = s | s | s | s
        movdqu xmm3, xmm4       ; xmm3 = s | s | s | s

        pcmpgtd xmm4, xmm1      ; xmm4[i] = 0xFFFFFFFF si xmm1[i] < s
                                ;           0x00000000 si no
        movdqu xmm5, [NEG_XOR]  ; xmm5 = FFFFFFFF | FFFFFFFF | ... | ...
        pxor xmm4, xmm5         ; xmm4[i] = 0xFFFFFFFF si xmm1[i] >= s
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

        movdqu xmm2, [INC_I]; xmm2 =  1  |  0  |  1  |  0
        paddd xmm1, xmm2    ; xmm1 = i_0 + 1 | j_0 + 2 % s | i_1 + 1 | j_1 + 2 % s

        ; Resto size a los que se pasaron
        movdqu xmm4, [MOD_SIZE] ; xmm4 = s | s | s | s
        movdqu xmm3, xmm4       ; xmm3 = s | s | s | s

        pcmpgtd xmm4, xmm1      ; xmm4[i] = 0xFFFFFFFF si xmm1[i] < s
                                ;           0x00000000 si no
        movdqu xmm5, [NEG_XOR]  ; xmm5 = FFFFFFFF | FFFFFFFF | ... | ...
        pxor xmm4, xmm5         ; xmm4[i] = 0xFFFFFFFF si xmm1[i] >= s
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
