default rel

__hello__hello__hello_again:
    push rbp
    mov rbp, rsp
    sub rsp, 8 ; Make space for native args
    lea rsi, [C0]
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov rsi, rax
    xor eax, eax
.L0:
    xor eax, eax
    pop rbp
    ret
    
;-------------------------;
;         Natives         ;
;-------------------------;

section .data
    ; Native Constants and Dependencies;
    @SS_SIGN_BIT: dq 0x80000000, 0, 0, 0
    @SD_SIGN_BIT: dq 0x8000000000000000, 0, 0, 0
    extern QueryPerformanceCounter
    extern GetCommandLineW
    extern CommandLineToArgvW
    extern WideCharToMultiByte
    extern malloc
    extern free
    extern ExitProcess
    extern printf

    ; Program Constants ;
    C0: db `Hello from module hello::hello`, 0
section .bss
    @CLOCK_START: resb 8
    @ARGC: resb 8
    @ARGV: resb 8
    @ARG_BUFFER: resb 8

    ; Program Globals ;
