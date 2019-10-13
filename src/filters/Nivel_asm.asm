; La estructura de pixel es:
; *----+-------------------+
; |    |                   |
; | 8b | char b            |
; |    |                   |
; +------------------------+
; |    |                   |
; | 8b | char g            |
; |    |                   |
; +------------------------+
; |    |                   |
; | 8b | char r            |
; |    |                   |
; +------------------------+
; |    |                   |
; | 8b | char a            |
; |    |                   |
; +----+-------------------+

section .text
global Nivel_asm
global Nivel_asm_mid
global Nivel_asm_low
global Nivel_asm_ultra_low
Nivel_asm:  ; RDI = pixel[][] src
            ; RSI = pixel[][] dst
            ; EDX = int width
            ; ECX = int height
            ; R8D = int src_row_size
            ; R9D = int dst_row_size
            ; [rsp + 8] = int n_index
    xor r10, r10
    mov r10d, ecx               ; R10D = height

    xor rcx, rcx                ; Limpio RCX
    mov ecx, dword[rsp + 8]     ; ECX = n_index

    mov r11, 1                  ; Preparo máscara
    shl r11, cl                 ; Shifteo n_index bits
    movq xmm1, r11              ; Meto la máscara en xmm1
    pxor xmm2, xmm2             ; Creo máscara para pshufb en xmm2
    pshufb xmm1, xmm2           ; Broadcasteo el primer byte en todos

    mov rax, r10                ; RAX = height (64 bits)
    mul rdx                     ; RAX = width * height
    mov rcx, rax                ; RCX = Cantidad total de píxeles
    shr rcx, 2                  ; Voy a levantar de a 4 píxeles, así que divido por 4
.loop:
    lea r11, [rcx * 2]                  ; R11 = RCX *2 (así rcx * 2 * 8 = rcx * 16)
    movdqu xmm0, [rdi + r11 * 8 - 16]   ; Levanto 4 píxeles de src (16 bytes)
    pand xmm0, xmm1                     ; Hago AND con la máscara
    pcmpeqb xmm0, xmm2                  ; Por cada byte, si es igual a 0...
                                        ; Entonces debo escribir 0 en ese byte. Sino, 0xFF (255)
                                        ; Para ello, necesito negar el resultado del cmp
    pcmpeqb xmm3, xmm3                  ; xmm3 = 0xFFFFFFFF...
    pxor xmm0, xmm3                     ; xmm0 = !xmm0, acá tengo los bytes que quiero asignar!
    mov eax, 0xFF000000
    movq xmm3, rax
    pshufd xmm3, xmm3, 0x00             ; xmm3 = 0x000000FF000000FF000000FF000000FF
    por xmm0, xmm3                      ; Alphas tienen que ser siempre 255
    
    movdqu [rsi + r11 * 8 - 16], xmm0   ; Almaceno los 4 píxeles en dst

    loop .loop
.end:
    ret                                 ; No' fuimo'

; ====================== NUEVO EXPERIMENTO ======================

Nivel_asm_mid:  ; RDI = pixel[][] src
                ; RSI = pixel[][] dst
                ; EDX = int width
                ; ECX = int height
                ; R8D = int src_row_size
                ; R9D = int dst_row_size
                ; [rsp + 8] = int n_index
    xor r10, r10
    mov r10d, ecx               ; R10D = height

    xor rcx, rcx                ; Limpio RCX
    mov ecx, dword[rsp + 8]     ; ECX = n_index

    mov r11, 1                  ; Preparo máscara
    shl r11, cl                 ; Shifteo n_index bits
    movq xmm1, r11              ; Meto la máscara en xmm1
    pxor xmm2, xmm2             ; Creo máscara para pshufb en xmm2
    pshufb xmm1, xmm2           ; Broadcasteo el primer byte en todos

    mov rax, r10                ; RAX = height (64 bits)
    mul rdx                     ; RAX = width * height
    mov r8, rax                 ; r8 = Cantidad total de píxeles
    shr r8, 2                   ; Voy a levantar de a 4 píxeles, así que divido por 4

    mov rax, 15
    sub al, cl
    movq xmm15, rax
