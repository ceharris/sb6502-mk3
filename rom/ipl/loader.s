		.include "ascii.h.s"
		.include "acia.h.s"
		.include "loader.h.s"
		.include "ports.h.s"
		.include "prog.h.s"
		.include "stdio.h.s"

		MAX_REC_LENGTH = $80
		DEFAULT_BASE_BANK = $10
	
		; zero page offsets used for variables
		BASE_BANK = $0
		REC_TYPE = $1
		REC_LENGTH = $2
		CHECKSUM = $3
		ADDRESS = $4
		BOOTSTRAP_VECTOR = $10	; don't want to overwrite ADDRESS

		B = $10			; will overwrite during bootstrap


		.segment "CODE"

;-----------------------------------------------------------------------
; s19_loader:
; A utility routine that loads a program image from Motorola S-records 
; (S19 subset) into mapped memory and then executes the program. Assumes
; that the console ACIA hardware has been initialized for interrupt-
; driven input as the stdio provider.
;
s19_loader:
		; display the startup message
		ldy #<load_message
		lda #>load_message
		jsr cputs

		; load S-records from stdin
		lda #DEFAULT_BASE_BANK
		jsr load_srecs

		; execute the loaded program image
		jmp bootstrap


;-----------------------------------------------------------------------
; load_srecs:
; Load Motorola S-records (S19 subset) from stdin into consecutive RAM
; banks starting with a given bank number.
;
; On entry:
;	A = starting bank number
;
; On return:
;	ADDRESS = entry point address from the terminating S9 record
;	       
;	The program image represented in the S-records is laid out 
;	over the RAM address space starting with the given bank and its
; 	successors.
; 
load_srecs:
		sta BASE_BANK		; save the specified bank number
		
		; await an 'S' at the beginning of a line
		; indicating a legitimate start of record
@await_rec:
		jsr getc
		cmp #'S'
		beq @read_rec		; go read the record
		cmp #CR
		beq @await_rec		; ignore CR
		cmp #LF	
		beq @await_rec		; ignore LF

		; discard input until end-of-line
@discard:
		jsr getc
		cmp #CR
		beq @await_rec		; go if CR
		cmp #LF
		beq @await_rec		; go if LF
		bne @discard		; otherwise discard and try again	

@read_rec:
		stz CHECKSUM
		jsr read_rec_type
		jsr read_rec_length
		jsr read_addr_and_data
		jsr read_checksum

		; is it the terminating record?
		lda REC_TYPE
		cmp #'9'
		bne @await_rec		; go get another record

		; flush any remaining serial input
		ldx #$40
		ldy #0
@flush:
		jsr cgetc		; try to get a char
		bcc @delay		; wait for a while if not avail
		jsr cputc		; echo the char
		cmp #CR			
		bne @flush		; go if not CR
		lda #LF				
		jsr cputc		; send LF after CR
		bra @flush		; keep flushing
@delay:
		; make each loop a bit longer
		nop
		nop
		nop
		nop
		iny			; inner counter
		bne @delay		; keep going until inner is zero
		dex			; outer counter
		bne @flush		; keep going until outer is also zero

		; now we're really done
@done:
		ldy #<ok_message
		lda #>ok_message
		jsr cputs

		; wait for user to press CR
@await_cr:
		jsr cwaitc
		cmp #CR
		bne @await_cr		; ignore other keys
		jsr cputc		; echo CR
		lda #LF
		jsr cputc		; send LF after CR
		rts


;-----------------------------------------------------------------------
; read_rec_type:
; Read the S-record type digit. Returns if and only if record type 
; in {0, 1, 5, 9} (the S19 subset).
;
read_rec_type:
		jsr read_digit
		sta REC_TYPE
		cmp #'0'
		beq @done
		cmp #'1'
		beq @done
		cmp #'5'
		beq @done
		cmp #'9'
		beq @done
		ldy #<err_rec_type
		lda #>err_rec_type
		jmp error
@done:
		rts


;-----------------------------------------------------------------------
; read_rec_length:
; Read the two hexadecimal digits that provide the S-record length.
; Returns if and only if the record length is less than or equal to
; MAX_REC_LENGTH.
;
; On return:
;	REC_LENGTH contains the 8-bit record length
;
read_rec_length:
		jsr read_hex8
		cmp #MAX_REC_LENGTH+1
		bcc @done
		ldy #<err_rec_too_long
		lda #>err_rec_too_long
		jmp error
