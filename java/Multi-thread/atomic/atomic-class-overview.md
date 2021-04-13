---
title: 原子类总览
mathjax: true
data: 2021-04-11 20:37:00
updated:
tags:
- atomic class
categories:
- java基础
---

J.U.C包提供了许多原子类，我按照功能分了四类，如下所示：
|  普通原子类   | 原子更新的数组  | 原子更新对象字段的updater  | 大数原子类  |
|  ----  | ----  | ----  | ----  |
| AtomicBoolean AtomicInteger <br> AtomicLong AtomicReference atomicMarkableReference AtomicStampedReference | AtomicIntegerArray AtomicLongArray AtomicReferenceArray |  AtomicIntegerFiledUpdater AtomicLongFiledUpdater AtomicReferenceUpdater| LongAccumulator DoubleAccumulator LongAdder DoubleAdder |

**普通原子类**下的六种，

## 2. 核心类Unsafe

不管是原子类还是AQS锁以及其他的CAS操作，全都是依靠`sun.misc`包下的`Unsafe`类完成。之所以叫`Unsafe`，是因为该类的方法都是native方法，能够直接以类似于指针的方式操作对象中的数组，这样就破坏了Java程序所恪守的不使用指针，并且如果操作不当，可能会造成未知后果。所以只有通过启动类加载器加载的类才能使用该类。当然，我们可以通过反射破坏这一规则。

`Unsafe`类采用的是饿汉单例模式，如下所示：

``` java
public final class Unsafe {
    private static final Unsafe theUnsafe;
    ...

    private Unsafe() {
    }

    static {
        registerNatives();
        Reflection.registerMethodsToFilter(Unsafe.class, new String[]{"getUnsafe"});
        theUnsafe = new Unsafe();
        ...
    }
    @CallerSensitive
    public static Unsafe getUnsafe() {
        Class var0 = Reflection.getCallerClass();
        //判断调用者的类加载器是否为null，因为null表示启动类加载器
        if (!VM.isSystemDomainLoader(var0.getClassLoader())) {
            throw new SecurityException("Unsafe");
        } else {
            return theUnsafe;
        }
    }
    
}
```

我们可以使用`getUnsafe()`获取单例，当然使用这种方法的前提是该方法的调用者必须通过启动类加载器来加载。

## 3.总结

原子类非常多，但是大部分都只是数据类型不同，所以我仅分析了每个类别下的代表类：

1. 普通原子类：
    + [AtomicInteger](./AtomicInteger-analysis.md)
    + [AtomicStampedReference](./AtomicStampedReference-analysis.md)
2. 原子数组：
    + [AtomicIntegerArray](./AtomicIntegerArray-analysis.md)
3. 原子更新对象的updater：
    + AtomicIntegerFiledUpdater
4. 大数原子类
    + [LongAccumulator](./LongAccumulator-analysis.md)