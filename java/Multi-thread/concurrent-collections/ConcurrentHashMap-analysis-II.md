---
title: ConcurrentHashMap扩容分析
mathjax: true
date: 2021-04-06 10:02:09
updated: 2021-04-07 10:41:46
tags:
- concurrent collections
categories:
- java基础
---

## 前言

本篇继承于[ConcurrentHashMap架构解析](./ConcurrentHashMap-analysis-I.md)，在了解了`ConcurrentHashMap`的整体架构与插入删除逻辑后，还有一个知识点：**扩容逻辑**需要学习，我认为这是`ConcurrentHashMap`核心中的核心。

废话不多说，对于`ConcurrentHashMap`来说，扩容可以整体分为两个部分：

1. 将属性table扩展为原来的两倍
2. 将旧table中数据迁移到新table

那么本文就按照这两个小点逐个击破JDK8下的`ConcurrentHashMap`。

## 1. 预备知识

在真正学习扩容逻辑前，我们有必要了解`ConcurrentHashMap`中的两个重点字段：`sizeCtl`与`transferIndex`：

``` java
/**
* Table initialization and resizing control.  When negative, the
* table is being initialized or resized: -1 for initialization,
* else -(1 + the number of active resizing threads).  Otherwise,
* when table is null, holds the initial table size to use upon
* creation, or 0 for default. After initialization, holds the
* next element count value upon which to resize the table.
*/
/*
-1表示当前正在初始化table，在初始化完毕后，sizeCtl维护的是扩容阈值
为其他负数时，值的含义是：-(1+正在协作数据转移的线程数量)
*/
private transient volatile int sizeCtl;

/**
* The next table index (plus one) to split while resizing.
*/
private transient volatile int transferIndex;
```

**sizeCtl**的注释基本上解释了这个字段的含义：

1. “-1”表示当前table正在初始化
2. “其他负数”的含义为-(1+当前正在协助扩容的线程数量)
3. 当table为空，为初始值“0”或者用户自定义的容量
4. 当table不为空，“其他正数”的含义为扩容阈值

其中第二点需要我们注意，当`sizeCtl`为负数时，32位bit被一分为2：

1. 高16位是一个基于当前线程生成的特征码，用于标记线程是否正在协助扩容
2. 低16位表示（1+当前正在协助扩容的线程数量）

可能这里说的太抽象，后面了解具体的构造逻辑应该就不是问题了。

至于**transferIndex**则表示的是一个线程负责的迁移范围右边界的下一个索引。

## 2. table扩展逻辑

能进行`table`扩展的地方有很多，我目前仅了解到两处：

1. 在`putVal(K,V,boolean)`中，如果table未初始化，那么则会调用`initTable()`扩展`table`
2. 在链表过长调用`treeifyBin()`尝试树化时，如果`table`的容量小于64，那么仅仅会通过`tryPreSize(int)`完成`table`扩展以及数据迁移
3. 在调用`putAll()`时，首先会调用`tryPresize()`尝试扩展table

基本上会扩展`table`的场景就上面三种，那么我们依次来了解下它们具体的逻辑。

### 2.1 table的初始化

`table`初始化的逻辑还是比较简单的，在关键点我都写了注释：

``` java
private final Node<K,V>[] initTable() {
    Node<K,V>[] tab; int sc;
    while ((tab = table) == null || tab.length == 0) {
        //如果状态码sizeCtl小于0，表示有其他线程正在扩展扩展，那么我们需要做的只有等待
        if ((sc = sizeCtl) < 0)
            Thread.yield(); // lost initialization race; just spin
        else if (U.compareAndSwapInt(this, SIZECTL, sc, -1)) {
            try {
                if ((tab = table) == null || tab.length == 0) {
                    //sc不为0，表示用户自定义了容量
                    int n = (sc > 0) ? sc : DEFAULT_CAPACITY;
                    @SuppressWarnings("unchecked")
                    Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n];
                    table = tab = nt;
                    //设置sc=factor*capacity，也就是扩容阈值
                    sc = n - (n >>> 2);
                }
            } finally {
                sizeCtl = sc;
            }
            //只初始化一次
            break;
        }
    }
    return tab;
}
```

