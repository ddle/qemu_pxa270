@
@ This version implements ALARM clock irq
@ Dung Le
@

.text
.global _start 
_start:

@====GPIO, UART & INTERRUPT====
.equ GPDR2, 0x40E00014
.equ GRER2, 0x40E00038
.equ GEDR2, 0x40E00050
.equ GPSR2, 0x40E00020
.equ GPCR2, 0x40E0002C
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
LDR R3, =GPCR2		 
LDR R4, =0x08		 
STR R4, [R3]		@ set pin to low before set to output
LDR R1, =GPDR2	
LDR	R6, [R1]	
ORR	R6, R6, #0x08	@ set bit 3 to program GPIO <67> as output
STR	R6, [R1]	

@==================== initialize CLK ===========================================
@ ENABLE OSCILLATOR
	LDR R0,= 0X41300008		@ADDRESS OF OSCILLATOR CONFIGURATION
	LDR R1,[R0]			
	ORR R1, R1, #02			
	STR R1,[R0]		
@ read current Counter 
	LDR R0,=RCNR		
	LDR R1, [R0]			@STORE RESULTS TO RCNR			
@ Set Alarm  		
	LDR R0,=RTAR			
	ADD R1, R1, #0x1		@ will interrupt in the next sec
	STR R1,[R0]		
@ ENABLE ALARM INTERUPT		
	LDR R0,=RTSR			
	LDR R1, [R0]			
	ORR R1, R1, #0X4		
	STR R1, [R0]	

@ ================== Setup interrupt ===========================================
@ active/send clock interrupt signal to IRQ:
    LDR	R0, =ICMR			
	LDR	R1, [R0]			
	ORR	R1, R1, #0x80000000    @ set bit 31
	STR	R1, [R0]		    

@ Hook our interrupt handler to irq vector
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

@===================== MAINLINE =========================
	MAIN_LOOP:
	NOP
	B	MAIN_LOOP

@================== INTERRUPT DIRECTOR PROCEDURE ===============================
@ Direct interrupt to user or system service, note that interrupt services 
@ automatically return to mainline program after finished, 
INT_DIRECTOR:
	STMFD	R13!, {R0, R1, R14} 		@ save registers and PC
	
	LDR	R0, =ICIP			@ point at IRQ pending register
	LDR	R1, [R0]			@ read ICIP content to...

	TST	R1, #0x80000000		@ check if BIT 31 = 1	
	BNE	CLK_handler			@ YES, GO TO CLK SERVICE
	
	TST	R1, #0x400			@ check if BIT 10	
	BNE	BUTTON_handler		@ YES, GO TO CLK SERVICE	
    
PASSON:						@ should not get here (unknown irq)
	LDMFD	R13!, {R0, R1, R14}		@ restore registers	
	SUBS 	PC, R14, #4		@ return from interrupt
	
@============================= BUTTON service ==================================
BUTTON_handler:
@ clear bit 9 in GEDR2
	MOV	R1, #0x00000200		@ this will also reset bit 10 in ICPR and ICIP
	STR	R1, [R0]		    

	LDMFD	R13!, {R0, R1, R14}	@ restore registers,
	SUBS 	PC, R14, #4		@ return from interrupt
    
@============================= CLOCK service ===================================
CLK_handler:
@ clear this interrupt signal
	LDR R0,= RTSR			
	LDR R1, [R0]			
	ORR R1, R1, #0x1			
	STR R1, [R0]	
@ read current Counter 
	LDR R0,=RCNR		
	LDR R1, [R0]			@STORE RESULTS TO RCNR			
@ Set Alarm  		
	LDR R0,=RTAR			
	ADD R1, R1, #0x1		@ will interrupt in the next sec
	STR R1,[R0]		
@ turn on/off led
    LDR R3, =GPSR2	
	LDR R4, =0x08	
	STR R4, [R3]			@ turn on		
	LDR R3, =GPCR2		 
	LDR R4, =0x08		 
	STR R4, [R3]			@ turn off

    LDMFD	R13!, {R0, R1, R14}	@ restore registers
	SUBS 	PC, R14, #4		@ return from interrupt
@===============================================================================    

BTLDR_IRQ_ADDRESS:	.word	0x0	@ Space to store bootloader IRQ address

.end
