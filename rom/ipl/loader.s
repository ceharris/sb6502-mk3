		.include "ascii.h.s"
		.include "acia.h.s"
		.include "hex.h.s"
		.include "loader.h.s"
		.include "ports.h.s"
		.include "prog.h.s"
		.include "stdio.h.s"

		MAX_REC_LENGTH = $80
		DEFAULT_BASE_BANK = $10
		DEFAULT_ENTRY_POINT = $0200
	
		SREC_START = 'S'
		SREC_TYPE_HEADER = '0'
		SREC_TYPE_DATA = '1'
		SREC_TYPE_COUNT = '5'
		SREC_TYPE_END = '9'

		IHEX_START = ':'
		IHEX_TYPE_DATA = 0
		IHEX_TYPE_END = 1
		IHEX_TYPE_EXTENDED_ADDR = 4
		IHEX_TYPE_START_ADDR = 5

		; zero page offsets used for variables
		BASE_BANK = $0
		REC_TYPE = $1
		REC_LENGTH = $2
		CHECKSUM = $3
		ADDRESS = $4
		ENTRY_POINT = $6

		B = $10			; will overwrite during bootstrap


		.segment "CODE"

;-----------------------------------------------------------------------
; loader:
; A utility routine that loads a program image from a supported
; text format -- either Motorola S-record (S19 subset) or Intel Hex.
; The format is detected by the first start-of-record character.
;
; The program image is mapped into consecutive RAM memory banks 
; starting at DEFAULT_BASE_BANK (the start of which corresponds to
; image address 0) and continuing through DEFAULT_BASE_BANK+15 
; (the end of which corresponds to image address $FFFF).
; 
; Assumes that the console ACIA hardware has been initialized for 
; interrupt-driven input as the stdio provider, and that the sender
; will respond to RTS/CTS handshake.
;
loader:
		; display the startup message
		ldy #<load_message
		lda #>load_message
		jsr cputs

		lda #DEFAULT_BASE_BANK
		sta BASE_BANK		; set BASE_BANK to default

		; default entry point address is zero
		stz ENTRY_POINT
		stz ENTRY_POINT+1

		stz REC_TYPE		; zero to allow either start
		jsr await_start

		cmp #IHEX_START
		beq @is_intel

		jsr load_srec
		bra @finish_up
@is_intel:
		jsr load_ihex

@finish_up:

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
		iny			; inner counter
		bne @delay		; keep going until inner is zero
		dex			; outer counter
		bne @flush		; keep going until outer is also zero

		; print success message
		ldy #<ok_message
		lda #>ok_message
		jsr cputs

		jsr get_exec_addr	; allow user to choose address
		jmp bootstrap


;-----------------------------------------------------------------------
; load_srec:
; Load Motorola S-records (S19 subset).
;
; On return:
;	ENTRY_POINT = entry point address from the terminating S9 record
;	       
;	The program image represented in the S-records is laid out 
;	over the mapped address space.
; 
load_srec:
		stz CHECKSUM
		jsr read_srec_type
		jsr read_rec_length
		jsr read_address

		; account for the address and checksum in the length
		dec REC_LENGTH
		dec REC_LENGTH
		dec REC_LENGTH

		; empty record?
		lda REC_LENGTH
		beq @finish_rec

		; is it a data record?
		lda REC_TYPE
		cmp #SREC_TYPE_DATA
		bne @not_data
		jsr read_data
		bra @finish_rec
@not_data:
		jsr skip_data
@finish_rec:
		jsr read_srec_checksum

		; is it the terminating record?
		lda REC_TYPE
		cmp #SREC_TYPE_END
		bne @next_rec
		lda ADDRESS
		sta ENTRY_POINT
		lda ADDRESS+1
		sta ENTRY_POINT+1
		rts
@next_rec:
		lda #SREC_START
		sta REC_TYPE
		jsr await_start
		bra load_srec


