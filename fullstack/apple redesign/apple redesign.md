White List all domains
to allow nextJs to rended the lazy images



## href
if you want to source from an online image... youhave 

## [Objectfit](https://stackoverflow.com/questions/74213106/how-to-use-objectfit-for-next-js-13-image)

old 
```
<Image src="/logo.png" layout="fill" objectFit="contain" alt='lala'/>
```

new
```

```


### plugin
- [ ] [prettier with css](https://tailwindcss.com/blog/automatic-class-sorting-with-prettier)

``` npm
npm install -D prettier prettier-plugin-tailwindcss
```


In order for the link to work it can only have one child
```
    <Link href='/'>
      <div className='relative  w-5 cursor-pointer opacity-75 transition hover:opacity-100 h-10'>
        <Image src="/logo.png" layout="fill" style={{objectFit:"contain"}} alt='lala'/>
      </div>
    </Link>
```

# Components
## Link <>
its the same as `<A>` tagg but on steroids


# HeroIcons
- [ ] [documentation + install](https://github.com/tailwindlabs/heroicons)



# Ports
Killing ports 
``` cli
npx kill-port [3333]
```




# Breakpoints
- [ ] sm: screens that are at least 640 pixels wide
- [ ] md: screens that are at least 768 pixels wide
- [ ] lg: screens that are at least 1024 pixels wide
- [ ] xl: screens that are at least 1280 pixels wide
- [ ] 2xl: screens that are at least 1536 pixels wide

for example.... a md:flex 
- it wont show unless the device is 768px >= 766px



# Image nextJs
whenever we do 
`objectFit`
we  need
`relative`
```html
        <div className="relative">
            <Image src='/iphone.png' layout="fill" objectFit="contain"/>
        </div>
```

# compulsory

: --> compulsory
here, `title` is mandatory to have title
``` ts
interface Props 
{
    title: string;
    onClick?: ()=> void;
    width?: string;
    loading?: boolean;
    padding?: string;
    noIcon?: boolean;
}
```


# backend in nextJs
anything inside /api... is backend
![](aharo24%202023-03-26%20at%2010.31.04%20PM.png)
else:
everything else is frontend





# env
whenever you change anything from `env` you need to restart the server 



# backend
```cli
npm run dev        
```






