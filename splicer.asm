default rel
extern QueryPerformanceCounter
global main
section .text
main:
    ; Setup main args
    sub rsp, 24
    mov [rsp], rcx
    mov [rsp+8], rdx

    ; Setup clock
    push rax
    mov rcx, rsp
    sub rsp, 40
    call QueryPerformanceCounter
    add rsp, 40
    pop qword [@CLOCK_START]

    ; Global Declarations
    mov rsi, 32 ; Load UINT
    mov [_DEFAULT_DELIMINATOR], sil ; Declare identifier
    movsd xmm0, [C0] ; Load F64
    movsd [_MAX_DENSITY], xmm0 ; Declare identifier
    mov rsi, 16 ; Load INT
    mov [_SIZEOF_STRING], rsi ; Declare identifier
    mov rsi, qword [_SIZEOF_STRING] ; Get Global
    mov rdi, 8 ; Load INT
    add rsi, rdi ; (U)INT Add
    mov [_SIZEOF_ENTRY], rsi ; Declare identifier

    call _main ; Execute main
    add rsp, 24
    mov rcx, rax
    ret


_String_init:
    sub rsp, 8 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rbp + 8], rsi ; Declare identifier
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rsi, [rsi] ; Dereference Pointer
    mov rdi, 0 ; Load INT
    movzx rsi, sil
    cmp rsi, rdi ; UINT !=
    setne al
    movzx rsi, al
    test rsi, rsi ; Exit check
    jz .L1
.L2:
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, 1 ; Load INT
    add rsi, rdi ; (U)INT Add
    lea rdi, [rbp+8] ; Get Local
    mov [rdi], rsi ; Mutate
.L3:
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rsi, [rsi] ; Dereference Pointer
    mov rdi, 0 ; Load INT
    movzx rsi, sil
    cmp rsi, rdi ; UINT !=
    setne al
    movzx rsi, al
    test rsi, rsi ; Loop check
    jnz .L2
.L1:
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    sub rsi, rdi ; (U)INT  Sub
    mov rdi, qword [rbp+24] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
.L0:
    xor eax, eax
    pop rbp
    add rsp, 8
    ret

_String_initLen:
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rdi, qword [rbp+16] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+16] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
.L4:
    xor eax, eax
    pop rbp
    ret

_String_eql:
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+24] ; Get Arg/Local
    mov rdi, qword [rdi+0] ; Field access
    cmp rsi, rdi ; INT ==
    sete al
    movzx rsi, al
    test rsi, rsi ; Logical AND
    jz .L6
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov rdi, qword [rbp+24] ; Get Arg/Local
    mov rdi, qword [rdi+8] ; Field access
    cmp rsi, rdi ; UINT ==
    sete al
    movzx rsi, al
.L6:
    mov rax, rsi
    jmp .L5
.L5:
    pop rbp
    ret

_String_cmp:
    sub rsp, 24 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov rdi, qword [rbp+48] ; Get Arg/Local
    mov rdi, qword [rdi+8] ; Field access
    cmp rsi, rdi ; UINT !=
    setne al
    movzx rsi, al
    test rsi, rsi
    jz .L8
    mov rsi, 0 ; Load BOOL
    mov rax, rsi
    jmp .L7
.L8:
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rbp + 8], rsi ; Declare identifier
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rbp + 16], rsi ; Declare identifier
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+40] ; Get Arg/Local
    mov rdi, qword [rdi+8] ; Field access
    add rsi, rdi ; (U)INT Add
    mov [rbp + 24], rsi ; Declare identifier
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    cmp rsi, rdi ; UINT <
    setb al
    movzx rsi, al
    test rsi, rsi ; Exit check
    jz .L9
.L10:
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rsi, [rsi] ; Dereference Pointer
    mov rdi, qword [rbp+16] ; Get Arg/Local
    mov rdi, [rdi] ; Dereference Pointer
    movzx rsi, sil
    movzx rdi, dil
    cmp rsi, rdi ; UINT !=
    setne al
    movzx rsi, al
    test rsi, rsi
    jz .L12
    mov rsi, 0 ; Load BOOL
    mov rax, rsi
    jmp .L7
