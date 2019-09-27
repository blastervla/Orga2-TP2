section .rodata
section .text

global Bordes_asm
;#define PIXEL_SIZE 1
Bordes_asm:
; rdi: unit8_t *src
; rsi: uint8_t *dst
; edx: int width
; ecx: int height
; r8d: src_row_size
; r9d: dst_row_size

    push r12
    push r13
    push r14

    ;mov r10, rdi
    ;mov r11, rsi    

    mov eax, ecx        ; eax = height
    mov eax, eax        ; rax = 0x00000000 | height
    mov edx, edx        ; rdx = 0x00000000 | width
    mov r8d, r8d        ; r8  = 0x00000000 | src_row_size
;   Le decrementamos uno porque queremos recorrer hasta la anteúltima fila.
;   Seguimos teneiendo que rax = 8*k pues width es multiplo de 8
    dec rax             ; rax = 0x00000000 | height - 1
    mul rdx             ; rax = width * (height - 1) = width * height - width
    sub rax, r8
    ;sub rax, 1
    
    lea r11, [rdi + r8 +1]
    lea r10, [r11]
    sub r10, r8
    lea r12, [r11 +r8]
    lea r13, [rsi + r8 +1]
    lea r14, [rdi + rax]        ; Define pixel_size
    
    .loop:
        cmp r11, r14
        jge .end

        
        pxor xmm15, xmm15

;       ↖ ↑ ↗  =  xmm1 xmm2 xmm3
;       ← ⋅ →  =  xmm4   0   xmm6
;       ↙ ↓ ↘  =  xmm7 xmm8 xmm9
        movq xmm1, [r10 - 1]  ; xmm1 = ↖
        movq xmm2, [r10]      ; xmm2 = ↑
        movq xmm3, [r10 + 1]  ; xmm3 = ↗
        movq xmm4, [r11 - 1]  ; xmm4 = ←
        movq xmm6, [r11 + 1]  ; xmm6 = →
        movq xmm7, [r12 - 1]  ; xmm7 = ↙
        movq xmm8, [r12]      ; xmm8 = ↓
        movq xmm9, [r12 + 1]  ; xmm9 = ↘
        movdqu xmm10, xmm3      ; xmm10 = ↗
        movdqu xmm11, xmm9      ; xmm11 = ↘
        ; Calculamos TotalGx.
        psubb xmm3, xmm1        ; xmm3[31:0] = ____ | ____ | ↗₁ - ↖₁ | ↗₀ - ↖₀
        psubb xmm9, xmm7        ; xmm9[31:0] = ____ | ____ | ↘₁ - ↙₁ | ↘₀ - ↙₀
        psubb xmm6, xmm4        ; xmm6[31:0] = ____ | ____ | →₁ - ←₁ | →₀ - ←₀

        pxor xmm14, xmm14
        pcmpgtb xmm14, xmm6
        punpcklbw xmm6, xmm14   ; xmm6[31:0] = 0xFF | →₁ - ←₁ | 0x00 | →₀ - ←₀
        psllw xmm6, 1           ; xmm6[31:0] = 2 * (→₁ - ←₁)  | 2 * (→₀ - ←₀)
        
        pxor xmm14, xmm14
        pcmpgtb xmm14, xmm3
        punpcklbw xmm3, xmm14   ; xmm3[31:0] = 0x00 | ↗₁ - ↖₁ | 0x00 | ↗₀ - ↖₀

        pxor xmm14, xmm14
        pcmpgtb xmm14, xmm9
        punpcklbw xmm9, xmm14   ; xmm9[31:0] = 0x00 | ↘₁ - ↙₁ | 0x00 | ↘₀ - ↙₀    

        paddw xmm3, xmm9        ; xmm3[15:0] = (↗₀ - ↖₀) + (↘₀ - ↙₀)
        paddw xmm3, xmm6        ; xmm3[15:0] = (↗₀ - ↖₀) + (↘₀ - ↙₀) + 2*(→₀ - ←₀)
        ;pabsw xmm3, xmm3
        movdqu xmm0, xmm3

        pcmpgtw xmm15, xmm3     ; xmm15[15:0]= xmm3[15:0] < 0? 1 : 0
        ; Tenemos en xmm15 la mascara de negativos
        ; Haciendo un and con xmm3 nos quedamos solamente los negativos.
        pand xmm3, xmm15        ; xmm3[15:0] = xmm3[15:0] < 0? xmm3[15:0] : 0
        ; Haciendo un xor invertimos los bits de los negativos.
        ; Los que no eran negativos, se quedan en 0.
        pxor xmm3, xmm15        ; xmm3[15:0] = xmm3[15:0] < 0? !xmm3[15:0] : 0
        movdqu xmm14, xmm15
        psrlw xmm14, 15         ; Ej: xmm14 = 1 | 0 | 1 | 1
        ; Sumando obtenemos el inverso aditivio de todos los negativos.
        paddw xmm3, xmm14       ; xmm3[15:0] = xmm3[15:0] < 0? -xmm3[15:0] : 0
        ;movdqu xmm14, xmm15
        ; Si hacemos un and negado entre la mascara de negativos y xmm0
        ; Obtenemos en xmm15, los positivos y 0 donde había negativos.
        pandn xmm15, xmm0
        ; Si hacemos un or contra el registro con los inversos aditivos,
        ; tenemos el resultado.
        por xmm3, xmm15         ; xmm3[15:0] = abs(xmm3[15:0])
        movdqu xmm0, xmm3
