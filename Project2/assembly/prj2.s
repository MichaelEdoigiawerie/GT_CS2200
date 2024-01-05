! Fall 2023 Revisions 

! This program executes pow as a test program using the LC 2222 calling convention
! Check your registers ($v0) and memory to see if it is consistent with this program

! vector table
vector0:
        .fill 0x00000000                        ! device ID 0
        .fill 0x00000000                        ! device ID 1
        .fill 0x00000000                        ! ...
        .fill 0x00000000
        .fill 0x00000000
        .fill 0x00000000
        .fill 0x00000000
        .fill 0x00000000                        ! device ID 7
        ! end vector table

main:	lea $sp, initsp                         ! initialize the stack pointer
        lw $sp, 0($sp)                          ! finish initialization

        lea $s0, timer_handler                  ! Install timer interrupt handler into vector table
        sw $s0, 0($zero)

        lea $s0, distance_tracker_handler       ! Install distance tracker interrupt handler into vector table
        sw $s0, 1($zero)

        lea $t0, minval
        lw $t0, 0($t0)
	lea $t1, INT_MAX 			! store 0x7FFFFFFF into minval (to initialize)
	lw $t1, 0($t1)	                  		
        sw $t1, 0($t0)

        ei                                      ! Enable interrupts

        lea $a0, BASE                           ! load base for pow
        lw $a0, 0($a0)
        lea $a1, EXP                            ! load power for pow
        lw $a1, 0($a1)
        lea $at, POW                            ! load address of pow
        jalr $at, $ra                           ! run pow
        lea $a0, ANS                            ! load base for pow
        sw $v0, 0($a0)

        halt                                    ! stop the program here
        addi $v0, $zero, -1                     ! load a bad value on failure to halt

BASE:   .fill 2
EXP:    .fill 8
ANS:	.fill 0                                 ! should come out to 256 (BASE^EXP)

INT_MAX: .fill 0x7FFFFFFF

POW:    addi $sp, $sp, -1                       ! allocate space for old frame pointer
        sw $fp, 0($sp)

        addi $fp, $sp, 0                        ! set new frame pointer

        bgt $a1, $zero, BASECHK                 ! check if $a1 is zero
        beq $zero, $zero, RET1                  ! if the exponent is 0, return 1

BASECHK:bgt $a0, $zero, WORK                    ! if the base is 0, return 0
        beq $zero, $zero, RET0

WORK:   addi $a1, $a1, -1                       ! decrement the power
        lea $at, POW                            ! load the address of POW
        addi $sp, $sp, -2                       ! push 2 slots onto the stack
        sw $ra, -1($fp)                         ! save RA to stack
        sw $a0, -2($fp)                         ! save arg 0 to stack
        jalr $at, $ra                           ! recursively call POW
        add $a1, $v0, $zero                     ! store return value in arg 1
        lw $a0, -2($fp)                         ! load the base into arg 0
        lea $at, MULT                           ! load the address of MULT
        jalr $at, $ra                           ! multiply arg 0 (base) and arg 1 (running product)
        lw $ra, -1($fp)                         ! load RA from the stack
        addi $sp, $sp, 2

        beq $zero, $zero, FIN                   ! unconditional branch to FIN

RET1:   add $v0, $zero, $zero                   ! return a value of 0
	addi $v0, $v0, 1                        ! increment and return 1
        beq $zero, $zero, FIN                   ! unconditional branch to FIN

RET0:   add $v0, $zero, $zero                   ! return a value of 0

FIN:	lw $fp, 0($fp)                          ! restore old frame pointer
        addi $sp, $sp, 1                        ! pop off the stack
        jalr $ra, $zero

MULT:   add $v0, $zero, $zero                   ! return value = 0
        addi $t0, $zero, 0                      ! sentinel = 0
AGAIN:  add $v0, $v0, $a0                       ! return value += argument0
        addi $t0, $t0, 1                        ! increment sentinel
        blt $t0, $a1, AGAIN                     ! while sentinel < argument, loop again
        jalr $ra, $zero                         ! return from mult

timer_handler:
        addi $sp, $sp, -3                       ! allocate space for $k0 and other registers
        sw $k0, 0($sp)                          ! save the current value of $k0
        ei                                      ! enable interrupts
        sw $t0, 1($sp)                          ! save the state of the interrupted program
        sw $t1, 2($sp)

        lea $t0, ticks                          ! execute device code
        lw $t1, 0($t0)
        lw $t0, 0($t1)
        addi $t0, $t0, 1
        sw $t0, 0($t1)

        lw $t1, 2($sp)                          ! restore the processor registers
        lw $t0, 1($sp)

        di                                      ! disable interrupts
        lw $k0, 0($sp)                          ! restore $k0
        addi $sp, $sp, 3                        ! pop $k0 and other registers off the stack
        reti                                    ! return from interrupt

distance_tracker_handler:
        addi $sp, $sp, -6                       ! allocate space for $k0 and other registers
        sw $k0, 0($sp)                          ! save the current value of $k0
        ei                                      ! enable interrupts
        sw $t0, 1($sp)                          ! save the state of the interrupted program
        sw $t1, 2($sp)
        sw $s0, 3($sp)
        sw $s1, 4($sp)
        sw $s2, 5($sp)

        in $s0, 1                               ! execute device code and load distance
        
        lea $s1, maxval                         ! load max value
        lw $t0, 0($s1)
        lw $s1, 0($t0)

        lea $s2, minval                         ! load min value
        lw $t1, 0($s2)
        lw $s2, 0($t1)

        bgt $s0, $s1, update_max                ! conditions
        blt $s0, $s2, update_min
        beq $zero, $zero, finish_function

update_max:
        sw $s0, 0($t0)                          ! update max value   
        blt $s0, $s2, update_min                    
        beq $zero, $zero, calc_new_range

update_min:
        sw $s0, 0($t1)                          ! update min value

calc_new_range:
        lw $s1, 0($t0)                          ! get new max value
        lw $s2, 0($t1)                          ! get new min value

        lea $t1, range                          ! get range address
        lw $t1, 0($t1)
        
        nand $s2, $s2, $s2                      ! get 2's complement
        addi $s2, $s2, 1

        add $s2, $s1, $s2                       ! compute range
        sw $s2, 0($t1)                          ! store range

finish_function:
        lw $s2, 5($sp)                          ! restore the processor registers
        lw $s1, 4($sp)
        lw $s0, 3($sp)
        lw $t1, 2($sp)
        lw $t0, 1($sp)

        di                                      ! disable interrupts
        lw $k0, 0($sp)                          ! restore $k0
        addi $sp, $sp, 6                        ! pop $k0 and other registers off the stack
        reti                                    ! return from interrupt

initsp: .fill 0xA000
ticks:  .fill 0xFFFF
range:  .fill 0xFFFE
maxval: .fill 0xFFFD
minval: .fill 0xFFFC