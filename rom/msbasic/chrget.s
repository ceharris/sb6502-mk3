.segment "CHRGET"

;-------------------------------------------------------------------------
; GENERIC_CHRGET:
; This subroutine seems to get the next character from the input buffer.
; It is relocated to RAM during init, so that the address in the `lda`
; instruction at GENERIC_CHRGOT can be rewritten.
;
; On return:
;       A = input character
;       TXTPTR points at the input character
;       carry clear if and only if A in '0'..'9'
;
RAMSTART1:
GENERIC_CHRGET:
        ; TXTPTR++
        inc     TXTPTR
        bne     GENERIC_CHRGOT
        inc     TXTPTR+1

GENERIC_CHRGOT:
GENERIC_TXTPTR = GENERIC_CHRGOT + 1
        ; the address here is probably the current value of TXTPTR
        lda     $EA60                   ; A = next input character 
        cmp     #$3A                    ; compare it to ASCII '9' + 1
        bcs     L4058                   ; go if not in range '0'..'9'
GENERIC_CHRGOT2:
        cmp     #$20                    ; compare to ASCII space
        beq     GENERIC_CHRGET          ; skip over spaces
        ; these next instructions clear the carry flag if and only if the input
        ; character is an ASCII digit '0'..'9'
        sec
        sbc     #$30
        sec
        sbc     #$D0
L4058:
        rts
