	 # - Unit width in pixels: 8
 # - Unit height in pixels: 8
 # - Display width in pixels: 256
 # - Display height in pixels: 256
 # - Base Address for Display: 0x10008000 ($gp)
 
.data 
	# Screen Values
	displayAddress: .word 0x10008000
	screenHeight: .word 128
	screenWidth: .word 128
	
	la $t2, centipedeParts
	lw $t1, 4(centipedeParts)
	# Entities
	centipedeParts: .word 0:40
	centipedeMoves: .word 0:40
	centipedeHP: .word 12:1
	
	playerYPos: .word 3964
	playerXPos: .word 64:1
	
	initialBlastYPos: .word 3840
	blasts: .word -4:40
	fleaPos: .word -4:1
	# Colors
	playerColor: .word 0x00ff00
	mushroomColor: .word 0xff70ff
	centipedeHeadColor: .word 0xff1f1f
	centipedeBodyColor: .word 0x00eeff
	backgroundColor: .word 0x010101
	blastColor: .word 0xadd8e6
	fleaColor: .word 0xffff00
	gameOverColor: .word 0xfef3f0
	winColor: .word 0x37eb34
	loseColor: .word 0xeb4634
	result: .word 0:1
.globl main
.text
main:
	### Start
	lw $t0, displayAddress 		# $t0 stores the base address for display
	# Draw background
	li $t1,	0 			
	jal draw_bg_loop
	
	li $t1,	0 
	jal draw_mushrooms
	li $a1, 0
	
	# Init Flea
	li $t1,	0
	jal init_flea
	
	continue_main_inits:
	li $a1, 0
	
	# Init Centipede
	li $t1,	0 			# $t1 stores i, initially zero
	la $t9, centipedeMoves 		# $t9 stores address of centipedeMoves
	jal init_centipede_moves
	
	li $t1, 12
	la $t2, centipedeHP
	sw $t1, ($t2)
	li $t1,	0 			# $t1 stores i, initially zero
	la $t8, centipedeParts 		# $t8 stores address of centipedeParts
	jal init_centipede_parts
	
	jal init_player
	### Update
	jal Update
	j Exit	
	
init_flea:	
	jal get_flea_pos
#continue_init_flea:  
	# draw it in
	lw $t4, fleaPos
	add $t5, $t0, $t4
	lw $t4, fleaColor
	sw $t4, ($t5)
	j continue_main_inits
get_flea_pos:
	bge $t1, 128, fallback_pos
	addi $t1, $t1, 4 
	li $v0, 42			# syscall code random is 42
	li $a0, 0			# random number is in a0
	li $a1, 128			# max number is 28
	syscall
	li $a1, 0
	
	add $t4, $a0, $zero
	li $t2, 4
	div $t4, $t2
	mfhi $t3
	beq $t3, $zero, found_flea_pos
	j get_flea_pos

fallback_pos:
	li $t4, 256
found_flea_pos:
	la $t3, fleaPos
	sw $t4, ($t3)
	jr $ra

init_centipede_moves:
	bge $t1, 40, back_to_main	# branch if i >= 10
	add $t2, $t9, $t1  		# $t2 holds addr(centipedeMoves[i])
	li $t3, 4
	sw $t3, ($t2)			# centipedeMoves[i] = i
	addi $t1, $t1, 4		# i++
	j init_centipede_moves 

init_centipede_parts: 			
	bge $t1, 40, back_to_main	# branch if i >= 10
	add $t2, $t8, $t1  		# $t2 holds addr(centipedeParts[i])
	addi $t3, $t1, 64 
	sw $t3, ($t2)			# centipedeParts[i] = i
	addi $t1, $t1, 4		# i++
	j init_centipede_parts   

