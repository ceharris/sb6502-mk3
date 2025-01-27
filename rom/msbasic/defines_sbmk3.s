.include "jmptab.h.s"

; configuration
CONFIG_2C := 1

CONFIG_SCRTCH_ORDER := 2

CONFIG_CLS := 1
CONFIG_CLS_ANSI := 1
;CONFIG_SOUND := 1

; zero page
ZP_START0 = 0
ZP_START1 = $10
ZP_START2 = $20
ZP_START3 = $70
ZP_START4 = $7B

USR := GOUSR 

SPACE_FOR_GOSUB := $3E
STACK_TOP := $FA
WIDTH := 80		; default value for screen width
WIDTH2 := 70		; default right margin (must be divisible by 14)

NUM_USR_VECS = 8
USRVEC := $0300
RAMSTART2 := USRVEC + 2*NUM_USR_VECS

; monitor functions
MONCOUT	:= J_CPUTC
MONRDKEY := GETC
EXIT_TO_MONITOR := J_IPL
