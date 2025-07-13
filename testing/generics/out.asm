default rel
global _start
global __List@@pu8__bytes
global ____max@f64
global __List@i8__bytes
global __main
global ____max@i64
global __Complex__mag
global __Complex__greater
global __Complex__display
global __Complex__new
global ____max@__Complex
global __List@i64__bytes
global __List@__Complex__bytes
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
    sub rsp, 24
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

    call __main ; Execute main
    add rsp, 24
    push rax

    mov rcx, [@ARG_BUFFER]
    sub rsp, 32
    call free
    add rsp, 32

    mov rcx, [rsp]
    call ExitProcess
    ret

    
__Complex__new:
    sub rsp, 16 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea r8, [rbp+8] ; Get Local
    movsd xmm0, qword [rbp+40] ; Get Arg/Local
    movq [r8], xmm0 ; Mutate
    lea r8, [rbp+8] ; Get Local
    lea r8, [r8+8] ; Field access
    movsd xmm0, qword [rbp+48] ; Get Arg/Local
    movq [r8], xmm0 ; Mutate
    lea r8, qword [rbp+8] ; Get Arg/Local
    mov rax, [rbp+32]
    mov rsi, r8
    lea rdi, [rax+0]
    mov rcx, 16
    rep movsb
    mov r8, rax
    mov rax, r8
    jmp .L0
    xor eax, eax
.L0:
    pop rbp
    add rsp, 16
    ret

__Complex__mag:
    push rbp
    mov rbp, rsp
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+16] ; Get Arg/Local
    movsd xmm0, [r8+0] ; Field access
    mov r8, qword [rbp+16] ; Get Arg/Local
    movsd xmm1, [r8+0] ; Field access
    mulsd xmm0, xmm1 ; Float Mul
    mov r8, qword [rbp+16] ; Get Arg/Local
    movsd xmm1, [r8+8] ; Field access
    mov r8, qword [rbp+16] ; Get Arg/Local
    movsd xmm2, [r8+8] ; Field access
    mulsd xmm1, xmm2 ; Float Mul
    addsd xmm0, xmm1 ; Float Add
    movsd [rsp+0], xmm0
    pop rcx
    sqrtsd xmm0, xmm0
    movq rax, xmm0
    movq xmm0, rax
    movq rax, xmm0
    jmp .L1
    xor eax, eax
.L1:
    pop rbp
    ret

__Complex__greater:
    push rbp
    mov rbp, rsp
    lea r8, [__Complex__mag] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+16] ; Get Arg
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    movq xmm0, rax
    lea r8, [__Complex__mag] ; Method access
    sub rsp, 8
 movq [rsp], xmm0
    sub rsp, 8 ; Reserve call arg space
    push r8
    lea r8, [rbp+32] ; Get Arg
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 8
    movq xmm0, [rsp]
    add rsp, 8
    movq xmm1, rax
    comisd xmm0, xmm1 ; Float >=
    setnb al
    movzx r8, al
    mov rax, r8
    jmp .L2
    xor eax, eax
.L2:
    pop rbp
    ret

__Complex__display:
    push rbp
    mov rbp, rsp
    sub rsp, 24 ; Make space for native args
    lea r8, [C0]
    mov [rsp+0], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    movsd xmm0, [r8+0] ; Field access
    movsd [rsp+8], xmm0
    mov r8, qword [rbp+16] ; Get Arg/Local
    movsd xmm0, [r8+8] ; Field access
    movsd [rsp+16], xmm0
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

__List@__Complex__bytes:
    sub rsp, 16 ; Reserve locals space
    push rbp
    mov rbp, rsp
    sub rsp, 16 ; Make space for native args
    lea r8, [C1]
    mov [rsp+0], r8
    mov rax, 16 ; Inline sizeof
    mov r8, rax
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    mov r8, 0 ; Load INT
    mov [rbp+8], r8
    push r8
    sub rsp, 8 ; Make space for native args
    mov rax, 16 ; Inline sizeof
    add rsp, 8
    pop r8
    mov r9, rax
    mov [rbp+16], r9
    cmp r8, r9
    jge .L5
