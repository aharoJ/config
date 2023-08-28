### Overview

![](aharo24%202023-01-15%20at%205.33.16%20PM.png)
.
.
![](aharo24%202023-01-15%20at%205.34.03%20PM.png)
.
.
![](aharo24%202023-01-15%20at%205.34.26%20PM.png)
.
.
![](aharo24%202023-01-15%20at%205.37.13%20PM.png)
.
.
![](aharo24%202023-01-15%20at%205.38.19%20PM.png)
.
.
![](aharo24%202023-01-15%20at%205.49.50%20PM.png)

---


# scatterplot
### doc for scatterplot()
### [colors](https://matplotlib.org/stable/tutorials/colors/colormaps.html)


![](aharo24%202023-01-15%20at%205.55.58%20PM.png)

	sns.scatterplot(x="salary", y='sales', data=df)

![](aharo24%202023-01-15%20at%206.00.11%20PM.png)

```python 
plt.figure(figsize=(12,4), dpi=200)

sns.scatterplot(x="salary", y='sales', data=df, hue="salary")
```

![](aharo24%202023-01-15%20at%206.13.41%20PM.png)

---

## Colors

### [colors](https://matplotlib.org/stable/tutorials/colors/colormaps.html)

## How to?

The `plot_color_gradients` will provide a list of all possible colors you can pass.

ie...

	plot_color_gradients('Qualitative',
                     ['Pastel1', 'Pastel2', 'Paired', 'Accent', 'Dark2',
                      'Set1', 'Set2', 'Set3', 'tab10', 'tab20', 'tab20b',
                      'tab20c'])

![](aharo24_119.png)




## Transparency 

`alpha`

``` python
0= none
1= full
```


ie...
```python 
plt.figure(figsize=(8,4), dpi=200)
sns.scatterplot(x='salary',y='sales',data=df, size='work experience', alpha=0.3)
```

![](aharo24%202023-01-15%20at%206.41.19%20PM.png)

#important/categorical 

---
#### important 
#matplotlib/figure

easy way to standardize the overall view of most `sns` stuff

ie...
	plt.figure(figsize=(10,4), dpi=120)



# Distribution-Plots

## Bins
![](aharo24%202023-01-15%20at%206.57.02%20PM.png)
.
.
![](aharo24%202023-01-15%20at%206.57.24%20PM.png)
.
.
![](aharo24%202023-01-15%20at%206.57.45%20PM.png)

#### histogram^^^


## rugplot
![](aharo24%202023-01-15%20at%207.08.24%20PM.png)

	sns.rugplot(x='salary', data=df, height=0.5)

![](aharo24%202023-01-15%20at%207.10.12%20PM.png)


`displot`
![](aharo24%202023-01-15%20at%207.10.57%20PM.png)



---
---
---

# Categorical-Plots

![](aharo24%202023-01-16%20at%2011.10.26%20PM.png)



## countplot

![](aharo24%202023-01-16%20at%2011.18.45%20PM.png)


### countplot == values_counts
#sns/countplot
![](aharo24%202023-01-17%20at%209.09.00%20PM.png)

refer to:
#pandas/value_counts 
[value_counts](pandas.md#value_counts)


---
#important/categorical/instances 

#### x=(feature target rows)

	sns.countplot(data=df, x='level of education')



`ci` --> confidence interval
![](aharo24%202023-01-16%20at%2011.23.20%20PM.png)


	sns.barplot(data=df, x='level of education', y='salary', estimator=np.mean,ci='sd')

![](aharo24%202023-01-16%20at%2011.31.30%20PM.png)


# Boxplot



## violinpliot

```python
sns.violinplot(data=df,x='reading score',y='parental level of education', hue='test preparation course', palette='Set2') # in violins we usually dont do hue's
```

instead use a boxplot



`bw` --> bandwidth





## swarmplot

```python
plt.figure(figsize=(10,4), dpi=150)

sns.swarmplot(data=df,x='math score',y='gender', hue='test preparation course')

  

plt.legend(bbox_to_anchor=(1.355,0.5))
```

![](aharo24%202023-01-17%20at%201.56.02%20PM.png)

`dodge=True)`
![](aharo24%202023-01-17%20at%201.56.57%20PM.png)

it will seperate the sub category









## joinplot

```python
sns.jointplot(data=df,x='math score', y='reading score')
```
![](aharo24%202023-01-17%20at%202.06.41%20PM.png)


`kind=`
`kind=hist`
`kind=scatter`
`kind=hex`
`kind=kde`

ie... 

	sns.jointplot(data=df,x='math score', y='reading score', kind='hex')
![](aharo24%202023-01-17%20at%202.07.51%20PM.png)





#### clean ie...
![](aharo24%202023-01-17%20at%202.13.13%20PM.png)

hue sepera


# pairplot
#important 
seen a lot in ML
![](aharo24%202023-01-17%20at%202.31.11%20PM.png)

```python
sns.pairplot(data=df)
```
![](aharo24%202023-01-17%20at%202.33.05%20PM.png)


#### cleanest way for pairplot
```python
sns.pairplot(data=df,hue='gender',corner=True)
```
![](aharo24%202023-01-17%20at%202.51.38%20PM.png)









# Hue

`hue=`
is amazing for allowing the user to understand the difference between feature or instances

![](aharo24%202023-01-17%20at%202.26.10%20PM.png)




## scatplot

in addition `col` and `row` is now available

```python
sns.catplot(data=df,x='gender',y='math score',kind='box', col='lunch', row='test preparation course')
```

max recommended ~> 4 
![](aharo24%202023-01-17%20at%203.02.45%20PM.png)




## pairgrid
allows you to create your own graph per section
![](aharo24%202023-01-17%20at%203.07.42%20PM.png)

this is how we put stuff
![](aharo24%202023-01-17%20at%203.06.50%20PM.png)

ie...
![](aharo24%202023-01-17%20at%203.12.24%20PM.png)

## kdeplot
#important/categorical/instances 
this plot is used to compare instances opposed to having a Y vs X/x
```python
sns.kdeplot(data=fan_reviewed, x='RATING', clip=[0,5],label= 'TRUE Rating')
sns.kdeplot(data=fan_reviewed, x='STARS', clip=[0,5],label= 'Stars Shown')

plt.legend(loc=(1.05, 0.5))
```

![](aharo24%202023-01-17%20at%209.31.33%20PM.png)

# Matrix Plot == Pivot Table

```python
plt.figure(dpi=200)

sns.heatmap(df.drop('Life expectancy',axis=1),linewidths=0.5,annot=True,cmap='viridis')
```

`annot` -> writes the number
`cmap` -> same as `palette`
`linewidth` -> straight forward
`center` -> like changing the mean
![](aharo24%202023-01-17%20at%203.26.52%20PM.png)