.L12:
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, 1 ; Load INT
    add rsi, rdi ; (U)INT Add
    lea rdi, [rbp+8] ; Get Local
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, 1 ; Load INT
    add rsi, rdi ; (U)INT Add
    lea rdi, [rbp+16] ; Get Local
    mov [rdi], rsi ; Mutate
.L11:
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    cmp rsi, rdi ; UINT <
    setb al
    movzx rsi, al
    test rsi, rsi ; Loop check
    jnz .L10
.L9:
    mov rsi, 1 ; Load BOOL
    mov rax, rsi
    jmp .L7
.L7:
    pop rbp
    add rsp, 24
    ret

_String_isEmpty:
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, 0 ; Load NULLPTR
    cmp rsi, rdi ; INT ==
    sete al
    movzx rsi, al
    mov rax, rsi
    jmp .L13
.L13:
    pop rbp
    ret

_String_hash:
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
    jz .L15
.L16:
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
.L17:
    mov rsi, 1 ; Load INT
    lea rdi, [rbp+32] ; Get Local
    add [rdi], rsi ; Mutate
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+24] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Loop check
    jnz .L16
.L15:
    mov esi, dword [rbp+8] ; Get Arg/Local
    mov rax, rsi
    jmp .L14
.L14:
    pop rbp
    add rsp, 32
    ret

_String_display:
    push rbp
    mov rbp, rsp
    sub rsp, 32 ; Make space for native args
    lea rsi, [C1]
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
    add rsp, 8
    mov rsi, rax
.L18:
    xor eax, eax
    pop rbp
    ret

_Splicer_init:
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
    movzx rsi, byte [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+16] ; Get Arg/Local
    lea rdi, [rdi+16] ; Field access
    mov [rdi], sil ; Mutate
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, 1 ; Load INT
    sub rsi, rdi ; (U)INT  Sub
    mov rdi, qword [rbp+16] ; Get Arg/Local
    lea rdi, [rdi+24] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rdi+8] ; Field access
    add rsi, rdi ; (U)INT Add
    mov rdi, qword [rbp+16] ; Get Arg/Local
    lea rdi, [rdi+32] ; Field access
    mov [rdi], rsi ; Mutate
.L19:
    xor eax, eax
    pop rbp
    ret

_Splicer_next:
    sub rsp, 24 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea rsi, [_Splicer_atEnd] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    test rsi, rsi
    jz .L21
    mov rsi, 0 ; Load NULLPTR
    mov rdi, qword [rbp+48] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, 0 ; Load INT
    mov rdi, qword [rbp+48] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, 0 ; Load BOOL
    mov rax, rsi
    jmp .L20
.L21:
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+24] ; Field access
    mov rdi, 1 ; Load INT
    add rsi, rdi ; (U)INT Add
    mov rdi, qword [rbp+40] ; Get Arg/Local
    lea rdi, [rdi+24] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+40] ; Get Arg/Local
    movzx rsi, byte [rsi+16] ; Field access
    mov [rbp + 8], sil ; Declare identifier
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+24] ; Field access
    mov [rbp + 16], rsi ; Declare identifier
    lea rsi, [_Splicer_atEnd] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    xor rsi, 1 ; Bool not
    test rsi, rsi ; Logical AND
    jz .L23
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+24] ; Field access
    mov rsi, [rsi] ; Dereference Pointer
    movzx rdi, byte [rbp+8] ; Get Arg/Local
    movzx rsi, sil
    movzx rdi, dil
    cmp rsi, rdi ; UINT !=
    setne al
    movzx rsi, al
.L23:
    test rsi, rsi ; Exit check
    jz .L22
.L24:
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+24] ; Field access
    mov rdi, 1 ; Load INT
    add rsi, rdi ; (U)INT Add
    mov rdi, qword [rbp+40] ; Get Arg/Local
    lea rdi, [rdi+24] ; Field access
    mov [rdi], rsi ; Mutate
.L25:
    lea rsi, [_Splicer_atEnd] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    xor rsi, 1 ; Bool not
    test rsi, rsi ; Logical AND
    jz .L26
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+24] ; Field access
    mov rsi, [rsi] ; Dereference Pointer
    movzx rdi, byte [rbp+8] ; Get Arg/Local
    movzx rsi, sil
    movzx rdi, dil
    cmp rsi, rdi ; UINT !=
    setne al
    movzx rsi, al
