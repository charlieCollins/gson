
PROCESS NOTES
=============

Overview
----------
start with json, no deps beyond simple java (cheating a little) 

goal
compile java (just to make sure it works, extra step to get in habit) 
transpile to obj-c
compile objc-c
transpile/compile gson TESTS
run the tests as OBJECTIVE MUTHA FLIPPING C


Steps for j2objc internally
---------------------------
http://j2objc.org/docs/Design-Overview.html
1. rewriter rewrites stuff that doesn’t have java equivalent, it all started here, was bigger, stuff split out
2. autoboxer
3. iostypeconverter — foundation classes, object, number, string, throwable, class, etc
4. iosmethodconverter - uses a mapping table to “fix” method names, no overloading allowed!
5. initialization normalizer - static vars and static blocks and any init stuff moved into initializers
6. anon class converter - makes anon classes into inner classes
7. inner class converter - makes inner classes top level classes “in sample compilation unit” (runs after anon class step, so once this is done it’s all top level, yup)
8. destructor converter - creates mem momt destructors as needed, tries to deal with finalize, depends on arc or not, etc
9. complex expression extractor - breaks up complex expressions like chained method calls
10. nil check resolver - ads nil_chk wherever an expression is dereferenced

interesting notes from tom: 
https://groups.google.com/forum/#!topic/j2objc-discuss/iXdtl4KRP1k


take gson and convert it, as an example
----------------------------------------

1. run mvn tests, all good, 1018 passed
mvn test

#if you NEED sources, maven can help you get them for OS stuff
#(this puts all the stuff in target/dependency)
mvn dependency:unpack-dependencies -Dclassifier=sources

2. get ALL the source together and make sure javac can compile it
find ../src -name "*.java" > sources_all.txt

3. make sure javac works, and include deps in classpath (ONLY use deps that j2objc supports, else get SOURCE for those deps too)
javac -classpath ~/.m2/repository/junit/junit/4.12/junit-4.12.jar -d ./build_java @sources_all.txt

4. transpile the JAVA source in OBJC source with j2objc (no pkg dirs makes the imports cleaner/easier)
j2objc --no-package-directories -classpath ~/.m2/repository/junit/junit/4.12/junit-4.12.jar -d ./build_objc @sources_all.txt

5. compile the OBJC into an executable 
j2objcc -Wno-deprecated -ObjC -o gsonobjc -ljre_emul -ljunit ./build_objc/*.m

#you now have an executable! and it can run all the interfaces defined within! (incl junit) 

6. run a SINGLE test
./gsonobjc org.junit.runner.JUnitCore ComGoogleGsonCommentsTest

7. get the NAMES of all the tests, while not using package directories, from the gened header files 
find ./build_objc/*Test.h -exec grep -hw -m1 "$@interface" {} \; | sed 's/@interface//' | sed 's/ ().*/\/' | sed 's/ :.*//' > test_names.txt

8. RUN the tests 
for i in `cat test_names.txt`; do echo RUNNING: $i; ./gsonobjc org.junit.runner.JUnitCore $i; done



other notes
------------

#try to determing number of tests match?
grep "OK" test_results.txt | sed 's/OK (//' | sed 's/ test.*//'

#how many original java tests are there
find ../src/test -name "*Test.java" | wc -l

#sum of tests that ran (it's 1018 in java)
SUM=0; for i in `grep "OK" test_results.txt | sed 's/OK (//' | sed 's/ test.*//'`; do SUM=$(($SUM + $i)); done; echo $SUM