.L7:
    sub rsp, 16 ; Make space for native args
    lea r8, [C2]
    mov [rsp+0], r8
    mov rax, 16 ; Inline sizeof
    mov r8, rax
    mov r9, qword [rbp+8] ; Get Arg/Local
    sub r8, r9 ; (U)INT  Sub
    mov r9, 1 ; Load INT
    sub r8, r9 ; (U)INT  Sub
    lea r9, [rbp+40] ; Get Arg
    imul r8, 1
    movzx r8, byte [r9+r8] ; Ptr Index
    movzx r8, r8b
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
.L6:
    inc qword [rbp+8]
    mov r8, [rbp+8]
    mov r9, [rbp+16]
    cmp r8, r9
    jl .L7
.L5:
    sub rsp, 8 ; Make space for native args
    lea r8, [C3]
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    xor eax, eax
.L4:
    xor eax, eax
    pop rbp
    add rsp, 16
    ret

__List@i64__bytes:
    sub rsp, 16 ; Reserve locals space
    push rbp
    mov rbp, rsp
    sub rsp, 16 ; Make space for native args
    lea r8, [C1]
    mov [rsp+0], r8
    mov rax, 8 ; Inline sizeof
    mov r8, rax
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    mov r8, 0 ; Load INT
    mov [rbp+8], r8
    push r8
    sub rsp, 8 ; Make space for native args
    mov rax, 8 ; Inline sizeof
    add rsp, 8
    pop r8
    mov r9, rax
    mov [rbp+16], r9
    cmp r8, r9
    jge .L9
.L11:
    sub rsp, 16 ; Make space for native args
    lea r8, [C2]
    mov [rsp+0], r8
    mov rax, 8 ; Inline sizeof
    mov r8, rax
    mov r9, qword [rbp+8] ; Get Arg/Local
    sub r8, r9 ; (U)INT  Sub
    mov r9, 1 ; Load INT
    sub r8, r9 ; (U)INT  Sub
    lea r9, [rbp+40] ; Get Arg
    imul r8, 1
    movzx r8, byte [r9+r8] ; Ptr Index
    movzx r8, r8b
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
.L10:
    inc qword [rbp+8]
    mov r8, [rbp+8]
    mov r9, [rbp+16]
    cmp r8, r9
    jl .L11
.L9:
    sub rsp, 8 ; Make space for native args
    lea r8, [C3]
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    xor eax, eax
.L8:
    xor eax, eax
    pop rbp
    add rsp, 16
    ret

__List@i8__bytes:
    sub rsp, 24 ; Reserve locals space
    push rbp
    mov rbp, rsp
    sub rsp, 24 ; Make space for native args
    lea r8, [C1]
    mov [rsp+0], r8
    mov rax, 1 ; Inline sizeof
    mov r8, rax
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov r8, rax
    mov r8, 0 ; Load INT
    mov [rbp+15], r8
    push r8
    mov rax, 1 ; Inline sizeof
    pop r8
    mov r9, rax
    mov [rbp+23], r9
    cmp r8, r9
    jge .L13
.L15:
    sub rsp, 24 ; Make space for native args
    lea r8, [C2]
    mov [rsp+0], r8
    mov rax, 1 ; Inline sizeof
    mov r8, rax
    mov r9, qword [rbp+15] ; Get Arg/Local
    sub r8, r9 ; (U)INT  Sub
    mov r9, 1 ; Load INT
    sub r8, r9 ; (U)INT  Sub
    lea r9, [rbp+48] ; Get Arg
    imul r8, 1
    movzx r8, byte [r9+r8] ; Ptr Index
    movzx r8, r8b
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov r8, rax
.L14:
    inc qword [rbp+15]
    mov r8, [rbp+15]
    mov r9, [rbp+23]
    cmp r8, r9
    jl .L15