.L26:
    test rsi, rsi ; Loop check
    jnz .L24
.L22:
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+24] ; Field access
    mov rdi, qword [rbp+16] ; Get Arg/Local
    sub rsi, rdi ; (U)INT  Sub
    mov [rbp + 24], rsi ; Declare identifier
    lea rsi, [_String_initLen] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov [rsp+16], rsi
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    mov rsi, 1 ; Load BOOL
    mov rax, rsi
    jmp .L20
.L20:
    pop rbp
    add rsp, 24
    ret

_Splicer_atEnd:
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+24] ; Field access
    mov rdi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rdi+32] ; Field access
    cmp rsi, rdi ; UINT >=
    setae al
    movzx rsi, al
    mov rax, rsi
    jmp .L27
.L27:
    pop rbp
    ret

_Dictionary_init:
    push rbp
    mov rbp, rsp
    sub rsp, 24 ; Make space for native args
    mov rsi, 8 ; Load INT
    mov [rsp+0], rsi
    mov rsi, qword [_SIZEOF_ENTRY] ; Get Global
    mov [rsp+8], rsi
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline calloc call
    call calloc
    add rsp, 32
    add rsp, 8
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
.L28:
    xor eax, eax
    pop rbp
    ret

_Dictionary_resize:
    sub rsp, 40 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rbp + 8], rsi ; Declare identifier
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov [rbp + 16], rsi ; Declare identifier
    sub rsp, 24 ; Make space for native args
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, 2 ; Load INT
    imul rsi, rdi ; (U)INT Mul
    mov [rsp+0], rsi
    mov rsi, qword [_SIZEOF_ENTRY] ; Get Global
    mov [rsp+8], rsi
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline calloc call
    call calloc
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    mov [rbp + 24], rsi ; Declare identifier
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rdi, qword [rbp+56] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, 2 ; Load INT
    imul rsi, rdi ; (U)INT Mul
    mov rdi, qword [rbp+56] ; Get Arg/Local
    lea rdi, [rdi+16] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, 0 ; Load INT
    mov rdi, qword [rbp+56] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, 0 ; Load INT
    mov [rbp + 32], rsi ; Declare identifier
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+16] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Exit check
    jz .L30
.L31:
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    imul rdi, 24
    lea rsi, [rsi+rdi] ; Ptr Index
    mov [rbp + 40], rsi ; Declare identifier
    lea rsi, [_String_isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    test rsi, rsi
    jz .L33
    jmp .L32
.L33:
    lea rsi, [_Dictionary_moveOverEntry] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
.L32:
    mov rsi, 1 ; Load INT
    lea rdi, [rbp+32] ; Get Local
    add [rdi], rsi ; Mutate
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, qword [rbp+16] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Loop check
    jnz .L31
.L30:
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    add rsp, 8
    mov rsi, rax
.L29:
    xor eax, eax
    pop rbp
    add rsp, 40
    ret

_Dictionary_moveOverEntry:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov [rbp + 8], rsi ; Declare identifier
    lea rsi, [_String_hash] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    mov [rbp + 16], rsi ; Declare identifier
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+8] ; Get Arg/Local
    mov rax, rsi ; (U)INT Mod
    xor edx, edx
    idiv rdi
    mov rsi, rdx
    mov [rbp + 24], rsi ; Declare identifier
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+24] ; Get Arg/Local
    imul rdi, 24
    lea rsi, [rsi+rdi] ; Ptr Index
    mov [rbp + 32], rsi ; Declare identifier
    lea rsi, [_String_isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    xor rsi, 1 ; Bool not
    test rsi, rsi ; Exit check
    jz .L35
.L36:
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
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+24] ; Get Arg/Local
    imul rdi, 24
    lea rsi, [rsi+rdi] ; Ptr Index
    lea rdi, [rbp+32] ; Get Local
    mov [rdi], rsi ; Mutate
.L37:
    lea rsi, [_String_isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    xor rsi, 1 ; Bool not
    test rsi, rsi ; Loop check
    jnz .L36
.L35:
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+32] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov rdi, qword [rbp+32] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+64] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    lea rdi, [rdi+16] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, 1 ; Load INT
    mov rdi, qword [rbp+48] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    add [rdi], rsi ; Mutate
