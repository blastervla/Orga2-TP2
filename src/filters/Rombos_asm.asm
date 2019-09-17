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

Rombos_asm:
    ; Rombos_asm(
    ;   uint8_t *src,       rdi
    ;   uint8_t *dst,       rsi
    ;   int width,          rdx
    ;   int height,         rcx
    ;   int src_row_size,   r8
    ;   int dst_row_size    r9
    ; )

    ; TODO: Short y operar de a 8 ies

    ;        for pixel 0 | for pixel 1
    ; xmm2 = size | size | size | size
    ; >>1               ; xmm2 = s/2  | s/2  | s/2  | s/2
    ; movdqu xmm0, xmm2

    ; TODO
    ; xmm1 = i_0 % s | j_0 % s | i_1 % s | j_1 % s
    ; insert / mov 
    ; shift izq 4

    ; psub xmm2, xmm1   ; xmm2 = s/2 - i_0%s | s/2 - j_0%s | s/2 - i_1%s | s/2 - j_1%s
    ; pxor xmm3, xmm3   ; xmm3 = 0 | 0 | 0 | 0
    ; pcmpgtd xmm3, xmm2 ; si xmm2[i]<0, xmm3[i]=0xFF
    
    ; Multiplico por -1 a los menores
    ;   (niego y sumo 1)
    ;   (xor con ff y add 1)
    ; A los no menores, hago xor con 00 que queda igual
    ; y sumo 0.
    
    ; niego 
    ; xormask = FFFFF....
    ; movdqu xmm4, xormask
    ; pand xmm4, xmm3
    ; pxor xmm2, xmm4

    ; sumo 1
    ; addmask = 1 | 1 | 1 | 1
    ; movdqu xmm4, addmask
    ; pand xmm4, xmm3
    ; paddd xmm2, xmm4

    ; xmm2 = ii_0 | jj_0 | ii_1 | jj_1
    ; phaddd xmm2, xmm2     ; xmm2 = ii_0 + jj_0 | ii_1 + jj_1 | ii_0 + jj_0 | ii_1 + jj_1
    ; psubd xmm2, xmm0      ; xmm2 = ii_0+jj_0 - s/2 | ... | ... | ...
    ; multiplico x2 shifteando (izq logico)
    ; xmm2 = 2*(ii_0+jj_0) - s/2 | ... | ... | ...

    ; xmm0>>2   ; xmm0 = s/8 | s/8 | s/8 | s/8
    ; pcmpgtd xmm0, xmm2 ; si xmm2[i]>s/8, xmm0[i]=0, sino 0xFF
    ; pand xmm2, xmm0
    ; tengo en 0 los mayores a size/8

    ; xmm2 = x_0 | x_1 | x_0 | x_1
    ; packusdw xmm2, xmm2   ; xmm2 = x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1
    ; packuswb xmm2, xmm2   ; xmm2 = x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1 | x_0 | x_1
    ; pshufb mask turbia    ; xmm2 =  _  |  _  |  _  |  _  |  _  |  _  |  _  |  _  | x_0 | x_0 | x_0 | x_0 | x_1 | x_1 | x_1 | x_1

    ; movdwu xmm8, src algo     ; xmm8 = _ | _ | p_0 | p_1
                                ; xmm8 = _  |  _  |  _  |  _  |  _  |  _  |  _  |  _  | b_0 | g_0 | r_0 | a_0 | b_1 | g_1 | r_1 | a_1

    ; paddusb xmm8, xmm2    ; pixeles + xs

    ; movdwu xmm8, dst algo

    ; incrementar offsets / contadores
    ; chequear condicion de salida
    ; loop        
ret
