import os
os.chdir(os.path.dirname(__file__))
scripts={}
scripts[chr(34)+chr(116)+chr(101)+chr(115)+chr(116)+chr(95)+chr(98)+chr(97)+chr(115)+chr(101)+chr(32)+chr(42)+chr(46)+chr(112)+chr(121)+chr(34)]=chr(34)+chr(35)+chr(32)+chr(98)+chr(97)+chr(115)+chr(101)+chr(10)+chr(34)
for n,c in scripts.items():
 open(n,chr(119)).write(c)
print(chr(68)+chr(111)+chr(110)+chr(101))