.loop:
    lea r11, [r8 * 2]                  ; R11 = RCX *2 (así rcx * 2 * 8 = rcx * 16)
    movq xmm0, qword[rdi + r11 * 8 - 16] ; Levanto 2 píxeles de src (16 bytes)
    pand xmm0, xmm1                    ; Hago AND con la máscara
    movdqa xmm3, xmm0
    
    punpcklbw xmm0, xmm2
    punpcklbw xmm3, xmm2
    psllw xmm0, xmm15
    psllw xmm3, xmm15
    psraw xmm0, 15
    psraw xmm3, 15

    packuswb xmm0, xmm3

    mov eax, 0xFF000000
    movq xmm3, rax
    pshufd xmm3, xmm3, 0x00             ; xmm3 = 0x000000FF000000FF000000FF000000FF
    por xmm0, xmm3                      ; Alphas tienen que ser siempre 255
    
    movq qword[rsi + r11 * 8 - 16], xmm0 ; Almaceno los 4 píxeles en dst

    dec r8
    jnz .loop
.end:
    ret                                 ; No' fuimo'

; ====================== NUEVO EXPERIMENTO ======================

; Levantanding de a un pixel (sha fua)
; Nivel_asm_mid:  ; RDI = pixel[][] src
;                 ; RSI = pixel[][] dst
;                 ; EDX = int width
;                 ; ECX = int height
;                 ; R8D = int src_row_size
;                 ; R9D = int dst_row_size
;                 ; [rsp + 8] = int n_index
;     xor r10, r10
;     mov r10d, ecx               ; R10D = height

;     xor rcx, rcx                ; Limpio RCX
;     mov ecx, dword[rsp + 8]     ; ECX = n_index

;     mov r11, 1                  ; Preparo máscara
;     shl r11, cl                 ; Shifteo n_index bits
;     movq xmm1, r11              ; Meto la máscara en xmm1
;     pxor xmm2, xmm2             ; Creo máscara para pshufb en xmm2
;     pshufb xmm1, xmm2           ; Broadcasteo el primer byte en todos

;     mov rax, r10                ; RAX = height (64 bits)
;     mul rdx                     ; RAX = width * height
;     mov rcx, rax                ; RCX = Cantidad total de píxeles
;     shr rcx, 1                  ; Voy a levantar de a 2 píxeles, así que divido por 2
; .loop:
;     movq xmm0, qword[rdi + rcx * 8 - 8] ; Levanto 2 píxeles de src (16 bytes)
;     pand xmm0, xmm1                     ; Hago AND con la máscara
;     pcmpeqb xmm0, xmm2                  ; Por cada byte, si es igual a 0...
;                                         ; Entonces debo escribir 0 en ese byte. Sino, 0xFF (255)
;                                         ; Para ello, necesito negar el resultado del cmp
;     pcmpeqb xmm3, xmm3                  ; xmm3 = 0xFFFFFFFF...
;     pxor xmm0, xmm3                     ; xmm0 = !xmm0, acá tengo los bytes que quiero asignar!
;     mov eax, 0xFF000000
;     movq xmm3, rax
;     pshufd xmm3, xmm3, 0x00             ; xmm3 = 0x000000FF000000FF000000FF000000FF
;     por xmm0, xmm3                      ; Alphas tienen que ser siempre 255
    
;     movq qword[rsi + rcx * 8 - 8], xmm0 ; Almaceno los 4 píxeles en dst

;     loop .loop
; .end:
;     ret                                 ; No' fuimo'

