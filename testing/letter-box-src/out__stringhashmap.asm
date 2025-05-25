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
    mov r8, qword [__SIZE_OF_STRING] ; Get Global
    mov r9, 2 ; Load INT
    imul r8, r9 ; (U)INT Mul
    mov [rsp+0], r8
    mov r8, 8 ; Load INT
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline calloc call
    call calloc
    add rsp, 32
    mov r8, rax
    mov r9, qword [rbp+16] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, 0 ; Load INT
    mov r9, qword [rbp+16] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, 8 ; Load INT
    mov r9, qword [rbp+16] ; Get Arg/Local
    lea r9, [r9+16] ; Field access
    mov [r9], r8 ; Mutate
    movsd xmm0, [C0] ; Load F64
    mov r8, qword [rbp+16] ; Get Arg/Local
    lea r8, [r8+24] ; Field access
    movq [r8], xmm0 ; Mutate
    xor eax, eax
.L0:
    xor eax, eax
    pop rbp
    ret

__stringhashmap__StringHashMap_string__put:
    sub rsp, 16 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, 0 ; Load NULLPTR
    mov r8, 0 ; Load NULLPTR
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov r9, 1 ; Load INT
    add r8, r9 ; (U)INT Add
    cvtsi2sd xmm0, r8 ; Non-floating point to F64
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    cvtsi2sd xmm1, r8 ; Non-floating point to F64
    divsd xmm0, xmm1 ; Float Div
    mov r8, qword [rbp+32] ; Get Arg/Local
    movsd xmm1, [r8+24] ; Field access
    comisd xmm0, xmm1 ; Float >
    seta al
    movzx r8, al
    test r8, r8
    jz .L2
    lea r8, [StringHashMap_string__resize] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
.L2:
    lea r8, [StringHashMap_string__get_entry] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], r8
    lea r8, [rbp+8] ; Get Local
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    mov [rbp + 16], r8b ; Declare identifier
    movzx r8, byte [rbp+16] ; Get Arg/Local
    test r8, r8
    jz .L3
    lea r8, [__stringhashmap__Entry_string__deinit] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    jmp .L4
.L3:
    mov r8, 1 ; Load INT
    mov r9, qword [rbp+32] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    add [r9], r8 ; Mutate
.L4:
    lea r8, [__stringhashmap__Entry_string__init] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], r8
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    movzx r8, byte [rbp+16] ; Get Arg/Local
    mov rax, r8
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
    lea r8, [StringHashMap_string__get_entry] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], r8
    lea r8, [rbp+8] ; Get Local
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    mov [rbp + 16], r8b ; Declare identifier
    movzx r8, byte [rbp+16] ; Get Arg/Local
    test r8, r8 ; If Expr
    jz .L6
    mov r8, qword [rbp+8] ; Get Arg/Local
    lea r8, [r8+16] ; Field access
    jmp .L7
.L6:
    mov r8, 0 ; Load NULLPTR
.L7: ; End of If Expr
    mov rax, r8
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
    lea r8, [StringHashMap_string__get_entry] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], r8
    lea r8, [rbp+8] ; Get Local
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    mov [rbp + 16], r8b ; Declare identifier
    movzx r8, byte [rbp+16] ; Get Arg/Local
    test r8, r8
    jz .L9
    lea r8, [__string__String__deinit] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    mov r8, 1 ; Load INT
    mov r9, qword [rbp+8] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, 0 ; Load INT
    mov r9, qword [rbp+8] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, 1 ; Load INT
    mov r9, qword [rbp+32] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    sub [r9], r8 ; Mutate
.L9:
    movzx r8, byte [rbp+16] ; Get Arg/Local
    mov rax, r8
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
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov [rbp + 24], r8 ; Declare identifier
    sub rsp, 24 ; Make space for native args
    lea r8, [C1]
    mov [rsp+0], r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    pop rdx
    pop r8
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    mov r8, 0 ; Load INT
    mov [rbp + 32], r8 ; Declare identifier
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Exit check
    jz .L11
.L12:
    lea r8, [__stringhashmap__Entry_string__display] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    imul r9, 32
    lea r8, [r8+r9] ; Ptr Index
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
.L13:
    mov r8, 1 ; Load INT
    lea r9, [rbp+32] ; Get Local
    add [r9], r8 ; Mutate
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L12
.L11:
    sub rsp, 24 ; Make space for native args
    lea r8, [C2]
    mov [rsp+0], r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    pop rdx
    pop r8
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
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
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, 2 ; Load INT
    imul r8, r9 ; (U)INT Mul
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rbp + 24], r8 ; Declare identifier
    sub rsp, 24 ; Make space for native args
    mov r8, qword [__SIZE_OF_STRING] ; Get Global
    mov r9, 2 ; Load INT
    imul r8, r9 ; (U)INT Mul
    mov [rsp+0], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline calloc call
    call calloc
    add rsp, 32
    add rsp, 8
    mov r8, rax
    mov r9, qword [rbp+56] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+56] ; Get Arg/Local
    lea r9, [r9+16] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, 0 ; Load INT
    mov [rbp + 32], r8 ; Declare identifier
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Exit check
    jz .L15
.L16:
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    imul r9, 32
    lea r8, [r8+r9] ; Ptr Index
    mov [rbp + 40], r8 ; Declare identifier
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, 1 ; Load INT
    cmp r8, r9 ; UINT >
    seta al
    movzx r8, al
    test r8, r8
    jz .L18
    lea r8, [StringHashMap_string__insert_no_check] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 24
    mov r8, rax
