default rel
global _start
global __main
section .text
_start:
    ; Setup main args
    sub rsp, 40
    call GetCommandLineW ; Get Full string

    mov rcx, rax
    lea rdx, [@ARGC]
    call CommandLineToArgvW ; Split into wide substrings
    add rsp, 40
    mov [@ARGV], rax

    xor ebx, ebx
    xor esi, esi
    mov rdi, [@ARGC]
.BUFFER_SIZE_START:
    cmp rsi, rdi ; Test if i is less than argc
    jae .BUFFER_SIZE_END
    mov rcx, 65001
    xor edx, edx
    mov r8, [@ARGV]
    mov r8, [r8+rsi*8]
    mov r9, -1
    push 0
    push 0
    push 0
    push 0
    sub rsp, 40
    call WideCharToMultiByte ; Get the length of current argv[i] conversion
    add rsp, 72
    inc rax
    add rbx, rax
    inc rsi
    jmp .BUFFER_SIZE_START
.BUFFER_SIZE_END:

    mov rcx, rbx
    sub rsp, 40
    call malloc ; Allocate space for argv buffer
    add rsp, 40
    mov [@ARG_BUFFER], rax

    xor esi, esi ; arg count
    xor edi, edi ; total length
.BUFFER_MAKE_START:
    cmp rsi, [@ARGC] ; Test if i is less than argc
    jae .BUFFER_MAKE_END
    mov rcx, 65001
    xor edx, edx
    mov r8, [@ARGV]
    mov r8, [r8+rsi*8]
    mov r9, -1
    push 0
    push 0
    push 0
    push rbx
    mov r15, [@ARG_BUFFER]
    lea r15, [r15+rdi]
    push r15
    sub rsp, 32
    call WideCharToMultiByte ; Convert argv[i] to utf8
    inc rax
    mov r14, [rsp+32]
    mov r15, [@ARGV]
    mov [r15+rsi*8], r14
    add rsp, 72
    add rdi, rax
    inc rsi
    jmp .BUFFER_MAKE_START
.BUFFER_MAKE_END:
    mov rcx, [@ARGC]
    mov rdx, [@ARGV]

    sub rsp, 16
    mov [rsp], rcx
    mov [rsp+8], rdx

    ; Setup clock
    push rax
    mov rcx, rsp
    sub rsp, 32
    call QueryPerformanceCounter
    add rsp, 32
    pop qword [@CLOCK_START]

    ; Global Declarations
    lea r8, [C0]
    mov [__DEFAULT_EXPORT_PATH], r8 ; Declare identifier
    mov r8, 32 ; Load UINT
    mov [__DEFAULT_DELIMITER], r8b ; Declare identifier
    movsd xmm0, [C1] ; Load F64
    movsd [__MAX_DENSITY], xmm0 ; Declare identifier
    mov r8, 16 ; Load INT
    mov [__SIZEOF_STRING], r8 ; Declare identifier
    mov r8, qword [__SIZEOF_STRING] ; Get Global
    mov r9, 8 ; Load INT
    add r8, r9 ; (U)INT Add
    mov [__SIZEOF_ENTRY], r8 ; Declare identifier

    call __main ; Execute main
    add rsp, 16
    push rax

    mov rcx, [@ARG_BUFFER]
    sub rsp, 32
    call free
    add rsp, 32

    mov rcx, [rsp]
    call ExitProcess
    ret

    
__String__init:
    sub rsp, 8 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r8, [r8] ; Dereference Pointer
    mov r9, 0 ; Load INT
    movzx r8, r8b
    cmp r8, r9 ; UINT !=
    setne al
    movzx r8, al
    test r8, r8 ; Exit check
    jz .L1
.L2:
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, 1 ; Load INT
    add r8, r9 ; (U)INT Add
    lea r9, [rbp+8] ; Get Local
    mov [r9], r8 ; Mutate
.L3:
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r8, [r8] ; Dereference Pointer
    mov r9, 0 ; Load INT
    movzx r8, r8b
    cmp r8, r9 ; UINT !=
    setne al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L2
.L1:
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    sub r8, r9 ; (U)INT  Sub
    mov r9, qword [rbp+24] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    xor eax, eax
.L0:
    xor eax, eax
    pop rbp
    add rsp, 8
    ret

__String__initLen:
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    xor eax, eax
.L4:
    xor eax, eax
    pop rbp
    ret

__String__eql:
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [r9+0] ; Field access
    cmp r8, r9 ; INT ==
    sete al
    movzx r8, al
    test r8, r8 ; Logical AND
    jz .L6
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov r9, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [r9+8] ; Field access
    cmp r8, r9 ; UINT ==
    sete al
    movzx r8, al
.L6:
    mov rax, r8
    jmp .L5
    xor eax, eax
.L5:
    pop rbp
    ret

__String__cmp:
    sub rsp, 24 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov r9, qword [rbp+48] ; Get Arg/Local
    mov r9, qword [r9+8] ; Field access
    cmp r8, r9 ; UINT !=
    setne al
    movzx r8, al
    test r8, r8
    jz .L8
    mov r8, 0 ; Load BOOL
    mov rax, r8
    jmp .L7
.L8:
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+40] ; Get Arg/Local
    mov r9, qword [r9+8] ; Field access
    add r8, r9 ; (U)INT Add
    mov [rbp + 24], r8 ; Declare identifier
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    cmp r8, r9 ; UINT <
    setb al
    movzx r8, al
    test r8, r8 ; Exit check
    jz .L9
.L10:
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r8, [r8] ; Dereference Pointer
    mov r9, qword [rbp+16] ; Get Arg/Local
    mov r9, [r9] ; Dereference Pointer
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT !=
    setne al
    movzx r8, al
    test r8, r8
    jz .L12
    mov r8, 0 ; Load BOOL
    mov rax, r8
    jmp .L7