; Levantanding de a un pixel (porque podemo')
Nivel_asm_low:  ; RDI = pixel[][] src
                ; RSI = pixel[][] dst
                ; EDX = int width
                ; ECX = int height
                ; R8D = int src_row_size
                ; R9D = int dst_row_size
                ; [rsp + 8] = int n_index
    xor r10, r10
    mov r10d, ecx               ; R10D = height

    xor rcx, rcx                ; Limpio RCX
    mov ecx, dword[rsp + 8]     ; ECX = n_index

    mov r11, 1                  ; Preparo máscara
    shl r11, cl                 ; Shifteo n_index bits
    movq xmm1, r11              ; Meto la máscara en xmm1
    pxor xmm2, xmm2             ; Creo máscara para pshufb en xmm2
    pshufb xmm1, xmm2           ; Broadcasteo el primer byte en todos

    mov rax, r10                ; RAX = height (64 bits)
    mul rdx                     ; RAX = width * height
    mov rcx, rax                ; RCX = Cantidad total de píxeles
.loop:
    movd xmm0, dword[rdi + rcx * 4 - 4] ; Levanto 1 píxel de src (4 bytes)
    pand xmm0, xmm1                     ; Hago AND con la máscara
    pcmpeqb xmm0, xmm2                  ; Por cada byte, si es igual a 0...
                                        ; Entonces debo escribir 0 en ese byte. Sino, 0xFF (255)
                                        ; Para ello, necesito negar el resultado del cmp
    pcmpeqb xmm3, xmm3                  ; xmm3 = 0xFFFFFFFF...
    pxor xmm0, xmm3                     ; xmm0 = !xmm0, acá tengo los bytes que quiero asignar!
    mov eax, 0xFF000000
    movq xmm3, rax
    ; pshufd xmm3, xmm3, 0x00             ; xmm3 = 0x000000FF000000FF000000FF000000FF
    por xmm0, xmm3                      ; Alphas tienen que ser siempre 255
    
    movd dword[rsi + rcx * 4 - 4], xmm0 ; Almaceno los 4 píxeles en dst

    loop .loop
.end:
    ret                                 ; No' fuimo'


; Levantanding de a un byte (seh... peor no podemos ya...)
Nivel_asm_ultra_low:    ; RDI = pixel[][] src
                        ; RSI = pixel[][] dst
                        ; EDX = int width
                        ; ECX = int height
                        ; R8D = int src_row_size
                        ; R9D = int dst_row_size
                        ; [rsp + 8] = int n_index
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    xor r12, r12
    xor r13, r13
    xor r14, r14
    xor r15, r15

    xor r10, r10
    mov r10d, ecx               ; R10D = height

    xor rcx, rcx                ; Limpio RCX
    mov ecx, dword[rsp + 48]    ; ECX = n_index

    mov r11, 1                  ; Preparo máscara
    shl r11, cl                 ; Shifteo n_index bits

    mov rax, r10                ; RAX = height (64 bits)
    mul rdx                     ; RAX = width * height
    mov r8, rax                 ; R8 = Cantidad total de píxeles

    mov rax, 7
    sub al, cl
    mov cl, al                  ; Cantidad a shiftear para llevar adelante de todo
.loop:
    mov r12b, byte[rdi + r8 * 4 - 4]       ; R
    mov r13b, byte[rdi + r8 * 4 - 3]       ; G
    mov r14b, byte[rdi + r8 * 4 - 2]       ; B
    mov r15b, byte[rdi + r8 * 4 - 1]       ; A
    
    and r12b, r11b
    and r13b, r11b
    and r14b, r11b

    ; ALTERNATIVA 1 =============
    shl r12b, cl
    shl r13b, cl
    shl r14b, cl

    sar r12b, 7                         ; Broadcasteo el bit que sobrevivio (si sobrevivio)
    sar r13b, 7
    sar r14b, 7
    ; ALTERNATIVA 1 =============

    ; ALTERNATIVA 2 =============
; .cmpR12:
;     cmp r12b, 0
;     je .ceroR12
;     mov r12b, 0xFF
;     jmp .cmpR13
; .ceroR12:
;     mov r12b, 0

; .cmpR13:
;     cmp r13b, 0
;     je .ceroR13
;     mov r13b, 0xFF
;     jmp .cmpR14
; .ceroR13:
;     mov r13b, 0

; .cmpR14:
;     cmp r14b, 0
;     je .ceroR14
;     mov r14b, 0xFF
;     jmp .setAlpha
; .ceroR14:
;     mov r14b, 0

; .setAlpha:
    ; ALTERNATIVA 2 =============

    
    mov r15b, 0xFF
    
    mov byte[rsi + r8 * 4 - 4], r12b       ; R
    mov byte[rsi + r8 * 4 - 3], r13b       ; G
    mov byte[rsi + r8 * 4 - 2], r14b       ; B
    mov byte[rsi + r8 * 4 - 1], r15b       ; A

    dec r8
    test r8, r8
    jne .loop
.end:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret                                 ; No' fuimo'
