		.include "ascii.h.s"
		.include "acia.h.s"
		.include "ports.h.s"
		.include "prog.h.s"
		.include "stdio.h.s"

		MAX_REC_LENGTH = $80
		DEFAULT_BASE_BANK = $10
	
		BASE_BANK = $0
		REC_TYPE = $1
		REC_LENGTH = $2
		CHECKSUM = $3
		ADDRESS = $4
		BOOTSTRAP_VECTOR = $10	; don't want to overwrite ADDRESS

		B = $10


		.segment "CODE"
		.word PROG_MAGIC
		.byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, $C, $D, $E, $86
		.word loader

loader:
		jsr cinit
		ldy #<load_message
		lda #>load_message
		jsr cputs
		jsr load_srecs

		jmp bootstrap

load_srecs:
		lda #DEFAULT_BASE_BANK
		sta BASE_BANK
		; await an 'S' at the beginning of a line
		; indicating a legitimate start of record
await_record:
		jsr getc
		cmp #'S'
		beq read_record		; go handle the record
		cmp #CR
		beq await_record	; ignore CR
		cmp #LF	
		beq await_record	; ignore LF

		; discard input until end-of-line
@discard:
		jsr getc
		cmp #CR
		beq await_record	; go if CR
		cmp #LF
		beq await_record	; go if LF
		bne @discard		; otherwise discard and try again	

read_record:
		stz CHECKSUM
		jsr read_rec_type
		jsr read_rec_length
		jsr read_addr_and_data
		jsr read_checksum

		; is it the terminating record?
		lda REC_TYPE
		cmp #'9'
		bne await_record

		; flush any remaining serial input
		ldx #$40
		ldy #0
@flush:
		jsr cgetc
		bcc @delay
		jsr cputc
		cmp #CR
		bne @flush
		lda #LF
		jsr cputc
		bra @flush
@delay:
		nop
		nop
		nop
		nop
		iny
		bne @delay
		dex
		bne @flush		
@done:
		ldy #<ok_message
		lda #>ok_message
		jsr cputs
		lda #LF
		jsr cputc
		rts

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

read_addr_and_data:
		jsr read_hex8
		sta ADDRESS+1
		jsr read_hex8
		sta ADDRESS+0
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
@skip:
		; read each data byte to update the checksum
		; (but don't store them anywhere)
		jsr read_hex8
		dec REC_LENGTH
		bne @skip
@done:
		rts

read_checksum:
		jsr read_hex8
		lda CHECKSUM
		ina
		bne @bad_sum
		rts
@bad_sum:
		ldy #<err_bad_checksum
		lda #>err_bad_checksum
		jmp error

read_hex8:
		jsr read_hex4
		asl
		asl
		asl
		asl
		sta B
		jsr read_hex4
		ora B
		pha
		clc
		adc CHECKSUM
		sta CHECKSUM
		pla
		rts

read_hex4:
		jsr read_digit
		cmp #'9'+1
		bcc @no_adjust
		sec
		sbc #7		
@no_adjust:
		sec
		sbc #'0'
		rts

read_digit:
		jsr getc
		cmp #'0'
		bcc @bad_digit
		cmp #'9'+1
		bcc @done
		cmp #'A'
		bcc @bad_digit
		cmp #'F'+1
		bcs @bad_digit
@done:
		rts
@bad_digit:
		ldy #<err_bad_digit
		lda #>err_bad_digit
		jmp error

getc:
		jsr cwaitc
		jsr cputc
		cmp #CR
		beq @addlf
		rts
@addlf:
		pha
		lda #LF
		jsr cputc
		pla
		rts

error:
		pha
		phy
		ldy #<error_label
		lda #>error_label
		jsr cputs
		ply
		pla
		jsr cputs
		lda #LF
		jsr cputc
halt:
		jmp halt

bootstrap:
		sei
		jsr acia_reset

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

bootstrap_fn:
		ldx #1
@loop:
		txa
		clc
		adc BASE_BANK
		sta MMU_BASE,x
		inx
		cpx #$10
		bne @loop
		jmp (ADDRESS)

		BOOTSTRAP_LENGTH = *-bootstrap_fn
	.if BOOTSTRAP_LENGTH > $100 - BOOTSTRAP_VECTOR
		.error "bootstrap function is too big"
	.endif


		.segment "RODATA"
load_message:
		.byte "Awaiting S-records", LF, NUL
ok_message:
		.byte "Load successful", LF, NUL
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