; Gy
        pxor xmm15, xmm15
        
        psubb xmm7, xmm1        ; xmm7[31:0] = ____ | ____ | ↙₁ - ↖₁ | ↙₀ - ↖₀
        psubb xmm11, xmm10      ; xmm11[31:0]= ____ | ____ | ↘₁ - ↗₁ | ↘₀ - ↗₀
        psubb xmm8, xmm2        ; xmm8[31:0] = ____ | ____ | ↓₁ - ↑₁ | ↓₀ - ↑₀
        
        pxor xmm14, xmm14
        pcmpgtb xmm14, xmm8
        punpcklbw xmm8, xmm15   ; xmm8[31:0] = 0x00 | ↓₁ - ↑₁ | 0x00 | ↓₀ - ↑₀
        psllw xmm8, 1           ; xmm8[31:0] = 2 * (↓₁ - ↑₁)  | 2 * (↓₀ - ↑₀)
        
        pxor xmm14, xmm14
        pcmpgtb xmm14, xmm7
        punpcklbw xmm7, xmm14   ; xmm7[31:0] = 0x00 | ↙₁ - ↖₁ | 0x00 | ↙₀ - ↖₀
        
        pxor xmm14, xmm14
        pcmpgtb xmm14, xmm11
        punpcklbw xmm11, xmm14  ; xmm11[31:0]= 0x00 | ↘₁ - ↗₁ | 0x00 | ↘₀ - ↗₀

        paddw xmm7, xmm11
        paddw xmm7, xmm8
        ;pabsw xmm7, xmm7

        movdqu xmm12, xmm7
        ; Generamos la mascara de los negativos para poder hacerles el
        ; valor absoluto.       ; xmm7  =   >0   |   >0   | .... |   <0  
        pcmpgtw xmm15, xmm7     ; xmm15 = 0x0000 | 0x0000 | .... | 0xFFFF 
        pand xmm7, xmm15
        pxor xmm7, xmm15
        ; Tenemos en xmm7 los negativos negados bit a bit. Hay que sumarles 1.
        movdqu xmm14, xmm15     
        psrlw xmm14, 15         ; xmm14 = 0x0000 | 0x0000 | .... | 0x0001
        paddw xmm7, xmm14       ; xmm7  =   >0   |   >0   | .... |   >0  
        pandn xmm15, xmm12
        por xmm7, xmm15

        paddw xmm0, xmm7
        packuswb xmm0, xmm0
        movd [r13], xmm0 ;!!

        add r10, 8
        add r11, 8
        add r12, 8
        add r13, 8
        jmp .loop
   .end:
        pop r14
        pop r13
        pop r12
        ret
