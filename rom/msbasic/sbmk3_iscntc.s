.include "jmptab.h.s"
.segment "CODE"
ISCNTC:
        jsr     J_CGETC
        bcc     RET1
        cmp     #$03
	bne	RET1

;!!! runs into "STOP"
