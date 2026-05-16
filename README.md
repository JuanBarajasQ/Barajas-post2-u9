
# Laboratorio: Entrada y Salida Avanzada - Rutinas de Servicio de Interrupción (ISR)
* **Estudiante:** Juan Carlos Barajas Quintero 
* **Curso:** Arquitectura de Computadores - Unidad 9
* **Institución:** Universidad Francisco de Paula Santander

Este repositorio contiene la implementación de diversos manejadores de interrupción personalizados para el **IRQ1 (teclado)** en un entorno x86 bajo DOS. El objetivo principal es comprender el flujo de atención de interrupciones de hardware, la programación del controlador de interrupciones (PIC 8259A) y las técnicas de encadenamiento de servicios.

## Propósito
El propósito de este laboratorio es implementar una **Rutina de Servicio de Interrupción (ISR)** personalizada en ensamblador que reemplace temporalmente el manejador estándar del teclado, permitiendo observar cómo el procesador y el PIC gestionan los eventos externos. Además, se explora el **enmascaramiento selectivo** de IRQs y el **encadenamiento (chaining)** para mantener la funcionalidad del sistema operativo mientras se ejecuta código personalizado.

## Prerrequisitos
Para ejecutar y compilar los programas de este laboratorio, se requiere:
*   **Software:** DOSBox 0.74 o superior con el ensamblador **NASM 2.x** instalado.
*   **Conocimientos:** Manejo de la Tabla de Vectores de Interrupción (IVT), uso de las funciones de DOS (INT 21h) para la manipulación de vectores y comprensión del flag de interrupción (IF).

## Pasos de Ejecución
Siga estas instrucciones en el entorno DOSBox:

1.  **Compilación:** Genere los archivos ejecutables `.COM` desde el código fuente `.ASM`:
    *   `nasm -f bin isrkb.asm -o isrkb.com`.
    *   `nasm -f bin maskkb.asm -o maskkb.com`.
    *   `nasm -f bin isrchain.asm -o isrchain.com`.
2.  **Ejecución:** Simplemente escriba el nombre del ejecutable deseado en la línea de comandos (ej. `isrkb.com`).
3.  **Interacción:** En `isrkb`, presione cualquier tecla 5 veces para ver la detección y la finalización del programa. En `maskkb`, observe cómo el teclado deja de responder durante aproximadamente 3 segundos.

---

## Explicación Técnica

### 1. Funcionamiento de cada ISR
*   **ISRKB.ASM:** Este programa reemplaza totalmente el manejador de la `INT 09h`. Al detectar una pulsación (IRQ1), la ISR guarda los registros, lee y descarta el *scancode* del puerto `60h`, incrementa un contador interno y envía la señal **EOI (End Of Interrupt)** al puerto `20h` para avisar al PIC que la interrupción ha sido atendida.
*   **MASKKB.ASM:** No modifica el vector de interrupción, sino el **IMR (Interrupt Mask Register)** del PIC maestro en el puerto `21h`. Coloca en `1` el bit correspondiente al IRQ1 para deshabilitar las interrupciones del teclado, espera un retardo usando la `INT 1Ah` del BIOS y luego restaura el valor original del IMR para habilitar el teclado nuevamente.
*   **ISRCHAIN.ASM:** Es una variante de la ISR personalizada que, tras ejecutar su código (como registrar la pulsación), utiliza la técnica de encadenamiento para pasar el control al manejador original del sistema.

### 2. Instalación y Restauración del Vector
La manipulación de la Tabla de Vectores de Interrupción (IVT) se realiza mediante servicios de la **INT 21h**:
*   **Obtención (Instalación):** Se utiliza `AH=35h` para obtener la dirección actual del manejador de la `INT 09h`, la cual se almacena en una variable (`old_isr`) para su posterior restauración.
*   **Fijación (Instalación):** Se emplea `AH=25h` para apuntar el vector de la `INT 09h` hacia nuestra nueva rutina (`mi_isr`).
*   **Restauración:** Antes de que el programa termine, es crítico devolver el control al manejador original. Esto se hace cargando la dirección guardada en `old_isr` y llamando nuevamente a `AH=25h`. Se utilizan las instrucciones `CLI` (deshabilitar interrupciones) y `STI` (habilitarlas) durante este proceso para evitar que una interrupción ocurra mientras el vector está a medio cambiar, lo que causaría un cuelgue del sistema.

### 3. Encadenamiento (Chaining)
El **encadenamiento** consiste en invocar el manejador original de la interrupción después de que nuestra ISR personalizada ha terminado su tarea. 
*   **Mecánica:** Debido a que el manejador original espera ser llamado como una interrupción (con los flags en la pila y un retorno vía `IRET`), se simula este proceso usando `PUSHF` (para meter los flags a la pila) seguido de un `CALL FAR` a la dirección del manejador original almacenada previamente.
*   **Importancia:** Es esencial cuando no queremos anular las funciones del sistema operativo. Por ejemplo, permite que el "eco" de los caracteres en DOS siga funcionando mientras nuestra ISR realiza tareas adicionales, como llevar un conteo de teclas.
