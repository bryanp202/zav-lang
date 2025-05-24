default rel
global __stringhashmap__StringHashMap_string__init
global __stringhashmap__StringHashMap_string__get_ptr
global __stringhashmap__StringHashMap_string__remove
global __stringhashmap__StringHashMap_string__display
global __stringhashmap__StringHashMap_string__put
extern __SIZE_OF_STRING
extern __string__data
extern __string__String__init_from
extern __string__String__eql
extern __string__String
extern __string__String__hash
extern __string__len
extern __string__String__deinit
section .text

__stringhashmap__StringHashMap_string__init:
    push rbp
    mov rbp, rsp
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [__SIZE_OF_STRING] ; Get Global
    mov rdi, 2 ; Load INT
    imul rsi, rdi ; (U)INT Mul
    mov [rsp+0], rsi
    mov rsi, 8 ; Load INT
    mov [rsp+8], rsi
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline calloc call
    call calloc
    add rsp, 32
    mov rsi, rax
    mov rdi, qword [rbp+16] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, 0 ; Load INT
    mov rdi, qword [rbp+16] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, 8 ; Load INT
    mov rdi, qword [rbp+16] ; Get Arg/Local
    lea rdi, [rdi+16] ; Field access
    mov [rdi], rsi ; Mutate
    movsd xmm0, [C0] ; Load F64
    mov rsi, qword [rbp+16] ; Get Arg/Local
    lea rsi, [rsi+24] ; Field access
    movq [rsi], xmm0 ; Mutate
    xor eax, eax
.L0:
    xor eax, eax
    pop rbp
    ret

__stringhashmap__StringHashMap_string__put:
    sub rsp, 16 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov rdi, 1 ; Load INT
    add rsi, rdi ; (U)INT Add
    cvtsi2sd xmm0, rsi ; Non-floating point to F64
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    cvtsi2sd xmm1, rsi ; Non-floating point to F64
    divsd xmm0, xmm1 ; Float Div
    mov rsi, qword [rbp+32] ; Get Arg/Local
    movsd xmm1, [rsi+24] ; Field access
    comisd xmm0, xmm1 ; Float >
    seta al
    movzx rsi, al
    test rsi, rsi
    jz .L2
    lea rsi, [StringHashMap_string__resize] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
.L2:
    lea rsi, [StringHashMap_string__get_entry] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 32
    mov rsi, rax
    mov [rbp + 16], sil ; Declare identifier
    movzx rsi, byte [rbp+16] ; Get Arg/Local
    test rsi, rsi
    jz .L3
    lea rsi, [__stringhashmap__Entry_string__deinit] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
    jmp .L4
.L3:
    mov rsi, 1 ; Load INT
    mov rdi, qword [rbp+32] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    add [rdi], rsi ; Mutate
.L4:
    lea rsi, [__stringhashmap__Entry_string__init] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], rsi
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 32
    mov rsi, rax
    movzx rsi, byte [rbp+16] ; Get Arg/Local
    mov rax, rsi
    jmp .L1
    xor eax, eax
.L1:
    pop rbp
    add rsp, 16
    ret

__stringhashmap__StringHashMap_string__get_ptr:
    sub rsp, 16 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea rsi, [StringHashMap_string__get_entry] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 32
    mov rsi, rax
    mov [rbp + 16], sil ; Declare identifier
    movzx rsi, byte [rbp+16] ; Get Arg/Local
    test rsi, rsi ; If Expr
    jz .L6
    mov rsi, qword [rbp+8] ; Get Arg/Local
    lea rsi, [rsi+16] ; Field access
    jmp .L7
.L6:
    mov rsi, 0 ; Load NULLPTR
.L7: ; End of If Expr
    mov rax, rsi
    jmp .L5
    xor eax, eax
.L5:
    pop rbp
    add rsp, 16
    ret

__stringhashmap__StringHashMap_string__remove:
    sub rsp, 16 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea rsi, [StringHashMap_string__get_entry] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 32
    mov rsi, rax
    mov [rbp + 16], sil ; Declare identifier
    movzx rsi, byte [rbp+16] ; Get Arg/Local
    test rsi, rsi
    jz .L9
    lea rsi, [__string__String__deinit] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
    mov rsi, 1 ; Load INT
    mov rdi, qword [rbp+8] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, 0 ; Load INT
    mov rdi, qword [rbp+8] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, 1 ; Load INT
    mov rdi, qword [rbp+32] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    sub [rdi], rsi ; Mutate
