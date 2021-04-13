---
title: AtomicStampedReference源码解析
mathjax: true
data: 2021-04-13 11:42:05
updated:
tags:
- atomic
categories:
- java基础
---

`AtomicStampeddReference`解决了普通CAS操作的ABA问题，当然该类只能存储引用类型，因为泛型只支持引用。具体的解决方法就是为每个引用提供了一个时间戳（实际用int代替），这两个数据由内部静态类`Pair`封装，如下所示：

``` java
public class AtomicStampedReference<V> {

    private static class Pair<T> {
        final T reference;
        final int stamp;
        private Pair(T reference, int stamp) {
            this.reference = reference;
            this.stamp = stamp;
        }

        static <T> Pair<T> of(T reference, int stamp) {
            return new Pair<T>(reference, stamp);
        }
    }

    private volatile Pair<V> pair;
```

## 构造函数

`AtomicStampedReference`的构造函数只有一个，该构造方法要求我们必须提供一个初始时间戳，如下所示：

``` java
public AtomicStampedReference(V initialRef, int initialStamp) {
    pair = Pair.of(initialRef, initialStamp);
}
```

## 更新操作

对于`AtomicStampedReference`的更新，提供了两种方式`compareAndSet`和`weakCompareAndSet`。对于后者来说，它有可能会“虚假”的失败，也就是说，实际上更新成功但是却返回false，并且后者并不提供“happens before”效果，更难使用，尽管后者在某些平台上效率更高。所以一般还是使用`compareAndSet`吧。

``` java
/**
* Atomically sets the value of both the reference and stamp
* to the given update values if the
* current reference is {@code ==} to the expected reference
* and the current stamp is equal to the expected stamp.
*/
public boolean compareAndSet(V   expectedReference,
                                V   newReference,
                                int expectedStamp,
                                int newStamp) {
    Pair<V> current = pair;
    return
        expectedReference == current.reference &&
        expectedStamp == current.stamp &&
        ((newReference == current.reference &&
            newStamp == current.stamp) ||
            casPair(current, Pair.of(newReference, newStamp)));
}

/**
* Atomically sets the value of both the reference and stamp
* to the given update values if the
* current reference is {@code ==} to the expected reference
* and the current stamp is equal to the expected stamp.
*
* <p><a href="package-summary.html#weakCompareAndSet">May fail
* spuriously and does not provide ordering guarantees</a>, so is
* only rarely an appropriate alternative to {@code compareAndSet}.
*/
public boolean weakCompareAndSet(V   expectedReference,
                                    V   newReference,
                                    int expectedStamp,
                                    int newStamp) {
    return compareAndSet(expectedReference, newReference,
                            expectedStamp, newStamp);
}
```

当然，每次更新时都需要提供旧时间戳，如果旧的不符合说明产生了ABA。