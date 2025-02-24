default rel

extern printf

global main

section .text
main:
    push rbp
    mov rbp, rsp

    ; Calculate expr "-(2 * (100 + (-3)))"
    push 2
    push 100
    push 3
    neg qword [rsp]
    pop r11
    pop r10
    add r10, r11
    push r10
    pop r11
    pop r10
    imul r10, r11
    push r10
    neg qword [rsp]
    pop r10
    cvtsi2sd xmm0, r10
    movq xmm1, [SIGN_BIT]
    xorpd xmm0, xmm1
    movsd [number], xmm0

    ; printf call
    lea rcx, [rel format]
    mov rdx, [number]
    sub rsp, 40 ; shadow space
    call printf
    add rsp, 40    

    ; Quit
    xor     ecx, ecx
    leave
    ret

section .data
    format: db "result: %f", 0xD, 0xA, 0
    SIGN_BIT: dq 0x8000000000000000

section .bss
    number resb 4