.L9:
    movzx rsi, byte [rbp+16] ; Get Arg/Local
    mov rax, rsi
    jmp .L8
    xor eax, eax
.L8:
    pop rbp
    add rsp, 16
    ret

__stringhashmap__StringHashMap_string__display:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rbp + 8], rsi ; Declare identifier
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov [rbp + 16], rsi ; Declare identifier
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rbp + 24], rsi ; Declare identifier
    sub rsp, 24 ; Make space for native args
    lea rsi, [C1]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    pop rdx
    pop r8
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov rsi, rax
    mov rsi, 0 ; Load INT
    mov [rbp + 32], rsi ; Declare identifier
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+16] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Exit check
    jz .L11
.L12:
    lea rsi, [__stringhashmap__Entry_string__display] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    imul rdi, 32
    lea rsi, [rsi+rdi] ; Ptr Index
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
.L13:
    mov rsi, 1 ; Load INT
    lea rdi, [rbp+32] ; Get Local
    add [rdi], rsi ; Mutate
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+16] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Loop check
    jnz .L12
.L11:
    sub rsp, 24 ; Make space for native args
    lea rsi, [C2]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    pop rdx
    pop r8
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov rsi, rax
    xor eax, eax
.L10:
    xor eax, eax
    pop rbp
    add rsp, 32
    ret

StringHashMap_string__resize:
    sub rsp, 40 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov [rbp + 8], rsi ; Declare identifier
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, 2 ; Load INT
    imul rsi, rdi ; (U)INT Mul
    mov [rbp + 16], rsi ; Declare identifier
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rbp + 24], rsi ; Declare identifier
    sub rsp, 24 ; Make space for native args
    mov rsi, qword [__SIZE_OF_STRING] ; Get Global
    mov rdi, 2 ; Load INT
    imul rsi, rdi ; (U)INT Mul
    mov [rsp+0], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline calloc call
    call calloc
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    mov rdi, qword [rbp+56] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+56] ; Get Arg/Local
    lea rdi, [rdi+16] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, 0 ; Load INT
    mov [rbp + 32], rsi ; Declare identifier
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+8] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Exit check
    jz .L15
.L16:
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    imul rdi, 32
    lea rsi, [rsi+rdi] ; Ptr Index
    mov [rbp + 40], rsi ; Declare identifier
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, 1 ; Load INT
    cmp rsi, rdi ; UINT >
    seta al
    movzx rsi, al
    test rsi, rsi
    jz .L18
    lea rsi, [StringHashMap_string__insert_no_check] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
.L18:
.L17:
    mov rsi, 1 ; Load INT
    lea rdi, [rbp+32] ; Get Local
    add [rdi], rsi ; Mutate
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+8] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Loop check
    jnz .L16
.L15:
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    xor eax, eax
.L14:
    xor eax, eax
    pop rbp
    add rsp, 40
    ret

StringHashMap_string__insert_no_check:
    sub rsp, 8 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea rsi, [StringHashMap_string__get_entry] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__stringhashmap__Entry_string__copy_from] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    lea rsi, [rsi+16] ; Field access
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    xor eax, eax
.L19:
    xor eax, eax
    pop rbp
    add rsp, 8
    ret

StringHashMap_string__get_entry:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov [rbp + 8], rsi ; Declare identifier
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rbp + 16], rsi ; Declare identifier
    lea rsi, [__string__String__hash] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
    mov rdi, qword [rbp+8] ; Get Arg/Local
    mov rax, rsi ; (U)INT Mod
    xor edx, edx
    idiv rdi
    mov rsi, rdx
    mov [rbp + 24], rsi ; Declare identifier
    lea rsi, [__string__String__eql] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    imul rdi, 32
    lea rsi, [rsi+rdi] ; Ptr Index
    mov [rsp+8], rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
    mov [rbp + 32], sil ; Declare identifier
    movzx rsi, byte [rbp+32] ; Get Arg/Local
    xor rsi, 1 ; Bool not
    test rsi, rsi ; Logical AND
    jz .L22
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    imul rdi, 32
    lea rsi, [rsi+rdi] ; Ptr Index
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, 1 ; Load INT
    cmp rsi, rdi ; UINT >=
    setae al
    movzx rsi, al
.L22:
    test rsi, rsi ; Exit check
    jz .L21
