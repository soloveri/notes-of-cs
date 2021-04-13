---
title: AtomicIntegerArray源码解析
mathjax: true
data: 2021-04-13 10:56:46
updated:
tags:
- atomic
categories:
- java基础
---

`AtomicIntegerArray`能够保证数组中的每个元素原子地更新。构造方法、增加、减少方法都没什么好说，我认为值得关注的点是仅有计算偏移的方法。我们先来看看它的静态构造块：

``` java
public class AtomicIntegerArray implements java.io.Serializable {
    private static final long serialVersionUID = 2862133569453604235L;

    private static final Unsafe unsafe = Unsafe.getUnsafe();
    private static final int base = unsafe.arrayBaseOffset(int[].class);
    private static final int shift;
    private final int[] array;

    static {
        //scale表示数组中每个元素的字节数，必须都是2的倍数
        int scale = unsafe.arrayIndexScale(int[].class);
        if ((scale & (scale - 1)) != 0)
            throw new Error("data type scale not a power of two");
        //shift表示偏移量
        shift = 31 - Integer.numberOfLeadingZeros(scale);
    }

    private long checkedByteOffset(int i) {
        if (i < 0 || i >= array.length)
            throw new IndexOutOfBoundsException("index " + i);

        return byteOffset(i);
    }

    private static long byteOffset(int i) {
        return ((long) i << shift) + base;
    }
    ...
```

首先静态构造块会计算当前数组元素类型的大小`scale`字段，要求类型只能是4的倍数，当然我们一般也只会用这个类存储int数组。接着会初始化单位偏移长度`shift`。那么对于每个元素在数组中的偏移就等于“元素个数 X 单位偏移长度”。比如我们的元素类型是int类型，那么单位偏移长度`shft`就为2。那么对应于索引为1的元素地址，就是`base + offset==1<<(shift==2)`。索引为i的元素地址同理。

那么我们如果想要更新数组中的某个元素，那么会调用`getAndSet()`，而该方法中又首先会调用`checkedByteOffset()`计算对应的偏移，最后使用`Unsafe`类的CAS操作完成更新。

``` java
public final int getAndSet(int i, int newValue) {
    return unsafe.getAndSetInt(array, checkedByteOffset(i), newValue);
}
```