.L34:
    xor eax, eax
    pop rbp
    add rsp, 32
    ret

_Dictionary_addEntry:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, 1 ; Load INT
    mov rdi, qword [rbp+48] ; Get Arg/Local
    mov rdi, qword [rdi+8] ; Field access
    add rsi, rdi ; (U)INT Add
    cvtsi2sd xmm0, rsi ; Non-floating point to F64
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    cvtsi2sd xmm1, rsi ; Non-floating point to F64
    divsd xmm0, xmm1 ; Float Div
    movsd xmm1, qword [_MAX_DENSITY] ; Get Global
    comisd xmm0, xmm1 ; Float >
    seta al
    movzx rsi, al
    test rsi, rsi
    jz .L39
    lea rsi, [_Dictionary_resize] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
.L39:
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov [rbp + 8], rsi ; Declare identifier
    lea rsi, [_String_hash] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    mov [rbp + 16], rsi ; Declare identifier
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+8] ; Get Arg/Local
    mov rax, rsi ; (U)INT Mod
    xor edx, edx
    idiv rdi
    mov rsi, rdx
    mov [rbp + 24], rsi ; Declare identifier
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+24] ; Get Arg/Local
    imul rdi, 24
    lea rsi, [rsi+rdi] ; Ptr Index
    mov [rbp + 32], rsi ; Declare identifier
    lea rsi, [_String_isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    xor rsi, 1 ; Bool not
    test rsi, rsi ; Logical AND
    jz .L41
    lea rsi, [_String_cmp] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    xor rsi, 1 ; Bool not
.L41:
    test rsi, rsi ; Exit check
    jz .L40
.L42:
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
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+24] ; Get Arg/Local
    imul rdi, 24
    lea rsi, [rsi+rdi] ; Ptr Index
    lea rdi, [rbp+32] ; Get Local
    mov [rdi], rsi ; Mutate
.L43:
    lea rsi, [_String_isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    xor rsi, 1 ; Bool not
    test rsi, rsi ; Logical AND
    jz .L44
    lea rsi, [_String_cmp] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    xor rsi, 1 ; Bool not
.L44:
    test rsi, rsi ; Loop check
    jnz .L42
.L40:
    lea rsi, [_String_isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    test rsi, rsi
    jz .L45
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+32] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov rdi, qword [rbp+32] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, 1 ; Load INT
    mov rdi, qword [rbp+32] ; Get Arg/Local
    lea rdi, [rdi+16] ; Field access
    mov [rdi], rsi ; Mutate
    mov rsi, 1 ; Load INT
    mov rdi, qword [rbp+48] ; Get Arg/Local
    lea rdi, [rdi+8] ; Field access
    add [rdi], rsi ; Mutate
    mov rsi, 0 ; Load BOOL
    mov rax, rsi
    jmp .L38
    jmp .L46
.L45:
    mov rsi, 1 ; Load INT
    mov rdi, qword [rbp+32] ; Get Arg/Local
    lea rdi, [rdi+16] ; Field access
    add [rdi], rsi ; Mutate
    mov rsi, 1 ; Load BOOL
    mov rax, rsi
    jmp .L38
.L46:
.L38:
    pop rbp
    add rsp, 32
    ret

_Dictionary_getEntry:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov [rbp + 8], rsi ; Declare identifier
    lea rsi, [_String_hash] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    mov [rbp + 16], rsi ; Declare identifier
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rdi, qword [rbp+8] ; Get Arg/Local
    mov rax, rsi ; (U)INT Mod
    xor edx, edx
    idiv rdi
    mov rsi, rdx
    mov [rbp + 24], rsi ; Declare identifier
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+24] ; Get Arg/Local
    imul rdi, 24
    lea rsi, [rsi+rdi] ; Ptr Index
    mov [rbp + 32], rsi ; Declare identifier
    lea rsi, [_String_isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    xor rsi, 1 ; Bool not
    test rsi, rsi ; Logical AND
    jz .L49
    lea rsi, [_String_cmp] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    xor rsi, 1 ; Bool not
.L49:
    test rsi, rsi ; Exit check
    jz .L48
.L50:
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
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+24] ; Get Arg/Local
    imul rdi, 24
    lea rsi, [rsi+rdi] ; Ptr Index
    lea rdi, [rbp+32] ; Get Local
    mov [rdi], rsi ; Mutate
