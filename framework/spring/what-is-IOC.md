---
title: IOC到底是什么？
mathjax: true
data: 2021-03-12 18:48:08
updated:
tags: Spring
categories: framework
---

这篇博文：[浅谈IOC--说清楚IOC是什么](https://www.cnblogs.com/DebugLZQ/archive/2013/06/05/3107957.html)讲的不错，我在此就是做一些摘抄。

---

## 1. IOC是什么？

IOC，Inversion of Control，译为控制反转。

1996年，Michael Mattson在其论文:[Object-Oriented FrameworksA survey of methodological issues](https://www.researchgate.net/publication/2238535_Object-Oriented_Frameworks)中，首先提出了IOC这个概念，IOC是一个方法论。

简单来说，IOC的概念仅适用于面向对象的框架，而不面向于库函数。如果使用了框架，那么不再是程序员控制程序的所有流程，而是框架控制我们书写的程序，我们写的程序仅仅是为了适应框架。

对于面向对象的框架，IOC用于把复杂系统分解成相互合作的对象，这些对象类通过封装以后，内部实现对外部是透明的，从而降低了解决问题的复杂度，而且可以灵活地被重用和扩展。

**IOC理论提出的观点大体是这样的：借助于“第三方”实现具有依赖关系的对象之间的解耦。**

## 2. 控制了什么？

![origin](https://images0.cnblogs.com/blog/281227/201305/30130748-488045b61d354b019a088b9cb7fc2d73.png)

软件系统在没有引入IOC容器之前，如上图所示，对象A依赖于对象B，那么对象A在初始化或者运行到某一点的时候，**自己必须主动**去创建对象B或者使用已经创建的对象B。无论是创建还是使用对象B，控制权都在自己手上。

![IOC](https://images0.cnblogs.com/blog/281227/201305/30131727-a8268fe6370049028078e6b8a1cbc88f.png)
软件系统在引入IOC容器之后，这种情形就完全改变了，如上图所示，由于IOC容器的加入，对象A与对象B之间失去了直接联系，所以，当对象A运行到需要对象B的时候，IOC容器会主动创建一个对象B注入到对象A需要的地方。

通过前后的对比，我们不难看出来：**对象A获得依赖对象B的过程,由主动行为变为了被动行为**，控制权颠倒过来了，这就是“控制反转”这个名称的由来。**所谓的控制就是依赖资源的控制权**。

## 3. 反转了什么？

2004年，Martin Fowler探讨了同一个问题，既然IOC是控制反转，那么到底是“哪些方面的控制被反转了呢？”，经过详细地分析和论证后，他得出了答案：**“获得依赖对象的过程被反转了”**。控制被反转之后，获得依赖对象的过程由自身管理变为了由IOC容器主动注入。于是，他给“控制反转”取了一个更合适的名字叫做“依赖注入（Dependency Injection）”。他的这个答案，实际上给出了实现IOC的方法：注入。所谓依赖注入，就是由IOC容器在运行期间，动态地将某种依赖关系注入到对象之中。

所以，依赖注入(DI)和控制反转(IOC)是从不同的角度的描述的同一件事情，就是指通过引入IOC容器，利用依赖关系注入的方式，实现对象之间的解耦。

## 4. 代码示例

``` java
public class UserServiceImpl {
    
    private UserDao u;
    public UserServiceImpl(){
        //UserServiceImpl的依赖对象是通过其自己生成的，耦合度较高
        //如果现在想用Oracle的实现类，那么就需要手动更改下面的代码
        u=new MySQLImpl();
    }
    public void service(){
        u.use();
    }
}
```

上面代码中的`UserServiceImpl`和其依赖的资源`UserDao`是一个强耦合的现象，**我们需要知道具体调用的是哪个实现类，构造方法的参数是什么**，如果想要换成另外的实现类，复杂程度会随着应用的复杂程度而增加。所以为了降低对象之间的耦合度，可以采取以下注入的方式的降低耦合度：

``` java
public class UserServiceImpl {
    
    private UserDao u;
    public UserServiceImpl(UserDao u){
        //通过注入的方式将UserServiceImpl的依赖添加进来
        this.u=u;
    }
    public void service(){
        u.use();
    }
}
```

所以上面实现了一次控制反转，在`UserServiceImpl`中我们并**不需要知道UserDao具体的实现类是什么，如何生成的，我们只管使用**。依赖资源的生成不再由主动使用方控制，而是由第三方控制，被动地接收第三方提供的资源。这里的第三方在Spring中就是IOC容器。

## 5. 使用IOC容器有什么好处？

如果我们手动地实现控制反转，那么我们必须手动地写很多new，并且需要了解各个对象的构造函数，例如对于上面的`UserServiceImpl`，使用的流程一般如下：

``` java
public class Main{
    ...main(){
        UserDao u=new MySQLImpl();
        UserServiceImpl i=new UserServiceImpl(u);
    }
}

```

如上所示，还是显示的使用了new，当依赖对象一旦多了起来，new的数量就会急剧增加，并且还要了解各个依赖对象的构造方法。所以IOC容器的好处就是：

1. 因为采用了依赖注入，在初始化的过程中就不可避免的会写大量的new。这里IoC容器就解决了这个问题。这个容器可以自动对你的代码进行初始化，你只需要维护一个Configuration（可以是xml可以是一段代码）
2. 我们在创建实例的时候不需要了解其中依赖资源的细节


## 参考文章

1. [About inversion of control](https://labs.madisoft.it/about-inversion-of-control/)