### 2.2 table的预扩展

所谓的预扩展，也就是方法`tryPresize(int)`，它作为关键先生，除了初始化table时不使用它，后续所有的扩展逻辑都需要通过`tryPresize()`扩展table（因为当table不为空，需要进行数据迁移，`initTable()`干不了这事），并在方法内部调用数据迁移方法`transfer()`。

那么所谓的“预”是指什么？我认为是指线程有资格尝试扩容，但不一定完成扩容。因为在一次扩容的过程中，可能有多个线程都想要完成相同的任务，比如从16扩展到32。那么肯定得防止多次扩容，只能允许第一个调用该方法的线程完成扩容的逻辑，后续的线程没资格扩展table，它们只能作为协助者帮助数据迁移。

了解了`tryPresize`的使用场景，我们看看它具体的实现逻辑：

``` java
/**
* Tries to presize table to accommodate the given number of elements.
*
* @param size number of elements (doesn't need to be perfectly accurate)
*/
private final void tryPresize(int size) {
    //c表示table的新容量
    int c = (size >= (MAXIMUM_CAPACITY >>> 1)) ? MAXIMUM_CAPACITY :
        tableSizeFor(size + (size >>> 1) + 1);
    int sc;
    //如果控制码sizeCtl为非负数，说明当前线程没有在初始化或者扩容
    while ((sc = sizeCtl) >= 0) {
        Node<K,V>[] tab = table; int n;
        //case1：table还未初始化或者长度为0
        if (tab == null || (n = tab.length) == 0) {
            n = (sc > c) ? sc : c;
            //将sizeCtl设置为-1，表示正在初始化table
            if (U.compareAndSwapInt(this, SIZECTL, sc, -1)) {
                //将旧table扩容原来的两倍
                try {
                    if (table == tab) {
                        @SuppressWarnings("unchecked")
                        Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n];
                        table = nt;
                        sc = n - (n >>> 2);
                    }
                } finally {
                    //设置新的状态码，也就是新的扩容阈值
                    sizeCtl = sc;
                }
            }
        }
        /*
        case2：有可能传入的参数size过小，甚至比原始table的扩容阈值都小，这种情况是有可能发生的：
        在putAll()中，首先会将table扩展为传入map的两倍大小，那么有可能原来table就不为空，
        并且远大于传入map大小的两倍，那么此时根本就不需要扩展以及数据迁移，直接返回即可
        */
        else if (c <= sc || n >= MAXIMUM_CAPACITY)
            break;
        //case3：table不为空，并且已经扩容完毕，为数据迁移做准备工作
        else if (tab == table) {
            //为当前线程生成唯一的扩容标识码，n是旧table的长度
            int rs = resizeStamp(n);
            /*****************************
            *           Question1        *
            *****************************/
            if (sc < 0) {
                Node<K,V>[] nt;
                //如果当前线程无法协作数据转移，则退出
                if (
                    (sc >>> RESIZE_STAMP_SHIFT) != rs ||
                    sc == rs + 1 || sc == rs + MAX_RESIZERS ||
                    (nt = nextTable) == null ||
                    transferIndex <= 0
                    )
                    break;
                //当前线程可能会作为协作线程帮助进行数据迁移
                //尝试使用cas操作负责把状态码sc中的协作线程数+1
                if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1))
                    transfer(tab, nt);
            }
            //本线程作为第一个作为数据迁移的线程，
            else if (U.compareAndSwapInt(this, SIZECTL, sc,
                                            (rs << RESIZE_STAMP_SHIFT) + 2))
                transfer(tab, null);
        }
    }
}

```

