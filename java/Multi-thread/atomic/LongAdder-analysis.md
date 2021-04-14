---
title: LongAdder源码解析
mathjax: true
data: 2021-04-14 09:53:33
updated:
tags:
- atomic
categories:
- java基础
---

## 1. 预备知识

在Java1.5中，JUC就已经提供了大数原子类`AtomicLong`，但是在Java1.8中，又提供了相同功能的大数原子类`LongAdder`。why？答案是如此的纯粹：为了效率。难道前者的效率就不行了吗？如果在轻微冲突的情况下，二者的效率几乎差不多。但是如果竞争非常激烈，那么因为每次对`AtomicLong`更新时都会使用CAS，激烈竞争导致CAS的成功的概率不大，所以有可能会执行多次无效的CAS操作。那么后者`LongAdder`在更新时采用了分段计数的方法，它在每次更新时不再直接更新具体的数，而是在内部维护了一个基数`base`和增量数组`cells`。在竞争激烈的情况下，每个线程会只会在增量数组中更新自己得到增量。那么如果想要获得最后的结果，只需要将`base`与`sum(cells[i])`相加即可。

那么分段计数的方法就如此完美吗？没有任何缺点吗？在该类的注释中说到：

>This class is usually preferable to AtomicLong when multiple threads update a common sum that is used for purposes such as collecting statistics, not for fine-grained synchronization control.

大意是说该类一般**用于收集一些统计数据**，而不应该用于线程同步，因为增量数中的值是瞬息万变的，那么是有可能直接略过了我们的目标值，比如我们的目标值是1，但是有可能直接从1增加到3。

## 2. 体系结构

`LongAdder`中采用的分段计数是由`Stripe64`类完成的，所以`LongAdder`的继承结构如下所示：

![Stripe64](./images/Stripe64.png)



此类维护一个由原子更新的变量的惰性初始化表，以及一个额外的“基本”字段。表的大小是2的幂。索引使用带掩码的每线程哈希码。此类中的几乎所有声明都是包私有的，可直接由子类访问。

表条目属于Cell类； AtomicLong的变体（通过@ sun.misc.Contended）填充以减少缓存争用。对于大多数原子而言，填充是过大的杀伤力，因为它们通常不规则地散布在内存中，因此彼此之间不会产生太多干扰。但是驻留在数组中的原子对象将倾向于彼此相邻放置，因此在没有这种预防措施的情况下，大多数情况下它们将共享缓存行（对性能产生巨大的负面影响）。

部分由于单元格相对较大，因此我们避免在需要它们之前创建它们。没有争用时，将对基础字段进行所有更新。第一次争用时（基本更新上的CAS失败），表初始化为大小2。进一步争用时，表大小加倍，直到达到大于或等于CPUS数的最接近的2的幂。表插槽在需要之前保持为空（空）。

单个自旋锁（“ cellsBusy”）用于初始化和调整表的大小，以及使用新的Cell填充插槽。当锁不可用时，线程会尝试其他插槽（或基座）。在这些重试期间，争用增加且位置减少，这仍然比替代方法更好。

通过ThreadLocalRandom维护的“线程”探针字段用作每个线程的哈希码。我们让它们保持未初始化为零（如果它们以这种方式出现），直到它们在插槽0中竞争为止。然后将它们初始化为通常不经常与其他对象冲突的值。当执行更新操作时，失败的CASes表示争用和/或表冲突。发生冲突时，如果表的大小小于容量，那么除非有其他线程使用，否则表的大小将增加一倍
握住锁。如果哈希槽为空，并且锁可用，则会创建一个新的单元格。否则，如果存在该插槽，则尝试CAS。重试通过“双重哈希”进行，使用辅助哈希（Marsaglia XorShift）尝试查找空闲插槽。

该表的大小是有上限的，因为当有更多线程时
与CPU相比，假设每个线程都绑定到一个CPU，则将存在一个完美的哈希函数，将线程映射到插槽中以消除冲突。当达到容量时，我们通过随机更改冲突线程的哈希码来搜索此映射。因为搜索是随机的，并且仅通过CAS故障才知道冲突，所以收敛可能很慢，并且由于线程通常永远不会永远绑定到CPUS，因此可能根本不会发生。但是，尽管有这些限制，但是在这些情况下，观察到的竞争率通常较低。