update_centipede:
	# $t1: i
	# $t2: addr(centipedeParts[i])
	# $t3: addr(centipedeMoves[i])
	# $t4: value(centipedeParts[i])
	# $t5: value(centipedeMoves[i])
	# $t6: 
	#	1. currPos % screenWidth (check move right)
	#	2. currPos+4 % screenWidth (check move left)
	#	3. nextPos
	# $t7: screenWidth
	# $t8: centipedeParts
	# $t9: centipedeMoves
	## for (i < 10)  
	bge $t1, 40, back_to_main	# branch if i >= 10
	
	## Getting values
	add $t2, $t8, $t1  		# $t2 = addr(centipedeParts[i])
	add $t3, $t9, $t1  		# $t3 = addr(centipedeMoves[i])
	lw $t4, ($t2)		 	# $t4 = value(centipedeParts[i])
	lw $t5, ($t3)		 	# $t5 = value(centipedeMoves[i])
	
	## i++
	add $t1, $t1, 4			
	
	## If just moved down, go other direction
	bge $t5, 5, c_change_direction
	
	## Go down if ends of screen	
	# if at right end, go down
	lw $t7, screenWidth		
	div $t4, $t7
	mfhi $t6
	beq $t6, 0, c_down  		   
	
	# if at left end, go down
	addi $t4, $t4, 4
	div $t4, $t7
	mfhi $t6
	addi $t4, $t4, -4
	beq $t6, 0, c_down
	
	## Collision handling
	# if next spot is not bg colored
	add $t6, $t4, $t5	
	add $t6, $t6, $t0
	lw $t7, ($t6)	
	lw $t6, mushroomColor
	beq $t6, $t7, c_down	# check if next spot ($t7) is mushroomColor
	lw $t6, playerColor
	beq $t6, $t7, Lost
c_update_end:
	add $t4, $t4, $t5 		 
	sw $t4, ($t2)
	j update_centipede	

c_down:
	bge $t4, 3968, c_change_direction
	addi $t5, $5, 128 
	sw $t5, ($t3) 
	j c_update_end
	
c_hit_bottom: # unused atm
	addi $t5, $t5, -128
	j c_change_direction
	
c_change_direction:
	lw $t7, screenWidth		# if at ends of screen, go down
	div $t4, $t7
	mfhi $t6
	beq $t6, 0, c_right  		# if pos mod width == 0, move part down   
c_left:
	li $t5, -4
	sw $t5, ($t3)
	j c_update_end
	
c_right:
	li $t5, 4
	sw $t5, ($t3)
	j c_update_end

# Meant for updating the centipede 
draw_centipede:
	bge $t1, 40, back_to_main	# branch if i >= 10
	add $t2, $t8, $t1  		# $t2 = addr(centipedeParts[i])
	
	lw $t3, ($t2)			# $t3 = value(centipedeParts[i])
	
	add $t2, $t0, $t3		# $t2 = addr(displayAddress[0]) + offset
	lw $t4, centipedeHeadColor 		# $t4 stores the red colour code
	bge $t1, 36, finish_c_draw
	lw $t4, centipedeBodyColor
finish_c_draw:
	sw $t4, ($t2) 			# paint the centipede part.	
	add $t1, $t1, 4			# i++
	j draw_centipede	

# Initialization of shrooms
draw_mushrooms:
	##	for i(t1) < 3072
	bge $t1, 3072, back_to_main	# branch if i >= 200
	add $t2, $t0, $t1  		# $t2 holds addr(A[i])
	addi $t1, $t1, 4		# i++
	
	##	if rand(a0) < 2 break
	li $v0, 42			# syscall code random is 42
	li $a0, 0			# random number is in a0
	li $a1, 28			# max number is 28
	syscall
	
	bge $a0, 2, draw_mushrooms  	# if rand >= 2, don't draw
	
	##	draw mushroom
	lw $t3, mushroomColor 		# $t3 stores the red colour code
	sw $t3, ($t2) 			# paint mushroom	
	j draw_mushrooms

# Helper function for quick'n easy jump backs
back_to_main:
	jr $ra       

draw_bg_loop:
	bge $t1, 4096, back_to_main
	add $t2, $t0, $t1  		# $t2 holds addr(A[i])
	addi $t1, $t1, 4		# i++
	lw $t3, backgroundColor 	# $t3 stores the background color
	sw $t3, ($t2)
	j draw_bg_loop

wipe_centipede:
	bge $t1, 40, back_to_main	# branch if i >= 10
	add $t2, $t8, $t1  		# $t2 = addr(centipedeParts[i])
	add $t1, $t1, 4			# i++
	lw $t3, ($t2)			# $t3 = value(centipedeParts[i])
	add $t2, $t0, $t3		# $t2 = addr(displayAddress[0]) + offset 
	lw $t4, backgroundColor 	# $t4 stores the red colour code
	sw $t4, ($t2) 			# paint the centipede part.	
	j wipe_centipede # changed this	