.L13:
    sub rsp, 16 ; Make space for native args
    lea r8, [C3]
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov r8, rax
    xor eax, eax
.L12:
    xor eax, eax
    pop rbp
    add rsp, 24
    ret

__List@@pu8__bytes:
    sub rsp, 16 ; Reserve locals space
    push rbp
    mov rbp, rsp
    sub rsp, 16 ; Make space for native args
    lea r8, [C1]
    mov [rsp+0], r8
    mov rax, 8 ; Inline sizeof
    mov r8, rax
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    mov r8, 0 ; Load INT
    mov [rbp+8], r8
    push r8
    sub rsp, 8 ; Make space for native args
    mov rax, 8 ; Inline sizeof
    add rsp, 8
    pop r8
    mov r9, rax
    mov [rbp+16], r9
    cmp r8, r9
    jge .L17
.L19:
    sub rsp, 16 ; Make space for native args
    lea r8, [C2]
    mov [rsp+0], r8
    mov rax, 8 ; Inline sizeof
    mov r8, rax
    mov r9, qword [rbp+8] ; Get Arg/Local
    sub r8, r9 ; (U)INT  Sub
    mov r9, 1 ; Load INT
    sub r8, r9 ; (U)INT  Sub
    lea r9, [rbp+40] ; Get Arg
    imul r8, 1
    movzx r8, byte [r9+r8] ; Ptr Index
    movzx r8, r8b
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
.L18:
    inc qword [rbp+8]
    mov r8, [rbp+8]
    mov r9, [rbp+16]
    cmp r8, r9
    jl .L19
.L17:
    sub rsp, 8 ; Make space for native args
    lea r8, [C3]
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    xor eax, eax
.L16:
    xor eax, eax
    pop rbp
    add rsp, 16
    ret

__main:
    sub rsp, 256 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea r8, [__List@__Complex__bytes] ; Method access
    sub rsp, 32 ; Reserve call arg space
    push r8
    lea r8, [rbp+8] ; Get Local
    mov [rsp+8], r8
    lea r8, [__Complex__new] ; Get Function
    sub rsp, 24 ; Reserve call arg space
    push r8
    lea rax, [rbp+32]
    mov [rsp+8], rax
    movsd xmm0, [C4] ; Load F64
    movq [rsp+16], xmm0
    movsd xmm0, [C5] ; Load F64
    xorps xmm0, oword [@SD_SIGN_BIT] ; F64 Negate
    movq [rsp+24], xmm0
    pop rcx
    call rcx
    add rsp, 24
    mov r8, rax
    mov rsi, r8
    lea rdi, [rsp+16]
    mov rcx, 16
    rep movsb
    pop rcx
    call rcx
    add rsp, 32
    mov r8, rax
    lea r8, [__List@i64__bytes] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+48] ; Get Local
    mov [rsp+8], r8
    mov r8, 9700 ; Load INT
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    lea r8, [__List@i8__bytes] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+72] ; Get Local
    mov [rsp+8], r8
    mov r8, 10 ; Load INT
    mov [rsp+16], r8b
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    lea r8, [__List@@pu8__bytes] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+96] ; Get Local
    mov [rsp+8], r8
    lea r8, [C6]
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    lea r8, [rbp+120]
    mov r9, 10 ; Load INT
    mov [r8], r9 ; Declare identifier
    lea r8, [rbp+128]
    push r8
    sub rsp, 16 ; Make space for native args
    mov r8, qword [rbp+120] ; Get Arg/Local
    mov r9, 8 ; Load INT
    imul r8, r9 ; (U)INT Mul
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline malloc call
    call malloc
    add rsp, 32
    add rsp, 8
    pop r8
    mov r9, rax
    mov [r8], r9 ; Declare identifier
    mov r8, 0 ; Load INT
    mov [rbp+136], r8
    mov r9, qword [rbp+120] ; Get Arg/Local
    mov [rbp+144], r9
    cmp r8, r9
    jge .L21
