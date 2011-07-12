#!/bin/sh

echo "*************************"
echo "**CAMERA PIM Test Suite**"
echo "*************************"

echo "Tests being carried out:"
echo "========================"
echo
echo "On Camera PIM-"
echo "--------------"
echo "Camera, I2C EEPROM"
# fix for running from rcS
export PATH=/usr/tests:/usr/bin:/bin:/sbin:/usr/sbin

# vars are stored in file on mmc
# mount, grab the vars and get back out
mount -t vfat /dev/mmcblk0p1 /mnt/mmc1
source /mnt/mmc1/testvars
umount /mnt/mmc1

scan_retry=0
mcbsp_count=0
RETRYMAX=3

prompt()
{
	tvar=L
	while [ "$tvar" != "y" ] &&
	        [ "$tvar" != "Y" ] &&
	        [ "$tvar" != "n" ] &&
	        [ "$tvar" != "N" ] &&
	        [ "$tvar" != "r" ] &&
	        [ "$tvar" != "R" ]; do

	        read -n1 tvar

	done
	export $1=$tvar
}

pim_en()
{
	if [ $1 -eq "2" ];then
		return
	fi
	echo $1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/pim_power
	echo $1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/pim_init
	sleep 2
	echo $1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/pim_sw  
	return
}

pim_dis()
{
	if [ $1 -eq "2" ];then
		return
	fi
	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/pim_sw
	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/pim_power
	return
}

cam()
{
#	cd /mnt/mmc1
#	file_capture
#	mv image.dat image$1.dat
#	cd -
	/usr/tests/setimg 1 UYVY 320 240 > /dev/null
	/usr/tests/camera_fb
	return $?
}

i2c_eep_w()
{
	echo
	echo "-----I2C EEPROM Write TEST-----"
	echo
	echo "writing data -- i2ctest"
	i2c_eeprom_write 0000 "i2ctest"
	return
}

i2c_eep_r()
{
	echo 
	echo "-----I2C EEPROM Read TEST------"
	echo 
	i2c_eeprom_read 0000 07
	i2c_eeprom_read 0000 07| grep i2ctest
	return $?
}

spi_eep_w()
{
	echo
	echo "-----SPI EEPROM Write TEST-----"
	echo 
	echo "writing data -- "spitest""	
	spi_eeprom_write $1 0000 "spitest"
	return
}

spi_eep_r()
{
	echo 
	echo "-----SPI EEPROM Read TEST------"
	echo 
	spi_eeprom_read $1 0000 07
	spi_eeprom_read $1 0000 07 | grep spitest
	return $?
}
uart()
{
	echo 
	echo "----UART TESTS----"
	echo
	if [ "$1" == "3" ];then
		echo "UART 1 test running at 9600 baud"
		uart1 9600 8 0 0 4
	else
		spi_uart $1
	fi
	if [ $? == "0" ];then
		echo "PIM$1 UART Tests passed" >> /home/testlog.txt
	else
		echo "PIM$1 UART Tests failed" >> /home/testlog.txt
	fi
	return
}

mcbsp()
{
	echo
	echo "----McBSP test----"
	echo
	echo "The Test writes 1-127 in the write buffer and reads the same"
	echo
	echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/mcbsp_en
	sleep 2
	echo $1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/mcbsp_test
	return
}

usb_base()
{
	echo 
	echo "----USB TESTS----"
	echo
	umount /mnt/usb$1
	ls /dev/sda1
	if [ $? -eq "1" ];then
		echo "Please ensure that the USB device is inserted properly!!!"
		echo "USB Test Failed" >> /home/testlog.txt
		return
	else
		echo "####USB device enumerated####"
		mount -t vfat /dev/sda1 /mnt/usb$1
		if [ $? -gt "0" ];then
			echo "Mounting failed"
			return
		fi
		echo "[--usb_test--]#"
		echo "++++STARTING FILE TRANSFER TESTS++++"
		echo "CLEARING CACHE-->"
		echo Dropping VM Caches
		echo 3 > /proc/sys/vm/drop_caches
		echo "[--usb_test--]# ls -l /mnt/usb$1"
		ls -l /mnt/usb$1
		echo "[--usb_test--]# dd if=/dev/zero of=/mnt/usb$1/usb$1_file bs=1M count=10"
		dd if=/dev/zero of=/mnt/usb$1/usb$1_file bs=1M count=10
		echo "[--usb_test--]# cp /mnt/usb$1/usb$1_file /home/usb$1_file"
		cp /mnt/usb$1/usb$1_file /home/usb$1_file
		echo "[--usb_test--]# ls -l /mnt/usb$1"
		ls -l /mnt/usb$1
		echo "[--usb_test--]# ls -l /home/"
		ls -l /home/
	fi
	cmp /mnt/usb$1/usb$1_file /home/usb$1_file
	if [ $? -eq "1" ];then
		echo "Compare Failed"
		echo "Base USB test failed" >> /home/testlog.txt
		umount /mnt/usb$1/
		rm /home/usb$1_file
		echo Dropping VM Caches
		echo 3 > /proc/sys/vm/drop_caches
		return
	else
		echo "Compare Passed"
		echo "Base USB test passed" >> /home/testlog.txt
	fi
	umount /mnt/usb$1/
	rm /home/usb$1_file
		echo Dropping VM Caches
	echo 3 > /proc/sys/vm/drop_caches
	return
}

