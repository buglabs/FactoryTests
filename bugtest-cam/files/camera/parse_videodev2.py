import sys

f= open(sys.argv[1], "r")
g= open("py_videodev2.c", "w")

g.write("void add_videodev2_defines(PyObject *m) {\n")

for line in f:
    words = line.split()
    if(len(words) > 1 and words[0] == "#define"):
        if(words[1][0] == "_"): continue
        if(words[1].find("(")>=0): continue
        if(words[1].find("OLD")>=0): continue

        g.write('  PyModule_AddObject(m, "%s", (PyObject *) PyInt_FromLong(%s));\n' % (words[1], words[1]))

g.write("}\n")
g.close()
f.close()