.L23:
    mov r8, qword [rbp+128] ; Get Arg/Local
    mov r9, qword [rbp+136] ; Get Arg/Local
    imul r9, 8
    lea r8, [r8+r9] ; Ptr Index
    mov r9, qword [rbp+136] ; Get Arg/Local
    mov [r8], r9 ; Mutate
.L22:
    inc qword [rbp+136]
    mov r8, [rbp+136]
    mov r9, [rbp+144]
    cmp r8, r9
    jl .L23
.L21:
    lea r8, [rbp+152]
    mov r9, 10 ; Load INT
    mov [r8], r9 ; Declare identifier
    lea r8, [rbp+160]
    push r8
    sub rsp, 16 ; Make space for native args
    mov r8, qword [rbp+152] ; Get Arg/Local
    mov r9, 8 ; Load INT
    imul r8, r9 ; (U)INT Mul
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline malloc call
    call malloc
    add rsp, 32
    add rsp, 8
    pop r8
    mov r9, rax
    mov [r8], r9 ; Declare identifier
    mov r8, 0 ; Load INT
    mov [rbp+168], r8
    mov r9, qword [rbp+152] ; Get Arg/Local
    mov [rbp+176], r9
    cmp r8, r9
    jge .L24
.L26:
    mov r8, qword [rbp+160] ; Get Arg/Local
    mov r9, qword [rbp+168] ; Get Arg/Local
    imul r9, 8
    lea r8, [r8+r9] ; Ptr Index
    mov r9, qword [rbp+168] ; Get Arg/Local
    cvtsi2sd xmm0, r9 ; Non-floating point to F64
    movsd xmm1, [C7] ; Load F64
    mulsd xmm0, xmm1 ; Float Mul
    movq [r8], xmm0 ; Mutate
.L25:
    inc qword [rbp+168]
    mov r8, [rbp+168]
    mov r9, [rbp+176]
    cmp r8, r9
    jl .L26
.L24:
    lea r8, [rbp+184]
    mov r9, 10 ; Load INT
    mov [r8], r9 ; Declare identifier
    lea r8, [rbp+192]
    push r8
    sub rsp, 16 ; Make space for native args
    mov r8, qword [rbp+184] ; Get Arg/Local
    mov r9, 16 ; Load INT
    imul r8, r9 ; (U)INT Mul
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline malloc call
    call malloc
    add rsp, 32
    add rsp, 8
    pop r8
    mov r9, rax
    mov [r8], r9 ; Declare identifier
    mov r8, 0 ; Load INT
    mov [rbp+200], r8
    mov r9, qword [rbp+184] ; Get Arg/Local
    mov [rbp+208], r9
    cmp r8, r9
    jge .L27
.L29:
    mov r8, qword [rbp+192] ; Get Arg/Local
    mov r9, qword [rbp+200] ; Get Arg/Local
    imul r9, 16
    lea r8, [r8+r9] ; Ptr Index
    lea r9, [__Complex__new] ; Get Function
    push r8
    sub rsp, 24 ; Reserve call arg space
    push r9
    mov rax, [rbp-8]
    mov [rsp+8], rax
    mov r8, qword [rbp+200] ; Get Arg/Local
    cvtsi2sd xmm0, r8 ; Non-floating point to F64
    movq [rsp+16], xmm0
    mov r8, qword [rbp+200] ; Get Arg/Local
    neg r8 ; (U)INT negate
    cvtsi2sd xmm0, r8 ; Non-floating point to F64
    movq [rsp+24], xmm0
    pop rcx
    call rcx
    add rsp, 24
    pop r8
    mov r9, rax
    mov rsi, r9
    lea rdi, [r8+0]
    mov rcx, 16
    rep movsb
