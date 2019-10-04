
        ; Si hacemos un and negado de la mascara de negativos con los inv, nos 
        ;pandn xmm14,
        ; Haciendo un or con la mascara de negativos, nos mantiene los positivos
        ; y nos deja en 1 a los negativos.
        ;por xmm0, xmm14         ; xmm0[15:0] = xmm0[15:0] < 0? 1 : xmm0[15:0]
;     push rbp
;     mov rbp, rsp

;     ;xor r10d, r10d
;     ;xor r11d, r11d

; ;   Recorremos la matriz hasta llegar hasta el último pixel que tiene vecinos.
; ;   Este pixel es el (n-1, m-1).

;     mov eax, edx        ; eax = width
;     mov ecx, ecx        ; rcx = 0x00000000 | height
;     mul rcx             ; rax = width * height

; ;   En rax tenemos la ultima fila y columna. mul 32b --> 64b
;     ;shl r8, 32
;     ;shr r8, 32
;     ;add r10d, ecx
;     ;mov r8d, r8d        ; r8 = 0x00000000 | src_row_size 
;     ;sub rax, r8
;     ;sub rax, 1
;     ;lea rax, [rax + r8 - 1]

    
;     pxor xmm0, xmm0
;     pxor xmm13, xmm13
;     .ciclo:
;         test rax, rax
;         jz .fin

;         movdqu xmm1, [rdi - r8 - 1]
;         movdqu xmm2, [rdi - r8]
;         movdqu xmm3, [rdi - r8 + 1]

;         movdqu xmm4, [rdi - 1]
;         ;movdqu xmm5, [rdi]
;         movdqu xmm6, [rdi + 1]

;         movdqu xmm7, [rdi + r8 - 1]
;         movdqu xmm8, [rdi + r8]
;         movdqu xmm9, [rdi + r8 + 1]

; ;   Podemos optimizar el uso de xmm1 y xmm9 pues para ambas matrices es
; ;   igual como se suma. Los unicos que cambian son xmm3 y xmm7. Los otros 
; ;   se usan solo en una matriz o en las dos pero con el mismo valor.

;         movdqu xmm10, xmm3
;         movdqu xmm11, xmm7
;         ;copiar xmm9 en vez de xmm7

; ;   Vamos a sumar de a pares negativos/positivos asi minimizamos la cantidad
; ;   de registros a desempaquetar.

;         psubb xmm3, xmm1

; ;   SI PODEMOS NEGAR EL XMM7 DE A PAQUETES DE BYTES, AHORRAMOS COPIAR EL
; ;   ALGUNO DE LO S DOS REGISTROS. LO HACEMOS SOBRE XMM7 PUES YA LO TENEMOS QUE
; ;   COPIAR PARA EL CALCULO DE GY.

;         paddb -xmm7, xmm9

; ;   Usamos xmm7 pues ya lo copiamos a xmm11. A continuación usamos xmm6 pues
; ;   no lo necesitamos para calcular Gy.

;         psubb xmm6, xmm4
;         movdqu xmm12, xmm6

; ;   Desempaquetamos todos los canales a words para multiplicarlos por dos
; ;   y no perder información en el cálculo intermedio. xmm13 es un registro
; ;   auxiliar con 0.


; ;   Me parece que no es ni necesario pues no vamos a estar restando nada
; ;   después de esto. Entonces lo que nos estamos salvando al deempaquetar ahora
; ;   lo vamos a perder cuando lo empaquetemos.

; ;   LA SATURACIÓN ES AL FINAL DE LA SUMA GX, GY

; ;   No veo como shiftear bytes empaquetados por bits. Para arreglar eso sigo
; ;   desempaquetando y shifteando parte alta y baja.

;         punpcklbw xmm6, xmm13
;         punpckhbw xmm12, xmm13

; ;   psll xmm6, 1
        
;         psllw xmm6, 1
;         psllw xmm12, 1

