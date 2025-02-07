	.ifndef SERIAL_H
		SERIAL_H = 1

		.global ser_init
		.global ser_isr
		.global ser_flush
		.global ser_putc
		.global ser_putci
		.global ser_puts
		.global ser_putsw
		.global ser_putsc

		.global ser_getc
		.global ser_getcp

	.endif