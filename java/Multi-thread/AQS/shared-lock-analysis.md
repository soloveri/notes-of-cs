---
title: 共享锁源码解析
mathjax: true
data: 2020-12-26 20:36:04
updated: 
tags: 
- shared lock
categories:
- 多线程基础
---


共享锁和独占锁的实现差别不是很大，一个最大的区别就是在共享锁中，当一个线程获取锁后，它会尽可能多地唤醒后继线程
``` java
public final boolean releaseShared(int arg) {
    //如果获取锁成功，那么就需要尝试唤醒后面的线程，因为锁是共享的
    if (tryReleaseShared(arg)) {
        doReleaseShared();
        return true;
    }
    return false;
}

```

``` java
private void doReleaseShared() {
    /*
    * Ensure that a release propagates, even if there are other
    * in-progress acquires/releases.  This proceeds in the usual
    * way of trying to unparkSuccessor of head if it needs
    * signal. But if it does not, status is set to PROPAGATE to
    * ensure that upon release, propagation continues.
    * Additionally, we must loop in case a new node is added
    * while we are doing this. Also, unlike other uses of
    * unparkSuccessor, we need to know if CAS to reset status
    * fails, if so rechecking.
    */
    for (;;) {
        Node h = head;

        if (h != null && h != tail) {
            int ws = h.waitStatus;
            //与独占锁类似，只有头节点的waitStatus == -1，说明后继线程才会被挂起
            if (ws == Node.SIGNAL) {
                if (!compareAndSetWaitStatus(h, Node.SIGNAL, 0))
                    continue;            // loop to recheck cases
                unparkSuccessor(h);
            }
            else if (ws == 0 &&
                        !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))
                continue;                // loop on failed CAS
        }
        if (h == head)                   // loop if head changed
            break;
    }
}
```
`doReleaseShared`这个函数用来唤醒尽可能多地后继线程。为什么要这么做呢？因为这是共享锁，当一个线程获取锁成功后，后继线程有概率成功获得锁，那么这个唤醒动作什么时候终止呢？答案是：直到没有线程成功锁为止。这个操作如何实现？就是通过下面的代码：

``` java
for (;;) {
    Node h = head;

    ...
    if (h == head)                   // loop if head changed
        break;
}
```

这个死循环动作的终止条件是：`h==head`。这个条件说明什么？说明head没有被改变，没被改变就等同于没有新线程获取锁，所以唤醒动作可以终止了。那么具体的唤醒动作是怎么实现的？请见如下代码：

``` java
for (;;) {
    Node h = head;

    if (h != null && h != tail) {
        int ws = h.waitStatus;
        //与独占锁类似，只有头节点的waitStatus == -1，说明后继线程才会被挂起
        if (ws == Node.SIGNAL) {
            if (!compareAndSetWaitStatus(h, Node.SIGNAL, 0))
                continue;            // loop to recheck cases
            unparkSuccessor(h);
        }
        else if (ws == 0 &&
                    !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))
            continue;                // loop on failed CAS
    }
    ...
}
```

对于代码中的第一个`if`条件：`(h != null && h != tail)`，说明需要同步队列中除head之外，必须还存在一个节点。不然唤醒谁呢？

对于第二个`if`条件：`ws == Node.SIGNAL`，这个条件的含义是只有`head.waitStatus == -1`，才表示后续节点被挂起。具体的挂起操作见`shouldParkAfterFailedAcquire`函数。

对于第三个`if`条件：`(!compareAndSetWaitStatus(h, Node.SIGNAL, 0))`，这里使用CAS执行`head.waitStatus=0`是为了防止多个线程多次唤醒同一个head之后的后继节点。


``` java
public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
        doReleaseShared();
        return true;
    }
    return false;
}
```

CountDownLatch

``` java
protected boolean tryReleaseShared(int releases) {
    // Decrement count; signal when transition to zero
    for (;;) {
        int c = getState();
        //这么判断是害怕有傻缺，设置count==5，但是却有6个线程调用countDown
        if (c == 0)
            return false;
        int nextc = c-1;
        if (compareAndSetState(c, nextc))
            return nextc == 0;
    }
}
```