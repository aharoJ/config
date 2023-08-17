
![](aharo24%202023-01-18%20at%206.33.21%20PM.png)
.
.
![](aharo24%202023-01-18%20at%206.44.12%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.17.50%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.19.48%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.20.38%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.22.33%20PM.png)

![](aharo24%202023-01-18%20at%207.26.32%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.26.49%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.28.01%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.28.46%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.30.18%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.31.42%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.32.34%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.33.44%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.37.41%20PM.png)
.
.
![](aharo24%202023-01-18%20at%207.38.33%20PM.png)







# Links
[Simple Linear regression](https://en.wikipedia.org/wiki/Simple_linear_regression)
	[slr equation](https://en.wikipedia.org/wiki/Simple_linear_regression#Intuition_about_the_slope)

[Ordinary least squares](https://en.wikipedia.org/wiki/Ordinary_least_squares)
- [equation process min:14](https://www.udemy.com/course/python-for-machine-learning-data-science-masterclass/learn/lecture/22976300?start=570#overview)




## feature vs instance
#important/featurevsinstances 

X--> feature matrix
y--> target output/label

```python
y=mx+b   -->    # for the best line for 'this' set of real data points
y=B1x+B0 -->    # beta coeficients
```


### polyfit

``` python
np.polyfit(X,y,deg=1)   
```
`deg` what degree of polynomial do you want to do?
`deg` = 1 --> x
`deg` = 2 --> x^2
`deg` = 3 --> x^3

#important/simple-lr
y=B1x+B0
```python
np.polyfit(X,y,3) #y= B3x**3 + B2*x**2 + B1x+ B0
```

^3
```python
pred_sales= 3.07615033e-07 * pot_spend **3 + -1.89392449e-04*pot_spend**2 + 8.20886302e-02*pot_spend+2.70495053e+00
```