.L51:
    lea rsi, [_String_isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    xor rsi, 1 ; Bool not
    test rsi, rsi ; Logical AND
    jz .L52
    lea rsi, [_String_cmp] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    xor rsi, 1 ; Bool not
.L52:
    test rsi, rsi ; Loop check
    jnz .L50
.L48:
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov rdi, qword [rbp+64] ; Get Arg/Local
    mov [rdi], rsi ; Mutate
    lea rsi, [_String_isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    xor rsi, 1 ; Bool not
    mov rax, rsi
    jmp .L47
.L47:
    pop rbp
    add rsp, 32
    ret

_Dictionary_display:
    sub rsp, 40 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, 0 ; Load INT
    mov [rbp + 8], rsi ; Declare identifier
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov [rbp + 16], rsi ; Declare identifier
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, 0 ; Load INT
    imul rdi, 24
    lea rsi, [rsi+rdi] ; Ptr Index
    mov [rbp + 24], rsi ; Declare identifier
    mov rsi, 0 ; Load INT
    mov [rbp + 32], rsi ; Declare identifier
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+16] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Exit check
    jz .L54
.L55:
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov rdi, qword [rbp+8] ; Get Arg/Local
    imul rdi, 24
    lea rsi, [rsi+rdi] ; Ptr Index
    mov [rbp + 40], rsi ; Declare identifier
    lea rsi, [_String_isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    test rsi, rsi
    jz .L57
    sub rsp, 16 ; Make space for native args
    lea rsi, [C2]
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    jmp .L58
.L57:
    sub rsp, 40 ; Make space for native args
    lea rsi, [C3]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rsp+8], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rsp+16], rsi
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov [rsp+24], rsi
    pop rcx
    pop rdx
    pop r8
    pop r9
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov rdi, qword [rbp+24] ; Get Arg/Local
    mov rdi, qword [rdi+16] ; Field access
    cmp rsi, rdi ; INT >
    setg al
    movzx rsi, al
    test rsi, rsi
    jz .L59
    mov rsi, qword [rbp+40] ; Get Arg/Local
    lea rdi, [rbp+24] ; Get Local
    mov [rdi], rsi ; Mutate
.L59:
    mov rsi, qword [rbp+40] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    lea rdi, [rbp+32] ; Get Local
    add [rdi], rsi ; Mutate
.L58:
.L56:
    mov rsi, 1 ; Load INT
    lea rdi, [rbp+8] ; Get Local
    add [rdi], rsi ; Mutate
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov rdi, qword [rbp+16] ; Get Arg/Local
    cmp rsi, rdi ; INT <
    setl al
    movzx rsi, al
    test rsi, rsi ; Loop check
    jnz .L55
.L54:
    sub rsp, 24 ; Make space for native args
    lea rsi, [C4]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    sub rsp, 24 ; Make space for native args
    lea rsi, [C5]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rsp+8], rsi
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    sub rsp, 16 ; Make space for native args
    lea rsi, [C6]
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    sub rsp, 40 ; Make space for native args
    lea rsi, [C3]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rsp+8], rsi
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rsp+16], rsi
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rsi, qword [rsi+16] ; Field access
    mov [rsp+24], rsi
    pop rcx
    pop rdx
    pop r8
    pop r9
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
.L53:
    xor eax, eax
    pop rbp
    add rsp, 40
    ret

_Dictionary_free:
    push rbp
    mov rbp, rsp
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [rbp+16] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    add rsp, 8
    mov rsi, rax
.L60:
    xor eax, eax
    pop rbp
    ret

_main:
    sub rsp, 168 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov rsi, qword [rbp+184] ; Get Arg/Local
    mov rdi, 2 ; Load INT
    cmp rsi, rdi ; INT !=
    setne al
    movzx rsi, al
    test rsi, rsi ; Logical AND
    jz .L62
    mov rsi, qword [rbp+184] ; Get Arg/Local
    mov rdi, 3 ; Load INT
    cmp rsi, rdi ; INT !=
    setne al
    movzx rsi, al
