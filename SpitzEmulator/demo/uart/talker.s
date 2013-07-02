@
@ ARM ASM DRIVER ON PXA270 FOR 16550 UART
@ By Dung Le - APRIL 2013
@ 
@ SEND (ASYNCHRONOUSLY) A MESSAGE OVER EXAR ST16C554Q QUAD UART/COM2
@ ON ZUES BOARD TO DOUBLETALKER BOARD (RC 8660), WHENEVER BUTTON IS PRESSED.
@ 
@ NOTE: This version supports both emulator and lab board (ZEUS), use USE_EMULATOR
@ constant below to switch b/w platform. The difference are base address and register 
@ offsets of the UART controllers. Another is the load address; in ldscript, use 
@ 0xa100_0000 for emulator, and 0x0040_0000 for Zeus
@ 
@ Also the emulator uses a virtual terminal for monitoring serial output, 
@ we could expect some minor differences when using real board with talker.
@ 
@ Debounced button      -----> GPIO <73>
@ UART COM2 IRQ output  -----> GPIO <10>
@================================================================================

.text
.global _start 
_start:

.equ GPDR0, 0x40E0000C
.equ GRER0, 0x40E00030
.equ GEDR0, 0x40E00048

.equ GPDR2, 0x40E00014
.equ GRER2, 0x40E00038
.equ GEDR2, 0x40E00050
.equ GPSR2, 0x40E00020
.equ GPCR2, 0x40E0002C
.equ GAFR2_L, 0x40E00064

.equ ICMR , 0x40D00004
.equ ICIP , 0x40D00000

.equ USE_EMULATOR, 1

.if USE_EMULATOR
    .equ UART_BASE, 0x10000000
    .equ UART_LCR , 0x10000003
    .equ UART_IER , 0x10000001
    .equ UART_FCR , 0x10000002
    .equ UART_MCR , 0x10000004
    .equ UART_MSR , 0x10000006
    .equ UART_LSR , 0x10000005
    .equ UART_DLL , 0x10000000
    .equ UART_DLM , 0x10000001
.else
    .equ UART_BASE, 0x10800000
    .equ UART_LCR , 0x10800006
    .equ UART_IER , 0x10800002
    .equ UART_FCR , 0x10800004
    .equ UART_MCR , 0x10800008
    .equ UART_MSR , 0x1080000C
    .equ UART_LSR , 0x1080000A
    .equ UART_DLL , 0x10800000
    .equ UART_DLM , 0x10800002
.endif

@ =============== Init button and uart =======================
@ init GPIO <73> as normal GPIO (alternate fucntion 0b00)
    LDR    R0, =GAFR2_L
    LDR    R4, [R0]
    BIC    R4, R4, #0xC0000   
    STR    R4, [R0]
@ init GPIO <73> for input
    LDR    R0, =GPDR2
    LDR    R4, [R0]
    BIC    R4, R4, #0x200        
    STR    R4, [R0] 
@ setup rising edge detect on GPIO <73>
    LDR    R0, =GRER2
    LDR    R4, [R0]
    ORR    R4, R4, #0x200
    STR    R4, [R0]
    
@ Init GPIO <10> for input
    LDR    R0, =GPDR0
    LDR    R4, [R0]
    BIC    R4, R4, #0x400
    STR    R4, [R0]
@ setup rising edge detect on GPIO <10>
    LDR    R0, =GRER0
    LDR    R4, [R0]
    ORR    R4, R4, #0x400
    STR    R4, [R0]

@ Init UART
@ disable uart irq first
    LDR R0, =UART_IER        @ point to interrupt enable register
    MOV R1, #0x00            
    STRB R1, [R0] 

@ UART params: 
@ set DLAB bit in line control Register to access baud rate divisor: 
    LDR R0, =UART_LCR        @ point to uart line control register
    MOV R1, #0x83            @ value for divisor enable = 1, 8bits, no parity, 1 stop bit
    STRB R1, [R0]            
@ Load divisor value to give 38.4 kBits/sec
    LDR R0, =UART_DLL        @ point to low divisor register
    MOV R1, #0x18            @ divisor for 38.4 kbits/sec
    STRB R1, [R0]           
    LDR R0, =UART_DLM        @ point to high divisor register
    MOV R1, #0x0             @ value for divisor high register
    STRB R1, [R0]            
@ Toggle DLAB bit back to 0 to give access to IER register
    LDR R0, =UART_LCR        
    MOV R1, #0x03            @ value for divisor enable = 0, 8bits, no parity, 1 stop bit
    STRB R1, [R0]            
@ Clear FIFO and turn off FIFO mode
    LDR R0, =UART_FCR        
    MOV R1, #0x06            @ value to disable FIFO and clear FIFO
    STRB R1, [R0]           