; ;   signed porque puede dar negativo

;         packsswb xmm6, xmm12

; ;   resultado Gx
; ;       no se si esto está bien, podemos perder alguna precision.
; ;       deberiamos satrurar solo al sumarlo con el resultado de gy.

;         paddb xmm3, xmm7
;         paddb xmm3, xmm6

;         movdqu xmm0, xmm3

; ;   Calculo Gy

;         psubb xmm11, xmm1
;         psubb xmm9, xmm10

;         psubb xmm8, xmm2
;         movdqu xmm12, xmm8

;         punpcklbw xmm8, xmm13
;         punpckhbw xmm12, xmm13

;         psllw xmm8, 1
;         psllw xmm12, 1

;         packuswb xmm8, xmm12

; ;   resultado Gx

;         paddb xmm11, xmm9
;         paddb xmm11, xmm8

;         paddb xmm0, xmm11

; ;   Hay que setear el alpha a 255 con alguna mascara

        
; ;   Si hacemos el empaquetado ahora los valores mayores a 255 van a saturar
; ;   a 255. Debemos sumar todos los registros acá , de forma desempaquetada
; ;   y solo empaquetarlos a lo último?

; ;       Seteamos el alpha.

;         por xmm0, xmm15

;         movdqu [rsi], xmm0

;         lea rdi, [rdi + PIXEL_SIZE*4]
;         lea rsi, [rsi + PIXEL_SIZE*4]
;         dec rax

;         jmp .ciclo

;     .fin:
;         call llenarBordes

;     pop rbp
; ret
























cmp r11, r14
        jge .end

        
        pxor xmm15, xmm15

;       ↖ ↑ ↗  =  xmm1 xmm2 xmm3
;       ← ⋅ →  =  xmm4   0   xmm6
;       ↙ ↓ ↘  =  xmm7 xmm8 xmm9
        movq xmm1, [r10 - 1]  
        movq xmm2, [r10]      
        movq xmm3, [r10 + 1]  
        movq xmm4, [r11 - 1]  
        movq xmm6, [r11 + 1]  
        movq xmm7, [r12 - 1]  
        movq xmm8, [r12]      
        movq xmm9, [r12 + 1]  
       
        ; Calculamos TotalGx.
        
        punpcklbw xmm1, xmm15
        punpcklbw xmm2, xmm15
        punpcklbw xmm3, xmm15
        punpcklbw xmm4, xmm15
        punpcklbw xmm6, xmm15
        punpcklbw xmm7, xmm15
        punpcklbw xmm8, xmm15
        punpcklbw xmm9, xmm15

        movdqu xmm10, xmm3      ; xmm10 = ↗
        movdqu xmm11, xmm9      ; xmm11 = ↘

        ; psubw xmm3, xmm1        ; xmm3[31:0] = ____ | ____ | ↗₁ - ↖₁ | ↗₀ - ↖₀
        ; psubw xmm9, xmm7        ; xmm9[31:0] = ____ | ____ | ↘₁ - ↙₁ | ↘₀ - ↙₀
        ; psubw xmm6, xmm4        ; xmm6[31:0] = ____ | ____ | →₁ - ←₁ | →₀ - ←₀

        ; ;pxor xmm14, xmm14
        ; ;pcmpgtb xmm14, xmm6
        ; ;punpcklbw xmm6, xmm14   ; xmm6[31:0] = 0xFF | →₁ - ←₁ | 0x00 | →₀ - ←₀
        ; psllw xmm6, 1           ; xmm6[31:0] = 2 * (→₁ - ←₁)  | 2 * (→₀ - ←₀)
        
        ; ;pxor xmm14, xmm14
        ; ;pcmpgtb xmm14, xmm3
        ; ;punpcklbw xmm3, xmm14   ; xmm3[31:0] = 0x00 | ↗₁ - ↖₁ | 0x00 | ↗₀ - ↖₀

        ; ;pxor xmm14, xmm14
        ; ;pcmpgtb xmm14, xmm9
        ; ;punpcklbw xmm9, xmm14   ; xmm9[31:0] = 0x00 | ↘₁ - ↙₁ | 0x00 | ↘₀ - ↙₀    

        ; paddw xmm3, xmm9        ; xmm3[15:0] = (↗₀ - ↖₀) + (↘₀ - ↙₀)
        ; paddw xmm3, xmm6        ; xmm3[15:0] = (↗₀ - ↖₀) + (↘₀ - ↙₀) + 2*(→₀ - ←₀)
        ; ;pabsw xmm3, xmm3
        ; movdqu xmm0, xmm3

        ; pcmpgtw xmm15, xmm3     ; xmm15[15:0]= xmm3[15:0] < 0? 1 : 0
        ; ; Tenemos en xmm15 la mascara de negativos
        ; ; Haciendo un and con xmm3 nos quedamos solamente los negativos.
        ; pand xmm3, xmm15        ; xmm3[15:0] = xmm3[15:0] < 0? xmm3[15:0] : 0
        ; ; Haciendo un xor invertimos los bits de los negativos.
        ; ; Los que no eran negativos, se quedan en 0.
        ; pxor xmm3, xmm15        ; xmm3[15:0] = xmm3[15:0] < 0? !xmm3[15:0] : 0
        ; movdqu xmm14, xmm15
        ; psrlw xmm14, 15         ; Ej: xmm14 = 1 | 0 | 1 | 1
        ; ; Sumando obtenemos el inverso aditivio de todos los negativos.
        ; paddw xmm3, xmm14       ; xmm3[15:0] = xmm3[15:0] < 0? -xmm3[15:0] : 0
        ; ;movdqu xmm14, xmm15
        ; ; Si hacemos un and negado entre la mascara de negativos y xmm0
        ; ; Obtenemos en xmm15, los positivos y 0 donde había negativos.
        ; pandn xmm15, xmm0
        ; ; Si hacemos un or contra el registro con los inversos aditivos,
        ; ; tenemos el resultado.
        ; por xmm3, xmm15         ; xmm3[15:0] = abs(xmm3[15:0])
        ; movdqu xmm0, xmm3