.L62:
    test rsi, rsi
    jz .L63
    sub rsp, 16 ; Make space for native args
    lea rsi, [C7]
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    mov rsi, 1 ; Load INT
    mov rax, rsi
    jmp .L61
.L63:
    mov rsi, qword [rbp+192] ; Get Arg/Local
    mov rdi, 1 ; Load INT
    imul rdi, 8
    mov rsi, [rsi+rdi] ; Ptr Index
    mov [rbp + 8], rsi ; Declare identifier
    mov rsi, qword [rbp+184] ; Get Arg/Local
    mov rdi, 3 ; Load INT
    cmp rsi, rdi ; INT ==
    sete al
    movzx rsi, al
    test rsi, rsi ; If Expr
    jz .L64
    mov rsi, qword [rbp+192] ; Get Arg/Local
    mov rdi, 2 ; Load INT
    imul rdi, 8
    mov rsi, [rsi+rdi] ; Ptr Index
    mov rdi, 0 ; Load INT
    imul rdi, 1
    movzx rsi, byte [rsi+rdi] ; Ptr Index
    jmp .L65
.L64:
    movzx rsi, byte [_DEFAULT_DELIMINATOR] ; Get Global
.L65: ; End of If Expr
    mov [rbp + 16], sil ; Declare identifier
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    mov rdx, 0xC0000000
    mov r8, 3
    mov r9, 0
    push 0
    push 0x80
    push 3
    sub rsp, 32 ; Open file call
    call CreateFileA
    add rsp, 56
    add rsp, 8
    mov rsi, rax
    mov [rbp + 24], rsi ; Declare identifier
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov rdi, 1 ; Load INT
    neg rdi ; (U)INT negate
    cmp rsi, rdi ; INT ==
    sete al
    movzx rsi, al
    test rsi, rsi
    jz .L66
    sub rsp, 24 ; Make space for native args
    lea rsi, [C8]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    mov rsi, 1 ; Load INT
    mov rax, rsi
    jmp .L61
.L66:
    mov rsi, 0 ; Load INT
    mov [rbp + 32], rsi ; Declare identifier
    sub rsp, 24 ; Make space for native args
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+0], rsi
    lea rsi, [rbp+32] ; Get Local
    mov [rsp+8], rsi
    pop rcx
    pop rdx
    sub rsp, 32 ; Get size of file call
    call GetFileSizeEx
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    mov [rbp + 40], sil ; Declare identifier
    movzx rsi, byte [rbp+40] ; Get Arg/Local
    xor rsi, 1 ; Bool not
    test rsi, rsi
    jz .L67
    sub rsp, 24 ; Make space for native args
    lea rsi, [C9]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    mov rsi, 1 ; Load INT
    mov rax, rsi
    jmp .L61
.L67:
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov rdi, 0 ; Load INT
    cmp rsi, rdi ; UINT ==
    sete al
    movzx rsi, al
    test rsi, rsi
    jz .L68
    sub rsp, 24 ; Make space for native args
    lea rsi, [C10]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    mov rsi, 0 ; Load INT
    mov rax, rsi
    jmp .L61
.L68:
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline malloc call
    call malloc
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    mov [rbp + 48], rsi ; Declare identifier
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov rdi, 0 ; Load NULLPTR
    cmp rsi, rdi ; INT ==
    sete al
    movzx rsi, al
    test rsi, rsi
    jz .L69
    sub rsp, 32 ; Make space for native args
    lea rsi, [C11]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+16], rsi
    pop rcx
    pop rdx
    pop r8
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    mov rsi, 1 ; Load INT
    mov rax, rsi
    jmp .L61
.L69:
    mov rsi, 0 ; Load INT
    mov [rbp + 56], rsi ; Declare identifier
    sub rsp, 40 ; Make space for native args
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+0], rsi
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], rsi
    lea rsi, [rbp+56] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    pop rdx
    pop r8
    pop r9
    push 0
    sub rsp, 32 ; Read call
    call ReadFile
    add rsp, 40
    add rsp, 8
    mov rsi, rax
    mov [rbp + 64], sil ; Declare identifier
    movzx rsi, byte [rbp+64] ; Get Arg/Local
    xor rsi, 1 ; Bool not
    test rsi, rsi ; Logical OR
    jnz .L70
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov rdi, qword [rbp+32] ; Get Arg/Local
    cmp rsi, rdi ; UINT !=
    setne al
    movzx rsi, al
