---
title: synchronized关键字
mathjax: true
data: 2020-12-01 19:54:01
updated: 2020-12-06 13:12:45
tags: 
- synchronized
categories:
- 多线程基础
---

## 预备知识

Java提供的同步机制有许多，`synchronized`是其中最经常使用、最万能的机制之一。
为了学习`synchronized`的实现原理，进而了解到`monior object`模式。在java中`synchronized`辅助实现了该模式。

## 1. monitor机制的起源与定义

在早期，编写并发程序时使用的同步原语是信号量semaphore与互斥量mutex。程序员需要手动操作信号量的数值与线程的唤醒与挂起，想想这也是一个十分麻烦的工作。所以提出了更高层次的同步机制`monitor`封装了信号量的操作。但是值得注意的是`monitor`并未在操作系统层面实现，而是在软件层次完成了这一机制。

下面描述了`monitor`机制之所以会出现的一个应用场景（摘自[探索Java同步机制](https://developer.ibm.com/zh/articles/j-lo-synchronized/)）：

> 我们在开发并发的应用时，经常需要设计这样的对象，该对象的方法会在多线程的环境下被调用，而这些方法的执行都会改变该对象本身的状态。为了防止竞争条件 (race condition，等同于死锁) 的出现，对于这类对象的设计，需要考虑解决以下问题：
1.在任一时间内，只有唯一的公共的成员方法，被唯一的线程所执行。
2.对于**对象的调用者**来说，如果总是需要在调用方法之前进行拿锁，而在调用方法之后进行放锁，这将会使并发应用编程变得更加困难。合理的设计是，该对象本身确保任何针对它的方法请求的会同步并且透明的进行，而**不需要调用者的介入**。
3.如果一个对象的方法执行过程中，由于某些条件不能满足而阻塞，应该允许其它的客户端线程的方法调用可以访问该对象。

我们使用 Monitor Object 设计模式来解决这类问题：**将被客户线程并发访问的对象定义为一个 monitor 对象**。客户线程仅仅通过 monitor 对象的同步方法才能使用 monitor 对象定义的服务。为了防止陷入死锁，在任一时刻只能有一个同步方法被执行。每一个monitor对象包含一个 monitor锁，被同步方法用于串行访问对象的行为和状态。此外，同步方法可以根据一个或多个与monitor对象相关的monitor conditions 来决定在何种情况下挂起或恢复他们的执行。

根据上述定义，monitor object模式分为四个组成部分：

- **监视者对象 (Monitor Object):** 负责定义公共的接口方法，这些公共的接口方法会在多线程的环境下被调用执行。
- **同步方法：** 这些方法是**监视者对象**所定义。为了防止死锁，无论是否同时有多个线程并发调用同步方法，还是监视者对象含有多个同步方法，在任一时间内只有监视者对象的一个同步方法能够被执行（所谓的同步方法也就是我们经常说的临界区）
- **监视锁 (Monitor Lock):** 每一个监视者对象都会拥有一把监视锁。
- **监视条件 (Monitor Condition):** 同步方法使用监视锁和监视条件来决定方法是否需要阻塞或重新执行。这里的监视条件可以来自程序本身也可来自monitor object内部。


这四个部分完成了两个动作：

1. 线程互斥的进入同步方法
2. 完成线程的一些调度动作，例如线程的挂起与唤醒

## 2. Java中的monitor

按照定义，Java下基于`synchronized`的`monitor object`模式也应该由四个部分组成,包括监视者对象、监视锁、监视条件、同步方法（临界区）。那么首先来看看我们一般使用`synchronized`来实现同步的代码：

``` java
class demo{
    Object lock=new Object();
    public void test1(){
        synchronized(lock){
            ...
        }
        ...
    }
    public synchronized void test2(){...}
    public static synchronized void test3(){...}
}
```

在我看到的大部分资料中，都认为上述代码中的`lock`对象是监视者对象，监视条件上面没有展示出来，`synchronized`后跟的代码块就是同步方法。但是这个同步方法并不是在`lock`所在的类`Object`中定义的啊，这如何解释？

>我的理解是这里的“定义”并不是诸如在类`A`中定义一个方法`test`之类的定义，而是规定了某些代码作为同步方法，例如规定字母`A`代表学校，字母`B`代表公司之类的将两个事物联系到一起的定义，就像在上面代码中规定了`{}`中的代码作为`lock`的同步方法

那么监视锁呢？上面完全没有锁的痕迹。原因是基于`synchronized`的`monitor object`模式，监视锁是由监视对象自带的，也被称为`intrinsic lock`。这个锁在java中是由`objectmonitor`实现的，其部分代码如下所示：

``` java


```

那么监视者对象是如何控制这个锁的呢？

在jvm中，任何一个对象都会存在对象头，在使用`synchronized`时，对象头会包含一个对象的`objectMonitor`对象，后者存储了挂起的线程队列、

---
**Extensions：**
上面的“同步方法由监视者对象所定义”这句话一直让我无法理解，我原以为这里的“定义”是指在类`A`中定义一个名叫`test`方法之类的定义。但是如果按照这样理解，那么

---

注意，

我认为这里的监视者是类似下面的概念：



`demo`类的对象称为监视者对象，其中的`test()`方法称为同步方法，




## 参考文献

1. [Java中的Monitor机制](https://segmentfault.com/a/1190000016417017)

2. [探索Java同步机制](https://developer.ibm.com/zh/articles/j-lo-synchronized/)


https://blog.csdn.net/L__ear/article/details/106369509

https://blog.csdn.net/DBC_121/article/details/105453101

https://www.mdeditor.tw/pl/2Z1b