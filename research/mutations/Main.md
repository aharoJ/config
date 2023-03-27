

# Set 

install maven first 
```brew
brew install maven 
```

Add the plugin to build/plugins in your pom.xml
``` pom
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



### CLI

``` cli
mvn test-compile org.pitest:pitest-maven:mutationCoverage
```


``` cli
mvn package
```


To speed-up repeated analysis of the same codebase set the `withHistory` parameter to true.
``` cli
mvn -DwithHistory test-compile org.pitest:pitest-maven:mutationCoverage
```

# Pitest Report
Go to `target/pit-reports/index.html` for visual reports 

## Active Mutators
These are mutations that were detected that now we can use in CLI for pitest
-   CONDITIONALS_BOUNDARY
-   EMPTY_RETURNS
-   FALSE_RETURNS
-   INCREMENTS
-   INVERT_NEGS
-   MATH
-   NEGATE_CONDITIONALS
-   NULL_RETURNS
-   PRIMITIVE_RETURNS
-   TRUE_RETURNS
-   VOID_METHOD_CALLS

how to call custom-mutators in pom
```
<configuration>
    <mutators>
        <mutator>CONSTRUCTOR_CALLS</mutator>
        <mutator>NON_VOID_METHOD_CALLS</mutator>
    </mutators>
</configuration>
```





Ask mentor 

```
Resource leak: 'sc' is never closedJava(536871799)
```



Attempt to resolve
```java
		try
		{
			side1 = sc.nextInt();
			side2 = sc.nextInt();
			side3 = sc.nextInt();
	
			String triangleType;
			triangleType = typeOfTriangle(side1, side2, side3);
			System.out.println(triangleType);
		} 
		finally { sc.close(); }
```



:: means --> Method / Function 