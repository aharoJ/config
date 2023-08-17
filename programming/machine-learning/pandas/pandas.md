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
	- ![](../../../z/aharo_17.png)
- #attribute_vs_func 



## Intro

![](../../../z/aharo_11.png)
![](../../../z/aharo_12.png)

- like an excel but for pandas but more powerful
- ss




# Series 


# Series_part_one

 ![](../../../z/aharo_13.png)


![](../../../z/aharo_14.png)

- Pandas seires replaces the [0,1,2,3] for names 
	- usa
	- canada
	- mexico

![](../../../z/aharo_16.png)




## series_data_index

`data`

![](../../../z/aharo_19.png)

![](../../../z/aharo_20.png)


`index`

![](../../../z/aharo_21.png)

![](../../../z/aharo_22.png)


**Lets combined them** 
`myser = pd.Series(mydata,myindex)`

![](../../../z/aharo_23.png)


From the looks, most real life data we will be using comes form dict (hashmaps/dict)


![](../../../z/aharo_24.png)



**Part One Finished**

---


# Series_part_two

![](../../../z/aharo_25.png)


- `keys()`


**we can do this because of broadcast**
![](../../../z/aharo_26.png)


### NaN 
- the 2 datasets that you are ( + - / * ) do no cross over 
	- ie... look above
	- no_bueno: Brazil and Japan
	- cross_over: China, India, and USA



![](../../../z/aharo_27.png)




****


--- 
---


# DataFrames_part-one

- ![](../../../z/aharo_45.png)
  
  
- ![](../../../z/aharo_46.png)
  
  
- *Important* #pandas/dataframe
  ![](../../../z/aharo_47.png)
	- each individual column is a pandas series in which they all share the same index
	  

- ![](../../../z/aharo_48.png)


--- 

> 					how to set our dataframe
> 			
#dataframe/set_up
- ![](../../../z/aharo_49.png)
	- ![](../../../z/aharo_50.png)





---



## reading_csv


#dataframe/reading_files
>			pd.read_csv("provide full-path")
- ![](../../../z/aharo_52.png)

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
	- ![](../../../z/aharo_53.png)
  
  
	df.tail()
> short summary of the **last** rows/col  of the .csv file


---



## info
- df.info()
	- ![](../../../z/aharo_51.png)



---

## Describe

- df.describe()
	- ![](../../../z/aharo_54.png)

---


#dataframe/transpose
#data/instances 

> 			df.describe().transpose()
-  ![](../../../z/aharo_55.png)




## transpose
#dataframe/transpose
#data/instances 


> 			df.describe().transpose()
-  ![](../../../z/aharo_55.png)

![](../../../z/aharo_136.png)

---

### transpose_more_things

- gio![](../../../z/aharo_132.png)
	- gio![](../../../z/aharo_134.png)
- 
  
- 
-  ![](../../../z/aharo_133.png)
- ![](../../../z/aharo_135.png)


#### make_your_own
![](../../../z/aharo_153.png)

---






# DataFrames_part-three



## DataFrames_columns

#dataframe/columns

getting more than **ONE** column 

- ![](../../../z/aharo_56.png)


---

#dataframe/columns/operations

- adding
	- ![](../../../z/aharo_57.png)
- 
-  dividing
	- ![](../../../z/aharo_58.png)
- 

---

#dataframe/columns/invoking


- ![](../../../z/aharo_60.png)
	- ![](../../../z/aharo_59.png)
		- ![](../../../z/aharo_62.png)


---


#numpy/round 


`np.round()`

	df['price_per_person'] = np.round(df['total_bill'] / df['size'], 2)
- ![](../../../z/aharo_64.png)


---
#dataframe/commit_changes
#dataframe/drop 



decapricates, not recommended to use the **inplace** parameter

	df.drop(x,x,inline)


- ![](../../../z/aharo_67.png)


	
> 		recommended way to commit changes + aligns with githubs repository updates... or something like that.

- `df = df.drop('tip_percentage',axis=1)`
	- ![](../../../z/aharo_68.png)



