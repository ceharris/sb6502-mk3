
		.include "ascii.h.s"
		.include "delay.h.s"
		.include "display.h.s"
		.include "keys.h.s"
		.include "model.h.s"
		.include "prog.h.s"
		.include "serial.h.s"
		.include "state.h.s"

		.segment "MAGIC"
		.word PROG_MAGIC
		.byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, $C, $D, $E, $84
		.word start

		.segment "CODE"
		.global start
start:
		jsr ser_init
		cli

play_again:
		jsr model_init
next_life:
		jsr model_reset
		jsr ui_clear		; initialize UI display
		jsr ser_iflush		; discard any early key presses

loop:
		jsr ui_update		; display current model state
		jsr model_next		; compute next model state
		bcs life_over		; go if snake bit itself
@scan:
		jsr scan
		bcc loop
		lda loop_timer
		bne @scan
		lda loop_timer+1
		bne @scan
		bra loop

scan:
		jsr key_scan		; scan for user key presses
		cmp #KEY_DUMP
		beq dump
		cmp #KEY_PLAY
		beq pause
		cmp #KEY_QUIT		
		beq game_over		; exit on QUIT key
		cmp #KEY_REDRAW
		beq redraw		; redraw the UI display
		jsr model_key_event	; interpret key as event
		rts

redraw:
		jsr ui_redraw
		jmp loop		
pause:
		jsr key_scan
		cmp #KEY_QUIT
		beq soft_reset
		cmp #KEY_DUMP
		beq dump
		cmp #KEY_PLAY
		bne pause
		jmp loop

dump:
		jsr ui_dump_grid
@wait:
		jsr key_scan
		cmp #KEY_QUIT
		beq soft_reset
		cmp #KEY_PLAY
		beq play_again
		cmp #KEY_DUMP
		bne @wait
		jsr ui_redraw
		jmp loop

life_over:
		dec lives		; lives--
		beq game_over		; used all lives
		jsr ui_life_over	; display life over
		DELAY $0
		; # double the current delay
		lda loop_delay
		asl
		sta loop_delay
		lda loop_delay+1
		rol
		sta loop_delay+1		
		cmp #$0a
		bcc @done
		lda #$0a
		sta loop_delay+1
		stz loop_delay
@done:
		jmp next_life		; still in it

game_over:
		jsr ui_game_over
@loop:
		jsr ui_play_again	; prompt user to play again
		jsr key_scan		; scan for user key presses
		beq @loop		; no key pressed
		cmp #KEY_QUIT
		beq soft_reset
		cmp #KEY_REDRAW
		beq game_over		; redraw game over screen
		cmp #KEY_PLAY
		bne @loop
		jmp play_again

		

		.include "reset.s"	


