default rel
global __string__String__eql
global __string__String__hash
global __string__String__deinit
global __string__String__init
global __string__String__display
global __string__String__init_from
section .text

__string__String__init:
    sub rsp, 16 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea r8, [__find_len] ; Get Function
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    mov [rbp + 8], r8 ; Declare identifier
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline malloc call
    call malloc
    add rsp, 32
    mov r8, rax
    mov [rbp + 16], r8 ; Declare identifier
    lea r8, [__copy_nstr] ; Get Function
    sub rsp, 32 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    xor eax, eax
.L0:
    xor eax, eax
    pop rbp
    add rsp, 16
    ret

__string__String__deinit:
    push rbp
    mov rbp, rsp
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    mov r8, rax
    xor eax, eax
.L1:
    xor eax, eax
    pop rbp
    ret

__string__String__init_from:
    sub rsp, 16 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov [rbp + 8], r8 ; Declare identifier
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline malloc call
    call malloc
    add rsp, 32
    mov r8, rax
    mov [rbp + 16], r8 ; Declare identifier
    lea r8, [__copy_nstr] ; Get Function
    sub rsp, 32 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rsp+16], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    xor eax, eax
.L2:
    xor eax, eax
    pop rbp
    add rsp, 16
    ret

__string__String__display:
    push rbp
    mov rbp, rsp
    sub rsp, 24 ; Make space for native args
    lea r8, [C0]
    mov [rsp+0], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov [rsp+8], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rsp+16], r8
    pop rcx
    pop rdx
    pop r8
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    xor eax, eax
.L3:
    xor eax, eax
    pop rbp
    ret

__string__String__eql:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+56] ; Get Arg/Local
    mov r9, qword [r9+8] ; Field access
    cmp r8, r9 ; UINT !=
    setne al
    movzx r8, al
    test r8, r8
    jz .L5
    mov r8, 0 ; Load BOOL
    mov rax, r8
    jmp .L4
.L5:
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rbp + 24], r8 ; Declare identifier
    mov r8, 0 ; Load INT
    mov [rbp + 32], r8 ; Declare identifier
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Exit check
    jz .L6
.L7:
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, qword [rbp+24] ; Get Arg/Local
    mov r10, qword [rbp+32] ; Get Arg/Local
    imul r10, 1
    movzx r9, byte [r9+r10] ; Ptr Index
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT !=
    setne al
    movzx r8, al
    test r8, r8
    jz .L9
    mov r8, 0 ; Load BOOL
    mov rax, r8
    jmp .L4
.L9:
    mov r8, 1 ; Load INT
    lea r9, [rbp+32] ; Get Local
    add [r9], r8 ; Mutate
.L8:
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L7
.L6:
    mov r8, 1 ; Load BOOL
    mov rax, r8
    jmp .L4
    xor eax, eax
.L4:
    pop rbp
    add rsp, 32
    ret

__string__String__hash:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, 2166126261 ; Load INT
    mov [rbp + 8], r8d ; Declare identifier
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov [rbp + 24], r8 ; Declare identifier
    mov r8, 0 ; Load INT
    mov [rbp + 32], r8 ; Declare identifier
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Exit check
    jz .L11
.L12:
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    lea r9, [rbp+8] ; Get Local
    xor [r9], r8d ; Mutate
    mov r8, 1677619 ; Load INT
    lea r9, [rbp+8] ; Get Local
    xor rax, rax ; Mutate    
    mov eax, dword [r9]
    imul r8d, eax
    mov [r9], r8d
.L13:
    mov r8, 1 ; Load INT
    lea r9, [rbp+32] ; Get Local
    add [r9], r8 ; Mutate
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L12
.L11:
    mov r8d, dword [rbp+8] ; Get Arg/Local
    mov rax, r8
    jmp .L10
    xor eax, eax
.L10:
    pop rbp
    add rsp, 32
    ret

__find_len:
    sub rsp, 8 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, 0 ; Load INT
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, 0 ; Load INT
    movzx r8, r8b
    cmp r8, r9 ; UINT !=
    setne al
    movzx r8, al
    test r8, r8 ; Exit check
    jz .L15
.L16:
    mov r8, 1 ; Load INT
    lea r9, [rbp+8] ; Get Local
    add [r9], r8 ; Mutate
.L17:
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, 0 ; Load INT
    movzx r8, r8b
    cmp r8, r9 ; UINT !=
    setne al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L16
.L15:
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov rax, r8
    jmp .L14
    xor eax, eax
.L14:
    pop rbp
    add rsp, 8
    ret

__copy_nstr:
    sub rsp, 8 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, 0 ; Load INT
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    cmp r8, r9 ; UINT <
    setb al
    movzx r8, al
    test r8, r8 ; Exit check
    jz .L19
.L20:
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, qword [rbp+40] ; Get Arg/Local
    mov r10, qword [rbp+8] ; Get Arg/Local
    imul r10, 1
    lea r9, [r9+r10] ; Ptr Index
    mov [r9], r8b ; Mutate
    mov r8, 1 ; Load INT
    lea r9, [rbp+8] ; Get Local
    add [r9], r8 ; Mutate
.L21:
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    cmp r8, r9 ; UINT <
    setb al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L20
.L19:
    xor eax, eax
.L18:
    xor eax, eax
    pop rbp
    add rsp, 8
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
    C0: db `\"%.*s\"\n`, 0
section .bss
    @CLOCK_START: resb 8
    @ARGC: resb 8
    @ARGV: resb 8
    @ARG_BUFFER: resb 8

    ; Program Globals ;
