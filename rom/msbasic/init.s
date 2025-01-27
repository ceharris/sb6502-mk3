.segment "INIT"
.global COLD_START

; ----------------------------------------------------------------------------
PR_WRITTEN_BY:
        lda     #<QT_WRITTEN_BY
        ldy     #>QT_WRITTEN_BY
        jsr     STROUT

COLD_START:
        ldx     #$FF
        stx     CURLIN+1
  .ifdef CONFIG_NO_INPUTBUFFER_ZP
        ldx     #$FB
  .endif
        txs                                     ; initialize machine stack

        ; copy COLD_START address into GORESTART vector
        lda     #<COLD_START
        ldy     #>COLD_START
        sta     GORESTART+1
        sty     GORESTART+2
        ; copy COLD_START address into GOSTROUT vector?
        sta     GOSTROUT+1
        sty     GOSTROUT+2
        ; copy AYINT address into GOAYINT vector
        lda     #<USR_AYINT
        ldy     #>USR_AYINT
        sta     GOAYINT+1
        sty     GOAYINT+2
        ; copy GIVAYF address into GOGIVEAYF vector
        lda     #<GIVAYF
        ldy     #>GIVAYF
        sta     GOGIVEAYF+1
        sty     GOGIVEAYF+2
        ; punch a JMP opcode into the GORESTART and GOSTROUT
        lda     #$4C                            ; opcode for JMP
        sta     GORESTART
        sta     GOSTROUT
        sta     GOAYINT
        sta     GOGIVEAYF
        ; punch a JMP opcode into the descriptor struct at DSRLEN+1?
        sta     JMPADRS
  .ifndef CONFIG_RAM
        ; punch a JMP opcode into the USR function vector
        sta     USR
        lda     #<UFERR
        ldy     #>UFERR
        sta     USR+1
        sty     USR+2
  .endif
        lda     #WIDTH                          ; terminal width
        sta     Z17
        lda     #WIDTH2                         ; right margin
        sta     Z18

;-----------------------------------------------------------------
; This copies GENERIC_CHRGET and GENERIC_RNDSEED from ROM to RAM
;
; All non-CONFIG_SMALL versions of BASIC have
; the same bug here: While the number of bytes
; to be copied is correct for CONFIG_SMALL,
; it is one byte short on non-CONFIG_SMALL:
; It seems the "ldx" value below has been
; hardcoded. So on these configurations,
; the last byte of GENERIC_RNDSEED, which
; is 5 bytes instead of 4, does not get copied -
; which is nothing major, because it is just
; the least significant 8 bits of the mantissa
; of the random number seed.

.ifdef CONFIG_SMALL
        ldx     #GENERIC_CHRGET_END-GENERIC_CHRGET
.else
        ldx     #GENERIC_CHRGET_END-GENERIC_CHRGET-1 ; XXX
.endif
L4098:
        lda     GENERIC_CHRGET-1,x
        sta     CHRGET-1,x
        dex
        bne     L4098
        ; this is probably redundant (happens again further below)
.ifdef CONFIG_2
        lda     #$03
        sta     DSCLEN
.endif

        txa                             ; A=0
        sta     SHIFTSIGNEXT
        sta     LASTPT+1
  .if .defined(CONFIG_NULL) || .defined(CONFIG_PRINTNULLS)
        sta     Z15
  .endif
  .ifndef CONFIG_11
        sta     POSX
  .endif
        pha                             ; push 0
        sta     Z14                     ; reset Ctrl-O state (bit 7 = 0)
        ; same sequence also happens above
        lda     #$03
        sta     DSCLEN
    
    .ifndef CONFIG_11
        lda     #$2C
        sta     LINNUM+1
    .endif
    
        jsr     CRDO
        ldx     #TEMPST
        stx     TEMPPT

        ; print memory size prompt
        lda     #<QT_MEMORY_SIZE
        ldy     #>QT_MEMORY_SIZE
        jsr     STROUT
        
        ; get memory size input (returns with Y,X pointing to the input)
        jsr     NXIN

        ; save the input pointer
        stx     TXTPTR
        sty     TXTPTR+1

        jsr     CHRGET                  ; get a character from the input
        cmp     #$41                    ; does the input start with 'A'
        beq     PR_WRITTEN_BY           ; show "written by" and restart

        tay                             ; Y = input character  
        bne     L40EE                   ; go if not end of input
        ; Y, A = RAMSTART2
        lda     #<RAMSTART2
        ldy     #>RAMSTART2
