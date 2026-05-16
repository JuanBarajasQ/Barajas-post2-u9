; ISR_KB.ASM — ISR personalizado para IRQ1 (teclado)
; Compila: nasm -f bin ISR_KB.ASM -o ISR_KB.COM
[BITS 16]
[ORG 0x100]

; --- Punto de entrada ---
start:
    ; Guardar vector original INT 09h
    MOV  AX, 3509h
    INT  21h                    ; ES:BX = handler actual
    MOV  [old_isr],   BX
    MOV  [old_isr+2], ES

    ; Instalar ISR propio
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    MOV  DX, mi_isr
    MOV  AX, 2509h
    INT  21h
    POP  DS
    STI

; --- Bucle principal: espera flag del ISR y hace el output ---
.esperar:
    ; Comprobar si el ISR dejó una tecla pendiente
    CMP  BYTE [nueva_tecla], 0
    JE   .esperar               ; nada aún, seguir esperando

    ; Hay tecla nueva: mostrar mensaje
    MOV  BYTE [nueva_tecla], 0  ; limpiar flag ANTES de imprimir
    MOV  AH, 09h
    MOV  DX, msg_tecla
    INT  21h                    ; INT 21h seguro: estamos en el mainloop

    ; Comprobar si llegamos a MAX_KEYS
    MOV  AX, [contador]
    CMP  AX, MAX_KEYS
    JL   .esperar               ; seguir esperando más teclas
                                ; (contador ya fue incrementado por ISR)

    ; --- Restaurar handler original ---
    CLI
    LDS  DX, [old_isr]
    MOV  AX, 2509h
    INT  21h
    STI

    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h

    MOV  AH, 4Ch
    INT  21h

; -------------------------------------------------------
; ISR propio: SOLO lee scancode, filtra make/break, pone flag
; NUNCA llama INT 21h ni ninguna función DOS
; -------------------------------------------------------
mi_isr:
    PUSH AX
    PUSH DS

    MOV  AX, CS
    MOV  DS, AX

    ; Leer scancode del puerto 60h
    IN   AL, 60h

    ; Ignorar break codes (bit 7 = 1 → tecla soltada)
    TEST AL, 80h
    JNZ  .eoi

    ; Es make code (tecla presionada): actualizar estado
    INC  WORD [contador]
    MOV  BYTE [nueva_tecla], 1  ; señal para el mainloop

.eoi:
    ; Enviar EOI al PIC maestro (obligatorio)
    MOV  AL, 20h
    OUT  20h, AL

    POP  DS
    POP  AX
    IRET

; --- Datos ---
contador    DW 0
nueva_tecla DB 0                ; flag: 1 = hay tecla nueva sin procesar
MAX_KEYS    EQU 5
old_isr     DD 0
msg_tecla   DB 0Dh, 0Ah, "Tecla detectada por ISR propio$"
msg_fin     DB 0Dh, 0Ah, "ISR restaurado. Fin del programa.$"