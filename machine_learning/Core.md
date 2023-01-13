# I will come back and refresh files... ik ik its messy
## I was not even a week into .md note-taking here

what are columns and what are rows?
#data/feature 
#data/instances 
![](../z/aharo_88.png)

---

# instance_vs_feature
#data/instances
#data/feature
- x represents an instance of the data
	- `axis=0`
- y represents a feature or attribute of the data 
	- `axis=1`

``` table
col     y      y     y                   
 x      x      x     x 
 x      x      x    rows
```

## axis_parameter
#data/feature 
#data/instances  
                                             
`axis=0` 
iterates over the instances (x)

`axis=1`
iterates/creates features (Y)

---
---
# multiple_features
#data/feature 

- [internal_resources](Pandas.md#resources)

[Applying function with multiple arguments to create a new pandas column](https://stackoverflow.com/questions/19914937/applying-function-with-multiple-arguments-to-create-a-new-pandas-column)


---
---
---
# Vectorize

[Using Numpy Vectorize on Functions that Return Vectors](https://stackoverflow.com/questions/3379301/using-numpy-vectorize-on-functions-that-return-vectors)
                      
> The purpose of `np.vectorize` is to transform functions which are not numpy-aware

![](../z/aharo_129.png)

```python
import timeit

# code snippet to be executed only once

setup = '''

import numpy as np

import pandas as pd

df = pd.read_csv('tips.csv')

def quality(total_bill,tip):

if tip/total_bill > 0.25:

return "Generous"

else:

return "Other"

'''

# code snippet whose execution time is to be measured

stmt_one = '''

df['Tip Quality'] = df[['total_bill','tip']].apply(lambda df: quality(df['total_bill'],df['tip']),axis=1)

'''

  

stmt_two = '''

df['Tip Quality'] = np.vectorize(quality)(df['total_bill'], df['tip'])

'''
```
![](../z/aharo_130.png)






















