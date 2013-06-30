These are the modified sources from recent qemu (at the time I am using: Mar-2013). I should have done a "diff" instead but whatever...( I am new to git ). Also I put the archive of this qemu version in the qemu_archive folder since there are lot of developments recently on qemu. 

BUILD QEMU
----------------------------------

To build this under Windows (a binary is provided in case you give up)
1. take a look at this first:
http://hpoussineau.free.fr/qemu/buildenv/HOWTO-_compile_Qemu_under_Windows_for_i386_and_x86_64_emulation_targets.pdf
and
http://wiki.qemu.org/Hosts/W32
2. get MinGW, then open MinGW terminal
3. Follow instruction in step 1 to get additional libraries, be patient, this step can be very daunting. General method is download the tar packet, unpack, ./configure, make then make install. Additional libraries used in my case: gettext, glib, libiconv, pixman, SDL, zlib
4. Assuming step 3 is done, follow instruction in step 1 to compile qemu. I use
(get the qemu archive first)
	cd qemu
	./configure --target-list="arm-softmmu" --prefix=/F/qemu_build
	make
	make install
Note: if some dependencies aren't met, make will fail. Repeat step 3 to resolve. 
5. The executable is qemu-system-arm.exe in "/F/qemu_build" folder ( if you use --prefix option )

For Linux (ubuntu) build:

1. install qemu build dependencies.
# apt-get build-dep qemu

This will install build dependencies for current version of qemu in debian so this might not be precisely what you need. However it should be quite simple to install new build dependencies or disable build options in configure to match what the qemu source you just downloaded. Configure and build a qemu arm system.
$ ./configure  --target-list=arm-softmmu
$ make
use --prefix option as windows example above if you want to relocate the binaries

RECENT CHANGES
----------------------------------
Okay, This section keeps track changes throughout versions

