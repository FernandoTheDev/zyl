bits 16
org 0x7C00

start:
    ; Configura segmentos
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Carrega o kernel (setor 2 em diante)
    mov ah, 0x02    ; Função de leitura
    mov al, 10      ; Número de setores
    mov ch, 0       ; Cilindro 0
    mov cl, 2       ; Setor 2
    mov dh, 0       ; Cabeça 0
    mov bx, 0x1000  ; Endereço de destino
    int 0x13        ; Chamada BIOS

    ; Pula para modo protegido
    cli
    lgdt [gdt_descriptor]
    
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    jmp 0x08:protected_mode

bits 32
protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Chama o kernel
    call 0x1000
    
    ; Loop infinito
    jmp $

gdt_start:
    dq 0x0
gdt_code:
    dw 0xFFFF, 0x0
    db 0x0, 0x9A, 0xCF, 0x0
gdt_data:
    dw 0xFFFF, 0x0
    db 0x0, 0x92, 0xCF, 0x0
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 510-($-$$) db 0
dw 0xAA55