; pxor xmm15, xmm15
        
        psubw xmm7, xmm1        ; xmm7[31:0] = ____ | ____ | ↙₁ - ↖₁ | ↙₀ - ↖₀
        psubw xmm11, xmm10      ; xmm11[31:0]= ____ | ____ | ↘₁ - ↗₁ | ↘₀ - ↗₀
        psubw xmm8, xmm2        ; xmm8[31:0] = ____ | ____ | ↓₁ - ↑₁ | ↓₀ - ↑₀
        
        pxor xmm14, xmm14
        ;pcmpgtb xmm14, xmm8
        ;punpcklbw xmm8, xmm15   ; xmm8[31:0] = 0x00 | ↓₁ - ↑₁ | 0x00 | ↓₀ - ↑₀
        psllw xmm8, 1           ; xmm8[31:0] = 2 * (↓₁ - ↑₁)  | 2 * (↓₀ - ↑₀)
        
        ;pxor xmm14, xmm14
        ;pcmpgtb xmm14, xmm7
        ;punpcklbw xmm7, xmm14   ; xmm7[31:0] = 0x00 | ↙₁ - ↖₁ | 0x00 | ↙₀ - ↖₀
        
        ;pxor xmm14, xmm14
        ;pcmpgtb xmm14, xmm11
        ;punpcklbw xmm11, xmm14  ; xmm11[31:0]= 0x00 | ↘₁ - ↗₁ | 0x00 | ↘₀ - ↗₀

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

        ;paddw xmm0, xmm7
;        packuswb xmm0, xmm0
        packuswb xmm7, xmm7

        movd [r13], xmm7 ;!!
        ; Gy
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
