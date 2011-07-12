/* Python bindings to bug_vl4.c API */

#include <Python.h>
#include <structmember.h>
#include <bufferobject.h>
#include <linux/videodev2.h>
#include "../bug_v4l.h"


typedef struct {
    PyObject_HEAD
    struct v4l2_pix_format fmt;
} pyfmtObject;

static int pyfmt_init(pyfmtObject *self, PyObject *args, PyObject *kwds) {
  static char *kwlist[] = {"width", "height", "pixelformat", NULL};
  self->fmt.width = 1024;
  self->fmt.height= 768;
  self->fmt.pixelformat = V4L2_PIX_FMT_YUYV;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|iii", kwlist, &(self->fmt.width), &(self->fmt.height), &(self->fmt.pixelformat)))
    return -1; 
  return 0;
}

static PyMemberDef pyfmt_members[] = {
  {"width",       T_INT, offsetof(pyfmtObject, fmt)+offsetof(struct v4l2_pix_format, width), 0, "image width"},
  {"height",      T_INT, offsetof(pyfmtObject, fmt)+offsetof(struct v4l2_pix_format, height),  0, "image height"},
  {"pixelformat", T_INT, offsetof(pyfmtObject, fmt)+offsetof(struct v4l2_pix_format, pixelformat),0, "pixel format"},
  {NULL}  /* Sentinel */
};

PyObject *pyfmt_str(PyObject *self) {
  struct v4l2_pix_format *fmt = &((pyfmtObject *) self)->fmt;
  return PyString_FromFormat("width=%d height=%d pixelformat=%d", fmt->width, fmt->height, fmt->pixelformat);
}

static PyTypeObject pyfmtType = {
    PyObject_HEAD_INIT(NULL)
    0,                         /*ob_size*/
    "bugv4l.format",           /*tp_name*/
    sizeof(pyfmtObject),             /*tp_basicsize*/
    0,                         /*tp_itemsize*/
    0,                         /*tp_dealloc*/
    0,                         /*tp_print*/
    0,                         /*tp_getattr*/
    0,                         /*tp_setattr*/
    0,                         /*tp_compare*/
    pyfmt_str,                 /*tp_repr*/
    0,                         /*tp_as_number*/
    0,                         /*tp_as_sequence*/
    0,                         /*tp_as_mapping*/
    0,                         /*tp_hash */
    0,                         /*tp_call*/
    pyfmt_str,                 /*tp_str*/
    0,                         /*tp_getattro*/
    0,                         /*tp_setattro*/
    0,                         /*tp_as_buffer*/
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,    /*tp_flags*/
    "Python equivalant of a v4l2_pix_format struct", /* tp_doc */
    0,		               /* tp_traverse */
    0,		               /* tp_clear */
    0,		               /* tp_richcompare */
    0,		               /* tp_weaklistoffset */
    0,		               /* tp_iter */
    0,		               /* tp_iternext */
    0,                         /* tp_methods */
    pyfmt_members,             /* tp_members */
    0,                         /* tp_getset */
    0,                         /* tp_base */
    0,                         /* tp_dict */
    0,                         /* tp_descr_get */
    0,                         /* tp_descr_set */
    0,                         /* tp_dictoffset */
    (initproc)pyfmt_init,      /* tp_init */
};




typedef struct {
  PyObject_HEAD
  struct bug_img img;
  char own_memory;
} pyimgObject;

static int __pyimg_alloc(pyimgObject *self) {
  self->img.length = self->img.width*self->img.height;
  switch(self->img.code) {
  case V4L2_PIX_FMT_RGB32:
    self->img.length *= 4;
    break;
  case V4L2_PIX_FMT_RGB24:
    self->img.length *= 3;
    break;
  case V4L2_PIX_FMT_YUYV:
  case V4L2_PIX_FMT_YVYU:
  case V4L2_PIX_FMT_UYVY:
  case V4L2_PIX_FMT_VYUY:
    self->img.length *= 2;
    break;
  case V4L2_PIX_FMT_SGRBG8:
  case V4L2_PIX_FMT_SBGGR8:
    break;
  default:
    PyErr_SetString(PyExc_Exception, "Unknown image format.");
    return -1;
  }

  self->own_memory = 1;
  self->img.start = malloc(sizeof(char)*self->img.length);
  if(!self->img.start)
    return -1;
  return 0;
}

