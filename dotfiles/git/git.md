git s
## [Git Tutorial Link](https://www.youtube.com/watch?v=tRZGeaHPoaw&ab_channel=KevinStratvert)

# Overview

![](aharo24%202023-01-14%20at%207.09.20%20PM.png)




## config help

```git
git config -h
```





# Tracking
### git status tracking

![](aharo24%202023-01-14%20at%206.21.12%20PM.png)



## rm

![](aharo24%202023-01-14%20at%206.22.28%20PM.png)



![](aharo24%202023-01-14%20at%206.25.45%20PM.png)


## add

both will add everything in `pwd`
``` git 
git add --all   

git add .
```


## diff

shows the difference between old and new modification of files/dir.
 ``` git
git diff   
```



---
---




# Commit

its taking a snapchat of the current workflow.
That also implies we can go back and forth between commits.





## restore

![](aharo24%202023-01-14%20at%207.04.21%20PM.png)



normally after a commit
![](aharo24%202023-01-14%20at%207.09.20%20PM%201.png)



# log


view detailed logs 
``` git
git log -p 
```



.
.
.
.
# rebase
 ``` git
git rebase -i --root  
```


.
.
.
.
# branch

## creating
``` git 
git branch (name)
```
![](aharo24%202023-01-14%20at%209.08.20%20PM.png)

### faster way 
``` git
git switch -c (branch_name)
```  
![](aharo24%202023-01-14%20at%209.27.37%20PM.png)
.
.
### most people do it this way
#important/git/checkout
```python3
git checkout -b (branch_name)
```

whatever branch you are in, it will clone it
.
.
## merge
![](aharo24%202023-01-14%20at%209.21.43%20PM.png)
.
.
![](aharo24%202023-01-14%20at%209.23.03%20PM.png)
.
.
## delete
![](aharo24%202023-01-14%20at%209.25.10%20PM.png)


.
.
.
.
# Pushing

![](aharo24%202023-01-14%20at%2010.22.10%20PM.png)

![](aharo24%202023-01-14%20at%2010.23.44%20PM.png)


when pushing to 

		git push (remote) (branch)

git default 
		git push origin main



```git
git push --all origin
```

or 

```git
git push origin [branch_name]
```
^^^recommended 

ie...
![](aharo24%202023-01-17%20at%2010.28.23%20PM.png)




.
.
.
.
# Pull Request

# [Source This video for Request stuff](https://www.youtube.com/watch?v=rgbCcBNZcdQ&ab_channel=JakeVanderplas)
![](aharo24%202023-01-14%20at%2010.55.44%20PM.png)









# GPT
![](aharo24%202023-01-14%20at%209.13.16%20PM.png)


![](aharo24%202023-01-14%20at%2010.39.35%20PM.png)

![](aharo24%202023-01-19%20at%2010.39.26%20PM.png)
#git/origin
after we can just do git push since the local establishes a connection with the remote



.
.
.

---
---

## revert
choose the snapchat you want to revert into 

check -> [Commit](#Commit)
![](aharo24%202023-01-16%20at%2010.43.41%20PM.png)







# Attempt to restructure OpenSource 

setting up branches for environmental set up
![](aharo24%202023-01-17%20at%2010.10.54%20PM.png)






## fetch

### branch up to date?

	do `git fetch`
![](aharo24%202023-01-17%20at%2010.21.19%20PM.png)

if nothing returns we are up to date 










# Origin (more than One branch)

## delete

``` git
git push origin --delete [branch-name]
```

ie...
![](aharo24%202023-01-17%20at%2010.52.30%20PM.png)


## pull

pulling from a specific branch 
 ``` git
git pull origin [branch] 
```






![](aharo24%202023-01-17%20at%2011.43.40%20PM.png)






## branch info

```python 
git branch -v 
```

```python 
git branch -a 
```


ie...

![](aharo24%202023-01-17%20at%2011.58.03%20PM.png)



## revert a pull

#git/revert
if you pulled a origin by acident just follow it up with a rever
```git
 git revert 
```



## abbort

``` git
git merge --abort
```

``` git
git rebase --abbort
```

## cherry-picking 

![](aharo24%202023-01-18%20at%2012.29.28%20AM.png)




---
---
.
.
.
# gitignore



### creating

vim/nvim/emacs

``` vim
vim .ignore
```

mac 
``` macOS
touch .ignore
```


`*`

```git
# ignore all txt filex

*.txt
```




## stash

![](aharo24%202023-01-19%20at%2011.08.37%20PM.png)

will auto gen a staash
``` git
git stash 
```

allow you to stash with a commit name 
```git
git stash push -m "commit_name"
```

drop a stash by index
```git
git stash drop [0,1,2...]
```

pop the stash into working directory 
```git
git stash pop
```


if you want to revert to a previous file
```git
git checkout file_name.py
```

see the difference of the files that changed 
```git
git diff
```

rename a commit name on the spot
```git
git commit --amend -m "redo commit"
```

add a file to the previous commit instead of creating a new commit history
```git
git commit --amend file_name.py
```

if you want to revert to an older commit without and storing all files into the staging area ready to commit
```git
git reset --soft #2e7520782
```

this will revert to an older but will now leave all the files in the working directory
```git
git reset #1234
```

(dangerous) revert changes to # but will delete all changes ahead 
```git
git reset --soft #2e7520782
```

idk but its important from the looks... dir/files
```git
git clean df
```

if you accidently nuked yoo stuff... recovery 30 days
```git
git reflog
```

This command removes the file from the staging area, but leaves the file in your working directory.
```git
git rm --cached [file_name.blah]
```

```git
git 
```

```git
git 
```

```git
git 
```

```git
git 
```

```git
git 
```

```git
git 
```

```git
git 
```

```git
git 
```

```git
git 
```

```git
git 
```

```git
git 
```












### config
```.gitignore
tools/
linkFixer.py
dev/

  

# Ignore the ".obsidian" folder
/.obsidian


# Ignore .DS_Store files (macOs)
.DS_Store


# ignore obsidian ".trash" directory
/.trash

##########       ############
```






# [Advance](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/organizing-information-with-tables)
```markdown
|  Header  |  Header |
| ------------- | ------------- |
| Cnt   | Cnt  |
```

```markdown
| Command | Description |
| --- | --- |
| git status | List all new or modified files |
| git diff | Show file differences that haven't been staged |
```



````markdown
<details><summary>CLICK ME</summary>
<p>

#### We can hide anything, even code!

```ruby
   puts "Hello World"
```

</p>
</details>
````


# Reset

Unstage everything from git add -A
```shell
git reset 
```

# Force Untrack
normally
```shell
git rm --cached mvnw
git rm --cached mvnw.cmd
```
recursively
```shell
git rm --cached -r file_name/path
```