@done:
		sta REC_LENGTH
		rts


;-----------------------------------------------------------------------
; read_addr_and_data:
; Reads the hexadecimal digits that provide the target address and reads
; digit pairs representing data bytes until REC_LENGTH reaches zero.
; If reading a Type 1 record, the data bytes will be transferred to 
; mapped memory starting at the target address given in the record.
;
; On return:
;	REC_LENGTH = 0
;	mapped memory contains the data from the record
;
read_addr_and_data:
		jsr read_hex8
		sta ADDRESS+1
		jsr read_hex8
		sta ADDRESS+0
		
		; account for the address and checksum in the length
		dec REC_LENGTH
		dec REC_LENGTH
		dec REC_LENGTH

		; empty record?
		lda REC_LENGTH
		beq @done

		; not a data record?
		lda REC_TYPE
		cmp #'1'
		bne @skip

		; determine target bank and map it and its successor
		; into slots 1 and 2
		lda ADDRESS+1
		lsr
		lsr
		lsr
		lsr
		ora BASE_BANK
		sta MMU_SLOT1		; map target bank
		ina
		sta MMU_SLOT2		; and next bank

		; discard bits 15..12 of the address and replace
		; with slot 1 bits (0001)
		lda ADDRESS+1
		and #$0f
		ora #$10
		sta ADDRESS+1

		; transfer the data into the mapped memory
		ldy #0
