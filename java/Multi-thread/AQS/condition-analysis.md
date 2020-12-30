---
title: Condition队列
mathjax: true
data: 2020-12-29 14:54:44
updated:
tags: 
- condition queue
categories:
- 多线程基础
---

`Condition`接口的功能用来实现类似于`synchronized`的await()/signal()通知机制。但是比`synchronized`的通知机制更丰富、更灵活。我们知道，`synchronized`锁内部维护了一个`waitList`保存调用了`wait()`主动释放锁的线程。AQS的`waitList`功能就是通过`Condition`内部维护的`Condition queue`实现的。

与AQS的同步队列相似，`Condition queue`也是由`Node`类型的节点组成的。但是这里并没有使用`Node`的prev、next指针组成双向队列，而是通过一组额外的指针`firstWaiter`和`lastWaiter`维护了一个单向队列。`condition queue`的组成元素如下图所示：

![condition queue](images/condition-queue.png)

我们发现还有两个没见过的元素：`REINTERRUPT`和`THROW_IE`。这两个元素与线程wait之后发生的中断有关，这放到后面再解释。了解了基本情况，那么我们就来看看AQS的wait/notify机制是如何实现的。

## 挂起机制

在AQS中，主动挂起是通过`await()`方法实现的，与`synchronized`类似，调用`await()`的线程必须是获得锁的线程。那万一有人故意在没有获得锁的时候调用呢？这种情况如何处理？暂时不清楚。`await()`方法实现如下：

``` java
public final void await() throws InterruptedException {
    //当线程发生中断时，直接抛出异常
    if (Thread.interrupted())
        throw new InterruptedException();
    // 将当前线程加入condition queue
    Node node = addConditionWaiter();
    // 释放当前线程持有的锁
    int savedState = fullyRelease(node);
    int interruptMode = 0;
    // 如果当前线程仍然在condition queue中，那么就主动park，知道被唤醒
    while (!isOnSyncQueue(node)) {
        LockSupport.park(this);
        if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
            break;
    }
    // 处理park期间发生中断的情况
    if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
        interruptMode = REINTERRUPT;
    if (node.nextWaiter != null) // clean up if cancelled
        unlinkCancelledWaiters();
    if (interruptMode != 0)
        reportInterruptAfterWait(interruptMode);
}
```

线程调用`await()`之后，首先会将当前线程加入`condition queue`，然后完全释放当前线程持有的锁，最后挂起当前线程直到当前线程被中断或者被`signal`唤醒。我们先来分析线程从调用`await()`到被挂起这一阶段所发生的事情。

### wait机制

`condition queue`是一个单向队列，因为能够调用`await()`的线程，在正确的情况下都已经获得了锁，所以直接操作单向队列是线程安全的，具体的实现代码如下所示：

``` java
// 将当前线程加入队列
private Node addConditionWaiter() {
    Node t = lastWaiter;
    // If lastWaiter is cancelled, clean out.
    //如果condition queue不为空，并且最后一个节点不在condition queue中
    // 那么就剔除队列中的所有取消节点
    if (t != null && t.waitStatus != Node.CONDITION) {
        unlinkCancelledWaiters();
        t = lastWaiter;
    }
    Node node = new Node(Thread.currentThread(), Node.CONDITION);
    if (t == null)
        firstWaiter = node;
    else
        t.nextWaiter = node;
    lastWaiter = node;
    return node;
}

// 剔除所有的非等待节点
private void unlinkCancelledWaiters() {
    Node t = firstWaiter;
    //trail始终指向队列中最后一个有效节点
    Node trail = null;
    while (t != null) {
        Node next = t.nextWaiter;
        //如果当前节点仍不为Node.CONDITION状态
        if (t.waitStatus != Node.CONDITION) {
            t.nextWaiter = null;
            //如果仍没有找到一个有效节点
            if (trail == null)
                // 那么就假设next是有效节点
                firstWaiter = next;
            // 如果已经找到了有效节点，那么就跳过当前节点
            else
                trail.nextWaiter = next;
            
            if (next == null)
                lastWaiter = trail;
        }
        else
            trail = t;
        t = next;
    }
}
```

节点入队的逻辑比较简单，如果条件队列的最后一个节点失效了，那么就会一次性剔除队列中所有的失效节点。**那么这里就出现了一个问题：`condition queue`中的节点的waitStatus什么时候会被修改成非`Node.CONDITION`？** 有人说是超时、中断会被更改，没找到啊？此问题仍待解决。

当前线程找到最后一个有效节点入队后，就会使用所有持有的锁。这里为什么要指**所有**？因为有可能发生锁重入的情况。这也就是释放锁为什么叫`fullyRelease`。

