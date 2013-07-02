#
# A Simple Spitz (Xscale pxa270) Emulator Graphic Front End, version 1.1
# Copyright Dung Le 2013, ddle@pdx.edu
#
# This script is the GUI for our customized qemu-system-arm emulator, emulating the "spitz"
# machine (PDA board based on PXA270). 
# 
# Currently the emulator has:
# - button on GPIO 73, LED on GPIO 67
# - external UART (base addr: 0x1000_0000) with output interrupt on GPIO 10
# - info querying via qemu's monitor.
#
# Our script establishes two telnet connections with qemu: one with monitor and one with 
# virtual serial output.
# Led and switch actions are handled via the custom qmp command "info ssbinfo" in qemu's
# monitor. In addition, switch action is simulated by the "sendkey" command. 
# See qemu/docs/writing-qmp-commands.txt for more info about qmp commands.
#
# Interface:
# - Button: send button press event 
# - Halt: stop the machine
# - Resume: resume the machine
# - restart: kill and restart emulator
# - reset: currently NOT supported since qemu does not have clean reset yet
# - serial output display
#
# NOTE: this script should be in the same folder with the qemu binary when executing