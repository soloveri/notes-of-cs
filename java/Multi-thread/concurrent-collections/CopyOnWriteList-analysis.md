---
title: CopyOnWriteList分析
mathjax: true
data: 2021-04-10 21:39:01
updated:
tags:
- concurrent collections
categories:
- java基础
---

## 1. 预备知识

`CopyOnWriteList`是`ArrayList`线程安全的版本。所有更改`CopyOnWriteList`内容的操作都基于`CopyOnWrite`。所谓的`CopyOnWrite`，字如其名，就是说只在更改list内容时，才会对内部数组加锁，将更改后的内容复制到新数组，最后再赋值给list内部的数组。本篇文章将从`CopyOnWriteList`的构造、添加、删除、查询四个方面来分析。

## 2. 架构解析

`CopyOnWriteList`的继承体系比较简单，实现了`utils`包下的`List`接口，并支持随机访问、序列化、克隆等功能，继承关系如下所示：

![CopyOnWriteList-arch](./images/CopyOnWriteList-arch.png)

`CopyOnWriteList`本身的属性也比较简单，如下所示：

![CopyOnWriteList-fields](./images/CopyOnWriteList-fields.png)

一般我们关注是独占锁与内部数组。内部数组是真正存储元素的地方，而独占锁保证了各线程互斥地访问。

### 2.2 添加 

`CopyOnWriteList`的增加逻辑主要由`add`方法完成，对于每次添加，都会上锁，否则会造成多个线程同时添加时复制出多份原数组。我这里就不细说了，下面的代码一看就懂：

``` java
/**
* Appends the specified element to the end of this list.
*
* @param e element to be appended to this list
* @return {@code true} (as specified by {@link Collection#add})
*/
public boolean add(E e) {
    final ReentrantLock lock = this.lock;
    lock.lock();
    try {
        Object[] elements = getArray();
        int len = elements.length;
        Object[] newElements = Arrays.copyOf(elements, len + 1);
        newElements[len] = e;
        setArray(newElements);
        return true;
    } finally {
        lock.unlock();
    }
}
```

### 2.3 删除

对于删除逻辑，其实和添加逻辑差不多。第一步先上锁，然后删除目标元素，最后再将剩余元素拷贝到新数组中，代码如下所示：

``` java
/**
* Removes the element at the specified position in this list.
* Shifts any subsequent elements to the left (subtracts one from their
* indices).  Returns the element that was removed from the list.
*
* @throws IndexOutOfBoundsException {@inheritDoc}
*/
public E remove(int index) {
    final ReentrantLock lock = this.lock;
    lock.lock();
    try {
        Object[] elements = getArray();
        int len = elements.length;
        E oldValue = get(elements, index);
        int numMoved = len - index - 1;
        //拷贝数组
        if (numMoved == 0)
            setArray(Arrays.copyOf(elements, len - 1));
        else {
            Object[] newElements = new Object[len - 1];
            System.arraycopy(elements, 0, newElements, 0, index);
            System.arraycopy(elements, index + 1, newElements, index,
                                numMoved);
            setArray(newElements);
        }
        return oldValue;
    } finally {
        lock.unlock();
    }
}
```

### 2.4 查询

查询可以通过两种方法：

1. `get(int)`方法
2. 迭代器

第一种方法没什么好说的，不用上锁，直接读取即可，如下所示：

``` java
/**
* {@inheritDoc}
*
* @throws IndexOutOfBoundsException {@inheritDoc}
*/
public E get(int index) {
    return get(getArray(), index);
}
private E get(Object[] a, int index) {
    return (E) a[index];
}
```

迭代器遍历的方式还稍微有趣一点，`CopyOnWriteList`的迭代器会对当前内部数组做一个快照，所谓的快照并不是指真正的复制一份，而是持有一个旧数组的引用，在逻辑上做了一个“snapshot”。如下所示：

``` java
public Iterator<E> iterator() {
    return new COWIterator<E>(getArray(), 0);
}

static final class COWIterator<E> implements ListIterator<E> {
    /** Snapshot of the array */
    private final Object[] snapshot;
    //游标
    private int cursor;

    private COWIterator(Object[] elements, int initialCursor) {
        cursor = initialCursor;
        //持有旧数组的引用，迭代器只会遍历旧数组的元素
        snapshot = elements;
    }
    ...
}
```

## 3. 总结

CopyOnWriteArrayList的思想和实现整体上还是比较简单，它适用于处理“读多写少”的并发场景。通过上述对CopyOnWriteArrayList的分析，读者也应该可以发现该类存在的一些问题：

1. 内存的使用
由于CopyOnWriteArrayList使用了“写时复制”，所以在进行写操作的时候，内存里会同时存在两个array数组，如果数组内存占用的太大，那么可能会造成频繁GC,所以CopyOnWriteArrayList并不适合大数据量的场景。

2. 数据一致性
CopyOnWriteArrayList只能保证数据的最终一致性，不能保证数据的实时一致性——读操作读到的数据只是一份快照。所以如果希望写入的数据可以立刻被读到，那CopyOnWriteArrayList并不适合。

## 参考文章

1. [JAVA中的COPYONWRITE容器](https://coolshell.cn/articles/11175.html#%E4%BB%80%E4%B9%88%E6%98%AFCopyOnWrite%E5%AE%B9%E5%99%A8)
2. [Java多线程进阶（二七）——J.U.C之collections框架：CopyOnWriteArrayList](https://segmentfault.com/a/1190000016214572)