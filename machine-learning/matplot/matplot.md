
****---
updated: 2023-01-12_14:45:35-08:00
---

# Overview
- ![](aharo24%202023-01-12%20at%202.21.20%20PM.png)
- 
- 
- ![](aharo24%202023-01-12%20at%202.21.05%20PM.png)
- 
- 
- ![](aharo24%202023-01-12%20at%202.22.23%20PM.png)
- 
- 
- ![](aharo24%202023-01-12%20at%202.22.36%20PM.png)
- 
- ![](aharo24%202023-01-12%20at%202.23.05%20PM.png)
- 
- 
- ![](aharo24%202023-01-12%20at%202.23.43%20PM.png)
- 
- 
- ![](aharo24%202023-01-12%20at%202.24.33%20PM.png)

---
---
---

# basics
#importan/plt
#plt/labels
#plt/titles
#plt/xlim
#plt/ylim

- 
	- ![](aharo24%202023-01-12%20at%202.34.06%20PM.png)
- 
- 
- `plot()` `show()` 
	- 
	- ![](aharo24%202023-01-12%20at%202.46.07%20PM.png)
- 
- 
- `xlabel() ylabel() title()`
	- 
	- ![](aharo24%202023-01-12%20at%202.53.13%20PM.png)
- 
- 
- `xlim() ylim()`
	- 
	- this limits the x or y borders
	- ![](aharo24%202023-01-12%20at%202.57.22%20PM.png)
		- 
		- ![](aharo24%202023-01-12%20at%202.58.37%20PM.png)
- 
- 
- 
- 
- 
- 
- 
- 
- a
	


---

# savefig
#plt/saving_plot

## saving to png

``` python
plt.savefig("/Users/aharo/Desktop/the_aharo_plot.png") #choose_path
plt.savefig("the_aharo_plot.png") #default_path
```



## saving the 'x' 'y' labels


```python
fig.savefig('new_fig.png', bbox_inches='tight')
```

` bbox_inches='tight' `







---




# Figures
### oop
- 
	- ![](aharo24%202023-01-12%20at%203.06.56%20PM.png)
	- 
- 
- 
- `figure`
	- 
	- ![](aharo24%202023-01-12%20at%203.12.19%20PM.png)
	- 
	- ![](aharo24%202023-01-12%20at%203.11.15%20PM.png)
	- 
	- ![](aharo24%202023-01-12%20at%203.12.39%20PM.png)
	- 
	- ![](aharo24%202023-01-12%20at%203.13.29%20PM.png)
	- 
	- ![](aharo24%202023-01-12%20at%203.14.10%20PM.png)
	- 
	- ![](aharo24%202023-01-12%20at%203.15.21%20PM.png)
	- 
	- ![](aharo24%202023-01-12%20at%203.16.01%20PM.png)
	- 
	- ![](aharo24%202023-01-12%20at%203.16.31%20PM.png)
	- 
	- ![](aharo24%202023-01-12%20at%203.18.08%20PM.png)
	- 

---

# add_axes( [] )

```python
fig = plt.figure()

#Large Axes

axes1 = fig.add_axes([0,0,1,1])

axes1.plot(a,b)

  

#Small Axes

axes2 = fig.add_axes([0.2,0.1,0.4,0.4])
```

```python
fig.add_axes([x, y, width, height])
```

![](aharo24%202023-01-12%20at%203.34.47%20PM.png)




---

# Zoom

```python

fig = plt.figure()

#Large Axes
axes1 = fig.add_axes([0,0,1,1])
axes1.plot(a,b)

axes1.set_title("aharo24")
axes1.set_xlim(0,8)
axes1.set_ylim(0,8000)
axes1.set_xlabel("A")
axes1.set_ylabel('B')  
  

#Zoomed in Axes
axes2 = fig.add_axes([0.2,0.5,0.3,0.3])
axes2.plot(x,y)  
  

axes2.set_title("ZOOM")
axes2.set_xlim(1,2)
axes2.set_ylim(0,30)
axes2.set_xlabel("A")
axes2.set_ylabel('B')
```


![](aharo24%202023-01-12%20at%203.42.13%20PM.png)


**another sample**
## look at width, height
```python
#Zoomed in Axes
axes2 = fig.add_axes([0.2,0.5,0.5,0.1])
axes2.plot(x,y)
```

![](aharo24%202023-01-12%20at%203.51.16%20PM.png)


---




# resolution
## how to fix bad res.
![](aharo24%202023-01-12%20at%203.55.14%20PM.png)


```python
fig = plt.figure(dpi=150)     # the higher the dpi, the more RAM
```

![](aharo24%202023-01-12%20at%203.56.28%20PM.png)






---
---
---



# subplots

### overview

![](aharo24%202023-01-12%20at%204.04.10%20PM.png)


![](aharo24%202023-01-12%20at%204.04.37%20PM.png)


![](aharo24%202023-01-12%20at%204.04.54%20PM.png)


![](aharo24%202023-01-12%20at%204.05.17%20PM.png)

![](aharo24%202023-01-12%20at%204.05.42%20PM.png)


---
---

##  n_rows

``` python
fig, axes=plt.subplots(nrows=1,ncols=2)
```

![](aharo24%202023-01-15%20at%201.32.38%20AM.png)


``` python
axes[0].plot(x,y)
axes[1].plot(a,b)
```

![](aharo24%202023-01-15%20at%201.36.13%20AM.png)


now its 2D 
![](aharo24%202023-01-15%20at%201.39.38%20AM.png)

plotting for 2 dimensional
![](aharo24%202023-01-15%20at%201.42.37%20AM.png)



looping 3 rows of a Y
![](aharo24%202023-01-15%20at%201.45.26%20AM.png)


## spacing

### auto spacing 
			plt.tight_layout()

![](aharo24%202023-01-15%20at%201.47.13%20AM.png)


### manual spacing 

```python
fig.subplots_adjust()
```
![](aharo24%202023-01-15%20at%204.51.25%20PM.png)

	fig.subplots_adjust(wspace=0.9, hspace=0.3)

![](aharo24%202023-01-15%20at%204.55.17%20PM.png)

.
.
birds view of spacing 2D
![](aharo24%202023-01-15%20at%205.01.14%20PM.png)





---
---
---

# Styling


## ax plot and legend

	ax.plot(x,x**2, label="X vs X^2")

	ax.legend(loc=(1.01,0.5))

**overview**
![](aharo24%202023-01-15%20at%205.13.22%20PM.png)


### plot color 

	ax.plot(x,x, color='#9bb5a7')


![](aharo24%202023-01-15%20at%205.21.52%20PM.png)


















