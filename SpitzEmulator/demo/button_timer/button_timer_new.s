@ button_timer.s:
@ This example demonstrates ALARM irq and Button irq on Emulator.
@ The program waits then serves button press action, which enables alarm irq.
@ In alarm handler, just blink LED.
@ 
@ Note: 
@ - Button on GPIO 73, LED on GPIO67
@ - Alternate functions are both set to GPIO ('b00) by default.
@ Dung Le, 2013
@

.text
.global _start 
_start:

@==== & INTERRUPT====
.equ GPDR2, 0x40E00014
.equ GRER2, 0x40E00038
.equ GEDR2, 0x40E00050
.equ GPSR2, 0x40E00020
.equ GPCR2, 0x40E0002C
.equ GPLR2, 0x40E00008

.equ GPDR0, 0x40E0000C
.equ GRER0, 0x40E00030
.equ GEDR0, 0x40E00048

.equ GPDR2, 0x40E00014
.equ GRER2, 0x40E00038
.equ GEDR2, 0x40E00050

.equ GPDR3, 0x40E0010C
.equ GRER3, 0x40E00130
.equ GEDR3, 0x40E00148

.equ ICMR , 0x40D00004
.equ ICIP , 0x40D00000

.EQU RCNR, 0X40900000
.EQU RTAR, 0X40900004
.EQU RTSR, 0X40900008


@==================== initialize LED ===========================================
@ set pin to low before set to output
	LDR R3, =GPCR2		 
	LDR R4, =0x08		 
	STR R4, [R3]				
@ set GPDR2 bit 3 to program GPIO <67> as output    
	LDR R1, =GPDR2	
	LDR	R6, [R1]	
	ORR	R6, R6, #0x08			
	STR	R6, [R1]	
@==================== initialize Button ===========================================
@ GPIO 73 as input
	LDR	R0, =GPDR2				
	LDR	R4, [R0]			
	BIC	R4, R4, #0x200		
	STR	R4, [R0]				
@ set for rising edge detect 
	LDR	R0, =GRER2				
	LDR	R4, [R0]	
	ORR	R4, R4, #0x200			
	STR	R4, [R0]	 
@==================== initialize alarm ===========================================
@ ENABLE OSCILLATOR
	LDR R0,= 0x41300008     @ ADDRESS OF OSCILLATOR CONFIGURATION
	LDR R1,[R0]			
	ORR R1, R1, #02			
	STR R1,[R0]		    
@ Set Alarm expiration time 		
	LDR R0,=RTAR			
	MOV R1, #0x2            @ will interrupt in the next 2 sec
	STR R1,[R0]	
@ The rest will be done in button handler...
    
@ ================== Setup interrupt ===========================================
@ active/send clock and button signal to CPU:
    LDR	R0, =ICMR			
	LDR	R1, [R0]			
	ORR	R1, R1, #0x80000000    @ set bit 31 for alarm irq and 10 for GPIO irq
	ORR R1, R1, #0x400
	STR	R1, [R0]		    

@ Hook our interrupt director to irq vector
	MOV	R0, #0x18			@ Load interrupt IRQ vector at address 0x18
	LDR	R4, [R0]			@ Read content of interrupt vector table at 0x18
	LDR	R1, =0xFFF			@ construct mask
	AND 	R4, R4, R1		@ Mask all but offset of part of intruction
	ADD	R4, R4, #0x20		@ build absolute address of IRQ procedure in literal pool

	LDR	R1, [R4]			@ Read BTLDR IRQ address from pool
	STR	R1, BTLDR_IRQ_ADDRESS	@ save BTLDR IRQ for later use
	LDR	R1, =INT_DIRECTOR	@ load address of our INTERRUPT procedure
	STR	R1, [R4]			@ store this address in pool

@ make sure IRQ is enable by clearing bit 7 in CPSR
	MRS	R1, CPSR
	BIC	R1, R1, #0x80
	MSR	CPSR_c, R1
	
@ ...and it 's all set

@===================== WAITLOOP =========================
	MAIN_LOOP:
	NOP
	B	MAIN_LOOP

@================== INTERRUPT DIRECTOR PROCEDURE ===============================
@ Direct interrupt appropriate handler
INT_DIRECTOR:
	STMFD	R13!, {R0, R1, R14} 		@ save registers and PC
	
	LDR	R0, =ICIP			@ point at IRQ pending register
	LDR	R1, [R0]			@ read ICIP content to...

	TST	R1, #0x80000000		@ check if BIT 31 = 1 (alarm) 	
	BNE	CLK_handler			@ YES, GO TO CLK SERVICE
	
	TST	R1, #0x400          @ check BIT 10 (GPIO)
	BEQ PASSON
	
	LDR R0, =GEDR2          @ Yes, check if GPIO 73 causing irq
	LDR R1, [R0]
	TST R1, #0x200
	BNE	BUTTON_handler		@ YES, GO TO BTN SERVICE	
    
PASSON:						@ should not get here (unknown irq)
	LDMFD	R13!, {R0, R1, R14}		@ restore registers	
	SUBS 	PC, R14, #4		@ return from interrupt
	
@============================= BUTTON service ==================================
BUTTON_handler:
@ clear pin 73 pending in GEDR2
	MOV	R1, #0x200			@ this will also reset bit 10 in ICPR and ICIP
	STR	R1, [R0]		    

@ reset current Counter 
	LDR R0,=RCNR		
	MOV R1, #0x0			
    STR R1, [R0]
  
@ ENABLE ALARM INTERUPT		
	LDR R0,=RTSR			
	LDR R1, [R0]			
	ORR R1, R1, #0X4		
	STR R1, [R0]

	LDMFD	R13!, {R0, R1, R14}	@ restore registers,
	SUBS 	PC, R14, #4		@ return from interrupt
    
@============================= CLOCK service ===================================
CLK_handler:
@ clear this interrupt signal
	LDR R0,= RTSR			
	LDR R1, [R0]			
	ORR R1, R1, #0x1			
	STR R1, [R0]	

@ turn on/off led
	LDR R3, =GPLR2	
	LDR R4, [R3]
	TST R4, #0x08
	BNE OFF
    LDR R3, =GPSR2	
	MOV R4, #0x08	
	STR R4, [R3]			@ turn on
	B RESET_CLK
OFF:	
	LDR R3, =GPCR2		 
	MOV R4, #0x08		 
	STR R4, [R3]			@ turn off
    
RESET_CLK:
@ reset current Counter to re-arm alarm irq
	LDR R0,=RCNR		
	MOV R1, #0x0			
    STR R1, [R0]
	
    LDMFD	R13!, {R0, R1, R14}	@ restore registers
	SUBS 	PC, R14, #4		@ return from interrupt
@===============================================================================    

BTLDR_IRQ_ADDRESS:	.word	0x0	@ Space to store bootloader IRQ address

.end
