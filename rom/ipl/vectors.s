
		.global ipl

		.global acia_isr

		.segment "CODE"
noop_isr:
		rti
	
		.segment "IRQVECS"
		.word noop_isr		; IRQ0
		.word noop_isr		; IRQ1
		.word noop_isr		; IRQ2
		.word acia_isr		; IRQ3 (serial console)
		.word noop_isr		; IRQ4
		.word noop_isr		; IRQ5
		.word noop_isr		; IRQ6
		.word noop_isr		; IRQ7

		.segment "MACHVECS"
		.word noop_isr
		.word ipl
		.word noop_isr