usb_pim()
{
	echo 
	echo "----USB TESTS----"
	echo
	umount /mnt/usb$1
	ls /dev/sdb1
	if [ $? -eq "1" ];then
		echo "Please ensure that the USB device is inserted properly!!!"
		echo "PIM$1 USB Test Failed" >> /home/testlog.txt
		return
	else
		echo "####USB device enumerated####"
		mount -t vfat /dev/sdb1 /mnt/usb$1
		if [ $? -gt "0" ];then
			echo "Mounting failed"
			return
		fi
		echo "[--usb_test--]#"
		echo "++++STARTING FILE TRANSFER TESTS++++"
		echo "CLEARING CACHE-->"
		echo 3 > /proc/sys/vm/drop_caches
		echo "[--usb_test--]# ls -l /mnt/usb$1"
		ls -l /mnt/usb$1
		echo "[--usb_test--]# dd if=/dev/zero of=/mnt/usb$1/usb$1_file bs=1M count=10"
		dd if=/dev/zero of=/mnt/usb$1/usb$1_file bs=1M count=10
		echo "[--usb_test--]# cp /mnt/usb$1/usb$1_file /home/usb$1_file"
		cp /mnt/usb$1/usb$1_file /home/usb$1_file
		echo "[--usb_test--]# ls -l /mnt/usb$1"
		ls -l /mnt/usb$1
		echo "[--usb_test--]# ls -l /home/"
		ls -l /home/
	fi
	cmp /mnt/usb$1/usb$1_file /home/usb$1_file
	if [ $? -eq "1" ];then
		echo "Compare Failed"
		echo "PIM$1 USB test failed" >> /home/testlog.txt
		umount /mnt/usb$1/
		rm /home/usb$1_file
		echo Dropping VM Caches
		echo 3 > /proc/sys/vm/drop_caches
		return
	else
		echo "Compare Passed"
		echo "PIM$1 USB test passed" >> /home/testlog.txt
	fi
	umount /mnt/usb$1/
	rm /home/usb$1_file
		echo Dropping VM Caches
	echo 3 > /proc/sys/vm/drop_caches
	return
}


quit_fn()
{
	pim_dis $1
	echo "###CTRL + C pressed###"
	exit 1
}

check_pim()
{
	pim_inserted=`cat /sys/bus/spi/drivers/SC16IS762/spi1.0/pim_plugged`
	val4=$(( $pim_inserted & 8 ))
	val3=$(( $pim_inserted & 4 ))
	val2=$(( $pim_inserted & 2 ))
	val1=$(( $pim_inserted & 1 ))
	
	
	if [ $val4 = "8" ];then
		if [ $1 = "4" ];then
			allowed=$(( $allowed + 1 ))
		else 
			allowed=$(( $allowed ))
		fi
	fi
	if [ $val3 = "4" ];then
		if [ $1 = "3" ];then
			allowed=$(( $allowed + 1 ))
		else 
			allowed=$(( $allowed ))
		fi
	fi
	if [ $val2 = "2" ];then
		if [ $1 = "2" ];then
			allowed=$(( $allowed + 1 ))
		else 
			allowed=$(( $allowed ))
		fi
	fi
	if [ $val1 = "1" ];then
		if [ $1 = "1" ];then
			allowed=$(( $allowed + 1 ))
		else 
			allowed=$(( $allowed ))
		fi
	fi
	
	if [ $allowed = "1" ];then
		echo "Check Passed!!"
		allowed=0
	else
		echo "PIM$1 is not plugged in !!"
		return 1
	fi
}