@copy:
		jsr read_hex8		; read a data byte
		sta (ADDRESS),y		; store it
		iny
		dec REC_LENGTH
		bne @copy
		rts

		; read each data byte to update the checksum
		; (but don't store them anywhere)
@skip:
		jsr read_hex8
		dec REC_LENGTH
		bne @skip

@done:
		rts


;-----------------------------------------------------------------------
; read_checksum:
; Reads the two hexadecimal digits representing the checksum and 
; validates that the computed checksum is correct. Returns only if 
; the checksum is valid.
;
read_checksum:
		jsr read_hex8		; read a byte from record
		lda CHECKSUM		; fetch the computed checksum
		ina			; increment the sum
		bne @bad_sum		; checksum doesn't match
		rts
@bad_sum:
		ldy #<err_bad_checksum
		lda #>err_bad_checksum
		jmp error


;-----------------------------------------------------------------------
; read_hex8:
; Reads two hexadecimal digits as an 8-bit value. 
; Returns if and only if twohexadecimal digits can be read successfully.
;
; On return:
;	A = byte read as two hexadecimal digits
;	CHECKSUM += A
;
read_hex8:
		
		jsr read_hex4		; read first digit
		
		; shift result into upper nibble
		asl
		asl
		asl
		asl
		
		sta B			; store it temporarily
		
		jsr read_hex4		; read second digit
		ora B			; merge in the upper nibble

		; update the checksum
		pha
		clc
		adc CHECKSUM
		sta CHECKSUM
		pla
		rts


;-----------------------------------------------------------------------
; read_hex4:
; Reads a hexadecimal digit as a 4-bit value.
; Returns if and only if a hexadecimal digit can be read successfully.
;
; On return:
;	A = 4-bit binary equivalent of the digit (in the lower nibble)
;
read_hex4:
		jsr read_digit
		cmp #'9'+1
		bcc @no_adjust		; go if digit ($30..39)
		sec		
		sbc #7			; 'A'..'F' ($41..46) mapped to $3A..3F
@no_adjust:
		sec		
		sbc #'0'		; $30..3F mapped to $0..F
		rts


;-----------------------------------------------------------------------
; read_digit:
; Reads an ASCII hexadecimal digit.
; Returns if and only if a hexadecimal digit can be read successfully.
;
; On return:
;	A in ['0'..'9', 'A'..'F']
;
read_digit:
		jsr getc		; read a character
		cmp #'0'
		bcc @bad_digit		; go if below '0'
		cmp #'9'+1
		bcc @done		; go if in '0'..'9'
		and #$df		; upper case only
		cmp #'A'
		bcc @bad_digit		; go if below 'A'
		cmp #'F'+1
		bcs @bad_digit		; go if above 'F'
@done:
		rts
@bad_digit:
		ldy #<err_bad_digit
		lda #>err_bad_digit
		jmp error


;-----------------------------------------------------------------------
; getc:
; Waits for a character from stdin and echoes it to stdout.
; When CR is received, it is echoed as CR+LF.
;
; On return:
;	A = character that was read
;
getc:
		jsr cwaitc		; await input character
		jsr cputc		; echo it
		cmp #CR
		beq @addlf		; go if CR
		rts
@addlf:
		lda #LF			; send LF too
		jsr cputc
		lda #CR			; put back CR
		rts


;-----------------------------------------------------------------------
; error:
; Prints an error message and halts by entering an infinite loop.
; DOES NOT RETURN
;
; On entry:
;	AY = pointer to the error message
;
error:
		; save message pointer
		pha
		phy

		; prefix the message with an ERROR label
		ldy #<error_label
		lda #>error_label
		jsr cputs

		; recover error message pointer and print message
		ply
		pla
		jsr cputs

		; move cursor to new line
		lda #LF
		jsr cputc

		; halt by looping foreever
@halt:
		bra @halt


;-----------------------------------------------------------------------
; bootstrap:
; Maps the loaded program into the processor's address space and then 
; jumps to the program's entry point. 
; 
; DOES NOT RETURN.
;
; The approach:
;	1. Reset stack pointer, disable interrupts, reset ACIA 
;          hardware.
;	2. Load the first bank number (in BASE_BANK) and entry point
;	   address (in ADDRESS) into registers temporarily.
;	3. Map the first bank into slot 0 (replacing the memory used 
;	   for the zero page, stack space, etc, up to $3FFF.
;	4. Restore the values for BASE_BANK and ADDRESS in the newly
;	   mapped zero page.
;	5. Copy a small bootstrap routine (at bootstrap_fn) into the
;	   zero page and jump to it.
;	6. The bootstrap routine maps in the other 15 consecutive 
;	   banks of RAM memory into slots $1..F.
; 	7. Jump to the entry point address (in ADDRESS).
;
bootstrap:
		sei			; disable interrupts
		jsr acia_reset		; reset ACIA hardware
		ldx #$FF
		txs			; reset stack

		; copy zero page variables into registers
		lda BASE_BANK		; A = base bank num
		ldx ADDRESS		; X = entry point LSB
		ldy ADDRESS+1		; Y = entry point MSB

		; map base bank into slot 0
		sta MMU_SLOT0		

		; restore zero page variables
		sta BASE_BANK
		stx ADDRESS
		sty ADDRESS+1

		; copy bootstrap function to zero page
		ldy #0
		ldx #BOOTSTRAP_LENGTH
@loop:
		lda bootstrap_fn,y
		sta BOOTSTRAP_VECTOR,y
		iny
		dex
		bne @loop

		; jump to bootstrap function (in zero page)
		jmp BOOTSTRAP_VECTOR

		; NOTE: this routine executes from the zero page
bootstrap_fn:
		ldx #1			; X = first slot to map
@loop:
		txa
		clc
		adc BASE_BANK		; A = bank to map
		sta MMU_BASE,x		; map bank A into slot X 
		inx			; next slot
		cpx #$10
		bne @loop		; loop until all slots mapped

		; start program at entry point address
		jmp (ADDRESS)

		; compute length of the bootstrap routine
		BOOTSTRAP_LENGTH = *-bootstrap_fn
		; sanity check
	.if BOOTSTRAP_LENGTH > $100 - BOOTSTRAP_VECTOR
		.error "bootstrap function is too big"
	.endif


		.segment "RODATA"
load_message:
		.byte "S19 Loader Ready", LF, NUL
ok_message:
		.byte "Load successful", LF
		.byte "Press Return to execute...", NUL
error_label:
		.byte LF, "ERROR: ", NUL
err_bad_digit:
		.byte "Received invalid character (must be ASCII 0..9 or A..F)", NUL
err_rec_type:
		.byte "Invalid record type (must be S0, S1, S5, or S9)", NUL
err_rec_too_long:
		.byte "Record is too long (must be <= 128)", NUL
err_bad_checksum:
		.byte "Checksum mismatch", NUL
