---
title: 多线程基础
mathjax: true
date: 2020-04-16 18:57:12
updated: 2020-06-21 20:36:26
tags:
- 多线程
categories:
- Java
---

多进程是为了提高CPU效率，而多线程是为了提高程序使用率？我咋感觉不对啊，多线程通信方便，资源浪费小。并且多线程能不能提高效率得看是什么任务。

总而言之：**多进程为操作系统提供了并发的可能，多进程为单个程序提供了并发的能力**。

简而言之：多线程就是程序内部有多条执行路径，这句话至少我认为是没有错的。

并且并发是在某一时间段同时发生，**并行**是在某一**时间点**同时发生。不要记混了。所以记住java搞高并发就不会错了。

在java中，启动一个java程序，也就是启动一个JVM进程，然后进程会自动运行一个**主线程**来调用某个类的main方法。

> 那么JVM的启动是单线程的还是多线程的？

是多线程的，因为至少会启动一个gc线程和主线程。

### 多线程的实现方式

在java中，实现多线程的方法主要就分为三种，一种是继承Thread类，override它的run方法，第二种就是实现Runnable接口下的run方法。或者实现Callable<V>下的run方法。

#### 继承Thread类

这是第一种实现多线程方式。

1. 首先我们需要自定义类并继承自Thread类
2. 重写`run()`方法：因为**不是类中的所有代码都需要被线程执行**，所以为了区别哪些代码被线程执行，java提供了`run()`来包含那些需要被线程执行的代码。
3. 创建对象
4. 启动线程：如果直接使用`run()`启动线程，那么就相当直接调用线程，也就是只实现了单线程效果。

> run()与start()有什么区别？

run()仅仅是封装了需要执行的代码，直接调用就相当于调用普通方法。而`start()`是启动了线程，使线程处于就绪状态，然后再由JVM调用线程的`run()`方法。

> 如何获取与设置线程的名称？

很简单，调用线程的`getName()`与`setName()`即可。或者直接在构造线程对象时设置名称。

``` java "多线程入门栗子"
public class MyThread extends Thread {
    public MyThread() {
        // TODO Auto-generated constructor stub
    }
    public MyThread(String name) {
        super(name);
    }
    @Override
    public void run() {
        // TODO Auto-generated method stub
        //super.run();
        for(int i=0;i<100;++i) {
            System.out.println(getName()+":"+i);
        }
    }
}

public static void main(String[] args) {
    // TODO Auto-generated method stub
    MyThread my=new MyThread("tom");
    my.start();
    MyThread my1=new MyThread("bob");
    my1.start();
}
```

> 调用自己写的线程子类很容易获取名称。但是如何获取不是我们自定义的线程的名称呢？例如main线程？

很简单，调用Thread类的静态方法：`public static Thread currentThread()`获得当前线程的引用。然后在调用该线程的`getName()`即可。在哪个线程里调`currentThread()`，就是获得了哪个线程的Thread对象引用。

#### 实现Runnable接口

1. 自定义类实现Runnable接口，`Runnable`接口只有一个抽象方法`run`，无法取消
2. 实现`run()`方法
3. 创建MyRunnable对象
4. 创建Thread对象并将第三步的对象作为参数传进去

``` java
public class MyRunnable implements Runnable {
    @Override
    public void run() {
        // TODO Auto-generated method stub
        for(int i=0;i<500;++i) {
            System.out.println(Thread.currentThread().getName()+i);
        }
    }
}

public static void main(String[] args) {
    // TODO Auto-generated method stub
    MyRunnable my=new MyRunnable();
    Thread t1=new Thread(my,"tom");
    Thread t2=new Thread(my,"candy");
    t1.start();
    t2.start();
}

```



#### 实现callable接口

这种实现多线程的方式必须配合线程池使用。这种方式与实现Runnable接口的区别就是这种方法可以返回一个值。由泛型指定类型。调用`submit()`后会返回一个Future，可以通过Future的`get()`方法获得返回值，但是该方法会阻塞当前线程，直到得到结果。下面是一个使用的栗子：

``` java
public class Mycallable implements Callable<Integer> {
    private int num;

    public Mycallable(int num) {
        super();
        this.num = num;
    }

    @Override
    public Integer call() throws Exception {
        // TODO Auto-generated method stub
        int sum=0;
        for(int i=0;i<num;i++) {
            sum+=i;
        }
        return sum;
    }
}

public static void main(String[] args) {
    // TODO Auto-generated method stub
    ExecutorService pool=Executors.newFixedThreadPool(3);
    Future<Integer> f1=pool.submit(new Mycallable(50));
    Future<Integer> f2=pool.submit(new Mycallable(100));
    try {
        System.out.println(f1.get()+f2.get());
    } catch (InterruptedException e) {
        // TODO Auto-generated catch block
        e.printStackTrace();
    } catch (ExecutionException e) {
        // TODO Auto-generated catch block
        e.printStackTrace();
    }
    finally {
        pool.shutdown();
    }
}
```

