; error
; line input, line editing
; tokenize
; detokenize
; BASIC program memory management

; MICROTAN has some nonstandard extension to LIST here

.segment "CODE"

MEMERR:
        ldx     #ERR_MEMFULL

; ----------------------------------------------------------------------------
; HANDLE AN ERROR
;
; (X)=OFFSET IN ERROR MESSAGE TABLE
; (ERRFLG) > 128 IF "ON ERR" TURNED ON
; (CURLIN+1) = $FF IF IN DIRECT MODE
; ----------------------------------------------------------------------------
ERROR:
        ; reset Ctrl-O state by putting a zero in bit 7 of Z14
        lsr     Z14
.ifdef CONFIG_FILE
        lda     CURDVC    ; output
        beq     LC366     ; is screen
        jsr     CLRCH     ; otherwise redirect output back to screen
        lda     #$00
        sta     CURDVC
LC366:
.endif
        jsr     CRDO
        jsr     OUTQUES
L2329:
        lda     ERROR_MESSAGES,x
.ifndef CONFIG_SMALL_ERROR
        pha
        and     #$7F
.endif
        jsr     OUTDO
.ifdef CONFIG_SMALL_ERROR
        lda     ERROR_MESSAGES+1,x
        jsr     OUTDO
.else
        inx
        pla
        bpl     L2329
.endif
        jsr     STKINI
        lda     #<QT_ERROR
        ldy     #>QT_ERROR

; ----------------------------------------------------------------------------
; PRINT STRING AT (Y,A)
; PRINT CURRENT LINE # UNLESS IN DIRECT MODE
; FALL INTO WARM RESTART
; ----------------------------------------------------------------------------
PRINT_ERROR_LINNUM:
        jsr     STROUT
        ldy     CURLIN+1
        iny
        beq     RESTART
        jsr     INPRT

; ----------------------------------------------------------------------------
; WARM RESTART ENTRY
; ----------------------------------------------------------------------------
.global RESTART
RESTART:
        ; Reset Ctrl-O state by putting zero in bit 7 of Z14
        lsr     Z14
        ; print the OK prompt
        lda     #<QT_OK
        ldy     #>QT_OK
        jsr     GOSTROUT
L2351:
        ; get a line of input
        jsr     INLIN
        stx     TXTPTR
        sty     TXTPTR+1
        jsr     CHRGET                  ; get first character
.ifdef CONFIG_11
; bug in pre-1.1: CHRGET sets Z on '\0'
; and ':' - a line starting with ':' in
; direct mode gets ignored
        tax                             ; set Z flag from A
.endif
        beq     L2351                   ; go if no input
        ldx     #$FF            
        stx     CURLIN+1
        bcc     NUMBERED_LINE           ; go if first character is a digit
        jsr     PARSE_INPUT_LINE        ; parse immediate statement
        jmp     NEWSTT2                 ; go execute it

; ----------------------------------------------------------------------------
; HANDLE NUMBERED LINE
; ----------------------------------------------------------------------------
NUMBERED_LINE:
        jsr     LINGET                  ; set LINNUM from input line
        jsr     PARSE_INPUT_LINE        ; parse numbered statement
        sty     EOLPNTR
        jsr     FNDLIN
        bcc     PUT_NEW_LINE
        ldy     #$01
        lda     (LOWTR),y
        sta     INDEX+1
        lda     VARTAB
        sta     INDEX
        lda     LOWTR+1
        sta     DEST+1
        lda     LOWTR
        dey
        sbc     (LOWTR),y
        clc
        adc     VARTAB
        sta     VARTAB
        sta     DEST
        lda     VARTAB+1
        adc     #$FF
        sta     VARTAB+1
        sbc     LOWTR+1
        tax
        sec
        lda     LOWTR
        sbc     VARTAB
        tay
        bcs     L23A5
        inx
        dec     DEST+1
L23A5:
        clc
        adc     INDEX
        bcc     L23AD
        dec     INDEX+1
        clc
L23AD:
        lda     (INDEX),y
        sta     (DEST),y
        iny
        bne     L23AD
        inc     INDEX+1
        inc     DEST+1
        dex
        bne     L23AD

