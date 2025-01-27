

		.include "acia.h.s"
		.include "exec.h.s"

		.segment "CODE"
noop_isr:
		rti
	
		.segment "IRQVECS"
		.word noop_isr		; IRQ0
		.word noop_isr		; IRQ1
		.word noop_isr		; IRQ2
		.word acia_isr		; IRQ3 (Serial Console)
		.word noop_isr		; IRQ4
		.word noop_isr		; IRQ5
		.word noop_isr		; IRQ6
		.word noop_isr		; IRQ7

		.segment "VECTORS"
		.word noop_isr
		.word ipl
		.word noop_isr