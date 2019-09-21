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
SHUFB_MASK:     dd 0x00000000, 0x01010101, 0xFFFFFFFF, 0xFFFFFFFF
;                    a g r b     a g r b  
SET_ALPHA:      dd 0xFF000000, 0xFF000000   ; Poner en 255 el canal alpha 

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

    ; Inicializo los offsets
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
        ;   ii_0 = ((s/2)-(i_0%s)) > 0 ? ((s/2)-(i_0%s)) : -((s/2)-(i_0%s))
        ;        = abs(s/2 - i_0%s)
        ;   jj_0 = abs(s/2 - j_0%s)
        ;   ii_1 = abs(s/2 - i_1%s)
        ;   jj_1 = abs(s/2 - j_1%s)
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
        ; xmm2 = abs(s/2 - i_0%s) | abs(s/2 - j_0%s) | abs(s/2 - i_1%s) | abs(s/2 - j_0%s)
        ;      = ii_0 | jj_0 | ii_1 | jj_1

        ; Quiero calcular los x-es
        ;
        ;   x_0 = (ii_0+jj_0-(s/2)) > (s/16) ? 0 : 2*(ii_0+jj_0-(s/2))
        ;   x_1 = (ii_1+jj_1-(s/2)) > (s/16) ? 0 : 2*(ii_1+jj_1-(s/2))
        ;
        ; Y noto que es lo mismo que multiplicar por dos siempre, y ver
        ;
        ;   x_0 = 2*(ii_0+jj_0-(s/2)) > (s/8) ? 0 : 2*(ii_0+jj_0-(s/2))
        ;   x_1 = 2*(ii_1+jj_1-(s/2)) > (s/8) ? 0 : 2*(ii_1+jj_1-(s/2))

        phaddd xmm2, xmm2   ; xmm2 =    ii_0 + jj_0    |    ii_1 + jj_1    |    ii_0 + jj_0    | ii_1 + jj_1
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
        
        ; Quiero sumarlos a los canales de sus respectivos pixeles,
        ; pero al levantarlos tienen la siguiente pinta (donde lo menos
        ; significativo está a la izquierda y lo mas a la derecha) 
        ;
        ;   xmm{x} =           p_0          ||          p_1          || ... || ... 
        ;          =  b_0 | g_0 | r_0 | a_0 || b_1 | g_1 | r_1 | a_1 || ... || ...
        ;
        ; Pero cada canal es un byte, y mis x son de 4 bytes
        ; Las empaqueto dos veces para llevarlas a 1 byte c/u

        ; xmm2 = x_0 | x_1 | x_0 | x_1
        packssdw xmm2, xmm2 ; xmm2 = x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1
        packsswb xmm2, xmm2 ; xmm2 = x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1
        ; Pero están desordenados, necesito agruparlos en la parte baja según
        ; a que pixel tienen que sumarse
        movq xmm3, [SHUFB_MASK] ; TODO: Podría estar precargada
                            ;        b_0 | g_0 | r_0 | a_0 | b_1 | g_1 | r_1 | a_1 || ... || ... ||             
                            ; xmm2 = x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1 || ... || ... ||
        pshufb xmm2, xmm3   ; xmm2 = x_0 | x_0 | x_0 | x_0 | x_1 | x_1 | x_1 | x_1 || ... || ... ||
        
        ; Pongo el canal de transparencia en 255
        movq xmm3, [SET_ALPHA]  ; TODO: Podría estar precargada
        por xmm2, xmm3      ; xmm2 = x_0 | x_0 | x_0 | FF  | x_1 | x_1 | x_1 | FF || ... || ... || 

        ; Recuerdo que
        ;
        ;   rdi = src
        ;   rsi = dst
        ;
        ; Levanto los pixeles y hago la suma con saturacion
        movq xmm3, [rdi + r10 * PIXEL_SIZE] ; xmm3 =    b_0    |    g_0    |    r_0    | a_0 |    b_1    |    g_1    |    r_1    | a_1 || ... || ... 
        paddsb xmm3, xmm2                   ; xmm3 = b_0 + x_0 | g_0 + x_0 | r_0 + x_0 | FF  | b_1 + x_1 | g_1 + x_1 | r_1 + x_1 | FF  || ... || ... 
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
        ; Solo debería hacerlo si se resetearon los j-es
        ; Tengo en xmm4 F si los j-es se pasaron y 0 sino, lo shifteo a la 
        ; izquierda así lo tengo en la posicion de los ies
                            ;    X = F si se paso y 0 sino
                            ;        i_0 | j_0 | i_1 | j_1
                            ; xmm4 =  _  |  X  |  _  |  X  
        psrldq xmm4, 4      ; xmm4 =  X  |  _  |  X  |  _

        movdqu xmm2, [INC_I]; xmm2 =  1  |  0  |  1  |  0
        pand xmm2, xmm4     ; xmm2 tiene el incr. solo si i se había pasado
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
                            
        ; Avanzo el offset
        add r10, 2             ; offset += 2 (leo de a dos pixeles)

        ; Si no termine, sigo ciclando
        cmp r10, r11        ; cmp offset, max_offset
        jne .loop

    ; Termine     
ret
