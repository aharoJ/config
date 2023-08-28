# CLI 
```mysql
mysql -u (root) -p
```


# Connecting sql to vscode 
For MySql 8 instead of changing the authentication for the **root** user create a new **user** with all privileges and change the authentication method from caching_sha2_password to mysql_native_password. Please check the [documentation](https://medium.com/@kelvinekrresa/mysql-client-does-not-support-authentication-protocol-6eed9a6e813e) by Ochuko Ekrresa for detailed steps.

Summary of Steps:

1.  Login as root `mysql -u root -p`
2.  Create new user `CREATE USER 'newuser'@'localhost' IDENTIFIED BY 'password';`
3.  Grand all permission `GRANT ALL PRIVILEGES ON *.* TO 'newuser'@'localhost';`

Check the above-mentioned document link to get details on giving specific privileges.

4.  Reload the privileges `FLUSH PRIVILEGES;`
5.  Quit MySql `quit;` and login again with `mysql -u [newuser] -p;`
6.  Last step change the authentication `ALTER USER 'newuser'@'localhost' IDENTIFIED WITH mysql_native_password by 'password';`

# Schema 
```sql
SHOW DATABASEs;
```

```sql
CREATE DATABASE [my_new_schema];
```

# Drop
```sql
DROP TABLE [my_table];
```

```sql
drop database [my_schema];
```

# Src
- [ ] [how to connect your mysql to vscode](https://stackoverflow.com/questions/50093144/mysql-8-0-client-does-not-support-authentication-protocol-requested-by-server)