.L28:
    inc qword [rbp+200]
    mov r8, [rbp+200]
    mov r9, [rbp+208]
    cmp r8, r9
    jl .L29
.L27:
    lea r8, [rbp+216]
    lea r9, [__@anon0] ; Get Function
    mov [r8], r9 ; Declare identifier
    lea r8, [rbp+224]
    lea r9, [____max@f64] ; Get Function
    push r8
    sub rsp, 24 ; Reserve call arg space
    push r9
    mov r8, qword [rbp+160] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+152] ; Get Arg/Local
    mov [rsp+16], r8
    mov r8, qword [rbp+216] ; Get Arg/Local
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 24
    pop r8
    movq xmm0, rax
    movsd [r8], xmm0 ; Declare identifier
    lea r8, [rbp+232]
    lea r9, [____max@i64] ; Get Function
    push r8
    sub rsp, 24 ; Reserve call arg space
    push r9
    mov r8, qword [rbp+128] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+120] ; Get Arg/Local
    mov [rsp+16], r8
    lea r8, [__@anon1] ; Get Function
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 24
    pop r8
    mov r9, rax
    mov [r8], r9 ; Declare identifier
    lea r8, [rbp+240]
    lea r9, [____max@i64] ; Get Function
    push r8
    sub rsp, 24 ; Reserve call arg space
    push r9
    mov r8, qword [rbp+128] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+120] ; Get Arg/Local
    mov [rsp+16], r8
    lea r8, [__@anon2] ; Get Function
    mov [rsp+24], r8
    pop rcx
    call rcx
    add rsp, 24
    pop r8
    mov r9, rax
    mov [r8], r9 ; Declare identifier
    lea r8, [rbp+248]
    lea r9, [____max@__Complex] ; Get Function
    push r8
    sub rsp, 40 ; Reserve call arg space
    push r9
    mov rax, [rbp-8]
    mov [rsp+8], rax
    mov r8, qword [rbp+192] ; Get Arg/Local
    mov [rsp+16], r8
    mov r8, qword [rbp+184] ; Get Arg/Local
    mov [rsp+24], r8
    lea r8, [__Complex__greater] ; Get Function
    mov [rsp+32], r8
    pop rcx
    call rcx
    add rsp, 40
    pop r8
    mov r9, rax
    mov rsi, r9
    lea rdi, [r8+0]
    mov rcx, 16
    rep movsb
    sub rsp, 16 ; Make space for native args
    lea r8, [C8]
    mov [rsp+0], r8
    mov r8, qword [rbp+232] ; Get Arg/Local
    mov [rsp+8], r8
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    sub rsp, 16 ; Make space for native args
    lea r8, [C9]
    mov [rsp+0], r8
    movsd xmm0, qword [rbp+224] ; Get Arg/Local
    movsd [rsp+8], xmm0
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    mov r8, rax
    lea r8, [__Complex__display] ; Method access
    sub rsp, 16 ; Reserve call arg space
    push r8
    lea r8, [rbp+248] ; Get Local
    mov [rsp+8], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    mov r8, 0 ; Load INT
    mov rax, r8
    push rax
    sub rsp, 16 ; Make space for native args
    mov r8, qword [rbp+192] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    add rsp, 8
    mov r8, rax
    sub rsp, 16 ; Make space for native args
    mov r8, qword [rbp+160] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    add rsp, 8
    mov r8, rax
    sub rsp, 16 ; Make space for native args
    mov r8, qword [rbp+128] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    add rsp, 8
    mov r8, rax
    pop rax
    jmp .L20
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+192] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    mov r8, rax
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+160] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    mov r8, rax
    sub rsp, 8 ; Make space for native args
    mov r8, qword [rbp+128] ; Get Arg/Local
    mov [rsp+0], r8
    pop rcx
    sub rsp, 32 ; Inline free call
    call free
    add rsp, 32
    mov r8, rax
    xor eax, eax