; ----------------------------------------------------------------------------
PUT_NEW_LINE:
  .ifdef CONFIG_2
        jsr     SETPTRS
        jsr     LE33D
        lda     INPUTBUFFER
        beq     L2351
        clc
  .else
        lda     INPUTBUFFER
        beq     FIX_LINKS
        lda     MEMSIZ
        ldy     MEMSIZ+1
        sta     FRETOP
        sty     FRETOP+1
  .endif
        lda     VARTAB
        sta     HIGHTR
        adc     EOLPNTR
        sta     HIGHDS
        ldy     VARTAB+1
        sty     HIGHTR+1
        bcc     L23D6
        iny
L23D6:
        sty     HIGHDS+1
        jsr     BLTU
.ifdef CONFIG_INPUTBUFFER_0200
        lda     LINNUM
        ldy     LINNUM+1
        sta     INPUTBUFFER-2
        sty     INPUTBUFFER-1
.endif
        lda     STREND
        ldy     STREND+1
        sta     VARTAB
        sty     VARTAB+1
        ldy     EOLPNTR
        dey
; ---COPY LINE INTO PROGRAM-------
L23E6:
        lda     INPUTBUFFER-4,y
        sta     (LOWTR),y
        dey
        bpl     L23E6

; ----------------------------------------------------------------------------
; CLEAR ALL VARIABLES
; RE-ESTABLISH ALL FORWARD LINKS
; ----------------------------------------------------------------------------
FIX_LINKS:
        jsr     SETPTRS
.ifdef CONFIG_2
        jsr     LE33D
        jmp     L2351
LE33D:
.endif
        lda     TXTTAB
        ldy     TXTTAB+1
        sta     INDEX
        sty     INDEX+1
        clc
L23FA:
        ldy     #$01
        lda     (INDEX),y
.ifdef CONFIG_2
        beq     RET3
.else
        jeq     L2351
.endif
        ldy     #$04
L2405:
        iny
        lda     (INDEX),y
        bne     L2405
        iny
        tya
        adc     INDEX
        tax
        ldy     #$00
        sta     (INDEX),y
        lda     INDEX+1
        adc     #$00
        iny
        sta     (INDEX),y
        stx     INDEX
        sta     INDEX+1
        bcc     L23FA	; always

; ----------------------------------------------------------------------------
.ifdef CONFIG_2
RET3:
		rts
.endif

.include "inline.s"

; ----------------------------------------------------------------------------
; TOKENIZE THE INPUT LINE
; ----------------------------------------------------------------------------
PARSE_INPUT_LINE:
        ldx     TXTPTR
        ldy     #$04
        sty     DATAFLG
L246C:
        lda     INPUTBUFFERX,x
        cmp     #$20
        beq     L24AC                   ; simply store spaces
        sta     ENDCHR                  ; save statement char
        cmp     #$22                    ; ASCII quote (")
        beq     L24D0                   ; go if it's a quote
        bit     DATAFLG
        bvs     L24AC                   ; if bit 6 of DATAFLG, store character
        cmp     #$3F                    ; ASCII question mark (?)
        bne     L2484                   ; go if not question mark
        lda     #TOKEN_PRINT            ; treat ? like PRINT
        bne     L24AC                   ; (always jumps)
L2484:
        cmp     #$30                    ; ASCII zero (0)
        bcc     L248C                   ; go if less than '0'
        cmp     #$3C                    ; ASCII less than (<)
        bcc     L24AC                   ; go store if less than '<'
; ----------------------------------------------------------------------------
; SEARCH TOKEN NAME TABLE FOR MATCH STARTING
; WITH CURRENT CHAR FROM INPUT LINE
; ----------------------------------------------------------------------------
L248C:
        sty     STRNG2                  ; STRNG2 = 4
        ldy     #$00
        sty     EOLPNTR                 ; EOLPNTR = 0
        dey
        stx     TXTPTR
        dex
L2496:
        iny
L2497:
        inx
