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






