.L12:
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, 1 ; Load INT
    add r8, r9 ; (U)INT Add
    lea r9, [rbp+8] ; Get Local
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, 1 ; Load INT
    add r8, r9 ; (U)INT Add
    lea r9, [rbp+16] ; Get Local
    mov [r9], r8 ; Mutate
.L11:
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    cmp r8, r9 ; UINT <
    setb al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L10
.L9:
    mov r8, 1 ; Load BOOL
    mov rax, r8
    jmp .L7
    xor eax, eax
.L7:
    pop rbp
    add rsp, 24
    ret

__String__isEmpty:
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, 0 ; Load NULLPTR
    cmp r8, r9 ; INT ==
    sete al
    movzx r8, al
    mov rax, r8
    jmp .L13
    xor eax, eax
.L13:
    pop rbp
    ret

__String__isZeroLength:
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov r9, 0 ; Load INT
    cmp r8, r9 ; UINT ==
    sete al
    movzx r8, al
    mov rax, r8
    jmp .L14
    xor eax, eax
.L14:
    pop rbp
    ret

__String__hash:
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
    jz .L16
.L17:
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
.L18:
    mov r8, 1 ; Load INT
    lea r9, [rbp+32] ; Get Local
    add [r9], r8 ; Mutate
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L17
.L16:
    mov r8d, dword [rbp+8] ; Get Arg/Local
    mov rax, r8
    jmp .L15
    xor eax, eax
.L15:
    pop rbp
    add rsp, 32
    ret

__String__trim:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, 0 ; Load INT
    mov [rbp + 24], r8 ; Declare identifier
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Logical AND
    jz .L21
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, 10 ; Load INT
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT ==
    sete al
    movzx r8, al
.L21:
    test r8, r8 ; Logical OR
    jnz .L22
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, 13 ; Load INT
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT ==
    sete al
    movzx r8, al
.L22:
    test r8, r8 ; Exit check
    jz .L20
.L23:
    mov r8, 1 ; Load INT
    lea r9, [rbp+24] ; Get Local
    add [r9], r8 ; Mutate
.L24:
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Logical AND
    jz .L25
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, 10 ; Load INT
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT ==
    sete al
    movzx r8, al
.L25:
    test r8, r8 ; Logical OR
    jnz .L26
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, 13 ; Load INT
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT ==
    sete al
    movzx r8, al
.L26:
    test r8, r8 ; Loop check
    jnz .L23
.L20:
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov r9, 1 ; Load INT
    sub r8, r9 ; (U)INT  Sub
    mov [rbp + 32], r8 ; Declare identifier
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, 0 ; Load INT
    cmp r8, r9 ; INT >
    setg al
    movzx r8, al
    test r8, r8 ; Logical AND
    jz .L28
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, 10 ; Load INT
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT ==
    sete al
    movzx r8, al
.L28:
    test r8, r8 ; Logical OR
    jnz .L29
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, 13 ; Load INT
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT ==
    sete al
    movzx r8, al
.L29:
    test r8, r8 ; Exit check
    jz .L27
.L30:
    mov r8, 1 ; Load INT
    lea r9, [rbp+32] ; Get Local
    sub [r9], r8 ; Mutate
.L31:
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, 0 ; Load INT
    cmp r8, r9 ; INT >
    setg al
    movzx r8, al
    test r8, r8 ; Logical AND
    jz .L32
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, 10 ; Load INT
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT ==
    sete al
    movzx r8, al
.L32:
    test r8, r8 ; Logical OR
    jnz .L33
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    mov r9, 13 ; Load INT
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT ==
    sete al
    movzx r8, al
.L33:
    test r8, r8 ; Loop check
    jnz .L30
.L27:
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    sub r8, r9 ; (U)INT  Sub
    mov r9, 1 ; Load INT
    add r8, r9 ; (U)INT Add
    mov r9, 0 ; Load INT
    cmp r8, r9 ; INT <=
    setle al
    movzx r8, al
    test r8, r8 ; If Expr
    jz .L34
    mov r8, 0 ; Load INT
    jmp .L35
.L34:
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    sub r8, r9 ; (U)INT  Sub
    mov r9, 1 ; Load INT
    add r8, r9 ; (U)INT Add
.L35: ; End of If Expr
    mov r9, qword [rbp+48] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 1
    lea r8, [r8+r9] ; Ptr Index
    mov r9, qword [rbp+48] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    xor eax, eax
.L19:
    xor eax, eax
    pop rbp
    add rsp, 32
    ret

__String__display:
    push rbp
    mov rbp, rsp
    sub rsp, 24 ; Make space for native args
    lea r8, [C2]
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
.L36:
    xor eax, eax
    pop rbp
    ret

