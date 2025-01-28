
	.ifndef STATE_H
		STATE_H = 1

		GRID_ROWS = 24
		GRID_COLUMNS = 40

		EMPTY_CELL = 0
		SNAKE_HEAD_CELL = $8F
	
		GF_AXIS_VERTICAL = %00000001
		GF_OP_DECREMENT = %00000010
		GF_FOOD_WAITING = %10000000

		.globalzp snake_head_x
		.globalzp snake_head_y
		.globalzp snake_tail_x
		.globalzp snake_tail_y
		.globalzp game_flags
		.globalzp grow_count
		.globalzp food_offset_0
		.globalzp food_offset_1
		.globalzp food_expires
		.globalzp score

		.global game_grid

	.endif