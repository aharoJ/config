# MarketPlace
- eclipse marketplace to download plugs 
	- 'help'
	- 'market'
	- search for plugs 
		- install and download 


# Dependecies 
- [ ] Spring Boot DevTools
- [ ] Spring Boot Actuator
- [ ] Spring Data JPA
- [ ] PostgreSQL Driver
- [ ] Spring Security
- [ ] Spring Web


# SQL set up
- [ ] Download PostgressSQL
- [ ] Donwload DBeaver 






# Errors
To fix this issue, you need to update the data type of the ID field in your entity to an integral data type, such as `Long` or `Integer`.
```java
Caused by: org.springframework.orm.jpa.JpaSystemException: Unknown integral data type for ids : java.lang.String; nested exception is org.hibernate.id.IdentifierGenerationException: Unknown integral data type for ids : java.lang.String
```

the fix:
```java
@Entity
public class MyEntity {
    @Id
    private String id;
    // other fields and methods
}
```

```java
@Entity
public class MyEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    // other fields and methods
}
```

[Mail not working](https://stackoverflow.com/questions/16807758/java-lang-noclassdeffounderror-com-sun-mail-util-maillogger-for-junit-test-case)

# kill-port

if dont work go step 2
```shell
npx kill-port 5432
```

step 2:
```shell
brew services list 

brew services stop postgresql  
```




# Testing
```java
	// TESTING 
	@Bean
	CommandLineRunner run(RoleRepository roleRepo, UserRepository userRepo)
	{
		return args -> 
		{
			roleRepo.save(new Role(1, "USER"));
			ApplicationUser u = new ApplicationUser();
			u.setFirstName("Yaretzy");
			u.setLastName("Haro");

			HashSet<Role> roles= new HashSet<>();
			roles.add(roleRepo.findByAuthority("USER").get());
			u.setAuthorities(roles);
			userRepo.save(u);
		};
	}
```



# Architectural Design

repo == DB
models == entities (Objects)
controllers == reactive-to-events
services == fetch 

![](aharo24%202023-04-09%20at%2011.38.17%20PM.png)

``` controller
ooohh soo the controller is like the middle layer that speaks to the top n bottom layer
```


# Bean
I think its just the OBJECT 

# Autowired
before you autowired anything, it must first be a BEAN 

# @RequestBody

@RequestBody is a Spring annotation used to indicate that a method parameter should be bound to the body of the HTTP request.

When you use @RequestBody annotation with a method parameter, Spring will automatically deserialize the incoming HTTP request body into an object of the specified type, using a message converter. This is useful when you want to receive data from the client in a structured format, such as JSON or XML.

Here's an example:
```java
Copy code
@PostMapping("/users")
public ResponseEntity<User> createUser(@RequestBody User user) {
    // Process the user object received in the request body
    // ...

    // Return a response with a status code and a user object
    return new ResponseEntity<>(user, HttpStatus.CREATED);
}
```
In this example, we're using the @PostMapping annotation to handle HTTP POST requests to the /users endpoint. The createUser method takes a User object as a parameter with the @RequestBody annotation, indicating that it should be deserialized from the HTTP request body.

The createUser method then processes the user object and returns a response with a status code and a user object using the ResponseEntity class.

Note that you can use other annotations, such as @GetMapping, @PutMapping, @DeleteMapping, etc., depending on the HTTP method you want to handle. Also, you can use other parameter annotations, such as @PathVariable, @RequestParam, etc., to access other parts of the HTTP request.




# Error on return type

```
The issue you encountered is related to the difference between primitive types and object types in TypeScript.

In TypeScript, primitive types like `string`, `number`, and `boolean` represent the basic types of values that can be used in your code. Object types, on the other hand, represent more complex data structures that can be created using constructor functions or class declarations.

In your case, the `value` property in the `ValidatedInputState` interface seems to be defined as an object type `String`, which is a wrapper object for a string value. When you pass this object as an argument to a function that expects a primitive `string` type, TypeScript throws a type error because the two types are not compatible.

By calling the `toString()` method on the `String` object, you convert it to a primitive `string` type, which is compatible with the function argument type and resolves the type error.

In general, it's a good practice to use primitive types instead of object types when possible, since they are more efficient and have fewer edge cases to consider. However, in some cases, object types may be necessary or more appropriate, depending on your use case.
```


![](aharo24%202023-04-23%20at%2012.35.43%20AM.png)

```ts
export interface ValidatedInputState{
    active: boolean;
    valid: boolean;
    typedIn: boolean;
    labelActive: boolean;
    labelColor:string;
    value:String;          // ISSUE WAS HERE 
}
```