``` java
//释放目前持有的锁，包括可重入
final int fullyRelease(Node node) {
    boolean failed = true;
    try {
        int savedState = getState();
        //调用AQS框架的释放方法，最终又会调用用户自定的tryRelease
        if (release(savedState)) {
            failed = false;
            return savedState;
        }
        //释放锁失败，则说明当前线程根本就没有持有锁 
        else {
            throw new IllegalMonitorStateException();
        }
    } finally {
        if (failed)
            node.waitStatus = Node.CANCELLED;
    }
}
```

在前面我们曾说到，调用`await()`的线程必须持有锁，但是有可能有人故意在没有持有锁的线程中调用`await()`。在`await()`中并没有对这一特殊情况进行处理，其实AQS是把这个检查交给用户自己去定义了。例如在`reentrantLock`自定义的`tryRelease`中，如果当前线程没有持有锁，则释放失败。

``` java
protected final boolean tryRelease(int releases) {
    int c = getState() - releases;
    //当前线程并没有持有锁，直接抛出异常
    if (Thread.currentThread() != getExclusiveOwnerThread())
        throw new IllegalMonitorStateException();
    boolean free = false;
    if (c == 0) {
        free = true;
        setExclusiveOwnerThread(null);
    }
    setState(c);
    return free;
}
```

如果释放锁时抛出异常，那么会将当前已经进入`condition queue`的节点的waitStatus设为Node.CANCELLED（原来这也是在条件队列中生成取消节点的一种方法）。释放锁之后需要做的就是主动挂起当前线程，直到被中断或者被`signal`。从下面的代码中我们发现，如果当前线程被唤醒之后仍在条件队列中，那么继续会被主动挂起。？？？将被挂起的线程移除条件队列难道不是通过`await()`实现的？是谁？我们想想，正常情况下，是谁把挂起的线程唤醒的？是`signal`或者发生的中断。那么有没有可能就是这二者偷偷做的呢？

``` java
public final void await() throws InterruptedException {
    ...
    //被唤醒之后，如果当前节点不在同步队列中，那么继续park
    while (!isOnSyncQueue(node)) {
        LockSupport.park(this);
        if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
            break;
    }
    ...
}
```

### signal机制

当某个条件满足时，线程可以通过调用`signal()`方法唤醒`condition queue`中的某个线程或者使用`signalALL()`方法唤醒`condition queue`中的所有线程。注意，调用`await()`的线程和调用`signal()`的线程不是同一个哦。`signal()`和`signalALL()`的具体实现差不多。我先详细一下已下`singal()`吧。具体代码如下所示：

``` java "signal"
public final void signal() {
    if (!isHeldExclusively())
        throw new IllegalMonitorStateException();
    Node first = firstWaiter;
    if (first != null)
        doSignal(first);
}
```

``` java
private void doSignal(Node first) {
    do {
        if ( (firstWaiter = first.nextWaiter) == null)
            lastWaiter = null;
        first.nextWaiter = null;
    } while (!transferForSignal(first) &&
                (first = firstWaiter) != null);
}
```

``` java
final boolean transferForSignal(Node node) {
    /*
        * If cannot change waitStatus, the node has been cancelled.
        */
    if (!compareAndSetWaitStatus(node, Node.CONDITION, 0))
        return false;

    /*
        * Splice onto queue and try to set waitStatus of predecessor to
        * indicate that thread is (probably) waiting. If cancelled or
        * attempt to set waitStatus fails, wake up to resync (in which
        * case the waitStatus can be transiently and harmlessly wrong).
        */
    Node p = enq(node);
    int ws = p.waitStatus;
    if (ws > 0 || !compareAndSetWaitStatus(p, ws, Node.SIGNAL))
        LockSupport.unpark(node.thread);
    return true;
}

```

``` java
final boolean isOnSyncQueue(Node node) {
    if (node.waitStatus == Node.CONDITION || node.prev == null)
        return false;
    if (node.next != null) // If has successor, it must be on queue
        return true;
    /*
        * node.prev can be non-null, but not yet on queue because
        * the CAS to place it on queue can fail. So we have to
        * traverse from tail to make sure it actually made it.  It
        * will always be near the tail in calls to this method, and
        * unless the CAS failed (which is unlikely), it will be
        * there, so we hardly ever traverse much.
        */
    return findNodeFromTail(node);
    }

```





## 通知机制


## 参考文章

1. [逐行分析AQS源码(4)——Condition接口实现](https://segmentfault.com/a/1190000016462281)