static int pyimg_init(pyimgObject *self, PyObject *args, PyObject *kwds) {
  static char *kwlist[] = {"width", "height", "pixelformat", NULL};

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "iii", kwlist, &(self->img.width), &(self->img.height), &(self->img.code)))
    return -1; 
  return __pyimg_alloc(self);
}

static void pyimg_dealloc(pyimgObject* self) {
  if(self->own_memory) {
    free(self->img.start);
  }
  self->ob_type->tp_free((PyObject*)self);
}


static PyMemberDef pyimg_members[] = {
  {"width",       T_INT, offsetof(pyimgObject, img)+offsetof(struct bug_img, width), READONLY, "image width"},
  {"height",      T_INT, offsetof(pyimgObject, img)+offsetof(struct bug_img, height),  READONLY, "image height"},
  {"pixelformat", T_INT, offsetof(pyimgObject, img)+offsetof(struct bug_img, code), READONLY, "pixel format"},
  {NULL}  /* Sentinel */
};

static PyObject *pyimg_get_data(pyimgObject* self) {
  return PyString_FromStringAndSize(self->img.start, self->img.length);
}

static PyMethodDef pyimg_methods[] = {
    {"get_data", (PyCFunction)pyimg_get_data, METH_NOARGS,
     "Returns a copy of the image data as a python string"
    },
    {NULL}  /* Sentinel */
};


PyObject *pyimg_str(PyObject *self) {
  struct bug_img *img = &((pyimgObject *) self)->img;
  return PyString_FromFormat("width=%d height=%d pixelformat=%d", img->width, img->height, img->code);
}

Py_ssize_t pyimg_getbuffer(PyObject *self, Py_ssize_t segment, void **ptrptr) {
  if(!((pyimgObject *) self)->img.start) {
    PyErr_SetString(PyExc_Exception, "No memory allocated yet.");
    return -1;
  }
  *ptrptr = (void *) ((pyimgObject *) self)->img.start;
  return ((pyimgObject *) self)->img.length;
}

Py_ssize_t pyimg_segcount(PyObject *self, Py_ssize_t *lenp) {
  // Return the number of memory segments which comprise the
  // buffer. If lenp is not NULL, the implementation must report the
  // sum of the sizes (in bytes) of all segments in *lenp. The function
  // cannot fail.
  return 1;
}

static Py_ssize_t pyimg_len(PyObject *self) {
  return ((pyimgObject *) self)->img.length;
}

static PyObject *pyimg_getitem(PyObject *self, Py_ssize_t i) {
  struct bug_img *img = &((pyimgObject *) self)->img;
  if(!img->start) {
    PyErr_SetString(PyExc_Exception, "No memory allocated yet.");
    return NULL;
  }
  if(i >= img->length || i < 0) {
    PyErr_SetString(PyExc_Exception, "Index out of bounds.");
    return NULL;
  }
  return PyInt_FromLong(((unsigned char *) img->start)[i]);
}

static int pyimg_setitem(PyObject *self, Py_ssize_t i, PyObject *v) {
  long tmp;
  struct bug_img *img = &((pyimgObject *) self)->img;
  if(!img->start) {
    PyErr_SetString(PyExc_Exception, "No memory allocated yet.");
    return -1;
  }
  if(i >= img->length || i < 0) {
    PyErr_SetString(PyExc_Exception, "Index out of bounds.");
    return -1;
  }
  if(!PyNumber_Check(v)) {
    PyErr_SetString(PyExc_Exception, "Value must be a number");
    return -1;
  }    
  PyObject *n = PyNumber_Int(v);
  if(!n) {
    PyErr_SetString(PyExc_Exception, "Value must be convertable to an integer");
    return -1;
  }
  tmp = PyInt_AS_LONG(n);
  Py_DECREF(n);
  if(tmp > 255) tmp = 255;
  if(tmp < 0) tmp = 0;
  ((unsigned char *) img->start)[i] = tmp;
  return 0;
}

