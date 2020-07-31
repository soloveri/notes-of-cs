set workPath=D:\complie
set destiantion=D:\complie\jdk8_src
set sourcePath=D:\JavaProject\StudyJDK\src\source
set finalPath=C:\"Program Files"\Java\jdk1.8.0_251\jre\lib\endorsed


xcopy %sourcePath%\java %destiantion%\java /s /e /y /i
xcopy %sourcePath%\javax %destiantion%\javax /s /e /y /i
xcopy %sourcePath%\org %destiantion%\org /s /e /y /i

copy C:\"Program Files"\Java\jdk1.8.0_251\jre\lib\rt.jar %workPath% /y

cd /d d:\complie

dir /B /S /X jdk8_src\*.java > filelist.txt

javac -encoding UTF-8 -J-Xms16m -J-Xmx1024m -sourcepath d:\complie\jdk8_src -cp d:\complie\rt.jar -d d:\complie\jdk_debug -g @filelist.txt >> log.txt 2>&1

cd d:\complie\jdk_debug

jar cf0 rt_debug.jar *

copy .\rt_debug.jar %finalPath% /y