__Splicer__init:
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+16] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov r9, qword [rbp+16] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    movzx r8, byte [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    lea r9, [r9+16] ; Field access
    mov [r9], r8b ; Mutate
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, 1 ; Load INT
    sub r8, r9 ; (U)INT  Sub
    mov r9, qword [rbp+16] ; Get Arg/Local
    lea r9, [r9+24] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [r9+8] ; Field access
    add r8, r9 ; (U)INT Add
    mov r9, qword [rbp+16] ; Get Arg/Local
    lea r9, [r9+32] ; Field access
    mov [r9], r8 ; Mutate
    xor eax, eax
.L37:
    xor eax, eax
    pop rbp
    ret

__Splicer__next:
    sub rsp, 24 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea r8, [__Splicer__atEnd] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 8
    mov r8, rax
    test r8, r8
    jz .L39
    mov r8, 0 ; Load NULLPTR
    mov r9, qword [rbp+48] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, 0 ; Load INT
    mov r9, qword [rbp+48] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, 0 ; Load BOOL
    mov rax, r8
    jmp .L38
.L39:
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+24] ; Field access
    mov r9, 1 ; Load INT
    add r8, r9 ; (U)INT Add
    mov r9, qword [rbp+40] ; Get Arg/Local
    lea r9, [r9+24] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+40] ; Get Arg/Local
    movzx r8, byte [r8+16] ; Field access
    mov [rbp + 8], r8b ; Declare identifier
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+24] ; Field access
    mov [rbp + 16], r8 ; Declare identifier
    lea r8, [__Splicer__atEnd] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 8
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8 ; Logical AND
    jz .L41
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+24] ; Field access
    mov r8, [r8] ; Dereference Pointer
    movzx r9, byte [rbp+8] ; Get Arg/Local
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT !=
    setne al
    movzx r8, al
.L41:
    test r8, r8 ; Exit check
    jz .L40
.L42:
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+24] ; Field access
    mov r9, 1 ; Load INT
    add r8, r9 ; (U)INT Add
    mov r9, qword [rbp+40] ; Get Arg/Local
    lea r9, [r9+24] ; Field access
    mov [r9], r8 ; Mutate
.L43:
    lea r8, [__Splicer__atEnd] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 8
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8 ; Logical AND
    jz .L44
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+24] ; Field access
    mov r8, [r8] ; Dereference Pointer
    movzx r9, byte [rbp+8] ; Get Arg/Local
    movzx r8, r8b
    movzx r9, r9b
    cmp r8, r9 ; UINT !=
    setne al
    movzx r8, al
.L44:
    test r8, r8 ; Loop check
    jnz .L42
.L40:
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+24] ; Field access
    mov r9, qword [rbp+16] ; Get Arg/Local
    sub r8, r9 ; (U)INT  Sub
    mov [rbp + 24], r8 ; Declare identifier
    lea r8, [__String__initLen] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+16], r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 24
    mov r8, rax
    mov r8, 1 ; Load BOOL
    mov rax, r8
    jmp .L38
    xor eax, eax
.L38:
    pop rbp
    add rsp, 24
    ret

__Splicer__atEnd:
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, qword [r8+24] ; Field access
    mov r9, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [r9+32] ; Field access
    cmp r8, r9 ; UINT >=
    setae al
    movzx r8, al
    mov rax, r8
    jmp .L45
    xor eax, eax
.L45:
    pop rbp
    ret

__Dictionary__init:
    push rbp
    mov rbp, rsp
    sub rsp, 16 ; Make space for native args
    mov r8, 8 ; Load INT
    mov [rsp+0], r8
    mov r8, qword [__SIZEOF_ENTRY] ; Get Global
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
    mov r8, 0 ; Load INT
    mov r9, qword [rbp+16] ; Get Arg/Local
    lea r9, [r9+24] ; Field access
    mov [r9], r8 ; Mutate
    xor eax, eax
.L46:
    xor eax, eax
    pop rbp
    ret

__Dictionary__resize:
    sub rsp, 40 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rbp + 16], r8 ; Declare identifier
    sub rsp, 24 ; Make space for native args
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, 2 ; Load INT
    imul r8, r9 ; (U)INT Mul
    mov [rsp+0], r8
    mov r8, qword [__SIZEOF_ENTRY] ; Get Global
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline calloc call
    call calloc
    add rsp, 32
    add rsp, 8
    mov r8, rax
    mov [rbp + 24], r8 ; Declare identifier
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [rbp+56] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, 2 ; Load INT
    imul r8, r9 ; (U)INT Mul
    mov r9, qword [rbp+56] ; Get Arg/Local
    lea r9, [r9+16] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, 0 ; Load INT
    mov r9, qword [rbp+56] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, 0 ; Load INT
    mov [rbp + 32], r8 ; Declare identifier
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Exit check
    jz .L48
.L49:
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    imul r9, 24
    lea r8, [r8+r9] ; Ptr Index
    mov [rbp + 40], r8 ; Declare identifier
    lea r8, [__String__isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 8
    mov r8, rax
    test r8, r8
    jz .L51
    jmp .L50
.L51:
    lea r8, [__Dictionary__moveOverEntry] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+16], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 24
    mov r8, rax
.L50:
    mov r8, 1 ; Load INT
    lea r9, [rbp+32] ; Get Local
    add [r9], r8 ; Mutate
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L49
.L48:
    sub rsp, 16 ; Make space for native args
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    add rsp, 8
    mov r8, rax
    xor eax, eax
.L47:
    xor eax, eax
    pop rbp
    add rsp, 40
    ret

__Dictionary__moveOverEntry:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rbp + 8], r8 ; Declare identifier
    lea r8, [__String__hash] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    mov rax, r8 ; (U)INT Mod
    xor edx, edx
    idiv r9
    mov r8, rdx
    mov [rbp + 24], r8 ; Declare identifier
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 24
    lea r8, [r8+r9] ; Ptr Index
    mov [rbp + 32], r8 ; Declare identifier
    lea r8, [__String__isEmpty] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8 ; Exit check
    jz .L53
.L54:
    mov r8, 1 ; Load INT
    lea r9, [rbp+24] ; Get Local
    add [r9], r8 ; Mutate
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, 1 ; Load INT
    sub r8, r9 ; (U)INT  Sub
    lea r9, [rbp+24] ; Get Local
    and [r9], r8 ; Mutate
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 24
    lea r8, [r8+r9] ; Ptr Index
    lea r9, [rbp+32] ; Get Local
    mov [r9], r8 ; Mutate