;-----------------------------------------------------------------------
; load_ihex:
; Load Intel Hex records.
;
; On return:
;	ENTRY_POINT = entry point address from a type 5 record if present,
;                     otherwise the address from the type 1 record
;	       
;	The program image represented in the hex is laid out over the 
;       mapped address space.
; 
load_ihex:
		stz CHECKSUM
		jsr read_rec_length
		jsr read_address
		jsr read_ihex_type

		lda REC_LENGTH
		beq @finish_rec		; empty record

		lda REC_TYPE
		cmp #IHEX_TYPE_DATA
		bne @not_data		; not a data record
		jsr read_data
		bra @finish_rec
@not_data:
		cmp #IHEX_TYPE_START_ADDR
		bne @skip_it		; go if not start address record
		jsr read_ihex_entry_point
		bra @finish_rec
@skip_it:
		jsr skip_data	
@finish_rec:
		jsr read_ihex_checksum

		; is it the terminating record?
		lda REC_TYPE
		cmp #IHEX_TYPE_END
		bne @next_rec

		; is there already an entry point address?
		lda ENTRY_POINT
		bne @done
		lda ENTRY_POINT+1
		bne @done
		; use the address from the end record as a default
		lda ADDRESS
		sta ENTRY_POINT
		lda ADDRESS+1
		sta ENTRY_POINT+1
@done:
		rts
@next_rec:
		lda #IHEX_START
		sta REC_TYPE
		jsr await_start
		bra load_ihex


;-----------------------------------------------------------------------
; read_srec_type:
; Read the S-record type digit. Returns if and only if record type 
; in {0, 1, 5, 9} (the S19 subset).
;
read_srec_type:
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
; read_ihex_type:
; Read the hex record type digit. Returns if and only if record type 
; in {0, 1, 4, 5}.
;
read_ihex_type:
		jsr read_hex8
		sta REC_TYPE
		cmp #IHEX_TYPE_DATA
		beq @done
		cmp #IHEX_TYPE_END
		beq @done
		cmp #IHEX_TYPE_EXTENDED_ADDR
		beq @done
		cmp #IHEX_TYPE_START_ADDR
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
; read_address
; Reads the hexadecimal digits that provide the target address.
;
read_address:
		jsr read_hex8
		sta ADDRESS+1
		jsr read_hex8
		sta ADDRESS+0
		rts

;-----------------------------------------------------------------------
; read_data:
; Read the data from the record into mapped memory at the address
; specified by ADDRESS.
;
; On entry:
; 	REC_LENGTH >= 1
;	ADDRESS = target address in mapped memory
;
; On return:
;	REC_LENGTH = 0
;	CHECKSUM incremented with every byte read
;	mapped memory contains the data from the record
;
read_data:
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


;-----------------------------------------------------------------------
; skip_data:
; Read and discard the data from the current record.
;
; On entry:
; 	REC_LENGTH >= 1
;
; On return:
;	REC_LENGTH = 0
;	CHECKSUM incremented with every byte read
;
skip_data:
		jsr read_hex8
		dec REC_LENGTH
		bne skip_data
		rts


;-----------------------------------------------------------------------
; read_ihex_entry_point:
; Reads the entry point address from the data field of an Intel type 5
; record.
;
; On return:
;	ENTRY_POINT = address from the record
;
read_ihex_entry_point:
		; the field contains a 32-bit big endian address
		; read and ignore the first two bytes
		jsr read_hex8
		jsr read_hex8
		; read and store the 16-bit address
		jsr read_hex8
		sta ENTRY_POINT+1
		jsr read_hex8
		sta ENTRY_POINT
		rts


;-----------------------------------------------------------------------
; read_srec_checksum:
; Reads the two hexadecimal digits representing the checksum and 
; validates that the computed checksum is correct. Returns only if 
; the checksum is valid.
;
read_srec_checksum:
		jsr read_hex8		; read a byte from record
		lda CHECKSUM		; fetch the computed checksum
		ina			; increment the sum
		bne bad_checksum	; checksum doesn't match
		rts