init_player:
	la $t3, playerXPos
	li $t2, 64
	sw $t2, ($t3)
	jr $ra

wipe_player:

	lw $t2, playerXPos
	lw $t3, backgroundColor
	add $t4, $t0, $t2
	lw $t2, playerYPos
	add $t4, $t4, $t2
	sw $t3, ($t4)
	jr $ra	
	
draw_blasts:
	bge $t1, 40, back_to_main
	la $t2, blasts 
	add $t3, $t2, $t1 #blasts[i]
	addi $t1, $t1, 4	
	lw $t2, ($t3) # val(blasts[i])
	beq $t2, -4, draw_blasts
	add $t4, $t0, $t2 # offset t0 by val(blasts[i])
	lw $t3, blastColor
	sw $t3, ($t4)
	j draw_blasts
		
make_blast:
	# ! do not change t1, needed for continue_input
	# NOTE: $t3 is the address to store pos
	lw $t4, playerXPos
	lw $t5, initialBlastYPos
	add $t4, $t4, $t5 
	sw $t4, ($t3)
	j continue_input

find_available_blast:
	# ! do not change t1, needed for continue_input
	bge $t2, 40, continue_input
	add $t3, $t2, $t4
	lw $t5, ($t3)
	beq $t5, -4, make_blast
	addi $t2, $t2, 4
	j find_available_blast

pressed_shoot_blaster:
	# ! do not change t1, needed for continue_input
	li $t2, 0
	la $t4, blasts
	j find_available_blast

wipe_blasts:
	bge $t1, 40, back_to_main
	la $t2, blasts 
	add $t3, $t2, $t1 	#blasts[i]
	addi $t1, $t1, 4	
	lw $t2, ($t3) 		# val(blasts[i])
	beq $t2, -4, wipe_blasts
	add $t5, $t2, $t0
	lw $t6, backgroundColor
	sw $t6, ($t5)
	j wipe_blasts

update_blasts:
	# move them up
	bge $t1, 40, back_to_main
	la $t2, blasts 
	add $t3, $t2, $t1 	#blasts[i]
	addi $t1, $t1, 4	
	lw $t2, ($t3) 		# val(blasts[i])
	beq $t2, -4, update_blasts
	
	# Move blast up by -128
	addi $t2, $t2, -128
	
	# if hit top of screen destroy
	blt $t2, 0, destroy_blast
	
	add $t5, $t0, $t2
	
	lw $t6, backgroundColor
	lw $t7, ($t5)
	bne $t6, $t7, hit_something				
	continue_updating_blast:
	sw $t2, ($t3)
	j update_blasts

hit_something:
	lw $t6, centipedeBodyColor
	beq $t6, $t7, hit_centipede
	lw $t6, centipedeHeadColor
	beq $t6, $t7, hit_centipede
	lw $t6, mushroomColor
	beq $t6, $t7, hit_mushroom

hit_mushroom:
	lw $t6, backgroundColor
	sw $t6, ($t5)
	j destroy_blast
	
hit_centipede:
	lw $t5, centipedeHP
	addi $t6, $t5, -4
	ble $t6, 0, Won
	la $t5, centipedeHP
	sw $t6, ($t5)
	j destroy_blast
	
destroy_blast:
	li $t2, -4
	j continue_updating_blast

keyboard_input:
	lw  $t1, 0xffff0004			# Read Key value into t1	
	beq $t1, 0x78, pressed_shoot_blaster	# If `x`, shoot blaster
	
continue_input:
	beq $t1, 0x6A, keyboard_left	# If `j`, move left
	beq $t1, 0x6B, keyboard_right	# If `k`, move right
	beq $t1, 0x63, Exit 		# If `c`, terminate the program gracefully
	j inputDoneUpdate
	
keyboard_left:	
	la $t3, playerXPos
	lw $t4, ($t3)
	add $t2, $t4, -4
	li $t5, 0
	blt $t2, $t5, loop_from_left
	sw $t2, ($t3)
	j inputDoneUpdate
	
loop_from_left:
	li $t2, 124
	sw $t2, ($t3)
	j inputDoneUpdate
	
keyboard_right:	
	la $t3, playerXPos
	lw $t4, ($t3)
	add $t2, $t4, 4
	li $t5, 128
	bge $t2, $t5, loop_from_right
	sw $t2, ($t3)
	j inputDoneUpdate
	