.L55:
    lea r8, [__String__isEmpty] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8 ; Loop check
    jnz .L54
.L53:
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+32] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov r9, qword [rbp+32] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+64] ; Get Arg/Local
    mov r9, qword [rbp+32] ; Get Arg/Local
    lea r9, [r9+16] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, 1 ; Load INT
    mov r9, qword [rbp+48] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    add [r9], r8 ; Mutate
    xor eax, eax
.L52:
    xor eax, eax
    pop rbp
    add rsp, 32
    ret

__Dictionary__addEntry:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, 1 ; Load INT
    mov r9, qword [rbp+48] ; Get Arg/Local
    mov r9, qword [r9+8] ; Field access
    add r8, r9 ; (U)INT Add
    cvtsi2sd xmm0, r8 ; Non-floating point to F64
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    cvtsi2sd xmm1, r8 ; Non-floating point to F64
    divsd xmm0, xmm1 ; Float Div
    movsd xmm1, qword [__MAX_DENSITY] ; Get Global
    comisd xmm0, xmm1 ; Float >
    seta al
    movzx r8, al
    test r8, r8
    jz .L57
    lea r8, [__Dictionary__resize] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
.L57:
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+24] ; Field access
    mov r9, qword [rbp+56] ; Get Arg/Local
    mov r9, qword [r9+8] ; Field access
    cmp r8, r9 ; UINT <
    setb al
    movzx r8, al
    test r8, r8
    jz .L58
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov r9, qword [rbp+48] ; Get Arg/Local
    lea r9, [r9+24] ; Field access
    mov [r9], r8 ; Mutate
.L58:
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rbp + 8], r8 ; Declare identifier
    lea r8, [__String__hash] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    mov rax, r8 ; (U)INT Mod
    xor edx, edx
    idiv r9
    mov r8, rdx
    mov [rbp + 24], r8 ; Declare identifier
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 24
    lea r8, [r8+r9] ; Ptr Index
    mov [rbp + 32], r8 ; Declare identifier
    lea r8, [__String__isEmpty] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8 ; Logical AND
    jz .L60
    lea r8, [__String__cmp] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
.L60:
    test r8, r8 ; Exit check
    jz .L59
.L61:
    mov r8, 1 ; Load INT
    lea r9, [rbp+24] ; Get Local
    add [r9], r8 ; Mutate
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, 1 ; Load INT
    sub r8, r9 ; (U)INT  Sub
    lea r9, [rbp+24] ; Get Local
    and [r9], r8 ; Mutate
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 24
    lea r8, [r8+r9] ; Ptr Index
    lea r9, [rbp+32] ; Get Local
    mov [r9], r8 ; Mutate
.L62:
    lea r8, [__String__isEmpty] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8 ; Logical AND
    jz .L63
    lea r8, [__String__cmp] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
.L63:
    test r8, r8 ; Loop check
    jnz .L61
.L59:
    lea r8, [__String__isEmpty] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    test r8, r8
    jz .L64
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+32] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov r9, qword [rbp+32] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, 1 ; Load INT
    mov r9, qword [rbp+32] ; Get Arg/Local
    lea r9, [r9+16] ; Field access
    mov [r9], r8 ; Mutate
    mov r8, 1 ; Load INT
    mov r9, qword [rbp+48] ; Get Arg/Local
    lea r9, [r9+8] ; Field access
    add [r9], r8 ; Mutate
    mov r8, 0 ; Load BOOL
    mov rax, r8
    jmp .L56
    jmp .L65
.L64:
    mov r8, 1 ; Load INT
    mov r9, qword [rbp+32] ; Get Arg/Local
    lea r9, [r9+16] ; Field access
    add [r9], r8 ; Mutate
    mov r8, 1 ; Load BOOL
    mov rax, r8
    jmp .L56
.L65:
    xor eax, eax
.L56:
    pop rbp
    add rsp, 32
    ret

__Dictionary__getEntry:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rbp + 8], r8 ; Declare identifier
    lea r8, [__String__hash] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+8] ; Get Arg/Local
    mov rax, r8 ; (U)INT Mod
    xor edx, edx
    idiv r9
    mov r8, rdx
    mov [rbp + 24], r8 ; Declare identifier
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 24
    lea r8, [r8+r9] ; Ptr Index
    mov [rbp + 32], r8 ; Declare identifier
    lea r8, [__String__isEmpty] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8 ; Logical AND
    jz .L68
    lea r8, [__String__cmp] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
.L68:
    test r8, r8 ; Exit check
    jz .L67
.L69:
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
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+24] ; Get Arg/Local
    imul r9, 24
    lea r8, [r8+r9] ; Ptr Index
    lea r9, [rbp+32] ; Get Local
    mov [r9], r8 ; Mutate
.L70:
    lea r8, [__String__isEmpty] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8 ; Logical AND
    jz .L71
    lea r8, [__String__cmp] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
.L71:
    test r8, r8 ; Loop check
    jnz .L69
.L67:
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov r9, qword [rbp+64] ; Get Arg/Local
    mov [r9], r8 ; Mutate
    lea r8, [__String__isEmpty] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
    mov rax, r8
    jmp .L66
    xor eax, eax
.L66:
    pop rbp
    add rsp, 32
    ret

__Dictionary__display:
    sub rsp, 40 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, 0 ; Load INT
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, 0 ; Load INT
    imul r9, 24
    lea r8, [r8+r9] ; Ptr Index
    mov [rbp + 24], r8 ; Declare identifier
    mov r8, 0 ; Load INT
    mov [rbp + 32], r8 ; Declare identifier
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Exit check
    jz .L73
