#!/bin/sh

J2OBJC_HOME=~/projects/j2objc
J2OBJC=$J2OBJC_HOME/j2objc
J2OBJCC=$J2OBJC_HOME/j2objcc

BUILD_DIR=./build
BUILD_DIR_JAVA=$BUILD_DIR/java
BUILD_DIR_OBJC=$BUILD_DIR/objc
SRC_DIR=../src

CLASSPATH=~/.m2/repository/junit/junit/4.12/junit-4.12.jar

echo ""
echo "Starting java->objc source transpile and compile process..."
echo "----------------------------------------------------------"

#setup output dirs
if [[ ! -e $BUILD_DIR ]]; then
    mkdir $BUILD_DIR
fi
if [[ ! -e $BUILD_DIR_JAVA ]]; then
    mkdir $BUILD_DIR_JAVA
fi
if [[ ! -e $BUILD_DIR_OBJC ]]; then
    mkdir $BUILD_DIR_OBJC
fi

#find ../src -name "*.java"
JAVA_FILES="$(find $SRC_DIR -name '*.java')"

#run javac
#```javac -classpath ~/.m2/repository/junit/junit/4.12/junit-4.12.jar -d ./build_java @sources_all.txt``` 
echo "Compiling JAVA via javac ..."
echo "   javac -classpath <CLASSPATH> -d $BUILD_DIR_JAVA <JAVA_FILES>"
javac -classpath $CLASSPATH -d $BUILD_DIR_JAVA $JAVA_FILES

#run j2objc
echo "Transpiling JAVA to OBJC via j2objc ..."
echo "   j2objc --no-package-directories -classpath <CLASSPATH> -d $BUILD_DIR_OBJC <JAVA_FILES>"
$J2OBJC --no-package-directories -classpath $CLASSPATH -d $BUILD_DIR_OBJC $JAVA_FILES

#run j2objcc to compile objc
echo "Compiling OBJC via j2objcc ..."
echo "   j2objcc -Wno-deprecated -ObjC -o gsonobjc -ljre_emul -ljunit <BUILD_DIR_OBJC>/*.m"
$J2OBJCC -Wno-deprecated -ObjC -o gsonobjc -ljre_emul -ljunit $BUILD_DIR_OBJC/*.m

#run tests, optionally
echo "Running JUNIT tests as ObjC code ..."
echo "./gsonobjc OrgJunitRunnerJUnitCore ComGoogleGsonCommentsTest"
OBJC_TEST_NAMES="$(find $BUILD_DIR_OBJC/*Test.h -exec grep -hw -m1 "$@interface" {} \; | sed 's/@interface//' | sed 's/ ().*//' | sed 's/ :.*//')"
#echo $OBJC_TEST_NAMES
for i in $OBJC_TEST_NAMES; do echo RUNNING: $i; ./gsonobjc org.junit.runner.JUnitCore $i; done > $BUILD_DIR/test_output.txt

# TODO sum tests that ran
SUM_TESTS=0; for i in `grep "OK" $BUILD_DIR/test_output.txt | sed 's/OK (//' | sed 's/ test.*//'`; do SUM_TESTS=$(($SUM_TESTS + $i)); done;
SUM_FAILS=0; for i in `grep "Tests run:" $BUILD_DIR/test_output.txt | sed 's/.*Failures: //'`; do SUM_FAILS=$(($SUM_FAILS + $i)); done;

echo "   number of tests run: $SUM_TESTS"
echo "   number of failures: $SUM_FAILS"

echo ""
echo "Completed"