上面提到了Future，这是个啥？其实它是一个接口，它只有五个非常简单的方法。

``` java "Future接口"
public interface Future<V> {

    boolean cancel(boolean mayInterruptIfRunning);

    boolean isCancelled();

    boolean isDone();

    V get() throws InterruptedException, ExecutionException;

    V get(long timeout, TimeUnit unit)
        throws InterruptedException, ExecutionException, TimeoutException;
}
```

`cancel()`表示**试图**取消当前线程的执行，但注意仅仅是试图，到底能不能取消还不知道，因为当前线程或许已经执行完了，或者已经取消了，或者一些其他不可控的因素。唯一的参数表示是否以中断的方式取消。

>所以有时候，为了让任务有能够取消的功能，就使用Callable来代替Runnable。如果为了可取消性而使用 Future但又不提供可用的结果，则可以声明 Future<?>形式类型、并返回 null作为底层任务的结果。[参考](http://concurrent.redspider.group/article/01/2.html)。

但是自定义Future接口中的`cancel`、`get`方法又非常困难，所以jdk为我们提供了一个Future的实现类`FutureTask`类。`FutureTask`实现了`RunnableFuture<V>`接口，而`RunnableFuture<V>`又继承了`Runnable`与`Future<V>`接口。

``` java "FutureTask简单使用"
public class CreateThread3 implements Callable<Integer> {
    @Override
    public Integer call() throws Exception {

        Thread.sleep(1000);
        return 2;
    }

    public static void main(String[] args) {
        ExecutorService service= Executors.newCachedThreadPool();
        FutureTask<Integer> futureTask=new FutureTask<>(new CreateThread3());
        service.submit(futureTask);
        try {
            System.out.println(futureTask.get());
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }
    }
}
```

上面使用线程池`submit()`提交一个FutureTask实例后，并不像提交Callable的实例后，有一个返回值。并且获取返回值的时候是直接通过FutureTask的实例获取。这里的submit原型为`submit(Runnable task)`，因为FutureTask就是Runnable接口的实现类。提交Callable的函数原型为`submit(Callable<V> task)`。


#### java中实现线程的方式到底有几个？

这是一个值得思考的问题。上面我们看到定义一个线程的方法主要有三种。

第一种就是实现`Runnable`run方法。这种方式是怎么执行我们定义的线程代码的？源码给出了答案：

``` java
@Override
    public void run() {
        if (target != null) {
            target.run();
        }
    }
```

虚拟机会调用Thread实例的run方法执行线程代码，而在run方法中，又会调用target的`run()`方法，这个target就是我们传进去的RUnnable实例。

第二种就是继承Thread类，重写Thread的类的run方法。那么运行时会调用该实例重写的`run`方法。

第三种就是实现Callable接口的run方法，然后提交到线程池中。注意线程池中的线程是怎么来的？还是通过new一个Thread来实现的。

>无论是 Callable 还是 FutureTask，它们首先和 Runnable 一样，都是一个任务，是需要被执行的，而不是说它们本身就是线程。它们可以放到线程池中执行，如代码所示， submit() 方法把任务放到线程池中，并由线程池创建线程，不管用什么方法，最终都是靠线程来执行的。线程池里的线程还是new Thread创建出来的。

所以说创建线程的方式就一种：**创建一个Thread实例**，而定义线程执行的内容有两种，实现Runnable、Callable等的run方法，或者重写Thread类的run方法。

那么我们应该选取哪种方式实现线程执行内容?

实现Runnable比继承Thread更好，理由如下：

1. 实现Runnable接口可以解决单继承的局限性
2. 把线程和程序代码更好的分离。也就是如果使用继承Thread的方式实现，如果自定义类中有成员数据，就得创建多个MyThread对象才能实现多线程，数据成员也会出现多次。
而采用接口实现，只创建一个MyRunnabe对象就可实现多线程。数据成员只会出现一次。实现了Runnable与Thread类的解耦，Thread类只负责设置一些线程的参数。
3. 在某些情况下Runnable的效率更好，比如我们需要重复执行一些小而短的程序，不停的创建Thread实例代价太高了，实现一个Runnable丢给线程池执行就好。

### 线程组的基本知识

在java中，运行的线程必然属于某一个线程组，如果没有设置，默认线程组是当前启动新线程的线程所在的线程组，就是线程A启动了线程B，默认B的线程组为A所在的线程组。线程组的属性非常多，比如其他的线程组，当前组里的线程等等。

> ThreadGroup管理着它下面的Thread，ThreadGroup是一个标准的向下引用的树状结构，这样设计的原因是防止"上级"线程被"下级"线程引用而无法有效地被GC回收。


### 线程不安全的经典案例

下面以电影院买票为例阐述多线程编程时的经典问题：

``` java
public class SellTickets implements Runnable {
    private int tickets=10;
    @Override
    public void run() {
        // TODO Auto-generated method stub
        while(tickets>0) {
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            }
            System.out.println(Thread.currentThread().getName()+"正在卖出第： "+(tickets--)+"张票");
        }
    }
}

```

买票时会出现售出同票或者售出负数票，这是为什么？

1. 首先解释同票的问题：因为`--`不是一个原子操作，所以有可能窗口1读到的tickets为100，此时时间片结束，窗口2读到的也为100，窗口3同理。由于不是原子性操作，所以可能会出现同票问题。

2. 售出负数票是因为线程调度是随意的，没有顺序的。有可能tickets为1，t1、t2、t3三个线程都进入了循环，然后分别依次执行，就会出现负数票问题。

综上，由于不是原子性操作和线程调度随意性。

### 解决线程安全

首先我们需要判断是否会出现线程不安全的问题。有以下几个标准：

1. 是否为多线程环境
2. 是否线程间**共享**了数据
3. 处理共享数据的操作是否为**原子**操作

综上所述，只要将线程同步了，就可以解决线程安全的问题。那么同步有什么特征吗?

1. 必须是多线程环境
2. 多个线程必须使用的同一把锁
3. 当线程过多时，由于需要判断锁的情况，效率地下

那么如何实现同步？使用`synchronized`关键字的方法有三种：

1. 使用同步代码块，并且同步代码块能够解决线程安全的关键在于对象，这个对象就相当于一把锁。锁对象可以是**任意对象**。必须共享同一个对象。

2. 使用对象同步方法：锁对象就是**该实例对象**本身，将这个对象都锁住了。

3. 使用静态同步方法：锁就是**class对象**本身

显而易见，锁的范围越小越好，所以同步代码块的代价是最低的。

如果采用实例同步方法：同时有两个不相关的实例同步方法。当某个线程在调用其中一个同步实例方法的时候，其他的线程就无法继续调用另外的一个实例同步方法。因为锁只有一个，就是这个实例本身，导致没有关系的两个方法却不能同时进行。<a href=http://www.tianshouzhi.com/api/tutorials/mutithread/284>哪种同步方法好解析</a>。

``` java "同步代码块实例"
public class SellTickets implements Runnable {
private int tickets = 10;
private Object obj = new Object();

@Override
public void run() {
    // TODO Auto-generated method stub
    synchronized (obj) {//同步代码块的对象必须是同一对象
        while (tickets > 0) {

            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            }
            System.out.println(Thread.currentThread().getName() + "正在卖出第： " + (tickets--) + "张票");
        }
    }
}
}

```

``` java "实例同步方法"
public class SellTickets implements Runnable {
    private int tickets = 100;
    private Object obj = new Object();

    @Override
    public void run() {
    while (tickets > 0) {
        sell();

    private synchronized void sell() {
    if (tickets > 0) {
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        System.out.println(Thread.currentThread().getName() + "正在卖出第： " + (tickets--) + "张票");
    }
    }
}

```

### 解决死锁问题

死锁问题归根到底就是锁的嵌套问题。下面是一个死锁的栗子：

``` java
//公共锁
public class MyLock{
    public static final Object obj1=new Object();
    public static final Object obj2=new Object();
    }

public class MultiThread extends Thread {
    boolean flag;

public MultiThread(boolean flag) {
    super();
    this.flag = flag;
};
    @Override
    public void run() {
    // TODO Auto-generated method stub
    // super.run();
        if(flag) {
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                // TODO Auto-generated catch block
                e.printStackTrace();
            }
            synchronized (MyLock.obj1) {
                System.out.println(Thread.currentThread().getName()+
                        "get lock obj1");
                synchronized (MyLock.obj2) {
                    System.out.println(Thread.currentThread().getName()+
                            "get lock obj2");
                }
            }
        }else {
            synchronized (MyLock.obj2) {
                System.out.println(Thread.currentThread().getName()+"get lock obj2");
                synchronized (MyLock.obj1) {
                    System.out.println(Thread.currentThread().getName()+"get lock obj1");
                }
            }
        }
    }
}
```

上面的代码由于锁的相互嵌套，造成了死锁问题。这是由线程间通信方式不当而造成的。

> 什么是线程间的通信问题？

就是不同**种类**的线程针对同一资源的操作。

### 生产者消费者问题

场景：

1. 共同资源：学生对象
2. 设置学生数据：setThread(生产者)
3. 获得学生数据： getThread(消费者)
4. 测试demo

### 线程调度

线程调度有两种模型，分别为：

- 分时调度模型：所有线程轮流使用CPU，并且分配的时间片都相同
- 抢占式调度模型：优先级高的线程优先获得CPU使用权，并且时间片也会比低级线程的多一些。如果线程优先级相同，则随机选一个。

**java使用抢占式调度模式。**

那么如何设置优先级呢？没有设置优先级之前，在java中所有线程的优先级都为5。线程优先级范围为1-10。注意：

> 线程优先级高仅仅代表线程获取时间片的几率较高，而不是这个线程最先执行完毕。并且要多次执行才能看出效果。

而且这里设置的优先级也仅仅是建议，到底优不优先还得看操作系统。并且线程一定属于线程组，那么如果线程的优先级高于所在线程组的优先级，会怎么样呢？

``` java "线程组优先级"
public static void main(String[] args) {
    ThreadGroup t=new ThreadGroup("t");
    Thread t1= new Thread(t,new CreateThread2("tom"));
    Thread t2=new Thread(t,new CreateThread2("bob"));
    t.setMaxPriority(6);
    t1.setPriority(9);
    t2.setPriority(2);
    t1.start();
    t2.start();
    System.out.println("线程组优先级:"+t.getMaxPriority());
    System.out.println("t1优先级:"+t1.getPriority());
    System.out.println("t2优先级:"+t2.getPriority());
    }
```

结果如下：

>线程组优先级:6
t1优先级:6
t2优先级:2

- 设置优先级：
  - setPriority()
- 获取优先级：
  - getPriority()

### 线程控制

- 线程休眠：`public static void sleep(long time)`，time表示休眠的毫秒值

- 线程加入：`public final void join()`,这个方法的作用就是调用该方法的线程先执行完了，其他的线程才能加进来，进入就绪状态。这个join方法有点意思，后序会更新。现在先列一些参考：[参考1](https://blog.csdn.net/u013425438/article/details/80205693),[参考2](https://blog.csdn.net/qq_20919883/article/details/100695018)[参考3](https://www.cnblogs.com/techyc/p/3286678.html)

``` java
public static void main(String[] args) throws InterruptedException {
    // TODO Auto-generated method stub
    MyThread my=new MyThread("tom");

    MyThread my1=new MyThread("bob");

    MyThread my2=new MyThread("candy");
    my.start();
    my.join();
    my1.start();
    my2.start();

}
```

~~注意：调用join的位置很重要，必须放在其他线程对象调用`start()`之前才起作用。~~ 前面这句话完全是在扯淡。在使用join方法，我们需要考虑一个更高的维度，就是当前代码的执行环境。我们可以看到`my.join()`是在主线程里被调的，虽然调的是`MyThread`的join方法，但是执行的线程环境是在执行这句代码的线程中。所以这就解释了为什么是`my`在调用，而阻塞的是`main`线程，之所以与位置有关，是为主线程被阻塞了，`my1.start()`、`my2.start()`还没执行呢，线程当然不会启动。

这里多说一句，`join()`方法底层调用的还是`wait(0)`。

- 线程礼让：`public static void yield()`:暂停当前执行的线程对象，并之情其他线程，让多个线程执行更和谐，但不能保证一人一次。

``` java
public class MyThread extends Thread {
    public MyThread() {
        // TODO Auto-generated constructor stub
    }
    public MyThread(String name) {
        super(name);
    }
    @Override
    public void run() {
        // TODO Auto-generated method stub
        //super.run();
        for(int i=0;i<100;++i) {
            System.out.println(getName()+":"+i);
            Thread.yield();
        }
    }
}
```

- 守护线程：简而言之就是守护线程是与其守护的线程的同生死的。被守护的线程死了，守护线程必须得死，但不是立即死。反之则不一定。被守护的线程没死，守护线程可以死。

那么守护线程到底守护的是谁？是所有的非守护线程，只要还有非守护线程，那么守护线程就会一直工作。

通过使用成员方法`public final void setDaemon()`。并且一定要在线程启动前调用。

``` java
public static void main(String[] args) throws InterruptedException {
    // TODO Auto-generated method stub
    MyThread my=new MyThread("tom");

    MyThread my1=new MyThread("bob");

    MyThread my2=new MyThread("candy");
    my.setDaemon(true);//必须在就绪前设为守护线程
    my1.setDaemon(true);
    my2.setDaemon(true);
    my.start();
    my1.start();
    my2.start();

    for(int i=0;i<100;i++) {
        System.out.println(Thread.currentThread().getName()+i);
    }
    //System.out.println(my.getPriority());
    //Thread curThread=Thread.currentThread();
    //System.out.println(curThread.getName());
}

```

- 线程终止：有两种方法，`stop()`,`public void interrupt()`。前者已经过时。主要使用后者。后者中断的原理时抛出`InterruptedException`异常，使用`try-catch`捕捉后，后续代码仍可执行。


