
 A Simple Spitz (Xscale pxa270) Emulator GUI, Python 2.7

 This script works with a patched qemu-system-arm that enables basic external
 parts (leds, switches) on "spitz" machine and provides info querying via qemu's monitor.
 Led and switch actions are monitored using the custom hmp command "info ssbinfo", via 
 a telnet client on localhost connection with the emulating machine. In addition, pressing 
 switch event is simulated by the "sendkey" command. 
 See https://github.com/qemu/qemu/blob/master/docs/writing-qmp-commands.txt for more info about monitoring commands.

 Note: 
 - In current patch: switch: GPIO73 (sendkey's hex code: 0x53), Led: GPIO67
 - for Linux usage, beside python, get python-tk if you haven't got it.