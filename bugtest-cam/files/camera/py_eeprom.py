######################################
#BUG Module EEPROM Programming Script#
#
#FOR BUG 2.0!!
#by DaveR
#
#type help at the prompt for help
#or ask TheMammal if you have q's
######################################

import fcntl
import struct
import sys
import time
import datetime

I2C_SLAVE = 0X0703
EEP_I2C_ADDRESS = 0X50

#EEPROM settings stored in a dictionary
#Data Saved as Strings

#dictionary for index lookup
#tuple value: (index, bytes)
byte_index = {'format':0,'vendor_msb':1,'vendor_lsb':2,'product_msb':3,'product_lsb':4,'revision_msb':5,'revision_lsb':6,
                'bus_useage':7,'gpio_useage':8,'power_use':9,'power_charging':10,'memory_size_msb':11,'memory_size_lsb':12,
                'serial_num_loc':13,'serial_num_year':14,'serial_num_week':15,
                'serial_num_seq_msb':16,'serial_num_seq_mid':17,'serial_num_seq_lsb':18,'checksum':127}

#also useful
byte_order = ('format','vendor_msb','vendor_lsb','product_msb','product_lsb','revision_msb','revision_lsb',
                'bus_useage','gpio_useage','power_use','power_charging','memory_size_msb','memory_size_lsb',
                'serial_num_loc','serial_num_year','serial_num_week',
                'serial_num_seq_msb','serial_num_seq_mid','serial_num_seq_lsb','checksum')

#and raw lists to store mod data and local data
mod_raw = []
local_raw = []
for n in range (0, 128):
    mod_raw.append('0x00')
    local_raw.append('0x00')

#Validate string 8bit hex string and return value
def w_hexify8(input,dest):
    if (input.startswith('0x')):
        #Check for valid hex data
        try:
            value = int(input[2:],16)
        except ValueError:
            print "Error: invalid hex value"
            return -1

        if value > 0xFF:
        	print "Error: 8 bit max"
        	return -1
        else:
            input = input[2:].zfill(2)
            local_raw[byte_index[dest]] = '0x'+input
            checksum_gen(local_raw)
    else:
        print "Error: prefix 8 bit hex value with 0x"
        return -1

#Validate string 16bit hex string and return lsb, msb
def w_hexify16(input,dest):
    if (input.startswith('0x')):
        #Check for valid hex data
        try:
            value = int(input[2:],16)
        except ValueError:
            print "Error: invalid hex value"
            return -1

        if value > 0xFFFF:
        	print "Error: 16 bit max"
        	return -1
        else:
            input = input[2:].zfill(4)
            local_raw[byte_index[dest+'_lsb']] = '0x'+input[2:]
            local_raw[byte_index[dest+'_msb']] = '0x'+input[0:2]
            checksum_gen(local_raw)
    else:
        print "Error: prefix 16bit hex value with 0x"
        return -1

#Validate string 24bit hex string and return lsb, msb
def w_hexify24(input,dest):
    if (input.startswith('0x')):
        #Check for valid hex data
        try:
            value = int(input[2:],16)
        except ValueError:
            print "Error: invalid hex value"
            return -1

        if value > 0xFFFFFF:
        	print "Error: 24 bit max"
        	return -1
        else:
            input = input[2:].zfill(6)
            local_raw[byte_index[dest+'_lsb']] = '0x'+input[4:]
            local_raw[byte_index[dest+'_mid']] = '0x'+input[2:4]
            local_raw[byte_index[dest+'_msb']] = '0x'+input[0:2]
            checksum_gen(local_raw)
            return 0
    else:
        print "Error: prefix 24bit hex value with 0x"
        return -1

def read_eeprom(slot):
    node = '/dev/i2c-'+str(slot+4)
    print "Devnode %s" %node, "(slot %s) not found..." %slot
    try:
        i2c_dev = open(node,"r+b")
    except IOError:
        print "Devnode %s" %node, "(slot %s) not found..." %slot
        return -1

    try:
        fcntl.ioctl(i2c_dev, I2C_SLAVE, EEP_I2C_ADDRESS)
        #Read Data
        i2c_dev.write(struct.pack('B',0x00))            # initiate read (start at byte 0x00)
        i2c_dev.flush()
        raw = i2c_dev.read(128)                         # read all relevant data bytes
        for n in range(0, 128):
            mod_raw[n] = '0x'+hex(ord(raw[n]))[2:].zfill(2)
    except IOError:
        print "i2c error on slot %s" %slot
        i2c_dev.close
        return -1

    i2c_dev.close()
