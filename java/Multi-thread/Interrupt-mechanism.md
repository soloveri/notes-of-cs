---
title: 中断机制
mathjax: true
date: 2021-01-10 15:57:22
updated:
tags: 
- interrupt
categories:
- 多线程基础
---

在多线程环境下，终止一个线程的任务最好的方法是通过中断。而Java的中断类似于通知协作机制，被中断的线程并不会立即停止自己的任务，而是仅仅收到了中断的通知，具体怎么处理收到的中断，这需要用户自己定义。那么为什么说Java的中断类似于通知机制？我们首先需要了解中断到底做了什么。

## 1. 实施中断

Java中的中断操作只需要调用目标线程的`interrupt()`方法即可完成。那么这个方法到底做了什么？我们来看看具体的实现源码：

``` java
/**
    * Interrupts this thread.
    *
    * <p> Unless the current thread is interrupting itself, which is
    * always permitted, the {@link #checkAccess() checkAccess} method
    * of this thread is invoked, which may cause a {@link
    * SecurityException} to be thrown.
    *
    * <p> If this thread is blocked in an invocation of the {@link
    * Object#wait() wait()}, {@link Object#wait(long) wait(long)}, or {@link
    * Object#wait(long, int) wait(long, int)} methods of the {@link Object}
    * class, or of the {@link #join()}, {@link #join(long)}, {@link
    * #join(long, int)}, {@link #sleep(long)}, or {@link #sleep(long, int)},
    * methods of this class, then its interrupt status will be cleared and it
    * will receive an {@link InterruptedException}.
    *
    * <p> If this thread is blocked in an I/O operation upon an {@link
    * java.nio.channels.InterruptibleChannel InterruptibleChannel}
    * then the channel will be closed, the thread's interrupt
    * status will be set, and the thread will receive a {@link
    * java.nio.channels.ClosedByInterruptException}.
    *
    * <p> If this thread is blocked in a {@link java.nio.channels.Selector}
    * then the thread's interrupt status will be set and it will return
    * immediately from the selection operation, possibly with a non-zero
    * value, just as if the selector's {@link
    * java.nio.channels.Selector#wakeup wakeup} method were invoked.
    *
    * <p> If none of the previous conditions hold then this thread's interrupt
    * status will be set. </p>
    *
    * <p> Interrupting a thread that is not alive need not have any effect.
    *
    * @throws  SecurityException
    *          if the current thread cannot modify this thread
    *
    * @revised 6.0
    * @spec JSR-51
    */
public void interrupt() {
    if (this != Thread.currentThread())
        checkAccess();

    synchronized (blockerLock) {
        Interruptible b = blocker;
        if (b != null) {
            interrupt0();           // Just to set the interrupt flag
            b.interrupt(this);
            return;
        }
    }
    interrupt0();
}
```

注释很长，我们分开慢慢细品。首先是第一段：

>Unless the current thread is interrupting itself, which is always permitted, the checkAccess method of this thread is invoked, which may cause a SecurityException to be thrown.

大意是说：任何一个线程都肯定能中断它自己，如果希望中断别的线程，那么需要通过`checkAccess()`方法检查权限，并且可能会抛出`SecurityException`异常。这很好理解。任何一个线程都可能接受到中断。

接着是第二段：
>If this thread is blocked in an invocation of the wait(), wait(long), or wait(long, int) methods of the Object class, or of the join(), join(long), join(long, int), sleep(long), or sleep(long, int), methods of this class, then its interrupt status will be cleared and it will receive an InterruptedException.

上面的注释中提到了两个新鲜玩意，`interrupt status`(中断状态)和`InterruptException`。中断状态就是实现中断通知机制的关键。当一个线程被中断后，它的中断标记可能会被改变。为什么说可能？
因为有些例外情况只会抛出中断异常而不是设置中断状态。而这些例外情况在第二段的注释已全部声明：如果中断目标是因为调用了以下的方法进入阻塞状态，那么目标线程的中断位会被**清除**，并且目标线程会收到`InterruptedException`异常：

- `Object.wait()`
- `Object.wait(long)`
- `Object.wait(long,int)`
- `Thread.join()`
- `Thread.join(long)`
- `Thread.join(long,int)`
- `Thread.sleep(long)`
- `Thread.sleep(long,int)`

接着是第三、四关于NIO的中断情况：

>If this thread is blocked in an I/O operation upon an InterruptibleChannel then the channel will be closed, the thread's interrupt status will be set, and the thread will receive a java.nio.channels.ClosedByInterruptException.
If this thread is blocked in a java.nio.channels.Selector then the thread's interrupt status will be set and it will return immediately from the selection operation, possibly with a non-zero value, just as if the selector's wakeup method were invoked.

如果中断目标是因为调用了`InterruotibleChannel()`而被阻塞，那么当收到中断时channel将被关闭，并且**设置中断目标的中断状态**，同时会收到`java.nio.channels.ClosedByInterruptException`。
或者中断目标是因为调用了`channels.Selector()`而被阻塞，那么当收到中断时该方法会立即返回，并且**设置中断目标的中断状态**。

接下来是最后一段：

>f none of the previous conditions hold then this thread's interrupt status will be set.Interrupting a thread that is not alive need not have any effect.

很简单，就是上面的情况除外，其他任何时候发生中断只会设置中断目标的中断标志。例如在运行时发起中断，目标线程只会设置中断标志。

## 2. 检测中断

而检测中断的方法有两种：`interrupted`和`isInterrupted`。这两种方法都是检测当前当前线程的中断状态。唯一的区别就是：`interrupted`会清除调用线程的中断状态。也就是说如果连续调用两次该方法（在两次调用之间没有发生中断），中断标志一定是`false`。那么这两个方法一般用在哪里呢？这就跟中断发生的场景有关了，中断发生的情况一般只有两种：

1. 调用`wait`阻塞后，发生中断
2. 线程运行时，发起中断

对于第一种情况，因为会抛出中断异常，所以我们一般用以下模式检测中断：

``` java
public void run() {
    while(true) {
        try {
            // do some task
            // blocked by calling wait/sleep/join
        } catch (InterruptedException ie) {  
            break; // 这里使用break, 可以使我们在线程中断后退出死循环，从而终止线程。
        }
    }
}
```

对于第二种情况，因为只会设置中断标志，所以我们一般使用`interrupted`或者`isinterrupted`检测中断情况：

``` java
public void run() {
    //isInterrupted() 用于终止一个正在运行的线程。
    while (!isInterrupted()) {
        try {
            //    do something
            }
        } catch (InterruptedException ie) {  
            // 在这里不做任何处理，仅仅依靠isInterrupted检测异常
        }
    }
}
```

## 3. 总结

Java中的中断只是一种通知机制，并不会立即中断目标线程，被中断的线程如何响应中断完全是程序员自己的事。中断机制的核心内容就是中断标志`interrupted status`与中断异常`InterruptException`。

## 参考文章

[Thread类源码解读(3)——线程中断interrupt](https://segmentfault.com/a/1190000016083002)


