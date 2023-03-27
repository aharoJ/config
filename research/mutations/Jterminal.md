

Add the dependency to pom
```
<dependencies>
  ...
  <dependency>
    <groupId>com.grahamedgecombe.jterminal</groupId>
    <artifactId>jterminal</artifactId>
    <version>1.0.1</version>
  </dependency>
  ...
</dependencies>
```

package
``` cli
mvn package
```

compile
``` cli
mvn compile
```

run
``` cli
mvn -DwithHistory test-compile org.pitest:pitest-maven:mutationCoverage
```