.L18:
.L17:
    mov r8, 1 ; Load INT
    lea r9, [rbp+32] ; Get Local
    add [r9], r8 ; Mutate
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L16
.L15:
    sub rsp, 16 ; Make space for native args
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    add rsp, 8
    mov r8, rax
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
    lea r8, [StringHashMap_string__get_entry] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], r8
    lea r8, [rbp+8] ; Get Local
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 24
    mov r8, rax
    lea r8, [__stringhashmap__Entry_string__copy_from] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    lea r8, [r8+16] ; Field access
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 24
    mov r8, rax
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
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rbp + 16], r8 ; Declare identifier
    lea r8, [__string__String__hash] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    mov r9, qword [rbp+8] ; Get Arg/Local
    mov rax, r8 ; (U)INT Mod
    xor edx, edx
    idiv r9
    mov r8, rdx
    mov [rbp + 24], r8 ; Declare identifier
    lea r8, [__string__String__eql] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 32
    lea r8, [r8+r9] ; Ptr Index
    mov [rsp+8], r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    mov [rbp + 32], r8b ; Declare identifier
    movzx r8, byte [rbp+32] ; Get Arg/Local
    xor r8, 1 ; Bool not
    test r8, r8 ; Logical AND
    jz .L22
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 32
    lea r8, [r8+r9] ; Ptr Index
    mov r8, qword [r8+0] ; Field access
    mov r9, 1 ; Load INT
    cmp r8, r9 ; UINT >=
    setae al
    movzx r8, al
.L22:
    test r8, r8 ; Exit check
    jz .L21
.L23:
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r9, 1 ; Load INT
    add r8, r9 ; (U)INT Add
    mov r9, qword [rbp+8] ; Get Arg/Local
    mov rax, r8 ; (U)INT Mod
    xor edx, edx
    idiv r9
    mov r8, rdx
    lea r9, [rbp+24] ; Get Local
    mov [r9], r8 ; Mutate
    lea r8, [__string__String__eql] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 32
    lea r8, [r8+r9] ; Ptr Index
    mov [rsp+8], r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    lea r9, [rbp+32] ; Get Local
    mov [r9], r8b ; Mutate
.L24:
    movzx r8, byte [rbp+32] ; Get Arg/Local
    xor r8, 1 ; Bool not
    test r8, r8 ; Logical AND
    jz .L25
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 32
    lea r8, [r8+r9] ; Ptr Index
    mov r8, qword [r8+0] ; Field access
    mov r9, 1 ; Load INT
    cmp r8, r9 ; UINT >=
    setae al
    movzx r8, al
.L25:
    test r8, r8 ; Loop check
    jnz .L23
.L21:
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 32
    lea r8, [r8+r9] ; Ptr Index
    mov r9, qword [rbp+64] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    movzx r8, byte [rbp+32] ; Get Arg/Local
    mov rax, r8
    jmp .L20
    xor eax, eax
.L20:
    pop rbp
    add rsp, 32
    ret

__stringhashmap__Entry_string__init:
    push rbp
    mov rbp, rsp
    lea r8, [__string__String__init_from] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    lea r8, [__string__String__init_from] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    lea r8, [r8+16] ; Field access
    mov [rsp+8], r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor eax, eax
.L26:
    xor eax, eax
    pop rbp
    ret

__stringhashmap__Entry_string__deinit:
    push rbp
    mov rbp, rsp
    lea r8, [__string__String__deinit] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    lea r8, [__string__String__deinit] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    lea r8, [r8+16] ; Field access
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor eax, eax
.L27:
    xor eax, eax
    pop rbp
    ret

__stringhashmap__Entry_string__copy_from:
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    mov rsi, r8
    lea rdi, [r9+0]
    mov rcx, 16
    rep movsb
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    lea r9, [r9+16] ; Field access
    mov rsi, r8
    lea rdi, [r9+0]
    mov rcx, 16
    rep movsb
    xor eax, eax
.L28:
    xor eax, eax
    pop rbp
    ret

__stringhashmap__Entry_string__display:
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, 1 ; Load INT
    cmp r8, r9 ; UINT >
    seta al
    movzx r8, al
    test r8, r8 ; Logical AND
    jz .L30
    mov r8, qword [rbp+16] ; Get Arg/Local
    lea r8, [r8+16] ; Field access
    mov r8, qword [r8+0] ; Field access
    mov r9, 1 ; Load INT
    cmp r8, r9 ; UINT >
    seta al
    movzx r8, al
.L30:
    test r8, r8
    jz .L31
    sub rsp, 48 ; Make space for native args
    lea r8, [C3]
    mov [rsp+0], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov [rsp+8], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rsp+16], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    lea r8, [r8+16] ; Field access
    mov r8, qword [r8+8] ; Field access
    mov [rsp+24], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    lea r8, [r8+16] ; Field access
    mov r8, qword [r8+0] ; Field access
    mov [rsp+32], r8
    pop rcx
    pop rdx
    pop r8
    pop r9
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 16
    mov r8, rax
    jmp .L32
.L31:
    sub rsp, 8 ; Make space for native args
    lea r8, [C4]
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
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
    C2: db `-- [End of StringHashMap] --\n`, 0
    C4: db `Entry: (Empty)\n`, 0
    C1: db `-- [StringHashMap, Entry: (Key: String, Value: String), Count: %lu, Capacity: %lu] --\n`, 0
    C3: db `Entry: (Key: \"%.*s\", Value: \"%.*s\")\n`, 0
section .bss
    @CLOCK_START: resb 8
    @ARGC: resb 8
    @ARGV: resb 8
    @ARG_BUFFER: resb 8

    ; Program Globals ;
