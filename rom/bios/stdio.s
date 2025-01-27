		.include "ascii.h.s"
		.include "registers.h.s"
		.include "stdio.h.s"

		.segment "CODE"

;-----------------------------------------------------------------------
; cputc:
; Prints a single character on the console. A newline character (ASCII LF)
; is automatically translated to CR + LF for the console terminal.
;
; On entry:
;	A = the character to print
;
	.proc cputc
		cmp #LF
		beq @newline
		jsr acia_putc
		rts
@newline:
		lda #CR
		jsr acia_putc
		lda #LF
		jsr acia_putc
		rts
	.endproc		


;-----------------------------------------------------------------------
; cgets:
; Reads a string from the console input. The string is read one character
; at a time until an ASCII carriage return (CR) or Ctrl-C is input. 
; Rudimentary editing using either ASCII backspace (BS) or delete (DEL) 
; is supported. Ctrl-U can be used to clear the entire input and start over.
;
; On entry:
;       w0 = address of a buffer
;	b0 = size of the buffer in bytes
; 
; On return:
; 	buffer at w0 contains a null-terminated string
;	b0 = number of characters placed into the buffer 
;            (less the null-terminator)
;	A = input character that terminated input, ASCII CR or CTRL_C
;
	.proc cgets
		; preserve registers
		phx
		phy

		ldy #0			; Y counts number of chars input
		ldx b0			; X counts the buffer space remaining
@next_char:
		jsr acia_getc		; get a character if available
		bcc @next_char		; keep trying if none available
		sta b0			; preserve input character
		cmp #BS			; is it Backspace?
		beq @delete_char
		cmp #DEL		; is it Delete?
		beq @delete_char
		cmp #CR			; is it Return?
		beq @done
		cmp #CTRL_C		; is it Ctrl-C?
		beq @done
		cmp #CTRL_U		; is it Ctrl-U?
		beq @clear_input
		cmp #SPC		; is it some other control character?
		bcc @next_char
		cmp #DEL		; is it outside of ASCII range?
		bcs @next_char
		tax			; A = remaining buffer space			
		dec a			; leave room for null terminator
		bne @store_char		; if there's room, store input char
		lda #BEL		; ring the bell
		jsr acia_putc		
		bra @next_char
@store_char:
		lda b0			; recover input character
		sta (w0),y		; store in caller's buffer
		dex			; --buffer space remaining
		iny			; ++number of chars input
		jsr acia_putc		; echo the input character
		bra @next_char
@delete_char:
		tya			; A = number of chars input
		beq @next_char		
		inx			; ++buffer space remaining
		dey			; --number of chars input
		jsr @rubout
		bra @next_char
@clear_input:
		tya			; A = number of chars input
		beq @next_char
		jsr @rubout
		inx			; ++buffer space remaining
		dey			; --number of chars input
		bra @clear_input
@rubout:
		lda #BS
		jsr acia_putc		; move cursor backward
		lda #SPC
		jsr acia_putc		; print a space
		lda #BS			; 
		jsr acia_putc		; move cursor backward
		rts
@done:
		pha			; preserve terminating char
		lda #0			
		sta (w0),y		; null-terminate the input string
		sty b0			; save number of characters input
		pla
		ply
		plx
		rts

	.endproc


;-----------------------------------------------------------------------
; cputs:
; Prints a string on the console output. The string must be null
; terminated and more than 256 characters in length.
;
; On entry:
;       w0 = pointer to a null-terminated string
;
	.proc cputs
		phy
		ldy #0
@next:
		lda (w0),y
		beq @done
		jsr cputc
		iny
		bne @next
@done:
		ply
		rts
	.endproc

