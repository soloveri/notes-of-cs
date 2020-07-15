## 前言

分析源码初体验，第一次分析个比较简单的集合类ArrayList。我把重点放在了ArrayList实现的接口、继承的类以及几个主要的类方法上。

### 0x0 ArrayList继承图

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

### 0x1 ArrayList实现的接口

ArrayList实现了`RandomAccess`、`List`、`Cloneable`、`Serializable`接口。

**RandomAccess接口:**

这个`RandomAccess`是一个marker interface(该接口内什么都没有实现，仅仅是作为一个标记接口)。简单来说，实现了该接口的类就一定拥有随机访问的能力。所以我们在遍历一个类的时候，建议我们首先使用`instanceOf`判断当前类是否为`RandomAccess`的实现类，如果时，那么采用for循环(p普通for循环，而不是增强型for循环，因为增强型内部也是使用迭代器)遍历比采用迭代器的平均性能更好。

**List接口:**

上一小节已经回答了该问题，开发人员的笔误。 :)

**Cloneable接口:**

虽然官方文档没有说明该接口是marker interface,但我感觉作用差不多，实现了该接口的类，那么该类的`clone`方法就是可用的，允许对象的字段复制。

**Serializable接口:**

作用也相当于一个marker interface，标识实现类是可序列化与反序列化的。

### 0x2 ArrayList中的重要属性与方法

#### ArrayList的属性

ArrayList的属性不是很多，但是有一个非常重要的属性`modCount`，继承自抽象类`AbstractList`，这个属性保证了fast-fail机制,这会在后面讲解方法的时候提到。

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

    //这个数组是实际存储元素的数组，不知道为什么不是private的啊，按道理来说即使是private也不影响内部类访问啊。
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

#### ArrayList中的方法

**构造方法:**
ArrayList中的构造方法有三个:

- 默认无参构造方法
- 初始化容量的构造方法
- 使用集合初始化的构造方法

第一个构造方法没什么好说的,就是使用`DEFAULTCAPACITY_EMPTY_ELEMENTDATA`初始化一个空的Object数组。数组的默认长度为10.

``` java
public ArrayList() {
        this.elementData = DEFAULTCAPACITY_EMPTY_ELEMENTDATA;
    }
```

第二个构造方法提供了一个容量参数,参数必须>=0,否则会抛出非法参数异常。如果容量大小为0,那么则使用`EMPTY_ELEMENTDATA`初始化数组,容量为0。

``` java
public ArrayList(int initialCapacity) {
        if (initialCapacity > 0) {
            this.elementData = new Object[initialCapacity];
        } else if (initialCapacity == 0) {
            this.elementData = EMPTY_ELEMENTDATA;
        } else {
            throw new IllegalArgumentException("Illegal Capacity: "+
                                               initialCapacity);
        }
    }
```

最后一个构造方法使用一个Collection初始化ArrayList,

``` java
public ArrayList(Collection<? extends E> c) {
        elementData = c.toArray();
        if ((size = elementData.length) != 0) {
            // c.toArray might (incorrectly) not return Object[] (see 6260652)
            if (elementData.getClass() != Object[].class)
                //如果c.toArray返回的不是Object数组,那么则需要使用数组工具类的copy方法一个一个复制元素
                elementData = Arrays.copyOf(elementData, size, Object[].class);
        } else {
            // replace with empty array.
            this.elementData = EMPTY_ELEMENTDATA;
        }
    }
```

这里需要提一嘴Arrays中的`copyOf`方法,其中的一个小问题困扰了我很长时间,下面是Arrays中其中一个的`copyOf`的源码:

``` java
public static <T,U> T[] copyOf(U[] original, int newLength, Class<? extends T[]> newType) {

    @SuppressWarnings("unchecked")
    T[] copy = ((Object)newType == (Object)Object[].class) ?
            (T[]) new Object[newLength] :
            (T[]) Array.newInstance(newType.getComponentType(), newLength);
    System.out.println((Object)newType.toString());
    System.arraycopy(original, 0, copy, 0,
                        Math.min(original.length, newLength));
    return copy;
}
```

我一直不理解为什么需要加上`((Object)newType == (Object)Object[].class)`这一句判断，在stackoverflow上看到了一个[答案](https://stackoverflow.com/questions/29494800/do-not-understand-the-source-code-of-arrays-copyof),回答说这句话的目的就是检查`newType`是否持有一个`Object[]`类型的引用,可是这里的newType只有非基本类型的Class对象传进来才能编译成功,否则就会出现无法推断泛型的准确类型???

我好像又懂了,虽然代码里写的是强转Object,但是在运行时`==`比较的是等号两边指的是否为同一个对象,并不是说,我们在代码里把它转成Object了,两边比较的就是Object.