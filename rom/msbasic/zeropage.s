
.feature org_per_seg
.zeropage

.org ZP_START1

GORESTART:				; init sets this to JMP COLD_START
	.res 3
GOSTROUT:				; init sets this to JMP COLD_START
	.res 3
GOAYINT:				; init sets this to address of AYINT
	.res 3
GOGIVEAYF:				; init sets this to address of GIVAYF
	.res 3
GOUSR:
	.res 3				; init sets this to "Undefined function" error

.org ZP_START2
Z15:					; number of NULs to print after CR+LF
	.res 1				; init sets this to zero
.ifndef POSX; allow override
POSX:					; terminal column position
.endif
	.res 1
.ifndef Z17; allow override
Z17:					; init sets this to the terminal width
.endif
	.res 1
.ifndef Z18; allow override
Z18:					; appears to be a right margin (see L29DE in print.s)
.endif
	.res 1				; init sets this to
LINNUM:
.ifndef TXPSV; allow override
TXPSV:
.endif
	.res 2
.ifndef INPUTBUFFER; allow override
INPUTBUFFER:
.endif

.org ZP_START3

CHARAC:					; holds character used in STRLIT to find the end of a string
	.res 1
ENDCHR:					; holds character used in STRLIT to find the end of a string
	.res 1
EOLPNTR:
	.res 1
DIMFLG:
	.res 1
VALTYP:
.ifdef CONFIG_SMALL
	.res 1
.else
	.res 2
.endif
DATAFLG:				; (right-shifted in GETSPA)
	.res 1
SUBFLG:
	.res 1
INPUTFLG:
	.res 1
CPRMASK:
	.res 1
Z14:					; bit 7 is used to track Ctrl-O state
	.res 1				; init sets this to zero

.org ZP_START4

TEMPPT:					; temp descriptor stack pointer (see PUTNEW)
	.res 1				; (init sets this to the LSB of TEMPST)
LASTPT:					; previous temp stack pointer address (see PUTNEW)
	.res 2				; (init sets second byte to zero)
TEMPST:					; temp descriptor stack (see PUTNEW)
	.res 9				
INDEX:					; used to hold a source address for indirect
	.res 2				; addressing (in MOVSTR)
DEST:
	.res 2
RESULT:
	.res BYTES_FP
RESULT_LAST = RESULT + BYTES_FP-1
TXTTAB:
	.res 2
VARTAB:
	.res 2
ARYTAB:
	.res 2
STREND:
	.res 2
FRETOP:
	.res 2
FRESPC:					; used by GETSPA to provide address 
	.res 2				; of space allocated for a string
MEMSIZ:
	.res 2
CURLIN:
	.res 2
OLDLIN:
	.res 2
OLDTEXT:
	.res 2
Z8C:
	.res 2
DATPTR:
	.res 2
INPTR:
	.res 2
VARNAM:
	.res 2
VARPNT:
	.res 2
FORPNT:
	.res 2
LASTOP:
	.res 2
CPRTYP:
	.res 1
FNCNAM:
TEMP3:
	.res 2
DSCPTR:				; holds the address of a string descriptor
				; (assigned in STRINI)
.ifdef CONFIG_SMALL
		.res 2		
.else
		.res 3
.endif
DSCLEN:
	.res 2
.ifndef JMPADRS ; allow override
JMPADRS			:= DSCLEN + 1
.endif
Z52:				; used in string.s, to hold a length?
	.res 1
ARGEXTENSION:
.ifndef CONFIG_SMALL
	.res 1
.endif
TEMP1:
	.res 1
HIGHDS:
	.res 2
HIGHTR:
	.res 2
.ifndef CONFIG_SMALL
TEMP2:
	.res 1
.endif
INDX:
TMPEXP:
.ifdef CONFIG_SMALL
TEMP2:
.endif
	.res 1
EXPON:
	.res 1
LOWTR:
.ifndef LOWTRX ; allow override
LOWTRX:
.endif
	.res 1
EXPSGN:
	.res 1
FAC:
	.res BYTES_FP
FAC_LAST = FAC + BYTES_FP-1
FACSIGN:
	.res 1
SERLEN:
	.res 1
SHIFTSIGNEXT:				; init sets this to zero
	.res 1
ARG:
	.res BYTES_FP
ARG_LAST = ARG + BYTES_FP-1
ARGSIGN:
	.res 1
STRNG1:					; holds the address of the string in STRLT2
	.res 2				; used for indirect indexing of the string
SGNCPR = STRNG1
FACEXTENSION = STRNG1+1
STRNG2:					; holds address of string in STRLT2
	.res 2
CHRGET:
TXTPTR = <(GENERIC_TXTPTR-GENERIC_CHRGET + CHRGET)
CHRGOT = <(GENERIC_CHRGOT-GENERIC_CHRGET + CHRGET)
CHRGOT2 = <(GENERIC_CHRGOT2-GENERIC_CHRGET + CHRGET)
RNDSEED = <(GENERIC_RNDSEED-GENERIC_CHRGET + CHRGET)


