#!/bin/sh

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
		# echo "Check Passed!!"
		allowed=0
	else
		# echo "PIM$1 is not plugged in !!"
		return 1
	fi
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

echo "==========================================="
echo "      VIDEO PIM TEST ON BUGBASE            "
echo "==========================================="

#PIM 2
check_pim 2
if [ $? = "1" ];then
	echo "VPIM not plugged in"
	exit 1
fi

#Initialize PIM
echo 1 >  /sys/bus/i2c/devices/3-0071/vpim_init

#I2C EEPROM test
echo
echo "Starting I2C EEPROM Read/Write Test"
echo
echo 0 > /sys/bus/i2c/devices/3-0071/eeprom_interface

i2c_eep_w 
echo
i2c_eep_r 
if [ "$?" == "0" ];then
	echo LCD PIM I2C EEPROM Read/Write Test Passed
	echo LCD PIM I2C EEPROM Read/Write Test Passed >> /home/testlog.txt
else
	echo LCD PIM I2C EEPROM Read/Write Test Failed
	echo LCD PIM I2C EEPROM Read/Write Test Failed >> /home/testlog.txt
fi

echo "Start VGA Test? (y/n):"
echo
prompt decision
if [ $decision = "y" ];then
	LCD_to_VGA.sh
	sleep 1
	xga_all &
	sleep 1
	killall xga_all

	while [ 1 ]
	do
		cat /usr/tests/images/canyon.raw > /dev/fb0
		sleep 2
		cat /usr/tests/images/xga_1.raw > /dev/fb0
		sleep 2
		cat /usr/tests/images/xga_2.raw > /dev/fb0
		echo
		echo "Did you see the image displayed on the VGA Monitor? (y/n/r)"
		prompt answer
		if [ $answer = "y" ];then
			echo "VGA Test PASSED."
			break
		elif [ $answer = "r" ];then
			continue
		else
			echo "VGA Test FAILED."
			break
		fi
	done
fi


echo "Start DVI Test? (y/n):"
echo
prompt decision
if [ $decision = "y" ];then
	LCD_to_DVI.sh
	sleep 1
	dvi_all &
	sleep 1
	killall dvi_all

	while [ 1 ]
	do
		cat /usr/tests/images/home.raw > /dev/fb0
		sleep 2
		cat /usr/tests/images/dvi_1.raw > /dev/fb0
		sleep 2
		cat /usr/tests/images/dvi_2.raw > /dev/fb0
		echo
		echo "Did you see the image displayed on the DVI Monitor? (y/n/r)"
		prompt answer
		if [ $answer = "y" ];then
			#Check for the EEPROM Access.
			echo 1 > /sys/bus/i2c/devices/3-0071/eeprom_interface
			sleep 1
			echo
			cat /sys/bus/i2c/devices/3-0071/print_eeprom
			echo "Did you see 'DDC Access OK' Message? (y/n/r)"
			prompt answer
			if [ $answer = "y" ];then
				echo "DVI Test PASSED."
				break
			else
				echo "DVI Test FAILED."
				break
			fi
		elif [ $answer = "r" ];then
			continue
		else
			echo "DVI Test FAILED."
			break
		fi
	done
fi
cat /home/testlog.txt
#End of File

