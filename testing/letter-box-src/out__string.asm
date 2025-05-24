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
    lea rsi, [__find_len] ; Get Function
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
    mov [rbp + 8], rsi ; Declare identifier
    sub rsp, 8 ; Make space for native args
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline malloc call
    call malloc
    add rsp, 32
    mov rsi, rax
    mov [rbp + 16], rsi ; Declare identifier
    lea rsi, [__copy_nstr] ; Get Function
    sub rsp, 32 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 32
    mov rsi, rax
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
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
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    mov rsi, rax
    xor eax, eax
.L1:
    xor eax, eax
    pop rbp
    ret

__string__String__init_from:
    sub rsp, 16 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rbp + 8], rsi ; Declare identifier
    sub rsp, 8 ; Make space for native args
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline malloc call
    call malloc
    add rsp, 32
    mov rsi, rax
    mov [rbp + 16], rsi ; Declare identifier
    lea rsi, [__copy_nstr] ; Get Function
    sub rsp, 32 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rsp+16], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 32
    mov rsi, rax
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
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
    lea rsi, [C0]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rsp+8], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rsp+16], rsi
    pop rcx
    pop rdx
    pop r8
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov rsi, rax
    xor eax, eax
.L3:
    xor eax, eax
    pop rbp
    ret

__string__String__eql:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rbp + 8], rsi ; Declare identifier
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+56] ; Get Arg/Local
    mov rdi, qword [rdi+8] ; Field access
    cmp rsi, rdi ; UINT !=
    setne al
    movzx rsi, al
    test rsi, rsi
    jz .L5
    mov rsi, 0 ; Load BOOL
    mov rax, rsi
    jmp .L4
.L5:
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rbp + 16], rsi ; Declare identifier
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rbp + 24], rsi ; Declare identifier
    mov rsi, 0 ; Load INT
    mov [rbp + 32], rsi ; Declare identifier
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+8] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Exit check
    jz .L6
.L7:
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    imul rdi, 1
    movzx rsi, byte [rsi+rdi] ; Ptr Index
    mov rdi, qword [rbp+24] ; Get Arg/Local
    mov r8, qword [rbp+32] ; Get Arg/Local
    imul r8, 1
    movzx rdi, byte [rdi+r8] ; Ptr Index
    movzx rsi, sil
    movzx rdi, dil
    cmp rsi, rdi ; UINT !=
    setne al
    movzx rsi, al
    test rsi, rsi
    jz .L9
    mov rsi, 0 ; Load BOOL
    mov rax, rsi
    jmp .L4
.L9:
    mov rsi, 1 ; Load INT
    lea rdi, [rbp+32] ; Get Local
    add [rdi], rsi ; Mutate
.L8:
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+8] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Loop check
    jnz .L7
.L6:
    mov rsi, 1 ; Load BOOL
    mov rax, rsi
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
    mov rsi, 2166126261 ; Load INT
    mov [rbp + 8], esi ; Declare identifier
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rbp + 16], rsi ; Declare identifier
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rbp + 24], rsi ; Declare identifier
    mov rsi, 0 ; Load INT
    mov [rbp + 32], rsi ; Declare identifier
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Exit check
    jz .L11
.L12:
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    imul rdi, 1
    movzx rsi, byte [rsi+rdi] ; Ptr Index
    lea rdi, [rbp+8] ; Get Local
    xor [rdi], esi ; Mutate
    mov rsi, 1677619 ; Load INT
    lea rdi, [rbp+8] ; Get Local
    xor rax, rax ; Mutate    
    mov eax, dword [rdi]
    imul esi, eax
    mov [rdi], esi
.L13:
    mov rsi, 1 ; Load INT
    lea rdi, [rbp+32] ; Get Local
    add [rdi], rsi ; Mutate
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Loop check
    jnz .L12
.L11:
    mov esi, dword [rbp+8] ; Get Arg/Local
    mov rax, rsi
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
    mov rsi, 0 ; Load INT
    mov [rbp + 8], rsi ; Declare identifier
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rdi, qword [rbp+8] ; Get Arg/Local
    imul rdi, 1
    movzx rsi, byte [rsi+rdi] ; Ptr Index
    mov rdi, 0 ; Load INT
    movzx rsi, sil
    cmp rsi, rdi ; UINT !=
    setne al
    movzx rsi, al
    test rsi, rsi ; Exit check
    jz .L15
.L16:
    mov rsi, 1 ; Load INT
    lea rdi, [rbp+8] ; Get Local
    add [rdi], rsi ; Mutate
.L17:
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rdi, qword [rbp+8] ; Get Arg/Local
    imul rdi, 1
    movzx rsi, byte [rsi+rdi] ; Ptr Index
    mov rdi, 0 ; Load INT
    movzx rsi, sil
    cmp rsi, rdi ; UINT !=
    setne al
    movzx rsi, al
    test rsi, rsi ; Loop check
    jnz .L16
.L15:
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rax, rsi
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
    mov rsi, 0 ; Load INT
    mov [rbp + 8], rsi ; Declare identifier
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    cmp rsi, rdi ; UINT <
    setb al
    movzx rsi, al
    test rsi, rsi ; Exit check
    jz .L19
.L20:
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+8] ; Get Arg/Local
    imul rdi, 1
    movzx rsi, byte [rsi+rdi] ; Ptr Index
    mov rdi, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [rbp+8] ; Get Arg/Local
    imul r8, 1
    lea rdi, [rdi+r8] ; Ptr Index
    mov [rdi], sil ; Mutate
    mov rsi, 1 ; Load INT
    lea rdi, [rbp+8] ; Get Local
    add [rdi], rsi ; Mutate
.L21:
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    cmp rsi, rdi ; UINT <
    setb al
    movzx rsi, al
    test rsi, rsi ; Loop check
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
