---
title: 关于泛型的常见问题
mathjax: true
data: 2020-08-14 20:59:33
updated:
tags:
- 泛型
categories: 基础
---

## 前言

这里罗列一些关于泛型的常见问题,并给出解答。其中本篇大多数问题来自[Java Generics FAQs - Generic And Parameterized Types](http://www.angelikalanger.com/GenericsFAQ/FAQSections/ParameterizedTypes.html),我这里仅翻译一些我认为比较容易糊涂的问题。

当然,在解答这些问题时,我们需要牢记一个概念,通配符`?`表示的是不知道是什么类型,而不是任意类型。  

## 1. 使用通配符时经常出现的capture#XXX of ? 到底什么意思?

在使用通配符时,我们很有可能会遇到类似`capture#337 of ?`这样莫名奇妙的错误。其中`capture`是捕获的意思,捕获的是通配符`?`,那么`#337`又代表着什么?这一切都要从捕获转化(Capture Conversion)开始说起。

让我们思考一个问题,如果我们定义定义一个泛型类C如下(类似于List容器)如下:

``` java
class C <T extends Number>{
    ...
    T get();
    void add(T)
}

C<?> c=new C<Integer>()
```

那么通过`c`调用对象方法时,方法的签名是什么样的?像下面这样?(编译时期泛型还是存在的)

``` java
class C <? extends Number>{
    ...
    ? get();
    void add(?);
}
```
这显然是毫无意义的,但是我们知道实例化类时一定会使用一个具体的类型X\:\< Number( **:<** 表示前者继承于后者),尽管我们不知道这个X到底是什么类型的。这并不重要。那么被具体类型X实例化的类C长下面这样:

``` java
class C<X>{//X:<Number
    ...
    X get();
    void add(X);
}
```
使用一个具有名字的类型比使用通配符`?`容易多了。所以编译器也是这么做的。只不过编译器并不会使用`X`,而是随机使用一个数字,例如`#337`表示上面这个通配符。所以才会有了这句`capture#337 of ?`。即编译将遇到这个统配符`?`分配了一个名字叫做`#337`。

当一个对象的类型是通配符类型,编译器会使用类型变量替换**每一个**遇到的通配符`?`(类型变量中的数字按序增长),这种操作名为`capture conversion`,通过这个操作,编译器只需要处理带有具体类型的对象。

对于上面的例子,`get()`方法返回一个`X`类型的引用,其中`X:<Number`,那么我们就可以执行下述操作:
>Number n= c.get();//c为类C的实例,get方法返回的是Number类型

但是我们却不能向c中添加元素。

> c.add(number)//add方法接受的参数为类型为capture#1 of ?

因为add方法接受的参数类型为x(编译器的名字可能为capture#1 of ?),而容器c中的引用至少都为Number类型,因为容器内的元素类型都有一个限制:`? extends Number`,所以编译器出于安全,将容器内的引用推断为`Number`类型肯定是不会错的。
那么一个存储`Number`类型的容器,能接受一个类型为`capture#1 of ?`的值吗?不知道,因为后者的类型编译器无法推断,所以为了保险起见,直接会产生编译错误。

只要有表达式产生了`wild type`的**value**(The compiler applies capture conversion on every expression that yields a value in wild type),`capture conversion`操作就存在。并且会为每个通配符`?`分配一个唯一ID。以下面代码为例:

``` java
List<? extends Number> foo(List<? extends Number> numberList)
{
#1  for(Number number : numberList)
#2      assert numberList.contains(number);
#3  numberList = numberList;
#4  return numberList;
}
```

上面代码有四个地方都存在`wild type`的变量,我们一个一个来分析。

对于`#1`处的`numberList`,其类型为`List <? extends Number>`,那么会将这处的`numberList`转换为`List<X1>`类型,`List<X1>`是`Iterable<X1>`的子类,所以可以使用for循环遍历,number的类型是`X1`,又因为`X1:<Number`,所以其可以向上转型为`Number`

对于`#2`处的`numberList`,编译器会将其类型转换为`List<X2>`类型,其中的`contains`方法是`List<X2>`类型下的`contains`方法,所以该方法接受一个`X2`类型的参数

对于`#3`处的右`numberList`,编译器会将其类型转换为`List<X3>`,但是！！！对于左边的`numberList`,因为其是一个variable,而不是一个value,所以编译器不会对其类型进行转换,还是`List<? extends Number>`,将`List<X3>`类型赋值给`List<? extends Number>`类型是合法的,因为`X3:<Number`。**那么是否可以认为左侧的都是variable,而右侧的是value???**

对于`#4`处的`numberList`,编译器同样会转换为`List<X4>`后返回。

上面的转换规则非常重要,我们再来看一个难一点的例子。现在有一个map,类型为`Map<?,?> map`,那么如果进行如下操作是合法的:
``` java
for(Entry<?,?> entry : map.entrySet())
```
因为`map`会被转型为`Map<X1,X2>`类型,那么返回的entrySet就是`Set<Entry<X1,X2>>`,因为`X1<:?`,`X2<:?`,所以将`Entry<X1,X2>`类型赋值给`Entry<?,?>`类型是合理的。但是下面的操作就非法了

``` java
Set<Entry<?,?>> entrySet = map.entrySet(); // compile error
```
很简单,错误原因是因为泛型不是协变的,`Set<Entry<X1,X2>>`不是`Set<Entry<?,?>>`的子类。比较笨拙的办法是在定义一个`wild type`,如下所示:
``` java
Set<? extends Entry<?,?>> entrySet=map.entrySet();
```

其实还有一个比较取巧的办法,通过名为`capture helper`的操作来解决这个问题。

### Capture Helper

因为编译器对于`wild type`的取名都是任意的,并且对我们是不可见的,所以我们在源码中无法引用,以下面的代码为例:

``` java
void bar(List<? extends Number> numberList)
{
    // numberList.add( numberList.get(0) ); // compile error,因为左numberList接受的是X2类型,而又numberList接受的是X1类型

    //假设下面的代码存在,我们将传进来的numberList转型为List<X>类型,那么该方法所有使用numberList的地方,其类型是List<X>
    //而不是见一个numberList换一个类型
    List<X> list = numberList;  // *imaginary* code

    X number = list.get(0);     // get() returns X
    list.add(number);           // add() accepts X
}
```

既然人为定义`wild type`的类型,可行,那么我把类型`X`定义出来不久好了?如下面代码所示:

``` java
<T extends Number> void bar2(List<T> list)
{
    T number = list.get(0);
    list.add(number);
}
```
然后我们就可以调用`bar(numberList)`解决上面每个`numberList`类型不一样的问题。方法`bar2`就叫做`capture helper`。

那么`capture helper`的出现有什么意义呢?
答案是为了兼容老代码,因为1.5之前的代码没有泛型,如果使用泛型的代码想要接受没有泛型的容器,就得实现`capture helper`(当然不局限于容器,这里容器比较典型)

**参考文献:**

1. [Capturing Wildcards](http://bayou.io/draft/Capturing_Wildcards.html#Capture_Everywhere)

2. [Wildcard Case Studies](http://bayou.io/draft/Wildcard_Case_Studies.html#Map&lt;?,?&gt;_Entry_Set)

## 2. <? extends E>于<T extends E>有什么区别?
https://stackoverflow.com/questions/18384897/what-is-difference-between-extends-object-and-e-extends-object

## 3. <T super E>为什么是非法的?

https://stackoverflow.com/questions/2800369/bounding-generics-with-super-keyword

## 为什么定义泛型类时不能使用通配符?

https://blog.csdn.net/qq_27093465/article/details/73249434


