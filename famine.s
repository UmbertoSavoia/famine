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

%macro strcpy_my 2 ; src, dest
	save_regx
	mov	rax, -1			;i = -1
	%%strcpy_loop:						;while
   		inc	rax			;i++
   		mov	cl, byte [%1 + rax]	;cl = src[i]
   		mov	byte [%2 + rax], cl	;dest[i] = cl
   		cmp	cl, 0			;if cl == 0
   		jne	%%strcpy_loop			;jump to end if 0
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
   		js _exit						; dunque se in rax ci sta un numero con il segno -> exit(1)
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
   		add r15, 19						; ptr + d_name[]
   		strcat_my %1, r15, buffer		; unisco in buffer il percorso della dir e il nome del file
   		check_executable buffer			; controllo se il file è un eseguibile
   		cmp rax, 0						; se rax == 0 è eseguibile
   		jne %%else_print_file				; altrimenti si va avanti nel loop
   %%if_print_file:
   		strlen_my r15					; conto caratteri nome file
   		write_my r15, rax				; stampo nome file
   		write_my string_space, 2		; stampo \n
   		jmp %%end_if
   %%else_print_file:
   %%end_if:
   		sub r15, 19						; ptr - d_name[]
   		mov r13w, [r15 + 16]			; salvo la grandezza di questa struttura
   		add r15, r13					; ptr + size struttura
   		sub r14, r13					; sottraggo la size della struttura dal totale letto
   		cmp r14, 0						; controllo se ho letto tutti i byte restituiti
   		ja %%loop_my
%endmacro

section .bss
	linux_dirent64 resb BUF_SIZE
	stat resb 144
	buffer resb 4096

section .text
	global _start

_start:
	check_dir string_dir1
	check_dir string_dir2
	exit_my 0

_exit:
	exit_my 1

string_space:
	db 10, 0

string_dir1:
	db '/tmp/test/', 0

string_dir2:
	db '/tmp/test2/', 0