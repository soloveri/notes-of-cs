---
title: HashMap源码分析(二)-插入源码
mathjax: true
data: 2020-10-02 17:40:48
updated:
tags:
- HashMap
categories:
- 源码分析
---

HashMap中最常用的就是`put(key,value)`函数与`remove`函数,而且这些函数还会包含RB树与list的相互转换,比较复杂。值得认真推敲。

## 1. put方法
下面JDk1.8中,HashMap的`put`源码。其又在内部调用了`putVal`。

``` java
public V put(K key, V value) {
    return putVal(hash(key), key, value, false, true);
}

final V putVal(int hash, K key, V value, boolean onlyIfAbsent,boolean evict) {
...
}
```

`putVal(int hash, K key, V value, boolean onlyIfAbsent,boolean evict)`有四个参数,其中前两个参数都好理解。第三个参数`onlyIfAbsent`为一个标志位:
- 如果为false,表示对于相同key的value会进行覆盖
- 为true则不会进行覆盖

**在`HashMap`默认对相同key的value进行覆盖。** 最后一个参数`evict`已在介绍`putEntries`方法时介绍过。在`HashMap`表示是否处于创建模式,**默认为false**。

在深入分析`putVal`方法之前,需要先了解一下`resize()`方法,下面是其源码:

``` java
/**
    * Initializes or doubles table size.  If null, allocates in
    * accord with initial capacity target held in field threshold.
    * Otherwise, because we are using power-of-two expansion, the
    * elements from each bin must either stay at same index, or move
    * with a power of two offset in the new table.
    *
    * @return the table
    */
final Node<K,V>[] resize() {
    Node<K,V>[] oldTab = table;
    int oldCap = (oldTab == null) ? 0 : oldTab.length;
    int oldThr = threshold;
    int newCap, newThr = 0;
    //如果HashMap不为空,已经是存储过元素了才会不为空
    if (oldCap > 0) {
        //如果当前容量已经超过最大容量了,已经没办法扩大了,那么就只会更新存储个数的阈值,只能利用剩下的25%空间
        //无需进行复制
        if (oldCap >= MAXIMUM_CAPACITY) {
            threshold = Integer.MAX_VALUE;
            return oldTab;
        }
        //这就是常规的对容量进行扩充一倍的操作
        else if ((newCap = oldCap << 1) < MAXIMUM_CAPACITY &&
                    //如果原始容量太小,那么threshold就会在后面进行自动计算
                    //比如原始容量为4,原始threshold为3,但是newThr通过原始threshold左移一位也能正确
                    //得出答案啊,为啥还要多此一举?
                    oldCap >= DEFAULT_INITIAL_CAPACITY)
            newThr = oldThr << 1; // double threshold
    }
    //仅仅是调用了能够设置初始容量的构造函数,但是还未put值
    else if (oldThr > 0) // initial capacity was placed in threshold
        newCap = oldThr;
    //如果当前HashMap的table还未分配,也就是调用默认的无参构造函数
    //此时threshold=0,就是分配默认大小的table
    else {
        //新的容量就是默认的初始化容量为16
        newCap = DEFAULT_INITIAL_CAPACITY;
        //设置新的threshold,新的threshold就是12
        newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
    }
    //执行下面if语句只会有两种情况发生,一种就是调用能够设置初始容量的构造函数但还未put元素
    //另外一种就是当前HashMap已经有元素,但是当前容量小于默认容量,也就是小于16
    //因为如果调用默认构造函数,那么threshold在上面已经分配
    //如果HashMap中已经有元素,也会直接设置好
    if (newThr == 0) {
        //通过用户的指定的容量进行threshold的计算
        float ft = (float)newCap * loadFactor;
        newThr = (newCap < MAXIMUM_CAPACITY && ft < (float)MAXIMUM_CAPACITY ?
                    (int)ft : Integer.MAX_VALUE);
    }
    threshold = newThr;
    @SuppressWarnings({"rawtypes","unchecked"})
    Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
    table = newTab;
    //已经设置好新的容量与新的threshold,如果原始HashMap不为空,那么就进行元素的复制
    if (oldTab != null) {
        //逐个拷贝
        for (int j = 0; j < oldCap; ++j) {
            Node<K,V> e;
            if ((e = oldTab[j]) != null) {
                oldTab[j] = null;
                if (e.next == null)
                    newTab[e.hash & (newCap - 1)] = e;
                else if (e instanceof TreeNode)
                    //如果是使用红黑树存储的,那么就把一棵树分裂成两颗树?这留着后面再分析
                    ((TreeNode<K,V>)e).split(this, newTab, j, oldCap);
                else { // preserve order
                    //HashMap会把一个完整的链表分成高低两个链表,每个链表的具体个数取决元素hash的某一bit是否为1,概率各为50%,高表示当前使用的bit位为1,低表示bit位为0
                    //所以理想情况下分成两个长度相等的链表

                    //低链表的头尾
                    Node<K,V> loHead = null, loTail = null;
                    //高链表的头尾
                    Node<K,V> hiHead = null, hiTail = null;
                    Node<K,V> next;
                    do {
                        //尾插法
                        next = e.next;
                        //低链表,如果当前使用的bit为0,那么就使用尾插法加入到链表中
                        if ((e.hash & oldCap) == 0) {
                            if (loTail == null)
                                loHead = e;
                            else
                                loTail.next = e;
                            loTail = e;
                        }
                        else {
                            if (hiTail == null)
                                hiHead = e;
                            else
                                hiTail.next = e;
                            hiTail = e;
                        }
                    } while ((e = next) != null);
                    //这里为什么需要判断非null呢?因为有可能运气不好,元素全部聚集到low链表或high链表中
                    if (loTail != null) {
                        loTail.next = null;
                        //如果是low链表,那么索引就会保持原位置不动
                        newTab[j] = loHead;
                    }
                    if (hiTail != null) {
                        hiTail.next = null;
                        //如果是high表,那么索引就会偏移原来的容量的长度
                        newTab[j + oldCap] = hiHead;
                    }
                }
            }
        }
    }
    return newTab;
}
```

