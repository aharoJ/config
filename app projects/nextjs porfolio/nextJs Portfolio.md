

# Target
`target={'_blank'}`

```js
<Link href='/dummy.pdf' target={'_blank'}> Dummy</Link>
```
Setting `target="_blank"` on a link element opens the link in a new browser tab or window. This is often used for external links so that the user can keep the current page open while visiting the linked content.

By default, when a link is clicked, the browser will navigate away from the current page and load the linked content in the same tab. However, using `target="_blank"` instructs the browser to open the linked content in a new tab or window, without navigating away from the current page. This can be useful for situations where you want the user to be able to easily return to the original page, such as when linking to external websites or resources.


# Download

This will download the pdf but not open a tab... gonna come in handy I knowit 
```js
download={true}
```

if (ref.current && latest.toFixed(0) <= value){
ref.current.textContent= latest.toFixed()
}

# useEffect Snippet
```js
useEffect(() =>

{
	if (isInView)
	{
		motionValue.set()
	}
}, [Dependency])
```




# Underline Color
```js
<h2 className='capitalize text-xl font-semibold hover:underline hover:underline-offset-4 hover:decoration-sky-400/80'>{title} </h2>
```











