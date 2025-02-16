;-----------------------------------------------------------------------
; reset.s
;
; This file contains a `soft_reset` reset function. It should be used
; as an include file in another source module.
;
; The syntax used here should work for either of the ca64 or 64tass
; assembler. It might also work for vasm.
;

_CONF_REG := $FFD8
_ACIA_CTRL := $FFD0
_ACIA_RESET := $3
_MMU_SLOT0 := $FFC0
_CONF_MMUE := $80
_IPL_VECTOR := $F000
_PIVOT_VECTOR := $F0

pivot_fn:
		; disable MMU
                lda _CONF_REG
                and #<~_CONF_MMUE
                sta _CONF_REG
		; jump back to the IPL program
                jmp _IPL_VECTOR

_PIVOT_FN_LENGTH := *-pivot_fn

soft_reset:
		; quiesce the system
                sei
                cld
                ; reset the ACIA used for the console
                lda #_ACIA_RESET
                sta _ACIA_CTRL
		; put bank 0 in slot zero since we will disable MMU
		stz _MMU_SLOT0
		; copy pivot_fn into the zero page
                ldx #_PIVOT_FN_LENGTH
                ldy #0
copy_pivot:
                lda pivot_fn,y
                sta _PIVOT_VECTOR,y
                iny
                dex
                bne copy_pivot
                jmp _PIVOT_VECTOR