## 2. putVal方法

老规矩,先把代码粘上来:

``` java
/**
    * Implements Map.put and related methods.
    *
    * @param hash hash for key
    * @param key the key
    * @param value the value to put
    * @param onlyIfAbsent if true, don't change existing value
    * @param evict if false, the table is in creation mode.
    * @return previous value, or null if none
    */
final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
                boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;
    if ((tab = table) == null || (n = tab.length) == 0)
        n = (tab = resize()).length;
        //前文说过,(n-1)&hash等价于hash%n,不同hash的key不可能取到同一个下标
        //如果还没有创建过节点,那么创建新节点放到对应桶中即可
    if ((p = tab[i = (n - 1) & hash]) == null)
        tab[i] = newNode(hash, key, value, null);
    //目标bucket已经有元素了,那么会有两种情况:
    //要么是替换key对应的value,要么就是加入一个新节点    
    else {
        Node<K,V> e; K k;
        //这里总是首先判断目标bucket中第一个元素是否和key是用一个元素,p就是第一个元素
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k)))) //@Fisrt Question
            //把bucket中的第一个元素赋值给e
            e = p;
        //如果目标bucket已经使用RB tree存储了,那么就调用TreeNode的putTreeVal方法存入新节点
        else if (p instanceof TreeNode)
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
        //走到这里,说明bucket还是使用链表存储
        //那么需要判断是加入新节点还是替换value
        else {
            for (int binCount = 0; ; ++binCount) {
                if ((e = p.next) == null) {
                    //链表已经遍历完了,还是没有找到相同的对象,说明用户的目的是插入新节点
                    
                    //注意,Hash冲突的在这里也会执行插入,导致一条链表过长
                    p.next = newNode(hash, key, value, null);
                    //因为是从p.next开始遍历的,所以在插入第七个元素时,进行树化
                    //从0开始计算，0表示第一个节点，所以如果原来本身就有8个节点，那么则会调用treeifyBin
                    //但是只有table的长度达到64时，才会进行树化
                    if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                        treeifyBin(tab, hash);
                    break;
                }
                //与上面的@First Question一样,判断我们当前处理的链表节点与key是否为同一个对象
                //如果是,说明用户的目的是替换value,而不是插入
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))
                    break;
                p = e;
            }
        }
        //如果用户目的是替换元素,那么额e就是找出来的对象,否则如果是插入新节点e就会为null
        if (e != null) { // existing mapping for key
            V oldValue = e.value;
            //onlyIfAbsent为false允许替换元素,如果不允许替换元素,那么就看看原始value是否为null
            //如果为null,那么即使onlyAbsence为true也能替换
            if (!onlyIfAbsent || oldValue == null)
                e.value = value;
            afterNodeAccess(e);//@second question
            return oldValue;
        }
    }
    //为了实现fast-fail机制
    ++modCount;
    //如果插入后元素个数超出了存储阈值,那么就会调用resize扩容
    if (++size > threshold)
        resize();
    afterNodeInsertion(evict);
    return null;
}

```

