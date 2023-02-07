# Sources

- [Build a Command-Line To-Do App With Python and Typer](https://realpython.com/python-typer-cli/)
- .
- .
- .
- [another](https://codeburst.io/building-beautiful-command-line-interfaces-with-python-26c7e1bb54df)



``` python
%%writefile raw_input.py
import sys

if __name__ == "__main__":
print(sys.argv)
```

![](aharo24_127.png)


## argparse 

```python
%%writefile cli_argparse.py
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("integers", type=int, nargs= "+")

    args = parser.parse_args()
    print(args)
```

![](aharo24%202023-02-05%20at%203.49.10%20PM.png)

### add argument
`nargs='+'` 
- is what takes in a List of arguments.
	- if removed, only 1 argument is taken



``` python
%%writefile cli_argparse.py
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("integers", type=int, nargs= "+")
    parser.add_argument('--sum', dest='accumulate', action='store_const', const=sum, default=max)
    args = parser.parse_args()
    print(sum(args.integers))
```


	print(sum(args.integers))

- sum
	- adds
- max
	- highest number

`dest=accumalte`
	stores the function destionation 'sum or 'max'



# Fire 

```python
%%writefile cli_fire.py 
import fire

def hello(name='World'):            # default
    return f'hello: {name}'

if __name__ == '__main__':
    fire.Fire(hello)
```

![](aharo24%202023-02-05%20at%204.19.50%20PM.png)







``` python
%%writefile cli_fire_pipeline.py
import fire
from getpass import getpass

def login(username):             
    if username == None:
        username= input("enter username: ")
    
    if username== None:
        print("error: must have a username ")
        return

    pw = getpass('password: ')
    return username, pw


def scrape_tag(tag = "python", query_filter = "Votes", max_pages=10, pagesize=25):
    base_url = 'https://stackoverflow.com/questions/tagged/'
    datas = []
    for p in range(max_pages):
        page_num = p + 1
        url = f"{base_url}{tag}?tab={query_filter}&page={page_num}&pagesize={pagesize}"
        datas.append(url)
    return datas

class Pipeline():                                                               # Pipeline means to have the availibility to call multiple functions
    def __init__(self):
        self.scrape= scrape_tag
        self.login = login

if __name__ == '__main__':
    fire.Fire(Pipeline)
```

in cli

	 python3 cli_fire_pipeline.py login angel boba