;-----------------------------------------------------------------------
; read_ihex_checksum:
; Reads the two hexadecimal digits representing the checksum and 
; validates that the computed checksum is correct. Returns only if 
; the checksum is valid.
;
read_ihex_checksum:
		jsr read_hex8
		lda CHECKSUM
		bne bad_checksum
		rts


;-----------------------------------------------------------------------
; bad_checksum:
; Halt with a bad checksum error.
;
bad_checksum:
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
; await_start:
; Awaits the start of a record.
;
; On entry:
;	REC_TYPE = SREC_START to look for a Motorola record
;		   IHEX_START to look for an Intel record
;		   NULL to look for either record format
; On return:
;	A = start of record character
;	B clobbered
;
await_start:
		jsr getc
		cmp #SREC_START
		beq @found_start
		cmp #IHEX_START
		beq @found_start
		cmp #NUL
		beq await_start		; ignore NUL
		cmp #CR
		beq await_start		; ignore CR
		cmp #LF	
		beq await_start		; ignore LF

		; discard input until end-of-line
@discard:
		jsr getc
		cmp #CR
		beq await_start		; go if CR
		cmp #LF
		beq await_start		; go if LF
		bne @discard		; otherwise discard and try again	

		; found a start characger -- which one did we expect?
@found_start:
		cmp REC_TYPE
		beq @done		; found what we expected
		sta B			; save it
		lda REC_TYPE		; okay with either of them?
		bne await_start		; nope... go try again
		lda B			; recover it
@done:
		rts


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
; get_exec_addr:
; Gets the entry point address for program execution from the user.
; If an entry point address was included in the image data, it is used
; here as a default.
;
; On entry:
;	ENTRY_POINT = default entry point address
;
get_exec_addr:
@again:
		; print first segment of prompt
		ldy #<addr_prompt1
		lda #>addr_prompt1
		jsr cputs
		; print the default entry point address
		lda ENTRY_POINT+1
		jsr phex8
		lda ENTRY_POINT
		jsr phex8
		; print the last segment of prompt
		ldy #<addr_prompt2
		lda #>addr_prompt2
		jsr cputs
		
		; get user input
		jsr cgets
		cmp #CR			; check terminating char
		bne @again		; go if not Return key
		lda #LF
		jsr cputc		; move to next line
		
		; parse user input
		ldy #0			; start at beginning of input string
@strip:
		lda (STDIO_W0),y	; get character
		iny
		cmp #SPC
		beq @strip		; discard whitespace
		cmp #HT
		beq @strip		; discard whitespace
		cmp #'$'		; ignore $ if it appears before address
		bne @parse
		iny			; discard '$'
@parse:
		dey			; rewind to char that exited strip loop
		tya			; A = input pointer
		tax			; X = input pointer
		jsr hextok		; scan for hexadecimal input
		cmp #0
		beq @use_default	; go if no digits entered
		cmp #4+1
		bcs @again		; go if more than four digits entered
		lsr			; set carry if odd count
		txa			; A = input pointer
		tay			; Y = input pointer
		bcc @parse_first_two	; go if even count
		jsr ihex4		; parse first digit
		bra @parse_next
@parse_first_two:
		jsr ihex8		; parse first two digits
@parse_next:
		sta ENTRY_POINT		; assume it's the LSB
		stz ENTRY_POINT+1	; ... and that the MSB is zero
		lda (STDIO_W0),y
		beq @parse_done	 	; only the LSB was given
		lda ENTRY_POINT
		sta ENTRY_POINT+1	; first part was actually MSB
		jsr ihex8		; parse the last two digits
		sta ENTRY_POINT		; save the LSB
@parse_done:
		lda (STDIO_W0),y
		bne @again 		; go if extraneous input
@use_default:
		lda #LF			; go to next line
		jsr cputc
		rts		


