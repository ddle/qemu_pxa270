#define GPLR0 0x0

#define GPDR0 0x0C
#define GPDR1 0x10
#define GPDR2 0x14
#define GPDR3 0x10C

#define GPSR0 0x18
#define GPSR1 0x1C
#define GPSR2 0x20
#define GPSR3 0x118

#define GPCR0 0x24
#define GPCR1 0x28
#define GPCR2 0x2C
#define GPCR3 0x124


#define GRER2 0x38
#define GEDR2 0x50

#define ICMR  0x40D00004
#define ICIP  0x40D00000


// pointer arithmetic requires divided by pointer's size
// #define I2C_C   *(gI2cMap + BSC0_C_OFFSET / sizeof(uint32_t))

// use void to avoid this confusion
static volatile void * gpio_base = 0x40E00000;

/*
extern void PUT32 ( unsigned int, unsigned int );
extern unsigned int GET32 ( unsigned int );
extern void dummy ( unsigned int );


@====================initialize GPIO========================================

@ make it output
LDR R1, =GPDR2		@ get GPDR2 address to R1
LDR	R6, [R1]	@ read GPDR2 current value
ORR	R6, R6, #0x08	@ set bit 3 to program GPIO <67> as output
STR	R6, [R1]	@ write word back to GPDR0

LDR R3, =GPCR2		@ get GPCR0 address to R3
LDR R4, =0x08		@ load word to turn off LED
STR R4, [R3]		@ write R4 to GPCR0

NOP

LDR R3, =GPSR2		@ get GPCR0 address to R3
LDR R4, =0x08		@ load word to turn off LED
STR R4, [R3]		@ write R4 to GPCR0
@===========================================================================
*/
void main ( void )
{
	//unsigned int* gpdr0 = GPDR0;
	//*GPDR0 = 0xFFFFFFFF;
	//*(gpio_base + GPDR0) = 0xFFFFFFFF;
	//1. must specify int* to determine the size of data transfering ( 4bytes ), vs (short*) ect. 
	//2. since we specify void pointer, gpio_base + GPDR0 "executed as usual", vs declate int*


//	*(int*)(gpio_base + GPDR3) = 0xFFFFFFFF; // set all to output
	*(int*)(gpio_base + GPDR2) = *(int*)(gpio_base + GPDR2) | 0x8; // set to output
//	*(int*)(gpio_base + GPSR3) = 0xFFFFFFFF; // set all to 1
	*(int*)(gpio_base + GPSR2) = 0x8; // high
//	*(int*)(gpio_base + GPCR3) = 0xFFFFFFFF; // set all to 1
	*(int*)(gpio_base + GPCR2) = 0x8; // low
/*
    unsigned int ra;

    ra=GET32(GPFSEL1);
    ra&=~(7<<18);
    ra|=1<<18;
    PUT32(GPFSEL1,ra);
	
    while(1)
    {
        PUT32(GPSET0,1<<16);
        for(ra=0;ra<0x10000;ra++) dummy(ra);
        PUT32(GPCLR0,1<<16);
        for(ra=0;ra<0x10000;ra++) dummy(ra);
    }
*/
//	return 0;
	while (1);
}