@ No flow ctrl: DTR and RTS are both wedged high to keep remote happy
    LDR R0, =UART_MCR        
    MOV R1, #0x03            
    STRB R1, [R0]    
    
@ ================== Setup for interrupt ===========================================
@ active/send GPIO irq signal to CPU:
    LDR    R0, =ICMR            
    LDR    R1, [R0]            
    ORR R1, R1, #0x400
    STR    R1, [R0]    
    
@ Setup irq vector 
@ Hook:
    MOV    R0, #0x18        @ Load interrupt IRQ vector at address 0x18
    LDR    R4, [R0]         @ Read content of interrupt vector table at 0x18
    LDR    R1, =0xFFF       @ construct mask
    AND     R4, R4, R1      @ Mask all but offset of part of intruction
    ADD    R4, R4, #0x20    @ build absolute address of IRQ procedure in literal pool
@ Chain:
    LDR    R1, [R4]         @ Read BTLDR IRQ address from pool
    STR    R1, BTLDR_IRQ_ADDRESS    @ save BTLDR IRQ for later use
    LDR    R1, =INTR_DIRECTOR       @ load address of our INTERRUPT procedure
    STR    R1, [R4]         @ store this address in pool

@ make sure IRQ is enable by clearing bit 7 in CPSR
    MRS    R1, CPSR
    BIC    R1, R1, #0x80
    MSR    CPSR_c, R1
@ ...and it 's all set

@=====================MAIN PROGRAM=========================
MAIN_LOOP:
    NOP
    B    MAIN_LOOP
    NOP

@==================INTERRUPT DIRECTOR PROCEDURE============
@ Direct interrupt to our handlers or to system service

INTR_DIRECTOR:
    STMFD    R13!, {R0, R1, R14}         @ save registers and PC
    
    LDR    R0, =ICIP           @ point at IRQ pending register
    LDR    R1, [R0]            @ read ICIP content to...

    TST    R1, #0x400          @ check BIT 10 (GPIO)
    BEQ    PASSON
    
    LDR    R0, =GEDR0          @ YES, load GEDR0 address...
    LDR    R1, [R0]            @ ...and read content of GEDR to...
    TST    R1, #0x400          @ check if bit 10 = 1 (GPIO <10> rising edge detected)
    BNE    TLKR_SVC            @ YES, go to send character service
    
    LDR    R0, =GEDR2          @ Yes, check if GPIO 73 causing irq
    LDR    R1, [R0]
    TST    R1, #0x200
    BNE    BUTTON_SVC          @ YES, GO TO BTN SERVICE    
    
PASSON:                        @ should not get here (unknown irq)
    LDMFD    R13!, {R0, R1, R14}        @ restore registers    
    SUBS     PC, R14, #4       @ return from interrupt
    
@=============================BUTTON service=========================================
@ Turn on UART interrupt output so that msg will be automatically sent.
@ There are two sources could cause uart irq:
@ - Uart buffer (THR) empty: whenever THR is empty
@ - Modem status change: particularly, whenever CTS is rising/falling. 
@ Note: our actual serial connection b/w talker and Zeus involves: TX, RX and CTS ( no RTS ).
@ In my experience, no need to set irq output bit on MCR because it is set automatically 
@ when an IER bit is set

BUTTON_SVC:
@ clear pin 73 pending in GEDR2
    MOV    R1, #0x200            @ this will also reset bit 10 in ICPR and ICIP
    STR    R1, [R0]
    
