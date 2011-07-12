#!/usr/bin/env python
import time
import datetime
ee_date = "%02d%s" % (time.localtime()[7] / 7, str(datetime.date.today().year)[2:]) # save to put in EEPROM
print ee_date
