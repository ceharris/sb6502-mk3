
	.ifndef STATE_H
		STATE_H = 1

		GRID_ROWS = 24
		GRID_COLUMNS = 40
		GRID_CELLS = GRID_ROWS*GRID_COLUMNS

		GAME_START_X = 20
		GAME_START_Y = 11

		EMPTY_CELL = 0
		SNAKE_TAIL_RIGHT_CELL = $80
		SNAKE_TAIL_DOWN_CELL = $81
		SNAKE_TAIL_LEFT_CELL = $82
		SNAKE_TAIL_UP_CELL = $83
		SNAKE_HEAD_CELL = $8F
	
		GF_AXIS_VERTICAL = %00000001
		GF_OP_DECREMENT = %00000010
		GF_UNUSED = %00001100
		GF_TIMER_CHANGE = %00010000
		GF_SCORE_CHANGE = %00100000
		GF_FOOD_CHANGE = %01000000
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
		.globalzp next_head_x
		.globalzp next_head_y
		.globalzp prev_tail_x
		.globalzp prev_tail_y
		.globalzp game_flags
		.globalzp grow_count
		.globalzp snake_head_addr
		.globalzp snake_tail_addr
		.globalzp next_head_addr
		.globalzp food_addr_0
		.globalzp food_addr_1
		.globalzp food_expires
		.globalzp score

		.global game_grid

	.endif