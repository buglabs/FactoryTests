import bugv4l as bg


# open the bug camera as a 640x480 image
bg.open(dev_code=bg.V4L2_DEVNODE_RAW,
        raw_fmt=bg.format(640, 480,bg.V4L2_PIX_FMT_SGRBG8))

# put in walking 1's test pattern mode
bg.set_ctrl(bg.V4L2_CID_TEST_PATTERN, 1) 

# start the image stream
bg.start()

# capture an image
img = bg.grab()

# copy data into a python string so we can use it after closing down the stream
data = img.get_data()

# stop the stream and close the bug camera
bg.stop()
bg.close()

# now compare the captured data to ideal test pattern
base_pattern = '\x00\x00\x01\x01\x02\x02\x04\x04\x08\x08\x10\x10  @@\x80\x80\xff\xff'
N = len(base_pattern)
ideal = base_pattern * (len(data)/N)

print "Captured Test Pattern is correct: ", (ideal == data)


