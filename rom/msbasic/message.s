; global messages: "error", "in", "ready", "break"

.segment "CODE"

QT_ERROR:
        .byte " Error", 0
  
QT_IN:
        .byte " in ", 0

QT_OK:
	.byte CR, LF, "Ok", CR, LF, 0

QT_BREAK:
	.byte CR, LF, "Break", 0
