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
### 0x0-0 为什么节点数到8采用RB树?
首先说说为什么是桶中数据的容量达到8个就转用红黑树存储?我认为答案存在于源码中的开发笔记。这里仅摘抄最重要的部分。

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

而在节点数减少到6时,为什么不是5或者7?

不设置为5、4、3的原因显而易见,节点太少,用红黑树存储从空间角度上来说不划算,因为是链表存储的2倍。

那么为什么不设置为7呢?

因为如果设置为7,那么加一个entry,变为8就要升级红黑树,减一个entry就变为7降级为链表。如果对HashMap频繁的进行增删操作,那么桶的存储方式就得频繁的在红黑树和链表之间转换,这个开销是不可忽视的。所以设为6,有一个缓冲的空间。

>As a general rule, the default load factor (.75) offers a good tradeoff between time and space costs.  Higher values decrease the space overhead but increase the lookup cost (reflected in most of the operations of the <tt>HashMap</tt> class, including <tt>get</tt> and <tt>put</tt>).  The expected number of entries in the map and its load factor should be taken into account when setting its initial capacity, so as to minimize the number of
rehash operations.  If the initial capacity is greater than the maximum number of entries divided by the load factor, no rehash operations will ever occur.

## 0x1 HashMap的属性



## 0x2 HashMap中的常用方法


## 0x3 与JDK1.7的HashMap异同

https://stackoverflow.com/questions/10901752/what-is-the-significance-of-load-factor-in-hashmap


https://albenw.github.io/posts/df45eaf1/