.L20:
    pop rbp
    add rsp, 256
    ret

____max@f64:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea r8, [rbp+8]
    mov r9, qword [rbp+48] ; Get Arg/Local
    mov r10, 0 ; Load INT
    imul r10, 8
    movsd xmm0, [r9+r10] ; Ptr Index
    movsd [r8], xmm0 ; Declare identifier
    mov r8, 1 ; Load INT
    mov [rbp+24], r8
    mov r9, qword [rbp+48] ; Get Arg/Local
    mov r10, 1 ; Load INT
    imul r10, 8
    lea r9, [r9+r10] ; Ptr Index
    mov [rbp+16], r9
    mov r9, qword [rbp+56] ; Get Arg/Local
    mov [rbp+32], r9
    cmp r8, r9
    jge .L31
.L33:
    mov r8, qword [rbp+64] ; Get Arg/Local
    sub rsp, 16 ; Reserve call arg space
    push r8
    movsd xmm0, qword [rbp+8] ; Get Arg/Local
    movq [rsp+8], xmm0
    mov r8, qword [rbp+16] ; Get Arg/Local
    movsd xmm0, [r8] ; Dereference Pointer
    movq [rsp+16], xmm0
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8
    jz .L34
    lea r8, [rbp+8] ; Get Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    movsd xmm0, [r9] ; Dereference Pointer
    movq [r8], xmm0 ; Mutate
.L34:
.L32:
    inc qword [rbp+24]
    add qword [rbp+16], 8
    mov r8, [rbp+24]
    mov r9, [rbp+32]
    cmp r8, r9
    jl .L33
.L31:
    movsd xmm0, qword [rbp+8] ; Get Arg/Local
    movq rax, xmm0
    jmp .L30
    xor eax, eax
.L30:
    pop rbp
    add rsp, 32
    ret

____max@i64:
    sub rsp, 32 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea r8, [rbp+8]
    mov r9, qword [rbp+48] ; Get Arg/Local
    mov r10, 0 ; Load INT
    imul r10, 8
    mov r9, [r9+r10] ; Ptr Index
    mov [r8], r9 ; Declare identifier
    mov r8, 1 ; Load INT
    mov [rbp+24], r8
    mov r9, qword [rbp+48] ; Get Arg/Local
    mov r10, 1 ; Load INT
    imul r10, 8
    lea r9, [r9+r10] ; Ptr Index
    mov [rbp+16], r9
    mov r9, qword [rbp+56] ; Get Arg/Local
    mov [rbp+32], r9
    cmp r8, r9
    jge .L36
.L38:
    mov r8, qword [rbp+64] ; Get Arg/Local
    sub rsp, 16 ; Reserve call arg space
    push r8
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov [rsp+8], r8
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r8, [r8] ; Dereference Pointer
    mov [rsp+16], r8
    pop rcx
    call rcx
    add rsp, 16
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8
    jz .L39
    lea r8, [rbp+8] ; Get Local
    mov r9, qword [rbp+16] ; Get Arg/Local
    mov r9, [r9] ; Dereference Pointer
    mov [r8], r9 ; Mutate
.L39:
.L37:
    inc qword [rbp+24]
    add qword [rbp+16], 8
    mov r8, [rbp+24]
    mov r9, [rbp+32]
    cmp r8, r9
    jl .L38
.L36:
    mov r8, qword [rbp+8] ; Get Arg/Local
    mov rax, r8
    jmp .L35
    xor eax, eax
.L35:
    pop rbp
    add rsp, 32
    ret

