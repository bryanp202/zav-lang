default rel
global _start
global __SIZE_OF_STRING
extern __stringhashmap__StringHashMap_string__display
extern __string__data
extern __string__String__init
extern __stringhashmap__StringHashMap_string__remove
extern __stringhashmap__StringHashMap_string__get_ptr
extern __string__String
extern __stringhashmap__StringHashMap_string
extern __stringhashmap__StringHashMap_string__put
extern __stringhashmap__StringHashMap_string__init
extern __string__len
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
    mov rsi, 16 ; Load INT
    mov [__SIZE_OF_STRING], rsi ; Declare identifier

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

    
__main:
    sub rsp, 136 ; Reserve locals space
    push rbp
    mov rbp, rsp
    lea rsi, [__stringhashmap__StringHashMap_string__init] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    lea rsi, [__string__String__init] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+40] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [C0]
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__string__String__init] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+56] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [C1]
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__string__String__init] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+72] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [C2]
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__string__String__init] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+88] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [C3]
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__string__String__init] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+104] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [C4]
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__string__String__init] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+120] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [C5]
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__put] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+40] ; Get Local
    mov [rsp+16], rsi
    lea rsi, [rbp+56] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__put] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+40] ; Get Local
    mov [rsp+16], rsi
    lea rsi, [rbp+88] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__put] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+40] ; Get Local
    mov [rsp+16], rsi
    lea rsi, [rbp+56] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__put] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+72] ; Get Local
    mov [rsp+16], rsi
    lea rsi, [rbp+88] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__put] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+88] ; Get Local
    mov [rsp+16], rsi
    lea rsi, [rbp+88] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__put] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+56] ; Get Local
    mov [rsp+16], rsi
    lea rsi, [rbp+88] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__put] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+104] ; Get Local
    mov [rsp+16], rsi
    lea rsi, [rbp+88] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__put] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+120] ; Get Local
    mov [rsp+16], rsi
    lea rsi, [rbp+88] ; Get Local
    mov [rsp+24], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__display] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__remove] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+72] ; Get Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__display] ; Method access
    sub rsp, 8 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    pop rcx
    call rcx
    add rsp, 8
    mov rsi, rax
    lea rsi, [__stringhashmap__StringHashMap_string__get_ptr] ; Method access
    sub rsp, 24 ; Reserve call arg space
    push rsi
    lea rsi, [rbp+8] ; Get Local
    mov [rsp+8], rsi
    lea rsi, [rbp+40] ; Get Local
    mov [rsp+16], rsi
    pop rcx
    call rcx
    add rsp, 24
    mov rsi, rax
    mov [rbp + 136], rsi ; Declare identifier
    mov rsi, qword [rbp+136] ; Get Arg/Local
    mov rdi, 0 ; Load NULLPTR
    cmp rsi, rdi ; INT !=
    setne al
    movzx rsi, al
    test rsi, rsi
    jz .L1
    sub rsp, 40 ; Make space for native args
    lea rsi, [C6]
    mov [rsp+0], rsi
    lea rsi, [rbp+40] ; Get Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rsp+8], rsi
    lea rsi, [rbp+40] ; Get Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rsp+16], rsi
    mov rsi, qword [rbp+136] ; Get Arg/Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rsp+24], rsi
    mov rsi, qword [rbp+136] ; Get Arg/Local
    mov rsi, qword [rsi+0] ; Field access
    mov [rsp+32], rsi
    pop rcx
    pop rdx
    pop r8
    pop r9
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    jmp .L2
.L1:
    sub rsp, 32 ; Make space for native args
    lea rsi, [C7]
    mov [rsp+0], rsi
    lea rsi, [rbp+40] ; Get Local
    mov rsi, qword [rsi+8] ; Field access
    mov [rsp+8], rsi
    lea rsi, [rbp+40] ; Get Local
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
.L2:
    sub rsp, 24 ; Make space for native args
    lea rsi, [C8]
    mov [rsp+0], rsi
    sub rsp, 8 ; Make space for native args
    call @nanoTimestamp
    add rsp, 8
    mov rsi, rax
    cvtsi2sd xmm0, rsi ; Non-floating point to F64
    movsd xmm1, [C9] ; Load F64
    divsd xmm0, xmm1 ; Float Div
    movsd [rsp+8], xmm0
    pop rcx
    pop rdx
    sub rsp, 32 ; Inline printf call
    call printf
    add rsp, 32
    add rsp, 8
    mov rsi, rax
    xor eax, eax
.L0:
    pop rbp
    add rsp, 136
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
    extern printf

    ; Program Constants ;
    C4: db `Canada`, 0
    C5: db `3,855,100 mi^2`, 0
    C1: db `3,800,000 mi^2`, 0
    C3: db `145,937 mi^2`, 0
    C8: db `Time to run: %f sec\n`, 0
    C0: db `United States of America`, 0
    C7: db `Did not find \"%.*s\"\n`, 0
    C6: db `The landmass of \"%.*s\" is \"%.*s\"\n`, 0
    C9: dq 1e9
    C2: db `Japan`, 0
section .bss
    @CLOCK_START: resb 8
    @ARGC: resb 8
    @ARGV: resb 8
    @ARG_BUFFER: resb 8

    ; Program Globals ;
    __SIZE_OF_STRING: resb 8
