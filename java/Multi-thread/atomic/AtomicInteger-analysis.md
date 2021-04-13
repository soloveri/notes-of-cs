---
title: AtomicInteger源码解析
mathjax: true
data: 2021-04-12 11:46:51
updated:
tags:
- atomic
categories:
- java基础
---

整数型原子类`AtomicInteger`，能够保证每次更新时都是原子操作。其中的CAS操作都需要依靠`Unsafe`类来完成，我们需要关注的一般就是构造方法、增加方法与删除方法。

## 1. 构造方法

`AtomicInteger`首先会调用类构造器，初始化当前对象的`valueoffset`用于进行CAS操作，具体值由volatile变量`value`负责维护，字段定义如下所示：

``` java
public class AtomicInteger extends Number implements java.io.Serializable {
    private static final long serialVersionUID = 6214790243416807050L;

    // setup to use Unsafe.compareAndSwapInt for updates
    private static final Unsafe unsafe = Unsafe.getUnsafe();
    private static final long valueOffset;

    static {
        try {
            valueOffset = unsafe.objectFieldOffset
                (AtomicInteger.class.getDeclaredField("value"));
        } catch (Exception ex) { throw new Error(ex); }
    }
    private volatile int value;

    public AtomicInteger(int initialValue) {
        value = initialValue;
    }

    /**
     * Creates a new AtomicInteger with initial value {@code 0}.
     */
    public AtomicInteger() {}
    ...
```

## 2. 增加方法

增加方法与删除方法的逻辑基本一致，就是通过`Unsafe`类来完成，如下所示：

``` java
/**
* Atomically increments by one the current value.
*
* @return the previous value
*/
public final int getAndIncrement() {
    return unsafe.getAndAddInt(this, valueOffset, 1);
}

public final int decrementAndGet() {
    return unsafe.getAndAddInt(this, valueOffset, -1) - 1;
}
```

## 3. 总结

原子类`AtomicBoolean`、`AtomicInteger`、`AtomicLong`、`AtomicReference`其实没有本质区别，所以我这里仅简单介绍了一下`AtomicInteger`，所有的工作都会通过`Unsafe`类来完成。