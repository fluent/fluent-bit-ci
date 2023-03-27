#!/bin/bash

echo "The tail multiline legacy source will deliver to ${SOURCE_PATH}"

while [ 1 ]
do
    cat >${SOURCE_PATH} <<__EOF__
Dec 14 06:41:08 Exception in thread "main" java.lang.RuntimeException: First multiline record!
    at com.myproject.module.MyProject.badMethod(MyProject.java:22)
    at com.myproject.module.MyProject.oneMoreMethod(MyProject.java:18)
    at com.myproject.module.MyProject.anotherMethod(MyProject.java:14)
    at com.myproject.module.MyProject.someMethod(MyProject.java:10)
    at com.myproject.module.MyProject.main(MyProject.java:6)
Non compliant line
Dec 15 06:41:08 Exception in thread "main" java.lang.RuntimeException: Second multiline record!
    at com.myproject.module.MyProject.badMethod(MyProject.java:22)
    at com.myproject.module.MyProject.oneMoreMethod(MyProject.java:18)
    at com.myproject.module.MyProject.anotherMethod(MyProject.java:14)
    at com.myproject.module.MyProject.someMethod(MyProject.java:10)
    at com.myproject.module.MyProject.main(MyProject.java:6)
Another test line
And another one just in case
Dec 16 06:41:08 Exception in thread "main" java.lang.RuntimeException: Third multiline record!
    at com.myproject.module.MyProject.badMethod(MyProject.java:22)
    at com.myproject.module.MyProject.oneMoreMethod(MyProject.java:18)
    at com.myproject.module.MyProject.anotherMethod(MyProject.java:14)
    at com.myproject.module.MyProject.someMethod(MyProject.java:10)
    at com.myproject.module.MyProject.main(MyProject.java:6)
__EOF__

    break
    sleep 1
done