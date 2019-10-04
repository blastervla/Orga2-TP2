section .rodata
    edges: TIMES 8 db 255
section .text
global Bordes_asm

Bordes_asm:

    push r12
    push r13
    push r14

    mov ecx, ecx
    mov rax, rcx        ; rax = 0x00000000 | height
    mov edx, edx        ; rdx = 0x00000000 | width
    mov r8d, r8d        ; r8  = 0x00000000 | src_row_size
;   Le decrementamos uno porque queremos recorrer hasta la anteúltima fila.
;   Seguimos teneiendo que rax = 8*k pues width es multiplo de 8
    dec rax             ; rax = width - 1
    mul rdx             ; rax = width * (height - 1) = width * height - width

    lea r10, [rdi]              ; r10 --> (-1,-1) | (0,-1) | (1,-1)
    lea r11, [rdi + r8]         ; r11 --> (-1, 0) | (0, 0) | (1, 0)
    lea r12, [rdi + r8*2]       ; r12 --> (-1, 1) | (0, 1) | (1, 1)
    lea r13, [rsi + r8]         ; Donde (0, 0) es el pixel que estamos
    lea r14, [rdi + rax - 32]   ; procesando.
                                ; Vamos a hacer la última iteración aparte pues
    pxor xmm15, xmm15           ; si no lo hacemos, estamos haciendo un invalid
                                ; read cuando accedemos a r12.

    cmp rcx, 2      ; Caso borde donde solo hay menos de 3 filas. Las posiciónes
    jle .edges   ; apuntadas por r12 y r11 están fuera de rango.
    .loop:
        cmp r11, r14
        jge .end_loop

        movq xmm1, [r10]        ; xmm1 : ↖ - Esquina superior izquierda.
        movq xmm2, [r10 + 1]    ; xmm2 : ^ - Medio superior.
        movq xmm3, [r10 + 2]    ; xmm3 : ↗ - Esquina superior derecha.
        movq xmm4, [r11]        ; xmm4 : < - Medio lateral izquierdo.
        movq xmm5, [r11 + 2]    ; xmm5 : > - Medio lateral derecho.
        movq xmm6, [r12]        ; xmm6 : ↙ - Esquina inferior izquierda.
        movq xmm7, [r12 + 1]    ; xmm7 : v - Medio inferior.
        movq xmm8, [r12 + 2]    ; xmm8 : ↘ - Esquina inferior derecha.

        movdqu xmm9, xmm3       ; Copiamos xmm3, xmm8 pues los tenemos
        movdqu xmm10, xmm8      ; que usar para el calculo de Total_Gy.

        punpcklbw xmm1, xmm15   ; xmm1[31:0] = 0x00 | ↖₁ | 0x00 | ↖₀
        punpcklbw xmm3, xmm15   ; xmm3[31:0] = 0x00 | ↗₁ | 0x00 | ↗₀
        psubw xmm3, xmm1        ; xmm3[31:0] = ↗₁ - ↖₁ | ↗₀ - ↖₀

        punpcklbw xmm6, xmm15   ; xmm6[31:0] = 0x00 | ↙₁ | 0x00 | ↙₀
        punpcklbw xmm8, xmm15   ; xmm8[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm8, xmm6        ; xmm8[31:0] = ↘₁ - ↙₁ | ↘₀ - ↙₀

        punpcklbw xmm4, xmm15   ; xmm4[31:0] = 0x00 | <--₁ | 0x00 | <--₀
        punpcklbw xmm5, xmm15   ; xmm5[31:0] = 0x00 | -->₁ | 0x00 | -->₀
        psubw xmm5, xmm4        ; xmm5[31:0] = -->₁ - <--₁ | -->₀ - <--₀
        psllw xmm5, 1           ; xmm5[31:0] = 2*(-->₁ - <--₁) | 2*(-->₀ - <--₀)

        paddw xmm3, xmm8
        paddw xmm3, xmm5

        pabsw xmm3, xmm3
        movdqu xmm0, xmm3      

        psubw xmm6, xmm1        ; xmm6[31:0] = ↙₁ - ↖₁ | ↙₀ - ↖₀

        punpcklbw xmm9, xmm15   ; xmm3[31:0]  = 0x00 | ↗₁ | 0x00 | ↗₀
        punpcklbw xmm10, xmm15  ; xmm10[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm10, xmm9       ; xmm10[31:0] = ↘₁ - ↗₁ | ↘₀ - ↗₀

        punpcklbw xmm2, xmm15   ; xmm2[31:0] = 0x00 | ^₁ | 0x00 | ^₀
        punpcklbw xmm7, xmm15   ; xmm7[31:0] = 0x00 | v₁ | 0x00 | v₀
        psubw xmm7, xmm2        ; xmm7[31:0] = v₁ - ^₁ | v₀ - ^₀
        psllw xmm7, 1           ; xmm7[31:0] = 2*(v₁ - ^₁) | 2*(v₀ - ^₀)

        paddw xmm6, xmm10
        paddw xmm6, xmm7

        pabsw xmm6, xmm6
        
        paddw xmm0, xmm6
        packuswb xmm0, xmm0

        movq [r13 + 1], xmm0

        add r13, 8
        add r12, 8
        add r11, 8
        add r10, 8

        movq xmm1, [r10]        ; xmm1 : ↖ - Esquina superior izquierda.
        movq xmm2, [r10 + 1]    ; xmm2 : ^ - Medio superior.
        movq xmm3, [r10 + 2]    ; xmm3 : ↗ - Esquina superior derecha.
        movq xmm4, [r11]        ; xmm4 : < - Medio lateral izquierdo.
        movq xmm5, [r11 + 2]    ; xmm5 : > - Medio lateral derecho.
        movq xmm6, [r12]        ; xmm6 : ↙ - Esquina inferior izquierda.
        movq xmm7, [r12 + 1]    ; xmm7 : v - Medio inferior.
        movq xmm8, [r12 + 2]    ; xmm8 : ↘ - Esquina inferior derecha.

        movdqu xmm9, xmm3       ; Copiamos xmm3, xmm8 pues los tenemos
        movdqu xmm10, xmm8      ; que usar para el calculo de Total_Gy.

        punpcklbw xmm1, xmm15   ; xmm1[31:0] = 0x00 | ↖₁ | 0x00 | ↖₀
        punpcklbw xmm3, xmm15   ; xmm3[31:0] = 0x00 | ↗₁ | 0x00 | ↗₀
        psubw xmm3, xmm1        ; xmm3[31:0] = ↗₁ - ↖₁ | ↗₀ - ↖₀

        punpcklbw xmm6, xmm15   ; xmm6[31:0] = 0x00 | ↙₁ | 0x00 | ↙₀
        punpcklbw xmm8, xmm15   ; xmm8[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm8, xmm6        ; xmm8[31:0] = ↘₁ - ↙₁ | ↘₀ - ↙₀

        punpcklbw xmm4, xmm15   ; xmm4[31:0] = 0x00 | <--₁ | 0x00 | <--₀
        punpcklbw xmm5, xmm15   ; xmm5[31:0] = 0x00 | -->₁ | 0x00 | -->₀
        psubw xmm5, xmm4        ; xmm5[31:0] = -->₁ - <--₁ | -->₀ - <--₀
        psllw xmm5, 1           ; xmm5[31:0] = 2*(-->₁ - <--₁) | 2*(-->₀ - <--₀)

        paddw xmm3, xmm8
        paddw xmm3, xmm5

        pabsw xmm3, xmm3
        movdqu xmm0, xmm3      

        psubw xmm6, xmm1        ; xmm6[31:0] = ↙₁ - ↖₁ | ↙₀ - ↖₀

        punpcklbw xmm9, xmm15   ; xmm3[31:0]  = 0x00 | ↗₁ | 0x00 | ↗₀
        punpcklbw xmm10, xmm15  ; xmm10[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm10, xmm9       ; xmm10[31:0] = ↘₁ - ↗₁ | ↘₀ - ↗₀

        punpcklbw xmm2, xmm15   ; xmm2[31:0] = 0x00 | ^₁ | 0x00 | ^₀
        punpcklbw xmm7, xmm15   ; xmm7[31:0] = 0x00 | v₁ | 0x00 | v₀
        psubw xmm7, xmm2        ; xmm7[31:0] = v₁ - ^₁ | v₀ - ^₀
        psllw xmm7, 1           ; xmm7[31:0] = 2*(v₁ - ^₁) | 2*(v₀ - ^₀)

        paddw xmm6, xmm10
        paddw xmm6, xmm7

        pabsw xmm6, xmm6
        
        paddw xmm0, xmm6
        packuswb xmm0, xmm0

        movq [r13 + 1], xmm0

        add r13, 8
        add r12, 8
        add r11, 8
        add r10, 8

        movq xmm1, [r10]        ; xmm1 : ↖ - Esquina superior izquierda.
        movq xmm2, [r10 + 1]    ; xmm2 : ^ - Medio superior.
        movq xmm3, [r10 + 2]    ; xmm3 : ↗ - Esquina superior derecha.
        movq xmm4, [r11]        ; xmm4 : < - Medio lateral izquierdo.
        movq xmm5, [r11 + 2]    ; xmm5 : > - Medio lateral derecho.
        movq xmm6, [r12]        ; xmm6 : ↙ - Esquina inferior izquierda.
        movq xmm7, [r12 + 1]    ; xmm7 : v - Medio inferior.
        movq xmm8, [r12 + 2]    ; xmm8 : ↘ - Esquina inferior derecha.

        movdqu xmm9, xmm3       ; Copiamos xmm3, xmm8 pues los tenemos
        movdqu xmm10, xmm8      ; que usar para el calculo de Total_Gy.

        punpcklbw xmm1, xmm15   ; xmm1[31:0] = 0x00 | ↖₁ | 0x00 | ↖₀
        punpcklbw xmm3, xmm15   ; xmm3[31:0] = 0x00 | ↗₁ | 0x00 | ↗₀
        psubw xmm3, xmm1        ; xmm3[31:0] = ↗₁ - ↖₁ | ↗₀ - ↖₀

        punpcklbw xmm6, xmm15   ; xmm6[31:0] = 0x00 | ↙₁ | 0x00 | ↙₀
        punpcklbw xmm8, xmm15   ; xmm8[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm8, xmm6        ; xmm8[31:0] = ↘₁ - ↙₁ | ↘₀ - ↙₀

        punpcklbw xmm4, xmm15   ; xmm4[31:0] = 0x00 | <--₁ | 0x00 | <--₀
        punpcklbw xmm5, xmm15   ; xmm5[31:0] = 0x00 | -->₁ | 0x00 | -->₀
        psubw xmm5, xmm4        ; xmm5[31:0] = -->₁ - <--₁ | -->₀ - <--₀
        psllw xmm5, 1           ; xmm5[31:0] = 2*(-->₁ - <--₁) | 2*(-->₀ - <--₀)

        paddw xmm3, xmm8
        paddw xmm3, xmm5

        pabsw xmm3, xmm3
        movdqu xmm0, xmm3      

        psubw xmm6, xmm1        ; xmm6[31:0] = ↙₁ - ↖₁ | ↙₀ - ↖₀

        punpcklbw xmm9, xmm15   ; xmm3[31:0]  = 0x00 | ↗₁ | 0x00 | ↗₀
        punpcklbw xmm10, xmm15  ; xmm10[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm10, xmm9       ; xmm10[31:0] = ↘₁ - ↗₁ | ↘₀ - ↗₀

        punpcklbw xmm2, xmm15   ; xmm2[31:0] = 0x00 | ^₁ | 0x00 | ^₀
        punpcklbw xmm7, xmm15   ; xmm7[31:0] = 0x00 | v₁ | 0x00 | v₀
        psubw xmm7, xmm2        ; xmm7[31:0] = v₁ - ^₁ | v₀ - ^₀
        psllw xmm7, 1           ; xmm7[31:0] = 2*(v₁ - ^₁) | 2*(v₀ - ^₀)

        paddw xmm6, xmm10
        paddw xmm6, xmm7

        pabsw xmm6, xmm6
        
        paddw xmm0, xmm6
        packuswb xmm0, xmm0

        movq [r13 + 1], xmm0

        add r13, 8
        add r12, 8
        add r11, 8
        add r10, 8

        movq xmm1, [r10]        ; xmm1 : ↖ - Esquina superior izquierda.
        movq xmm2, [r10 + 1]    ; xmm2 : ^ - Medio superior.
        movq xmm3, [r10 + 2]    ; xmm3 : ↗ - Esquina superior derecha.
        movq xmm4, [r11]        ; xmm4 : < - Medio lateral izquierdo.
        movq xmm5, [r11 + 2]    ; xmm5 : > - Medio lateral derecho.
        movq xmm6, [r12]        ; xmm6 : ↙ - Esquina inferior izquierda.
        movq xmm7, [r12 + 1]    ; xmm7 : v - Medio inferior.
        movq xmm8, [r12 + 2]    ; xmm8 : ↘ - Esquina inferior derecha.

        movdqu xmm9, xmm3       ; Copiamos xmm3, xmm8 pues los tenemos
        movdqu xmm10, xmm8      ; que usar para el calculo de Total_Gy.

        punpcklbw xmm1, xmm15   ; xmm1[31:0] = 0x00 | ↖₁ | 0x00 | ↖₀
        punpcklbw xmm3, xmm15   ; xmm3[31:0] = 0x00 | ↗₁ | 0x00 | ↗₀
        psubw xmm3, xmm1        ; xmm3[31:0] = ↗₁ - ↖₁ | ↗₀ - ↖₀

        punpcklbw xmm6, xmm15   ; xmm6[31:0] = 0x00 | ↙₁ | 0x00 | ↙₀
        punpcklbw xmm8, xmm15   ; xmm8[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm8, xmm6        ; xmm8[31:0] = ↘₁ - ↙₁ | ↘₀ - ↙₀

        punpcklbw xmm4, xmm15   ; xmm4[31:0] = 0x00 | <--₁ | 0x00 | <--₀
        punpcklbw xmm5, xmm15   ; xmm5[31:0] = 0x00 | -->₁ | 0x00 | -->₀
        psubw xmm5, xmm4        ; xmm5[31:0] = -->₁ - <--₁ | -->₀ - <--₀
        psllw xmm5, 1           ; xmm5[31:0] = 2*(-->₁ - <--₁) | 2*(-->₀ - <--₀)

        paddw xmm3, xmm8
        paddw xmm3, xmm5

        pabsw xmm3, xmm3
        movdqu xmm0, xmm3      

        psubw xmm6, xmm1        ; xmm6[31:0] = ↙₁ - ↖₁ | ↙₀ - ↖₀

        punpcklbw xmm9, xmm15   ; xmm3[31:0]  = 0x00 | ↗₁ | 0x00 | ↗₀
        punpcklbw xmm10, xmm15  ; xmm10[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm10, xmm9       ; xmm10[31:0] = ↘₁ - ↗₁ | ↘₀ - ↗₀

        punpcklbw xmm2, xmm15   ; xmm2[31:0] = 0x00 | ^₁ | 0x00 | ^₀
        punpcklbw xmm7, xmm15   ; xmm7[31:0] = 0x00 | v₁ | 0x00 | v₀
        psubw xmm7, xmm2        ; xmm7[31:0] = v₁ - ^₁ | v₀ - ^₀
        psllw xmm7, 1           ; xmm7[31:0] = 2*(v₁ - ^₁) | 2*(v₀ - ^₀)

        paddw xmm6, xmm10
        paddw xmm6, xmm7

        pabsw xmm6, xmm6
        
        paddw xmm0, xmm6
        packuswb xmm0, xmm0

        movq [r13 + 1], xmm0

        add r13, 8
        add r12, 8
        add r11, 8
        add r10, 8

        jmp .loop

    .end_loop:
        movq xmm1, [r10]        ; xmm1 : ↖ - Esquina superior izquierda.
        movq xmm2, [r10 + 1]    ; xmm2 : ^ - Medio superior.
        movq xmm3, [r10 + 2]    ; xmm3 : ↗ - Esquina superior derecha.
        movq xmm4, [r11]        ; xmm4 : < - Medio lateral izquierdo.
        movq xmm5, [r11 + 2]    ; xmm5 : > - Medio lateral derecho.
        movq xmm6, [r12]        ; xmm6 : ↙ - Esquina inferior izquierda.
        movq xmm7, [r12 + 1]    ; xmm7 : v - Medio inferior.
        movq xmm8, [r12 + 2]    ; xmm8 : ↘ - Esquina inferior derecha.

        movdqu xmm9, xmm3       ; Copiamos xmm3, xmm8 pues los tenemos
        movdqu xmm10, xmm8      ; que usar para el calculo de Total_Gy.

        punpcklbw xmm1, xmm15   ; xmm1[31:0] = 0x00 | ↖₁ | 0x00 | ↖₀
        punpcklbw xmm3, xmm15   ; xmm3[31:0] = 0x00 | ↗₁ | 0x00 | ↗₀
        psubw xmm3, xmm1        ; xmm3[31:0] = ↗₁ - ↖₁ | ↗₀ - ↖₀

        punpcklbw xmm6, xmm15   ; xmm6[31:0] = 0x00 | ↙₁ | 0x00 | ↙₀
        punpcklbw xmm8, xmm15   ; xmm8[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm8, xmm6        ; xmm8[31:0] = ↘₁ - ↙₁ | ↘₀ - ↙₀

        punpcklbw xmm4, xmm15   ; xmm4[31:0] = 0x00 | <--₁ | 0x00 | <--₀
        punpcklbw xmm5, xmm15   ; xmm5[31:0] = 0x00 | -->₁ | 0x00 | -->₀
        psubw xmm5, xmm4        ; xmm5[31:0] = -->₁ - <--₁ | -->₀ - <--₀
        psllw xmm5, 1           ; xmm5[31:0] = 2*(-->₁ - <--₁) | 2*(-->₀ - <--₀)

        paddw xmm3, xmm8
        paddw xmm3, xmm5

        pabsw xmm3, xmm3
        movdqu xmm0, xmm3      

        psubw xmm6, xmm1        ; xmm6[31:0] = ↙₁ - ↖₁ | ↙₀ - ↖₀

        punpcklbw xmm9, xmm15   ; xmm3[31:0]  = 0x00 | ↗₁ | 0x00 | ↗₀
        punpcklbw xmm10, xmm15  ; xmm10[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm10, xmm9       ; xmm10[31:0] = ↘₁ - ↗₁ | ↘₀ - ↗₀

        punpcklbw xmm2, xmm15   ; xmm2[31:0] = 0x00 | ^₁ | 0x00 | ^₀
        punpcklbw xmm7, xmm15   ; xmm7[31:0] = 0x00 | v₁ | 0x00 | v₀
        psubw xmm7, xmm2        ; xmm7[31:0] = v₁ - ^₁ | v₀ - ^₀
        psllw xmm7, 1           ; xmm7[31:0] = 2*(v₁ - ^₁) | 2*(v₀ - ^₀)

        paddw xmm6, xmm10
        paddw xmm6, xmm7

        pabsw xmm6, xmm6
        
        paddw xmm0, xmm6
        packuswb xmm0, xmm0

        movq [r13 + 1], xmm0

        add r13, 8
        add r12, 8
        add r11, 8
        add r10, 8

        movq xmm1, [r10]        ; xmm1 : ↖ - Esquina superior izquierda.
        movq xmm2, [r10 + 1]    ; xmm2 : ^ - Medio superior.
        movq xmm3, [r10 + 2]    ; xmm3 : ↗ - Esquina superior derecha.
        movq xmm4, [r11]        ; xmm4 : < - Medio lateral izquierdo.
        movq xmm5, [r11 + 2]    ; xmm5 : > - Medio lateral derecho.
        movq xmm6, [r12]        ; xmm6 : ↙ - Esquina inferior izquierda.
        movq xmm7, [r12 + 1]    ; xmm7 : v - Medio inferior.
        movq xmm8, [r12 + 2]    ; xmm8 : ↘ - Esquina inferior derecha.

        movdqu xmm9, xmm3       ; Copiamos xmm3, xmm8 pues los tenemos
        movdqu xmm10, xmm8      ; que usar para el calculo de Total_Gy.

        punpcklbw xmm1, xmm15   ; xmm1[31:0] = 0x00 | ↖₁ | 0x00 | ↖₀
        punpcklbw xmm3, xmm15   ; xmm3[31:0] = 0x00 | ↗₁ | 0x00 | ↗₀
        psubw xmm3, xmm1        ; xmm3[31:0] = ↗₁ - ↖₁ | ↗₀ - ↖₀

        punpcklbw xmm6, xmm15   ; xmm6[31:0] = 0x00 | ↙₁ | 0x00 | ↙₀
        punpcklbw xmm8, xmm15   ; xmm8[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm8, xmm6        ; xmm8[31:0] = ↘₁ - ↙₁ | ↘₀ - ↙₀

        punpcklbw xmm4, xmm15   ; xmm4[31:0] = 0x00 | <--₁ | 0x00 | <--₀
        punpcklbw xmm5, xmm15   ; xmm5[31:0] = 0x00 | -->₁ | 0x00 | -->₀
        psubw xmm5, xmm4        ; xmm5[31:0] = -->₁ - <--₁ | -->₀ - <--₀
        psllw xmm5, 1           ; xmm5[31:0] = 2*(-->₁ - <--₁) | 2*(-->₀ - <--₀)

        paddw xmm3, xmm8
        paddw xmm3, xmm5

        pabsw xmm3, xmm3
        movdqu xmm0, xmm3      

        psubw xmm6, xmm1        ; xmm6[31:0] = ↙₁ - ↖₁ | ↙₀ - ↖₀

        punpcklbw xmm9, xmm15   ; xmm3[31:0]  = 0x00 | ↗₁ | 0x00 | ↗₀
        punpcklbw xmm10, xmm15  ; xmm10[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm10, xmm9       ; xmm10[31:0] = ↘₁ - ↗₁ | ↘₀ - ↗₀

        punpcklbw xmm2, xmm15   ; xmm2[31:0] = 0x00 | ^₁ | 0x00 | ^₀
        punpcklbw xmm7, xmm15   ; xmm7[31:0] = 0x00 | v₁ | 0x00 | v₀
        psubw xmm7, xmm2        ; xmm7[31:0] = v₁ - ^₁ | v₀ - ^₀
        psllw xmm7, 1           ; xmm7[31:0] = 2*(v₁ - ^₁) | 2*(v₀ - ^₀)

        paddw xmm6, xmm10
        paddw xmm6, xmm7

        pabsw xmm6, xmm6
        
        paddw xmm0, xmm6
        packuswb xmm0, xmm0

        movq [r13 + 1], xmm0

        add r13, 8
        add r12, 8
        add r11, 8
        add r10, 8

        movq xmm1, [r10]        ; xmm1 : ↖ - Esquina superior izquierda.
        movq xmm2, [r10 + 1]    ; xmm2 : ^ - Medio superior.
        movq xmm3, [r10 + 2]    ; xmm3 : ↗ - Esquina superior derecha.
        movq xmm4, [r11]        ; xmm4 : < - Medio lateral izquierdo.
        movq xmm5, [r11 + 2]    ; xmm5 : > - Medio lateral derecho.
        movq xmm6, [r12]        ; xmm6 : ↙ - Esquina inferior izquierda.
        movq xmm7, [r12 + 1]    ; xmm7 : v - Medio inferior.
        movq xmm8, [r12 + 2]    ; xmm8 : ↘ - Esquina inferior derecha.

        movdqu xmm9, xmm3       ; Copiamos xmm3, xmm8 pues los tenemos
        movdqu xmm10, xmm8      ; que usar para el calculo de Total_Gy.

        punpcklbw xmm1, xmm15   ; xmm1[31:0] = 0x00 | ↖₁ | 0x00 | ↖₀
        punpcklbw xmm3, xmm15   ; xmm3[31:0] = 0x00 | ↗₁ | 0x00 | ↗₀
        psubw xmm3, xmm1        ; xmm3[31:0] = ↗₁ - ↖₁ | ↗₀ - ↖₀

        punpcklbw xmm6, xmm15   ; xmm6[31:0] = 0x00 | ↙₁ | 0x00 | ↙₀
        punpcklbw xmm8, xmm15   ; xmm8[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm8, xmm6        ; xmm8[31:0] = ↘₁ - ↙₁ | ↘₀ - ↙₀

        punpcklbw xmm4, xmm15   ; xmm4[31:0] = 0x00 | <--₁ | 0x00 | <--₀
        punpcklbw xmm5, xmm15   ; xmm5[31:0] = 0x00 | -->₁ | 0x00 | -->₀
        psubw xmm5, xmm4        ; xmm5[31:0] = -->₁ - <--₁ | -->₀ - <--₀
        psllw xmm5, 1           ; xmm5[31:0] = 2*(-->₁ - <--₁) | 2*(-->₀ - <--₀)

        paddw xmm3, xmm8
        paddw xmm3, xmm5

        pabsw xmm3, xmm3
        movdqu xmm0, xmm3      

        psubw xmm6, xmm1        ; xmm6[31:0] = ↙₁ - ↖₁ | ↙₀ - ↖₀

        punpcklbw xmm9, xmm15   ; xmm3[31:0]  = 0x00 | ↗₁ | 0x00 | ↗₀
        punpcklbw xmm10, xmm15  ; xmm10[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm10, xmm9       ; xmm10[31:0] = ↘₁ - ↗₁ | ↘₀ - ↗₀

        punpcklbw xmm2, xmm15   ; xmm2[31:0] = 0x00 | ^₁ | 0x00 | ^₀
        punpcklbw xmm7, xmm15   ; xmm7[31:0] = 0x00 | v₁ | 0x00 | v₀
        psubw xmm7, xmm2        ; xmm7[31:0] = v₁ - ^₁ | v₀ - ^₀
        psllw xmm7, 1           ; xmm7[31:0] = 2*(v₁ - ^₁) | 2*(v₀ - ^₀)

        paddw xmm6, xmm10
        paddw xmm6, xmm7

        pabsw xmm6, xmm6
        
        paddw xmm0, xmm6
        packuswb xmm0, xmm0

        movq [r13 + 1], xmm0

        add r13, 8
        add r12, 8
        add r11, 8
        add r10, 8

; ==============================================================================
        movq xmm1, [r10]        ; Ultimos 8 pixeles a procear.
        movq xmm4, [r11]        ; r10 -> fila n-2 : ____ | ____ | ... | ____
        movq xmm6, [r12]        ; r11 -> fila n-1 : ____ | ____ | ... | ____
                                ; r12 -> fila n   : ____ | ____ | ... | ____
        movdqu xmm2, xmm1       ; xmm2[63:0] = p_7 | p_6 | p_5 | p_4 | ... | p_0
        psrldq xmm2, 1          ; xmm2[63:0] = ___ | p_7 | p_6 | p_5 | ... | p_1
        movdqu xmm3, xmm1       
        psrldq xmm3, 2          ; xmm3[63:0] = ___ | ___ | p_7 | p_6 | ... | p_2

        movdqu xmm5, xmm4       ; xmm5[63:0] = q_7 | q_6 | q_5 | q_4 | ... | q_0
        psrldq xmm5, 2          ; xmm5[63:0] = ___ | ___ | q_7 | q_6 | ... | q_2

        movdqu xmm7, xmm6       ; xmm7[63:0] = r_7 | r_6 | r_5 | r_4 | ... | r_0
        psrldq xmm7, 1          ; xmm7[63:0] = ___ | r_7 | r_6 | r_5 | ... | r_1
        movdqu xmm8, xmm6
        psrldq xmm8, 2          ; xmm8[63:0] = ___ | ___ | r_7 | r_6 | ... | r_2
;       Ahora operamos de la misma manera que lo hicimos arriba. Notemos que,
;       aunque hicimos el shift necesario para que los pixeles vecinos nos
;       queden alineados, esto va a hacer que escribamos "basura" en la
;       fila próxima. Esto no es un problema ya es la última fila y la debemos
;       rellenar al final del procesar la imagen.
        movdqu xmm9, xmm3
        movdqu xmm10, xmm8

        punpcklbw xmm1, xmm15   ; xmm1[31:0] = 0x00 | ↖₁ | 0x00 | ↖₀
        punpcklbw xmm3, xmm15   ; xmm3[31:0] = 0x00 | ↗₁ | 0x00 | ↗₀
        psubw xmm3, xmm1        ; xmm3[31:0] = ↗₁ - ↖₁ | ↗₀ - ↖₀

        punpcklbw xmm6, xmm15   ; xmm6[31:0] = 0x00 | ↙₁ | 0x00 | ↙₀
        punpcklbw xmm8, xmm15   ; xmm8[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm8, xmm6        ; xmm8[31:0] = ↘₁ - ↙₁ | ↘₀ - ↙₀

        punpcklbw xmm4, xmm15   ; xmm4[31:0] = 0x00 | <--₁ | 0x00 | <--₀
        punpcklbw xmm5, xmm15   ; xmm5[31:0] = 0x00 | -->₁ | 0x00 | -->₀
        psubw xmm5, xmm4        ; xmm5[31:0] = -->₁ - <--₁ | -->₀ - <--₀
        psllw xmm5, 1           ; xmm5[31:0] = 2*(-->₁ - <--₁) | 2*(-->₀ - <--₀)

        paddw xmm3, xmm8
        paddw xmm3, xmm5

        pabsw xmm3, xmm3
        movdqu xmm0, xmm3

        psubw xmm6, xmm1        ; xmm6[31:0] = ↙₁ - ↖₁ | ↙₀ - ↖₀

        punpcklbw xmm9, xmm15   ; xmm3[31:0]  = 0x00 | ↗₁ | 0x00 | ↗₀
        punpcklbw xmm10, xmm15  ; xmm10[31:0] = 0x00 | ↘₁ | 0x00 | ↘₀
        psubw xmm10, xmm9       ; xmm10[31:0] = ↘₁ - ↗₁ | ↘₀ - ↗₀

        punpcklbw xmm2, xmm15   ; xmm2[31:0] = 0x00 | ^₁ | 0x00 | ^₀
        punpcklbw xmm7, xmm15   ; xmm7[31:0] = 0x00 | v₁ | 0x00 | v₀
        psubw xmm7, xmm2        ; xmm7[31:0] = v₁ - ^₁ | v₀ - ^₀
        psllw xmm7, 1           ; xmm7[31:0] = 2*(v₁ - ^₁) | 2*(v₀ - ^₀)

        paddw xmm6, xmm10
        paddw xmm6, xmm7

        pabsw xmm6, xmm6
        paddw xmm0, xmm6
        packuswb xmm0, xmm0

        movq [r13 + 1], xmm0

; -------------- BORDES ------------
    .edges:
        xor r10, r10                        
        movq xmm0, [edges]

    .horizontal:
        cmp r10, r8
        je .end_horizontal
        
        lea r11, [r10 + rax]
        
        movq [rsi + r10], xmm0
        movq [rsi + r11], xmm0

        add r10, 8
        jmp .horizontal

    .end_horizontal:
        lea r12, [rsi + rax - 1]
        lea rsi, [rsi + r8 - 1]
        mov r13w, [edges]

    .vertical:
        cmp rsi, r12
        je .end

        mov [rsi], r13w

        lea rsi, [rsi + r8]
        jmp .vertical

    .end:
        mov [rsi], r13w

        pop r14
        pop r13
        pop r12

        ret