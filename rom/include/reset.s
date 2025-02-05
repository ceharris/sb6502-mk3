;-----------------------------------------------------------------------
; reset.s
;
; This file contains a `soft_reset` reset function. It should be used
; as an include file in another source module.
;
; The syntax used here should work for either of the ca64 or 64tass
; assembler. It might also work for vasm.
;

CONF_REG := $FFD8
ACIA_CTRL := $FFD0
ACIA_RESET := $3
MMU_SLOT0 := $FFC0
CONF_MMUE := $80
IPL_VECTOR := $F000
PIVOT_VECTOR := $F0

pivot_fn:
		; disable MMU
                lda CONF_REG
                and #<~CONF_MMUE
                sta CONF_REG
		; jump back to the IPL program
                jmp IPL_VECTOR

PIVOT_FN_LENGTH := *-pivot_fn

soft_reset:
		; quiesce the system
                sei
                ; reset the ACIA used for the console
                lda #ACIA_RESET
                sta ACIA_CTRL
		; put bank 0 in slot zero since we will disable MMU
		stz MMU_SLOT0
		; copy pivot_fn into the zero page
                ldx #PIVOT_FN_LENGTH
                ldy #0
@copy:
                lda pivot_fn,y
                sta PIVOT_VECTOR,y
                iny
                dex
                bne @copy
                jmp PIVOT_VECTOR