static PySequenceMethods pyimg_sequence = {
  .sq_length = pyimg_len,
  .sq_item = pyimg_getitem,
  .sq_ass_item = pyimg_setitem,
};

static PyBufferProcs pyimg_buffer = {
  pyimg_getbuffer,
  pyimg_getbuffer,
  pyimg_segcount,
  pyimg_getbuffer,
};

static PyTypeObject pyimgType = {
    PyObject_HEAD_INIT(NULL)
    0,                         /*ob_size*/
    "bugv4l.image",           /*tp_name*/
    sizeof(pyimgObject),            /*tp_basicsize*/
    0,                         /*tp_itemsize*/
    pyimg_dealloc,             /*tp_dealloc*/
    0,                         /*tp_print*/
    0,                         /*tp_getattr*/
    0,                         /*tp_setattr*/
    0,                         /*tp_compare*/
    pyimg_str,                 /*tp_repr*/
    0,                         /*tp_as_number*/
    &pyimg_sequence,           /*tp_as_sequence*/
    0,                         /*tp_as_mapping*/
    0,                         /*tp_hash */
    0,                         /*tp_call*/
    pyimg_str,                 /*tp_str*/
    0,                         /*tp_getattro*/
    0,                         /*tp_setattro*/
    &pyimg_buffer,              /*tp_as_buffer*/
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GETCHARBUFFER, /*tp_flags*/
    "Python equivalant of a bug_img struct", /* tp_doc */
    0,		               /* tp_traverse */
    0,		               /* tp_clear */
    0,		               /* tp_richcompare */
    0,		               /* tp_weaklistoffset */
    0,		               /* tp_iter */
    0,		               /* tp_iternext */
    pyimg_methods,             /* tp_methods */
    pyimg_members,             /* tp_members */
    0,                         /* tp_getset */
    0,                         /* tp_base */
    0,                         /* tp_dict */
    0,                         /* tp_descr_get */
    0,                         /* tp_descr_set */
    0,                         /* tp_dictoffset */
    (initproc)pyimg_init,      /* tp_init */
};



static PyObject *open(PyObject *self, PyObject *args,PyObject *kwds) {
  char *media_node = "/dev/media0";
  int dev_code   = V4L2_DEVNODE_RESIZER;
  int slotnum = -1;
  pyfmtObject *py_raw_fmt=NULL, *py_resizer_fmt=NULL;
  struct v4l2_pix_format raw_fmt;
  struct v4l2_pix_format resizer_fmt;
  static char *kwlist[] = {"media_node", "dev_code", "slotnum", "raw_fmt", "resizer_fmt", NULL};
  int ret;

  raw_fmt.width =1024;
  raw_fmt.height=768;
  raw_fmt.pixelformat = V4L2_PIX_FMT_YUYV;
  resizer_fmt.width =640;
  resizer_fmt.height=480;
  resizer_fmt.pixelformat = V4L2_PIX_FMT_YUYV;

  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|siiOO", kwlist, &media_node, &dev_code, &slotnum, &py_raw_fmt, &py_resizer_fmt)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments.");
    return NULL; 
  }

  if(py_raw_fmt)
    memcpy(&raw_fmt,     &py_raw_fmt->fmt,     sizeof(raw_fmt));
  if(py_resizer_fmt)
    memcpy(&resizer_fmt, &py_resizer_fmt->fmt, sizeof(resizer_fmt));

  printf("media_node=%s dev_code=%d slotnum=%d raw_fmt=(%dx%d)\n", media_node, dev_code, slotnum, raw_fmt.width, raw_fmt.height);
  ret = bug_camera_open(media_node, dev_code, slotnum, &raw_fmt, &resizer_fmt);
  if(ret < 0) {
    PyErr_SetString(PyExc_Exception, "Failed to open bug camera.");
    return NULL;
  }
  Py_RETURN_NONE; 
}

