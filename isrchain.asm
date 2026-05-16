; ISR_KB.ASM — ISR personalizado para IRQ1 (teclado)
; Compila: nasm -f bin ISR_KB.ASM -o ISR_KB.COM
[BITS 16]
[ORG 0x100]

section .data
contador    DW 0
nueva_tecla DB 0
MAX_KEYS    EQU 5
old_isr     DD 0            ; formato: DW offset, DW segmento (little-endian)
msg_tecla   DB 0Dh, 0Ah, "Tecla detectada por ISR encadenado$"
msg_fin     DB 0Dh, 0Ah, "ISR restaurado. Fin del programa.$"

section .text
    ; Guardar vector original INT 09h
    MOV  AX, 3509h          ; AH=35h: obtener vector INT 09h
    INT  21h                ; ES:BX = SEG:OFF del handler actual
    MOV  [old_isr],   BX   ; guardar offset
    MOV  [old_isr+2], ES   ; guardar segmento
 
    ; Instalar ISR propio
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    MOV  DX, mi_isr_chain   ; DS:DX = nuevo handler
    MOV  AX, 2509h          ; AH=25h: fijar vector INT 09h
    INT  21h
    POP  DS
    STI                     ; asegurar interrupciones habilitadas
 
; --- Bucle principal: espera flag del ISR, luego imprime ---
.esperar:
    CMP  BYTE [nueva_tecla], 0
    JE   .esperar           ; nada aún
 
    MOV  BYTE [nueva_tecla], 0  ; limpiar flag
    MOV  AH, 09h
    MOV  DX, msg_tecla
    INT  21h                ; seguro: estamos en el mainloop, no en ISR
 
    MOV  AX, [contador]
    CMP  AX, MAX_KEYS
    JL   .esperar           ; seguir hasta 5 teclas
 
    ; Restaurar handler original
    CLI
    LDS  DX, [old_isr]      ; DS:DX = handler original
    MOV  AX, 2509h
    INT  21h
    STI
 
    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h
 
    MOV  AH, 4Ch
    INT  21h
 
; -------------------------------------------------------
; ISR encadenado:
;   1. Código propio (registrar tecla, poner flag)
;   2. Encadenar al handler original con PUSHF + CALL FAR
;      — esto simula exactamente lo que hace una instrucción INT:
;        empuja FLAGS, CS e IP, y salta al handler original.
;      — El handler original enviará su propio EOI al PIC y hará IRET,
;        por lo que aquí NO enviamos EOI ni hacemos IRET nosotros.
; -------------------------------------------------------
mi_isr_chain:
    PUSH AX
    PUSH DS
 
    MOV  AX, CS
    MOV  DS, AX             ; DS apunta al segmento del programa
 
    ; Leer scancode del puerto 60h
    IN   AL, 60h
 
    ; Filtrar break codes (bit 7 = 1 → tecla soltada)
    ; Solo contar y señalizar en make codes
    TEST AL, 80h
    JNZ  .encadenar         ; break code: saltar al original sin contar
 
    ; Make code: registrar tecla
    INC  WORD [contador]
    MOV  BYTE [nueva_tecla], 1
 
.encadenar:
    POP  DS
    POP  AX
 
    ; Encadenar con el handler original.
    ; PUSHF + CALL FAR simula un INT: el handler original verá la pila
    ; exactamente como si hubiera sido invocado por hardware, incluyendo
    ; FLAGS con IF=1 tal como estaban, y podrá hacer su propio IRET.
    ; El handler original también envía el EOI, así que nosotros no lo hacemos.
    PUSHF
    CALL FAR [old_isr]
 
    ; El handler original ya hizo IRET internamente (volvemos aquí).
    ; Solo retornamos de nuestra ISR.
    IRET