## I will come back and refresh files... ik ik its messy


# Pandas

#  [Documentation](https://pandas.pydata.org/docs/)


- help(pd.[function])  #help_pd
	- gives you a man -help
		- ie... `help(pd.series)`
			- #long_af_issue_git
		- in depth --> [Attribute_vs_Function_Calls](numpy.md#Attribute_vs_Function_Calls)****
	- 
	- 
	- ![](aharo_17.png)
- #attribute_vs_func 



## Intro

![](aharo_11.png)
![](aharo_12.png)

- like an excel but for pandas but more powerful
- ss




# Series 


# Series_part_one

 ![](aharo_13.png)


![](aharo_14.png)

- Pandas seires replaces the [0,1,2,3] for names 
	- usa
	- canada
	- mexico

![](aharo_16.png)




## series_data_index

`data`

![](aharo_19.png)

![](aharo_20.png)


`index`

![](aharo_21.png)

![](aharo_22.png)


**Lets combined them** 
`myser = pd.Series(mydata,myindex)`

![](aharo_23.png)


From the looks, most real life data we will be using comes form dict (hashmaps/dict)


![](aharo_24.png)



**Part One Finished**

---


# Series_part_two

![](aharo_25.png)


- `keys()`


**we can do this because of broadcast**
![](aharo_26.png)


### NaN 
- the 2 datasets that you are ( + - / * ) do no cross over 
	- ie... look above
	- no_bueno: Brazil and Japan
	- cross_over: China, India, and USA



![](aharo_27.png)




****


--- 
---


# DataFrames_part-one

- ![](aharo_45.png)
  
  
- ![](aharo_46.png)
  
  
- *Important* #pandas/dataframe
  ![](aharo_47.png)
	- each individual column is a pandas series in which they all share the same index
	  

- ![](aharo_48.png)


--- 

> 					how to set our dataframe
> 			
#dataframe/set_up
- ![](aharo_49.png)
	- ![](aharo_50.png)





---



## reading_csv


#dataframe/reading_files
>			pd.read_csv("provide full-path")
- ![](aharo_52.png)

> df = pd.read_csv("/Users/aharo/programming/python/machine_learning/zcode/guidance/Pandas_03/tips.csv")









# DataFrames_part-two


## DataFrames_Properties

	df.columns
> Index(['total_bill', 'tip', 'sex', 'smoker', 'day', 'time', 'size', 'price_per_person', 'Payer Name', 'CC Number', 'Payment ID'], dtype='object')

---

	df.index
> RangeIndex(start=0, stop=244, step=1)




> short summary of the **first** rows/col  of the .csv file
- df.head()
	- ![](aharo_53.png)
  
  
	df.tail()
> short summary of the **last** rows/col  of the .csv file


---



## info
- df.info()
	- ![](aharo_51.png)



---

## Describe

- df.describe()
	- ![](aharo_54.png)

---


#dataframe/transpose
#data/instances 

> 			df.describe().transpose()
-  ![](aharo_55.png)




## transpose
#dataframe/transpose
#data/instances 


> 			df.describe().transpose()
-  ![](aharo_55.png)

![](aharo_136.png)

---

### transpose_more_things

- gio![](aharo_132.png)
	- gio![](aharo_134.png)
- 
  
- 
-  ![](aharo_133.png)
- ![](aharo_135.png)


#### make_your_own
![](aharo_153.png)

---






# DataFrames_part-three



## DataFrames_columns

#dataframe/columns

getting more than **ONE** column 

- ![](aharo_56.png)


---

#dataframe/columns/operations

- adding
	- ![](aharo_57.png)
- 
-  dividing
	- ![](aharo_58.png)
- 

---

#dataframe/columns/invoking


- ![](aharo_60.png)
	- ![](aharo_59.png)
		- ![](aharo_62.png)


---


#numpy/round 


`np.round()`

	df['price_per_person'] = np.round(df['total_bill'] / df['size'], 2)
- ![](aharo_64.png)


---
#dataframe/commit_changes
#dataframe/drop 



decapricates, not recommended to use the **inplace** parameter

	df.drop(x,x,inline)


- ![](aharo_67.png)


	
> 		recommended way to commit changes + aligns with githubs repository updates... or something like that.

- `df = df.drop('tip_percentage',axis=1)`
	- ![](aharo_68.png)



---
---


# DataFrames_part-four

## DataFrames_rows



### converging a column into a row

-  df.set_index()
	- ![](aharo_70.png)
		- #dataframe/commit_changes 
			- ![](aharo_72.png)
				- `df = df`


---


### unconverging a column into a row
- df.reset_index()
- ![](aharo_73.png)
	- #dataframe/uncommit_changes 
		- ![](aharo_74.png)

---

## grabbing rows



![](aharo_75.png)

		df.iloc[0] # integer based location
#dataframe/iloc
- df.iloc[0]  # integer based location
	- ![](aharo_77.png)
- ![](aharo_79.png)



---



		df.loc['Sun2959'] # labed based location
#dataframe/loc
- df.loc['Sun2959'] # labed based location
	- ![](aharo_78.png)



---
#dataframe/iloc 

- ![](aharo_80.png)
	- slicing


---
#dataframe/loc 
- ![](aharo_82.png)



---
#dataframe/drop 
- ![](aharo_83.png)


---
#dataframe/append

- ![](aharo_85.png)
	- updated version but seems weird
		-  `pd.concat([one_row, one_row])`


---
---
---
# Conditional_Filterting

**SUMMARY**
- ![](aharo_86.png)
- ![](aharo_87.png)
	- #data/instances 
	- #data/feature 
		- ie... ![](aharo_88.png)

---
---
## single_feature
**rows are like examples of the feature**

![](aharo_89.png)


---

**rows and columns** 
![](aharo_90.png)

> rows as particular data instances and columns as features


---
**breakdown**
#pandas/broadcast
- ![](aharo_91.png)
	- ![](aharo_92.png)
		- ![](aharo_93.png)
			- ![](aharo_96.png)
			- #pandas/broadcast  will broadcast that comparison to every single instance of that column 
- ![](aharo_97.png)
	- ![](aharo_98.png)

![](aharo_99.png)


---
#pandas/conditional

**Baby Steps**

![](aharo_100.png)

--- 
**big boy steps**
#dataframe/loc 

- ![](aharo_101.png)
- ![](aharo_102.png)

**or**
- df [   df[]    ]
![](aharo_103.png)


> conditional filtering based off "one feature"


---

#pandas/conditional/and
#pandas/conditional/or  
**&&    ,  ||**

			df[ (df['sex'] == "Male") and (df['total_bill'] > 30) ]
- **and** causes an error
	- ![](aharo_104.png)
		- ![](aharo_106.png)
			- issue because pythons bool compares two val sides but these are series
- **correct**
	- **'&'**![](aharo_107.png)
	- **'|'** ![](aharo_108.png)


---

**baby steps**

![](aharo_109.png)
![](aharo_111.png)

---
#pandas/conditional/isin
#conditional/target_feature

		df[target_feature].isin()

#pandas/conditional/isin/doc
![](aharo_112.png)
---

**big boy steps**
#conditional/target_features

		df[target_feature].isin()
- ![](aharo_113.png)


---
---
---
# Methods_single-column


**Summary**
- ![](aharo_114.png)
- ![](aharo_115.png)




## apply()

- ~doc~
	- ![](aharo_118.png)


- ![](aharo_117.png)
	- ![](aharo_119.png)
		- data manipulation is so crazy, wow ~.~![](aharo_120.png)

---
##  [instance_vs_feature](machine-learning/self%20notes/Main.md#instance_vs_feature)

^reference_for_help

#data/instances 
#data/feature 



---
# Methods_multi-column

## lambdas


**wrong**
![](aharo_122.png)



**correct**
![](aharo_123.png)



### lambdas
``` python
df['Quality'] = np.vectorize(quality) (df['total_bill'], df['tip'])
```
![](aharo_126.png)


### vectorization

```python
df['Quality'] = np.vectorize(quality) (df['total_bill'], df['tip'])
```

![](aharo_127.png)


#### vectorization_vs_lambdas 

![](aharo_127%201.png)

- [link](https://stackoverflow.com/a/3379505/20353469)


---
---
---

# Methods_describe_sorting
#pandas/sorting
#pandas/describe

- ![](aharo_137.png)

- ![](aharo_138.png)

---
## sort_params

**df.sort_value('Y', param)**

- ![](aharo_139.png)

- if they math `x==x` then you can include a second ascending ==('Y')==
	- ![](aharo_140.png)


---
## min_max_idx
grabbing index location of min() and max()
- `max()`
	- ![](aharo_141.png)
- `idxmax()`
	- ![](aharo_143.png)


## corr

- how correlated the whole model is to eachother
	- ![](aharo_144.png)


--- 

## value_counts
#pandas/value_counts

- count the instances of your Y
	- ![](aharo_145.png)



---

## unique
#data/instances 
#important 

**I believe this will be important in abstract imagery**

---
**table**
![](panda_head_table.png)
---


> 	it shows all instances for that specific Y


- unique()
	- ![](aharo_146.png)
	- ![](aharo_148.png)
- nunique()
	- ![](aharo_147.png)

---
## replace
#pandas/replace
- replace()
	- single target
		- ![](aharo_149.png)
	- mult targets
		- Using List![](aharo_150.png)
	

### mapping

- mapping instead of using replace
	- ![](aharo_151.png)

--- 

## duplicate
- pretty straight forward
	- ![](aharo_152.png)


---


## inclusive

- inclusive()
	- ie... (10>= # && 20<= # )
	- 
	- ![](aharo_154.png)

---

## n_smallest-largest
#important 
#data/instances 
- df.nlargest()
	- conditional for targetting the **largest** instances of a Y
	- 
	- 
	- ![](aharo_155.png)

- df.nsmallest()
	- conditional for targetting the **smallest** instances of a Y
	- 
	- 
	- ![](aharo_156.png)

---

## sampling
- df.sample()
	- samples random series
	- 
	- ![](aharo_157.png)
	- ![](aharo_158.png)



---
### resources_method
#data/feature 

#### [Applying function with multiple arguments to create a new pandas column](https://stackoverflow.com/questions/19914937/applying-function-with-multiple-arguments-to-create-a-new-pandas-column)

- multiple ways to define features
- ![](aharo_124.png)



---














---
---
---

# Missing-Data_pandas-operations
## overview
#data/NaN

- ![](aharo_159.png)
- 
- ![](aharo_160.png)
- 
- ![](aharo_161.png)
- 
- ![](aharo_162.png)
- 
- ![](aharo_163.png)
- 
- ![](aharo_164.png)
- 
- ![](aharo_165.png)
- 
- ![](aharo_166.png)
- 
- ![](aharo_167.png)
	- **11,0,0**
- 
- 
- 
- 
- 



## is_vs_eq-eq

- `is`  **correct**
	- `==` will be **incorrect**
- 
- myvar is np.nan
- 
- ![](aharo_170.png)

---

## isnull
#data/NaN 
- **df.isnull()**
	- checks if there is a NaN
	- 
	- ![](aharo_171.png)

---

## notnull
#data/NaN 
- **df.notnull()**
	- checks **no** NaN's
	- 
	- ![](aharo_172.png)


---
## dropna
#data/instances 
- df.dropna()
	- drops all NaN instances of a Y
	- 
	- ![](aharo_173.png)
	- 
	- 
	- *param* threshold is like how many NaN do you allow before dropping 
		- ![](aharo_174.png)
- 
- 
- #dataframe/axis
- Parameter (axis)
	- 0 --> drops instances
	- 1 --> drops Y's
		- ![](aharo_175.png)
- 
- 
- Param --> ( subset=[] )
- 
	- ![](aharo_176.png)
- 
- 

---
## fillna
#data/NaN 
#data/instances 

- df.fillna()
	- fills in the NaN
	- 
	- not good practice tho![](aharo_177.png)
- 
- 
- ![](aharo_178.png)
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 


---
---
---
# GroupBy

## overview
- 
- ![](aharo24_13.png)
- 
- 
- groupby() gets the Y 
	- ![](aharo24_14.png)
- 
- #important/pandas
	- ![](aharo24_15.png)
	- ![](aharo24_16.png)
	- ![](aharo24_14.png)
- 
- 

---
---


## groupby

- important ones
	- ![](aharo24_18.png)
- 
- [FULL DOC](https://pandas.pydata.org/docs/reference/groupby.html)


- df.groupby("Y").mean/add/ []
	- ![](aharo24_19.png)



### multi level indexes Y's

```python
df.groupby(['model_year','cylinders']).mean()
```
- using two features to compare instances 
- 
	- ![](aharo24_20.png)


---

### quick statistical analysis

![](aharo24_21.png)

---


## index

```python
year_cyl = df.groupby(['model_year','cylinders']).mean()
```


- dataframe.index.names 
	- give you the features
	- 
	- ![](aharo24_22.png)
- dataframe.index.levels
	- gives you all corresponding instances of Y
	- 
	- ![](aharo24_23.png)


---

## loc_index

- overview of both single vs multi in action
- 
	- ![](aharo24_25.png)
	- 

### tuples

- [  (  )  ] 
- 
	- ![](aharo24_26.png)



---

## xs

- quick doc
	- ![](aharo24_27.png)
- 
- 

### cross section
- cross section
	- 
	- yearly_cyl.xs()![](aharo24_28.png)
- 
- 
- ![](aharo24_30.png)




its easier to specify your dataframe before doing an iloc,ioc, or groupby and then those commands

- ie...
- 
		df[df['cylinders'].isin([6,8])].
- 
- 
- 
- 
- df[df['cylinders'].isin([6,8])].groupby(['model_year','cylinders']).mean()
	- 
	- 
	- ![](aharo24_31.png)




---

## swaplevel

- swaplevel()
	- change the features inorder
	- ![](aharo24_32.png)


---
---

## sort_index

- reverse orders
	- ![](aharo24_33.png)


---
---

### advance method

- df.agg()
	- using hashmaps
	- 
	- ![](aharo24_34.png)





## Concatenation
**Combining Dataframes**

### [doc ](https://pandas.pydata.org/pandas-docs/stable/user_guide/merging.html)

## overview

- 
	- 
	- 
	- ![](aharo24_35.png)
	- 
	- 
	- ![](aharo24_36.png)
	- 
	- ![](aharo24_37.png)
		- ![](aharo24_38.png)



---

## concat

			pd.concat([one,two], axis=1)

- set up
	- 
	- ![](aharo24_39.png)
	- 
	- 
	- ![](aharo24_40.png)
		- 
		- switch the features
			- 
			- ![](aharo24_41.png)
- 
- x=0 mixes the instances 
	- 
	- ![](aharo24_42.png)
- what if we want `c` and `d` to fall under `a,b`
	- 
	- *two.columns = one.columns*
	- ![](aharo24_43.png)
- resetting the index 
	- 
	- 
	- newdf.index = range(len(newdf))![](aharo24_44.png)

---
---


# Merge_Combining

## overview

- ![](aharo24_46.png)
- 
- main idea
	- 
	- ![](aharo24_47.png)
- 
- ![](aharo24_49.png)
- 
- 
- merges are often shown as Venn Diagrams![](aharo24_50.png)
	- 
	- 
	- ![](aharo24_51.png)
	- 
	- 
	- ![](aharo24_54.png)
		- 
		- 
		- ![](aharo24_55.png)
- 
- 
- how=left we cmp against the right ![](aharo24_56.png)
- 
- 
-  how=right we cmp against the left![](aharo24_57.png)

---
---
## merge
#important/merge 
- **'inner'** is what gets both left and right 
	- 
	- 
	- ie... andrew,bob
		- 
		- 
		- ![](aharo24_52.png)
	- 
	- 
	- order dont matter
		- 
		- 
		- ![](aharo24_53.png)
- 
- 
- **`left`**
	- 
	- 
	- ![](aharo24_58.png)
- 
- 
- **`right`**
	- 
	- 
	- ![](aharo24_59.png)

---
---


## outer

### overview_outer

```python
pd.merge(registrations,logins, how='outter', on='name')
```

- ![](aharo24_60.png)
- 
- 
- ![](aharo24_61.png)
	- 
	- ![](aharo24_62.png)
	- 

---

- outer
	- 
	- ![](aharo24_63.png)


---

## left_on/right_index

		left_index/right_index -- right_on/left_on

- left_index/right_index -- right_on/left_on
	- 
	- ![](aharo24_64.png)

---

reset_index
#pandas/reset

```python
registrations = registrations.reset_index()
```


--- 

[left_on/right_index](#left_on/right_index)

![](aharo24_65.png)

---

## merging same feature_name

ie... here we have id's in both Y's
![](aharo24_66.png)



---
---

## Overview

### [doc](https://pandas.pydata.org/docs/user_guide/text.html)

- ![](aharo24_82.png)


## split

- split()
	- 
	- 
	- ![](aharo24_83.png)
- 


## replace, strip

- ![](aharo24_84.png)
	- capitalize 
	- 
	- ![](aharo24_85.png)
- 
- 
- or you can use a function
	- 
	- 
	- ![](aharo24_86.png)

---
---

## datetime

#### [docs](https://docs.python.org/3/library/datetime.html#strftime-and-strptime-format-codes)

- ![](aharo24_88.png)
- 
- 
- ![](aharo24_96.png)




### to_datetime
#importan/datetime

		pd.to_datetime(myser)

- ![](aharo24_89.png)
- 
- 
	- ![](aharo24_90.png)

---
### European-Time

- ![](aharo24_91.png)



### custom times
![](aharo24_92.png)


### from obj to datetime

- manually do it
- ![](aharo24_93.png)
- 
- smarter way is to set 
	- parse_date=[0]
- 
- 
- ![](aharo24_94.png)




### resampe

		sales.resample(rule='A').mean()

- ![](aharo24_95.png)


---
---
---

### overview

#### [docs](https://pandas.pydata.org/pandas-docs/stable/user_guide/io.html)


		df = pd.read_csv('/Users/aharo/desk/python/machine_learning/zcode/guidance/Pandas_03/example.csv',header=None)

- ![](aharo24_97.png)
- ![](aharo24_98.png)




## saving csv

- ![](aharo24_99.png)

![](aharo24_100.png)


---
---
---

## Pivot Tables

This is not going to be used in machine learning(ML) but is very useful for Excel stuff

- ![](aharo24_101.png)
- ![](aharo24_102.png)
- 

Decided to skip but will come back

---