当曾经对其进行哈希处理的线程终止时，以及在将表加倍导致没有线程在扩展的掩码下对其进行哈希处理的情况下，Cell可能变得未使用。在长时间运行的情况下，我们不会尝试检测或删除此类单元格，因为观察到的争用级别会再次出现，因此最终将再次需要这些单元格；对于短命的人来说，没关系。

``` java
abstract class Striped64 extends Number {
    @sun.misc.Contended static final class Cell {
        volatile long value;
        Cell(long x) { value = x; }
        final boolean cas(long cmp, long val) {
            return UNSAFE.compareAndSwapLong(this, valueOffset, cmp, val);
        }

        // Unsafe mechanics
        private static final sun.misc.Unsafe UNSAFE;
        private static final long valueOffset;
        static {
            try {
                UNSAFE = sun.misc.Unsafe.getUnsafe();
                Class<?> ak = Cell.class;
                valueOffset = UNSAFE.objectFieldOffset
                    (ak.getDeclaredField("value"));
            } catch (Exception e) {
                throw new Error(e);
            }
        }
    }

    //有效的CPU核心数，也就是增量数组cells的容量上限
    static final int NCPU = Runtime.getRuntime().availableProcessors();

    /**
     * Table of cells. When non-null, size is a power of 2.
     */
    //增量数组cells，容量必须为2的倍数，因为跟HashMap类似，需要依靠hash值计算对应的索引
    transient volatile Cell[] cells;

    //基数
    transient volatile long base;

    
    //自旋锁，用于互斥访问增量数组cells
    transient volatile int cellsBusy;
    ...
}
```

## 3. 计算逻辑

``` java

/**
 * Handles cases of updates involving initialization, resizing,
 * creating new Cells, and/or contention. See above for
 * explanation. This method suffers the usual non-modularity
 * problems of optimistic retry code, relying on rechecked sets of
 * reads.
 *
 * @param x the value
 * @param fn the update function, or null for add (this convention
 * avoids the need for an extra field or function in LongAdder).
 * @param wasUncontended false if CAS failed before call
 */
final void longAccumulate(long x, LongBinaryOperator fn,
                            boolean wasUncontended) {
    int h;
    if ((h = getProbe()) == 0) {
        ThreadLocalRandom.current(); // force initialization
        h = getProbe();
        wasUncontended = true;
    }
    boolean collide = false;                // True if last slot nonempty
    for (;;) {
        Cell[] as; Cell a; int n; long v;
        if ((as = cells) != null && (n = as.length) > 0) {
            if ((a = as[(n - 1) & h]) == null) {
                if (cellsBusy == 0) {       // Try to attach new Cell
                    Cell r = new Cell(x);   // Optimistically create
                    if (cellsBusy == 0 && casCellsBusy()) {
                        boolean created = false;
                        try {               // Recheck under lock
                            Cell[] rs; int m, j;
                            if ((rs = cells) != null &&
                                (m = rs.length) > 0 &&
                                rs[j = (m - 1) & h] == null) {
                                rs[j] = r;
                                created = true;
                            }
                        } finally {
                            cellsBusy = 0;
                        }
                        if (created)
                            break;
                        continue;           // Slot is now non-empty
                    }
                }
                collide = false;
            }
            else if (!wasUncontended)       // CAS already known to fail
                wasUncontended = true;      // Continue after rehash
            else if (a.cas(v = a.value, ((fn == null) ? v + x :
                                            fn.applyAsLong(v, x))))
                break;
            else if (n >= NCPU || cells != as)
                collide = false;            // At max size or stale
            else if (!collide)
                collide = true;
            else if (cellsBusy == 0 && casCellsBusy()) {
                try {
                    if (cells == as) {      // Expand table unless stale
                        Cell[] rs = new Cell[n << 1];
                        for (int i = 0; i < n; ++i)
                            rs[i] = as[i];
                        cells = rs;
                    }
                } finally {
                    cellsBusy = 0;
                }
                collide = false;
                continue;                   // Retry with expanded table
            }
            h = advanceProbe(h);
        }
        else if (cellsBusy == 0 && cells == as && casCellsBusy()) {
            boolean init = false;
            try {                           // Initialize table
                if (cells == as) {
                    Cell[] rs = new Cell[2];
                    rs[h & 1] = new Cell(x);
                    cells = rs;
                    init = true;
                }
            } finally {
                cellsBusy = 0;
            }
            if (init)
                break;
        }
        else if (casBase(v = base, ((fn == null) ? v + x :
                                    fn.applyAsLong(v, x))))
            break;                          // Fall back on using base
    }
}
```

