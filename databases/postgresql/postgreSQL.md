



The process for creating a new user and changing the authentication method in PostgreSQL is different from MySQL, but here are the general steps you can follow in a Macbook:

1.  First, open a terminal window on your Macbook.
2.  Enter the following command to log in to your PostgreSQL database:
    
    Copy code
    
    `psql -U postgres`
    
    This will log you in as the "postgres" user, which is the default superuser account in PostgreSQL.
    
3.  To create a new user with the username "aharoJ" and the password "lala", enter the following command:
    
    sqlCopy code
    
    `CREATE USER aharoJ WITH PASSWORD 'lala';`
    
4.  To grant all privileges to the "aharoJ" user, you can create a new database and grant all privileges to the user for that database:
    
    sqlCopy code
    
    `CREATE DATABASE mydatabase; GRANT ALL PRIVILEGES ON DATABASE mydatabase TO aharoJ;`
    
    This will create a new database called "mydatabase" and grant all privileges to the user "aharoJ" for that database.
    
6.  Restart PostgreSQL by running the following command:
    
    Copy code
    
    `sudo systemctl restart postgresql`
    
    This will restart the PostgreSQL service with the updated authentication method.
    

After following these steps, you should be able to log in to your PostgreSQL database using the "aharoJ" user with the "lala" password.


# Users - Role same thing in postgreSQL
```sql
CREATE USER [username] WITH PASSWORD 'pass';
```

```sql
CREATE ROLE [username]
```

# Drop

Databases
```sql
DROP DATABASE [database_name];
```

Roles
```sql
DROP ROLE [role_name];
```


# Clone Privalages

```sql
postgres=# GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO [user_name];
```


```sql
postgres=# ALTER USER [user_name] CREATEDB;
```


```sql
ALTER USER aharoJ WITH SUPERUSER CREATEDB CREATEROLE;
```





# Revoke
```sql
postgres=# REVOKE ALL PRIVILEGES ON SCHEMA public FROM fuser;
```


# CLI 
```sql
mysql -u (root)
```