.L74:
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+8] ; Get Arg/Local
    imul r9, 24
    lea r8, [r8+r9] ; Ptr Index
    mov [rbp + 40], r8 ; Declare identifier
    lea r8, [__String__isEmpty] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 8
    mov r8, rax
    test r8, r8
    jz .L76
    sub rsp, 16 ; Make space for native args
    lea r8, [C3]
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov r8, rax
    jmp .L77
.L76:
    sub rsp, 40 ; Make space for native args
    lea r8, [C4]
    mov [rsp+0], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov [rsp+8], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rsp+16], r8
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rsp+24], r8
    pop rcx
    pop rdx
    pop r8
    pop r9
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov r8, rax
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov r9, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [r9+16] ; Field access
    cmp r8, r9 ; INT >
    setg al
    movzx r8, al
    test r8, r8
    jz .L78
    mov r8, qword [rbp+40] ; Get Arg/Local
    lea r9, [rbp+24] ; Get Local
    mov [r9], r8 ; Mutate
.L78:
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    lea r9, [rbp+32] ; Get Local
    add [r9], r8 ; Mutate
.L77:
.L75:
    mov r8, 1 ; Load INT
    lea r9, [rbp+8] ; Get Local
    add [r9], r8 ; Mutate
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L74
.L73:
    sub rsp, 24 ; Make space for native args
    lea r8, [C5]
    mov [rsp+0], r8
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov r8, rax
    sub rsp, 24 ; Make space for native args
    lea r8, [C6]
    mov [rsp+0], r8
    mov r8, qword [rbp+56] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov r8, rax
    sub rsp, 16 ; Make space for native args
    lea r8, [C7]
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov r8, rax
    sub rsp, 40 ; Make space for native args
    lea r8, [C4]
    mov [rsp+0], r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r8, qword [r8+8] ; Field access
    mov [rsp+8], r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov [rsp+16], r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rsp+24], r8
    pop rcx
    pop rdx
    pop r8
    pop r9
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov r8, rax
    xor eax, eax
.L72:
    xor eax, eax
    pop rbp
    add rsp, 40
    ret

__Dictionary__export:
    sub rsp, 112 ; Reserve locals space
    push rbp
    mov rbp, rsp
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+136] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    mov rdx, 0xC0000000
    mov r8, 3
    mov r9, 0
    push 0
    push 0
    push 0x80
    push 1
    sub rsp, 32 ; Open file call
    call CreateFileA
    add rsp, 64
    mov r8, rax
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, 1 ; Load INT
    neg r9 ; (U)INT negate
    cmp r8, r9 ; INT ==
    sete al
    movzx r8, al
    test r8, r8
    jz .L80
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+136] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    mov rdx, 0xC0000000
    mov r8, 3
    mov r9, 0
    push 0
    push 0
    push 0x80
    push 3
    sub rsp, 32 ; Open file call
    call CreateFileA
    add rsp, 64
    mov r8, rax
    lea r9, [rbp+8] ; Get Local
    mov [r9], r8 ; Mutate
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov r9, 1 ; Load INT
    neg r9 ; (U)INT negate
    cmp r8, r9 ; INT ==
    sete al
    movzx r8, al
    test r8, r8
    jz .L81
    mov r8, 0 ; Load BOOL
    mov rax, r8
    jmp .L79
.L81:
.L80:
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+128] ; Get Arg/Local
    mov r8, qword [r8+24] ; Field access
    mov r9, 100 ; Load INT
    add r8, r9 ; (U)INT Add
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline malloc call
    call malloc
    add rsp, 32
    mov r8, rax
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, 0 ; Load INT
    mov [rbp + 24], r8 ; Declare identifier
    mov r8, 0 ; Load INT
    mov [rbp + 32], r8 ; Declare identifier
    mov r8, qword [rbp+128] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rbp + 40], r8 ; Declare identifier
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+40] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Exit check
    jz .L82
.L83:
    mov r8, qword [rbp+128] ; Get Arg/Local
    mov r8, qword [r8+0] ; Field access
    mov r9, qword [rbp+32] ; Get Arg/Local
    imul r9, 24
    lea r8, [r8+r9] ; Ptr Index
    mov [rbp + 48], r8 ; Declare identifier
    lea r8, [__String__isEmpty] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8
    jz .L85
    lea r8, [__Splicer__init] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push r8
    lea r8, [rbp+56] ; Get Local
    mov [rsp+8], r8
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov [rsp+16], r8
    mov r8, 34 ; Load UINT
    mov [rsp+24], r8b
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    mov r8, 34 ; Load UINT
    mov r9, qword [rbp+16] ; Get Arg/Local
    mov r10, 0 ; Load INT
    imul r10, 1
    lea r9, [r9+r10] ; Ptr Index
    mov [r9], r8b ; Mutate
    mov r8, 1 ; Load INT
    mov [rbp + 96], r8 ; Declare identifier
    lea r8, [__Splicer__next] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+56] ; Get Local
    mov [rsp+8], r8
    lea r8, [rbp+104] ; Get Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    sub rsp, 32 ; Make space for native args
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+96] ; Get Arg/Local
    imul r9, 1
    lea r8, [r8+r9] ; Ptr Index
    mov [rsp+0], r8
    lea r8, [C8]
    mov [rsp+8], r8
    lea r8, [rbp+104] ; Get Local
    mov r8, qword [r8+8] ; Field access
    mov [rsp+16], r8
    lea r8, [rbp+104] ; Get Local
    mov r8, qword [r8+0] ; Field access
    mov [rsp+24], r8
    pop rcx
    pop rdx
    pop r8
    pop r9
    sub rsp, 32 ; Inline sprintf call
    call sprintf
    add rsp, 32
    mov r8, rax
    lea r8, [rbp+104] ; Get Local
    mov r8, qword [r8+8] ; Field access
    lea r9, [rbp+96] ; Get Local
    add [r9], r8 ; Mutate
    lea r8, [__Splicer__next] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+56] ; Get Local
    mov [rsp+8], r8
    lea r8, [rbp+104] ; Get Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    test r8, r8 ; Exit check
    jz .L86
