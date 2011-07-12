import bugv4l as bg
import os


os.system("cp /usr/images/testingflash.fb /dev/fb0")

# open the bug camera as a 640x480 image
bg.open(dev_code=bg.V4L2_DEVNODE_RESIZER,
        raw_fmt=bg.format(2048,1536, bg.V4L2_PIX_FMT_YUYV),
        resizer_fmt=bg.format(640, 480))

bg.set_red_led(False)

bg.set_ctrl(bg.V4L2_CID_FLASH_STROBE, 1) # turn on flash LED strobe
os.system("sleep 3")

bg.set_ctrl(bg.V4L2_CID_FLASH_STROBE, 0) # turn off flash LED strobe

os.system("cp /usr/images/testingleds.fb /dev/fb0")

bg.set_red_led(True)
os.system("sleep 2")
bg.set_red_led(False)
bg.set_green_led(True)
os.system("sleep 2")
bg.set_green_led(False)


os.system("cp /usr/images/startingcamera.fb /dev/fb0")

# start the image stream
bg.start()

# capture some image
for i in range(50):
    yuv_img = bg.grab()
    rgb_img = bg.yuv2rgba(yuv_img, downby2=True);
    filename =  "fb.raw"
    f = open(filename, "w");
    f.write(rgb_img);
    f.close()
    os.system("cp fb.raw /dev/fb0")


    print("Wrote image %d" % i)

# switch to full res

bg.stop()
bg.close()

