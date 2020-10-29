---
title: HashMap源码分析(一)-HashMap中的那些常量
mathjax: true
data: 2020-07-29 20:22:26
updated:
tags:
- HashMap
categories:
- 源码分析
---

## 前言

HashMap实现了接口`Map`、`Cloneable`、`Serializable`,后两个都是标记接口,注意HasnMap的`clone`方法也仅仅是浅复制(shadow copy)。而`Map`是跟`Collection`并列的顶级接口。并且继承了抽象类`AbstractMap`。

本文将首先简单说说接口`Map`,因为`AbstarctMap`作为实现接口`Map`的骨架,仅实现了一些基本方法,没什么好说的。

### Map接口
``` java
public class HashMap<K,V> extends AbstractMap<K,V>
    implements Map<K,V>, Cloneable, Serializable {
    ...
    }
```

Map提供了三种方法来遍历自身:

- 通过`keySet()`方法返回Map中所有键组成的Set
- 通过`values()`返回Map中values组成的Collection
- 通过`entrySet()`返回由`Map.Entry`组成的Set

前两种都比较常规。值得一提的是第三种方式中的`Map.Entry`。在`Map`接口定义了一个内部接口`Entry`。Entry维护了一组键值对,类似于c++HashMap中的pair结构。这个Entry结构只能通过Map的迭代器获得。并且这些Entry集合**只**在遍历的过程中有效,如果在遍历过程中修改了集合,那么对Entry的操作是未定义的,除非使用Entry定义的`setValue()`方法。

## 1. HashMap中的常量

HashMap中定义了一些比较重要的常量,如下所示:

``` java

    //默认初始容量,必须是2的倍数
    static final int DEFAULT_INITIAL_CAPACITY = 1 << 4; // aka 16

    //HashMap最大的容量,也就是2^30,因为必须是2的倍数
    static final int MAXIMUM_CAPACITY = 1 << 30;

    //扩容因子,如果当前存储的Entry个数达到容量的75%,那么就进行扩容
    static final float DEFAULT_LOAD_FACTOR = 0.75f;

    /**
     * The bin count threshold for using a tree rather than list for a
     * bin.  Bins are converted to trees when adding an element to a
     * bin with at least this many nodes. The value must be greater
     * than 2 and should be at least 8 to mesh with assumptions in
     * tree removal about conversion back to plain bins upon
     * shrinkage.
     */
    //当一条链表上的数据容量达到8时就采用红黑树存储
    static final int TREEIFY_THRESHOLD = 8;

    /**
     * The bin count threshold for untreeifying a (split) bin during a
     * resize operation. Should be less than TREEIFY_THRESHOLD, and at
     * most 6 to mesh with shrinkage detection under removal.
     */
    //当一条链表上的数据少于等于6个时,就从红黑树转为链表存储一个桶中的数据
    static final int UNTREEIFY_THRESHOLD = 6;

    /**
     * The smallest table capacity for which bins may be treeified.
     * (Otherwise the table is resized if too many nodes in a bin.)
     * Should be at least 4 * TREEIFY_THRESHOLD to avoid conflicts
     * between resizing and treeification thresholds.
     */
    //如果一旦采用红黑树存储,那么HashMap的容量至少为64
    //当然用红黑树存储一个桶中的数据时,那么就至少是4*TREEIFY_THRESHOLD的容量
    static final int MIN_TREEIFY_CAPACITY = 64;
```

下面将罗列一些常见的关于HashMap常量的问题。

### 1.1 为什么Map的容量都是2的整数幂?

有两个理由:

- 寻找bucket索引更快
- 让扩容方法resize()效率更高

对于第一点,因为在JDK8中,HashMap计算bucket的索引方法如下:

>i = (n - 1) & hash == hash % n == (n-1) & (h = key.hashCode()) ^ (h >>> 16)

tab就是用来存储bucket的数组。n是数组的容量。如果n是2的整数幂,那么`(n-1)& hash== hash% n`,其中hash是一个32位整数。没错,就是这么神奇。这样计算索引只需移位操作,比取模更快。所以都是2的整数幂。

