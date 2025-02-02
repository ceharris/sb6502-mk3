	.include "acia.h.s"
	.include "prog.h.s"

	.segment "MAGIC"
	.word PROG_MAGIC
	.byte 0,1,2,3,4,5,6,7,8,9,$A,$B,$C,$84,$85,$86
	.word RES_vec

	.segment "BASIC"
	.include "basic.s"

	.segment "CODE"
; Put the IRQ and NMI code in RAM so that it can be changed

IRQ_vec	= VEC_SV+2	; IRQ code vector
NMI_vec	= IRQ_vec+$0A	; NMI code vector

; Now the code. all this does is set up the vectors and interrupt code
; and wait for the user to select [C]old or [W]arm start. Nothing else.
; Fits in less than 128 bytes

; Reset vector points here

RES_vec
	CLD				; clear decimal mode
	LDX	#$FF			; empty stack
	TXS				; set the stack

	jsr acia_init

; Set up vectors and interrupt code, copy them to page 2.

	LDY	#END_CODE-LAB_vec	; set index/count
LAB_stlp
	LDA	LAB_vec-1,Y		; get byte from interrupt code
	STA	VEC_IN-1,Y		; save to RAM
	DEY				; decrement index/count
	BNE	LAB_stlp		; loop if more to do

; Now do the signon message, Y = $00 here

LAB_signon
	LDA	LAB_mess,Y		; get byte from sign on message
	BEQ	LAB_nokey		; exit loop if done

	JSR	V_OUTP		        ; output character
	INY				; increment index
	BNE	LAB_signon		; loop, branch always

LAB_nokey
	JSR	V_INPT                  ; call scan input device
	BCC	LAB_nokey		; loop if no key

	AND	#$DF			; mask xx0x xxxx, ensure upper case

	CMP	#'W'			; compare with [W]arm start
	BEQ	LAB_dowarm		; branch if [W]arm start

	CMP	#'C'			; compare with [C]old start
	BNE	RES_vec		        ; loop if not [C]old start

	JMP	LAB_COLD		; do EhBASIC cold start

LAB_dowarm
	JMP	LAB_WARM		; do EhBASIC warm start

; Byte out to serial console

SCRNout = acia_putc

; Byte in from serial console

KBDin = acia_getc

; LOAD and SAVE - currently does nothing.
SBCload				        ; load vector for EhBASIC
SBCsave				        ; save vector for EhBASIC
	RTS

CONF_REG := $FFD8
CONF_MMUE := $80
IPL_VECTOR := $F000
BYE_VECTOR := $F0

bye_fn:
                lda CONF_REG
                and #<~CONF_MMUE
                sta CONF_REG
                jmp IPL_VECTOR

BYE_FN_LENGTH := *-bye_fn

LAB_EXIT:
                sei
                jsr acia_shutdown
                ldx #BYE_FN_LENGTH
                ldy #0
@copy:
                lda bye_fn,y
                sta BYE_VECTOR,y
                iny
                dex
                bne @copy
                jmp BYE_VECTOR


; vector tables

LAB_vec
	.word	KBDin                   ; byte in from keyboard
	.word	SCRNout		        ; byte out to screen
	.word	SBCload		        ; load vector for EhBASIC
	.word	SBCsave		        ; save vector for EhBASIC

; EhBASIC IRQ support

IRQ_CODE
	PHA				; save A
	LDA	IrqBase		        ; get the IRQ flag byte
	LSR				; shift the set b7 to b6, and on down ...
	ORA	IrqBase		        ; OR the original back in
	STA	IrqBase		        ; save the new IRQ flag byte
	PLA				; restore A
	RTI

; EhBASIC NMI support

NMI_CODE
	PHA				; save A
	LDA	NmiBase		        ; get the NMI flag byte
	LSR				; shift the set b7 to b6, and on down ...
	ORA	NmiBase		        ; OR the original back in
	STA	NmiBase		        ; save the new NMI flag byte
	PLA				; restore A
	RTI

END_CODE

LAB_mess
	.byte	$0D,$0A,"6502 EhBASIC",$0D,$0A, "[C]old/[W]arm?",$00
					; sign on string