acc()
{
	cat /sys/class/i2c-adapter/i2c-3/3-0017/readings
}

lcd_bkl_vary()
{
	echo "The brightness of LCD will vary from 100 to 0"
	sleep 2
	bright=100
	while [ $bright -gt 0 ]
	do
		echo $bright > /sys/class/backlight/omap-backlight/brightness
		bright=$(( $bright - 1 ))
	done
	echo "The brightness of LCD will vary from 0 to 100"
	sleep 2
	while [ $bright -lt 100 ]
	do
		echo $bright > /sys/class/backlight/omap-backlight/brightness
		bright=$(( $bright + 1 ))
	done
	sleep 2
}


pim()
{

	echo "Checking if PIM$1 is plugged in"
	check_pim $1
	if [ $? = "1" ];then
		return
	fi
	echo "Enabling PIM$1"
	pim_en $1
	trap quit_fn 2

	sleep 7
	echo
	echo
	echo "" >> /home/testlog.txt
	echo "CAMERA PIM $1 TESTS" >> /home/testlog.txt
	echo "==================" >> /home/testlog.txt
	echo "------------------------"
	echo "+---CAMERA PIM $1 Tests---+"
	echo "------------------------"
	echo

	echo
	echo "Starting I2C EEPROM Read/Write Test"
	echo
	i2c_eep_w $1
	echo
	i2c_eep_r $1

	if [ "$?" == "0" ];then
		echo PIM$1 I2C EEPROM Read/Write Test Passed
		echo PIM$1 I2C EEPROM Read/Write Test Passed >> /home/testlog.txt
	else
		echo PIM$1 I2C EEPROM Read/Write Test Failed
		echo PIM$1 I2C EEPROM Read/Write Test Failed >> /home/testlog.txt
	fi

	echo
	echo "Starting Camera Capture Test"
	echo
	cam $1
	if [ "$?" == "0" ];then
		echo Test Passed
		echo PIM$1 Camera Test Passed >> /home/testlog.txt
	else
		echo Test Failed
		echo PIM$1 Camera Test Failed >> /home/testlog.txt
	fi

	echo "Done!"
	echo "Disabling PIM $1"
	pim_dis $1
	return 0
}

audio()
{
	echo
	echo "----Audio TESTS----"
	echo
	audio_sc > /dev/null
	aplay /usr/tests/track01.wav
	if [ $? -eq "1" ];then
		echo "Audio test failed"
	fi
}

sys_sd()
{
	echo 
	echo "----System SD TESTS----"
	echo
	ls /dev/mmcblk0p1
	if [ $? -eq "1" ];then
		echo "Please ensure that the System SD is inserted properly in the System SD slot!!!"
		return
	else
		umount /dev/mmcblk0p1
		echo "System SD Unmounted"
		echo
		mount -t vfat /dev/mmcblk0p1 /mnt/mmc1
		if [ $? -gt "0" ];then
			echo "Mounting failed"
			return
		else 
			echo "System SD mounted"
			echo
		fi
		echo "[--$0--]#"
		echo "++++STARTING FILE TRANSFER TESTS++++"
		echo "CLEARING CACHE-->"
		echo 3 > /proc/sys/vm/drop_caches
		echo "[--$0--]# ls -l /mnt/mmc1"
		ls -l /mnt/mmc1
		echo "[--$0--]# dd if=/dev/zero of=/mnt/mmc1/mmc1_file bs=1M count=10"
		dd if=/dev/zero of=/mnt/mmc1/mmc1_file bs=1M count=10
		echo "[--$0--]# cp /mnt/mmc1/mmc1_file /home/mmc1_file"
		cp /mnt/mmc1/mmc1_file /home/mmc1_file
		echo "[--$0--]# ls -l /mnt/mmc1"
		ls -l /mnt/mmc1
		echo "[--$0--]# ls -l /home/"
		ls -l /home/

	fi
	cmp /mnt/mmc1/mmc1_file /home/mmc1_file
	if [ $? -eq "1" ];then
		echo "Compare Failed"
		echo "System SD test failed" >> /home/testlog.txt
		umount /mnt/mmc1/
		mount -t vfat /dev/mmcblk0p1 /mnt/mmc1
		rm /home/mmc1_file
		echo Dropping VM Caches
		echo 3 > /proc/sys/vm/drop_caches
		return
	else
		echo "Compare Passed"
		echo "System SD test passed" >> /home/testlog.txt
	fi
	umount /mnt/mmc1/
	mount -t vfat /dev/mmcblk0p1 /mnt/mmc1
	rm /home/mmc1_file
		echo Dropping VM Caches
	echo 3 > /proc/sys/vm/drop_caches
	return
}

