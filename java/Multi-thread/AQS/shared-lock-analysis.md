---
title: 从Semaphore中学习共享锁原理
mathjax: true
data: 2020-12-26 20:36:04
updated: 2020-12-28 10:24:02
tags: 
- shared lock
categories:
- 多线程基础
---


共享锁和独占锁的实现差别不是很大，一个最大的区别就是在共享锁中，当一个线程获取锁后，它会尽可能多地唤醒后继线程

## 1.共享锁的获取

对于共享锁的获取，自定义同步器肯定会首先调用AQS的模板方法`acquireShared`，然后会调用自定义的锁获取方法`tryAcquireShared`。在共享锁模式下，`tryAcquireShared`的返回值有三种含义：

- 返回值小于0表示获取锁失败
- 返回等于0表示当前线程获取锁成功，但是不保证后续的获取会成功
- 返回值大于0表示当前线程获取成功，并且后续的获取会成功，但是必须检查锁的有效性

所以当`tryAcquireShared`返回值小于0时，则调用`doAcquireShared`将当前线程放入同步队列，准备阻塞，`tryAcquireShared`代码如下所示：

``` java
public final void acquireShared(int arg) {
    if (tryAcquireShared(arg) < 0)
        doAcquireShared(arg);
}
```

`doAcuqiredShared`的主要功能就是将同步队列中的线程挂起或者在线程获取锁后移出同步队列，代码如下所示：

``` java
private void doAcquireShared(int arg) {
    final Node node = addWaiter(Node.SHARED);
    boolean failed = true;
    try {
        boolean interrupted = false;
        for (;;) {
            final Node p = node.predecessor();
            //如果node的前向节点为head，说明轮到node抢锁了
            if (p == head) {
                int r = tryAcquireShared(arg);
                //如果tryAcquireShared返回值不小于0，说明可以唤醒node的后继线程来获取共享锁了
                if (r >= 0) {
                    setHeadAndPropagate(node, r);
                    p.next = null; // help GC
                    if (interrupted)
                        selfInterrupt();
                    failed = false;
                    return;
                }
            }
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                interrupted = true;
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
```

如果有线程获取共享锁成功，则会调用`setHeadAndPropagate`唤醒`node`的后继线程。我们来看看具体的实现代码：

``` java
private void setHeadAndPropagate(Node node, int propagate) {
    Node h = head; // Record old head for check below
    setHead(node);
    /*
    * Try to signal next queued node if:
    *   Propagation was indicated by caller,
    *     or was recorded (as h.waitStatus either before
    *     or after setHead) by a previous operation
    *     (note: this uses sign-check of waitStatus because
    *      PROPAGATE status may transition to SIGNAL.)
    * and
    *   The next node is waiting in shared mode,
    *     or we don't know, because it appears null
    *
    * The conservatism in both of these checks may cause
    * unnecessary wake-ups, but only when there are multiple
    * racing acquires/releases, so most need signals now or soon
    * anyway.
    */
    if (propagate > 0 || h == null || h.waitStatus < 0 ||
        (h = head) == null || h.waitStatus < 0) {
        Node s = node.next;
        if (s == null || s.isShared())
            doReleaseShared();
    }
}
```

在`setHeadAndPropagate`中首先会重新设置头节点`head`，因为当前线程已经获取了锁，所以不需要保证线程安全。随后要经过一系列检查才会调用`doReleaseShared`执行真正的唤醒后继线程的操作。我们来看看这一系列的检查包括什么：

1. propagate > 0
2. h == null 或者 (h = head) == null
3. h.waitStatus < 0

其中，第一个条件很正常，当`propagate`的返回值大于0时，说明后继线程如果被唤醒，那么它们有概率获得锁。但是第二个条件我实在是无法理解，在进入`setHeadAndPropagate`函数之前，一定会调用`addWaiter`初始化同步队列，所以h不可能为空，这里为什么需要进行多余的判空操作？对于最后一个条件，`h.waitStatus<0`说明存在后继线程被挂起的情况。

假设检查通过，会执行`doReleaseShared`用来唤醒后继线程。这个方法可以说是共享锁的核心，而且它也会在线程释放共享锁时调用，总共会在两个位置被调用。为什么需要这么做？对于释放锁后调用此方法是可以理解的，不然同步队列的线程怎么获取锁呢？但是当线程获取锁后，还调用此方法，是因为**共享锁**希望能够被尽可能多的线程持有。当一个线程获取成功后，它有责任让更多的后继来尝试。`doReleaseShared`会被调用两次的原因解释清楚了，具体的分析请见共享锁的释放一章。

## 2.共享锁的释放

首先当共享锁释放时，会调用AQS的`releaseShared`方法。在`releaseShared`中会首先调用用户自定义的释放锁方法`tryReleaseShared`，`releaseShared`实现代码如下：

``` java
public final boolean releaseShared(int arg) {
    //调用用户自定义的释放锁方法
    if (tryReleaseShared(arg)) {
        doReleaseShared();
        return true;
    }
    return false;
}
```

