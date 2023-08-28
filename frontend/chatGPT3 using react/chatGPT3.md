


![](aharo24%202023-02-28%20at%2012.34.15%20AM.png)

---
## BEM
java:
	camelCase

Js:
	BEM
	Block Element Modifier

![](aharo24%202023-03-02%20at%2012.40.41%20AM.png)

---

# NavBar
![](aharo24%202023-02-28%20at%202.31.44%20AM.png)

![](aharo24%202023-02-28%20at%202.33.43%20AM.png)

![](aharo24%202023-02-28%20at%202.32.11%20AM.png)

`<p> its a p-tag <p/> `



## use state
- its for `Dynamic` state

```js
import React, { useState } from 'react';
```


## react fragments
```js
  <> 
    <p><a href='#home'>Homeee</a></p>
    <p><a href='#gp3'>What is GPT3?</a></p>
  </>
```



## invoking

```java
Menu myMenu = new Menu();
```

```js
<Menu/>
```

### displays

this hides it
```js
display: none
```

this shows it
```js
display: flex
```


## margins 

possible issues with margin design 

![](aharo24%202023-03-02%20at%201.36.36%20AM.png)

```css
margin: 0 0 0 1rem;
```


```css
margin: 0     0     0     0;
        top right bottom left
```



---
## ID 

Using JSX and CSS with a unique identifer ( ID )

![](aharo24%202023-03-02%20at%202.01.19%20AM.png)


```css
@media screen and (max-width: 650px) 
{
    .gpt3__header h1
    {
        font-size: 20px;
        line-height: 25px;
    }
    
    p#peoplevisits
    {
        font-size: 10;
        line-height: 15px;
    }

    .gpt3__header-content
    {
        margin: 0 0 3rem;
    }
}
```

---

## Features stuff
instead of 
```js
<Features/>
```

#### we can do an array and use a map

array
```js
const featuresData=
[
  {
  title: 'Improving end distrusts instantly ',
  text: 'From they fine john he give of rich he. They age and draw mrs like. Improving end distrusts may instantly was household applauded.'
  },
  {
  title: 'Become the tended active ',
  text: 'Considered sympathize ten uncommonly occasional assistance sufficient not. Letter of on become he tended active enable to.'
  },
  {
  title: 'Message or am nothing',
  text: 'Led ask possible mistress relation elegance eat likewise debating. By message or am nothing amongst chiefly address.'
  },
  
  {
  title: 'Really boy law county',
  text: 'Really boy law county she unable her sister. Feet you off its like like six. Among sex are leave law built now. In built table in an rapid blush.'
  }
]
```

map
```js
        {featuresData.map((item, index)=> (
          <Feature title={item.title} text={item.text} key={item.title + index}/>
        ))}
```

## flex
probably the most important thingy in Js soo far

```js
 display: flex;
```

this allows use to modify soo much 
```js
padding: 0.5rem 1rem;
```

```js
margin-left: 1rem;
```



for articles/blogs

```js
grid-template-columns: repeat(1,1fr);
```




## HREF

very professional way
```js
<div> <a href="https://www.linkedin.com/in/aharoJ/"> <img src={linkedin} alt='linkedin profile'></img> </a> </div>
```

easy way
```js
<a href="https://www.linkedin.com/in/aharoJ/"><img src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white" alt="Linkedin" /></a>
```










# Commands

replace multiple same words:
	--> opt + click_onword
	--> cmd+d 

# Sources

[color grading](https://angrytools.com/gradient/)

[animation tool](https://animista.net)

[idk but this tool looks wild](https://www.figma.com)




