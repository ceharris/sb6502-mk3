
		.include "ansi.h.s"
		.include "ascii.h.s"
		.include "conf.h.s"
		.include "hex.h.s"
		.include "loader.h.s"
		.include "prog.h.s"
		.include "ports.h.s"
		.include "stdio.h.s"

		.global ipl


		IPL_BANK = $87

		PROG_SLOT = $4
		PROG_SLOT_ADDRESS = PROG_SLOT<<12
		PROG_HEADER_LENGTH = 2 + 16 + 2		; magic word + 16 slot mappings + entry point address

		BOOTSTRAP_VECTOR = $300

		B = $0

		.segment "RODATA"
progtab:
		.byte 1
		.byte $81	; 2: Microsoft BASIC
		.word msbasic_label
		.byte 2
		.byte $84	; 2: EhBASIC
		.word ehbasic_label
		.byte 3
		.byte $8A	; 3: Tali Forth 2
		.word taliforth_label
		.byte 4
		.byte $84	; 4: Snake
		.word snake_label
		.byte 9
		.byte $80	; 9: Monitor
		.word monitor_label
		.byte $FF

id_message:
		ansi_reset
		ansi_home
		ansi_erase_display
		.byte BEL, "SB6502 Mk 3", LF, NUL
err_message:
		.byte "Invalid program header", LF, NUL
loader_label:
		.byte "S19 Loader", NUL
monitor_label:
		.byte "Monitor", NUL
msbasic_label:
		.byte "Microsoft BASIC", NUL
ehbasic_label:
		.byte "EhBASIC", NUL
snake_label:
		.byte "Snake", NUL
taliforth_label:
		.byte "Tali Forth 2", NUL

prompt:
		.byte "Enter item number, memory bank address, or (L)oad: ", NUL		

		.segment "CODE"

;-----------------------------------------------------------------------
; ipl:
; Initial program load. This routine puts the hardware into a known
; configuration with the MMU enabled, and then executes the monitor.
;
ipl:
		sei			; inhibit interrupts
		cld			; clear decimal mode
		ldx #$ff		
		txs			; initialize stack

		jsr mmu_init		; initialize the MMU
		jsr cinit		; initialize standard I/O

		; display startup message
		ldy #<id_message
		lda #>id_message
		jsr cputs

		lda CONF_REG
		lsr			; set carry if CFD0 is high
		bcs @load		; use the loader
@select:
		jsr prog_select		; allow user to select the program
		bcs @load		; use the loader
		jsr prog_load		; map and validate the header
		bcs @select		; try again if invalid bank header

		; go execute program in selected bank
		jmp bootstrap

@load:
		jmp loader		; run the loader

;-------------------------------------------------------------------
; mmu_init:
; Initialize the MMU's bank registers with a default configuration
; that puts RAM in slots $0..E and maps slot $F to the bank that
; contains this program.
;
mmu_init:
		; map slots $0..E to RAM banks $0..E
		ldx #15			; number of slots
		ldy #0			; slot number
@loop:
		tya			; bank number is slot number
		sta MMU_BASE,y
		iny			; next slot
		dex
		bne @loop

		; map slot $F to the ROM bank identified as IPL_BANK
		lda #IPL_BANK
		sta MMU_SLOTF	

		; enable the MMU
		lda CONF_REG
		ora #CONF_MMUE
		sta CONF_REG

		rts

;-----------------------------------------------------------------------
; prog_select:
; Prompt the user with program selections and get the user's choice.
;
; On return:
;	A = bank number of the selected program
;
prog_select:
		lda #LF
		jsr cputc
		ldx #0
@loop:
		lda progtab,x		; get BCD option number
		bmi @menu_end		; go if end of table

		; print option number
		cmp #$10
		bcs @print_two
		jsr phex4
		bra @print_label
@print_two:
		jsr phex8

@print_label:
		; skip forward to the menu label address
		inx
		inx		
		
		; display the corresponding menu label
		lda #'.'
		jsr cputc	
		lda #SPC
		jsr cputc
		lda progtab,x		; menu label LSB
		inx
		tay
		lda progtab,x		; menu label MSB
		inx
		jsr cputs
		lda #LF
		jsr cputc
		bra @loop
@menu_end:
		lda #LF
		jsr cputc
@select:
		; display prompt
		ldy #<prompt
		lda #>prompt
		jsr cputs

		; get user input
		jsr cgets
		cmp #CR			; check terminating char
		bne @select		; go if not Return key
		lda #LF
		jsr cputc		; move to next line
		
		; parse user input
		ldy #0			; start at beginning of input string
@strip:
		lda (STDIO_W0),y	; get character
		iny
		cmp #'L'
		beq @load		; go if (L)oad requested
		cmp #'l'
		beq @load		; go if (L)oad requested
		cmp #SPC
		beq @strip		; discard whitespace
		cmp #HT
		beq @strip		; discard whitespace
		sta B			; store it elsewhere
		cmp #'$'		; '$' indicates a direct bank selection
		bne @parse
		iny			; discard '$'