---
---


# DataFrames_part-four

## DataFrames_rows



### converging a column into a row

-  df.set_index()
	- ![](../../../z/aharo_70.png)
		- #dataframe/commit_changes 
			- ![](../../../z/aharo_72.png)
				- `df = df`


---


### unconverging a column into a row
- df.reset_index()
- ![](../../../z/aharo_73.png)
	- #dataframe/uncommit_changes 
		- ![](../../../z/aharo_74.png)

---

## grabbing rows



![](../../../z/aharo_75.png)

		df.iloc[0] # integer based location
#dataframe/iloc
- df.iloc[0]  # integer based location
	- ![](../../../z/aharo_77.png)
- ![](../../../z/aharo_79.png)



---



		df.loc['Sun2959'] # labed based location
#dataframe/loc
- df.loc['Sun2959'] # labed based location
	- ![](../../../z/aharo_78.png)



---
#dataframe/iloc 

- ![](../../../z/aharo_80.png)
	- slicing


---
#dataframe/loc 
- ![](../../../z/aharo_82.png)



---
#dataframe/drop 
- ![](../../../z/aharo_83.png)


---
#dataframe/append

- ![](../../../z/aharo_85.png)
	- updated version but seems weird
		-  `pd.concat([one_row, one_row])`


---
---
---
# Conditional_Filterting

**SUMMARY**
- ![](../../../z/aharo_86.png)
- ![](../../../z/aharo_87.png)
	- #data/instances 
	- #data/feature 
		- ie... ![](../../../z/aharo_88.png)

---
---
## single_feature
**rows are like examples of the feature**

![](../../../z/aharo_89.png)


---

**rows and columns** 
![](../../../z/aharo_90.png)

> rows as particular data instances and columns as features


---
**breakdown**
#pandas/broadcast
- ![](../../../z/aharo_91.png)
	- ![](../../../z/aharo_92.png)
		- ![](../../../z/aharo_93.png)
			- ![](../../../z/aharo_96.png)
			- #pandas/broadcast  will broadcast that comparison to every single instance of that column 
- ![](../../../z/aharo_97.png)
	- ![](../../../z/aharo_98.png)

![](../../../z/aharo_99.png)


---
#pandas/conditional

**Baby Steps**

![](../../../z/aharo_100.png)

--- 
**big boy steps**
#dataframe/loc 

- ![](../../../z/aharo_101.png)
- ![](../../../z/aharo_102.png)

**or**
- df [   df[]    ]
![](../../../z/aharo_103.png)


> conditional filtering based off "one feature"


---

#pandas/conditional/and
#pandas/conditional/or  
**&&    ,  ||**

			df[ (df['sex'] == "Male") and (df['total_bill'] > 30) ]
- **and** causes an error
	- ![](../../../z/aharo_104.png)
		- ![](../../../z/aharo_106.png)
			- issue because pythons bool compares two val sides but these are series
- **correct**
	- **'&'**![](../../../z/aharo_107.png)
	- **'|'** ![](../../../z/aharo_108.png)


---

**baby steps**

![](../../../z/aharo_109.png)
![](../../../z/aharo_111.png)

---
#pandas/conditional/isin
#conditional/target_feature

		df[target_feature].isin()

#pandas/conditional/isin/doc
![](../../../z/aharo_112.png)
---

**big boy steps**
#conditional/target_features

		df[target_feature].isin()
- ![](../../../z/aharo_113.png)


---
---
---
# Methods_single-column


**Summary**
- ![](../../../z/aharo_114.png)
- ![](../../../z/aharo_115.png)




## apply()

- ~doc~
	- ![](../../../z/aharo_118.png)


- ![](../../../z/aharo_117.png)
	- ![](../../../z/aharo_119.png)
		- data manipulation is so crazy, wow ~.~![](../../../z/aharo_120.png)

---
##  [instance_vs_feature](programming/machine-learning/self%20notes/Main.md#instance_vs_feature)

^reference_for_help