user_sd()
{
	echo 
	echo "----USER SD TESTS----"
	echo
	ls /dev/mmcblk1p1
	if [ $? -eq "1" ];then
		echo "Please ensure that the SD card is inserted properly in the USER SD slot!!!"
		return
	else
		umount /dev/mmcblk1p1
		echo "USER SD Unmounted"
		echo
		mount -t vfat /dev/mmcblk1p1 /mnt/mmc2
		if [ $? -gt "0" ];then
			echo "Mounting failed"
			return
		else 
			echo "USER SD mounted"
			echo
		fi
		echo "[--$0--]#"
		echo "++++STARTING FILE TRANSFER TESTS++++"
		echo "CLEARING CACHE-->"
		echo 3 > /proc/sys/vm/drop_caches
		echo "[--$0--]# ls -l /mnt/mmc2"
		ls -l /mnt/mmc2
		echo "[--$0--]# dd if=/dev/zero of=/mnt/mmc2/mmc2_file bs=1M count=10"
		dd if=/dev/zero of=/mnt/mmc2/mmc2_file bs=1M count=10
		echo "[--$0--]# cp /mnt/mmc2/mmc2_file /home/mmc2_file"
		cp /mnt/mmc2/mmc2_file /home/mmc2_file
		echo "[--$0--]# ls -l /mnt/mmc2"
		ls -l /mnt/mmc2
		echo "[--$0--]# ls -l /home/"
		ls -l /home/

	fi
	cmp /mnt/mmc2/mmc2_file /home/mmc2_file
	if [ $? -eq "1" ];then
		echo "Compare Failed"
		echo "USER SD test failed" >> /home/testlog.txt
		umount /mnt/mmc2/
		rm /home/mmc2_file
		echo Dropping VM Caches
		echo 3 > /proc/sys/vm/drop_caches
		return
	else
		echo "Compare Passed"
		echo "USER SD test passed" >> /home/testlog.txt
	fi
	umount /mnt/mmc2/
	mount -t vfat /dev/mmcblk1p1 /mnt/mmc2
	rm /home/mmc2_file
		echo Dropping VM Caches
	echo 3 > /proc/sys/vm/drop_caches
	return
}

scan_wlan()
{
	iwlist eth0 scan | grep $wlan_name
	if [ ! $? -eq "0" ];then
		scan_retry=$(( $scan_retry + 1 ))
		if [ $scan_retry -le 5 ];then
			echo "Scanning (again)..."
			scan_wlan
			if [ $scan_retry -eq 5 ]; then
				scan_retry=$(( $scan_retry + 1 ))
				echo "iwlist scan for $wlan_name failed" >> /home/testlog.txt
			fi
			return
		else
			return
		fi
	fi
}

wlan()
{
	echo 
	echo "----WLAN TESTS----"
	echo


	echo
	ifconfig eth0
	if [ $? -eq "1" ];then
		echo "WLAN Interface not found"
		echo "WLAN Interface not found" >> /home/testlog.txt
		return
	fi
	ifconfig eth0 up $wlan_ip
	scan_wlan
	iwconfig eth0 essid "$wlan_name"
	if [ $? -eq "1" ];then
		echo "Can't connect to wireless network"
		echo "Can't connect to wireless network" >> /home/testlog.txt
		return
	fi
	echo ==================
	echo ==WlAN PING TEST==
	echo ==================
	ping -I eth0 -c 8 $test_ip 

	if [ $? -eq 0 ]; then
			echo "WLAN Test Passed" 
			echo "WLAN Test Passed" >> /home/testlog.txt
	else
			echo "WLAN Test Failed" 
			echo "WLAN Test Failed" >>  /home/testlog.txt
	fi
}

bt()
{
	echo
	echo "----BT TESTS----"
	echo
	cd /usr/tests && diag_bt_scan.sh
	if [ "$?" = 0 ];then
		echo "BT Test Passed" 
		echo "BT Test Passed" >> /home/testlog.txt
	else
		echo "BT Test Failed" 
		echo "BT Test Failed" >>  /home/testlog.txt
	fi
}

