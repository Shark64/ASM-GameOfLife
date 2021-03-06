;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;											;
;	 ooooo                          ooooooo           o                      	;
;	o     o   oo   o    o oooooo    o     o oooooo    o       o oooooo oooooo	;
;	o        o  o  oo  oo o         o     o o         o       o o      o     	;
;	o  oooo o    o o oo o ooooo     o     o ooooo     o       o ooooo  ooooo 	;
;	o     o oooooo o    o o         o     o o         o       o o      o     	;
;	o     o o    o o    o o         o     o o         o       o o      o     	;
;	 ooooo  o    o o    o oooooo    ooooooo o         ooooooo o o      oooooo	;
;											;
;				NASM assembler, Linux x86-64				;
;											;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%use smartalign
alignmode P6
%macro print 2
	mov eax, sys_write
	mov edi, eax 	; stdout=sys_write=1
	mov esi, %1
	mov edx, %2
	syscall
%endmacro

global _start

section .data
align 64
	row_cells:	equ 32	; set to any (reasonable) value you wish
	column_cells: 	equ 64 ; set to any (reasonable) value you wish
	array_length:	equ row_cells * column_cells + row_cells ; cells are mapped to bytes in the array and a new line char ends each row
align  64
	cells1: 	times array_length db new_line
	cells2:		times array_length db new_line

	live:		equ 111	; ascii code for live cells, can be any odd number
	dead:		equ 32	; ascii code for dead cells, can be any even number
	new_line:	equ 10	; ascii code for new line

	timespec:
    		tv_sec  dq 0
    		tv_nsec dq 200000000

	clear:		db 27, "[2J", 27, "[H"
	clear_length:	equ $-clear
	
	sys_write:	equ 1
	sys_nanosleep:	equ 35
	sys_time:	equ 201

section .text
align 4096

_start:

	xor eax, eax
	lea edx, [rax+clear_length]
	lea edi, [rax+sys_write]
	mov esi, clear
	mov eax, edi
	syscall
	jmp first_generation
	.second_gen:
	mov r9d, cells1
	mov r8d, cells2
	.generate_cells:
		xchg r8d, r9d		; exchange roles of current and next generation cell containers		
		print r8d, array_length	; print current generation
		mov eax, sys_nanosleep
		mov edi, timespec
		xor esi, esi		; ignore remaining time in case of call interruption
		syscall			; sleep for tv_sec seconds + tv_nsec nanoseconds
		print clear, clear_length		


; r8: current generation, r9: next generation
next_generation:

	xor ebx, ebx	; array index counter
	.process_cell:
		mov eax, new_line
		cmp  al, byte [r8 + rbx] ;, new_line
		je .next_cell	; do not count live neighbours if new_line
		xor eax, eax 	; live neighbours
		.lower_index_neighbours:
			mov edx, ebx			; copy of array index counter, will point to neighbour positions
			sub edx, 1			; move to middle left neighbour
			js .higher_index_neighbours	; < 0, jump to neighbours with higher indexes
			movzx ecx, byte [r8 + rdx]
			and ecx, 1			; 1 if live, 0 if dead or new_line
			add eax, ecx
			sub edx, column_cells - 1 	; move to top right neighbour
			js .higher_index_neighbours	; < 0, jump to neighbours with higher indexes
			movzx ecx, byte [r8 + rdx]
			and ecx, 1			; 1 if live, 0 if dead or new_line
			add eax, ecx
			sub edx, 1			; move to top middle neighbour
			js .higher_index_neighbours	; < 0, jump to neighbours with higher indexes
			movzx ecx, byte [r8 + rdx]
			and ecx, 1			; 1 if live, 0 if dead or new_line
			add eax, ecx
			sub edx, 1			; move to top left neighbour
			js .higher_index_neighbours 	; < 0, jump to neighbours with higher indexes		
			movzx ecx, byte [r8 + rdx]
			and ecx, 1			; 1 if live, 0 if dead or new_line
			add eax, ecx
		.higher_index_neighbours:
			mov edx, ebx			; reset neighbour index
			add edx, 1			; move to middle right neighbour
			cmp edx, array_length - 1
			jge .assign_cell		; out of bounds, no more neighbours to consider
			movzx ecx, byte [r8 + rdx]
			and ecx, 1			; 1 if live, 0 if dead or new_line
			add eax, ecx
			add edx, column_cells - 1	; move to bottom left neighbour
			cmp edx, array_length - 1
			jge .assign_cell		; out of bounds, no more neighbours to consider
			movzx ecx, byte [r8 + rdx]
			and ecx, 1			; 1 if live, 0 if dead or new_line
			add eax, ecx
			add edx, 1			; move to bottom middle neighbour
			cmp edx, array_length - 1
			jge .assign_cell		; out of bounds, no more neighbours to consider
			movzx ecx, byte [r8 + rdx]
			and ecx, 1			; 1 if live, 0 if dead or new_line
			add eax, ecx
			add edx, 1			; move to bottom right neighbour
			cmp edx, array_length - 1
			jge .assign_cell		; out of bounds, no more neighbours to consider
			mov esi, dead
			mov edi, live
			movzx ecx, byte [r8 + rdx]
			and ecx, 1			; 1 if live, 0 if dead or new_line
			add eax, ecx
			cmp eax, 3
			cmove esi, edi    		; 3 live neighbours, live cell
		.assign_cell:
			movzx ecx, byte [r8 + rbx]
			cmp eax, 2
			cmovne ecx, esi			; 2 live neighbours, keep current state
			mov byte [r9+rbx], cl
		.next_cell:
			add ebx, 1
			cmp ebx, array_length		; check whether end of array
			jne .process_cell
			jmp _start.generate_cells


; array cells1 is initialised with pseudorandom cells using a middle-square Weyl sequence RNG
align 16
first_generation:

	mov eax, sys_time
        xor edi, edi 		; time stored in rax, rdi later used as array index counter 
        syscall
	mov r8d, eax 		; r8w stores seed, must be odd
	and eax, 1		; 1 if odd and 0 if even
	sub eax, 1		; map to 0 if odd and - 1 if even
	sub r8d, eax		; make seed odd
	xor ecx, ecx 		; rcx stores random number	
	xor r9d, r9d 		; r9w stores Weyl sequence	
	lea ebx, [rcx+column_cells]	; rbx stores index of next new_line
	lea esi, [rcx+dead]	; rsi stores dead
	lea ebp, [rcx+live]	; rbp stores live
	.init_cell:		
		mov eax, ecx
		lea r10d, [rdi+cells1]
		mul ecx 			; square random number
		add r9d, r8d 		; calculate next iteration of Weyl sequence
		add eax, r9d		; add Weyl sequence
    		movzx ecx, ah		; get lower byte of random number from higher byte of ax
    		movzx eax, dl		; get higher byte of random number from lower byte of dx
		shl eax, 8
		or  eax, ecx
		mov ecx, eax		; save random number for next iteration
		mov edx, esi		; edx=dead
		test eax, 1		; test whether even or odd
		cmovnz edx, ebp		; if odd -> live
		mov [r10], dl 	; store ascii code in array		
		lea eax, [rdi+2]
		lea edx, [rbx+column_cells+1]
		add edi, 1		; increment array index
		cmp edi, ebx		; check whether index of new_line
		cmove ebx, edx
		cmove edi, eax
		cmp edi, array_length	; check whether end of array
		jne .init_cell
		jmp _start.second_gen