# will generate checksum for local_raw
def checksum_gen(data):
    sum = 0
    for n in range(0, 127):
        sum ^= int(data[n],16)
    data[127] = '0x'+hex(sum)[2:].zfill(2)

def write_eeprom():
    checksum_gen(local_raw)
    node = '/dev/i2c-'+str(slot+4)
    try:
        i2c_dev = open(node,"r+b")
    except IOError:
        print "Devnode %s" %node, "(slot %s) not found..." %slot
        return -1

    try:
        fcntl.ioctl(i2c_dev, I2C_SLAVE, EEP_I2C_ADDRESS)
        for i in range(0,128):
            i2c_dev.write(struct.pack('B',i))                             # byte to write
            i2c_dev.write(struct.pack('B',(int(local_raw[i],16))))          # data to write
            i2c_dev.flush()
            time.sleep(0.01)
    except IOError:
        print "i2c error on slot %s" %slot
        i2c_dev.close
        return -1

    i2c_dev.close

def display_eeprom():
    if read_eeprom(slot) == -1:
        print "###################################################"
        print "###############   I2C READ FAILED   ###############"
        print "###################################################"
    print 'ENTRY                  Module Value     Local Value'
    for i in byte_order:
        #concatenate multiple byte entries
        if i.endswith('_msb'):
            m_msb = mod_raw[byte_index[i]]
            l_msb = local_raw[byte_index[i]]
        elif i.endswith('_mid'):
            m_mid = mod_raw[byte_index[i]]
            l_mid = local_raw[byte_index[i]]
        elif i.endswith('_lsb'):
            mod_data= m_msb+m_mid[2:]+mod_raw[byte_index[i]][2:]
            local_data = l_msb+l_mid[2:]+local_raw[byte_index[i]][2:]
            entry = i[:-4]
            prnt = 1
        else:
            mod_data = mod_raw[byte_index[i]]
            local_data = local_raw[byte_index[i]]
            entry = i
            prnt = 1

        if prnt == 1:
            print entry, '.'*(25-(len(entry))), mod_data, '.'*(15-(len(mod_data))), local_data
            m_mid = ''; m_msb = ''; l_mid = ''; l_msb = '';
            prnt = 0

def copy_data():
    read_eeprom(slot)
    for i in range (0, len(local_raw)):
        local_raw[i] = mod_raw[i]
    set_time()
    checksum_gen(local_raw)

def set_time():
    local_raw[byte_index['serial_num_week']] = '0x'+(hex(int((datetime.date.today().strftime("%W")))))[2:].zfill(2)
    local_raw[byte_index['serial_num_year']] = '0x'+(hex(int((datetime.date.today().strftime("%Y"))[2:])))[2:].zfill(2)
    checksum_gen(local_raw)

def batch_process():

    state = 1
    print "###################"
    print "## Batch Process ##"
    print "###################"
    print
    print "enter 'exit' to quit"
    print

    while state == 1:
        print "Enter starting serial number (hex)"
        cmd = raw_input("~~>")
        cmd = cmd.split()
        if len(cmd) == 0:
            cmd = ' '
        if len(cmd) == 1 & cmd[0].startswith('0x'):
            if (w_hexify24(cmd[0],'serial_num_seq')) == 0:
                state = 2
            else:
                state = 1
        elif cmd[0] == 'exit':
            print '...leaving batch processing'
            state = 0
        #ignore empty command
        elif cmd[0] == ' ':
            pass
        else:
            print '^ enter 24 bit hex prefixed by 0x ^'
        print

    print '### Local EEPROM data will be written: ###'
    print
    display_eeprom()
    print

    while state == 2:
        current_sn = local_raw[byte_index['serial_num_seq_msb']]+local_raw[byte_index['serial_num_seq_mid']][2:]+local_raw[byte_index['serial_num_seq_lsb']][2:]
        print 'Current Serial Number:', current_sn
        print "enter 'p' to program module"
        cmd = raw_input('~~>')
        cmd = cmd.split()

        if len(cmd) == 0:
            cmd = ' '
        if cmd[0] == 'exit':
            print '...leaving batch processing'
            print
            state = 0
        elif cmd[0] == 'p':
            write_eeprom()
            current_sn = hex(int(current_sn,16)+1)
            w_hexify24(current_sn,'serial_num_seq')
            display_eeprom()
        elif cmd[0] == ' ':
            pass
        else:
            print '^ invalid input ^'
            print "enter 'exit' to leave batch mode"
        print