loop_from_right:
	li $t2, 0
	sw $t2, ($t3)
	j inputDoneUpdate
	

draw_player:
	lw $t2, playerXPos
	lw $t3, playerColor
	add $t4, $t0, $t2
	lw $t2, playerYPos
	add $t4, $t4, $t2 
	sw $t3, ($t4)
	jr $ra		

update_flea:
	la $t2, fleaPos
	lw $t3, ($t2)
	li $t4, -4
	beq, $t4, $t3, respawn_flea
	lw $t4, fleaColor
	add $t5, $t3, $t0
	lw $t6, ($t5)
	bne $t6, $t4, continue_flea_update
	lw $t4, backgroundColor
	sw $t4, ($t5)
continue_flea_update:	
	add $t3, $t3, 128
	bge $t3, 4096, kill_flea
	sw $t3, ($t2)
	add $t3, $t3, $t0
	lw $t4, ($t3)
	lw $t5, blastColor
	beq $t4, $t5, kill_flea 
	lw $t5, playerColor
	beq $t4, $t5, Lost 
	lw $t5, backgroundColor
	bne $t4, $t5, back_to_main # don't draw 
	lw $t4, fleaColor
	sw $t4, ($t3)
	j fleaDoneUpdate
kill_flea:
	la $t2, fleaPos
	li $t3, -4
	sw $t3, ($t2)
	j fleaDoneUpdate
respawn_flea:
	li $t1,	0
	jal get_flea_pos
	li $a1, 0
	j fleaDoneUpdate
# Runs once per frame
Update:
	
	j update_flea
	fleaDoneUpdate:
	#jal draw_flea
	# Centipede
	li $t1, 0
	jal wipe_centipede
	li $t1,	0    
	jal update_centipede
	li $t1,	0
	
	jal draw_centipede
	
	# todo, include flea stuff
	# Player
	jal wipe_player
	lw $t1, 0xffff0000   		# Check MMIO location for keypress
	beq $t1, 1, keyboard_input	# If we have input, jump to handler
	
inputDoneUpdate:
	jal draw_player
	
	li $t1,	0
	jal wipe_blasts
	
	li $t1,	0
	jal update_blasts
	
	li $t1,	0
	jal draw_blasts

	# system refresh
	li $v0, 32 
	li $a0, 50				# Sleep 1/20 second 
	syscall
	j Update
	
GameOver_keyboard_input:
	lw  $t1, 0xffff0004			# Read Key value into t1	
	beq $t1, 0x72, main			# If `r`, restart
	beq $t1, 0x63, Exit 			# If `c`, terminate the program gracefully
	j gameover_input_done
draw_g:
	# t1 is color, t2 is top left
	sw $t1, 128($t2)
	sw $t1, 132($t2)
	sw $t1, 136($t2)
	sw $t1, 140($t2)
	
	sw $t1, 256($t2)
	
	sw $t1, 384($t2)
	sw $t1, 392($t2)
	sw $t1, 396($t2)
	
	sw $t1, 512($t2)
	sw $t1, 524($t2)
	
	sw $t1, 640($t2)
	sw $t1, 644($t2)
	sw $t1, 648($t2)
	sw $t1, 652($t2)	
	jr $ra


draw_game_over_win:
	lw $t1, winColor
	addi $t2, $t0, 44
	jal draw_g
	addi $t2, $t0, 64
	jal draw_g
	j GameOverLoop

draw_game_over_lose:
	lw $t1, loseColor
	addi $t2, $t0, 44
	jal draw_g
	addi $t2, $t0, 64
	jal draw_g
	j GameOverLoop
Lost: 
	j draw_game_over_lose
	j GameOverLoop
Won:
	j draw_game_over_win
	j GameOverLoop
	
GameOverLoop:
	li $t1, 0
	lw $t1, 0xffff0000   			# Check MMIO location for keypress
	beq $t1, 1, GameOver_keyboard_input	# If we have input, jump to handler
	gameover_input_done:
	# system refresh
	li $v0, 32 
	li $a0, 50				# Sleep 1/20 second 
	syscall
	j GameOverLoop
Exit:
	li $v0, 10 				# terminate the program gracefully
 	syscall
 
