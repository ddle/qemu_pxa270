#
# A Simple Spitz (Xscale pxa270) Emulator Graphic Front End, version 1.1
# Copyright Dung Le 2013, ddle@pdx.edu
#
# This script is the GUI for our customized qemu-system-arm emulator. It emulates "spitz" machine
# (PDA board based on PXA270). 
# 
# Currently the emulator adds:
# - button on GPIO 73, LED on GPIO 67
# - external UART (base addr: 0x1000_0000) with output interrupt on GPIO 10
# - info querying via qemu's monitor.
#
# Our script establishes two telnet connections with qemu: one with its monitor and one with its 
# virtual serial output.
# Led and switch actions are monitored using the custom hmp command "info ssbinfo", via qemu's monitor.
# In addition, switch action is simulated by the "sendkey" command. 
# See qemu/docs/writing-qmp-commands.txt for more info about monitoring commands.
#
# Interface:
# - Button: send button press event 
# - Halt: stop the machine
# - Resume: resume the machine
# - restart: kill and restart emulator
# - reset: currently NOT supported since qemu does not have clean reset yet
# - serial output display
#