battery()
{
	echo
	echo "----BATTERY TESTS----"
	echo
	echo "Displaying Battery/charger current status."
	echo -n "State of Charge: "
	cat /sys/class/i2c-adapter/i2c-2/2-0055/power_level
	echo

	echo -n "Voltage: "
	cat /sys/class/i2c-adapter/i2c-2/2-0055/voltage
	echo

	echo -n "Average Current: "
	cat /sys/class/i2c-adapter/i2c-2/2-0055/avg_current
	echo

	echo -n "Time to Empty: "
	cat /sys/class/i2c-adapter/i2c-2/2-0055/tte
	echo

	echo -n "Time to Full: "
	cat /sys/class/i2c-adapter/i2c-2/2-0055/ttf
	echo 

	echo -n "battery_detect: "
	cat /sys/class/i2c-adapter/i2c-2/2-0055/detect_battery
	echo 

	echo -n "battery_discharging "
	cat /sys/class/i2c-adapter/i2c-2/2-0055/detect_discharging
	echo 

	echo -n "Battery LOW Condition: "
	bat_low_cond=`cat /sys/class/i2c-adapter/i2c-2/2-0055/battery_low_status`
	if [ $bat_low_cond -eq "1" ];then
		echo "[ LOW ]"
	else
		echo "[ NORMAL ]"
	fi
	echo

	echo -n "Charging Status: "
	charging_status=`cat /sys/class/i2c-adapter/i2c-2/2-0055/charging`
	discharging=`cat /sys/class/i2c-adapter/i2c-2/2-0055/detect_discharging`
	bat_detect=`cat /sys/class/i2c-adapter/i2c-2/2-0055/detect_battery`
	if [ $bat_detect -eq "1" ];then
		if [ $discharging -eq "0" ];then
			if [ $charging_status -eq "0" ];then
				echo "Charging.."
			else
				echo "Charging DONE"
			fi
		else
			echo "[ Battery is discharging ]"
		fi
	else 
		echo "[ Battery not detected ]"
	fi
	echo

	echo -n "AC Power: "
	ac_status=`cat /sys/class/i2c-adapter/i2c-2/2-0055/ac_present`
	if [ $ac_status -eq "1" ];then
		echo "[ OFF ]"
	else
		echo "[ ON ]"
	fi
	echo
	
	echo -n "USB Power: "
	usb_status=`cat /sys/class/i2c-adapter/i2c-2/2-0055/usb_power`
	if [ $usb_status -eq "1" ];then
		echo "[ Low Power ]"
	else
		echo "[ High Power ]"
	fi
	echo
	
	echo -n "USB Status: "
	usb_status=`cat /sys/class/i2c-adapter/i2c-2/2-0055/usb_susp`
	if [ $usb_status -eq "1" ];then
		echo "[ Suspended ]"
	else
		echo "[ Not suspended ]"
	fi

}

pim_battery()
{
	echo
	echo "----PIM BATTERY TESTS----"
	echo

	echo -n "State of Charge: "
	cat /sys/class/i2c-adapter/i2c-3/3-0055/power_level
	echo

	echo -n "Voltage: "
	cat /sys/class/i2c-adapter/i2c-3/3-0055/voltage
	echo

	echo -n "Average Current: "
	cat /sys/class/i2c-adapter/i2c-3/3-0055/avg_current
	echo

	echo -n "Time to Empty: "
	cat /sys/class/i2c-adapter/i2c-3/3-0055/tte
	echo

	echo -n "Time to Full: "
	cat /sys/class/i2c-adapter/i2c-3/3-0055/ttf
	echo 

	echo -n "battery_detect: "
	cat /sys/class/i2c-adapter/i2c-3/3-0055/detect_battery
	echo 

	echo -n "battery_discharging "
	cat /sys/class/i2c-adapter/i2c-3/3-0055/detect_discharging
	echo 

	echo -n "Battery LOW Condition: "
	bat_low_cond=`cat /sys/class/i2c-adapter/i2c-3/3-0055/battery_low_status`
	if [ $bat_low_cond -eq "1" ];then
		echo "[ LOW ]"
	else
		echo "[ NORMAL ]"
	fi
	echo

	echo -n "Charging Status: "
	charging_status=`cat /sys/class/i2c-adapter/i2c-3/3-0055/charging`
	discharging=`cat /sys/class/i2c-adapter/i2c-3/3-0055/detect_discharging`
	bat_detect=`cat /sys/class/i2c-adapter/i2c-3/3-0055/detect_battery`
	if [ $bat_detect -eq "1" ];then
		if [ $discharging -eq "0" ];then
			if [ $charging_status -eq "0" ];then
				echo "Charging.."
			else
				echo "Charging DONE"
			fi
		else
			echo "[ Battery is discharging ]"
		fi
	else 
		echo "[ Battery not detected ]"
	fi
	echo

	echo -n "SW STATUS: "
	switch_base=`cat /sys/class/i2c-adapter/i2c-2/2-0055/sw_status`
	switch_pim=`cat /sys/class/i2c-adapter/i2c-3/3-0055/sw_status`
	if [ $switch_base -eq "1" ];then
		if [ $switch_pim -eq "1" ];then
			echo "Both BASE and PIM battery sourcing power"
		else
			echo "Power Drawn from Base"
		fi

	else
		if [ $switch_pim -eq "1" ];then
			echo "Power Drawn from PIM"
		else
			echo "Invalid state"
		fi

	fi

}

