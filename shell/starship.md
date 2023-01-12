---
updated: 2023-01-11_21:55:49-08:00
---


## starship
#important/terminal_prompt

- [Apple Logo](https://github.com/jasonlong/dotfiles/blob/main/starship/starship.toml)
- [cool line ](https://github.com/AshutoshDash1999/custom-starship.toml-file)
- [I really like, huge docs](https://github.com/Ruturajn/Dotfiles/blob/main/starship.toml)

---
``` TOML
format = "[  ](bg:#8fbcbb fg:#3b4252)$directory($git_branch) $git_metrics\n$character"
```

---
``` TOML
# Use custom format
format = """
[┌───────────────────](bold green)
[│](bold green)
[└─>](bold green) """
```
---



### directory

>[directory]
style = "bg:#DA627D"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

how to make a 'casita'
``` toml
"~" = " "
```



### time

- [time docs](https://docs.rs/chrono/0.4.7/chrono/format/strftime/index.html)

``` toml
[time]
disabled = false
time_format = "%c %P" # Hour:Minute Format
style = "bg:#33658A"
use_12hr = true
format = '[ ♥ $time ]($style)'
```

- time
	- 
	- ![](aharo24_10.png)
- Color
	- ![](aharo24_12.png)


**updated the format**
		time_format = "%B %d, %Y"




---

### status

```
[status]
disabled = false
symbol = ""
# style = "bg:#464347 fg:#ff3322"
# format = "[$symbol$status]($style)"
```


#### lines

> Disable the blank line at the start of the prompt
`add_newline = false`



### username

``` toml
$username\
[  ](bg:#a3aed2 fg:#090c0c)\
```




### python
[python]

disabled = true

#symbol = " "

#symbol = "🐍 "

#symbol = "👾 "


## colors

- d56767 (# red)

## symbols

-   
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 
- ❯
- 
- 
- 
- 
- 
- ﰮ
- ﬽
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 
- ﯊


## APPLE_SYMBOLS
#important/apple

- גּ
- דּ
- הּ



## format

``` toml
format = """
[  ](fg:#FFFFFF)
[ │](fg:#FFFFFF)
[ └─>](fg:#FFFFFF) $all 
"""
```



