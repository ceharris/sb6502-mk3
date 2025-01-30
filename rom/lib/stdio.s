		.include "ascii.h.s"
		.include "stdio.h.s"

		.segment "CODE"


;-----------------------------------------------------------------------
; cwaitc:
; Waits for an input character from the console.
;
; On return:
;	A = the input character
;
cwaitc:
		jsr acia_getc
		bcc cwaitc
		rts

;-----------------------------------------------------------------------
; cputc:
; Prints a single character on the console. A newline character (ASCII LF)
; is automatically translated to CR + LF for the console terminal.
;
; On entry:
;	A = the character to print
;
cputc:
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

;-----------------------------------------------------------------------
; cputcc:
; Puts a character, but translates control characters to a printable
; form. Intended mostly for debugging.
;
; On entry:
;	A = character to put
;
; On return:
;	A = A' + $40 if A' < $20 otherwise A is unchanged
;
cputcc:
		cmp #SPC
		bcs cputc
		pha
		lda #'^'
		jsr cputc
		pla
		clc
		adc #'@'
		bra cputc


;-----------------------------------------------------------------------
; cgets:
; Reads a string from the console input. The string is read one character
; at a time until an ASCII carriage return (CR) or Ctrl-C is input. 
; Rudimentary editing using either ASCII backspace (BS) or delete (DEL) 
; is supported. Ctrl-U can be used to clear the entire input and start over.
;
; On return:
;	A = input character that terminated input, ASCII CR or CTRL_C
;	(STDIO_W0) = pointer to the input string
;	(STDIO_B0) = the number of chracters input less the terminator
;
cgets:
		phx
		phy

		ldy #0			; Y counts number of chars input
		ldx #STDIO_BUF_LEN - 1  ; X counts the buffer space remaining
@next_char:
		jsr acia_getc		; get a character if available
		bcc @next_char		; keep trying if none available
		sta STDIO_BUF_ADDR,y	; store the input character
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
		txa			; A = remaining buffer space
		bne @store_char		; if there's room, keep it
		lda #BEL		; ring the bell
		jsr acia_putc		
		bra @next_char
@store_char:
		lda STDIO_BUF_ADDR,y	; recover input character
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
		sty STDIO_B0		; save the number of characters input
		tax			; save the char that ended input
		
		; null-terminate the input string
		lda #0
		sta STDIO_BUF_ADDR,y	

		; put the input buffer address into STDIO_W0
		lda #<STDIO_BUF_ADDR
		sta STDIO_W0
		lda #>STDIO_BUF_ADDR
		sta STDIO_W0+1
	
		txa			; recover the char that ended input
		ply
		plx
		rts


;-----------------------------------------------------------------------
; cputs:
; Prints a string on the console output. The string must be null
; terminated and no more than 256 characters in length.
;
; On entry:
;       AY = pointer to a null-terminated string
;
cputs:
		sty STDIO_W0+0
		sta STDIO_W0+1
		ldy #0
@next:
		lda (STDIO_W0),y
		beq @done
		jsr cputc
		iny
		bne @next
@done:
		ldy STDIO_W0+0
		lda STDIO_W0+1
		rts