otg()
{
	echo 
	echo "----USB OTG GADGET TEST----"
	echo        Loading ...
	umount /mnt/mmc1
	insmod /home/g_file_storage.ko file=/dev/mmcblk0 stall=n
	sleep 20
	mount -t vfat /dev/mmcblk0p1 /mnt/mmc1
	echo "Contens of SD"
	echo "============="
	ls -ltr /mnt/mmc1
	if [ -e /mnt/mmc1/otgverify ]; then
		rm -f /mnt/mmc1/otgverify
		echo OTG test Passed
		echo OTG test Passed >> /home/testlog.txt
	else
		echo OTG test Failed
		echo OTG test Failed >> /home/testlog.txt
	fi

}

rtc()
{
	echo
	echo "----RTC TESTS----"
	echo
	gettime
	echo 1|settime

	hwclock --hctosys
	echo "Current date:"
	date
	date +%m%d%y%H%M> datesamp1
	echo "Please wait ..."
	sleep 3
	echo "After 3 seconds Current date:"
	date
	date +%m%d%y%H%M> datesamp2

	cmp datesamp1 datesamp2 
	if [ "$?" == "0" ];then
		echo "RTC Test Passed"
		echo "RTC Test Passed" >> /home/testlog.txt
	else
		echo "RTC Test Failed"
		echo "RTC Test Failed" >>  /home/testlog.txt
	fi
}

led()
{
	echo "------------------------"
	echo "----BATTERY LED TEST----"
	echo "------------------------"

	#Initializing leds to OFF state

	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/bat_red_led
    echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/bat_blue_led
    echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/bat_green_led

	echo "battery red led on"
	echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/bat_red_led
	sleep 1
	echo "battery red led off"
	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/bat_red_led
#	sleep 1
	echo "battery blue led on"
	echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/bat_blue_led
	sleep 1
	echo "battery blue led off"
	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/bat_blue_led
#	sleep 1 
	echo "battery green led on"
	echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/bat_green_led
	sleep 1
	echo "battery green led off"
	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/bat_green_led
#	sleep 1

#yes, BT and power are swapped in the test kernel, I no longer care
	echo "----------------------------------"
    echo "----BLUE-TOOTH STATUS LED TEST----"
    echo "----------------------------------"
    echo "BT status blue led on"
    echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/power_status_blue_led
    sleep 1
    echo "BT status blue led off"
    echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/power_status_blue_led

#   sleep 1

	echo "---------------------"
	echo "----WIFI LED TEST----"
	echo "---------------------"

	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/wifi_red_led
    echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/wifi_blue_led
    echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/wifi_green_led


	echo "wifi red led on"
	echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/wifi_red_led
	sleep 1
	echo "wifi red led off"
	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/wifi_red_led
#sleep 1
	echo "wifi blue led on"
	echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/wifi_blue_led
	sleep 1
	echo "wifi blue led off"
	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/wifi_blue_led
#	sleep 1 
	echo "wifi green led on"
	echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/wifi_green_led
	sleep 1
	echo "wifi green led off"
	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/wifi_green_led
#	sleep 1


	echo "----------------------------------"
    echo "----POWER STATUS LED TEST----"
    echo "----------------------------------"

    echo "Power blue led on"
    echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/bt_status_blue_led
    sleep 1
    echo "Power blue led off"
    echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/bt_status_blue_led
#   sleep 1


}