对于第二点:每次HashMap扩容都是变为原来的两倍,扩容是一个代价高昂的操作。在扩容时不仅需要复制元素,而且需要更新对应的索引。如果HashMap的容量都是2的整数幂。那么它的索引要么在原来位置,要么偏移了2的整数次幂(**偏移了原始容量的距离**)。

对于这一点,我们随便设一个hash做验证,令hashcode=0x00008435。未扩容前的容量为2^4=16。那么当前计算出的索引:
>0000 0000 0000 0000 1000 0100 0001 0101 -> hash
0000 0000 0000 0000 0000 0000 0000 1111 -> n-1

计算出的索引为:0101b & 1111b=101b=5。现在将容量扩张为原来的2倍:

>0000 0000 0000 0000 0000 0000 0001 1111 -> n-1

计算出的索引为:11111b & 10101b=10101b=21。索引移动了2的整数幂。再将容量扩充为原来的2倍:

>0000 0000 0000 0000 0000 0000 0011 1111 -> n-1

计算出的索引为:111111b & 010101b=10101b=21。索引没有变化。

从上面的结果可以看出,索引动与不动随机的取决于hashcode某1bit是0还是1。后者是0还是1的概率为0.5。

将容量扩充为原来的两倍的同时,也公平的将每个桶的容量也扩充为原来的两倍,因为桶中的元素移动于不移动完全是等概率的,取决于hashcode某bit是1还是0。

> 值得注意的是,JDK1.8中,HashMap扩容不会讲链表倒置,而JDK1.7会

### 1.2 为什么hash要这么计算?

在JDK1.8中,Map计算hashcode采用了新的方法:

``` java
static final int hash(Object key) {
    int h;
    //null的hash为0
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
    //这里调用的key的hashCode方法,实际上调用的key的具体实现类,而不是Object的hashCode
}
```

是将key的hash高16位于低16位进行异或。最后的hash高16位还是原来的高16位,低16位是异或后的结果。为什么要这么做呢?

简单来说是为了增加hash的随机性。比如两个整数:365(11110101b),165(01110101b)。如果只采用Integer自己实现的hash算法,那么计算出来的hash就是365于165。

现在进行索引的计算(map容量为16):`(n-1) & 16`。计算出的结果都为`101b`,发生了hash碰撞。但是这两个数差别还是蛮大的。所以将对象的原始hash的高16位与低16位异或,这么做也是为了在低16中保留高16位的特性,加大低16位的随机性。