def help():
    print "####################"
    print "## Valid Commands ##"
    print "####################"
    print
    print "The following commands can be used to set any of the Bug Module EEPROM values"
    print "A list of EEPROM values can be seen by entering 'display' from the main prompt (-->)"
    print
    for i in byte_order:
        print "set %s [hex value]" %i
    print
    print "The following commands van be used to manipulate and display EEPROM values"
    print
    print "slot      -  change slot"
    print "read      -  read eeprom from module"
    print "write     -  write locally stored eeprom data to module"
    print "display   -  display eeprom data on module as well as locally stored data"
    print "             note: display issues a 'read' command every time it is called"
    print "copy      -  copies eeprom data stored on module to local data"
    print "batch     -  invokes batch processing (prompt: ~~>)"
    print "             batch processing allows consecutive writes to be performed conviniently"
    print "             note: the serial number value is incremented after every write"
    print "help      -  that's how you got here"
    print
    return

def whatslot():
    print
    slot = -1
    while (slot == -1):
        slot = raw_input("Program EEPROM on Slot: ")
        if ((slot == '0') | (slot == '1') | (slot == '2') | (slot == '3')):
            slot = int(slot)
        elif (slot == 'quit'):
            sys.exit()
        elif (slot == 'help'):
            help()
            slot = -1
        else:
            print 'invalid slot number'
            slot = -1
    return slot

#Main Loop
slot = whatslot()
print
print "For a summary of valid commands type 'help'"
print
set_time()
while 1:
    cmd = raw_input("-->")
    cmd = cmd.split()
    #Handle blank return
    if len(cmd) == 0:
        cmd = ' '
    #SET commands
    if cmd[0] == 'set':
        #Check for extra/missing args
        if len(cmd) != 3:
        	print '^ Syntax Error ^'
        #Appropriate number of args
        else:
            if (cmd[1]+'_lsb' in byte_order) & (cmd[1]+'_mid' in byte_order) & (cmd[1]+'_msb' in byte_order):
                w_hexify24(cmd[2],cmd[1])
            elif (cmd[1]+'_lsb' in byte_order) & (cmd[1]+'_msb' in byte_order):
                w_hexify16(cmd[2],cmd[1])
            elif (cmd[1]):
                w_hexify8(cmd[2],cmd[1])
            #EXCEPTION
            else:
                print '^ Invalid Arg ^'
    #SLOT command
    elif cmd[0] == 'slot':
        if len(cmd) != 1:
            print '^ Syntax Error ^'
        else:
            slot = whatslot()
    #READ command
    elif cmd[0] == 'read':
        if len(cmd) != 1:
            print '^ Syntax Error ^'
        else:
            print "use display instead.. it calls read for you"
            read_eeprom(slot)
    #WRITE command
    elif cmd[0] == 'write':
        if len(cmd) != 1:
            print '^ Syntax Error ^'
        else:
            set_time()
            write_eeprom()
    #DISPLAY command
    elif cmd[0] == 'display':
        if len(cmd) != 1:
            print '^ Syntax Error ^'
        else:
            display_eeprom()
    #COPY command
    elif cmd[0] == 'copy':
        if len(cmd) != 1:
            print '^ Syntax Error ^'
        else:
            copy_data()
    #BATCH command
    elif cmd[0] == 'batch':
        if len(cmd) != 1:
            print '^ Syntax Error ^'
        else:
            batch_process()
    #HELP command
    elif cmd[0] == 'help':
        if len(cmd) != 1:
            print '^ Syntax Error; try entering "help" ^'
        else:
            help()
    #QUIT command
    elif cmd[0] == 'quit':
        if len(cmd) != 1:
            print '^ Syntax Error; try entering "help" ^'
        else:
            sys.exit()
    #Ignore empty string
    elif cmd[0] == ' ':
        pass
    #Unrecognized command
    else:
        print '^ invalid command ^'
