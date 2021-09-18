; +--------+------------+--------+------+------+------+------+------+------+
; |  arch  | syscall NR | return | arg0 | arg1 | arg2 | arg3 | arg4 | arg5 |
; +--------+------------+--------+------+------+------+------+------+------+
; | x86    | eax        | eax    | ebx  | ecx  | edx  | esi  | edi  | ebp  |
; | x86_64 | rax        | rax    | rdi  | rsi  | rdx  | r10  | r8   | r9   |
; +--------+------------+--------+------+------+------+------+------+------+

; .-----------.-------.
; |   Stack   | bytes |
; :-----------+-------:
; | buffer    |  4096 |
; :-----------+-------:
; | tot letto |     8 |
; :-----------+-------:
; | getdents  | 32768 |
; :-----------+-------:
; | fd dir    |     8 |
; :-----------+-------:
; | str dir2  |    16 |
; :-----------+-------:
; | str dir1  |    16 |
; '-----------'-------'

section .text
    global _start

_start:

    struc dirent
        .d_ino resb 8
        .d_off resb 8
        .d_reclen resb 2
        .d_type resb 1
        .d_name resb 8
    endstruc

    struc ehdr
        .e_ident        resb 16       ;    /* File identification. */
        .e_type         resb 2        ;    /* File type. */
        .e_machine      resb 2        ;    /* Machine architecture. */
        .e_version      resb 4        ;    /* ELF format version. */
        .e_entry        resb 8        ;    /* Entry point. */
        .e_phoff        resb 8        ;    /* Program header file offset. */
        .e_shoff        resb 8        ;    /* Section header file offset. */
        .e_flags        resb 4        ;    /* Architecture-specific flags. */
        .e_ehsize       resb 2        ;    /* Size of ELF header in bytes. */
        .e_phentsize    resb 2        ;    /* Size of program header entry. */
        .e_phnum        resb 2        ;    /* Number of program header entries. */
        .e_shentsize    resb 2        ;    /* Size of section header entry. */
        .e_shnum        resb 2        ;    /* Number of section header entries. */
        .e_shstrndx     resb 2        ;    /* Section name strings section. */
    endstruc

    struc phdr
        .p_type         resb 4        ;    /* Entry type. */
        .p_flags        resb 4        ;    /* Access permission flags. */
        .p_offset       resb 8        ;    /* File offset of contents. */
        .p_vaddr        resb 8        ;    /* Virtual address in memory image. */
        .p_paddr        resb 8        ;    /* Physical address (not used). */
        .p_filesz       resb 8        ;    /* Size of contents in file. */
        .p_memsz        resb 8        ;    /* Size of contents in memory. */
        .p_align        resb 8        ;    /* Alignment in memory and file. */
    endstruc

    mov rbp, rsp                      ; salvo stato attuale stack
    sub rsp, 16                       ; riservo spazio per /tmp/test
    mov dword [rsp+8], `t/\0\0`
    mov dword [rsp+4], '/tes'
    mov dword [rsp], '/tmp'

    sub rsp, 16                       ; riservo spazio per /tmp/test1
    mov dword [rsp+8], `t2/\0`
    mov dword [rsp+4], '/tes'
    mov dword [rsp], '/tmp'

    mov rdi, rsp
    add rdi, 16                       ; passo come argomento /tmp/test/
    call open_dir
    test rax, rax
    js exit
    push rax                         ; salvo nello stack fd cartella

    sub rsp, 32768                   ; riservo spazio nello stack per lettura getdents64
    mov rdi, rsp                     ; passo come argomento lo spazio riservato
    call getdents64
    push rax                         ; salvo nello stack totale letto da getdents64

    sub rsp, 4096                    ; riservo spazio per il buffer
    mov r10, rsp                     ; r10 = puntatore buffer
    mov rdi, rsp
    add rdi, 4104                    ; rdi = puntatore struct
    call loop_indir

    mov rdi, 1
    mov rsi, rsp
    add rsi, 4096
    add rsi, 8
    add rsi, 32768
    add rsi, 8
    mov rdx, 11
    mov rax, 1
    syscall

exit:
    mov rsp, rbp                     ; ripristino lo stack
    mov rdi, 0                       ; error code
    mov rax, 60
    syscall

open_dir:                            ; rdi = fd
    mov rsi, 0                       ; permessi
    mov rdx, 0                       ; flag
    mov rax, 2
    syscall
    ret

getdents64:
    mov rsi, rdi                     ; struct linux_dirent64 *dirent
    mov rdi, [rsp+32768+8]           ; fd
    mov rdx, 32768                   ; quantità da leggere
    mov rax, 217
    syscall
    ret

loop_indir:                          ; rdi = ptr struct, r10 = puntatore buffer
    mov rax, [rsp+4096+8]            ; rax = tot letto
    .loop:
        mov rsi, [rdi+dirent.d_name] ; ptr + d_name
        cmp esi, 0x002e2e
        je .print
        cmp si, 0x002e
        je .print
        mov dx, [rdi+dirent.d_reclen]
        add rdi, rdx
        sub rax, rdx
        cmp rax, 0
        je .end
        jmp .loop
    .print:
        mov rdi, 1
        mov rsi, rdi
        add rsi, dirent.d_name
        mov rdx, 2
        mov rax, 1
        syscall
    .end:
    ret