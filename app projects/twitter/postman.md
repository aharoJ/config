


# src
- [ ] [tutorial](https://www.youtube.com/watch?v=CLG0ha_a0q8)


# 401Unauthorized
We have allowed users the endpoint.
```bash
Similar to 403 Forbidden, but specifically for use when authentication is possible but has failed or not yet been provided. The response must include a WWW-Authenticate header field containing a challenge applicable to the requested resource.
```

fix:
```java
@Configuration
public class SecurityCpnfigurations 
{
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.csrf().disable();
        http.authorizeRequests().anyRequest().permitAll(); // auth everyone to use it for now [temp]

        return http.build();
    }
}
```