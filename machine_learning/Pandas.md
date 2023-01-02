# Pandas

#  [Documentation](https://pandas.pydata.org/docs/)


- help(pd.[function])  #help_pd
	- gives you a man -help
		- ie... `help(pd.series)`
			- #long_af_issue_git
		- in depth --> [Attribute_vs_Function_Calls](NumPy.md#Attribute_vs_Function_Calls)****
	- 
	- 
	- ![](../../z/aharo_17.png)
- #attribute_vs_func 



## Intro

![](../../z/aharo_11.png)
![](../../z/aharo_12.png)

- like an excel but for pandas but more powerful
- ss




# Series 


# Series_part_one

![](../../z/aharo_13.png)


![](../../z/aharo_14.png)

- Pandas seires replaces the [0,1,2,3] for names 
	- usa
	- canada
	- mexico

![](../../z/aharo_16.png)




## series_data_index

`data`

![](../../z/aharo_19.png)

![](../../z/aharo_20.png)


`index`

![](../../z/aharo_21.png)

![](../../z/aharo_22.png)


**Lets combined them** 
`myser = pd.Series(mydata,myindex)`

![](../../z/aharo_23.png)


From the looks, most real life data we will be using comes form dict (hashmaps/dict)


![](../../z/aharo_24.png)



**Part One Finished**

---


# Series_part_two

![](../../z/aharo_25.png)


- `keys()`


**we can do this because of broadcast**
![](../../z/aharo_26.png)


### NaN 
- the 2 datasets that you are ( + - / * ) do no cross over 
	- ie... look above
	- no_bueno: Brazil and Japan
	- cross_over: China, India, and USA



![](../../z/aharo_27.png)




****


--- 
---


# DataFrames
## part-one

- ![](../z/aharo_45.png)
  
  
- ![](../z/aharo_46.png)
  
  
- *Important* #pandas/dataframe
  ![](../z/aharo_47.png)
	- each individual column is a pandas series in which they all share the same index
	  

- ![](../z/aharo_48.png)


--- 

> 					how to set our dataframe
> 			
#dataframe/set_up
- ![](../z/aharo_49.png)
	- ![](../z/aharo_50.png)





---



## reading_csv


#dataframe/reading_files
>			pd.read_csv("provide full-path")
- ![](../z/aharo_52.png)

> df = pd.read_csv("/Users/aharo/programming/python/machine_learning/zcode/guidance/Pandas_03/tips.csv")









# DataFrames
## part-two

## Properties

	df.columns
> Index(['total_bill', 'tip', 'sex', 'smoker', 'day', 'time', 'size', 'price_per_person', 'Payer Name', 'CC Number', 'Payment ID'], dtype='object')

---

	df.index
> RangeIndex(start=0, stop=244, step=1)


---



	df.head()
> short summary of the **first** rows/col  of the .csv file

- ![](../z/aharo_53.png)
  
  
  

  
---

	df.tail()
> short summary of the **last** rows/col  of the .csv file


---



>						df.info()
- reports back gen. information
	- ![](../z/aharo_51.png)



---


> 			df.describe()
- ![](../z/aharo_54.png)

---


#dataframe/transpose

> 			df.describe().transpose()
-  ![](../z/aharo_55.png)



---
---


## part-three
## columns

#dataframe/columns

getting more than **ONE** column 

- ![](aharo_56%202.png)


---

#dataframe/columns/operations

- adding
	- ![](../z/aharo_57.png)
- 
-  dividing
	- ![](../z/aharo_58.png)
- 

---

#dataframe/columns/invoking


- ![](../z/aharo_60.png)
	- ![](../z/aharo_59.png)
		- ![](aharo_62%201.png)


---


#numpy/round 


`np.round()`

	df['price_per_person'] = np.round(df['total_bill'] / df['size'], 2)
- ![](../z/aharo_64.png)


---

#dataframe/commit_changes

`df.drop()`
decapricates, not recommended to use the **inplace** parameter

	df.drop(x,x,inline)


- ![](../z/aharo_67.png)


							recommended way 
	
> 		recommended way to commit changes + aligns with githubs repository updates... or something like that.

- `df = df.drop('tip_percentage',axis=1)`
	- ![](../z/aharo_68.png)



---
---


## part-four
## rows

dis






















































































































































































































































































































































































































































































































































































































































































