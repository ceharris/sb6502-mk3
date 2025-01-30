.include "stdio.h.s"
.segment "CODE"
ISCNTC:
        jsr     cgetc
        bcc     RET1
        cmp     #$03
	bne	RET1

;!!! runs into "STOP"
