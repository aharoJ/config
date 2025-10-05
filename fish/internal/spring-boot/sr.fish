function sr --description '[brew]: update'
    ./mvnw clean install spring-boot:run -DskipTests
end
