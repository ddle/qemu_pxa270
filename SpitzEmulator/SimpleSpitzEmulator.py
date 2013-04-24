from Tkinter import *
import threading, subprocess, time, telnetlib
try:
	from Queue import Queue, Empty
except ImportError:
	from queue import Queue, Empty  # python 3.x

t = None
tn_client = None
proc = None
done = False
stop = False
led_state = 0
button_state = 0
HOST = "localhost"
PORT = "4321"
key = "0x52"
#QEMU_CMD = "qemu-system-arm -M spitz -kernel kernel.img -nographic -s -S -monitor tcp:"+ HOST + ":" + PORT + ",server,nowait"
#QEMU_CMD = "qemu-system-arm -M spitz -kernel kernel.img -nographic -s -S -monitor telnet:"+ HOST + ":" + PORT + ",server,nowait"
QEMU_CMD = "qemu-system-arm.exe -M spitz -kernel kernel.img -nographic -s -monitor telnet:localhost:" + PORT + ",ipv4,server,nowait"
#QEMU_CMD = "qemu-system-arm.exe -M spitz -kernel kernel.img -nographic -s -chardev socket,id=qmp,port=4321,host=localhost,server -mon chardev=,mode=control,pretty=on"

#-nographic -s -S -gdb tcp::1234,ipv4
request_queue = Queue()
result_queue = Queue()
output_queue = Queue()
hmp_cmd_queue = Queue()

def submit_to_tkinter(callable, *args, **kwargs):
	request_queue.put((callable, args, kwargs))
	return result_queue.get()
	
def button_cmd_callback(cmd):
	global hmp_cmd_queue
	try: 
		#tn_client.write(cmd)	
		hmp_cmd_queue.put(cmd)
		print cmd	
	except Exception,e:
		print e 	


def button_cmd_callback1():
	global tn_client,stop,restart
	try: 
		#tn_client.write("quit\n")	
		stop = True	
		#print cmd	
	except Exception,e:
		print e 
		
# main tkinter thread that runs graphic interface, uses a worker queue to handle
# board events (when monitoring emulator output)
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
		t.after(500, timertick)

	t = Tk()
	t.title("Simple Spitz Emulator")
	t.configure(width=280, height=150)
	#b = tk.Button(text='Power Off', name='button0', command = lambda:button0_callback(tn_client))
	#b0 = Button(text='Reset', name='button0',bg="CadetBlue", width=4, command = button0_callback)
	b0 = Button(text='Reset', name='button0', width=4, command = lambda:button_cmd_callback("\n")) #system_reset, unclean
	b0.place(x=5, y=5)
	
	b2 = Button(text='Halt', name='button2',width=4, command = lambda:button_cmd_callback("stop\n"))
	b2.place(x=75, y=5)
	b3 = Button(text='Resume', name='button3',width=4, command = lambda:button_cmd_callback("cont\n"))
	b3.place(x=145, y=5)
	
	b4 = Button(text='Restart', name='button4',bg="CadetBlue",width=4, command = button_cmd_callback1)
	b4.place(x=215, y=5)
	
	#b.pack(side=BOTTOM,fill=BOTH)
	b1 = Button(text='Button' ,width=12,height=2, name='button1',bg="WHITE", command = lambda:button_cmd_callback("sendkey " + key + "\n"))
	b1.place(x=5, y=60)
	#b.pack(side=BOTTOM,fill=BOTH)

	l0 = Button(text='led0',height=2, width=3, name='led0', state=DISABLED)
	l0.place(x=140, y=60)
	l1 = Button(text='led1',height=2, width=3, name='led1', state=DISABLED)
	l1.place(x=200, y=60)
	
	timertick()
	t.mainloop()	
	stop = True
	done = True
	tn_client.write("q\n")

def led_on(whichled):
	t.children[whichled].configure(bg="RED")
	
def led_off(whichled):
	t.children[whichled].configure(bg="WHITE")	
	
def get_button_text():
	return t.children["button0"]["text"]

def box_msg(msg):
	t.children["listbox0"].insert(END, msg)
	
# run qemu process
def Run(command):
	try:
		proc = subprocess.Popen(command, shell=True,stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)	
		return proc
	except Exception,e:
		print e.args
		return None
	
# telnet client establishes connection with our emulator
def start_telnet_client():
	timeout = 10
	counter = 0
	interval = 1
	tn = None
	while (counter < timeout) and not done:
		try:
			tn = telnetlib.Telnet("localhost",PORT)			
			#tn.interact()
			read = tn.read_until("(qemu)",timeout)		
			print "telnet connected"
			print read		
			return tn
		except Exception,e:			
			print e.args
			time.sleep(interval)
			counter = counter + interval
			time.sleep(0.1)
	return None

def process_qemu_output(l):
	global led_state
	if l.find("button0:1") > 0:
		print 'button press '
	if l.find("led0:0") > 0 and led_state == 1:
		print 'led off '
		submit_to_tkinter(led_off, "led0")
		led_state = 0
	elif l.find("led0:1") > 0 and led_state == 0:
		print 'led on '
		submit_to_tkinter(led_on, "led0")		
		led_state = 1
		#time.sleep(3)
	elif l == "":	
		pass
	else:
		pass
		#print "some" , l		
		#submit_to_tkinter(box_msg, l)
		
def enqueue_output(p, queue):
	global tn_client
	fo =open("stdout.txt","r")	
	
	#for line in iter(p.stdout.readline, b''):
	while p.poll() is None:
		try	:
			pass
			#queue.put(p.stdout.readline())
			#queue.put(fo.readline())
			#read = tn_client.read_very_eager()
			#queue.put(read)
			#print read
		except Exception,e:
			print e
		time.sleep(0.1)
	#p.stdout.close()
	fo = open('stdout.txt', 'r+')
	fo.truncate()
	fo.close()
	print "thread 3 done"
###################### main #########################
thread1 = threading.Thread(target=tk_thread)
thread1.start()

while not done:
	print "start emulator"
	stop = False
	
	proc = Run(QEMU_CMD)
	if proc.poll() is not None:
		print "emulator: failed"
		break
	
	tn_client = start_telnet_client()	

	thread3 = threading.Thread(target=enqueue_output, args=(proc, output_queue))
	thread3.daemon = True # thread dies with the program
	thread3.start()
	
	if tn_client is None:
		print "telnet: failed"
		break
	line = ""	
	while not stop:
		try:
			#line = output_queue.get_nowait() # none blocking
			process_qemu_output(line)		
			#print "line" , line
		except Empty:
			pass
		try:
			cmd = hmp_cmd_queue.get_nowait() # none blocking
			print cmd
			tn_client.write(cmd)
		except Empty:
			pass	
		tn_client.write("info ssbinfo\n")
		line = tn_client.read_very_eager()
		#output_queue.put(read)
		#print line
		time.sleep(0.1)
			
	if proc.poll() is None:
		tn_client.write("q\n")
		tn_client.close()
		print "kill emulator"
		#proc.kill()
		#proc.terminate()
		subprocess.Popen("taskkill /F /T /PID %i"%proc.pid , shell=True)

open('stdout.txt', 'w').close()
			
	
thread1.join()	

print "done"