.ifdef CONFIG_2
        ; TXTTAB = RAMSTART2
        sta     TXTTAB
        sty     TXTTAB+1
.endif
        ; LINNUM = RAMSTART2
        sta     LINNUM
        sty     LINNUM+1

        ldy     #$00                    ; Y = indirect offset of zero
L40D7:
        ; LINNUM++
        inc     LINNUM
        bne     L40DD
        inc     LINNUM+1

L40DD:
.ifdef CONFIG_2
        lda     #$55                    ; A = pattern (01010101 / 10101010)
.else
        lda     #$92 ; 10010010 / 00100100
.endif
        sta     (LINNUM),y              ; write pattern
        cmp     (LINNUM),y              ; read pattern
        bne     L40FA                   ; go if doesn't match
        asl     a                       ; push a zero bit in on left (A = $AA)
        sta     (LINNUM),y              ; write pattern
        cmp     (LINNUM),y              ; read pattern
  .ifndef CONFIG_11
        beq     L40D7; old: faster
        bne     L40FA
  .else
        bne     L40FA; new: slower      ; go if doesn't match
        beq     L40D7                   ; next address
  .endif

        ; parse the memory size input as a number
L40EE:
        jsr     CHRGOT                  ; re-read the first character
        jsr     LINGET                  ; Y,X points to the input buffer - 1,
                                        ;   A = 0 if a null terminator was inserted
        tay
        beq     L40FA                   ; go if no error
        jmp     SYNERR

L40FA:
        ; fetch the number
        lda     LINNUM
        ldy     LINNUM+1
        ; set it as the (writable) memory size
        sta     MEMSIZ
        sty     MEMSIZ+1
        ; set it as the top of free memory
        sta     FRETOP
        sty     FRETOP+1

L4106:
        ; prompt for terminal width
        lda     #<QT_TERMINAL_WIDTH
        ldy     #>QT_TERMINAL_WIDTH
        jsr     STROUT

        ; get the terminal width input
        jsr     NXIN
        stx     TXTPTR
        sty     TXTPTR+1
        jsr     CHRGET
        tay
        beq     L4136                   ; skip if nothing entered

        ; parse the terminal width input
        jsr     LINGET
        lda     LINNUM+1
        bne     L4106                   ; go if error
        lda     LINNUM                  ; fetch the width
        cmp     #$10                    ; if width is less than 16
        bcc     L4106                   ;     go try again
; this label seems to be a stray
L2829:
        sta     Z17

        ; Compute a right margin that is divisible by TAB width
L4129:
        sbc     #$0E                    ; tab width is 14
        bcs     L4129                   ; loop until after we wrap (divide by 14)
        eor     #$FF                    ; complement remainder
        sbc     #$0C                    ; A = two's complement of remainder
        clc                             
        adc     Z17                     ; A = term width - term width MOD tab width
        sta     Z18                     ; store as right margin

L4136:
.ifdef CONFIG_RAM
        lda     #<QT_WANT
        ldy     #>QT_WANT
        jsr     STROUT
        jsr     NXIN
        stx     TXTPTR
        sty     TXTPTR+1
        jsr     CHRGET
        ldx     #<RAMSTART1
        ldy     #>RAMSTART1
        cmp     #'Y'
        beq     L4183
        cmp     #'A'
        beq     L4157
        cmp     #'N'
        bne     L4136
