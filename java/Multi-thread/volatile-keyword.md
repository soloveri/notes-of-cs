---
title: volatile关键字
mathjax: true
data: 2020-12-06 13:13:19
updated:
tags: 
- volatile
categories:
- 多线程基础
---

## 1. volatile是什么

volatile被称为轻量级的`synchronzied`，它保证了内存的可见性、指令的有序性。我们通过经典的懒汉单例模式看看这个关键字的作用。

``` java "线程不安全"
public class DraconianSingleton {
    private static DraconianSingleton instance;
    public static  DraconianSingleton getInstance() {
        if (instance == null) {
            synchronzied(this){
                if(instance==null){
                    instance = new DraconianSingleton();
                }
            }
        }
        return instance;
    }
}
```

虽然使用了双锁，但是上述代码仍然是线程不安全的，因为`new DraconianSingleton()`并不是原子操作。这句代码的正常操作是：

1. 分配内存空间
2. 初始化对象
3. 将对象地址赋给引用instance

但是因为操作2和操作3之间没有数据依赖，编译器有理由将这两条指令进行重排。重拍后的操作为：

1. 分配内存空间
2. 将对象地址赋给引用instance
3. 初始化对象

重排后的指令在单线程环境下执行是没有问题的。但是在多线程环境下，如果thread1获得锁并且在执行了第二步之后，`instance != null`,但是对象并没有完成初始化。此时如果thread1时间片到期，切换到thread2。thread2调用`getInstace()`后获得的是一个部分初始化的对象，此时thread2在使用这个对象时很可能会出现意外的错误。

但是使用`volatile`修饰`instance`后，就能够禁止上述的重排现象发生，从而变成线程安全。

``` java "线程安全"
public class DraconianSingleton {
    private static volatile DraconianSingleton instance;
    public static  DraconianSingleton getInstance() {
        if (instance == null) {
            synchronzied(this){
                if(instance==null){
                    instance = new DraconianSingleton();
                }
            }
        }
        return instance;
    }
}
```

## 2.volatile做了什么

volatile能够禁止上述指令重排的原因是因为它在volatile write操作之前插入了内存屏障，禁止volatile write操作之前任何的read/write操作重排序到volatile write之后。在执行`new DraconianSingleton()`时，构造函数肯定会执行write操作，所以构造函数的write操作一定不会被重排序到volatile write操作之后，从而保证了只会在实例化对象完成后才会`instance`赋值。

网上许多文章都说volatile会执行上述的操作禁止指令重排，但是几乎没有人说它为什么这么做。我尝试使用如下代码解释一下我的理解：

``` java
    int a;
    volatile b;
    write(){ //thread 1
        a=1; //opreation 1
        //StoreStore memory barrier
        b=2; //opreation 2
        //StoreLoad memory barrier
    }

    read(){ //thread 2
        if(b==2){ //opreation 3
            sout(a);
        }
    }
```

根据happens before的程序次序原则，o1 hb o2，那么JMM保证o1的执行结果必须被o2看到。我们可以延伸一下，volatile write之前所有的动作结果都应该在volatile write执行时被看到。所以为了实现这个效果，JMM会在volatile write之前插入StoreStore、StoreLoad内存屏障（这是最笨、最稳妥的办法，具体实现时肯定会有相应的优化。
根据happens before的volatile变量规则，o2 hb o3，JMM保证o2（volatile写）的执行结果必须被o3（volatile读）看到。为了实现这个效果，需要借助StoreLoad内存屏障的力量。

**所以volatile做这些工作都是为了实现happens before relation**。内存屏障只是volatile实现happens before的**技术手段**。并且volatile并不会刷新内存，那不是它的责任，刷新内存是内存屏障的作用。

---

**对于volatile的一些小疑问：**

**Q1：对于volatile write(A) hb volatile read(B)，是不是只有A先比B发生，JMM才会使用内存屏障达到B一定能够看到A的效果（即实现 A hb B）。也就是说，如果A没有比B先发生，JMM就不会使用内存屏障实现A hb B了？**

很明显这个表述是有问题的，但是我一直不知道如何否定这个逻辑。经过几天的思考，我给出我的理解：
对于volatile write(A) hb volatile read(B)，JMM不管A与B谁先发生，它只管使用内存屏障达到：如果A发生，B就能看到结果的效果（换言之，JMM按照理想情况，A先发生B后发生的情形插入内存屏障）。这样就会有：

- 如果A比B先发生，那么就能实现A hb B的效果
- 如果B比A先发生，那么虽然插入了内存屏障，但是也没有产生什么负面效果

**Q2：volatile真的禁止重排序了吗？**

我认为volatile并没有这么做，volatile它只是借助内存屏障禁止volatile write之前的任何read/write重排序到volatile write之后，至于那些read/write操作到底如何重排序，volatile并不care

---

## 3. volatile如何使用

首先我们需要知道volatile只有read/write操作具有原子性，剩余的基于volatile的算数运算并没有原子性。例如：

``` java
    volatile int j=0;
    void clac(){
        for(int i=0;i<5;i++){
            new Thread(){
                public void run() {
                    for(int j=0;j<1000;j++)
                        j++;
                };
            }.start();
        }
    }
```

上述`j++`并不具有原子性。想象以下多线程的场景：

`j`默认初始化为0。首先thread读取到`j=0`，然后进行`+1`操作，但是在将1赋给`j`之前，时间片用完，所以此时并没有volatile write操作。切换到thread2，thread2读取到的`j`仍然为0，并且完成了`+1`的动作。这样在thread2完成之后，其他所有的线程读取到的`j`肯定都为`1`。但是thread1此时不需要读取`j`了，它只会完成最后一步的volatile write动作。出现了线程安全问题。所以说volatile只有read/write操作具有原子性。

上面出现问题的原因是什么呢？

>多个线程都能够修改同一个volatile的值，并且目标修改值依赖volatile变量的前一个值

所以为了避免上述缺陷，volatile的理想使用场景是：

1. 可以有多个线程修改volatile变量，但是修改后的值不应该依赖volatile变量之前的值

2. volatile变量不需要与其他变量构成约束条件（我理解的约束条件是导致控制流发生改变的条件）

规则1很好理解，对于规则2的理解见如下代码：

``` java
//代码摘自：http://kael-aiur.com/java/java%E4%B8%ADvolatile%E5%85%B3%E9%94%AE%E5%AD%97.html
public class NumberRange {
    private volatile int lower, upper;

    public int getLower() { return lower; }
    public int getUpper() { return upper; }

    public void setLower(int value) { 
        if (value > upper) 
            throw new IllegalArgumentException(...);
        lower = value;
    }
    public void setUpper(int value) { 
        if (value < lower) 
            throw new IllegalArgumentException(...);
        upper = value;
    }
}
```

在上面的代码中，如果lower与upper初始化为(0,5)。两个线程分别调用`setLower`和`setUpper`，将（lower,upper）设置为（4，3）。这样的区间是没有意义的，之所以会出现这样的错误是因为约束条件为`value>upper`，`volatile`与`value`共同参与了不变约束。

## 参考文献

1. [What is the point of making the singleton instance volatile while using double lock?](https://stackoverflow.com/questions/11639746/what-is-the-point-of-making-the-singleton-instance-volatile-while-using-double-l/11640026#11640026)