Patched qemu-system-arm that enables basic external parts (leds, switches) on "spitz" machine and provides info querying via qemu's monitor, plus a simple python graphic front end.
Copyright Dung Le 2013
----
- "arm" folder contains modified sources from the original qemu's
- bootloader: bootloader source, basicly set up interrupt vectors, execute a blink then loop forever
- SpitzEmulator: windows binary of qemu (win7 tested) + Python frontend (v2.7 tested). For Linux (ubuntu in my case), please follow build instruction in arm folder
- qemu_archive: archive of qemu version that was built for this project. Qemu is currently under heavily development (May 2013)