static PyObject *open_and_start(PyObject *self, PyObject *args,PyObject *kwds) {
  int width, height, format = V4L2_PIX_FMT_YUYV;
  static char *kwlist[] = {"width", "height", "format", NULL};
  int ret;
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "ii|i", kwlist, &width, &height, &format)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments. Should be width and height as ints");
    return NULL; 
  }
  ret = bug_camera_open_and_start(width, height, format);
  if(ret < 0) {
    PyErr_SetString(PyExc_Exception, "Error opending and starting bug camera.");
    return NULL;
  } 
  Py_RETURN_NONE;
}

static PyObject *switch_to_dev(PyObject *self, PyObject *args,PyObject *kwds) {
  int dev_code;
  static char *kwlist[] = {"dev_code", NULL};
  int ret;
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "i", kwlist, &dev_code)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments. Should be dev_code");
    return NULL; 
  }
  ret = bug_camera_switch_to_dev(dev_code);
  if(ret < 0) {
    PyErr_SetString(PyExc_Exception, "Error switching to devices.");
    return NULL;
  } 
  Py_RETURN_NONE;
}

static PyObject *py_close(PyObject *self, PyObject *args,PyObject *kwds) {
  bug_camera_close();
  Py_RETURN_NONE;
}

static PyObject *py_bug_camera_start(PyObject *self, PyObject *args,PyObject *kwds) {
  bug_camera_start();
  Py_RETURN_NONE;
}

static PyObject *py_bug_camera_stop(PyObject *self, PyObject *args,PyObject *kwds) {
  bug_camera_stop();
  Py_RETURN_NONE;
}

static PyObject *py_bug_camera_grab(PyObject *self, PyObject *args,PyObject *kwds) {
  pyimgObject *pyimg = (pyimgObject *) pyimgType.tp_alloc(&pyimgType, 0);
  Py_BEGIN_ALLOW_THREADS
  bug_camera_grab(&(pyimg->img));
  Py_END_ALLOW_THREADS
  return (PyObject *) pyimg;
}

static PyObject *py_set_red_led(PyObject *self, PyObject *args,PyObject *kwds) {
  int on=1, ret;
  static char *kwlist[] = {"on", NULL};
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|i", kwlist, &on)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments.");
    return NULL; 
  }
  ret = set_red_led(on);
  if(ret < 0) {
    PyErr_SetString(PyExc_Exception, "Failed to set red LED.");
    return NULL; 
  }    
  Py_RETURN_NONE;
}

static PyObject *py_set_green_led(PyObject *self, PyObject *args,PyObject *kwds) {
  int on=1, ret;
  static char *kwlist[] = {"on", NULL};
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|i", kwlist, &on)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments.");
    return NULL; 
  }
  ret = set_green_led(on);
  if(ret < 0) {
    PyErr_SetString(PyExc_Exception, "Failed to set green LED.");
    return NULL; 
  }    
  Py_RETURN_NONE;
}

static PyObject *py_get_ctrl(PyObject *self, PyObject *args,PyObject *kwds) {
  int id, ret, val;
  static char *kwlist[] = {"id", NULL};
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "i", kwlist, &id)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments.");
    return NULL; 
  }
  ret = get_ctrl(id, &val);
  if(ret < 0) {
    PyErr_SetString(PyExc_Exception, "Control not implemented");
    return NULL; 
  }
  return PyInt_FromLong(val);
}

static PyObject *py_set_ctrl(PyObject *self, PyObject *args,PyObject *kwds) {
  int id, ret, val;
  static char *kwlist[] = {"id", "value", NULL};
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "ii", kwlist, &id, &val)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments.");
    return NULL; 
  }
  ret = set_ctrl(id, val);
  if(ret < 0) {
    PyErr_SetString(PyExc_Exception, "Control not implemented");
    return NULL; 
  }
  Py_RETURN_NONE;
}

static PyObject *py_get_input_slot(PyObject *self, PyObject *args,PyObject *kwds) {
  return PyInt_FromLong(get_input_slot());
}