.L23:
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rdi, 1 ; Load INT
    add rsi, rdi ; (U)INT Add
    mov rdi, qword [rbp+8] ; Get Arg/Local
    mov rax, rsi ; (U)INT Mod
    xor edx, edx
    idiv rdi
    mov rsi, rdx
    lea rdi, [rbp+24] ; Get Local
    mov [rdi], rsi ; Mutate
    lea rsi, [__string__String__eql] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    imul rdi, 32
    lea rsi, [rsi+rdi] ; Ptr Index
    mov [rsp+8], rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
    lea rdi, [rbp+32] ; Get Local
    mov [rdi], sil ; Mutate
.L24:
    movzx rsi, byte [rbp+32] ; Get Arg/Local
    xor rsi, 1 ; Bool not
    test rsi, rsi ; Logical AND
    jz .L25
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    imul rdi, 32
    lea rsi, [rsi+rdi] ; Ptr Index
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, 1 ; Load INT
    cmp rsi, rdi ; UINT >=
    setae al
    movzx rsi, al
.L25:
    test rsi, rsi ; Loop check
    jnz .L23
.L21:
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    imul rdi, 32
    lea rsi, [rsi+rdi] ; Ptr Index
    mov rdi, qword [rbp+64] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    movzx rsi, byte [rbp+32] ; Get Arg/Local
    mov rax, rsi
    jmp .L20
    xor eax, eax
.L20:
    pop rbp
    add rsp, 32
    ret

__stringhashmap__Entry_string__init:
    push rbp
    mov rbp, rsp
    lea rsi, [__string__String__init_from] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
    lea rsi, [__string__String__init_from] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    lea rsi, [rsi+16] ; Field access
    mov [rsp+8], rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
    xor eax, eax
.L26:
    xor eax, eax
    pop rbp
    ret

__stringhashmap__Entry_string__deinit:
    push rbp
    mov rbp, rsp
    lea rsi, [__string__String__deinit] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
    lea rsi, [__string__String__deinit] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    lea rsi, [rsi+16] ; Field access
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 16
    mov rsi, rax
    xor eax, eax
.L27:
    xor eax, eax
    pop rbp
    ret

__stringhashmap__Entry_string__copy_from:
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+16] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov rdi, qword [rbp+16] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+16] ; Get Arg/Local
    lea rdi, [rdi+16] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov rdi, qword [rbp+16] ; Get Arg/Local
    lea rdi, [rdi+16] ; Field access
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
    xor eax, eax
.L28:
    xor eax, eax
    pop rbp
    ret

__stringhashmap__Entry_string__display:
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, 1 ; Load INT
    cmp rsi, rdi ; UINT >
    seta al
    movzx rsi, al
    test rsi, rsi ; Logical AND
    jz .L30
    mov rsi, qword [rbp+16] ; Get Arg/Local
    lea rsi, [rsi+16] ; Field access
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, 1 ; Load INT
    cmp rsi, rdi ; UINT >
    seta al
    movzx rsi, al
.L30:
    test rsi, rsi
    jz .L31
    sub rsp, 48 ; Make space for native args
    lea rsi, [C3]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rsp+8], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rsp+16], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    lea rsi, [rsi+16] ; Field access
    mov rsi, qword [rsi+8] ; Field access
    mov [rsp+24], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    lea rsi, [rsi+16] ; Field access
    mov rsi, qword [rsi+0] ; Field access
    mov [rsp+32], rsi
    pop rcx
    pop rdx
    pop r8
    pop r9
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 16
    mov rsi, rax
    jmp .L32
.L31:
    sub rsp, 8 ; Make space for native args
    lea rsi, [C4]
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov rsi, rax
.L32:
    xor eax, eax
.L29:
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
    extern calloc
    extern printf

    ; Program Constants ;
    C0: dq 7e-1
    C3: db `Entry: (Key: \"%.*s\", Value: \"%.*s\")\n`, 0
    C2: db `-- [End of StringHashMap] --\n`, 0
    C4: db `Entry: (Empty)\n`, 0
    C1: db `-- [StringHashMap, Entry: (Key: String, Value: String), Count: %lu, Capacity: %lu] --\n`, 0
section .bss
    @CLOCK_START: resb 8
    @ARGC: resb 8
    @ARGV: resb 8
    @ARG_BUFFER: resb 8

    ; Program Globals ;
