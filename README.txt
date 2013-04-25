Patched qemu-system-arm that enables basic external parts (leds, switches) on "spitz" machine and provides info querying via qemu's monitor, plus a simple python graphic front end.
Copyright Dung Le 2013
----
- "arm" folder contains modified sources from the original qemu's
- bootloader: bootloader source, basicly set up interrupt vectors, execute a "blink" then loop forever
- blink, interrupt: example bare metal source for testing with the machine 
- SpitzEmulator: windows binary is provided (nice! very painful to build this under windows) and Python frontend (v2.7 tested)