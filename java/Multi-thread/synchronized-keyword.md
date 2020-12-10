---
title: synchronized关键字
mathjax: true
data: 2020-12-01 19:54:01
updated: 2020-12-10 10:59:23
tags: 
- synchronized
categories:
- 多线程基础
---

# 预备知识

Java提供的同步机制有许多，`synchronized`是其中最经常使用、最万能的机制之一。
为了学习`synchronized`的实现原理，进而了解到`monior object`模式。在java中`synchronized`辅助实现了该模式。

# 1. monitor机制的起源与定义

在早期，编写并发程序时使用的同步原语是信号量semaphore与互斥量mutex。程序员需要手动操作信号量的数值与线程的唤醒与挂起，想想这也是一个十分麻烦的工作。所以提出了更高层次的同步机制`monitor`封装了信号量的操作。但是值得注意的是`monitor`并未在操作系统层面实现，而是在软件层次完成了这一机制。

下面描述了`monitor`机制之所以会出现的一个应用场景（摘自[探索Java同步机制](https://developer.ibm.com/zh/articles/j-lo-synchronized/)）：

> 我们在开发并发的应用时，经常需要设计这样的对象，该对象的方法会在多线程的环境下被调用，而这些方法的执行都会改变该对象本身的状态。为了防止竞争条件 (race condition，等同于死锁) 的出现，对于这类对象的设计，需要考虑解决以下问题：
1.在任一时间内，只有唯一的公共的成员方法，被唯一的线程所执行。
2.对于**对象的调用者**来说，如果总是需要在调用方法之前进行拿锁，而在调用方法之后进行放锁，这将会使并发应用编程变得更加困难。合理的设计是，该对象本身确保任何针对它的方法请求的会同步并且透明的进行，而**不需要调用者的介入**。
3.如果一个对象的方法执行过程中，由于某些条件不能满足而阻塞，应该允许其它的客户端线程的方法调用可以访问该对象。

我们使用 Monitor Object 设计模式来解决这类问题：**将被客户线程并发访问的对象定义为一个 monitor 对象**。客户线程仅仅通过 monitor 对象的同步方法才能使用 monitor 对象定义的服务。为了防止陷入死锁，在任一时刻只能有一个同步方法被执行。每一个monitor对象包含一个 monitor锁，被同步方法用于串行访问对象的行为和状态。此外，同步方法可以根据一个或多个与monitor对象相关的monitor conditions 来决定在何种情况下挂起或恢复他们的执行。

根据上述定义，monitor object模式分为四个组成部分：

- **监视者对象 (Monitor Object):** 负责定义公共的接口方法，这些公共的接口方法会在多线程的环境下被调用执行。
- **同步方法：** 这些方法是**监视者对象**所定义。为了防止死锁，无论是否同时有多个线程并发调用同步方法，还是监视者对象含有多个同步方法，在任一时间内只有监视者对象的一个同步方法能够被执行（所谓的同步方法也就是我们经常说的临界区）
- **监视锁 (Monitor Lock):** 每一个监视者对象都会拥有一把监视锁。
- **监视条件 (Monitor Condition):** 同步方法使用监视锁和监视条件来决定方法是否需要阻塞或重新执行。这里的监视条件可以来自程序本身也可来自monitor object内部。


这四个部分完成了两个动作：

1. 线程互斥的进入同步方法
2. 完成线程的一些调度动作，例如线程的挂起与唤醒

# 2. Java中的monitor object模式

按照定义，Java下基于`synchronized`的`monitor object`模式也应该由四个部分组成,包括监视者对象、监视锁、监视条件、同步方法（临界区）。那么首先来看看我们一般使用`synchronized`来实现同步的代码：

``` java
class demo{
    Object lock=new Object();
    public void test1(){
        synchronized(lock){
            ...
        }
        ...
    }
    public synchronized void test2(){...}
    public static synchronized void test3(){...}
}
```

在我看到的大部分资料中，都认为上述代码中的`lock`对象是监视者对象，监视条件上面没有展示出来，`synchronized`后跟的代码块就是同步方法。但是这个同步方法并不是在`lock`所在的类`Object`中定义的啊，这如何解释？

>我的理解是这里的“定义”并不是诸如在类`A`中定义一个方法`test`之类的定义，而是规定了某些代码作为同步方法，例如规定字母`A`代表学校，字母`B`代表公司之类的将两个事物联系到一起的定义，就像在上面代码中规定了`{}`中的代码作为`lock`的同步方法

那么监视锁呢？上面完全没有锁的痕迹。原因是基于`monitor object`模式的`synchronized`，监视锁是由监视对象自带的，也被称为`intrinsic lock`。这个锁在java中是由`objectmonitor`实现的。

那么监视者对象、监视锁和线程这三者如何产生联系的呢？这就跟Java中对象的内存布局有关了。在jvm中，任何一个对象都会持有一个对象头用来存储一些对象的信息,下图中是一个对象的内存布局，由对象头、对象数据和填充数据组成。

![object memory layout](images/object_header.png)

其中对象头由`markword`和`class pointer`组成。`markword`在32位和64位的机器上略有不同，32bit长的`markword`布局如下所示（图片出自[Synchronized与锁](https://deecyn.com/java-synchronized-and-lock.html)）：

![32-markword](images/32-MarkWord.png)

因为空间有限，所以这32bit是复用的，在不同状态下存储的信息是不同的。对于Java1.6之前的`synchronized`对应于图中的重量级锁状态（其他三种锁状态在Java1.6后出现），该状态下`markword`存储了指向了重量级锁的指针，这个重量级锁就是`monitor object`模式中的监视锁。这个重量级锁是在JVM中通过`ObjectMonitor`类实现的，**而该类本质上又是基于系统的mutex创建的**。其部分代码如下所示：

``` java
class ObjectMonitor {
...
  //省略一些代码
  bool      try_enter (TRAPS) ;
  void      enter(TRAPS);
  void      exit(bool not_suspended, TRAPS);
  void      wait(jlong millis, bool interruptable, TRAPS);
  void      notify(TRAPS);
  void      notifyAll(TRAPS);
  ...

  // WARNING: this must be the very first word of ObjectMonitor
  // This means this class can't use any virtual member functions.

  volatile markOop   _header;       // displaced object header word - mark
  void*     volatile _object;       // backward object pointer - strong root

  // All the following fields must be machine word aligned
  // The VM assumes write ordering wrt these fields, which can be
  // read from other threads.

 protected:                         // protected for jvmtiRawMonitor
  void *  volatile _owner;          // pointer to owning thread OR BasicLock
...
 private:
  int OwnerIsThread ;               // _owner is (Thread *) vs SP/BasicLock
...
 protected:
  ObjectWaiter * volatile _EntryList ;     // Threads blocked on entry or reentry.

 protected:
  ObjectWaiter * volatile _WaitSet; // LL of threads wait()ing on the monitor
 private:
  volatile int _WaitSetLock;        // protects Wait Queue - simple spinlock
  //省略一些代码
}
```
其中：

- `_header`存储了指向属于`monitor object`的`object header`的指针
- `_object`存储了指向`monitor object`的指针
- `_owner`存储了指向获得监视锁的线程
- `_EntryList`存储了访问同一临界区但是被阻塞的线程集合
- `_WaitList`存储了调用`wait()`方法主动释放锁的线程集合

并且`ObjectMonitor`实现了`wait()`、`notify()`、`notifyAll()`等方法。

那么监视对象、监视锁、线程的关系是：监视对象内存存储了监视锁，而监视锁中又存储了获得当前锁的线程。并且由于每个对象都会有对象头，而对象头中自带监视锁，所以Java中任何一个对象都可以用作监视对象，所以`wait()`、`notify()`等方法在顶级父类`Object`中实现。


# 3. Java1.6后的synchronized

因为Java的线程模型采用的是1:1模型，一个Java线程映射到系统的一个线程，所以Java线程的切换、阻塞、唤醒都需要在内核模式中完成，频繁地切换用户模式与内核模式代价非常高（所以`synchronzied`被称为重锁）。那么如果同步区非常短，执行同步区的时间比切换内核模式的时间还短，程序的效率就比较低了。所以在Java1.6之后，`synchronzied`进行了大量优化。对于`synchronized`，不会再一开始就使用`objectMonitor`完成同步。而是根据线程对锁的竞争程度不断升级获取锁的难度。

升级后的`synchronized`分为四个阶段：无锁->偏向锁->轻量级锁->重量级锁。这四个状态通过`markword`中的两位标记来区分，再次搬出32位下的`markword`结构图：

![32-markword](images/32-MarkWord.png)

可以看到，偏向锁和无锁状态的锁标志位都是`01`，他们是通过1bit的标志位来区分。

## 3.1 偏向锁

偏向锁，将锁的归属权偏向给第一个获得该锁的线程。说人话，就是如果有一个线程threadA第一次成功获得了偏向锁lock，那么lock默认认为以后能够成功获得锁的线程都会是线程A。

>注意：“偏向第一个获得该锁的线程”并不是指在偏向锁的生命周期内只会有一个线程获得锁。
比如在最开始，threadA获得了偏向锁lock，此时lock偏向threadA。使用完毕后，threadB请求lock。虽然lock发现此时请求的线程不是threadA，但是由于此时没有发生竞争，所以lock重新设置其偏向的线程为threadB。**而不是说从头到尾lock都只偏向threadA。**

偏向锁的使用场景是同步区只被同一个线程访问。那么在使用偏向锁时只会在第一次申请时将`markword`中的线程ID（默认为0）使用CAS替换为当前获得锁的线程ID。但是并不是简单的替换而已，同时也会在当前线程的`Lock Record`列表中插入一个`Lock Record`结构。`Lock Record`用在线程中保存锁的相关信息，其结构如下所示：

![lock record](images/lock-record.png)

其中：

- `displaced markword`:用来保存`monitor object`对象头中的`markword`信息
- `owner`：指向`monitor object`的指针

### 3.1.1 偏向锁的获取流程

下图中是偏向锁的工作流程：

![biased-lock](images/biased-lock.jpg)

其中有几点需要注意，在一个线程每次成功获取偏向锁时，**会在当前线程的`Lock Record`队列中插入一个`Lock Record(LR)`**,并且设置新插入LR中的owner指向当前监视器对象（monitor object），具体的实现代码如下所示：

``` java
//代码分析摘自：Synchronized 源码分析（http://itliusir.com/2019/11-Synchronized/）
//来自bytecodeInterpreter.cpp

CASE(_monitorenter): {
  oop lockee = STACK_OBJECT(-1);
  CHECK_NULL(lockee);
  // 寻找空闲的锁记录(Lock Record) 空间
  BasicObjectLock* limit = istate->monitor_base();
  BasicObjectLock* most_recent = (BasicObjectLock*) istate->stack_base();
  BasicObjectLock* entry = NULL;
  while (most_recent != limit ) {
    if (most_recent->obj() == NULL) entry = most_recent;
    else if (most_recent->obj() == lockee) break;
    most_recent++;
  }
  // 存在空闲的Lock Record
  if (entry != NULL) {
    /***********************************/
    // 设置Lock Record 的 obj指针(owner)指向锁对象(monitor object)
    //这句代码完成了线程每次获取锁时向LR集合中插入新LR的动作
    entry->set_obj(lockee);
    /***********************************/

    int success = false;
    uintptr_t epoch_mask_in_place = (uintptr_t)markOopDesc::epoch_mask_in_place;
    markOop mark = lockee->mark();
    intptr_t hash = (intptr_t) markOopDesc::no_hash;

    /*****************************************************/
    // 如果锁对象的对象头标志是偏向模式(1 01)
    if (mark->has_bias_pattern()) {
      uintptr_t thread_ident;
      uintptr_t anticipated_bias_locking_value;
      thread_ident = (uintptr_t)istate->thread();
      // 通过位运算计算anticipated_bias_locking_value
      anticipated_bias_locking_value =
        // 将线程id与prototype_header(epoch、分代年龄、偏向模式、锁标志)部分相或
        (((uintptr_t)lockee->klass()->prototype_header() | thread_ident) 
        // 与锁对象的markword异或，相等为0
         ^ (uintptr_t)mark) 
        // 将上面结果中的分代年龄忽略掉
        &~((uintptr_t) markOopDesc::age_mask_in_place);
        // ① 为0代表偏向线程是当前线程 且 对象头的epoch与class的epoch相等，什么也不做
        if  (anticipated_bias_locking_value == 0) {
            if (PrintBiasedLockingStatistics) {
            (* BiasedLocking::biased_lock_entry_count_addr())++;
            }
            success = true;
        }
      // ② 偏向模式关闭，则尝试撤销(0 01)
      else if ((anticipated_bias_locking_value & markOopDesc::biased_lock_mask_in_place) != 0) {
        // try revoke bias
        markOop header = lockee->klass()->prototype_header();
        if (hash != markOopDesc::no_hash) {
          header = header->copy_set_hash(hash);
        }
        if (Atomic::cmpxchg_ptr(header, lockee->mark_addr(), mark) == mark) {
          if (PrintBiasedLockingStatistics)
            (*BiasedLocking::revoked_lock_entry_count_addr())++;
        }
      }

      /*****************************************************/
      // ③ 锁对象头的 epoch 与 class 的 epoch 不相等，尝试重偏向
      else if ((anticipated_bias_locking_value & epoch_mask_in_place) !=0) {
        // try rebias
        markOop new_header = (markOop) ( (intptr_t) lockee->klass()->prototype_header() | thread_ident);
        if (hash != markOopDesc::no_hash) {
          new_header = new_header->copy_set_hash(hash);
        }
        if (Atomic::cmpxchg_ptr((void*)new_header, lockee->mark_addr(), mark) == mark) {
          if (PrintBiasedLockingStatistics)
            (* BiasedLocking::rebiased_lock_entry_count_addr())++;
        }
        else {
          // 有竞争重偏向失败，调用 monitorenter 锁升级
          CALL_VM(InterpreterRuntime::monitorenter(THREAD, entry), handle_exception);
        }
        success = true;
      }

      /*****************************************************/
      // ④ 未偏向任何线程，尝试偏向
      else {
        markOop header = (markOop) ((uintptr_t) mark & ((uintptr_t)markOopDesc::biased_lock_mask_in_place |
                                                        (uintptr_t)markOopDesc::age_mask_in_place |
                                                        epoch_mask_in_place));
        if (hash != markOopDesc::no_hash) {
          header = header->copy_set_hash(hash);
        }
        markOop new_header = (markOop) ((uintptr_t) header | thread_ident);
        // debugging hint
        DEBUG_ONLY(entry->lock()->set_displaced_header((markOop) (uintptr_t) 0xdeaddead);)
        // CAS 尝试修改
        if (Atomic::cmpxchg_ptr((void*)new_header, lockee->mark_addr(), header) == header) {
          if (PrintBiasedLockingStatistics)
            (* BiasedLocking::anonymously_biased_lock_entry_count_addr())++;
        }
        // 有竞争偏向失败，调用 monitorenter 锁升级
        else {
          CALL_VM(InterpreterRuntime::monitorenter(THREAD, entry), handle_exception);
        }
        success = true;
      }
    }

    /*****************************************************/
    // 走到这里说明偏向的不是当前线程或没有开启偏向锁等原因
    if (!success) {
      // 轻量级锁逻辑 start
      // 构造无锁状态 Mark Word 的 copy(Displaced Mark Word)
      markOop displaced = lockee->mark()->set_unlocked();
      // 将锁记录空间(Lock Record)指向Displaced Mark Word
      entry->lock()->set_displaced_header(displaced);
      // 是否禁用偏向锁和轻量级锁
      bool call_vm = UseHeavyMonitors;
      if (call_vm || Atomic::cmpxchg_ptr(entry, lockee->mark_addr(), displaced) != displaced) {
        // 判断是不是锁重入，是的话把Displaced Mark Word设置为null来表示重入
        // 置null的原因是因为要记录重入次数，但是mark word大小有限，所以每次重入都在栈帧中新增一个Displaced Mark Word为null的记录
        if (!call_vm && THREAD->is_lock_owned((address) displaced->clear_lock_bits())) {
          entry->lock()->set_displaced_header(NULL);
        } else {
          // 若禁用则锁升级
          CALL_VM(InterpreterRuntime::monitorenter(THREAD, entry), handle_exception);
        }
      }
    }
    UPDATE_PC_AND_TOS_AND_CONTINUE(1, -1);
  } else {
    istate->set_msg(more_monitors);
    UPDATE_PC_AND_RETURN(0); // Re-execute
  }
}
```

**对偏向锁的获取流程总结如下：**

1. 如果当前线程有空闲的LockRecord（LR），那么设置当前使用的LR的`owner`指针指向当前`monitor object`（也就相当于添加了一个新的LR到当前线程中）

2. 检查monitor object是否处于可偏向状态（在开启偏向锁后，markword中的锁标志默认为可偏向状态，如果存储的线程ID为0，则称其为匿名可偏向状态）

3. 如果处于可偏向状态，检查偏向锁偏向的线程是否为当前线程，如果是，那么则执行（6），否则执行（4）

4. 如果偏向模式被关闭，那么执行（8）

5. 对偏向锁设置重偏向，如果成功，那么则执行（7），否则产生竞争，执行（8）

6. 对偏向锁第一次设置偏向线程，如果成功，那么则执行（7），否则产生竞争，执行（8）

7. 执行临界区代码

8. 进行一系列判断，决定是否能够保留偏向锁，或者升级为轻量级锁

### 3.1.2 偏向锁的撤销流程

对于偏向锁获取流程中第（8）步的判断，其执行的检查十分复杂，调用链如下：

InterpreterRuntime::monitorenter --> ObjectSynchronizer::fast_enter --> BiasedLocking::revoke_and_rebias --> BiasedLocking::revoke_bias

我们着重分析`revoke_and_rebias`与`revoke_bias`

``` java
static BiasedLocking::Condition revoke_bias(oop obj, bool allow_rebias, bool is_bulk, JavaThread* requesting_thread) {
  markOop mark = obj->mark();
  // 如果对象不是偏向锁，直接返回 NOT_BIASED
  if (!mark->has_bias_pattern()) {
    ...
    return BiasedLocking::NOT_BIASED;
  }

  uint age = mark->age();
  // 构建两个 mark word，一个是匿名偏向模式（101），一个是无锁模式（001）
  markOop   biased_prototype = markOopDesc::biased_locking_prototype()->set_age(age);
  markOop unbiased_prototype = markOopDesc::prototype()->set_age(age);

  ...

  JavaThread* biased_thread = mark->biased_locker();
  if (biased_thread == NULL) {
     // 匿名偏向。当调用锁对象原始的 hashcode() 方法会走到这个逻辑
     // 如果不允许重偏向，则将对象的 mark word 设置为无锁模式
    if (!allow_rebias) {
      obj->set_mark(unbiased_prototype);
    }
    ...
    return BiasedLocking::BIAS_REVOKED;
  }

  // 判断偏向线程是否还存活
  bool thread_is_alive = false;
  // 如果当前线程就是偏向线程 
  if (requesting_thread == biased_thread) {
    thread_is_alive = true;
  } else {
     // 遍历当前 jvm 的所有线程，如果能找到，则说明偏向的线程还存活
    for (JavaThread* cur_thread = Threads::first(); cur_thread != NULL; cur_thread = cur_thread->next()) {
      if (cur_thread == biased_thread) {
        thread_is_alive = true;
        break;
      }
    }
  }
  // 如果偏向的线程已经不存活了
  if (!thread_is_alive) {
    // 如果允许重偏向，则将对象 mark word 设置为匿名偏向状态，否则设置为无锁状态
    if (allow_rebias) {
      obj->set_mark(biased_prototype);
    } else {
      obj->set_mark(unbiased_prototype);
    }
    ...
    return BiasedLocking::BIAS_REVOKED;
  }

  // 线程还存活则遍历线程栈中所有的 lock record
  GrowableArray<MonitorInfo*>* cached_monitor_info = get_or_compute_monitor_info(biased_thread);
  BasicLock* highest_lock = NULL;
  for (int i = 0; i < cached_monitor_info->length(); i++) {
    MonitorInfo* mon_info = cached_monitor_info->at(i);
    // 如果能找到对应的 lock record，说明偏向所有者正在持有锁
    if (mon_info->owner() == obj) {
      ...
      // 升级为轻量级锁，修改栈中所有关联该锁的 lock record
      // 先处理所有锁重入的情况，轻量级锁的 displaced mark word 为 NULL，表示锁重入
      markOop mark = markOopDesc::encode((BasicLock*) NULL);
      highest_lock = mon_info->lock();
      highest_lock->set_displaced_header(mark);
    } else {
      ...
    }
  }
  if (highest_lock != NULL) { // highest_lock 如果非空，则它是最早关联该锁的 lock record
    // 这个 lock record 是线程彻底退出该锁的最后一个 lock record
    // 所以要，设置 lock record 的 displaced mark word 为无锁状态的 mark word
    // 并让锁对象的 mark word 指向当前 lock record
    highest_lock->set_displaced_header(unbiased_prototype);
    obj->release_set_mark(markOopDesc::encode(highest_lock));
    ...
  } else {
    // 走到这里说明偏向所有者没有正在持有锁
    ...
    if (allow_rebias) {
       // 设置为匿名偏向状态
      obj->set_mark(biased_prototype);
    } else {
      // 将 mark word 设置为无锁状态
      obj->set_mark(unbiased_prototype);
    }
  }

  return BiasedLocking::BIAS_REVOKED;
}
```

上述代码中只有一点需要注意：在判断线程是否处于同步状态时，遍历的`Lock Record`正是线程在获取锁时添加到线程中的只有`owner`指针的`Lock Record`。

1. 所以当偏向锁产生最普通的竞争时，JVM会首先JVM中所有存活的线程中是否存在偏向锁偏向的线程。如果存在，执行（2），否则执行（4）

2. 判断偏向锁偏向的线程当前是否处于同步区，这通过遍历目标线程的`Lock Record`集合实现（为什么能这么做呢？这跟偏向锁的释放有关，见后文）。如果处于同步区，则执行（3），否则执行（4）

3. 将最先关联到线程的`Lock Record`结构中的`Displace markword`设置为无锁模式，然后将monitor object对象头的markdown设置为指向`Displace markword`的指针（处于safepoint，所有线程终止）。至此，完成轻量锁的升级。注意，此时轻量锁的归属权仍然属于原来获得偏向锁的线程

4. 如果开启可重偏向，那么则将monitor object对象的markword设置为匿名偏向模式，否则执行（5）

5. 将将monitor object对象头的markword设置为无锁模式

### 3.1.3 偏向锁的释放流程

偏向锁的释放流程比较简单：

``` java
//代码来自：bytecodeInterpreter.cpp
CASE(_monitorexit): {
  oop lockee = STACK_OBJECT(-1);
  CHECK_NULL(lockee);
  // derefing's lockee ought to provoke implicit null check
  // find our monitor slot
  BasicObjectLock* limit = istate->monitor_base();
  BasicObjectLock* most_recent = (BasicObjectLock*) istate->stack_base();
  // 从低往高遍历栈的Lock Record
  while (most_recent != limit ) {
    // 如果Lock Record关联的是该锁对象
    if ((most_recent)->obj() == lockee) {
      BasicLock* lock = most_recent->lock();
      markOop header = lock->displaced_header();
      // 释放Lock Record
      most_recent->set_obj(NULL);
      // 如果是偏向模式，仅仅释放Lock Record就好了。否则要走轻量级锁or重量级锁的释放流程
      if (!lockee->mark()->has_bias_pattern()) {
        bool call_vm = UseHeavyMonitors;
        // header!=NULL说明不是重入，则需要将Displaced Mark Word CAS到对象头的Mark Word
        if (header != NULL || call_vm) {
          if (call_vm || Atomic::cmpxchg_ptr(header, lockee->mark_addr(), lock) != lock) {
            // CAS失败或者是重量级锁则会走到这里，先将obj还原，然后调用monitorexit方法
            most_recent->set_obj(lockee);
            CALL_VM(InterpreterRuntime::monitorexit(THREAD, most_recent), handle_exception);
          }
        }
      }
      //执行下一条命令
      UPDATE_PC_AND_TOS_AND_CONTINUE(1, -1);
    }
    //处理下一条Lock Record
    most_recent++;
  }
  // Need to throw illegal monitor state exception
  CALL_VM(InterpreterRuntime::throw_illegal_monitor_state_exception(THREAD), handle_exception);
  ShouldNotReachHere();
}
```

对于偏向锁，代码从低往高的遍历`Lock Record`，因为加进去的时候就是按照从高往低加入的。它将当前遍历的`Lock Record`中的owner指针都置为null，表示当前线程释放了偏向锁。这也就是为什么在偏向锁撤销的过程中，通过查看线程中的`Lock Record`的owner指针是否指向monitor object就能判断当前持有偏向锁的线程是否处于同步区。因为如果不处于同步区，线程肯定会释放偏向锁，并且将owner置为null。

## 3.2 轻量锁

轻量锁的来源有两处：

1. 通过偏向锁升级而来
2. 关闭偏向模式

轻量锁和偏向锁的区别在哪呢？

1. 偏向锁只需要在第一次请求锁使用CAS设置ThreadID，而轻量锁需要在每次请求锁时都使用CAS修改markword

2. 偏向锁只适用于一个线程进入临界区，轻量锁适用于多个线程交替地进入临界区（交替是指不会发生争夺锁的冲突）

### 3.2.1 轻量锁的申请流程


### 3.2.2 轻量锁的撤销流程



### 3.2.3 轻量锁的释放流程


当然大部分时候都是通过偏向锁升级而来

## 3.3 重量锁

### 3.3.1

自旋
适应性自旋


图片来自[看完这篇恍然大悟，理解Java中的偏向锁，轻量级锁，重量级锁](https://blog.csdn.net/DBC_121/article/details/105453101)

![lock](images/lock.png)

## 参考文献

1. [Java中的Monitor机制](https://segmentfault.com/a/1190000016417017)

2. [探索Java同步机制](https://developer.ibm.com/zh/articles/j-lo-synchronized/)

3. [markword图片出处](https://deecyn.com/java-synchronized-and-lock.html)

[Synchronized 源码分析](http://itliusir.com/2019/11-Synchronized/)

[死磕Synchronized底层实现--偏向锁](https://juejin.cn/post/6844903726554038280)

[源码解析-偏向锁撤销流程解读](https://blog.csdn.net/L__ear/article/details/106369509)

[Lock Record--锁记录](https://www.jianshu.com/p/fd780ef7a2e8)

https://blog.csdn.net/L__ear/article/details/106369509

https://blog.csdn.net/DBC_121/article/details/105453101

https://www.mdeditor.tw/pl/2Z1b