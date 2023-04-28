
## Vite web-tool

``` js
npm create vite@latest ./ -- --template react 
```

instead of `npm start`

```js
npm run dev
```

## Packages
### tailwindcss

``` tailwind
npm install -D tailwindcss
npx tailwindcss init
```


### allow vite to integrate with React
```js
npm install -D postcss autoprefixer
npx tailwindcss init -p
```
.
.
.
lecgacy
```js
npm install  --legacy-peer-deps -D postcss autoprefixer
```
...
isMobile
```js
npm install --legacy-peer-deps react-device-detect 
```


#important/js/packages
## using old packages

```js
npm install --legacy-peer-deps 
```

ie...
```js
npm install --legacy-peer-deps @react-three/fiber @react-three/drei maath react-tilt react-vertical-timeline-component @emailjs/browser framer-motion react-router-dom
```





# CSS TalinWind CSS
w --> width px
h --> height px

```css
className='w-20 h-20 object-contain'/>
```

[object for img](https://tailwindcss.com/docs/object-position)









---
#important/js/dynamic_template
# template literals
![](../../../z/aharo24%202023-03-05%20at%202.26.30%20PM.png)
WRONG
```js
className={'${ active === link.title ? "text-white" : "text-secondary" }'}
```
CORRECT
```js
className={`${active === link.title ? "text-white" : "text-secondary"}`}
```


# mesh
`<mesh>`
we use them instead of `<div>`  when it comes to 3d models. 
Also we need to use useGLTF() function 

additionally we need to add a `light`
```js
    <mesh>
      <hemisphereLight 
```



# psvm but for JS 
```js
rafce
```




## '...' what does it do?

```java
// Unpacking an array into individual arguments for a method call
int[] myArray = {1, 2, 3};
myMethod(...myArray);

// Combining two arrays into a new array using the spread operator
int[] array1 = {1, 2, 3};
int[] array2 = {4, 5, 6};
int[] combinedArray = [...array1, ...array2];
```



## double {{}}

In React, double curly braces are used to indicate that an object is being passed as a prop. In the code snippet you provided, `viewport` is a prop being passed to a component, and its value is an object with two properties: `once` and `amount`. The first set of curly braces is used to indicate that the value being passed to the prop is an object, and the second set of curly braces is used to define the object and its properties.

The `viewport` prop appears to be used for triggering animations when the component is in view. The `once` property indicates that the animation should only be triggered once, and the `amount` property determines how much of the component needs to be in view before the animation is triggered. The specific use case and implementation of this prop will depend on the component and the animation library being used.

## hash-Mapping 

seems to be the standard way of mapping ~(-.-)~
```js
blahhh.map(()=>())}
```

real example:
		example of mapping and generating a map.ofTestimonials Cards --> <FeedBackCard/>
```js
        {testimonials.map((testimonial,index)=>(
          <FeedbackCard
            key={testimonial.name}
            index={index}
            {...testimonial}
          />
        ))}
```


## using the special brackets and not recalling on extern tags 

This just calling the object
```js
<p className={styles.sectionSubText}>
```

Instead this is dynamic block I think... we can extend to other things which is more beneficial 
```js
<p className={`${styles.sectionSubText} 
text-center
font-semibold tracking-tighter bg-gradient-to-r 
from-indigo-500 via-yellow-500 to-pink-500 inline-block 
text-transparent bg-clip-text
`}>
```






---


# Possible Errors

WRONG
```js
hover: text-white text[18px] font-medium cursor-pointer`}
```

CORRECT
```js
hover:text-white text[18px] font-medium cursor-pointer`}
```

```
npm ls three        

portfolio@0.0.0 /Users/aharo/desk/javascript/portfolio
└── (empty)


npm install --legacy-peer-deps three
```

[trying to get the 3d model to work](https://www.youtube.com/watch?v=WBe3xrV4CPM)

## What are props in JS? translation to Java 

In Java, props are not a built-in concept like in React. However, you can achieve similar functionality using method parameters and return values. Suppose you have a `User` class that represents a user and has a `getName()` method and an `getAge()` method:

```java
public class User {
  private String name;
  private int age;

  public User(String name, int age) {
    this.name = name;
    this.age = age;
  }

  public String getName() {
    return name;
  }

  public int getAge() {
    return age;
  }
}
```
To use this `User` class in another class, you can create a method that takes a `User` object as a parameter and returns a string that represents the user's name and age:
```java
public class MyClass {
  public String formatUser(User user) {
    return "Name: " + user.getName() + ", Age: " + user.getAge();
  }
}
```
Here, we're using the `formatUser()` method to "pass props" to the `User` object. We're passing the `User` object as a parameter to the method, and the method is accessing the user's name and age using the `getName()` and `getAge()` methods.

You can call the `formatUser()` method with a `User` object to get the formatted string:
```java
User user = new User("Alice", 25);
MyClass myClass = new MyClass();
String formattedUser = myClass.formatUser(user);
System.out.println(formattedUser); // prints "Name: Alice, Age: 25"
```
This is similar to passing props to a React component, where you pass props as arguments to a method and the method uses the props to render some output. However, the syntax and mechanics of passing props are different in Java compared to React.


## Issue with canvas (balls)

### WRONG
![](../../../z/aharo24%202023-03-08%20at%207.23.32%20PM.png)
### Correct
![](../../../z/aharo24%202023-03-08%20at%207.24.15%20PM.png)


# Size matters

![](../../../z/aharo24%202023-03-12%20at%202.53.41%20PM.png)


issue on my code:
```js
absolute inset-0 top-[80px] xs:top-[50px] max-w-7xl mx-auto flex
```

correct way since we defined it for a size: already 
```js
absolute inset-0 md:top-[80px] xs:top-[50px] max-w-7xl mx-auto flex
```



















---
---

# SRC
[logos](https://logo.com)

[react three fiber ](https://docs.pmnd.rs/react-three-fiber/getting-started/introduction)
	[lights](https://docs.pmnd.rs/react-three-fiber/getting-started/your-first-scene#adding-lights)

[using {} on an import vs not ](https://stackoverflow.com/questions/36795819/when-should-i-use-curly-braces-for-es6-import)



[animation samples](https://framerbook.com/animation/example-animations/1-tween/)

### font
megrim is fire af 