.L87:
    mov r8, 92 ; Load UINT
    mov r9, qword [rbp+16] ; Get Arg/Local
    mov r10, qword [rbp+96] ; Get Arg/Local
    imul r10, 1
    lea r9, [r9+r10] ; Ptr Index
    mov [r9], r8b ; Mutate
    mov r8, 34 ; Load UINT
    mov r9, qword [rbp+96] ; Get Arg/Local
    mov r10, 1 ; Load INT
    add r9, r10 ; (U)INT Add
    mov r10, qword [rbp+16] ; Get Arg/Local
    imul r9, 1
    lea r10, [r10+r9] ; Ptr Index
    mov [r10], r8b ; Mutate
    mov r8, 2 ; Load INT
    lea r9, [rbp+96] ; Get Local
    add [r9], r8 ; Mutate
    sub rsp, 32 ; Make space for native args
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+96] ; Get Arg/Local
    imul r9, 1
    lea r8, [r8+r9] ; Ptr Index
    mov [rsp+0], r8
    lea r8, [C8]
    mov [rsp+8], r8
    lea r8, [rbp+104] ; Get Local
    mov r8, qword [r8+8] ; Field access
    mov [rsp+16], r8
    lea r8, [rbp+104] ; Get Local
    mov r8, qword [r8+0] ; Field access
    mov [rsp+24], r8
    pop rcx
    pop rdx
    pop r8
    pop r9
    sub rsp, 32 ; Inline sprintf call
    call sprintf
    add rsp, 32
    mov r8, rax
    lea r8, [rbp+104] ; Get Local
    mov r8, qword [r8+8] ; Field access
    lea r9, [rbp+96] ; Get Local
    add [r9], r8 ; Mutate
.L88:
    lea r8, [__Splicer__next] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+56] ; Get Local
    mov [rsp+8], r8
    lea r8, [rbp+104] ; Get Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    test r8, r8 ; Loop check
    jnz .L87
.L86:
    sub rsp, 24 ; Make space for native args
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+96] ; Get Arg/Local
    imul r9, 1
    lea r8, [r8+r9] ; Ptr Index
    mov [rsp+0], r8
    lea r8, [C9]
    mov [rsp+8], r8
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r8, qword [r8+16] ; Field access
    mov [rsp+16], r8
    pop rcx
    pop rdx
    pop r8
    sub rsp, 32 ; Inline sprintf call
    call sprintf
    add rsp, 32
    mov r8, rax
    lea r9, [rbp+96] ; Get Local
    add [r9], r8 ; Mutate
    sub rsp, 32 ; Make space for native args
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+0], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+96] ; Get Arg/Local
    mov [rsp+16], r8
    lea r8, [rbp+24] ; Get Local
    mov [rsp+24], r8
    pop rcx
    pop rdx
    pop r8
    pop r9
    push 0
    push 0
    sub rsp, 32 ; Write call
    call WriteFile
    add rsp, 48
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8
    jz .L89
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    mov r8, rax
    mov r8, 0 ; Load BOOL
    mov rax, r8
    jmp .L79
.L89:
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov r9, qword [rbp+144] ; Get Arg/Local
    add [r9], r8 ; Mutate
.L85:
.L84:
    mov r8, 1 ; Load INT
    lea r9, [rbp+32] ; Get Local
    add [r9], r8 ; Mutate
    mov r8, qword [rbp+32] ; Get Arg/Local
    mov r9, qword [rbp+40] ; Get Arg/Local
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
    test r8, r8 ; Loop check
    jnz .L83
.L82:
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    mov r8, rax
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    mov r8, rax
    mov r8, 1 ; Load BOOL
    mov rax, r8
    jmp .L79
    xor eax, eax
.L79:
    pop rbp
    add rsp, 112
    ret

__Dictionary__free:
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
.L90:
    xor eax, eax
    pop rbp
    ret

__main:
    sub rsp, 256 ; Reserve locals space
    push rbp
    mov rbp, rsp
    mov r8, 100 ; Load INT
    mov [rbp + 8], r8 ; Declare identifier
    mov r8, qword [rbp+272] ; Get Arg/Local
    mov r9, 4 ; Load INT
    cmp r8, r9 ; INT >
    setg al
    movzx r8, al
    test r8, r8 ; Logical OR
    jnz .L92
    mov r8, qword [rbp+272] ; Get Arg/Local
    mov r9, 2 ; Load INT
    cmp r8, r9 ; INT <
    setl al
    movzx r8, al
.L92:
    test r8, r8
    jz .L93
    sub rsp, 8 ; Make space for native args
    lea r8, [C10]
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    mov r8, 1 ; Load INT
    mov rax, r8
    jmp .L91
.L93:
    mov r8, qword [rbp+280] ; Get Arg/Local
    mov r9, 1 ; Load INT
    imul r9, 8
    mov r8, [r8+r9] ; Ptr Index
    mov [rbp + 16], r8 ; Declare identifier
    mov r8, qword [rbp+272] ; Get Arg/Local
    mov r9, 3 ; Load INT
    cmp r8, r9 ; INT >=
    setge al
    movzx r8, al
    test r8, r8 ; If Expr
    jz .L94
    mov r8, qword [rbp+280] ; Get Arg/Local
    mov r9, 2 ; Load INT
    imul r9, 8
    mov r8, [r8+r9] ; Ptr Index
    jmp .L95
