
GSON as a J2OBJC EXAMPLE
========================

Overview
----------

Premises: 
* This example project is an attempt to understand how to share code across iOS and Android using j2objc... 
* j2objc is intended to transpile (source -> source) java code to objective-C   
* j2objc is one way to share code across iOS and Android, it is interesting because: 
   * Focus on native code (webviews and frameworks that use them are nonstarters)
   * Focus on non UI code (logic that should be shared and is not idiomatic of UI)
   * Provides well written source that can be used to debug 
   * Written with a testing focus in mind, tests can be run across platform (ensures semantics, not just syntax, are correct) 
   * Written with performance and memory footprint in mind
   * Open source and maintained by very smart and capable people (tom et al at google) 
   * Out of the box it includes a JRE emulation library for core classes, and a useful and sensible set of 3rd party libs

The idea of code sharing across mobile platforms is the DRY principle turned up to 11.   
There are several ways to share native code on iOS and Android, these include C, j2objc, and maybe someday Kotlin and Swift.  j2objc is very well written and very performant and shares the code that you want to share, hence it is interesting and helpful.   

Why GSON
--------

This example project uses an existing Java library with a lot of source code and a lot of tests: GSON.    
This allows for a robust example that does not have any transitive dependencies not already supported by j2objc. 

Process high level:
* compile java (just to make sure it works, extra step to get in habit) 
* transpile to obj-c
* compile objc-c
* transpile/compile gson TESTS
* run the tests as OBJECTIVE MUTHA FLIPPING C

j2objc internals
-----------------
http://j2objc.org/docs/Design-Overview.html
1. rewriter - rewrites stuff that doesn’t have java equivalent, it all started here, was bigger, stuff split out
2. autoboxer
3. iostypeconverter - foundation classes, object, number, string, throwable, class, etc
4. iosmethodconverter - uses a mapping table to “fix” method names, no overloading allowed!
5. initialization normalizer - static vars and static blocks and any init stuff moved into initializers
6. anon class converter - makes anon classes into inner classes
7. inner class converter - makes inner classes top level classes “in sample compilation unit” (runs after anon class step, so once this is done it’s all top level, yup)
8. destructor converter - creates mem momt destructors as needed, tries to deal with finalize, depends on arc or not, etc
9. complex expression extractor - breaks up complex expressions like chained method calls
10. nil check resolver - ads nil_chk wherever an expression is dereferenced

interesting notes from tom: 
https://groups.google.com/forum/#!topic/j2objc-discuss/iXdtl4KRP1k


Detailed Process: GSON java to objc with tests
----------------------------------------------

1. Prerequisites: 
   * clone this project, or get the source of gson and mirror this project
   * install j2objc and have $J2OBJC_HOME in the path. 

2. run mvn tests, ensure all java works and tests pass (1018 tests)   
```mvn test```

3. get ALL the source together and make sure javac can compile it   
```find ../src -name "*.java" > sources_all.txt```   

4. make sure javac works, and include deps in classpath (ONLY use deps that j2objc supports, else get SOURCE for those deps too)   
```javac -classpath ~/.m2/repository/junit/junit/4.12/junit-4.12.jar -d ./build_java @sources_all.txt```   

5. transpile the JAVA source into OBJ-C source with j2objc (no pkg dirs makes the imports cleaner/easier)   
```j2objc --no-package-directories -classpath ~/.m2/repository/junit/junit/4.12/junit-4.12.jar -d ./build_objc @sources_all.txt```   

6. compile the OBJ-C into an executable   
```j2objcc -Wno-deprecated -ObjC -o gsonobjc -ljre_emul -ljunit ./build_objc/*.m```   
(you now have an executable! and it can run all the interfaces defined within! (incl junit))

7. run a SINGLE test   
```./gsonobjc org.junit.runner.JUnitCore ComGoogleGsonCommentsTest```   
(NOTE that you can refer to EITHER the full package name with dots OR the CamelCaseName)    
(this also works: ./gsonobjc OrgJunitRunnerJUnitCore com.google.gson.CommentsTest)   

8. get the NAMES of all the tests, while not using package directories, from the gened header files 
```find ./build_objc/*Test.h -exec grep -hw -m1 "$@interface" {} \; | sed 's/@interface//' | sed 's/ ().*/\/' | sed 's/ :.*//' > test_names.txt```

9. RUN the tests   
```for i in `cat test_names.txt`; do echo RUNNING: $i; ./gsonobjc org.junit.runner.JUnitCore $i; done```



Other Notes
------------

NOTE: if you NEED sources for other projects, such as for transitive dependencies, maven can help you get them for open source stuff.    
```mvn dependency:unpack-dependencies -Dclassifier=sources```   
(this will put source in target/dependency)

NOTE: how many original java tests are there and how many objc tests there are from the OBJ-C header files
```find ../src/test -name "*Test.java" | wc -l```   
```find ./build_objc -name "*Test.h" | wc -l``` 

NOTE: sum of tests that ran (it's 1018 in java)   
```SUM=0; for i in `grep "OK" test_results.txt | sed 's/OK (//' | sed 's/ test.*//'`; do SUM=$(($SUM + $i)); done; echo $SUM```   