.L70:
    test rsi, rsi
    jz .L71
    sub rsp, 24 ; Make space for native args
    lea rsi, [C12]
    mov [rsp+0], rsi
    mov rsi, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], rsi
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    mov rsi, 1 ; Load INT
    mov rax, rsi
    jmp .L61
.L71:
    lea rsi, [_Dictionary_init] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+72] ; Get Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    lea rsi, [_String_initLen] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+96] ; Get Local
    mov [rsp+8], rsi
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov [rsp+16], rsi
    mov rsi, qword [rbp+56] ; Get Arg/Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [_Splicer_init] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+112] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+96] ; Get Local
    mov [rsp+16], rsi
    movzx rsi, byte [rbp+16] ; Get Arg/Local
    mov [rsp+24], sil
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [_Splicer_next] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+112] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+152] ; Get Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    test rsi, rsi ; Exit check
    jz .L72
.L73:
    lea rsi, [_Dictionary_addEntry] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+72] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+152] ; Get Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
.L74:
    lea rsi, [_Splicer_next] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+112] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+152] ; Get Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    test rsi, rsi ; Loop check
    jnz .L73
.L72:
    lea rsi, [_Dictionary_display] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+72] ; Get Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    lea rsi, [_Dictionary_free] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+72] ; Get Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [rbp+48] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    sub rsp, 16 ; Make space for native args
    mov rsi, qword [rbp+24] ; Get Arg/Local
    mov [rsp+0], rsi
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    sub rsp, 8 ; Make space for native args
    call @nanoTimestamp
    add rsp, 8
    mov rsi, rax
    cvtsi2sd xmm0, rsi ; Non-floating point to F64
    movsd xmm1, [C13] ; Load F64
    divsd xmm0, xmm1 ; Float Div
    movsd [rbp + 168], xmm0 ; Declare identifier
    sub rsp, 24 ; Make space for native args
    lea rsi, [C14]
    mov [rsp+0], rsi
    movsd xmm0, qword [rbp+168] ; Get Arg/Local
    movsd [rsp+8], xmm0
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
.L61:
    pop rbp
    add rsp, 168
    ret
    
;-------------------------;
;         Natives         ;
;-------------------------;
@nanoTimestamp:
    push rbp
    mov rbp, rsp
    push rax
    mov rcx, rsp
    sub rsp, 32
    call QueryPerformanceCounter
    add rsp, 32
    pop rax
    sub rax, [@CLOCK_START]
    imul rax, 100
    pop rbp
    ret

section .data
    ; Native Constants and Dependencies;
    @SS_SIGN_BIT: dq 0x80000000, 0, 0, 0
    @SD_SIGN_BIT: dq 0x8000000000000000, 0, 0, 0
    extern CloseHandle
    extern calloc
    extern printf
    extern malloc
    extern CreateFileA
    extern free
    extern ReadFile
    extern GetFileSizeEx

    ; Program Constants ;
    C8: db `Failed to open file: %s\n`, 0
    C7: db `Usage: splicer.exe path/to/file [deliminator]\n`, 0
    C6: db `Most common entry: `, 0
    C3: db `Key: '%.*s', Value: %i\n`, 0
    C0: dq 7.5e-1
    C14: db `Time to run: %f s\n`, 0
    C5: db `Total unique entries: %d\n`, 0
    C12: db `Failed to read file: %s\n`, 0
    C13: dq 1e9
    C1: db `\"%.*s\"\n`, 0
    C11: db `Failed to allocate read buffer of size %d bytes for file: %s\n`, 0
    C2: db `<Empty>\n`, 0
    C10: db `File is isEmpty: %s\n`, 0
    C9: db `Failed to get file size of file: %s\n`, 0
    C4: db `Total entries: %d\n`, 0

section .bss
    @CLOCK_START: resb 8

    ; Program Globals ;
    _MAX_DENSITY: resb 8
    _DEFAULT_DELIMINATOR: resb 1
    _SIZEOF_ENTRY: resb 8
    _SIZEOF_STRING: resb 8