v1.0:
	- add button emulation
		First, I found the original spitz has a GPIO connected keypad. In spitz.c, ignore the first 7 rows of spitz_keymap, the 8th row specifies to the following "special" buttons:
		
		--- 
		#define SPITZ_GPIO_AK_INT	13	/* Remote control */
		#define SPITZ_GPIO_SYNC		16	/* Sync button */
		#define SPITZ_GPIO_ON_KEY	95	/* Power button */
		#define SPITZ_GPIO_SWA		97	/* Lid */
		#define SPITZ_GPIO_SWB		96	/* Tablet mode */
		
		// patch: add new gpio pin for button
		#define SPITZ_GPIO_MYBUTTON	73	/* our custom button (keycode 0x53) */
		
		#define BUTTON_NUM			6	
		
		// patch
		/* The special buttons are mapped to unused keys */
		static const int spitz_gpiomap[BUTTON_NUM] = {
			SPITZ_GPIO_AK_INT, SPITZ_GPIO_SYNC, SPITZ_GPIO_ON_KEY,
			SPITZ_GPIO_SWA, SPITZ_GPIO_SWB, SPITZ_GPIO_MYBUTTON,
		};
		
		typedef struct {
		...
			// patch: 6
			qemu_irq gpiomap[BUTTON_NUM];
		...
		} SpitzKeyboardState;
		---
		
		Which later registered here:
		
		---
		static void spitz_keyboard_register(PXA2xxState *cpu)
		{
			...
			for (i = 0; i < BUTTON_NUM; i ++)
				s->gpiomap[i] = qdev_get_gpio_in(cpu->gpio, spitz_gpiomap[i]);

			if (!graphic_rotate)
				s->gpiomap[4] = qemu_irq_invert(s->gpiomap[4]);

			for (i = 0; i < BUTTON_NUM; i++)
				qemu_set_irq(s->gpiomap[i], 0);
			...
			qemu_add_kbd_event_handler(spitz_keyboard_handler, s);
		}
		---
		
		That "seems" to be all it take for hooking up a new button to our machine.
		How can we simulate button action on the emulator? Qemu supports the "sendkey" command (via monitor) which can  trigger a series of event on the specific pin. In our case, the above 6 special buttons are mapped in the 8th row of spitz_keymap matrix:
		{ 0x52, 0x43, 0x01, 0x47, 0x49,  0x53 ,  -1 ,  -1 ,  -1 ,  -1 ,  -1  }
		I decided to take over pin 73 for my purpose, and give a corresponding key code of 0x53.
		There're a lot of magic in what happening during sendkey, but at the end of the chain, it appears that spitz_keyboard_handler() happens first at "keypress" event. This queues the key into a FIFO which is then periodically checked by a timer callback, spitz_keyboard_tick(), which then calls spitz_keyboard_keydown(). There is also a subsequent callback to spitz_keyboard_handler() due to keyrelease event (keycode in this event will be 0xd3 = 0x53 + 0x80).
		Our button event is recorded as follow:
		
		---
		static void spitz_keyboard_handler(void *opaque, int keycode)
		{
			SpitzKeyboardState *s = opaque;
			uint16_t code;
			int mapcode;
			
			switch (keycode) {
			// patch : our button responses on sendkey command during key press/release event
			case 0x53:	// button press
				ssb.button0 = 1;
				break;
			case 0xd3:	// button release
				ssb.button0 = 0;
				break;
			...
		}
		---
		Note that the ssb struct is part of qmp command implementation, please see https://github.com/qemu/qemu/blob/master/docs/writing-qmp-commands.txt
		
	- add LED emulation
		I again found original spitz emulates two LEDs (green and orange). Adding another LED should be done in very similar way. In spitz.c :
		
		---
		static void spitz_scoop_gpio_setup(PXA2xxState *cpu,
						DeviceState *scp0, DeviceState *scp1)
		{
			qemu_irq *outsignals = qemu_allocate_irqs(spitz_out_switch, cpu, 8);
			// patch: hook up "RED LED" to gpio 67
			qdev_connect_gpio_out(cpu->gpio, 67, outsignals[7]);
			...
		} 
		
		static void spitz_out_switch(void *opaque, int line, int level)
		{
			switch (line) {
			...
			case 7:  	// patch: detect "RED LED" on gpio 67
				printf("RED LED %s.\n", level ? "on" : "off");
				ssb.led0 = level;
				break;
			}
		}
		---
		
		Note that spitz_out_switch() is the callback that was specified in spitz_scoop_gpio_setup().
		
		In general, I think what makes these patches work are the following:
		
		---
		// button case (input). This registers the pin then returns a qemu_irq instance which can be chained to a callback
		qemu_irq qdev_get_gpio_in(DeviceState *dev, int n)
		{
			assert(n >= 0 && n < dev->num_gpio_in);
			return dev->gpio_in[n];
		}

		// led case (output). This registers the pin which requires a pre-allocated qemu_irq instance, previously chained to a callback
		void qdev_connect_gpio_out(DeviceState * dev, int n, qemu_irq pin)
		{
			assert(n >= 0 && n < dev->num_gpio_out);
			dev->gpio_out[n] = pin;
		}
		---	
	
	- add qmp "ssbinfo" command, see https://github.com/qemu/qemu/blob/master/docs/writing-qmp-commands.txt
		When "ssbinfo" cmd is submitted, the following functions will get called:
		
		---hmp.c
		void hmp_info_SSBInfo(Monitor *mon,const QDict *qdict)
		{
			SSBInfo *binfo;
			Error *errp = NULL;

			binfo = qmp_query_SSBInfo(&errp);
			if (error_is_set(&errp)) {
				monitor_printf(mon, "Could not query simple spitz board information\n");
				error_free(errp);
				return;
			}

			monitor_printf(mon, "led0:%d\n", (int)binfo->led0);
			monitor_printf(mon, "button0:%d\n", (int)binfo->button0);

			qapi_free_SSBInfo(binfo); 
		}
		---
		
		which invokes the following in spitz.c
		
		---spitz.c
		// patch
		static SSBInfo ssb = {0,0}; /* off state */
		
		// note: ssb.button0 set/reset via key press/release event handler
		SSBInfo * qmp_query_SSBInfo(Error **errp)
		{
			SSBInfo *binfo;	
			binfo = g_malloc0(sizeof(*binfo));
			
			binfo->led0 = ssb.led0;
			binfo->button0 = ssb.button0;
			return binfo;
		}
		---
		
	- spitz has rom at 0x0 but seems not has been remapped (to higher addr, so that ram can go to 0x0). This prevents copying irq vectors to 0x0 at Power On Reset. A simple hack is commenting out : "memory_region_set_readonly(rom, true);", and make it behave as ram.
	
	- boottraping process is as follow:
		Relevant codes:

			/pxa.h:# define PXA2XX_SDRAM_BASE	0xa0000000

			static struct arm_boot_info spitz_binfo = {
				.loader_start = PXA2XX_SDRAM_BASE,
				.ram_size = 0x04000000,
			};

		After necessary setup, emulator starts at ram base 0xa0000000. Below is disassembly of coressponding machine's memory 
			
			0xa0000000:  e3a00000      mov	r0, #0	; 0x0
			0xa0000004:  e59f1004      ldr	r1, [pc, #4]	; 0xa0000010
			0xa0000008:  e59f2004      ldr	r2, [pc, #4]	; 0xa0000014
			0xa000000c:  e59ff004      ldr	pc, [pc, #4]	; 0xa0000018
			0xa0000010:  000002c9      andeq	r0, r0, r9, asr #5 // board id
			0xa0000014:  a0000100      andge	r0, r0, r0, lsl #2 // kernel arguments
			0xa0000018:  a0010000      andge	r0, r1, r0         // kernel entry point

		This set up r0-r2 then jump to 0xa0010000 (kernel.img). kernel.img (built from bootldr.s) assembly code: 

			(0xa0010000)
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

			loop: b loop
			
		This sets up irq vectors at 0x0, then goes into an endless loop. Boot process is done here. 
		So what's now? Well, Qemu supports gdb mode, which means we can use a gdb client to connect to our machine, download code and debug. For example I use arm-elf-gdb with target setting as GDBserver/localhost/1234 to connect to qemu, then I could load my binary to whenever ram location (via a load script) and run/debug. Or, just add bootldr.c to your custom project as start-up code, then instead of doing loop code, jump to your main function. 
		For the first purpose, I made a python script that runs qemu in background, exchanges monitor messages (qmp query) then shows the result in its GUI. See SimpleSpitzEmulator.py


	
	