gpio()
{
	echo "------------------"
	echo "----GPIO TESTS----"
	echo "------------------"

	echo 
	echo "Testing GPIO-0"
	echo "=============="
	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/base_gpio_output
	echo 0 > /sys/bus/spi/drivers/SC16IS762/spi1.0/base_gpio_input

	echo "Testing GPIO-1"
	echo "=============="
	echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/base_gpio_output
	echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/base_gpio_input

	echo "Testing GPIO-2"
	echo "=============="
	echo 2 > /sys/bus/spi/drivers/SC16IS762/spi1.0/base_gpio_output
	echo 2 > /sys/bus/spi/drivers/SC16IS762/spi1.0/base_gpio_input

	echo "Testing GPIO-3"
	echo "=============="
	echo 3 > /sys/bus/spi/drivers/SC16IS762/spi1.0/base_gpio_output
	echo 3 > /sys/bus/spi/drivers/SC16IS762/spi1.0/base_gpio_input


	for gpio_num in 0 1 2 3; do 
		msg_cnt=$(dmesg | grep "GPIO $gpio_num Test passed" | wc -l)
		if [ $msg_cnt -ge 2 ];then
			echo GPIO $gpio_num Test Passed >> /home/testlog.txt
		else
			echo GPIO $gpio_num Test Failed >> /home/testlog.txt
		fi
	done
}


base()
{
	echo "BASE TESTS" >> /home/testlog.txt
	echo "==========" >> /home/testlog.txt
	echo
	echo
	echo "Starting SYSTEM SD Test"
	sys_sd
	echo "Starting USER SD Test"
	user_sd
	echo
	echo "Starting USB OTG Gadget Test"
	echo
	otg
	echo "Starting WLAN Test"
	echo
	wlan $wlan_ip $test_ip
	echo
	echo "Starting BlueTooth Test"
	echo
	bt
	echo "Starting RTC Test"
	echo
	rtc
	echo
	echo
	echo "Starting Fuel Gauge & Battery Charger Test"
	echo
	battery
#		echo "Are you able to see valid battery values? (y/n)"
#		read resp
#		if [ $resp = "y" ];then
#			echo "Battery Test Passed" 
#			echo "Battery Test Passed" >> /home/testlog.txt
#		else
#			echo "Battery Test Failed" 
#			echo "Battery Test Failed" >>  /home/testlog.txt
#		fi
#	else
#		echo
#		echo "Skipping Fuel Gauge & Battery Charger Test"
#		echo "Fuel Gauge & Battery Charger Test skipped" >> /home/testlog.txt
#		echo
#	fi

}

ethernet()
{
	echo "---------------------"
	echo "----Ethernet TEST----"
	echo "---------------------"
	ifconfig eth0 down
	ifconfig usb0 up
	sleep 2
#	udhcpc -i usb0
	echo "Enter the client(source) IP Address"
	ifconfig eth0 down
	ifconfig usb0 $source_addr up
	sleep 2
#	udhcpc -i usb0
	echo =================
	echo ==ETH PING TEST==
	echo =================
	ping -I usb0 -c 8 $dest_addr
	if [ $? -eq "1" ];then
		echo "Ethernet test error"
		return
	else
		echo "Ethernet test Passed" >> /home/testlog.txt
	fi
}

dock()
{
	echo "" >> /home/testlog.txt
	echo "DOCK TESTS" >> /home/testlog.txt
	echo "==========" >> /home/testlog.txt
	echo "------------------"
	echo "----DOCK TESTS----"
	echo "------------------"
	echo
	echo "Starting Ethernet Test"
	echo
	ethernet
	echo
	echo "Starting USB Test"
	echo
	usb_base $1
}

