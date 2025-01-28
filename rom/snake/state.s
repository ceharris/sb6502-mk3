		.include "state.h.s"

		.segment "ZEROPAGE"

snake_head_x:
		.res 1
snake_head_y:
		.res 1
snake_tail_x:
		.res 1
snake_tail_y:
		.res 1
game_flags:
		.res 1
grow_count:
		.res 1
food_offset_0:
		.res 2
food_offset_1:
		.res 2
food_expires:
		.res 2
score:
		.res 2


		.segment "BSS"
game_grid:
		.res GRID_ROWS*GRID_COLUMNS
