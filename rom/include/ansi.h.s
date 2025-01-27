	.ifndef ANSI_H
		ANSI_H = 1

	.macro	ansi_home
		.byte $1B,"[H"
	.endmacro

	.macro	ansi_erase_display
		.byte $1B,"[J"
	.endmacro

	.endif