可以看到，`tryPresize(int)`中的`while`执行条件，只有当前table没有扩容或者初始化时才会执行后续操作，这也就防止多个线程执行相同的扩容操作。那么进入`while`后，会分为3个小场景：

1. 当table没有被初始化时，说明用户应该调用的是`putAll()`，那么则尝试将状态码`sizeCtl`设置为-1并初始化table
2. 当table不为空时，如果新容量小于旧的扩容阈值，或者已经超过了最大容量，那么根本就不需要扩容，直接返回即可
3. 当table没有被扩容，那么当前线程则尝试作为第一个进行数据迁移的线程，调用`transfer()`

上面比较难理解的是第三个场景，我这里详细解释一下。首先会通过调用`resizeStamp`为本轮扩容操作生成唯一的标识，它的逻辑如下：

``` java
//线程标识符生成逻辑
static final int resizeStamp(int n) {
    return Integer.numberOfLeadingZeros(n) | (1 << (RESIZE_STAMP_BITS - 1));
}
```

在生成标识符的过程中：首先会将数字`1`右移15位（RESIZE_STAMP_BITS值为16），将标识符的第16位（从右往左）设置为1，然后跟当前table长度的前导0个数进行或操作。那么根据这个逻辑，在同一轮扩容操作中，假设有n个线程在协助扩容，扩容完成前旧table的前导0个数必然是相等的，那么为这n个线程生成的标识符也必然相等。

下面是生成标识符后的代码逻辑，分为两个部分：

1. 当前table正在进行数据迁移，那么当前线程只能作为协助者去帮助
2. 当前table没有在数据迁移，那么当前线程作为数据迁移的发起者 

```java
    //case3逻辑
    ...
    if (sc < 0) {
        Node<K,V>[] nt;
        //如果当前线程无法协作数据转移，则退出
        if (
            (sc >>> RESIZE_STAMP_SHIFT) != rs ||
            sc == rs + 1 || sc == rs + MAX_RESIZERS ||
            (nt = nextTable) == null ||
            transferIndex <= 0
            )
            break;
        //当前线程可能会作为协作线程帮助进行数据迁移
        //尝试使用cas操作负责把状态码sc中的协作线程数+1
        if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1))
            transfer(tab, nt);
    }
    //本线程作为第一个作为数据迁移的线程，
    else if (U.compareAndSwapInt(this, SIZECTL, sc,
                                    (rs << RESIZE_STAMP_SHIFT) + 2))
        transfer(tab, null);
```

可以看到，如果当前线程想要作为协助者，必须要求局部变量`sc`小于0，那么“Question1”处的`if`语句什么时候会被执行？能进入`while`循环，那么局部变量`sc`（不存在竞争性）不是必定大于等于0？怎么可能小于0？

