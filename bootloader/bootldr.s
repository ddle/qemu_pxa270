@
@ bootloader for qemu's PXA270 PDA board 
@ Dung Le
@

.equ GPDR2, 0x40E00014
.equ GRER2, 0x40E00038
.equ GEDR2, 0x40E00050
.equ GPSR2, 0x40E00020
.equ GPCR2, 0x40E0002C

.global _start
_start:

	ldr pc,reset_handler
    ldr pc,undefined_handler
    ldr pc,swi_handler
    ldr pc,prefetch_handler
    ldr pc,data_handler
    ldr pc,unused_handler
    ldr pc,irq_handler
    ldr pc,fiq_handler
reset_handler:      .word reset
undefined_handler:  .word hang
swi_handler:        .word hang
prefetch_handler:   .word hang
data_handler:       .word hang
unused_handler:     .word hang
irq_handler:        .word irq
fiq_handler:        .word hang

reset:

    ldr r0,=0xa0010000 @ spitz's specific load address
    mov r1,#0x0
        
    ldmia r0!,{r2,r3,r4,r5,r6,r7,r8,r9}
    stmia r1!,{r2,r3,r4,r5,r6,r7,r8,r9}
    ldmia r0!,{r2,r3,r4,r5,r6,r7,r8,r9}
    stmia r1!,{r2,r3,r4,r5,r6,r7,r8,r9}

    ;@ (PSR_IRQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
    mov r0,#0xD2
    msr cpsr_c,r0
    mov sp,#0x10000

    ;@ (PSR_FIQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
    mov r0,#0xD1
    msr cpsr_c,r0
    mov sp,#0x4000

    ;@ (PSR_SVC_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
    mov r0,#0xD3
    msr cpsr_c,r0
    mov sp,#0x8000000

    ;@ SVC MODE, IRQ ENABLED, FIQ DIS
    ;@mov r0,#0x53
    ;@msr cpsr_c, r0
    
@    b LOOP
	
@reset_blink:

	LDR R1, =GPDR2	
	LDR	R6, [R1]	
	ORR	R6, R6, #0x08	@ set bit 3 to program GPIO <67> as output
	STR	R6, [R1]	

	LDR R3, =GPSR2	
	LDR R4, =0x08	
	STR R4, [R3]		@ turn on
	
	LDR R3, =GPCR2		 
	LDR R4, =0x08		 
	STR R4, [R3]		@ turn off

LOOP:
	B LOOP    @ do nothing here, or could jump to a another boot 
	
hang: 
	b hang

irq: 
	b irq


.end
