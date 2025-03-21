
		.global ser_isr
		.global timer_isr

		.segment "CODE"
noop_isr:
		rti
	
		.segment "IRQVECS"
		.word noop_isr		; IRQ0
		.word noop_isr		; IRQ1
		.word noop_isr		; IRQ2
		.word ser_isr		; IRQ3 (serial console)
		.word noop_isr		; IRQ4
		.word noop_isr		; IRQ5
		.word timer_isr		; IRQ6 (timer)
		.word noop_isr		; IRQ7

		.segment "MACHVECS"
		.word noop_isr
		.word noop_isr
		.word noop_isr