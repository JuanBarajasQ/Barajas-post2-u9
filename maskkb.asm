; MASK_KB.ASM — Enmascarar/desenmascarar IRQ1 con el PIC 8259A
; Compila: nasm -f bin MASK_KB.ASM -o MASK_KB.COM

[BITS 16]
[ORG 0x100]

msg_mask DB "IRQ1 enmascarado (teclado deshabilitado)...$"
msg_unmask DB 0Dh, 0Ah, "IRQ1 restaurado.$"

start:
 ; Leer IMR actual y guardar
 IN AL, 21h
 PUSH AX ; conservar valor original

 ; Enmascarar IRQ1 (bit 1 del IMR)
 OR AL, 02h ; bit 1 = IRQ1
 OUT 21h, AL

 MOV AH, 09h
 MOV DX, msg_mask
 INT 21h

 ; Esperar ~3 segundos usando el timer BIOS (18.2 ticks/s ≈ 55 ticks)
 MOV AH, 00h
 INT 1Ah ; leer ticks actuales en CX:DX
 MOV BX, DX
 ADD BX, 55 ; objetivo: 55 ticks más

.wait:
 MOV AH, 00h
 INT 1Ah
 CMP DX, BX
 JL .wait

 ; Restaurar IMR original
 POP AX
 OUT 21h, AL
 
 MOV AH, 09h
 MOV DX, msg_unmask
 INT 21h
 MOV AH, 4Ch
 INT 21h
