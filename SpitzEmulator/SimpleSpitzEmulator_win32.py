#
# A Simple Spitz (Xscale pxa270) Emulator Graphic Front End, Python 2.7
#
# This script works with a patched qemu-system-arm that enables basic external
# parts (leds, switches) on "spitz" machine and provides info querying via qemu's monitor.
# Led and switch actions are monitored using the custom hmp command "info ssbinfo", via 
# a telnet client on localhost connection with the emulating machine. In addition, pressing 
# switch event is simulated by the "sendkey" command. 
# See qemu/docs/writing-qmp-commands.txt for more info about monitoring commands.
# In current patch: Key's hex code: 0x52, switch: GPIO13, Led: GPIO67
#
# Dung Le 2013, ddle@pdx.edu
#
from Tkinter import *
import threading, subprocess, time, telnetlib
try:
	from Queue import Queue, Empty
except ImportError:
	from queue import Queue, Empty  # python 3.x
	
# global variables to be shared among thread, 
t = None
tn_client = None
proc = None
done = False
stop = False
led_state = 0
button_state = 0
request_queue = Queue()
result_queue = Queue()
hmp_cmd_queue = Queue() 

HOST = "localhost"
PORT = "4321"
key = "0x52"

# must have "ipv4" (!) on windows env 
QEMU_CMD = "qemu-system-arm.exe -M spitz -kernel kernel.img -nographic -gdb tcp::1234,ipv4 -monitor telnet:" + HOST + ":" + PORT + ",server,nowait,ipv4"

# callback routines
def submit_to_tkinter(callable, *args, **kwargs):
	request_queue.put((callable, args, kwargs))
	return result_queue.get()
	
def button_cmd_callback(cmd):
	global hmp_cmd_queue
	try: 
		hmp_cmd_queue.put(cmd)
		#print cmd	
	except Exception,e:
		print e 	

def button_cmd_callback1():
	global tn_client,stop,restart
	try: 
		print "restart machine..."
		stop = True	
	except Exception,e:
		print e 
		
# main tkinter thread that runs graphic interface, uses a worker queue to handle
# board events (monitoring hmp output)
def tk_thread():
	global t,tn_client,stop,done, request_queue, result_queue
		
	def timertick():
		try:
			callable, args, kwargs = request_queue.get_nowait()
		except Empty:
			pass
		else:
			retval = callable(*args, **kwargs)
			result_queue.put(retval)
		t.after(300, timertick)

	t = Tk()
	t.title("Simple Spitz Emulator 1.0")
	t.configure(width=280, height=150)
	b0 = Button(text='Reset', name='button0', width=7, command = lambda:button_cmd_callback("\n")) #system_reset is unclean so currently not used
	b0.place(x=5, y=5)
	
	b2 = Button(text='Halt', name='button2',width=7, command = lambda:button_cmd_callback("stop\n"))
	b2.place(x=75, y=5)
	b3 = Button(text='Resume', name='button3',width=7, command = lambda:button_cmd_callback("cont\n"))
	b3.place(x=145, y=5)
	
	b4 = Button(text='Restart', name='button4',bg="CadetBlue",width=7, command = button_cmd_callback1)
	b4.place(x=215, y=5)
	
	b1 = Button(text='Button' ,width=12,height=2, name='button1',bg="WHITE", command = lambda:button_cmd_callback("sendkey " + key + "\n"))
	b1.place(x=25, y=60)
	#b.pack(side=BOTTOM,fill=BOTH)

	l0 = Button(text='led0',height=2, width=5, name='led0', state=DISABLED)
	l0.place(x=140, y=60)
	l1 = Button(text='led1',height=2, width=5, name='led1', state=DISABLED)
	l1.place(x=200, y=60)
	
	timertick()
	t.mainloop()	
	stop = True
	done = True
	#tn_client.write("q\n")
	
# serve request to change led states
def led_on(whichled):
	t.children[whichled].configure(bg="RED")
	
# serve request to change led states
def led_off(whichled):
	t.children[whichled].configure(bg="WHITE")	

def box_msg(msg):
	t.children["listbox0"].insert(END, msg)
	
# run shell command (child process)
def Run(command):
	try:
		pr = subprocess.Popen(command, shell=True,stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)	
		return pr
	except Exception,e:
		print e.args
		return None
		
# telnet client establishes connection with our emulator, this is our query channel 
#(led,button states) via hmp commands
def start_telnet_client():
	timeout = 10
	counter = 0
	interval = 1
	tn = None
	while (counter < timeout) and not done:
		try:
			tn = telnetlib.Telnet(HOST,PORT)			
			#tn.interact()
			read = tn.read_until("(qemu)",timeout)		
			print "telnet connected"
			tn.write("stop") # we 've let the machine's boot code run, can stop now to relax cpu 
			#print read		
			return tn
		except Exception,e:			
			print e.args
			time.sleep(interval)
			counter = counter + interval
			time.sleep(0.1)
	return None

# extract and submit state-change requests
def process_qemu_output(l):
	global led_state
	if l.find("button0:1") > 0:
		print 'button press '
	if l.find("gdb") > 0:
		print l	
	if l.find("led0:0") > 0 and led_state == 1:
		print 'led off '
		submit_to_tkinter(led_off, "led0") 
		led_state = 0
	elif l.find("led0:1") > 0 and led_state == 0:
		print 'led on '
		submit_to_tkinter(led_on, "led0")		
		led_state = 1
	else:
		pass
		#submit_to_tkinter(box_msg, l)
		
############################# main ################################
thread1 = threading.Thread(target=tk_thread) # tk graphic thread
thread1.start()

#main thread
while not done:
	print "start emulator"
	stop = False
	
	proc = Run(QEMU_CMD) # start qemu
	if proc.poll() is not None:
		print "emulator: failed"
		break
	time.sleep(1) # wait for qemu process
	tn_client = start_telnet_client()

	if tn_client is None:
		print "telnet: failed"
		break
		
	while not stop:
		try:
			tn_client.write("info ssbinfo\n") # query board info
			time.sleep(0.1)
			line = tn_client.read_very_eager() # read all available w/o blocking
			process_qemu_output(line)		
			cmd = hmp_cmd_queue.get_nowait() # none blocking, The Queue class implements all the required locking semantics
			tn_client.write(cmd) # execute cmd if any
		except Empty:
			pass	
		except Exception,e:
			print e.args		
		time.sleep(0.1)
		
	tn_client.write("q\n") # send exit code
	time.sleep(1) # wait for qemu process exiting
	if proc.poll() is None:	# force exit		
		print "kill emulator"
		#proc.kill()
		#proc.terminate()
		# kill process under windows:
		subprocess.Popen("taskkill /F /T /PID %i"%proc.pid , shell=True)
			
thread1.join()	
print "done"