#data/instances 
#data/feature 



---
# Methods_multi-column

## lambdas


**wrong**
![](../../../z/aharo_122.png)



**correct**
![](../../../z/aharo_123.png)



### lambdas
``` python
df['Quality'] = np.vectorize(quality) (df['total_bill'], df['tip'])
```
![](../../../z/aharo_126.png)


### vectorization

```python
df['Quality'] = np.vectorize(quality) (df['total_bill'], df['tip'])
```

![](../../../z/aharo_127.png)


#### vectorization_vs_lambdas 

![](../../../z/aharo_127%201.png)

- [link](https://stackoverflow.com/a/3379505/20353469)


---
---
---

# Methods_describe_sorting
#pandas/sorting
#pandas/describe

- ![](../../../z/aharo_137.png)

- ![](../../../z/aharo_138.png)

---
## sort_params

**df.sort_value('Y', param)**

- ![](../../../z/aharo_139.png)

- if they math `x==x` then you can include a second ascending ==('Y')==
	- ![](../../../z/aharo_140.png)


---
## min_max_idx
grabbing index location of min() and max()
- `max()`
	- ![](../../../z/aharo_141.png)
- `idxmax()`
	- ![](../../../z/aharo_143.png)


## corr

- how correlated the whole model is to eachother
	- ![](../../../z/aharo_144.png)


--- 

## value_counts
#pandas/value_counts

- count the instances of your Y
	- ![](../../../z/aharo_145.png)



---

## unique
#data/instances 
#important 

**I believe this will be important in abstract imagery**

---
**table**
![](../../../z/panda_head_table.png)
---


> 	it shows all instances for that specific Y


- unique()
	- ![](../../../z/aharo_146.png)
	- ![](../../../z/aharo_148.png)
- nunique()
	- ![](../../../z/aharo_147.png)

---
## replace
#pandas/replace
- replace()
	- single target
		- ![](../../../z/aharo_149.png)
	- mult targets
		- Using List![](../../../z/aharo_150.png)
	

### mapping

- mapping instead of using replace
	- ![](../../../z/aharo_151.png)

--- 

## duplicate
- pretty straight forward
	- ![](../../../z/aharo_152.png)


---


## inclusive

- inclusive()
	- ie... (10>= # && 20<= # )
	- 
	- ![](../../../z/aharo_154.png)

---

## n_smallest-largest
#important 
#data/instances 
- df.nlargest()
	- conditional for targetting the **largest** instances of a Y
	- 
	- 
	- ![](../../../z/aharo_155.png)

- df.nsmallest()
	- conditional for targetting the **smallest** instances of a Y
	- 
	- 
	- ![](../../../z/aharo_156.png)

---

## sampling
- df.sample()
	- samples random series
	- 
	- ![](../../../z/aharo_157.png)
	- ![](../../../z/aharo_158.png)



---
### resources_method
#data/feature 

#### [Applying function with multiple arguments to create a new pandas column](https://stackoverflow.com/questions/19914937/applying-function-with-multiple-arguments-to-create-a-new-pandas-column)

- multiple ways to define features
- ![](../../../z/aharo_124.png)



---














---
---
---

# Missing-Data_pandas-operations
## overview
#data/NaN

- ![](../../../z/aharo_159.png)
- 
- ![](../../../z/aharo_160.png)
- 
- ![](../../../z/aharo_161.png)
- 
- ![](../../../z/aharo_162.png)
- 
- ![](../../../z/aharo_163.png)
- 
- ![](../../../z/aharo_164.png)
- 
- ![](../../../z/aharo_165.png)
- 
- ![](../../../z/aharo_166.png)
- 
- ![](../../../z/aharo_167.png)
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
- ![](../../../z/aharo_170.png)

---

## isnull
#data/NaN 
- **df.isnull()**
	- checks if there is a NaN
	- 
	- ![](../../../z/aharo_171.png)

---

## notnull
#data/NaN 
- **df.notnull()**
	- checks **no** NaN's
	- 
	- ![](../../../z/aharo_172.png)


---
## dropna
#data/instances 
- df.dropna()
	- drops all NaN instances of a Y
	- 
	- ![](../../../z/aharo_173.png)
	- 
	- 
	- *param* threshold is like how many NaN do you allow before dropping 
		- ![](../../../z/aharo_174.png)
- 
- 
- #dataframe/axis
- Parameter (axis)
	- 0 --> drops instances
	- 1 --> drops Y's
		- ![](../../../z/aharo_175.png)
- 
- 
- Param --> ( subset=[] )
- 
	- ![](../../../z/aharo_176.png)
- 
- 

---
## fillna
#data/NaN 
#data/instances 

- df.fillna()
	- fills in the NaN
	- 
	- not good practice tho![](../../../z/aharo_177.png)
- 
- 
- ![](../../../z/aharo_178.png)
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
- ![](../../../z/aharo24_13.png)
- 
- 
- groupby() gets the Y 
	- ![](../../../z/aharo24_14.png)
- 
- #important/pandas
	- ![](../../../z/aharo24_15.png)
	- ![](../../../z/aharo24_16.png)
	- ![](../../../z/aharo24_14.png)
- 
- 

---
---


## groupby

- important ones
	- ![](../../../z/aharo24_18.png)
- 
- [FULL DOC](https://pandas.pydata.org/docs/reference/groupby.html)


- df.groupby("Y").mean/add/ []
	- ![](../../../z/aharo24_19.png)



### multi level indexes Y's

```python
df.groupby(['model_year','cylinders']).mean()
```
- using two features to compare instances 
- 
	- ![](../../../z/aharo24_20.png)


---

### quick statistical analysis

![](../../../z/aharo24_21.png)

---


## index

```python
year_cyl = df.groupby(['model_year','cylinders']).mean()
```


- dataframe.index.names 
	- give you the features
	- 
	- ![](../../../z/aharo24_22.png)
- dataframe.index.levels
	- gives you all corresponding instances of Y
	- 
	- ![](../../../z/aharo24_23.png)


---

## loc_index

- overview of both single vs multi in action
- 
	- ![](../../../z/aharo24_25.png)
	- 

### tuples

- [  (  )  ] 
- 
	- ![](../../../z/aharo24_26.png)



---

## xs

- quick doc
	- ![](../../../z/aharo24_27.png)
- 
- 

### cross section
- cross section
	- 
	- yearly_cyl.xs()![](../../../z/aharo24_28.png)
- 
- 
- ![](../../../z/aharo24_30.png)




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
	- ![](../../../z/aharo24_31.png)




---

## swaplevel

- swaplevel()
	- change the features inorder
	- ![](../../../z/aharo24_32.png)


---
---

## sort_index

- reverse orders
	- ![](../../../z/aharo24_33.png)


---
---

### advance method

- df.agg()
	- using hashmaps
	- 
	- ![](../../../z/aharo24_34.png)





## Concatenation
**Combining Dataframes**

### [doc ](https://pandas.pydata.org/pandas-docs/stable/user_guide/merging.html)

## overview

- 
	- 
	- 
	- ![](../../../z/aharo24_35.png)
	- 
	- 
	- ![](../../../z/aharo24_36.png)
	- 
	- ![](../../../z/aharo24_37.png)
		- ![](../../../z/aharo24_38.png)



---

## concat

			pd.concat([one,two], axis=1)

- set up
	- 
	- ![](../../../z/aharo24_39.png)
	- 
	- 
	- ![](../../../z/aharo24_40.png)
		- 
		- switch the features
			- 
			- ![](../../../z/aharo24_41.png)
- 
- x=0 mixes the instances 
	- 
	- ![](../../../z/aharo24_42.png)
- what if we want `c` and `d` to fall under `a,b`
	- 
	- *two.columns = one.columns*
	- ![](../../../z/aharo24_43.png)
- resetting the index 
	- 
	- 
	- newdf.index = range(len(newdf))![](../../../z/aharo24_44.png)

---
---


# Merge_Combining

## overview

- ![](../../../z/aharo24_46.png)
- 
- main idea
	- 
	- ![](../../../z/aharo24_47.png)
- 
- ![](../../../z/aharo24_49.png)
- 
- 
- merges are often shown as Venn Diagrams![](../../../z/aharo24_50.png)
	- 
	- 
	- ![](../../../z/aharo24_51.png)
	- 
	- 
	- ![](../../../z/aharo24_54.png)
		- 
		- 
		- ![](../../../z/aharo24_55.png)
- 
- 
- how=left we cmp against the right ![](../../../z/aharo24_56.png)
- 
- 
-  how=right we cmp against the left![](../../../z/aharo24_57.png)

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
		- ![](../../../z/aharo24_52.png)
	- 
	- 
	- order dont matter
		- 
		- 
		- ![](../../../z/aharo24_53.png)
- 
- 
- **`left`**
	- 
	- 
	- ![](../../../z/aharo24_58.png)
- 
- 
- **`right`**
	- 
	- 
	- ![](../../../z/aharo24_59.png)

---
---


## outer

### overview_outer

```python
pd.merge(registrations,logins, how='outter', on='name')
```

- ![](../../../z/aharo24_60.png)
- 
- 
- ![](../../../z/aharo24_61.png)
	- 
	- ![](../../../z/aharo24_62.png)
	- 

---

- outer
	- 
	- ![](../../../z/aharo24_63.png)


---

## left_on/right_index

		left_index/right_index -- right_on/left_on

- left_index/right_index -- right_on/left_on
	- 
	- ![](../../../z/aharo24_64.png)

---

reset_index
#pandas/reset

```python
registrations = registrations.reset_index()
```


--- 

[left_on/right_index](#left_on/right_index)

![](../../../z/aharo24_65.png)

---

## merging same feature_name

ie... here we have id's in both Y's
![](../../../z/aharo24_66.png)



---
---

## Overview

### [doc](https://pandas.pydata.org/docs/user_guide/text.html)

- ![](../../../z/aharo24_82.png)


## split

- split()
	- 
	- 
	- ![](../../../z/aharo24_83.png)
- 


## replace, strip

- ![](../../../z/aharo24_84.png)
	- capitalize 
	- 
	- ![](../../../z/aharo24_85.png)
- 
- 
- or you can use a function
	- 
	- 
	- ![](../../../z/aharo24_86.png)

---
---

## datetime

#### [docs](https://docs.python.org/3/library/datetime.html#strftime-and-strptime-format-codes)

- ![](../../../z/aharo24_88.png)
- 
- 
- ![](../../../z/aharo24_96.png)




### to_datetime
#importan/datetime

		pd.to_datetime(myser)

- ![](../../../z/aharo24_89.png)
- 
- 
	- ![](../../../z/aharo24_90.png)

---
### European-Time

- ![](../../../z/aharo24_91.png)



### custom times
![](../../../z/aharo24_92.png)


### from obj to datetime

- manually do it
- ![](../../../z/aharo24_93.png)
- 
- smarter way is to set 
	- parse_date=[0]
- 
- 
- ![](../../../z/aharo24_94.png)




### resampe

		sales.resample(rule='A').mean()

- ![](../../../z/aharo24_95.png)


---
---
---

### overview

#### [docs](https://pandas.pydata.org/pandas-docs/stable/user_guide/io.html)


		df = pd.read_csv('/Users/aharo/desk/python/machine_learning/zcode/guidance/Pandas_03/example.csv',header=None)

- ![](../../../z/aharo24_97.png)
- ![](../../../z/aharo24_98.png)




## saving csv

- ![](../../../z/aharo24_99.png)

![](../../../z/aharo24_100.png)


---
---
---

## Pivot Tables

This is not going to be used in machine learning(ML) but is very useful for Excel stuff

- ![](../../../z/aharo24_101.png)
- ![](../../../z/aharo24_102.png)
- 

Decided to skip but will come back

---