static PyObject *py_bug_camera_ioctl(PyObject *self, PyObject *args,PyObject *kwds) {
  int request, arg=0, ret;
  static char *kwlist[] = {"request", "arg", NULL};
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "i|i", kwlist, &request, &arg)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments. Two arguments are the 'request' code and the 'arg', as an integer");
    return NULL; 
  }
  ret = bug_camera_ioctl(request, &arg);
  if(ret < 0) {
    PyErr_SetString(PyExc_Exception, "ioctl call failed.");
    return NULL;
  }
  return PyInt_FromLong(arg);
}

static PyObject *py_v4l_dev_ioctl(PyObject *self, PyObject *args,PyObject *kwds) {
  int request, arg=0, ret;
  static char *kwlist[] = {"request", "arg", NULL};
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "i|i", kwlist, &request, &arg)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments. Two arguments are the 'request' code and the 'arg', as an integer");
    return NULL; 
  }
  ret = v4l_dev_ioctl(request, &arg);
  if(ret < 0) {
    PyErr_SetString(PyExc_Exception, "ioctl call failed.");
    return NULL;
  }
  return PyInt_FromLong(arg);
}

static PyObject *py_bmi_ioctl(PyObject *self, PyObject *args,PyObject *kwds) {
  int request, arg=0, ret;
  static char *kwlist[] = {"request", "arg", NULL};
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "i|i", kwlist, &request, &arg)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments. Two arguments are the 'request' code and the 'arg', as an integer");
    return NULL; 
  }
  ret = bmi_ioctl(request, &arg);
  if(ret < 0) {
    PyErr_SetString(PyExc_Exception, "ioctl call failed.");
    return NULL;
  }
  return PyInt_FromLong(arg);
}

static PyObject *py_yuv2rgb(PyObject *self, PyObject *args,PyObject *kwds) {
  pyimgObject *yuv, *rgb=NULL;
  int downby2 = 0;
  static char *kwlist[] = {"yuvimg", "rgbimg", "downby2", NULL};
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O|Oi", kwlist, &yuv, &rgb, &downby2)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments.");
    return NULL; 
  }
  if(!rgb) {
    rgb = (pyimgObject *) pyimgType.tp_alloc(&pyimgType, 0);
    rgb->img.width = yuv->img.width;
    rgb->img.height = yuv->img.height;
    rgb->img.code = V4L2_PIX_FMT_RGB24;
    if(downby2) {
      rgb->img.width /= 2;
      rgb->img.height /= 2;
    }
    __pyimg_alloc(rgb);
  }
  yuv2rgb(&(yuv->img), (unsigned char*) rgb->img.start, downby2);
  return (PyObject *) rgb;
}  

static PyObject *py_yuv2rgba(PyObject *self, PyObject *args,PyObject *kwds) {
  pyimgObject *yuv, *rgb=NULL;
  int downby2 = 0;
  static char *kwlist[] = {"yuvimg", "rgbimg", "downby2", NULL};
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O|Oi", kwlist, &yuv, &rgb, &downby2)) {
    PyErr_SetString(PyExc_Exception, "Bad arguments.");
    return NULL; 
  }
  if(!rgb) {
    rgb = (pyimgObject *) pyimgType.tp_alloc(&pyimgType, 0);
    rgb->img.width = yuv->img.width;
    rgb->img.height = yuv->img.height;
    rgb->img.code = V4L2_PIX_FMT_RGB32;
    if(downby2) {
      rgb->img.width /= 2;
      rgb->img.height /= 2;
    }
    __pyimg_alloc(rgb);
  }
  yuv2rgba(&(yuv->img), (int*) rgb->img.start, downby2, 0);
  return (PyObject *) rgb;
}  