如果锁释放成功，则会调用`doReleaseShared`唤醒当前节点的后继线程：

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

`doReleaseShared`这个函数用来唤醒尽可能多的处于同步队列的后继线程，为什么要这么做呢？因为这是共享锁，当一个线程获取锁成功后，不必等到当前线程释放后才让后继线程来抢锁，可以让后继线程和当前线程共同使用锁嘛。那么这个唤醒动作什么时候终止呢？答案是：直到没有线程成功锁为止。这个操作如何实现？就是通过下面的代码：

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

上面代码中的四处if条件我们需要好好理解一下。

对于代码中的**第一个**`if`条件：`(h != null && h != tail)`，说明需要同步队列中除head之外，必须还存在一个节点。不然唤醒谁呢？

对于**第二个**`if`条件：`(ws == Node.SIGNAL)`，这个条件的含义是只有`head.waitStatus == -1`，才表示后续节点被挂起。具体的挂起操作见`shouldParkAfterFailedAcquire`函数。

对于**第三个**`if`条件：`(!compareAndSetWaitStatus(h, Node.SIGNAL, 0))`，这里使用CAS执行`head.waitStatus=0`是为了防止多个线程多次唤醒同一个head之后的后继节点。这里为什么会有多个线程唤醒同一个head的后继节点？这就跟共享模式的唤醒机制有关了。假设现在同步队列如下：

![doReleaseShared](images/doReleaseShared-p1.drawio.svg)

当节点A调用`setHeadAndPropagate`重新设置head出队后，随后进入`doReleaseShared`时，发现同步队列中还有节点，那么当A成功执行`compareAndSetWaitStatus(h, Node.SIGNAL, 0)`后，执行`unparkSuccessor`唤醒节点B，此时节点A开始了下一次循环。

现在假设节点B也成功获取了锁，在`setHeadAndPropagate`中改变了head，随后也进入了`doReleaseShared`,此时同步队列状态如下所示：

![doReleaseShared](images/doReleaseShared-p2.drawio.svg)

此时线程A和线程B操作的可能是同一个head。假设A唤醒B，B成功获得锁，改变了head，A会再次进入`doReleaseShared`，并且B也会因为成功获得锁首次调用`doReleaseShared`，那么A和B操作的就是同一个head，而唤醒C只需要做一次，CAS来保证这个“一次”。

对于**第四个**`if`条件：`(ws == 0 && !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))`，这也可能是为了性能的极致优化。首先我们需要知道能够走到这个条件的状态是同步队列中必须有两个节点。如果`ws==0`为true，则说明此时同步队列中有可能所有的节点都没有挂起，或者原来的尾节点tail成为了新的头节点head。而`compareAndSetWaitStatus(h, 0, Node.PROPAGATE)`失败则说明头节点head的状态被另外的线程的改变了，谁有资格改head的`waitStatus`？只有一种情况：那就是后继节点挂起了，才会将前置节点的`waitStatus`设置为-1。以下图为例：
![doReleaseShared](images/doReleaseShared-p3.drawio.svg)

