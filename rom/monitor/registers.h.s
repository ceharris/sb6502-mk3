	.ifndef REGISTERS_H
		REGISTERS_H = 1

		.globalzp b0
		.globalzp b1
		.globalzp b2
		.globalzp b3
		.globalzp w0
		.globalzp w1
		.globalzp w2

	.macro ldib0 im8
		lda #im8
		sta b0
	.endmacro

	.macro ldib1 im8
		lda #im8
		sta b1
	.endmacro

	.macro phb0
		lda b0
		pha
	.endmacro

	.macro phb1
		lda b1
		pha
	.endmacro

	.macro plb0
		pla
		sta b0
	.endmacro

	.macro plb1
		pla
		sta b1
	.endmacro

	.macro ldiw0 im16
		lda #<im16
		sta w0
		lda #>im16
		sta w0+1
	.endmacro

	.macro ldiw1 im16
		lda #<im16
		sta w1
		lda #>im16
		sta w1+1
	.endmacro

	.macro ldiw2 im16
		lda #<im16
		sta w2
		lda #>im16
		sta w2+1
	.endmacro

	.macro	phw0
		lda w0+1
		pha
		lda w0
		pha
	.endmacro

	.macro	plw0
		pla
		sta w0
		pla
		sta w0+1
	.endmacro

	.macro	phw1
		lda w1+1
		pha
		lda w1
		pha
	.endmacro

	.macro	plw1
		pla
		sta w1
		pla
		sta w1+1
	.endmacro

	.macro	phw2
		lda w2+1
		pha
		lda w2
		pha
	.endmacro

	.macro	plw2
		pla
		sta w2
		pla
		sta w2+1
	.endmacro

	.macro	incw0
		.local no_inc_msb
		inc w0
		bne no_inc_msb
		inc w0+1
	no_inc_msb:
	.endmacro

	.macro	incw1
		.local no_inc_msb
		inc w1
		bne no_inc_msb
		inc w1+1
	no_inc_msb:
	.endmacro

	.macro	incw2
		.local no_inc_msb
		inc w2
		bne no_inc_msb
		inc w2+1
	no_inc_msb:
	.endmacro

	.macro	sbcw1
		lda w0
		sbc w1
		lda w0+1
		sbc w1+1
	.endmacro

	.macro	sbcw2
		lda w0
		sbc w2
		lda w0+1
		sbc w2+1
	.endmacro


	.macro	tw0w1
		lda w0
		sta w1
		lda w0+1
		sta w1+1
	.endmacro

	.macro	tw1w0
		lda w1
		sta w0
		lda w1+1
		sta w0+1
	.endmacro

	.macro	tw2w0
		lda w2
		sta w0
		lda w2+1
		sta w0+1
	.endmacro

	.macro	tw1w2
		lda w1
		sta w2
		lda w1+1
		sta w2+1
	.endmacro

	.macro	tw2w1
		lda w2
		sta w1
		lda w2+1
		sta w1+1
	.endmacro
	
	.endif