.L94:
    mov r8, qword [__DEFAULT_EXPORT_PATH] ; Get Global
.L95: ; End of If Expr
    mov [rbp + 24], r8 ; Declare identifier
    mov r8, 0 ; Load NULLPTR
    mov r8, 0 ; Load NULLPTR
    mov r8, qword [rbp+272] ; Get Arg/Local
    mov r9, 4 ; Load INT
    cmp r8, r9 ; INT ==
    sete al
    movzx r8, al
    test r8, r8 ; If Expr
    jz .L96
    mov r8, qword [rbp+280] ; Get Arg/Local
    mov r9, 3 ; Load INT
    imul r9, 8
    mov r8, [r8+r9] ; Ptr Index
    mov r9, 0 ; Load INT
    imul r9, 1
    movzx r8, byte [r8+r9] ; Ptr Index
    jmp .L97
.L96:
    movzx r8, byte [__DEFAULT_DELIMITER] ; Get Global
.L97: ; End of If Expr
    mov [rbp + 32], r8b ; Declare identifier
    sub rsp, 16 ; Make space for native args
    lea r8, [C11]
    mov [rsp+0], r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    mov rdx, 0xC0000000
    mov r8, 3
    mov r9, 0
    push 0
    push 0
    push 0x80
    push 3
    sub rsp, 32 ; Open file call
    call CreateFileA
    add rsp, 64
    mov r8, rax
    mov [rbp + 40], r8 ; Declare identifier
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov r9, 1 ; Load INT
    neg r9 ; (U)INT negate
    cmp r8, r9 ; INT ==
    sete al
    movzx r8, al
    test r8, r8
    jz .L98
    sub rsp, 16 ; Make space for native args
    lea r8, [C12]
    mov [rsp+0], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    mov r8, 1 ; Load INT
    mov rax, r8
    jmp .L91
.L98:
    sub rsp, 16 ; Make space for native args
    lea r8, [C13]
    mov [rsp+0], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    mov r8, 0 ; Load INT
    mov [rbp + 48], r8 ; Declare identifier
    sub rsp, 16 ; Make space for native args
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+0], r8
    lea r8, [rbp+48] ; Get Local
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Get size of file call
    call GetFileSizeEx
    add rsp, 32
    mov r8, rax
    mov [rbp + 56], r8b ; Declare identifier
    movzx r8, byte [rbp+56] ; Get Arg/Local
    xor r8, 1 ; Bool not
    test r8, r8
    jz .L99
    sub rsp, 16 ; Make space for native args
    lea r8, [C14]
    mov [rsp+0], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    mov r8, rax
    mov r8, 1 ; Load INT
    mov rax, r8
    jmp .L91
.L99:
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov r9, 0 ; Load INT
    cmp r8, r9 ; UINT ==
    sete al
    movzx r8, al
    test r8, r8
    jz .L100
    sub rsp, 16 ; Make space for native args
    lea r8, [C15]
    mov [rsp+0], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    mov r8, rax
    mov r8, 0 ; Load INT
    mov rax, r8
    jmp .L91
.L100:
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline malloc call
    call malloc
    add rsp, 32
    mov r8, rax
    mov [rbp + 64], r8 ; Declare identifier
    mov r8, qword [rbp+64] ; Get Arg/Local
    mov r9, 0 ; Load NULLPTR
    cmp r8, r9 ; INT ==
    sete al
    movzx r8, al
    test r8, r8
    jz .L101
    sub rsp, 24 ; Make space for native args
    lea r8, [C16]
    mov [rsp+0], r8
    mov r8, qword [rbp+48] ; Get Arg/Local
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
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    mov r8, rax
    mov r8, 1 ; Load INT
    mov rax, r8
    jmp .L91
.L101:
    mov r8, 0 ; Load INT
    mov [rbp + 72], r8 ; Declare identifier
    sub rsp, 32 ; Make space for native args
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+0], r8
    mov r8, qword [rbp+64] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+48] ; Get Arg/Local
    mov [rsp+16], r8
    lea r8, [rbp+72] ; Get Local
    mov [rsp+24], r8
    pop rcx
    pop rdx
    pop r8
    pop r9
    push 0
    push 0
    sub rsp, 32 ; Read call
    call ReadFile
    add rsp, 48
    mov r8, rax
    mov [rbp + 80], r8b ; Declare identifier
    movzx r8, byte [rbp+80] ; Get Arg/Local
    xor r8, 1 ; Bool not
    test r8, r8 ; Logical OR
    jnz .L102
    mov r8, qword [rbp+72] ; Get Arg/Local
    mov r9, qword [rbp+48] ; Get Arg/Local
    cmp r8, r9 ; UINT !=
    setne al
    movzx r8, al
.L102:
    test r8, r8
    jz .L103
    sub rsp, 16 ; Make space for native args
    lea r8, [C17]
    mov [rsp+0], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+64] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    mov r8, rax
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    mov r8, rax
    mov r8, 1 ; Load INT
    mov rax, r8
    jmp .L91