;-----------------------------------------------------------------------
; bootstrap:
; Maps the loaded program into the processor's address space and then 
; jumps to the program's entry point. This is designed to allow a 
; loaded program to initialize any portion of RAM except for the stack
; space from $100..1FF as part of the load image.
; 
; DOES NOT RETURN.
;
; The approach:
;	1. Reset stack pointer, disable interrupts, reset ACIA 
;          hardware.
;	2. Load the first bank number (in BASE_BANK) and entry point
;	   address (in ENTRY_POINT) into registers temporarily.
;	3. Map the first bank into slot 0 (replacing the memory used 
;	   for the zero page, stack space, etc, up to $3FFF.
;	4. Save the values for BASE_BANK and ENTRY_POINT on the stack
;          in the newly mapped memory in slot 0.
;	5. Copy a small bootstrap routine (at bootstrap_fn) into the
;	   base of the stack space.
;       6. Modify the bootstrap routine (in the stack space) to set
;          the first bank number and entry point addresses in the
;          appropriate instructions, using values recoved from the
;          stack.
;       7. Jump to the boostrap routine at the base of the stack space.
;          (In the bootstrap routine)
;	8. Map in the other 15 consecutive banks of RAM memory into 
;          slots $1..F.
; 	7. Jump to the entry point address.
;
bootstrap:
		sei			; disable interrupts
		jsr acia_shutdown	; reset ACIA hardware
		ldx #$FF
		txs			; reset stack

		; preserve zero page variables in registers
		lda BASE_BANK		; A = base bank num
		ldx ENTRY_POINT		; X = entry point LSB
		ldy ENTRY_POINT+1	; Y = entry point MSB

		; map base bank into slot 0
		sta MMU_SLOT0		; replaces all RAM from $0000..3FFF

		; transfer zero page variables to (new) stack
		pha			; save base bank number
		phx			; save entry point LSB
		phy			; save entry point MSB

		; copy bootstrap function to base of stack space
		BOOTSTRAP_VECTOR = $100
		ldy #0
		ldx #BOOTSTRAP_LENGTH
@loop:
		lda bootstrap_fn,y
		sta BOOTSTRAP_VECTOR,y
		iny
		dex
		bne @loop

		; modify the bootstrap function to fill in the
		; base bank number and entry point address
		ply			; recover entry point MSB
		sty BOOTSTRAP_VECTOR+BOOTSTRAP_ENTRY_POINT_OFFSET+1
		plx			; recover entry point LSB
		stx BOOTSTRAP_VECTOR+BOOTSTRAP_ENTRY_POINT_OFFSET
		pla			; recover base bank number
		sta BOOTSTRAP_VECTOR+BOOTSTRAP_BASE_BANK_OFFSET	

		; jump to bootstrap function (at base of stack space)
		jmp BOOTSTRAP_VECTOR

;-----------------------------------------------------------------------
; bootstrap_fn:
; This small routine is copied into the stack address space
; (at BOOTSTRAP_VECTOR) and then modified to set the base bank
; and entry point address before execution.
;
		DUMMY = $ffff		
bootstrap_fn:
		ldx #1			; X = first slot to map
bootstrap_fn_loop:
		txa
		clc
		adc #<DUMMY		; A = bank to map
		BOOTSTRAP_BASE_BANK_OFFSET = *-bootstrap_fn-1

		sta MMU_BASE,x		; map bank A into slot X 
		inx			; next slot
		cpx #$10
		bne bootstrap_fn_loop	; loop until all slots mapped

		; start program at entry point address
		jmp DUMMY
		BOOTSTRAP_ENTRY_POINT_OFFSET = *-bootstrap_fn-2

		; compute length of the bootstrap routine
		BOOTSTRAP_LENGTH = *-bootstrap_fn

		; sanity check
	.if BOOTSTRAP_LENGTH > $100-$10
		.error "bootstrap function is too big"
	.endif


		.segment "RODATA"
load_message:
		.byte "S19/IHEX Loader Ready", LF, NUL
ok_message:
		.byte "Load successful", LF, NUL
addr_prompt1:
		.byte "Execute at [", NUL
addr_prompt2:
		.byte "]: ", NUL
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
