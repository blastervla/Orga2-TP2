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

; ===================== Experimental =====================

; Levantanding de a un pixel (sha fua)
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
    mov rcx, rax                ; RCX = Cantidad total de píxeles
    shr rcx, 1                  ; Voy a levantar de a 2 píxeles, así que divido por 2
.loop:
    movq xmm0, qword[rdi + rcx * 8 - 8] ; Levanto 2 píxeles de src (16 bytes)
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
    
    movq qword[rsi + rcx * 8 - 8], xmm0 ; Almaceno los 4 píxeles en dst

    loop .loop
.end:
    ret                                 ; No' fuimo'

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