@parse:
		dey
		tya			; A = input pointer
		tax			; X = input pointer
		jsr hextok		; scan for hexadecimal input
		cmp #0
		beq @select		; go if no digits entered
		cmp #2+1
		bcs @select		; go if more than two digits entered
		txa			; A = input pointer
		tay			; Y = input pointer
		lda STDIO_B0		; A = number of digits to parse
		jsr ihex8		; parse hex digits
		tax			; X = converted input value

		; check for end of input
		lda (STDIO_W0),y
		bne @select	 	; go if extraneous input remains

@check_direct:
		; check for direct bank selection
		lda B			; get first input character
		cmp #'$'
		bne @find_in_menu
		txa			; use entered value as bank number
		clc			; user wants selected bank
		rts

		; find user's menu choice
@find_in_menu:		
		txa
		tay			; Y = user's input
		ldx #0
@match:
		tya			; A = user's input
		cmp progtab,x		; compare to first byte of menu entry
		beq @found		; go if it's a match

		; advance to next menu entry
		inx
		inx
		inx
		inx
		; at end of menu?
		lda progtab,x
		bpl @match		; keep looking if more entries
		bra @select		; try again
@found:
		inx				
		lda progtab,x		; get bank number from menu entry
		clc			; user wants the selected bank
		rts

@load:
		sec			; user wants the loader
		rts

;-----------------------------------------------------------------------
; prog_load:
; Maps a program bank into PROG_SLOT and validates the header.
;
; On entry:
;	A = bank number to load
;
; On return:
;	If carry clear, memory at PROG_SLOT_address contains a valid 
;	program header. Otherwise (carry set) the specified bank doesn't
;	contain a valid header.
;
prog_load:
		; map the specified bank into PROG_SLOT
		sta MMU_BASE+PROG_SLOT

 		; check for magic word
		lda #<PROG_MAGIC
		cmp PROG_SLOT_ADDRESS
		bne @error
		lda #>PROG_MAGIC
		cmp PROG_SLOT_ADDRESS+1
		bne @error
		clc
		rts		
@error:
		; put the default RAM bank back into the slot
		lda #PROG_SLOT
		sta MMU_BASE+PROG_SLOT

		; display error message
		ldy #<err_message
		lda #>err_message
		jsr cputs

		sec		 	; signal error
		rts


;-----------------------------------------------------------------------
; bootstrap:
; Maps the selected program into the processor's address space and then 
; jumps to the program's entry point.
; 
; On entry:
;	Memory slot at PROG_SLOT is mapped to the first bank of the
;	selected program. It begins with a header that describes the
;	memory map desired by the program.
;		offset $00 = [ 2 bytes] magic number
;		offset $02 = [ 1 byte ] unused (slot 0 is always mapped to $0)
;		offset $03 = [15 bytes] bank map table for slots $1..$F
;		offset $12 = [ 2 bytes] entry point address
; 
; DOES NOT RETURN.
;
; The approach:
;	1. Reset stack pointer, disable interrupts, reset ACIA 
;          hardware.
;	2. Copy a small bootstrap routine (at bootstrap_fn) into 
;	   slot 0 RAM (below $1000) and jump to it.
;	3. Copy the bank map table and entry point address from 
;          the program bank header into the zero page at address 0.
;       4. Map slots $1..F of the address space using the bank map 
;          table at address 0.
;       5. Jump to the entry point address from the program header.
;
bootstrap:
		sei			; disable interrupts
		jsr acia_shutdown	; reset ACIA hardware
		ldx #$ff
		txs			; reset stack

		; copy the bootstrap routine into RAM in slot 0
		ldx #<BOOTSTRAP_FN_LENGTH
		ldy #0
@loop:
		lda bootstrap_fn,y
		sta BOOTSTRAP_VECTOR,y
		iny
		dex
		bne @loop

		jmp BOOTSTRAP_VECTOR

bootstrap_fn:
		; Copy the header (excluding the magic word) into the zero page
		; This copies the bank mapping table into $0..F, and puts the
		; entry point address at $10.
		ldx #PROG_HEADER_LENGTH-2
		ldy #0
@copy_next:
		lda PROG_SLOT_ADDRESS+2,y
		sta 0,y
		iny
		dex
		bne @copy_next
		
		; Configure the MMU using the bank mapping table
		ldx #1				; slot index (skip slot 0)
@config_next:
		lda 0,x				; fetch bank number from zero page
		sta MMU_BASE,x			; store bank number in bank register
		inx
		cpx #$10
		bne @config_next		; go for slots $0..F

		jmp ($10)			; transfer control to the program

BOOTSTRAP_FN_LENGTH = * - bootstrap_fn
.if BOOTSTRAP_FN_LENGTH > 256
.error "bootstrap function is too big"
.endif

