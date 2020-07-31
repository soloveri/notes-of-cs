---
title: HashMap源码分析
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

前两种都比较常规。值得一提的是第三种方式中的`Map.Entry`。在`Map`接口定义了一个内部接口`Entry`。Entry维护了一组键值对,类似于c++HashMap中的pair结构。这个Entry结构只能通过Map的迭代器获得。并且这些Entry集合**只**在遍历的过程中有效,如果在遍历过程中修改了集合,那么Entry的操作是未定义,除了使用Entry定义的`setValue()`方法。

## 0x0 HashMap中的常量

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

### 0x0-0 为什么Map的容量都是2的整数幂?

有两个理由:

- 寻找bucket索引更快
- 让扩容方法resize()效率更高

对于第一点,因为在JDK8中,HashMap计算bucket的索引方法如下:

>i = (n - 1) & hash == hash % n == (n-1) & (h = key.hashCode()) ^ (h >>> 16)

tab就是用来存储bucket的数组。n是数组的容量。如果n是2的整数幂,那么`(n-1)& hash== hash% n`,其中hash是一个32位整数。没错,就是这么神奇。这样计算索引只需移位操作,比取模更快。所以都是2的整数幂。

对于第二点:每次HashMap扩容都是变为原来的两倍,扩容是一个代价高昂的操作。在扩容时不仅需要复制元素,而且需要更新对应的索引。如果HashMap的容量都是2的整数幂。那么它的索引要么在原来位置,要么偏移了2的整数次幂。

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

### 0x0-1 为什么hash要这么计算?

在JDK1.8中,Map计算hashcode采用了新的方法:

``` java
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
    //这里调用的key的hashCode方法,实际上调用的key的具体实现类,而不是Object的hashCode
}
```

是将key的hash高16位于低16位进行异或。最后的hash高16位还是原来的高16位,低16位是异或后的结果。为什么要这么做呢?

简单来说是为了增加hash的随机性。比如两个整数:365(11110101b),165(01110101b)。如果只采用Integer自己实现的hash算法,那么计算出来的hash就是365于165。

现在进行索引的计算(map容量为16):`(n-1) & 16`。计算出的结果都为`101b`,发生了hash碰撞。但是这两个数差别还是蛮大的。所以将对象的原始hash的高16位与低16位异或,这么做也是为了在低16中保留高16位的特性,加大低16位的随机性。

所以说最终目的就是为了**防止hash碰撞**。JDK1.7的hash算法并不怎么随机,曾经产生了dos攻击。[HASH COLLISION DOS 问题](https://coolshell.cn/articles/6424.html)

### 0x0-2 为什么HashMap的默认容量为16?

既然HashMap的容量必须是2的整数幂,那么为什么不是2,4,或者16,32。emm,这个问题我在网上看到的回答是:

>如果是2、4、8之类的,容量太小,容易导致频繁扩容。上文说过,扩容代价很高的。而不设置成32、64等更大的值是因为太大了,用到的概率不大。避免浪费空间。

这个答案还行吧,好像有那么一点道理。

### 0x0-3 为什么桶中节点数到8才采用RB树?

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



### 0x0-4 为什么桶中节点数减少为6才采用链表?

在节点数减少到6时才桶中元素采用RB树转为链表,为什么不是5或者7?

不设置为5、4、3的原因显而易见,节点太少,用红黑树存储从空间角度上来说不划算,因为是链表存储的2倍。

那么为什么不设置为7呢?

因为如果设置为7,那么加一个entry,变为8就要升级红黑树,减一个entry就变为7降级为链表。如果对HashMap频繁的进行增删操作,那么桶的存储方式就得频繁的在红黑树和链表之间转换,这个开销是不可忽视的。所以设为6,有一个缓冲的空间。

### 0x0-5 为什么factor设为0.75?

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

## 0x1 HashMap的属性



## 0x2 HashMap中的常用方法


## 0x3 与JDK1.7的HashMap异同

https://stackoverflow.com/questions/10901752/what-is-the-significance-of-load-factor-in-hashmap


https://albenw.github.io/posts/df45eaf1/

## 参考文献
1. [为什么容量都是2的整数幂](https://runzhuoli.me/2018/09/20/why-hashmap-size-power-of-2.html)

2. [关于HashMap的一些理解](https://albenw.github.io/posts/df45eaf1/)
3. [HashMap defaultLoadFactor = 0.75和泊松分布没有关系](https://blog.csdn.net/reliveIT/article/details/82960063?utm_medium=distribute.pc_relevant.none-task-blog-BlogCommendFromMachineLearnPai2-4.channel_param&depth_1-utm_source=distribute.pc_relevant.none-task-blog-BlogCommendFromMachineLearnPai2-4.channel_param)
4. [HashMap面试必问的6个点，你知道几个](https://juejin.im/post/5d5d25e9f265da03f66dc517)