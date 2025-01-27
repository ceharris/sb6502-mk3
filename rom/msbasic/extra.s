.segment "EXTRA"


; ----------------------------------------------------------------------------
; ERROR: UNDEFINED FUNCTION
; This subroutine is used as the default for the GOUSR vector.
; ----------------------------------------------------------------------------
UFERR:
        ldx     #ERR_UNDEFFN
        jmp     ERROR

; ----------------------------------------------------------------------------
; CONVERTS A NUMBER IN FAC TO A SIGNED INTEGER IN A,Y
; Unlike the DEINT subroutine in the 8080 version of BASIC, the AYINT
; subroutine doesn't actually place the resulting integer in A,Y. This
; makes it difficult to use AYINT from a machine language program executed
; via USR(), without hardcoding the location of FAC. Instead, this 
; function is used as GOAYINT vector.
; ----------------------------------------------------------------------------
USR_AYINT:
        jsr     AYINT			; convert number to signed int
        lda     FAC_LAST-1		; A = MSB of result
        ldy     FAC_LAST		; Y = LSB of result
        rts

; ----------------------------------------------------------------------------
; CONVERTS A LOWER CASE LETTER IN (A) TO UPPER CASE.
; Preserves status register and leaves (A) unmodified if it doesn't contain
; a lower case letter on entry.
; ----------------------------------------------------------------------------
TO_UPPER:
	php				; preserve status
        cmp     #'a'
        bcc     @done			; go if less than 'a'
        cmp     #'z'+1		
        bcs     @done			; if if greater than 'z'
        and     #$DF			; turn off bit 5		
@done:
	plp				; recover status
        rts

; ----------------------------------------------------------------------
; CONVERTS A HEXADECIMAL LITERAL (e.g. &H55AA) TO A NUMBER IN FAC.
; ----------------------------------------------------------------------
CONVERT_HEX:
	jsr	CHRGET
	; The correct syntax is &H followed by one or more hexadecimal digits
	cmp	#'H'
	bne	@error
	; we'll use FAC, FAC+1 to build up the result
	ldx	#0
	stx	FAC
	stx	FAC+1
	; We'll use FAC+2 to temporarily hold each nibble.
	; Initialize it to $FF to indicate that we haven't seen
	; any hexadecimal digits yet.
	dex
	stx	FAC+2
@next:
	jsr	CHRGET
	bcc	@digit			; go if digit 0..9
	cmp     #'A'
	bcc     @done			; go if not alphanumeric
	cmp	#'Z'+1
	bcs	@done			; go if not alphanumeric
	cmp	#'F'+1
	bcs	@error			; go if not letter A..F
	sec
	sbc	#7			; convert 'A'..'F' to $3A..$3F
@digit:
	sec
	sbc	#$30			; convert $30..$3F to $0..$F
	sta	FAC+2			; save nibble
	; shift our result left by 4 bits to make room for new nibble
	ldx	#4			; shift count
@shift:
	lda	FAC			; fetch LSB
	asl				; shift in 0 and high bit out
	sta	FAC			; store resulting LSB
	lda	FAC+1			; fetch MSB
	rol				; rotate in bit from LSB
	sta	FAC+1			; store MSB
	dex				; shift count--
	bne	@shift			; go until four bits shifted
	; fold new nibble into the result
	lda	FAC			; fetch LSB
	ora	FAC+2			; merge in lower nibble
	sta	FAC			; store LSB
	jmp	@next			; convert next digit
@done:	
	; it's an error if we haven't seen any hexadecimal digits
	lda	FAC+2			; get last nibble result
	cmp	#$ff			; all ones only if no conversions
	beq	@error			; go if no conversions
	; fetch our 16-bit result and put into FAC as a float
	ldy	FAC			; Y = result LSB
	lda	FAC+1			; A = result MSB
	jsr	GIVAYF			; put result in FAC
	rts
@error:
        jmp	SYNERR			; throw syntqx error

; ----------------------------------------------------------------------
; "HEX$" FUNCTION
; This function uses the same "STACK2" buffer space that is used by 
; the STR$ function as temporary storage for the converted hexadecimal
; digits, and subsequently passes the buffer address to STRLIT to 
; create a string for the function result.
; ----------------------------------------------------------------------
HEXSTR:
	; Convert argument, putting MSB in FAC_LAST-1 and LSB in FAC_LAST
	jsr	AYINT
	ldy	#0
	; Convert MSB of argument
	lda	FAC_LAST-1		
	jsr	@convert
	; convert LSB of argument
	lda	FAC_LAST
	jsr	@convert
	tya	
	bne	@done			; go if at least 1 digit converted
	lda	#'0'						
	sta	STACK2-1,y		; stuff a '0' into the (empty) buffer
	iny
@done:
	lda	#0	
	sta	STACK2-1,y		; null terminate the buffer
	pla				; remove something that was placed
	pla				;    on the stack by our caller
	lda	#<STACK2-1		; A=LSB of buffer
	ldy	#>STACK2-1		; Y=MSB of buffer
	jmp	STRLIT			; convert it to a string result
@convert:
	pha				; preserve value to convert
	lsr				; shift upper nibble
	lsr				;    into lower nibble
	lsr
	lsr
	jsr	@nibble			; convert nibble
	pla				; recover value to convert
	and	#$0f			; mask off upper nibble
	jsr	@nibble			; convert nibble
	rts
@nibble:
	cmp	#9+1
	bcc	@digit			; go if 0..9
	clc
	adc	#7			; bias so that we get 'A'..'F'
@digit:
	tax				; set Z flag if A is zero
	bne	@not_zero		; if not zero, always convert
	tya
	beq	@skip			; do zero only if at least 1 non-zero
	lda	#0
@not_zero:
	adc	#'0'			; convert binary to ASCII hexadecimal
	sta	STACK2-1,y		; store hexadecimal digit into buffer
	iny
@skip:
	rts

; ----------------------------------------------------------------------
; "CLS" STATEMENT
;-----------------------------------------------------------------------
.ifdef CONFIG_CLS
.ifdef CONFIG_CLS_ANSI
cls_sequence:
	.byte $1b, "[H", $1b, "[2J", 0
.endif

CLS:
.ifdef CONFIG_CLS_ANSI
	ldy #0				; Y will index the sequence
	beq @first			; jump unconditionally
@next:
	jsr MONCOUT			; write sequence char
	iny				; sequence index++
@first:
	lda cls_sequence,y		; fetch a char from the sequence
	bne @next			; go if not null terminator
.else
	lda #$0c			; ASCII form feed
	jsr MONCOUT			; write form feed to clear screen
.endif
	rts
.endif


.ifdef SBMKN
.include "sbmk3_extra.s"
.endif