interactive_tests() 
{

	sleep 2
	while [ 1 ]
	do
		audio
		echo
		echo "Did you hear the song without any glitches?(y/n/r)"
		echo
		prompt user
		if [ $user = "r" ];then
			continue
		elif [ $user = "y" ];then
			echo Test Passed
			echo Audio Test Passed >> /home/testlog.txt
			break
		else
			echo Test Failed
			echo Audio Test Failed >> /home/testlog.txt
			break
		fi
	done
	echo "Starting LED Test"
	echo
		echo "Press Enter to start the led test"
		read resp
	while [ 1 ]
	do
		led
		echo "Did the led operation succeed? (y/n/r)"
		echo
		prompt user
		if [ $user = "r" ];then
			continue
		elif [ $user = "y" ];then
			echo "LED Test Passed"
			echo "LED Test Passed" >> /home/testlog.txt
			break
		else
			echo "LED Test Failed"
			echo "LED Test Failed" >>  /home/testlog.txt
			break
		fi
	done
	echo
	echo "Starting Button Test"
	echo
	while [ 1 ]
	do
		rm foo
		echo
		echo press the power \(right side\) key twice
		echo
		sleep 20 && killall dd &
		dd if=/dev/input/event0 of=foo count=4
		killall sleep > /dev/null 2>&1
		echo data from key press:
		od foo
		echo
		rm foo
		echo
		echo press the user \(left side\) key twice
		echo
		sleep 20 && killall dd &
		dd if=/dev/input/event1 of=foo count=4
		killall sleep > /dev/null 2>&1
		echo data from key press:
		od foo
		echo
		rm foo

		echo
		echo "Did the key operation succeed? (y/n/r)"
		echo
		prompt user
		if [ $user = "r" ];then
			continue
		elif [ $user = "y" ];then
			echo "KEY Test Passed" 
			echo "KEY Test Passed" >> /home/testlog.txt
			break
		else
			echo "KEY Test Failed" 
			echo "LED Test Failed" >>  /home/testlog.txt
			break
		fi

	done

        echo
        echo "Starting LCD Test"
        echo
        while [ 1 ]
        do
            cat /usr/images/home_16.raw > /dev/fb0
            echo
            echo "Did an image appear on the LCD screen?(y/n/r)"
            echo
            prompt user
            if [ $user = "r" ];then
                continue
            elif [ $user = "y" ];then
                echo Test Passed
                echo LCD Test Passed >> /home/testlog.txt
                break
            else
                echo Test Failed
                echo LCD Test Failed >> /home/testlog.txt
                break
            fi
        done

	echo
	echo "Starting LCD Backlight Test? (y/n)"
	echo
	while [ 1 ]
	do
		lcd_bkl_vary
		echo "setting default brightness"
		echo
		echo 70 > /sys/class/backlight/omap-backlight/brightness

		echo
		echo "Did the backlight vary?(y/n)"
		echo
		prompt user
		if [ $user = "r" ];then
			continue
		elif [ $user = "y" ];then
			echo Test Passed
			echo Backlight Test Passed >> /home/testlog.txt
			break
		else
			echo Test Failed
			echo Backlight Test Failed >> /home/testlog.txt
			break
		fi
	done

	# have to turn i2c back on for pim 2 so the touch screen tests work
	echo 2 > /sys/bus/spi/drivers/SC16IS762/spi1.0/i2c_sw_base_en
	echo
	echo "Starting TouchScreen Test"
	echo
	while [ 1 ]
	do
		echo
		echo "Calibrate the TouchScreen (within 25 seconds)"
		echo

		sleep 25 && killall ts_calibrate &
		ts_calibrate
		killall sleep > /dev/null 2>&1
		echo
		echo "Drag and Draw on the TouchScreen (within 5 seconds)"
		echo
		ts_test &
		sleep 5
		killall ts_test
		cat /usr/images/home_16.raw > /dev/fb0
		echo
		echo "Did the touchscreen operate properly?(y/n/r)"
		echo
		prompt user
		if [ $user = "r" ];then
			continue
		elif [ $user = "y" ];then
			echo Test Passed
			echo TouchScreen Test Passed >> /home/testlog.txt
			break
		else
			echo Test Failed
			echo TouchScreen Test Failed >> /home/testlog.txt
			break
		fi
	done
}

######################################################################################################
############# Program Start ##########################################################################
######################################################################################################

while [ 1 ]; do

	echo "==========================================================================="
	echo " Put a Camera PIM in BMI Slot 1 and press Y to continue N to quit (y/n)"
	echo "==========================================================================="
	prompt user
	if [ $user = "y" ];then
		echo 1 > /sys/bus/spi/drivers/SC16IS762/spi1.0/i2c_sw_base_en
		pim 1

		echo "==========================================================================="
		echo " If there were any failures during test they will be listed below"
		echo "==========================================================================="
		echo
		cat /home/testlog.txt
	else
		echo Camera Testing Completed
		break
	fi

done