不难理解的代码都写在注释中了,这里写写比较难以理解的地方。

@First Question:为什么要这么写?

首先,`if (p.hash == hash && ((k = p.key) == key || (key != null && key.equals(k))))`这一句是在判断插入的key与bucket中的第一个key是否为同一个对象,在HashMap中判断两个对象是否为同一个需要hash相同并且对象相同。所以用`&&`把hash是否相同与对象是否相同的两个条件连接起来没什么问题。并且判断hash比后面的判断要快,所以把判断hash写在前面。但是判断两个对象是否相同为什么要使用`(key != null && key.equals(k)))`?

因为对于引用类型,`==`比较的是对象地址。所以如果两个对象地址都相同,那么肯定是同一个对象。后面的条件是为了满足有些重写了`equals`与`hashCode`方法的类需要把逻辑上相同的两个对象认为是同一个对象。

@Second Question:`afterNodeAccess`有什么用?

追踪其实现代码,发现其其实是空函数:
``` java
// Callbacks to allow LinkedHashMap post-actions
    void afterNodeAccess(Node<K,V> p) { }
    void afterNodeInsertion(boolean evict) { }
    void afterNodeRemoval(Node<K,V> p) { }
```

注释里写的是给`LinkedHashMap`用作回调函数,不知道为什么HashMap里也使用这个,我们可以override这些函数,在完成插入、替换或者移除节点这些动作后执行一些通用的操作。

>Attention!!!
能存储在一个链表或者一颗红黑树中的,都是hash冲突的key-value,我到今天才发现!!!惭愧！！！

### 2.1 treeifyBin

`putVal`中还有一个非常重要的方法,就是`treeifyBin`,该方法将链表转化为一颗RB tree,实现代码如下:

``` java
/**
    * Replaces all linked nodes in bin at index for given hash unless
    * table is too small, in which case resizes instead.
    */
final void treeifyBin(Node<K,V>[] tab, int hash) {
    int n, index; Node<K,V> e;
    //如果tab的长度小于64,那么就会扩容,而不是树化
    if (tab == null || (n = tab.length) < MIN_TREEIFY_CAPACITY)
        resize();
    else if ((e = tab[index = (n - 1) & hash]) != null) {
        //hd是头节点,tl指向尾节点
        TreeNode<K,V> hd = null, tl = null;
        do {
            //Node节点转换为TreeNode双链表
            TreeNode<K,V> p = replacementTreeNode(e, null);
            //设置头节点
            if (tl == null)
                hd = p;
            //尾插法
            else {
                p.prev = tl;
                tl.next = p;
            }
            tl = p;
        } while ((e = e.next) != null);
        //因为TreeNode是Node的子列,所以将tab[index]替换成RB树的头节点
        if ((tab[index] = hd) != null)
            hd.treeify(tab);
    }

    // For treeifyBin
    TreeNode<K,V> replacementTreeNode(Node<K,V> p, Node<K,V> next) {
        return new TreeNode<>(p.hash, p.key, p.value, next);
    }
}
```

可以看出,`treeifyBin`仅仅是将目标bucket的由`Node`组成的双向链表转化为由`TreeNode`组成的双向链表,具体的树化还得看双向链表的头节点`hd`的方法`treeify`。

### 2.2 TreeNode

在深入了解`treeify`之前,我们还需要简单了解一下`TreeNode`的结构。`TreeNode`继承于`LinkedHashMap.Entry`,而`LinkedHashMap.Entry`又继承于`HashMap.Node`,最后`HashMap.Node`继承于`Map.Entry`。这一串继承下来,`TreeNode`的变量总共有11个。