原始队列只有节点C，此时是有机会获得锁的，如图4-1所示。假设节点C出队，则有(`head.ws == 0`）。在做CAS之前，节点D入队并挂起，如图4-3所示。C之后的节点D明明有机会获得锁的，因为进入`doReleaseShared`时，队列中也只有一个节点，但是却不小心被刮起了，这个挂起完全没有意义。所以直接使用`continue`进入下一轮循环唤醒刚刚被挂起的线程。那么为什么不直接调用unparkSuccssor唤醒然后continue呢？

## 3. 新状态：PROPAGATE

在`doReleaseShared`第四个`if`条件中，我们发现了一点新东西，那就是`Node.PROPAGATE`。这个状态是什么？用来干嘛的？经过[网上的查阅](https://www.cnblogs.com/micrari/p/6937995.html)，PROPAGATR是用来修复[JDK-6801020](https://bugs.java.com/bugdatabase/view_bug.do?bug_id=6801020)。代码改动如下所示：
![diff](images/diff-AQS.png)

如果执行了如下代码，那么则有可能导致主线程被挂起：

``` java
public class TestSemaphore {

    private static Semaphore sem = new Semaphore(0);

    private static class Thread1 extends Thread {
        @Override
        public void run() {
            sem.acquireUninterruptibly();
        }
    }

    private static class Thread2 extends Thread {
        @Override
        public void run() {
            sem.release();
        }
    }

    public static void main(String[] args) throws InterruptedException {
        for (int i = 0; i < 10000000; i++) {
            Thread t1 = new Thread1();
            Thread t2 = new Thread1();
            Thread t3 = new Thread2();
            Thread t4 = new Thread2();
            t1.start();
            t2.start();
            t3.start();
            t4.start();
            t1.join();
            t2.join();
            t3.join();
            t4.join();
            System.out.println(i);
        }
    }
}
```

现在t3、t4获得锁，同步队列如下所示：

![propagate](images/propagate.drawio.svg)

t1时刻: t4释放锁，调用releaseShared，执行unparkSuccssor，唤醒t2。将head的waitStatus从-1设置0，唤醒t2
t2时刻：线程t2执行tryAcquireShared返回propagate=0，获取锁，还未执行setHeadAndPropagate
t3时刻：线程t3释放锁，执行releaseShared，读取到head.waitStatus =0（因为此时节点A还未出队），不会执行unparkSuccssor，这里的releaseShared是老版本的，如下所示：

``` java
public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
        Node h = head;
    if (h != null && h.waitStatus != 0){ 
        unparkSuccessor(h);
        return true;
    }
    return false;
}
```

t4时刻，线程t2继续执行setHeadAndPropagate，老版本setHeadAndPropagate代码如下所示：

``` java
private void setHeadAndPropagate(Node node, int propagate) {
    setHead(node);
    if (propagate > 0 && node.waitStatus != 0) {
        Node s = node.next;
        if (s == null || s.isShared())
        unparkSuccessor(node);
    }   
}
```

此时propogate==0，因为是`&&`，不会执行unparkSuccssor，线程t1永远不会被唤醒，那么引入的PROPAGATE是如何解决这个问题的呢？还是采用上述相同的执行顺序：

t1时刻: t4释放锁，调用releaseShared，执行unparkSuccssor，将head的waitStatus从-1设置0，唤醒t2
t2时刻：线程t2执行tryAcquireShared返回0，获取锁，还未执行setHeadAndPropagate
t3时刻：线程t3释放锁，执行releaseShared，执行doReleaseShared，如果此时能成功`compareAndSetWaitStatus(h, 0, Node.PROPAGATE)`，说明后继线程还在挂起，此时执行head.waitStatus==PROPOGATE。
t4时刻，线程t2继续执行setHeadAndPropagate，新版如下所示：

```java
private void setHeadAndPropagate(Node node, int propagate) {
    Node h = head; // Record old head for check below
    setHead(node);
    if (propagate > 0 || h == null || h.waitStatus < 0 ||
        (h = head) == null || h.waitStatus < 0) {
        Node s = node.next;
        if (s == null || s.isShared())
            doReleaseShared();
    }
}
```

虽然propagate==0，但是head.waitStatus ==PROPAGATE <0,能够成功执行doReleaseShared。在doReleaseShared中，因为新的head（也就是t2）的waitStatus = -1，所以能够成功执行unparkSuccssor，唤醒t1。

那么引入PROPAGATE状态后，在不考虑conditionObject的条件下，AQS中的状态转换图是如何的呢？

![status](images/state-transition.drawio.svg)

`PROPAGATE`状态只会赋值给头节点head。其他节点没有资格转移到这个状态。但是我并没有找到从`PROPAGATE`转化到`0`的代码，与参考文章[2]的理解略有不同。

## 4.共享锁的应用

CountDownLatch和Semaphore都是基于共享锁实现的。对于Semaphore，如果了解共享锁的获取与释放，并没有什么难以理解。而CountDownLatch则有点特殊。CountDownLatch的基本效果是一组线程等待另外一组线程工作完成。使用例子如下所示：

``` java
public class CountdownLatchExample {

    public static void main(String[] args) throws InterruptedException {
        final int totalThread = 10;
        CountDownLatch countDownLatch = new CountDownLatch(totalThread);
        ExecutorService executorService = Executors.newCachedThreadPool();
        for (int i = 0; i < totalThread; i++) {
            executorService.execute(() -> {
                System.out.print("run..");
                countDownLatch.countDown();
            });
        }
        countDownLatch.await();
        System.out.println("end");
        executorService.shutdown();
    }
}
```

对于调用`CountDownlatch.await()`的线程，会将其加入同步队列，直到调用`countDownLatch.countDown`的次数达到规定次数。这也就是调用`tryReleaseShared`释放锁的过程。代码如下所示：

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

可以看出，只有在`c`第一次被设置为0时，才会返回true。返回true后，则会唤醒队列中被挂起的线程。而线程又会调用`tryAcquireShared`，代码如下所示：

``` java
protected int tryAcquireShared(int acquires) {
    return (getState() == 0) ? 1 : -1;
}
```

所以说，当CountDownLatch减为0时，同步队列中的等待线程都会被唤醒。达到了一组线程等待另外一组线程的效果。

## 参考文章

1. [逐行分析AQS源码(3)——共享锁的获取与释放](https://segmentfault.com/a/1190000016447307)

2. [AbstractQueuedSynchronizer源码解读](https://www.cnblogs.com/micrari/p/6937995.html)

3. [引入PROPAGATE之后的AQS差异](http://gee.cs.oswego.edu/cgi-bin/viewcvs.cgi/jsr166/src/main/java/util/concurrent/locks/AbstractQueuedSynchronizer.java?r1=1.73&r2=1.74)

4.[面试官问我AQS中的PROPAGATE有什么用？](https://jishuin.proginn.com/p/763bfbd33115)