L2498:
        lda     INPUTBUFFERX,x
        jsr     TO_UPPER                ; convert lower case to upper case
  .ifndef CONFIG_2
        cmp     #$20
        beq     L2497
  .endif

        sec
        sbc     TOKEN_NAME_TABLE,y
        beq     L2496
        cmp     #$80
        bne     L24D7
        ora     EOLPNTR
; ----------------------------------------------------------------------------
; STORE CHARACTER OR TOKEN IN OUTPUT LINE
; ----------------------------------------------------------------------------
L24AA:
        ldy     STRNG2
L24AC:
        inx
        iny
        sta     INPUTBUFFER-5,y
        lda     INPUTBUFFER-5,y
        beq     L24EA
        sec
        sbc     #$3A
        beq     L24BF
        cmp     #$49
        bne     L24C1
L24BF:
        sta     DATAFLG
L24C1:
        sec
        sbc     #TOKEN_REM-':'
        bne     L246C
        sta     ENDCHR
; ----------------------------------------------------------------------------
; HANDLE LITERAL (BETWEEN QUOTES) OR REMARK,
; BY COPYING CHARS UP TO ENDCHR.
; ----------------------------------------------------------------------------
L24C8:
        lda     INPUTBUFFERX,x
        beq     L24AC
        cmp     ENDCHR
        beq     L24AC
L24D0:
        iny
        sta     INPUTBUFFER-5,y
        inx
        bne     L24C8
; ----------------------------------------------------------------------------
; ADVANCE POINTER TO NEXT TOKEN NAME
; ----------------------------------------------------------------------------
L24D7:
        ldx     TXTPTR
        inc     EOLPNTR
L24DB:
        iny
        lda     MATHTBL+28+1,y                  ; XXX -- this constant has to point at the end of MATHTBL
        bpl     L24DB
        lda     TOKEN_NAME_TABLE,y
        bne     L2498
        lda     INPUTBUFFERX,x
        jsr     TO_UPPER                        ; convert lower case to upper case
        bpl     L24AA
; ---END OF LINE------------------
L24EA:
        sta     INPUTBUFFER-3,y
.ifdef CONFIG_NO_INPUTBUFFER_ZP
        dec     TXTPTR+1
.endif
        lda     #<INPUTBUFFER-1
        sta     TXTPTR
        rts

; ----------------------------------------------------------------------------
; SEARCH FOR LINE
;
; (LINNUM) = LINE # TO FIND
; IF NOT FOUND:  CARRY = 0
;	LOWTR POINTS AT NEXT LINE
; IF FOUND:      CARRY = 1
;	LOWTR POINTS AT LINE
; ----------------------------------------------------------------------------
FNDLIN:
        lda     TXTTAB
        ldx     TXTTAB+1
FL1:
        ldy     #$01
        sta     LOWTR
        stx     LOWTR+1
        lda     (LOWTR),y
        beq     L251F
        iny
        iny
        lda     LINNUM+1
        cmp     (LOWTR),y
        bcc     L2520
        beq     L250D
        dey
        bne     L2516
L250D:
        lda     LINNUM
        dey
        cmp     (LOWTR),y
        bcc     L2520
        beq     L2520
L2516:
        dey
        lda     (LOWTR),y
        tax
        dey
        lda     (LOWTR),y
        bcs     FL1
L251F:
        clc
L2520:
        rts

; ----------------------------------------------------------------------------
; "NEW" STATEMENT
; ----------------------------------------------------------------------------
NEW:
        ; why would the Z flag matter here?
        bne     L2520
        
        ; This entry point is used during init to reset everything as
        ; though NEW was called. The point at which it is called varies
        ; depending on CONFIG_SCRTCH_ORDER
SCRTCH:
        lda     #$00
        tay
        sta     (TXTTAB),y
        iny
        sta     (TXTTAB),y
        lda     TXTTAB
.ifdef CONFIG_2
		clc
.endif
        adc     #$02
        sta     VARTAB
        lda     TXTTAB+1
        adc     #$00
        sta     VARTAB+1
; ----------------------------------------------------------------------------
SETPTRS:
        jsr     STXTPT