对于这个问题，我找了很久很久，终于在网上找到了答案，“Question1”是个bug：[JDK-8215409](https://bugs.openjdk.java.net/browse/JDK-8215409)，在JDK11以后，就不存在这个问题了。例如JDK14，对应的`tryPresize()`如下：

``` java
private final void tryPresize(int size) {
    int c = (size >= (MAXIMUM_CAPACITY >>> 1)) ? MAXIMUM_CAPACITY :
        tableSizeFor(size + (size >>> 1) + 1);
    int sc;
    while ((sc = sizeCtl) >= 0) {
        Node<K,V>[] tab = table; int n;
        if (tab == null || (n = tab.length) == 0) {
            ...
        }
        else if (c <= sc || n >= MAXIMUM_CAPACITY)
            break;
        /**********************
        * question1对应的代码  *
        **********************/
        else if (tab == table) {
            int rs = resizeStamp(n);
            if (U.compareAndSetInt(this, SIZECTL, sc,
                                    (rs << RESIZE_STAMP_SHIFT) + 2))
                transfer(tab, null);
        }
    }
}
```

可以看到，JDK8中的if语句完全被删除了。ok，虽然bug的问题解决了，但是又产生了一个新的问题，JDK8中的`if`是用来使用其他线程帮助数据迁移的，直接删除了帮助的逻辑，这个“帮助”又怎么实现？我仔细查看了插入的逻辑，发现在调用`putVal`时，有可能会调用`helpTransfer()`达到“帮助数据迁移”的目的，这个方法我会和迁移逻辑`transfer()`方法一起分析。

---
**Extension：**
对于这个问题，其实我觉的还有一点需要注意：我刚开始用中文英文都没有搜索到这个bug，why？我想原因可能是关键词没有写对，以后找JDK的bug，尽量使用`<class name>.<method name>`的格式，例如`ConcurrentHashMap.tryPresize()`。

---

那么如果当前线程作为数据迁移的发起者，会尝试CAS`U.compareAndSwapInt(this, SIZECTL, sc,(rs << RESIZE_STAMP_SHIFT) + 2)`将状态码`sizeCtl`设置为负数，这如何理解？

首先我们从前文知道，线程标识符`rs`的第16位一定是1，此时再右移16位，那么第16位的1一定会移动至第32位。ok，那么移动完成后`rs`一定是一个负数，并且第1~16位（从右往左）一定为0。此时再+2（1+1，其中一个1表示当前正在数据迁移的线程数量），就是最终的状态码`sizeCtl`。这也就达到了`sizeCtl`的第二种使用场景。

生成新的状态码后，第一个启动数据迁移的线程会调用`transfer()`完成真正的数据迁移，该方法的逻辑放在下一章中讲解。

### 2.2 小结

`ConcurrentHashMap`扩展table的核心方法是`tryPresize(int)`,它就是让属于同一轮扩容操作的线程一起完成数据迁移，加快效率。而不是让单个线程把整个table锁住，独自完成。

但是对于该方法，我也提出一个疑问：如果原始table中没有元素，那么初始化table后，没有数据转移啊，怎么结束`while`循环？目前我还没有明确的答案，我们在梳理完数据迁移函数`transfer()`的逻辑后，再来尝试回答这个问题。

---

在此贴出答案：其中变量`c`只会在旧table为空时才会改变，所以只会被初始化一次。而一旦进入`transfer()`，生成的新table长度是2c，那么新的扩容阈值`sizeCtl`为`2c*0.75=1.5c`，所以再次进入while循环时，会进入case2，因为`c<=sc`，直接退出循环。

---

## 3. 数据迁移

数据迁移是扩容操作的核心，主要通过`transfer(Node<K,V>[] tab, Node<K,V>[] nextTab)`完成，如果第二个参数`nextTab`为空，说明调用该方法的是数据迁移发起者，不为空则说明当前线程是数据迁移协助者。

能够调用该方法的地方有很多，我罗列一下目前我已知的地方：

1. 在`putVal()`中，如果发现table正在进行数据迁移，那么插入线程会调用`helpTransfer()`帮助数据迁移
2. 在`addCount()`中，更新table容量时会=可能会调用`transfer()`发起数据迁移
3. 在`tryPresize()`，会调用`transfer()`发起数据迁移

为了能够更快地理解`transfer()`地逻辑，我们首先需要了解一些前置知识：

1. 每一个进行数据迁移的线程都会负责一个范围的桶，范围的一般形式为 **[left_bound,right_bound ]**，其中**right_bound-left_bound=stride**
2. `stride`：表示一个线程需要负责转移多少连续的桶，最小值为16
3. `transferIndex`：表示当前线程负责迁移范围的右边界的下一个位置，有**transferIndex=right_bound+1**
4. `ForwardingNode`：占位符，如果一个桶转移完毕，那么会在旧table中放入一个`ForwardingNode`作为标记
5. `ConcurrentHashMap`是从后往前逐个转移每个桶的数据

说了这么多，我们来看看`transfer()`到底长什么样：

``` java

/*
* 该方法在table扩容后，进行数据迁移的操作
* Moves and/or copies the nodes in each bin to new table. See
* above for explanation.
*/
private final void transfer(Node<K,V>[] tab, Node<K,V>[] nextTab) {
    int n = tab.length, stride;
    if ((stride = (NCPU > 1) ? (n >>> 3) / NCPU : n) < MIN_TRANSFER_STRIDE)
        stride = MIN_TRANSFER_STRIDE; // subdivide range
    //数据迁移发起者传入的参数nextTab一定为null，所以能够保证只会生成一个nextTab
    //直接生成一个容量为旧table两倍的新table
    if (nextTab == null) {            // initiating
        try {
            @SuppressWarnings("unchecked")
            Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n << 1];
            nextTab = nt;
        } catch (Throwable ex) {      // try to cope with OOME
            sizeCtl = Integer.MAX_VALUE;
            return;
        }
        //将nextTab赋值给nextTable
        nextTable = nextTab;
        transferIndex = n;
    }
    int nextn = nextTab.length;
    ForwardingNode<K,V> fwd = new ForwardingNode<K,V>(nextTab);
    //advance为true表示当前线程已经把负责范围内的某个桶迁移完毕
    boolean advance = true;
    //finishing字段表示整个旧table的数据迁移是否完成
    boolean finishing = false; // to ensure sweep before committing nextTab
    for (int i = 0, bound = 0;;) {
        Node<K,V> f; int fh;
        //进行具体迁移任务前的预处理工作，主要是计算当前线程需要负责的桶索引
        while (advance) {
            //所有协作线程的nextIndex初始值都为(old table).length
            int nextIndex, nextBound;
            //i表示当前线程处理的桶索引，如果i>=bound，说明当前负责的范围还没有处理完毕,那么直接跳出循环，处理新桶
            //其中bound表示当前线程负责范围的下界
            if (--i >= bound || finishing)
                advance = false;
            
            //transferIndex<=0，表示整个table已经处理完毕了
            //因为transferIndex表示的是迁移范围的下一个索引
            else if ((nextIndex = transferIndex) <= 0) {
                i = -1;
                advance = false;
            }
            //当前线程负责迁移的范围：[transferIndex-stride,transferIndex-1]
            //每分配一次范围，将transferIndex从后往前移动stride的距离
            else if (U.compareAndSwapInt
                        (this, TRANSFERINDEX, nextIndex,
                        nextBound = (nextIndex > stride ?
                                    nextIndex - stride : 0))) {
                //bound表示迁移范围的左边界
                bound = nextBound;
                i = nextIndex - 1;
                advance = false;
            }
        }
        //case1：
        if (i < 0 || i >= n || i + n >= nextn) {
            int sc;
            //如果扩容结束，那么则将控制码sizeCtl设置为新的扩容阈值：n*factor，并返回
            if (finishing) {
                nextTable = null;
                table = nextTab;
                sizeCtl = (n << 1) - (n >>> 1);
                return;
            }
            //将SizeCtl后16位表示的协作线程数量-1
            if (U.compareAndSwapInt(this, SIZECTL, sc = sizeCtl, sc - 1)) {
                //如果当前线程不是最后一个完成迁移的线程，那么直接退出
                if ((sc - 2) != resizeStamp(n) << RESIZE_STAMP_SHIFT)
                    return;
                //当前线程是最后一个完成协作的线程，将完成标志位finishing设为true
                finishing = advance = true;
                i = n; // recheck before commit
            }
        }
        //case2：如果当前桶为空，直接尝试使用cas往该桶中放入占位符ForwardingNode
        else if ((f = tabAt(tab, i)) == null)
            advance = casTabAt(tab, i, null, fwd);
        //case3：如果当前桶的第一个节点是占位符ForwardingNode，那么说明当前桶已经完成了迁移
        else if ((fh = f.hash) == MOVED)
            advance = true; // already processed
        //case4：
        else {
            //对唯一的一个桶上锁，然后开始转移一个桶内的节点，这与HashMap是类似的
            synchronized (f) {
                if (tabAt(tab, i) == f) {
                    Node<K,V> ln, hn;
                    //当前桶的存储结构是链表
                    if (fh >= 0) {
                        ...
                        setTabAt(nextTab, i, ln);
                        setTabAt(nextTab, i + n, hn);
                        //设置占位符ForwardingNode
                        setTabAt(tab, i, fwd);
                        advance = true;
                    }
                    //如果当前桶的存储结构是红黑树，则采用红黑树的迁移方法
                    else if (f instanceof TreeBin) {
                        ...
                        }
                        ln = (lc <= UNTREEIFY_THRESHOLD) ? untreeify(lo) :
                            (hc != 0) ? new TreeBin<K,V>(lo) : t;
                        hn = (hc <= UNTREEIFY_THRESHOLD) ? untreeify(hi) :
                            (lc != 0) ? new TreeBin<K,V>(hi) : t;
                        setTabAt(nextTab, i, ln);
                        setTabAt(nextTab, i + n, hn);
                        setTabAt(tab, i, fwd);
                        advance = true;
                    }
                }
            }
        }
    }
}
```

`transfer()`的代码比较长，我们可以把它的逻辑分为如下两个部分：

1. 计算当前线程负责的迁移范围
2. 进行具体的迁移操作

下面我将分别详述这两个部分。

### 3.1 迁移范围的计算

当前线程负责的迁移范围由代码中的`while`循环负责计算，如下所示：

``` java
    ...
    while (advance) {
        //所有协作线程的nextIndex初始值都为(old table).length
        int nextIndex, nextBound;
        //i表示当前线程处理的桶索引，如果i>=bound，说明当前负责的范围还没有处理完毕,那么直接跳出循环，处理新桶
        //其中bound表示当前线程负责范围的下界

        /************************
        *        case1          *
        ************************/
        if (--i >= bound || finishing)
            advance = false;
        
        //transferIndex<=0，表示整个table已经处理完毕了
        //因为transferIndex表示的是迁移范围的下一个索引

        /************************
        *        case2          *
        ************************/
        else if ((nextIndex = transferIndex) <= 0) {
            i = -1;
            advance = false;
        }
        //当前线程负责迁移的范围：[transferIndex-stride,transferIndex-1]
        //每分配一次范围，将transferIndex从后往前移动stride的距离

        /************************
        *        case3          *
        ************************/
        else if (U.compareAndSwapInt
                    (this, TRANSFERINDEX, nextIndex,
                    nextBound = (nextIndex > stride ?
                                nextIndex - stride : 0))) {
            //bound表示迁移范围的左边界
            bound = nextBound;
            i = nextIndex - 1;
            advance = false;
        }
    }
    ...
```

我们可以分为三种case来理解`while`，对于每种case的含义我注释已经写的比较清楚了，不再赘述。我这里模拟一下多线程协作时计算范围的场景（假设有三个线程A、B，旧table的长度为32，步长为16）：

1. 当第一个线程`A`进入while循环后，会进入`case3`，`nextIndex`默认为32，那么`nextBound`的结果为（32-16），所以A线程负责的范围为`[bound,nextIndex-1]` ==`[16,32-1]`，并且从索引31开始处理
2. 当线程`B`进入while循环后，同样会进入`case3`，`nextIndex`的值为16，那么`nextBound`的结果为（16-16），所以B线程负责的范围为`[bound,nextIndex-1]` ==`[0,16-1]`，从索引15开始索引
3. 当A线程处理完毕后，因为`case1`条件不符合，进入`case2`将i设为`-1`，最后完成一些收尾工作；如果旧table足够大的话，会进入`case3`申请新的迁移区间重复数据迁移的过程

当整个旧table都迁移完成后，所有迁移线程都会进入`case2`将索引`i`设置为`-1`。

### 3.2 迁移操作的四种情况

在计算完当前线程需要负责的迁移范围后，会分为四种情况：

1. 当前线程的迁移工作已经结束
2. 当前处理的桶为空，直接尝试使用cas往该桶中放入占位符ForwardingNode
3. 当前桶的第一个节点是占位符ForwardingNode，那么说明当前桶已经完成了迁移，开始处理下一个桶
4. 对当前桶进行迁移工作

我在下面代码中已经注释了四种case：

``` java
    ...
    //case1：当前线程的迁移工作已经结束
    if (i < 0 || i >= n || i + n >= nextn) {
        int sc;
        //如果扩容结束，那么则将控制码sizeCtl设置为新的扩容阈值：n*factor，并返回
        if (finishing) {
            nextTable = null;
            table = nextTab;
            sizeCtl = (n << 1) - (n >>> 1);
            return;
        }
        //将SizeCtl后16位表示的协作线程数量-1
        if (U.compareAndSwapInt(this, SIZECTL, sc = sizeCtl, sc - 1)) {
            //如果当前线程不是最后一个完成迁移的线程，那么直接退出
            /*****************************
            *注意这里的sc和sizeCtl是两个值*
            ****************************/
            if ((sc - 2) != resizeStamp(n) << RESIZE_STAMP_SHIFT)
                return;
            //当前线程是最后一个完成协作的线程，将完成标志位finishing设为true
            finishing = advance = true;
            i = n; // recheck before commit
        }
    }
    
    //case2：如果当前桶为空，直接尝试使用cas往该桶中放入占位符ForwardingNode
    else if ((f = tabAt(tab, i)) == null)
        advance = casTabAt(tab, i, null, fwd);
    //case3：如果当前桶的第一个节点是占位符ForwardingNode，那么说明当前桶已经完成了迁移
    else if ((fh = f.hash) == MOVED)
        advance = true; // already processed
    //case4：迁移当前桶的数据
    else {
        //对唯一的一个桶上锁，然后开始转移一个桶内的节点，这与HashMap是类似的
        synchronized (f) {
            if (tabAt(tab, i) == f) {
                Node<K,V> ln, hn;
                if (fh >= 0) {
                    ...
                    setTabAt(nextTab, i, ln);
                    setTabAt(nextTab, i + n, hn);
                    //设置占位符ForwardingNode
                    setTabAt(tab, i, fwd);
                    advance = true;
                }
                //如果当前桶的存储结构是红黑树，则采用红黑树的迁移方法
                else if (f instanceof TreeBin) {
                    ...
                    setTabAt(nextTab, i, ln);
                    setTabAt(nextTab, i + n, hn);
                    setTabAt(tab, i, fwd);
                    advance = true;
                }
            }
        }
    }
    ...
```

我认为`case1`中的两个if**非常**值得注意：

1. `if (U.compareAndSwapInt(this, SIZECTL, sc = sizeCtl, sc - 1))`：这么写的原因是因为当一个线程完成了迁移工作，那么就会将`sizeCtl`低16位维护的线程数量减1。如果是最后一个协助线程，那么`sizeCtl`的值为`(resizeStamp(old tab.length)<<RESIZE_STAMP_SHIFT)+1`，这会作为迁移工作完成的标志，因为最后一个线程会通过下面的if条件并设置标志位`finishing`。

2. `if ((sc - 2) != resizeStamp(n) << RESIZE_STAMP_SHIFT)`，这么写的原因是因为迁移工作的发起者会执行`sizeCtl=(resizeStamp(old tab.length)<<RESIZE_STAMP_SHIFT)+2`，如果该if条件通过，说明当前线程就是最后一个完成迁移的线程，将标志位`finishing`设为true，并且将索引`i`设为n，这样下一轮循环依然能进入上面迁移操作的逻辑中，再次进入case1更新`sizeCtl`、`table`后并返回

至于其他三种case，我认为并不难理解，基本注释我已写在代码中，这里不再赘述。

### 3.3 协助线程的入口

如果一个线程只能作为协助者的身份来迁移数据，那么它调用`tranfser()`进行协助的入口点只有`helpTransfer(Node<K,V>[] tab, Node<K,V> f)`。能够调用`helpTransfer()`的地方有很多，一般最常见的就是在`putVal()`中，如果插入桶的第一个节点hash值为`MOVED`，就会进入`helpTransfer()`：

``` java
//putVal()中helpTransfer的入口点
...
    else if ((fh = f.hash) == MOVED)
        tab = helpTransfer(tab, f);
```

`helpTransfer()`的返回值是新table，基本的注释我都写在了代码中：

``` java
final Node<K,V>[] helpTransfer(Node<K,V>[] tab, Node<K,V> f) {
    Node<K,V>[] nextTab; int sc;
    //旧table不为空
    if (tab != null &&
    //桶中第一个节点为标记节点ForwardingNode
    (f instanceof ForwardingNode) &&
    //标记节点ForwardingNode中存储的新table不为空
        (nextTab = ((ForwardingNode<K,V>)f).nextTable) != null) {
        //计算出本轮扩容的标志码
        int rs = resizeStamp(tab.length);
        /*如果标记节点ForwardingNode中存储的新table和ConcurrentHashMap的属性nextTable是同一个table
        并且传入的旧table和ConcurrentHashMap的属性table是同一个table才能保证协助线程和发起线程实在操作同一轮扩容操作
        因为sizeCtl<0可能是正在进行初始化table操作
        */
        while (nextTab == nextTable && table == tab &&
                (sc = sizeCtl) < 0) {
            if (//如果生成的标识符不一样，说明本轮扩容工作已经结束了
                (sc >>> RESIZE_STAMP_SHIFT) != rs ||
                //表示扩容已经结束，原理在下面详解
                /*******************
                *      Question1   *
                *******************/
                sc == rs + 1 ||
                //扩容的线程数达到最大值
                sc == rs + MAX_RESIZERS ||
                //转移工作已经结束了
                transferIndex <= 0)
                break;
            //将协助的线程数+1，并调用transfer进行协助
            if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1)) {
                transfer(tab, nextTab);
                break;
            }
        }
        return nextTab;
    }
    return table;
}
```

我认为值得注意的是“Question1”处，`sc==rs+1`为什么表示当前迁移工作已经完成。原因我已在迁移操作四种情况中的case1处解释。

## 4. 总结

我认为`ConcurrentHashMap`的扩容还是比较复杂的，当然我们要抓住核心：只会有一个线程发起数据迁移，而其他线程会作为协作者。并且每个线程会负责一段连续的桶。至于具体的数据迁移跟`HashMap`是类似的：对于链表，会随机地划分为高低两个链表；对于红黑树，会拆分成两颗子树，最后存入新table对应的位置。

## 参考文献

1. [ConcurrentHashMap扩容源码介绍](https://kkewwei.github.io/elasticsearch_learning/2017/11/14/ConcurrentHashMap%E6%89%A9%E5%AE%B9%E8%BF%87%E7%A8%8B%E4%BB%8B%E7%BB%8D/)

2. [Java多线程进阶（二四）—— J.U.C之collections框架：ConcurrentHashMap(2) 扩容](https://segmentfault.com/a/1190000016124883)

3. [Java7/8 中的 HashMap 和 ConcurrentHashMap 全解析](https://www.javadoop.com/post/hashmap)

4. [Concurrent HashMap Source Detailed Analysis (JDK 1.8)](https://programmer.group/concurrent-hashmap-source-detailed-analysis-jdk-1.8.html)