``` java
 static final class TreeNode<K,V> extends LinkedHashMap.Entry<K,V> {
    TreeNode<K,V> parent;  // red-black tree links
    TreeNode<K,V> left;
    TreeNode<K,V> right;
    TreeNode<K,V> prev;    // needed to unlink next upon deletion
    boolean red;
    TreeNode(int hash, K key, V val, Node<K,V> next) {
        super(hash, key, val, next);
    }
    ...
}

static class Entry<K,V> extends HashMap.Node<K,V> {
    Entry<K,V> before, after;
    Entry(int hash, K key, V value, Node<K,V> next) {
        super(hash, key, value, next);
    }
}

static class Node<K,V> implements Map.Entry<K,V> {
    final int hash;
    final K key;
    V value;
    Node<K,V> next;
    ...
}
```
下面是`TreeNode`的`treeify`方法,该方法就是将一个双向链表转化为红黑树,树化肯定要从根节点开始树化嘛。

``` java
/**
* Forms tree of the nodes linked from this node.
*/

final void treeify(Node<K,V>[] tab) {
    TreeNode<K,V> root = null;
    for (TreeNode<K,V> x = this, next; x != null; x = next) {
        //x.next的运行时类型为TreeNode,但是静态类型为Node,所以需要强制转换
        next = (TreeNode<K,V>)x.next;
        x.left = x.right = null;
        //还没有设置RB树的根节点,设置一哈
        if (root == null) {
            x.parent = null;
            //根节点必为黑
            x.red = false;
            root = x;
        }
        //开始放置新的树节点
        else {
            //x就是当前要放入的节点
            K k = x.key;
            int h = x.hash;
            Class<?> kc = null;
            for (TreeNode<K,V> p = root;;) {
                int dir, ph;
                K pk = p.key;
                //@First-Q
                //为什么要比较hash的大小
                if ((ph = p.hash) > h)
                    dir = -1;
                else if (ph < h)
                    dir = 1;
                //hash相等
                //如果没有实现Comparable接口,那没法比了,只能调用tieBreakOrder强行比较
                else if ((kc == null &&(kc = comparableClassFor(k)) == null) ||
                            //实现了Comparable接口,但是二者compare的结果还是相等的
                            (dir = compareComparables(kc, k, pk)) == 0)
                    //强行比较
                    dir = tieBreakOrder(k, pk);

                TreeNode<K,V> xp = p;
                //dir<=0就插入到左子树中,否则插入到右子树中,并且如果目标方向的子节点为空,才会进行插入
                //否则继续向下遍历
                if ((p = (dir <= 0) ? p.left : p.right) == null) {
                    x.parent = xp;
                    if (dir <= 0)
                        xp.left = x;
                    else
                        xp.right = x;
                    //平衡颜色
                    root = balanceInsertion(root, x);
                    break;
                }
            }
        }
    }
    //对树进行平衡调整,从根节点开始调整
    moveRootToFront(tab, root);
}
```

那么其中`comaprableClassFor`是干嘛的呢?康康它的源码:

``` java
/**
    * Returns x's Class if it is of the form "class C implements
    * Comparable<C>", else null.
    */
static Class<?> comparableClassFor(Object x) {
    if (x instanceof Comparable) {//如果对象x实现了Comparable接口
        Class<?> c; Type[] ts, as; Type t; ParameterizedType p;
        if ((c = x.getClass()) == String.class) // bypass checks
            return c;
        //ts是一个Type类型的数组
        //getGenericInterfaces返回的是c直接实现的接口
        if ((ts = c.getGenericInterfaces()) != null) {
            for (int i = 0; i < ts.length; ++i) {
                //如果t是一个参数化类型并且原始类型是Comparable,并且t的泛型类型中参数个数只有1个,并且参数是x.getClass()
                //那么就返回x的Class对象,否则返回null
                if (((t = ts[i]) instanceof ParameterizedType) &&
                    ((p = (ParameterizedType)t).getRawType() ==
                        Comparable.class) &&
                    (as = p.getActualTypeArguments()) != null &&
                    as.length == 1 && as[0] == c) // type arg is c
                    return c;
            }
        }
    }
    return null;
}
```

