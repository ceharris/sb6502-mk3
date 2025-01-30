
		.include "ansi.h.s"
		.include "ascii.h.s"
		.include "conf.h.s"
		.include "hex.h.s"
		.include "prog.h.s"
		.include "ports.h.s"
		.include "stdio.h.s"

		.global ipl


		IPL_BANK = $87

		PROG_SLOT = $4
		PROG_SLOT_ADDRESS = PROG_SLOT<<12
		PROG_HEADER_LENGTH = 2 + 16 + 2		; magic word + 16 slot mappings + entry point address

		BOOTSTRAP_VECTOR = $200

		B = $0

		.segment "RODATA"
progtab:
		.byte 0
		.byte $80	; 0: Monitor
		.word monitor_label
		.byte 1
		.byte $81	; 1: Microsoft BASIC
		.word msbasic_label
		.byte 2
		.byte $84	; 2: Snake
		.word snake_label
		.byte $FF

id_message:
		ansi_home
		ansi_erase_display
		.byte BEL, "SB6502 Mk 3", LF, NUL
err_message:
		.byte "Invalid program header", LF, NUL

monitor_label:
		.byte "Monitor", NUL
msbasic_label:
		.byte "Microsoft BASIC", NUL
snake_label:
		.byte "Snake", NUL

prompt:
		.byte "Enter item number or memory bank address: ", NUL		

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
@loop:
		jsr prog_select		; allow user to select the program
		jsr prog_load		; map and validate the header
		bcs @loop		; try again if invalid bank header
@bootstrap:
		jsr bootstrap_copy	; copy the bootstrap routine to RAM
		jmp BOOTSTRAP_VECTOR	; bootstrap the selected program


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
		lda (STDIO_W0),y	; get first character
		iny
		cmp #SPC
		beq @strip		; discard whitespace
		cmp #HT
		beq @strip		; discard whitespace
		sta B			; store it elsewhere
		cmp #'$'		; '$' indicates a direct bank selection
		bne @parse
		iny			; discard '$'
@parse:
		; save input pointer in X
		dey
		tya
		tax
		jsr hextok		; scan for hexadecimal input
		cmp #0
		beq @select		; go if no digits entered
		cmp #2+1
		bcs @select		; go if more than two digits entered
		lsr			; set carry if one digit
		; recover input pointer from X
		txa
		tay
		bcc @parse_two		; go if two digits
		jsr ihex4
		bra @parse_done
@parse_two:
		jsr ihex8
@parse_done:
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
; bootstrap_copy:
; Copies `bootstrap_fn` into RAM slot 0 at the address specified by
; BOOTSTRAP_VECTOR.
;
bootstrap_copy:
		ldx #<BOOTSTRAP_FN_LENGTH
		ldy #0
@loop:
		lda bootstrap_fn,y
		sta BOOTSTRAP_VECTOR,y
		iny
		dex
		bne @loop
		rts


;-----------------------------------------------------------------------
; bootstrap_fn:
; This relocatable function is copied into RAM in page 0, which will
; remain resident as the requested system program is mapped into memory.
; After it is copied, it is executed by jumping to the address defined
; as BOOTSTRAP_VECTOR.
;
; On entry, the header bank for the program must be mapped into
; the slot identified as PROG_SLOT. It is assumed that the bank header
; has already been validated.
;
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
	
	stz 0				; ensure that slot 0 does not change

	; Configure the MMU using the bank mapping table
	ldx #16				; slot count
	ldy #0				; slot index
@config_next:
	lda 0,y				; fetch bank number from zero page
	sta MMU_BASE,y			; store bank number in bank register
	iny
	dex
	bne @config_next

	jmp ($10)			; transfer control to the program

BOOTSTRAP_FN_LENGTH = * - bootstrap_fn
.if BOOTSTRAP_FN_LENGTH > 256
.error "bootstrap function is too big"
.endif