____max@__Complex:
    sub rsp, 40 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea r8, [rbp+8]
    mov r9, qword [rbp+64] ; Get Arg/Local
    mov r10, 0 ; Load INT
    imul r10, 16
    lea r9, [r9+r10] ; Ptr Index
    mov rsi, r9
    lea rdi, [r8+0]
    mov rcx, 16
    rep movsb
    mov r8, 1 ; Load INT
    mov [rbp+32], r8
    mov r9, qword [rbp+64] ; Get Arg/Local
    mov r10, 1 ; Load INT
    imul r10, 16
    lea r9, [r9+r10] ; Ptr Index
    mov [rbp+24], r9
    mov r9, qword [rbp+72] ; Get Arg/Local
    mov [rbp+40], r9
    cmp r8, r9
    jge .L41
.L43:
    mov r8, qword [rbp+80] ; Get Arg/Local
    sub rsp, 40 ; Reserve call arg space
    push r8
    lea r8, qword [rbp+8] ; Get Arg/Local
    mov rsi, r8
    lea rdi, [rsp+8]
    mov rcx, 16
    rep movsb
    mov r8, qword [rbp+24] ; Get Arg/Local
    mov rsi, r8
    lea rdi, [rsp+24]
    mov rcx, 16
    rep movsb
    pop rcx
    call rcx
    add rsp, 40
    mov r8, rax
    xor r8, 1 ; Bool not
    test r8, r8
    jz .L44
    lea r8, [rbp+8] ; Get Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    mov rsi, r9
    lea rdi, [r8+0]
    mov rcx, 16
    rep movsb
.L44:
.L42:
    inc qword [rbp+32]
    add qword [rbp+24], 16
    mov r8, [rbp+32]
    mov r9, [rbp+40]
    cmp r8, r9
    jl .L43
.L41:
    lea r8, qword [rbp+8] ; Get Arg/Local
    mov rax, [rbp+56]
    mov rsi, r8
    lea rdi, [rax+0]
    mov rcx, 16
    rep movsb
    mov r8, rax
    mov rax, r8
    jmp .L40
    xor eax, eax
.L40:
    pop rbp
    add rsp, 40
    ret

__@anon2:
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    cmp r8, r9 ; INT >=
    setge al
    movzx r8, al
    mov rax, r8
    jmp .L45
    xor eax, eax
.L45:
    pop rbp
    ret

__@anon1:
    push rbp
    mov rbp, rsp
    mov r8, qword [rbp+16] ; Get Arg/Local
    mov r9, qword [rbp+24] ; Get Arg/Local
    cmp r8, r9 ; INT >=
    setge al
    movzx r8, al
    mov rax, r8
    jmp .L46
    xor eax, eax
.L46:
    pop rbp
    ret

__@anon0:
    push rbp
    mov rbp, rsp
    movsd xmm0, qword [rbp+16] ; Get Arg/Local
    movsd xmm1, qword [rbp+24] ; Get Arg/Local
    comisd xmm0, xmm1 ; Float >=
    setnb al
    movzx r8, al
    mov rax, r8
    jmp .L47
    xor eax, eax
.L47:
    pop rbp
    ret
    
;-------------------------;
;         Natives         ;
;-------------------------;

section .data
    ; Native Constants and Dependencies;
    align 16
    @SS_SIGN_BIT: dq 0x80000000, 0
    align 16
    @SD_SIGN_BIT: dq 0x8000000000000000, 0
    extern QueryPerformanceCounter
    extern GetCommandLineW
    extern CommandLineToArgvW
    extern WideCharToMultiByte
    extern malloc
    extern free
    extern ExitProcess
    extern printf

    ; Program Constants ;
    C0: db `%f+%fi\n`, 0
    C9: db `Max float: %f\n`, 0
    C2: db `%X,`, 0
    C6: db `Hello world!\n`, 0
    C1: db `sizeof item: %d\n`, 0
    C7: dq 3e0
    C3: db `\n`, 0
    C5: dq 1.3e1
    C4: dq 1e2
    C8: db `Max int: %d\n`, 0
section .bss
    @CLOCK_START: resb 8
    @ARGC: resb 8
    @ARGV: resb 8
    @ARG_BUFFER: resb 8

    ; Program Globals ;
