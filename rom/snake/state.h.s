
	.ifndef STATE_H
		STATE_H = 1

		GRID_ROWS = 24
		GRID_COLUMNS = 40

		EMPTY_CELL = 0
		SNAKE_HEAD_CELL = $8F
	
		GF_AXIS_VERTICAL = %00000001
		GF_OP_DECREMENT = %00000010
		GF_TIMER_DIRTY = %00100000
		GF_SCORE_DIRTY = %01000000
		GF_FOOD_WAITING = %10000000

	.macro ldiw im16
		lda #<im16
		sta W
		lda #>im16
		sta W+1
	.endmacro


		.globalzp B
		.globalzp W
		.globalzp snake_head_x
		.globalzp snake_head_y
		.globalzp snake_tail_x
		.globalzp snake_tail_y
		.globalzp next_x
		.globalzp next_y
		.globalzp game_flags
		.globalzp grow_count
		.globalzp snake_head_addr
		.globalzp snake_tail_addr
		.globalzp next_addr
		.globalzp food_addr_0
		.globalzp food_addr_1
		.globalzp food_expires
		.globalzp score

		.global game_grid

	.endif