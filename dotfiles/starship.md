# I will come back and refresh files... ik ik its messy


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
	- ![](../z/aharo24_10.png)
- Color
	- ![](../z/aharo24_12.png)


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




---

[directory]
style = "italic bg:#6F6A70 fg:#EEEEEE"
- ![](../z/aharo24_112.png)



---

## style

- ![](../z/aharo24_113.png)
- 
- 
- ![](../z/aharo24_114.png)








## color



- hex:89b482
	- nice green
- 
- 
- hex:78929b
	- fire blue
- 
- 
- hex: a17295
	- nice purple
- 
- 
- hex: F7DC6F
	- yellow
- 
- 
- hex: F7A278
	- orange 
- 
- 
- hex: 9b8378
	- brown
- 
- 
- hex:9b9578
	- shit fire (greyish green)
- 
- 
- hex:8e789b
	- dark purplee
- 
- 
- hex:808080
	- grey blue
- 
- 
- 


## right


[docs](https://starship.rs/advanced-config/#enable-right-prompt)


- ![](../z/aharo24_115.png)




