所以说最终目的就是为了**防止hash碰撞**。JDK1.7的hash算法并不怎么随机,曾经产生了dos攻击。[HASH COLLISION DOS 问题](https://coolshell.cn/articles/6424.html)

**最后,null的hash为0!**

### 1.3 为什么HashMap的默认容量为16?

既然HashMap的容量必须是2的整数幂,那么为什么不是2,4,或者16,32。emm,这个问题我在网上看到的回答是:

>如果是2、4、8之类的,容量太小,容易导致频繁扩容。上文说过,扩容代价很高的。而不设置成32、64等更大的值是因为太大了,用到的概率不大。避免浪费空间。

这个答案还行吧,好像有那么一点道理。

### 1.4 为什么桶中节点数到8才采用RB树?

答案存在于源码中的开发笔记。这里仅摘抄最重要的部分。

>Because TreeNodes are about twice the size of regular nodes, we use them only when bins contain enough nodes to warrant use(see TREEIFY_THRESHOLD). And when they become too small (due to removal or resizing) they are converted back to plain bins.  In usages with well-distributed user hashCodes, tree bins are rarely used.  Ideally, under random hashCodes, the frequency of nodes in bins follows a Poisson distribution (http://en.wikipedia.org/wiki/Poisson_distribution) with a parameter of about 0.5 on average for the default resizing threshold of 0.75, although with a large variance because of resizing granularity.

大致意思是说,采用红黑树的存储所消耗的空间是采用链表存储的两倍。所以仅在链表中数据足够多的情况下会转为红黑树存储,当节点数减少到一定数量,就会再次退化为链表存储。**如果使用足够好的hash算法**,那么计算出的hashcode应该是足够分散的。

在理想hash下,每个桶中的节点数符合参数为0.5的泊松分布。分布公式为`(exp(-0.5) * pow(0.5, k) / * factorial(k))`。通过公式的计算,每个桶中各个节点数出现的情况如下:

``` java
0:    0.60653066
1:    0.30326533
2:    0.07581633
3:    0.01263606
4:    0.00157952
5:    0.00015795
6:    0.00001316
7:    0.00000094
8:    0.00000006
```
可以看到,一个桶中出现出现8个节点的概率为千万分之六。几乎是不可能出现的情况。当然,回归现实,不可能每次都出现理想hash。所以采用8个节点作为分界点。一个桶中达到8个节点,就转为红黑树存储。

这里又可以引申出一个问题,**为什么泊松分布的参数要设置为0.5?**

>emmm,从注释中看,应该也是一个经验值吧。



### 1.5 为什么桶中节点数减少为6才采用链表?

在节点数减少到6时才桶中元素采用RB树转为链表,为什么不是5或者7?

不设置为5、4、3的原因显而易见,节点太少,用红黑树存储从空间角度上来说不划算,因为是链表存储的2倍。

那么为什么不设置为7呢?

因为如果设置为7,那么加一个entry,变为8就要升级红黑树,减一个entry就变为7降级为链表。如果对HashMap频繁的进行增删操作,那么桶的存储方式就得频繁的在红黑树和链表之间转换,这个开销是不可忽视的。所以设为6,有一个缓冲的空间。

### 1.6 为什么factor设为0.75?

在官方注释中,下面的节选部分解释了为什么`load factor`是0.75。

>As a general rule, the default load factor (.75) offers a good tradeoff between time and space costs.  Higher values decrease the space overhead but increase the lookup cost (reflected in most of the operations of the <tt>HashMap</tt> class, including <tt>get</tt> and <tt>put</tt>).  The expected number of entries in the map and its load factor should be taken into account when setting its initial capacity, so as to minimize the number of
rehash operations.  If the initial capacity is greater than the maximum number of entries divided by the load factor, no rehash operations will ever occur.

简而言之,0.75是一个经验值,在时间和空间两个方面达到了平衡。**这也就解释为什么不是0.5或是1?**

如果factor是**0.5**,那么就会导致map频繁扩容,代价比较高。而且空间利用率也比较低。但是链表中的内容或者RB树的节点就比较少,提升了查询效率。**是以空间换时间的方式。**

如果factor设置为**1**,虽然空间利用率达到了100%,在使用完才会扩容,一定程度增加了put的时间。并且可能会发生大量的hash碰撞,此时的查询效率是非常低的。**是以时间换空间的方式。**

**那么为什么不是0.6或者0.8?**

首先如果`load factor`为0.75,那么每次`load factor * capacity`都会得到一个整数。

其次,在StackOverflow上有一个[回答](https://stackoverflow.com/questions/10901752/what-is-the-significance-of-load-factor-in-hashmap),采用了二项分布的方式计算出了`load factor`与`capacity`的最佳比例:

他首先规定,在完美情况下,在每次插入时所选取的桶应该是一个空桶。泊松分布的极限就是二项分布。在n次插入实验中,每次插入都选取空桶的概率总和应该为0.5。计算公式为:

> 1/2=P=C(n, 0) * (1/s)^0 * (1 - 1/s)^(n - 0),其中s是桶的数量,n是试验次数

我一直不明白`1/s`代表的是什么?每次都选取的是非空桶?那么解释不了`1/s`啊。而且StackOverflow新人还不能评论,可恶啊。

进行简单变化,在s趋于正无穷时,`n/s=load factor`趋近于`ln(2)`。所以他得出load facotr在`ln(2)~0.75`之间HashMap都能有很出色的表现。

我对上述回答产生了如下疑问:

1. 也不一定要求每次插入都必须要求空桶吧?
2. `1/s`的数学意义到底代表着什么?

## 2. HashMap的属性

HashMap中的magic number在上面已经分析过,下面是HashMap的一些属性:

``` java
    /**
    * The table, initialized on first use, and resized as
    * necessary. When allocated, length is always a power of two.
    * (We also tolerate length zero in some operations to allow
    * bootstrapping mechanics that are currently not needed.)
    */
    //用来存储bucket的底层数组,无论是初始化HashMap还是扩容,容量一直都是2的整数幂
    //当然上面也指出了在某些时候允许长度为0,从而允许一些当前不需要的引导机制????这是啥意思
    transient Node<K,V>[] table;

    /**
    * Holds cached entrySet(). Note that AbstractMap fields are used
    * for keySet() and values().
    */
    transient Set<Map.Entry<K,V>> entrySet;

    /**
    * The number of key-value mappings contained in this map.
    */
    //这是HashMap中实际的Entry数量,不是容量哦
    transient int size;

    /**
    * The number of times this HashMap has been structurally modified
    * Structural modifications are those that change the number of mappings in
    * the HashMap or otherwise modify its internal structure (e.g.,
    * rehash).  This field is used to make iterators on Collection-views of
    * the HashMap fail-fast.  (See ConcurrentModificationException).
    */
    //modCount曾在分析ArrayList的源码解释过,用于支持fast-fail机制,从而也说明HashMap是线程不安全的
    transient int modCount;

    /**
    * The next size value at which to resize (capacity * load factor).
    *
    * @serial
    */
    // (The javadoc description is true upon serialization.
    // Additionally, if the table array has not been allocated, this
    // field holds the initial array capacity, or zero signifying
    // DEFAULT_INITIAL_CAPACITY.)
    
    //注释中的大致意思就是下一次扩容时的容量,如果HashMap还未初始化,那么就存储初始化的容量,或者0(表示默认初始化容量)
    int threshold;

    /**
    * The load factor for the hash table.
    *
    * @serial
    */
    //HashMap的装载因子,一旦确定,不可更改
    final float loadFactor;
```

更新:2020-08-02 18:57:49

`HashMap`中的`threshold`=`loadFactor*capacity`,并**不是**下一次扩容的容量,当然如果HashMap还未初始化,并且用户指定了初始化容量,那么存储的就是根据用户指定容量计算出的元素数量阈值,否则0就是表示默认值12。       

`table`数组的元素是Node,这又是什么呢?来一起康康:

``` java
static class Node<K,V> implements Map.Entry<K,V> {
        //key的Hash值,是一个32bit的int,不可更改
        final int hash;
        //key,不可更改
        final K key;
        V value;
        //next指针,因为刚开始就是使用链表存储的Entry的
        Node<K,V> next;
        //构造函数
        //注意:没有默认构造函数
        Node(int hash, K key, V value, Node<K,V> next) {
            this.hash = hash;
            this.key = key;
            this.value = value;
            this.next = next;
        }

        public final K getKey()        { return key; }
        public final V getValue()      { return value; }
        public final String toString() { return key + "=" + value; }

        public final int hashCode() {
            return Objects.hashCode(key) ^ Objects.hashCode(value);
        }

        public final V setValue(V newValue) {
            V oldValue = value;
            value = newValue;
            return oldValue;
        }

        public final boolean equals(Object o) {
            if (o == this)
                return true;
            if (o instanceof Map.Entry) {
                Map.Entry<?,?> e = (Map.Entry<?,?>)o;
                if (Objects.equals(key, e.getKey()) &&
                    Objects.equals(value, e.getValue()))
                    return true;
            }
            return false;
        }
    }
```

从上面可以看出,Node是在HashMap使用链表存储模式时一组key-value的wrapper类。而`Map.Entry`是在`Map`接口中定义的一个内部接口,规定了一些`Entry`必须实现的方法。基本上就可以说这个`Entry`就相当于c++中的`pair`结构。保存一对key-value。`Entry`的定义如下:

``` java

interface Entry<K,V> {
    K getKey();

    V getValue();

    V setValue(V value);

    boolean equals(Object o);

    int hashCode();

    public static <K extends Comparable<? super K>, V> Comparator<Map.Entry<K,V>> comparingByKey() {
        return (Comparator<Map.Entry<K, V>> & Serializable)
            (c1, c2) -> c1.getKey().compareTo(c2.getKey());
    }

    public static <K, V extends Comparable<? super V>> Comparator<Map.Entry<K,V>> comparingByValue() {
        return (Comparator<Map.Entry<K, V>> & Serializable)
            (c1, c2) -> c1.getValue().compareTo(c2.getValue());
    }

    public static <K, V> Comparator<Map.Entry<K, V>> comparingByKey(Comparator<? super K> cmp) {
        Objects.requireNonNull(cmp);
        return (Comparator<Map.Entry<K, V>> & Serializable)
            (c1, c2) -> cmp.compare(c1.getKey(), c2.getKey());
    }
    
    public static <K, V> Comparator<Map.Entry<K, V>> comparingByValue(Comparator<? super V> cmp) {
        Objects.requireNonNull(cmp);
        return (Comparator<Map.Entry<K, V>> & Serializable)
            (c1, c2) -> cmp.compare(c1.getValue(), c2.getValue());
    }
}
```

在`Entry`中定义了四个获取比较器的静态方法,对于不熟悉java8新语法的同学来说,静态方法内部的实现可能让人摸不着头脑。

首先,`(c1, c2) -> c1.getKey().compareTo(c2.getKey());`其实是lambda表达式,它的一般格式如下:

>(type1 arg1,type2 arg2...)->{ body...}

lambda有[以下特点](http://blog.oneapm.com/apm-tech/226.html):

- 一个 Lambda 表达式可以有零个或多个参数
- 参数的类型既可以明确声明，也可以根据上下文来推断。例如：(int a)与(a)效果相同
- 所有参数需包含在圆括号内，参数之间用逗号相隔。例如：(a, b) 或 (String a, int b, float c)
空圆括号代表参数集为空。例如：() -> 42
- 当只有一个参数，且其类型可推导时，**圆括号**（）可省略。例如：a -> return a*a
- Lambda 表达式的主体可包含零条或多条语句
- 如果 Lambda 表达式的主体只有**一条**语句，**花括号**{}可省略。匿名函数的返回类型与该主体表达式一致
- 如果 Lambda 表达式的主体包含一条以上语句，则表达式必须包含在花括号{}中（形成代码块）。匿名函数的返回类型与代码块的返回类型一致，若没有返回则为空

关于lambda表达式更高级知识可以了解一下函数式语言中的闭包,java中的lambda就是最接近闭包的概念。

接下来再看看为什么一个lambda表达式能够强转为接口。`Comparator`是一个函数式接口(`@FunctionalInterface`)。函数式接口的标准就是其内部只能定义一个抽象方法。在java8中,每个lambda表达式都能隐式的赋值给函数时接口。当然lambda表达式的返回值和参数得和接口中定义的抽象方法一样才行。

然而我们去实际看`Comparator`接口源码时,却发现`Comparator`有两个抽象方法:

``` java
@FunctionalInterface
public interface Comparator<T> {
    int compare(T o1, T o2);
    boolean equals(Object obj);
    ...
}
```
竟然和函数式接口的定义不一样?然而答案在`FunctionInterface`的[官方文档](https://docs.oracle.com/javase/8/docs/api/java/lang/FunctionalInterface.html)中。
>If an interface declares an abstract method overriding one of the public methods of java.lang.Object, that also does not count toward the interface's abstract method count since any implementation of the interface will have an implementation from java.lang.Object or elsewhere.

意思就是说如果函数式接口的抽象方法如果重写自`object`,那么是不计入函数式接口定义的方法个数中的,因为`Object`中的方法肯定都会在自身中实现或者override于其他地方。

最后强转的类型是竟然是`(Comparator<Map.Entry<K, V>> & Serializable)`,两个类型还能进行与操作?

其实这也是java8中的新语法,StackOverflow上关于此问题的[回答](https://stackoverflow.com/questions/28509596/java-lambda-expressions-casting-and-comparators)如下:

>The lambda is initialized with its target type as Comparator and Serializable. Note the return type of method is just Comparator, but because Serializable is also inscribed to it while initialization, it can always be serialized even though this message is lost in method signature.

简而言之就是lambda表达式的初始化的目标类型是`Comparator`和`Serializable`。但是最后的**返回类型**却只是`Comparator`,但是`Serializable`类型已经在表达式初始化时注册(inscribe)过了。所以尽管在函数签名中丢失了该信息,但是返回值是一定总是可以初始化的。

ok,经过上述的简单科普,相信返回比较器的代码实现已经不是问题了。上述所有的点都是java8的新语法,包括在接口中定义`default`方法和`static`方法。

## 3. HashMap的构造方法

`HashMap`总共有4个构造方法,除了`HashMap(Map<? extends K, ? extends V> m)`以外,其他3个构造函数都是仅仅设置装载因子`load factor`,在这三个构造函数中,除了默认构造函数,~~另外两个都会设置初始容量~~。

~~这里传入的初始容量仅仅是为了设置threshold,而不是设置初始容量~~,这里再次收回所说的话,虽然表面上看仅仅是将传入容量修正为最近的2的整数幂,并赋值给threshold。

**但是在第一次put元素时**,会将刚才设置好的threshold赋值给table的新容量,也就实现的指定HashMap的容量的操作。但是这三个构造都不会进行table内存的分配,**只会在第一次put时调用resize()进行分配**。

``` java

    public HashMap(int initialCapacity, float loadFactor) {
        if (initialCapacity < 0)
            throw new IllegalArgumentException("Illegal initial capacity: " +
                                               initialCapacity);
        if (initialCapacity > MAXIMUM_CAPACITY)
            initialCapacity = MAXIMUM_CAPACITY;
        if (loadFactor <= 0 || Float.isNaN(loadFactor))
            throw new IllegalArgumentException("Illegal load factor: " +
                                               loadFactor);
        this.loadFactor = loadFactor;
        this.threshold = tableSizeFor(initialCapacity);
    }

    
    public HashMap(int initialCapacity) {
        this(initialCapacity, DEFAULT_LOAD_FACTOR);
    }

    //默认构造函数不会设置threshold
    public HashMap() {
        this.loadFactor = DEFAULT_LOAD_FACTOR; // all other fields defaulted
    }

    //会在putEntries中设置threshold    
    public HashMap(Map<? extends K, ? extends V> m) {
        this.loadFactor = DEFAULT_LOAD_FACTOR;
        putMapEntries(m, false);
    }

```
在第四个使用`Map`对象构造HashMap的构造函数中,其调用了`putMapEntries(Map,boolean)`方法,这个函数值得一提,因为其第二个参数的意义会在后面用到:

``` java
/**
     * Implements Map.putAll and Map constructor.
     *
     * @param m the map
     * @param evict false when initially constructing this map, else
     * true (relayed to method afterNodeInsertion).
     */
    final void putMapEntries(Map<? extends K, ? extends V> m, boolean evict) {
        int s = m.size();
        if (s > 0) {
            if (table == null) { // pre-size
                //下面的操作是在计算完全存储m中的元素需要的capacity,注意不是threshold
                
                //下面的加1.0F是为在计算出的loadFactor为小数时向上取整
                float ft = ((float)s / loadFactor) + 1.0F;
                int t = ((ft < (float)MAXIMUM_CAPACITY) ?
                         (int)ft : MAXIMUM_CAPACITY);
                //查看所需的capacity是否比当前HashMap的扩容阈值还大,比阈值还大的情况下,不可能存储下m的所有元素,即使当前HashMap为空
                //那么就需要更新当前HashMap的阈值
                if (t > threshold)
                    threshold = tableSizeFor(t);
            }
            //当调用HashMap的putAll方法时,会再次调用该方法执行到下面的else if 
            //这里的resize相当于一次预判,如果m的元素个数比当前hashmap的元素个数阈值threshold还高的话
            //那么即使当前HashMap为空,也无法存储m的所有元素,所以必须扩容
            //当然即使s<=threshold,当前HashMap还是有可能存储不下,这会在putVal内部进行扩容
            else if (s > threshold)
                resize();
            for (Map.Entry<? extends K, ? extends V> e : m.entrySet()) {
                K key = e.getKey();
                V value = e.getValue();
                putVal(hash(key), key, value, false, evict);
            }
        }
    } 
```
在`else if`中的扩容操作体现了HashMap的扩容懒汉模式,仅仅在已经确定没有足够空间存储的情况中才会进行扩容操作,因为扩容操作的代价太高了。

**evict参数:**

如果当前`HashMap`的table还未进行分配,那么就会将参数`evict`设置为false,表示当前正处于构造模式。这个单词本身的意思具有驱逐的意思,主要应用于`LinkedHashMap`构造`LRU`时使用。与`HashMap`中的意义不同。

最后代码中经常使用`tableSizeFor(int)`方法就是把用户输入的容量调整到最近的2的整数幂。其代码与`ArrayQueue`的调整方式基本一致。
``` java
static final int tableSizeFor(int cap) {
    int n = cap - 1;
    n |= n >>> 1;
    n |= n >>> 2;
    n |= n >>> 4;
    n |= n >>> 8;
    n |= n >>> 16;
    return (n < 0) ? 1 : (n >= MAXIMUM_CAPACITY) ? MAXIMUM_CAPACIT      Y : n + 1;
}
```
唯一与`ArrayQueue`不同的时,当把容量调整到离cap最近的2的整数幂-1时:

- 如果已经溢出,那么会将容量设为1
- 如果此时的容量小于`2^31`但是大于`2^30`,那么就将容量修正为`2^30`
- 否则最新容量就是最近的2的整数幂。
        

[为什么HashMap的get方法没有写成泛型？](https://stackoverflow.com/questions/857420/what-are-the-reasons-why-map-getobject-key-is-not-fully-generic)

## 0x3 JDK1.8与JDK1.7的HashMap异同

1. 实现方式不同,在JDK1.7中,HashMap采用数组+链表的方式实现,1.8则采用数组+链表+红黑树实现。

2. 扩容与插入顺序不同,1.7在链表中扩容是需要时再扩,也就是在插入时发现实在没办法插入再进行扩容,然后重新完成插入操作。我认为这很正常,没地方放再扩容不是正常逻辑?
JDK1.8中是先把节点放入map中,最后再决定是否要调用`resize`,我认为这是因为1.8中链表和RB树会进行相互转换。如果先进行扩容,那么本来需要进行树化的链表由于扩容被迫拆为两条小链表,可能会浪费空间。例如链表为7个,插入后为8个需要进行树化,但是先扩容导致该链表的长度减为4,又不需要树化了。

3. 链表的插入顺序不同,1.7中是采用头插法,1.8中采用尾插法。


## 0x4 JDK1.7的HashMap中存在的问题

1. 死循环问题,因为1.7中采用头插法,在多线程环境下进行扩容操作时可能会形成循环链表,导致在进行get操作时陷入死循环。

2. 数据丢失问题,同样是因为头插法,原始链表的末尾数据可能会产生丢失问题。


## 0x5 JDK1.8的HashMap中存在的问题

仍然会出现死循环以及数据丢失的问题。

``` java
....
if ((p = tab[i = (n - 1) & hash]) == null)
    tab[i] = newNode(hash, key, value, null);
...
```
上述是`putVal`中的部分代码,在多线程环境下,如果线程1已经通过if检查但是被迫放弃cpu,而线程2因为hash相同已经完成了插入操作,线程1重新获取cpu,此时再进行插入就会覆盖线程2插入的线程。

数据丢失问题是多线程环境下必然产生的问题。而1.8下的死循环原因却不相同,在对链表进行树化(`treeify`)或者调整树平衡(`balanceInsertion`)时仍然会产生死循环问题。

## 参考文献
1. [为什么容量都是2的整数幂](https://runzhuoli.me/2018/09/20/why-hashmap-size-power-of-2.html)

2. [关于HashMap的一些理解](https://albenw.github.io/posts/df45eaf1/)

3. [HashMap defaultLoadFactor = 0.75和泊松分布没有关系](https://blog.csdn.net/reliveIT/article/details/82960063?utm_medium=distribute.pc_relevant.none-task-blog-BlogCommendFromMachineLearnPai2-4.channel_param&depth_1-utm_source=distribute.pc_relevant.none-task-blog-BlogCommendFromMachineLearnPai2-4.channel_param)

4. [HashMap面试必问的6个点，你知道几个](https://juejin.im/post/5d5d25e9f265da03f66dc517)

5. [1.7与1.8HashMap的异同](https://www.cnblogs.com/liang1101/p/12728936.html)

6. [1.8散列因子为0.75的可能原因](https://stackoverflow.com/questions/10901752/what-is-the-significance-of-load-factor-in-hashmap)

7. [1.7中HashMap存在的问题](https://www.cnblogs.com/xrq730/p/5037299.html)