该方法其中就是判断类`c`是否实现了接口`Comparable<c>`,如果实现了,就返回`c`的`Class`对象,否则返回null。那么`compareComparables`是干嘛的?顺便康康其源码:

``` java
/**
    * Returns k.compareTo(x) if x matches kc (k's screened comparable
    * class), else 0.
    */
@SuppressWarnings({"rawtypes","unchecked"}) // for cast to Comparable
static int compareComparables(Class<?> kc, Object k, Object x) {
    return (x == null || x.getClass() != kc ? 0 :
            ((Comparable)k).compareTo(x));
}
```

首先会比较待插入键`y`的`Class`文件`kc`与树中的节点`x`的`Class`文件是否相同,这一句就要求了如果`y`和`x`必须是同一类型,否则即使`y`实现了`Comaprable`接口也不能比较,因为我们不知道`x`是否实现了`Comparable`接口。

如果是同一类型,那么就是`comparaTo`方法比较这两个键的大小。注意这里还是有可能相等的,还是无法决定这两个键谁大谁小。那么当然还有最后一招,就是方法`tieBreakOrder`,这个方法必须抉择处待插入的节点和数中的某个节点到底谁大。那么它怎么比的?还是看源码咯。

``` java
/**
* Tie-breaking utility for ordering insertions when equal
* hashCodes and non-comparable. We don't require a total
* order, just a consistent insertion rule to maintain
* equivalence across rebalancings. Tie-breaking further than
* necessary simplifies testing a bit.
*/
static int tieBreakOrder(Object a, Object b) {
    int d;
    if (a == null || b == null ||
        (d = a.getClass().getName().
            compareTo(b.getClass().getName())) == 0)
        d = (System.identityHashCode(a) <= System.identityHashCode(b) ?
                -1 : 1);
    return d;
}
```

首先判断`a`或者`b`的名字谁长,名字短的排在前面。如果名字长度相等,那么计算`a`和`b`的hashCode,hash相等的话,`a`排在前面。那么`identityHashCode`是怎么计算的?

该方法就是返回对象`a`或`b`的默认hashcode,无论`a`或者`b`是否override了`hashCode`方法。`null`的`hashCode`为0。

经过上述最多三次的抉择,终于能决定待插入节点`x`和树中的节点谁大谁小了。那么抉择出来了,就可以在树中插入节点`x`了吗?当然不行,上面的代码仅仅是比较大小而已,真正插入时需要在RB树中找到一个合适的叶节点。下面的代码就是寻找合适的叶节点:

``` java
//下文中的x是待插入节点
for (TreeNode<K,V> p = root;;) {
    int dir, ph;
    K pk = p.key;
    //@First-Q
    //为什么要比较hash的大小
    if ((ph = p.hash) > h)
        dir = -1;
    else if (ph < h)
        dir = 1;
    //hash相等
    //如果没有实现Comparable接口,那没法比了,只能调用tieBreakOrder强行比较
    else if ((kc == null &&(kc = comparableClassFor(k)) == null) ||
                //实现了Comparable接口,但是二者compare的结果还是相等的
                (dir = compareComparables(kc, k, pk)) == 0)
        //强行比较
        dir = tieBreakOrder(k, pk);

    TreeNode<K,V> xp = p;
    //dir<=0就插入到左子树中,否则插入到右子树中,并且如果目标方向的子节点为空,这才是真正的插入点
    //否则继续向下遍历寻找合适的位置 
    if ((p = (dir <= 0) ? p.left : p.right) == null) {
        x.parent = xp;
        if (dir <= 0)
            xp.left = x;
        else
            xp.right = x;
        //平衡颜色
        root = balanceInsertion(root, x);
        break;
    }
}
```

在找到插入位置并完成插入后,需要调用`balanceInsertion`平衡节点之间的颜色。这个函数是红黑树的调整的核心操作。我把注释都写在了代码中:

