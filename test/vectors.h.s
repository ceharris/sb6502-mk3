		.org $7fe0
		.rorg $ffe0
		.word noop_isr
		.word noop_isr
		.word noop_isr
		.word noop_isr
		.word noop_isr
		.word noop_isr
		.word noop_isr
		.rend
		
		.org $7ffa
		.rorg $fffa
		.word noop_isr
		.word reset
		.word noop_isr
		.rend