@ condition for interrupt: Tx empty interrupt and modem status interrupt (CTS#)
    LDR    R0, =UART_IER         @ point to interrupt enable register
    MOV    R1, #0x0A        
    STRB   R1, [R0]            
    
@ Keep DTR and RTS activated, enable uart global irq output
    LDR    R0, =UART_MCR         @ point to modem control register
    MOV    R1, #0x0B            
    STRB   R1, [R0]                
    
    LDMFD  R13!, {R0, R1, R14}   @ restore registers,
    SUBS   PC, R14, #4           @ return from interrupt
 
@==============================TLKR_SVC:============================================
@ This service sends character codes to UART to make RC8660 "talks". Our sending logic 
@ uses interrupt approach (rather than polling status bit).
@ As mentioned, two sources could cause an UART irq: THR empty or CTS# change. However
@ it is observed that CTS@ remains LOW most of the time (meaning it is clear to send) and
@ will not the trigger interrupt unless our talker is busy (or if I disconnection the DB9 cable, 
@ which causes a LOW to HIGH transition because the CTS# is pulled HIGH on zeus side).
@ The main point is: THR empty is what keeps the sending logic going, and one character
@ (one byte) is transfered each time THR empty triggered. Putting another byte in the buffer 
@ will turn off this signal until it is sent out to talker. The sending will end at end of
@ message, when we turn off these UART irq sources.
@

TLKR_SVC:
    STMFD  R13!, {R2-R5}
@ clear pending bit on GEDR0
    LDR    R0, =GEDR0
    MOV    R1, #0x400
    STR    R1, [R0]	
@ check if CTS# is currently asserted, read MSR will reset modem status change interrupt bits
    LDR    R0,=UART_MSR         
    LDRB   R3, [R0]
    TST    R3, #0x10
    BEQ    NOCTS                @ if no, then go check THR
    LDR    R0, =UART_LSR        @ IF YES, then point to Line status register LSR to...
    LDRB   R1, [R0]             @ read LSR ( will not clear interrupt) and...
    TST    R1, #0x20            @ check if THR is empty
    BEQ    GOBACK               @ IF NOT, then go to GOBACK (exit)
    B      SEND                 @ else send characters
NOCTS:
    LDR    R0, =UART_LSR        @ point to line status register
    LDRB   R1, [R0]             @ read LSR ( will not clear interrupt) and...
    TST    R1, #0x20            @ check if THR is empty
    BEQ    GOBACK               @ IF NOT, then go to GOBACK (exit)
    LDR    R4, =UART_IER        @ point to IER
    MOV    R5, #0x08            @ disable bit 1 = TX interrupt enable, 0x1000=> 0 to bit 1, 1 to bit 3
    STRB   R5, [R4]             @ write to IER
    B      GOBACK               @ exit and wait for CTS#
    
@ UNMASK THR, SEND , RESET CHAR_COUNT IF NEED AND DISABLE UART INT
SEND:
@ make sure uart irq is still enable
    LDR    R4, =UART_IER
    MOV    R5, #0x0A            @ bit 3 and bit 1
    STRB   R5, [R4]
@ get current character from memory and send to buffer
    LDR    R0, =CHAR_PTR        
    LDR    R1, [R0]             @ get our string pointer
    LDRB   R4, [R1], #1         @ read character (8bits) and increment pointer 
    STR    R1,[R0]              @ put increment address in R1 back
    
    LDR    R5, =UART_BASE       @ point at UART transmit buffer
    STRB   R4, [R5]             @ write character to buffer
@ update character counter                     
    LDR    R2, =CHAR_COUNT      @ counter address
    LDR    R3, [R2]             @ R2 = get current count value     
    SUBS   R3, R3, #1           @ Decrement character counter by 1
    STR    R3, [R2]             @ store counter back
@ check for end of message
    BNE    GOBACK               @ greater than 0, more characters
	
@ Done sending message, restore string pointer and counter
    LDR    R3, =MESSAGE         @ else : DONE, reload start string address
    STR    R3, [R0]             @ write to char pointer 
    MOV    R3, #MESSAGE_LEN     @ reload string length
    STR    R3, [R2]             @ write back to memory
@ disable uart interrupt
    LDR    R4, =UART_IER 
    MOV    R5, #0x00             
    STRB   R5, [R4]
@ DTR and RTS deactivated, disable uart global irq output
    LDR    R0, =UART_MCR        @ point to modem control register
    MOV    R1, #0x00         
    STRB   R1, [R0] 
@ clear pending bit on GEDR0, again
    LDR    R0, =GEDR0
    MOV    R1, #0x400
    STR    R1, [R0]	
	
GOBACK:	
    LDMFD  R13!, {R2-R5}              @ restore additional regs
    LDMFD  R13!, {R0, R1, R14}    @ restore original regs
    SUBS   PC, R14, #4                 @ return from interrupt to wait loop

BTLDR_IRQ_ADDRESS:    .word    0x0   @ Space to store bootloader IRQ address

.equ MESSAGE_LEN, (MESSAGE_END-MESSAGE)

.data
.align 2                @ 2^n alignment n = 2, hence word align (.align 4 == 16 bytes alignment)
                        @ put align wherever we want that following data to be aligned
                        @ by "data", meaning anything start with a label
MESSAGE:          
.byte 0x01              @ ctrl - A
.ascii "1o"             @ vader void
.byte 0x01              @ ctrl - A
.ascii "9v"             @ volume 
.ascii "take me to your leader!"              
.ascii "\n\r"             @ CR, start speaking
MESSAGE_END:
.byte 0x0
.align 2                @ will mis-align without this (SIGBUS)
CHAR_PTR:        .word MESSAGE
CHAR_COUNT:      .word MESSAGE_LEN  @ Counter  for number of characters to send

.end
