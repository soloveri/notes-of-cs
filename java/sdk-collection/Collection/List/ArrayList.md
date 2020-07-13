## 前言

分析源码初体验，第一次分析个比较简单的集合类ArrayList。我把重点放在了ArrayList实现的接口、继承的类以及几个主要的类方法上。

### ArrayList继承图

我们首先来看看ArrayList中的继承图。

![ArrayList继承图](images/arrayList-hierarchy.png)

`ArrayList`继承自抽象类`AbstractList`,并且实现了`RandomAccess`、`Cloneable`、`Seriablizable`、`List`接口。

这里我首先有了两个疑惑:

- 接口与ArrayList之间为什么隔了一个抽象类`AbstractList`?
- 抽象类`AbstractList`已经实现了`List`接口，为什么ArrayList又实现了一遍？

对于**第一个**问题可以从设计模式的角度回答，因为接口`List`中的抽象方法是非常多的，如果`ArrayList`直接实现了该接口，那么`ArrayList`必须实现`List`中的所有抽象方法，尽管有些方法用不到。那么为了解决这个问题，JDK在接口与实现类中间添加一个抽象类，虽然抽象类不能生成对象，但是也可以实现接口中的抽象方法的，JDK中的AbstractList实现了一些非常非常通用的方法。ArrayList来继承上述的抽象类，这样ArrayList仅需实现AbstractList中没有实现的抽象方法，对于AbstractList已经实现的抽象方法，ArrayList可以自由选择实现与否。

也就是说抽象类AbstractList给了ArrayList需要实现的抽象方法的选择空间。

对于**第二个**问题,答案获取有些不那么令人信服，经过网上资料查阅，说是JDK的开发人员人为ArrayList实现List接口可能会对后序的开发有帮助，久而久之，就一直延续下来，造成了现在的局面。

ok，这两个问题解决了，我们继续向下探索。

### ArrayList实现的接口

ArrayList实现了`RandomAccess`、`List`、`Cloneable`、`Serializable`接口。

**RandomAccess接口:**

这个`RandomAccess`是一个marker interface(该接口内什么都没有实现，仅仅是作为一个标记接口)。简单来说，实现了该接口的类就一定拥有随机访问的能力。所以我们在遍历一个类的时候，建议我们首先使用`instanceOf`判断当前类是否为`RandomAccess`的实现类，如果时，那么采用for循环(p普通for循环，而不是增强型for循环，因为增强型内部也是使用迭代器)遍历比采用迭代器的平均性能更好。

**List接口:**

上一小节已经回答了该问题，开发人员的笔误。 :)

**Cloneable接口:**

虽然官方文档没有说明该接口是marker interface,但我感觉作用差不多，实现了该接口的类，那么该类的`clone`方法就是可用的，允许对象的字段复制。

**Serializable接口:**

作用也相当于一个marker interface，标识实现类是可序列化与反序列化的。

### ArrayList中的重要字段与方法

``` java

    //序列化ID
    @java.io.Serial
    private static final long serialVersionUID = 8683452581122892189L;

    /**
     * Default initial capacity.
     */
    //ArrayList的默认大小为10
    private static final int DEFAULT_CAPACITY = 10;

    /**
     * Shared empty array instance used for empty instances.
     */
    //这个和下面的区别就是采用无参构造函数时使用这个，大小为0的Object数组
    private static final Object[] EMPTY_ELEMENTDATA = {};

    /**
     * Shared empty array instance used for default sized empty instances. We
     * distinguish this from EMPTY_ELEMENTDATA to know how much to inflate when
     * first element is added.
     */
    //下面这个数组是在采用提供大小的构造函数但是提供的参数有误时使用的
    private static final Object[] DEFAULTCAPACITY_EMPTY_ELEMENTDATA = {};

    /**
     * The array buffer into which the elements of the ArrayList are stored.
     * The capacity of the ArrayList is the length of this array buffer. Any
     * empty ArrayList with elementData == DEFAULTCAPACITY_EMPTY_ELEMENTDATA
     * will be expanded to DEFAULT_CAPACITY when the first element is added.
     */

    //这个数组是实际存储元素的数组，不是不知道为什么不是private的啊，按道理来说即使是private也不影响内部类访问啊。
    //注意这个数组是不参与序列化的
    transient Object[] elementData; // non-private to simplify nested class access

    /**
     * The size of the ArrayList (the number of elements it contains).
     *
     * @serial
     */
     //List的大小是参与序列化的哦
    private int size;
```

其实ArrayList还有一个非常重要的属性`modCount`，继承自抽象类`AbstractList`，这个属性保证了在多线程环境下及时终止错误。