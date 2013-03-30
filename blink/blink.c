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


void main ( void )
{
	//1. must specify int* to determine the size of data transfering ( 4bytes ), vs (short*) ect. 
	//2. since we specify void pointer, gpio_base + GPDR0 "executed as usual", vs declate int*
	*(int*)(gpio_base + GPDR2) = *(int*)(gpio_base + GPDR2) | 0x8; // set to output

	*(int*)(gpio_base + GPSR2) = 0x8; // high

	*(int*)(gpio_base + GPCR2) = 0x8; // low

	while (1);
}