.L103:
    sub rsp, 24 ; Make space for native args
    lea r8, [C18]
    mov [rsp+0], r8
    mov r8, qword [rbp+72] ; Get Arg/Local
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
    lea r8, [__Dictionary__init] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+88] ; Get Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    lea r8, [__String__initLen] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push r8
    lea r8, [rbp+120] ; Get Local
    mov [rsp+8], r8
    mov r8, qword [rbp+64] ; Get Arg/Local
    mov [rsp+16], r8
    mov r8, qword [rbp+72] ; Get Arg/Local
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    lea r8, [__Splicer__init] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push r8
    lea r8, [rbp+136] ; Get Local
    mov [rsp+8], r8
    lea r8, [rbp+120] ; Get Local
    mov [rsp+16], r8
    mov r8, 10 ; Load INT
    mov [rsp+24], r8b
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    lea r8, [__Splicer__next] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+136] ; Get Local
    mov [rsp+8], r8
    lea r8, [rbp+176] ; Get Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    test r8, r8 ; Exit check
    jz .L104
.L105:
    lea r8, [__Splicer__init] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push r8
    lea r8, [rbp+192] ; Get Local
    mov [rsp+8], r8
    lea r8, [rbp+176] ; Get Local
    mov [rsp+16], r8
    movzx r8, byte [rbp+32] ; Get Arg/Local
    mov [rsp+24], r8b
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    lea r8, [__Splicer__next] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+192] ; Get Local
    mov [rsp+8], r8
    lea r8, [rbp+232] ; Get Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    test r8, r8 ; Exit check
    jz .L107
.L108:
    lea r8, [__String__trim] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+232] ; Get Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    lea r8, [__String__isZeroLength] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+232] ; Get Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8
    jz .L110
    lea r8, [__Dictionary__addEntry] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+88] ; Get Local
    mov [rsp+8], r8
    lea r8, [rbp+232] ; Get Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
.L110:
.L109:
    lea r8, [__Splicer__next] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+192] ; Get Local
    mov [rsp+8], r8
    lea r8, [rbp+232] ; Get Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    test r8, r8 ; Loop check
    jnz .L108
.L107:
.L106:
    lea r8, [__Splicer__next] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+136] ; Get Local
    mov [rsp+8], r8
    lea r8, [rbp+176] ; Get Local
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    test r8, r8 ; Loop check
    jnz .L105
.L104:
    mov r8, 0 ; Load INT
    mov [rbp + 248], r8 ; Declare identifier
    lea r8, [__Dictionary__export] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push r8
    lea r8, [rbp+88] ; Get Local
    mov [rsp+8], r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov [rsp+16], r8
    lea r8, [rbp+248] ; Get Local
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8
    jz .L111
    sub rsp, 16 ; Make space for native args
    lea r8, [C19]
    mov [rsp+0], r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+64] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    mov r8, rax
    mov r8, 1 ; Load INT
    mov rax, r8
    jmp .L91
.L111:
    sub rsp, 24 ; Make space for native args
    lea r8, [C20]
    mov [rsp+0], r8
    mov r8, qword [rbp+248] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov [rsp+16], r8
    pop rcx
    pop rdx
    pop r8
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    lea r8, [__Dictionary__free] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+88] ; Get Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+64] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    mov r8, rax
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+40] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Close handle call
    call CloseHandle
    add rsp, 32
    mov r8, rax
    call @nanoTimestamp
    mov r8, rax
    cvtsi2sd xmm0, r8 ; Non-floating point to F64
    movsd xmm1, [C21] ; Load F64
    divsd xmm0, xmm1 ; Float Div
    movsd [rbp + 256], xmm0 ; Declare identifier
    sub rsp, 16 ; Make space for native args
    lea r8, [C22]
    mov [rsp+0], r8
    movsd xmm0, qword [rbp+256] ; Get Arg/Local
    movsd [rsp+8], xmm0
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    xor eax, eax
.L91:
    pop rbp
    add rsp, 256
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
    extern QueryPerformanceCounter
    extern GetCommandLineW
    extern CommandLineToArgvW
    extern WideCharToMultiByte
    extern malloc
    extern free
    extern ExitProcess
    extern CloseHandle
    extern calloc
    extern printf
    extern sprintf
    extern WriteFile
    extern CreateFileA
    extern ReadFile
    extern CreateFileA
    extern GetFileSizeEx

    ; Program Constants ;
    C18: db `Read %d bytes from file: \"%s\"\n`, 0
    C5: db `Total entries: %d\n`, 0
    C12: db `Failed to open file: \"%s\"\n`, 0
    C11: db `export_path: %s\n`, 0
    C20: db `Exported %d bytes to file: \"%s\"\n`, 0
    C10: db `Usage: splicer.exe path/to/read/file [path/to/write/file] [delimiter]\n`, 0
    C17: db `Failed to read file: \"%s\"\n`, 0
    C14: db `Failed to get file size of file: \"%s\"\n`, 0
    C1: dq 7.5e-1
    C21: dq 1e9
    C19: db `Could not export dictionary to \"%s\"\n`, 0
    C7: db `Most common entry: `, 0
    C0: db `.\\splicer_out.txt`, 0
    C13: db `Opened file: \"%s\"\n`, 0
    C4: db `Key: '%.*s', Value: %i\n`, 0
    C2: db `\"%.*s\"\n`, 0
    C22: db `Time to run: %f s\n`, 0
    C3: db `<Empty>\n`, 0
    C8: db `%.*s`, 0
    C9: db `\" : %i,\n`, 0
    C15: db `File is empty: \"%s\"\n`, 0
    C6: db `Total unique entries: %d\n`, 0
    C16: db `Failed to allocate read buffer of size %d bytes for file: \"%s\"\n`, 0
section .bss
    @CLOCK_START: resb 8
    @ARGC: resb 8
    @ARGV: resb 8
    @ARG_BUFFER: resb 8

    ; Program Globals ;
    __MAX_DENSITY: resb 8
    __SIZEOF_ENTRY: resb 8
    __DEFAULT_DELIMITER: resb 1
    __SIZEOF_STRING: resb 8
    __DEFAULT_EXPORT_PATH: resb 8