.ifdef CONFIG_11A
        lda     #$00

; ----------------------------------------------------------------------------
; "CLEAR" STATEMENT
; ----------------------------------------------------------------------------
CLEAR:
        bne     L256A
.endif
CLEARC:
        lda     MEMSIZ
        ldy     MEMSIZ+1
        sta     FRETOP
        sty     FRETOP+1
        lda     VARTAB
        ldy     VARTAB+1
        sta     ARYTAB
        sty     ARYTAB+1
        sta     STREND
        sty     STREND+1
        jsr     RESTORE
; ----------------------------------------------------------------------------
STKINI:
        ldx     #TEMPST
        stx     TEMPPT
        pla
.ifdef CONFIG_2
		tay
.else
        sta     STACK+STACK_TOP+1
.endif
        pla
.ifndef CONFIG_2
        sta     STACK+STACK_TOP+2
.endif
        ldx     #STACK_TOP
        txs
.ifdef CONFIG_2
        pha
        tya
        pha
.endif
        lda     #$00
        sta     OLDTEXT+1
        sta     SUBFLG
L256A:
        rts

; ----------------------------------------------------------------------------
; SET TXTPTR TO BEGINNING OF PROGRAM
; ----------------------------------------------------------------------------
STXTPT:
        clc
        lda     TXTTAB
        adc     #$FF
        sta     TXTPTR
        lda     TXTTAB+1
        adc     #$FF
        sta     TXTPTR+1
        rts

; ----------------------------------------------------------------------------
; "LIST" STATEMENT
; ----------------------------------------------------------------------------
LIST:
        bcc     L2581
        beq     L2581
        cmp     #TOKEN_MINUS
        bne     L256A
L2581:
        jsr     LINGET
        jsr     FNDLIN
        jsr     CHRGOT
        beq     L2598
        cmp     #TOKEN_MINUS
        bne     L2520
        jsr     CHRGET
        jsr     LINGET
        bne     L2520
L2598:
        pla
        pla
        lda     LINNUM
        ora     LINNUM+1
        bne     L25A6
        lda     #$FF
        sta     LINNUM
        sta     LINNUM+1
L25A6:
L25A6X:
        ldy     #$01
.ifdef CONFIG_DATAFLG
        sty     DATAFLG
.endif
        lda     (LOWTRX),y
        beq     L25E5
        jsr     ISCNTC
        jsr     CRDO
        iny
        lda     (LOWTRX),y
        tax
        iny
        lda     (LOWTRX),y
        cmp     LINNUM+1
        bne     L25C1
        cpx     LINNUM
        beq     L25C3
L25C1:
        bcs     L25E5
; ---LIST ONE LINE----------------
L25C3:
        sty     FORPNT
        jsr     LINPRT
        lda     #$20
L25CA:
        ldy     FORPNT
        and     #$7F
L25CE:
        jsr     OUTDO
.ifdef CONFIG_DATAFLG
        cmp     #$22
        bne     LA519
        lda     DATAFLG
        eor     #$FF
        sta     DATAFLG
LA519:
.endif
        iny
.ifdef CONFIG_11
        beq     L25E5
.endif
        lda     (LOWTRX),y
        bne     L25E8
        tay
        lda     (LOWTRX),y
        tax
        iny
        lda     (LOWTRX),y
        stx     LOWTRX
        sta     LOWTRX+1
        bne     L25A6
L25E5:
        jmp     RESTART
L25E8:
        bpl     L25CE
.ifdef CONFIG_DATAFLG
        cmp     #$FF
        beq     L25CE
        bit     DATAFLG
        bmi     L25CE
.endif
        sec
        sbc     #$7F
        tax
        sty     FORPNT
        ldy     #$FF
L25F2:
        dex
        beq     L25FD
L25F5:
        iny
        lda     TOKEN_NAME_TABLE,y
        bpl     L25F5
        bmi     L25F2
L25FD:
        iny
        lda     TOKEN_NAME_TABLE,y
        bmi     L25CA
        jsr     OUTDO
        bne     L25FD	; always

