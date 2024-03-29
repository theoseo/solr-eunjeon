TARGET=MeCab
JAVAC=javac
JAVA=java
JAR=jar
CXX=c++
#INCLUDE=/usr/lib/jvm/java-6-openjdk/include
#INCLUDE=/home/parallels/Programs/jdk1.7.0_75/include
INCLUDE=/usr/local/openjdk-8/include
PACKAGE=org/chasen/mecab
LIBS=`mecab-config --libs`
INC=`mecab-config --cflags` -I$(INCLUDE) -I$(INCLUDE)/linux


all:
	$(CXX) -O1 -c -fpic $(TARGET)_wrap.cxx  $(INC)
	$(CXX) -shared  $(TARGET)_wrap.o -o lib$(TARGET).so $(LIBS)
	$(JAVAC) $(PACKAGE)/*.java
	$(JAVAC) test.java
	$(JAR) cfv $(TARGET).jar $(PACKAGE)/*.class

test:
	env LD_LIBRARY_PATH=. $(JAVA) test
clean:
	rm -fr *.jar *.o *.so *.class $(PACKAGE)/*.class
cleanall:
	rm -fr $(TARGET).java *.cxx