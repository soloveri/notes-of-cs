---
title: java的字符串
mathjax: true
data: 2020-04-08 17:00:57
updated: 2021-02-26 00:11:31
tags:
- String
categories:
- Java
---

java的所有字符串都会保存在全局字符串池中，在了解全局字符串池之前，我们需要明白：在java中，所有的字符串字面值都会被解释为一个字符串对象。

> All string literals in Java programs, such as "abc", are implemented as instances of this class

接下来我们聊聊全局字符串池。全局字符串池在jdk1.7后也是堆的一部分，不属于某个类，被所有线程共享。那么这个字符串池有啥用？

> String pool helps in saving a lot of space for Java Runtime although it takes more time to create the String.

由上可知，字符串池的创建是为了在运行时节省空间。字符串常量池跟创建字符串的方式息息相关。首先创建字符串的方式有两种：

``` java
String s1="test";
String s2=new String("test");
String s3=new String("abc");
String s4=new String("bc");
String s5="a"+s4;

System.out.println()
```

首先我们应该明白一个理念：就是所有能够在编译时确定的常量都会放在`constant_pool table`中，相对应的任何引用在编译期都无法确定。比如上面代码中的`test`、`abc`字面值都会作为String对象并在编译后加入当前class的`constant_pool table`中。在运行时会被解释为String对象加入字符串常量池。String的intern方法非常特殊。下面来详解关于String intern的一切。

## Intern的用法

在解释关于intern的相关操作时，我们首先需要知道什么是intern。
> String.intern()是一个Native方法，它的作用是 ： 如果字符串常量池已经包含一个内容等于当前String对象的字符串对象，则返回代表字符串常量池中的内容相同的字符串的对象；否则将此 String对象的引用地址（堆中）添加到字符串常量池中。**jdk 1.7 后的字符串常量池存在于堆中。**

### 字符串已加入字符串池后Intern

``` java
    String s1="abc";
    String s2=new String("abc");
    String s2Intern=s2.intern();
    System.out.println("s2Intern==s2: "+(s2Intern==s2));//flase
    System.out.println("s1==s2Intern: "+(s1==s2Intern));//true
```

在加载类后，`abc`这个字面值已经加入字符串池。因为这个在编译时就能确定。

在执行第一句后，`abc`会加入字符串池中，s1是指向该字符串的引用。

在执行第二句时，会在堆内创建一个String对象。该对象的字面值为`abc`。

第三句s2调用Intern时，会使用`equals`方法在字符串池中找与s2内容相同的字符串，能找到吗？当然，因为前一句执行完，`abc`这个字面值已经加入字符串池中。

第四句比较`s2`与`s2Intern`，`s2`是堆中`abc`的引用，`s2Intern`是字符串池中`abc`的引用。结果自然为false，因为都不是一个东西。

而第五句比较`s1``s2Intern`是否相等。`s1`是字符串池中`abc`的引用，`s2Intern`得到的也是字符串池中`abc`的引用，结果自然为true。

### 字符串未加入字符串池Intern

``` java
    String bb = new String("123") + "456";
    String bbIntern = bb.intern();
    System.out.println("bb==bbIntern    " + (bb == bbIntern));//true

    String str="123456";
    System.out.println("str== bb: "+(str==bb));//true
    System.out.println("str==bbIntern: "+(str==bbIntern));//true
    
    String cc=new String("12")+"3";
    String ccIntern=cc.intern();
    System.out.println("ccIntern==cc: "+(ccIntern==cc));//false
```

仍然对每句进行解读：

第一句：`123`、`456`这两个字面值会加入字符串池，但是`123456`并没有字符串池。

第二句：bb调用intern()查看在字符串池中是否有`123456`，当然没有。那就把堆中包含`123456`的对象bb的引用加入字符串池中并返回该引用。

第三句：`bb`和`bbIntern`保存的都是堆中`123456`对象的引用，地址自然相等。

第四句：`str`中保存的是字符串池`123456`的引用，也就是对象bb的引用，二者自然相等。

第五句：在字符串池中查找`123456`找到了，就是执行第二句时新添加到池中引用。二者自然相同。

第六句：把`12`、`3`两个字面值加入字符串池中，和`123`还是有区别的。

第七句：`cc`调用intern(),返回的当然是早已在第一句已经添加到池中的`123`的引用。

第八句：`ccIntern`保存的是池中`123`引用，而`cc`保存的是堆中`123`的引用，地址自然不相同

### 字符串到底创建几次的经典问题

``` java
String str=new String("123");
```

上述代码中到底创建了几个对象?
这得看常量池中有没有`123`这个String对象，如果有，那么只会在堆中创建一个String对象，然后该String对象中的`123`字符串对象会引用字符串常量池中的`123`String对象。如果没有，那么`123`这个String对象会被添加到字符串池中，然后在堆中也会创建一个包含`123`的String对象。**注意这两个对象一个在堆里面，一个在字符串池里面，肯定不是一个东西**

可以看出，字符串池相当于一个共享缓存，如果引用的字符串的字面值相同，那么它们就会引用字符串池中的同一个字符串。(前提是使用intern()方法)

### intern()方法小结

如果查询的字符串在字符串池中有，那么就返回字符串池中引用。如果没有，就把堆中的字符串对象引用加入字符串池中，然后返回该引用。

### 字符串进入字符串池的时机

我觉的如果时`String s1="abc"`这种形式构造字符串，那么就确定了s1中的内容，不需要等到运行时解决，应该直接会加入字符串池中。反之，如果使用`String s2=new String("123")`这种形式构造字符串，s2的值是没办法编译时解决的，但是`123`这个字面值还是会放到类常量池中。

这个问题我现在还没有答案，待定。

## 总结

constant_pool table是`.class`文件的一部分，run time constant table是类的一部分，而类又被放在方法区中，方法区又是堆的一部分。String pool也是堆的一部分
常量池是为了避免频繁的创建和销毁对象而影响系统性能。

**参考文献**
<a href=https://www.journaldev.com/797/what-is-java-string-pool>字符串池解析</a>
<a href=https://examples.javacodegeeks.com/core-java/lang/string/java-string-pool-example/>字符串简单剖析</a>
<a href=https://juejin.im/entry/5a4ed02a51882573541c29d5>深度解析字符串池,必看</a>
<a href=https://cloud.tencent.com/developer/article/1450501>深度解析java常量池</a>