``` java
static <K,V> TreeNode<K,V> balanceInsertion(TreeNode<K,V> root,
                                            TreeNode<K,V> x) {

    //注意在JDK8中,红黑树是左右倾都存在的
    //要从插入的节点x开始逐级向上调整
    //插入的节点一定是红色,而且可能插在x的左侧或者右侧
    x.red = true;
    for (TreeNode<K,V> xp, xpp, xppl, xppr;;) {
        //如果x没有父节点,那么根本不用调整
        //将x的颜色设为黑色返回即可,因为x此时就是根节点
        if ((xp = x.parent) == null) {
            x.red = false;
            return x;
        }
        //如果x的父节点xp是黑的,这时可以直接返回,因为在xp左侧插入一个红节点不影响RB的完美平衡
        //或者xp是红色的,但是xp没有父节点,那么可以直接返回?
        //查了一下,xp是红色但是没有父节点的情况不会出现,这样是为了给xpp赋值
        //综上,如果xp是黑色,就直接返回root,因为不影响平衡性
        else if (!xp.red || (xpp = xp.parent) == null)
            return root;
        //只要上面的else if没返回,那么xp必是红节点,而且xpp必然存在
        //因为xp为红但是xp为根节点的情况不存在
        //不然这里的if判断可能会产生null
        if (xp == (xppl = xpp.left)) {
            //走到这,xp就必定是左红节点，如果xpp有右子节点并且xppr为红
            //此时我们就需要把xppl和xppr的红色向上传递?为什么,因为插入的x节点必是红节点,不允许连续子节点和父节点都是红节点
            //这里进行向上传递红色的操作
            if ((xppr = xpp.right) != null && xppr.red) {
                xppr.red = false;
                xp.red = false;
                xpp.red = true;
                //将xpp赋值给x是因为xpp的所有子节点已经调整好了
                //这就相当于递归回溯调整颜色的过程,调整完颜色后直接从新的x节点开始继续开始下一轮循环
                x = xpp;
            }

            else {
                //如果xpp有右子节点但是为黑
                //或者xpp根本就没有右子节点
                //总之这时已经出现了x和xp两个连续的左红节点,要么都是左红节点,或者x是右红,xp是左红

                if (x == xp.right) {
                    //如果x是右红,那么就要先以xp为轴点进行左旋,形成x和xp都是左红的局面
                    //注意,这里不是把xp赋值给x后把x传进去,而是传进去xp,顺便把xp赋值给x
                    root = rotateLeft(root, x = xp);
                    //这里左旋x就会成为新的xp
                    //这里xp=x.parent也可能是进行赋值操作?
                    //xpp也是赋值操作?
                    xpp = (xp = x.parent) == null ? null : xp.parent;
                }
                //走到这,x和xp就一定都是左红,这里要以xpp为轴点进行右旋
                //这里为毛需要判空?xp不是一定存在?
                if (xp != null) {
                    //注意,这里xp一定是红色,那么xpp必然是黑色
                    //旋转后,xp会成为新的xpp,这里是将xpp的颜色赋值给xp
                    xp.red = false;
                    if (xpp != null) {
                        //将xp的颜色赋值给xpp,因为xp原来是红色
                        xpp.red = true;
                        //右旋,可能会产生新的root节点
                        root = rotateRight(root, xpp);
                    }
                }
            }
        }

        //跟上面的插入情况差不多
        else {
            //走到这,xp必是右红节点
            //将红色向上传递
            if (xppl != null && xppl.red) {
                xppl.red = false;
                xp.red = false;
                xpp.red = true;
                x = xpp;
            }
            else {
                //如果x是左红节点
                if (x == xp.left) {
                    //那么就需要以xp为轴点,向右旋,也就是把xp和x安排到一条直线上,也就是像下面这样
                    //    xpp(xpp不一定有)           xpp
                    //      \                         \
                    //       xp  ---->                 xp
                    //       /                          \
                    //      x                            x
                    root = rotateRight(root, x = xp);
                    xpp = (xp = x.parent) == null ? null : xp.parent;
                }
                //xp是必然存在的,xpp也是必然存在的,步知道为什么会有这两个判断
                if (xp != null) {
                    xp.red = false;
                    if (xpp != null) {
                        xpp.red = true;

                        //   xpp                xp
                        //    \               /  \
                        //     xp ------->   xpp  x
                        //     \
                        //      x
                        root = rotateLeft(root, xpp);
                    }
                }
            }
        }
    }
}
```