L4157:
        ldx     #<IQERR
        ldy     #>IQERR
        stx     UNFNC_ATN
        sty     UNFNC_ATN+1
        ldx     #<ATN	; overwrite starting
        ldy     #>ATN	; with ATN
        cmp     #'A'
        beq     L4183
        ldx     #<IQERR
        ldy     #>IQERR
        stx     UNFNC_COS
        sty     UNFNC_COS+1
        stx     UNFNC_TAN
        sty     UNFNC_TAN+1
        stx     UNFNC_SIN
        sty     UNFNC_SIN+1
        ldx     #<SIN_COS_TAN_ATN	; overwrite
        ldy     #>SIN_COS_TAN_ATN	; all of trig.s
L4183:
.else
        ldx     #<RAMSTART2
        ldy     #>RAMSTART2
.endif
        ; initialize TXTTAB pointer (program text pointer?)
        stx     TXTTAB
        sty     TXTTAB+1
        ldy     #$00
        tya
        sta     (TXTTAB),y              ; mark end of linked list?
        inc     TXTTAB
        bne     L4192
        inc     TXTTAB+1
L4192:
.if CONFIG_SCRTCH_ORDER = 1
        jsr     SCRTCH                  ; basically same as NEW
.endif
        ; check for sufficient memory
        lda     TXTTAB
        ldy     TXTTAB+1
        jsr     REASON
.if .defined(CBM2) | .defined(SBMKN)
        ; display startup message
        lda     #<QT_BASIC
        ldy     #>QT_BASIC
        jsr     STROUT
.else
        jsr     CRDO
.endif
        ; determine amount of free memory
        lda     MEMSIZ                  ; LSB of memory size
        sec
        sbc     TXTTAB                  ; subtract LSB of program address
        tax                             ; save result
        lda     MEMSIZ+1                ; MSB of memory size
        sbc     TXTTAB+1                ; subtract MSB of program address
        jsr     LINPRT                  ; print A,X as a decimal number
        lda     #<QT_BYTES_FREE
        ldy     #>QT_BYTES_FREE
        jsr     STROUT                  ; print "bytes free text"
.if CONFIG_SCRTCH_ORDER = 2
        jsr     SCRTCH                  ; basically same as NEW
.endif
        ; set up STROUT vector
        lda     #<STROUT
        ldy     #>STROUT
        sta     GOSTROUT+1
        sty     GOSTROUT+2
  .if CONFIG_SCRTCH_ORDER = 3
         jsr     SCRTCH                 ; basically same as NEW
  .endif
.ifdef SBMKN
        ; set up USR vectors
        jsr     USR_INIT
.endif
        ; set up RESTART vector
        lda     #<RESTART
        ldy     #>RESTART
        sta     GORESTART+1
        sty     GORESTART+2
        ; go to restart entry point
        jmp     (GORESTART+1)

  .ifdef CONFIG_RAM
QT_WANT:
        .byte   "WANT SIN-COS-TAN-ATN"
        .byte   0
  .endif
QT_WRITTEN_BY:
      .byte   CR,LF,$0C ; FORM FEED
      .ifndef CONFIG_11
        .byte   "WRITTEN BY RICHARD W. WEILAND."
      .else
        .byte   "WRITTEN BY WEILAND & GATES"
      .endif
      .byte   CR,LF,0
QT_MEMORY_SIZE:
        .byte   "Memory size", 0
QT_TERMINAL_WIDTH:
        .byte   "Terminal width", 0
QT_BYTES_FREE:
        .byte   " bytes free", CR, LF, 0
QT_BASIC:
  .ifdef SBMKN
      .byte CR,LF
	.byte "SB6502 MK3 BASIC V1.2"
  .endif 
      .byte   CR, LF, "Copyright (c) 1977 by Microsoft", CR, LF, 0