/*************************************  Vtb extension module ****************/
static PyMethodDef bugv4l_methods[] = {
  {"open",            (PyCFunction)open,    METH_KEYWORDS | METH_VARARGS,        "opens and initializes the bug camera by calling bug_camera_open()" },
  {"open_and_start",  (PyCFunction)open_and_start,    METH_KEYWORDS | METH_VARARGS, "Wrapper function to simplify getting an image stream running. Two arguments are width and height of desired stream." },
  {"switch_to_dev",  (PyCFunction)switch_to_dev,    METH_KEYWORDS | METH_VARARGS, "Wrapper function for bug_camera_switch_to_dev to switch the device currently active." },
  {"close", (PyCFunction) py_close, METH_NOARGS,         "closes the bug camera by calling bug_camera_close()" },
  {"bug_camera_ioctl",(PyCFunction)py_bug_camera_ioctl , METH_KEYWORDS | METH_VARARGS, "Calls an ioctl on the bug camera device. Only supports passing in an interger currently."},
  {"v4l_dev_ioctl",   (PyCFunction)py_v4l_dev_ioctl	  , METH_NOARGS, ""},  
  {"bmi_ioctl",       (PyCFunction)py_bmi_ioctl	  , METH_NOARGS, ""},  
  {"set_red_led",     (PyCFunction)py_set_red_led	  , METH_VARARGS, ""},  
  {"set_green_led",   (PyCFunction)py_set_green_led	  , METH_VARARGS, ""},  
  {"set_ctrl",        (PyCFunction)py_set_ctrl  	  , METH_VARARGS | METH_KEYWORDS, ""},
  {"get_ctrl",        (PyCFunction)py_get_ctrl  	  , METH_VARARGS | METH_KEYWORDS, ""},
  {"get_input_slot",  (PyCFunction)py_get_input_slot	  , METH_NOARGS, ""},  
  {"start",           (PyCFunction)py_bug_camera_start , METH_NOARGS, ""},
  {"stop",            (PyCFunction)py_bug_camera_stop  , METH_NOARGS, ""},
  {"grab",            (PyCFunction)py_bug_camera_grab  , METH_NOARGS, "Grabs an image. Returns an 'image' object." },
  {"yuv2rgb",         (PyCFunction)py_yuv2rgb         , METH_VARARGS | METH_KEYWORDS, "Converts a buffer in yuv422 format captured to RGB24 format. First argument is a 'image' in YUYV format. Second argument is optional RGB24 'image'. If second argument is provided, then image is updated. Otherwise a new RGB24 'image' is created and returned. Use the second argument to reuse memory." },
  {"yuv2rgba",        (PyCFunction)py_yuv2rgba         , METH_VARARGS | METH_KEYWORDS, "Converts a buffer in yuv422 format captured to RGB32 format. First argument is a 'image' in YUYV format. Second argument is optional RGB32 'image'. If second argument is provided, then image is updated. Otherwise a new RGB32 'image' is created and returned. Use the second argument to reuse memory." },
  {NULL}  /* Sentinel */
};

#include "py_videodev2.c"

#ifndef PyMODINIT_FUNC	/* declarations for DLL import/export */
#define PyMODINIT_FUNC void
#endif
PyMODINIT_FUNC initbugv4l(void) {
    PyObject* m;

    pyfmtType.tp_new = PyType_GenericNew;
    if (PyType_Ready(&pyfmtType) < 0)
        return;
    pyimgType.tp_new = PyType_GenericNew;
    if (PyType_Ready(&pyimgType) < 0)
        return;

    m = Py_InitModule3("bugv4l", bugv4l_methods,
                       "Python bindings to bug_v4l API");

    Py_INCREF(&pyfmtType);
    PyModule_AddObject(m, "format", (PyObject *)&pyfmtType);
    Py_INCREF(&pyimgType);
    PyModule_AddObject(m, "image", (PyObject *)&pyimgType);
    add_videodev2_defines(m);
    PyModule_AddObject(m, "V4L2_DEVNODE_RAW", PyInt_FromLong(V4L2_DEVNODE_RAW));
    PyModule_AddObject(m, "V4L2_DEVNODE_RESIZER", PyInt_FromLong(V4L2_DEVNODE_RESIZER));
    PyModule_AddObject(m, "V4L2_DEVNODE_PREVIEW", PyInt_FromLong(V4L2_DEVNODE_PREVIEW));
}
