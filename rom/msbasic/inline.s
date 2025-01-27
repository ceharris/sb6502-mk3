.segment "CODE"

.ifndef CONFIG_NO_INPUTBUFFER_ZP
;-----------------------------------------------------------------------
; Delete the last character input.
;-----------------------------------------------------------------------
L2420:
        dex                             ; decrement buffer pointer
        bpl     INLIN2                  ; go if still at least one char
L2423:
        jsr     CRDO                    ; print a CR+LF
.endif

; ----------------------------------------------------------------------------
; READ A LINE, AND STRIP OFF SIGN BITS
; ----------------------------------------------------------------------------
INLIN:
        ldx     #$00                    ; initialize buffer index
INLIN2:
        jsr     GETLN                   ; get a character
    .ifndef CONFIG_NO_LINE_EDITING
        cmp     #$07
        beq     L2443                   ; go if ASCII BEL
    .endif
        cmp     #$0D
        beq     L2453                   ; go if ASCII CR (return)
    .ifndef CONFIG_NO_LINE_EDITING
       .ifdef SBMKN
        cmp     #$8
        beq     L2420                   ; go if ASCII BS (backspace)
       .endif
        cmp     #$20
        bcc     INLIN2                  ; go if other control character
        cmp     #$7D
        bcs     INLIN2                  ; go if greater than `}` (did we mean to exclude '~'?)
        cmp     #$40                    
        beq     L2423                   ; go if '@'
      .if .def(SBMKN)
        cmp     #$7F ; DEL
      .else
        cmp     #$5F ; _
      .endif
        beq     L2420                   ; go if ASCII DEL (or '_')
L2443:
        cpx     #$47                    
        bcs     L244C                   ; go if X >= 71
    .endif
        sta     INPUTBUFFER,x
        inx
        bne     INLIN2
L244C:
    .ifndef CONFIG_NO_LINE_EDITING
        lda     #$07
        jsr     OUTDO                   ; ring the bell
        bne     INLIN2
    .endif
L2453:
        ; go null terminate the string and return the input pointer
        ; (the target of this jump should probably be in this file)
        jmp     L29B9

GETLN:
    .ifdef CONFIG_FILE
        jsr     CHRIN
        ldy     CURDVC
        bne     L2465
    .else
        jsr     MONRDKEY
    .endif
        cmp     #$0F                    ; is it ASCII SI (Ctrl-O)
        bne     L2465                   ; go if not SI (Ctrl-O)
        pha                             ; preserve character
        lda     Z14                     ; Z14 bit 7 is Ctrl-O state
        eor     #$FF                    ; complement bit 7 (and all others)
        sta     Z14                     ; store new Ctrl-O state
        pla                             ; recover character
L2465:
        rts
