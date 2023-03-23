


# Set up

install maven first 
```brew
brew install maven 
```

Add the plugin to build/plugins in your pom.xml
``` mvn
<plugin>
    <groupId>org.pitest</groupId>
    <artifactId>pitest-maven</artifactId>
    <version>LATEST</version>
</plugin>
```


### possible isues on ClassTest.java
``` java
[ERROR] shouldAnswerWithTrue(io.aharoj.AppTest)  Time elapsed: 0.005 s  <<< FAILURE!
org.junit.ComparisonFailure: expected:<Not a [t]riangle> but was:<Not a [T]riangle>
        at io.aharoj.AppTest.shouldAnswerWithTrue(AppTest.java:21)
```

![](../../z/aharo24%202023-03-07%20at%202.22.36%20PM.png)

the output must be the exact "string as "

