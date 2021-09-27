---
title: MVCC基础
mathjax: true
hide: true
date: 2021-08-06 22:09:09
updated: 
tags:
- MySQL
- MVCC
categories:
- MySQL
---

## 1. MVCC是什么？

MVCC，Multi-Version Concurrency Control，多版本并发控制，主要是用来提高数据库的**并发性能**。那么为什么能通过这种方式提高数据库读写的并发性能，原来是通过什么方式实现的？为什么会被淘汰？在回答这些问题时，我们需要知道，哪些操作可能会产生数据不安全的问题。对于数据库来说，无非就是读写两种操作，那么就可以分为写写、读写、读读三种操作。显而易见，只有**写写**、**读写**可能会产生数据不安全的问题。

那么最原始的解决方式就是对于任何一种可能会产生冲突的情况都加锁处理，数据库加锁又可以分为乐观锁和悲观锁，这不是本文要讨论的细节。但是盲目加锁必然会降低并发的性能，而MVCC以更好的方式解决了读写冲突，在不加锁的前提下实现读写操作的非阻塞并发执行。我们都知道数据库有四种隔离机制，其中借助MVCC实现了**REPEATABLE READ**和**READ COMMITIED**两个隔离级别。其他两个隔离级别都和MVCC不兼容 ，因为READ UNCOMMITIED总是读取最新的数据行，而SERIALIZABLE则会对所有读取的行都加锁。那么MVCC是如何实现这两种隔离机制的呢？

## 2. MVCC的原理是什么？

在了解MVCC的原理之前，我们需要了解数据库两种读数据的方式：**当前读(current read)**和**快照读(snapshot read)**。所谓的当前读是一种加锁的读，保证读取的数据行是当前时刻最新的。而快照读是一种不加锁的读，也就是读取的是当前行的某一个快照，显而易见可能读的是历史值，但这样做避免了很多加锁的开销。

MVCC就是借助快照读的产生的ReadView、每行记录的三个隐式字段以及undo log实现了隔离机制。快照读无需多言，那么隐式字段和undo log又是什么？

### 2.1 行记录中的隐式字段

其实对于库中的每行记录，额外提供了三个隐藏列：

1. `DB_TRX_ID`：6byte，创建这条记录/最后一次修改该记录的事务ID
2. `DB_ROLL_PTR`：7byte，回滚指针，指向这条记录的上一个版本（存储于rollback segment里）
3. `DB_ROW_ID`：6byte，隐含的自增ID（隐藏主键），如果数据表没有主键，InnoDB会自动以DB_ROW_ID产生一个聚簇索引


所谓的事务ID是指数据库为每个事务分配的全局ID，InnoDB的事务ID是从1开始连续自增的，全局唯一，不同的事务他们的ID不同，按照发生的时间先后持续自增。但是需要注意事务ID的产生时机，[官网的描述](https://dev.mysql.com/doc/refman/5.7/en/innodb-performance-ro-txn.html)如下所示：

>InnoDB can avoid the overhead associated with setting up the transaction ID (TRX_ID field) for transactions that are known to be read-only. A transaction ID is only needed for a transaction that might perform write operations or locking reads such as SELECT ... FOR UPDATE.

也就是说InnoDB只会为那些可能产生写操作的事务分配事务ID，并且**只会在真正开始执行增、删、改语句时才会分配**，而不是一开始执行事务就会分配。

而回滚指针用于undo log，详情见下文所述。

### 2.2 undo log

回滚指针在undo log中使用。undo log又可以操作种类划分为`insert undo log`和`update undo log`。我们现在只需要知道，每次进行增删改的操作前，InnoDB会对当前操作的记录做一个快照并存储到undo log中，然后

表空间由很多 segment（段） 组成，而这众多的段中有一种就是 undo segment。

### 2.3 ReadView

所谓的`ReadView`并不是一个所谓的表或者视图，而是指在进行快照读的那一刻，生成了四个用于判断数据可见性的指标：

- m_ids：表示在生成ReadView时，系统中活跃的事务id集合。
- min_trx_id：表示在生成ReadView时，系统中活跃的最小事务id，也就是 m_ids中的最小值。
- max_trx_id：表示在生成ReadView时，系统应该分配给下一个事务的id，也就是当前最大事务id+1。
- creator_trx_id：表示生成该ReadView的事务id（前面曾说到只有增删查才会产生事务id，那么读操作呢，会产生该值吗？从网上得知可能是0）

通过这四个参数实现了一组**可见性算法**用于判断当前读语句到底读的是哪个版本数据，步骤如下所示：

1. 如果被访问版本的`trx_id`和ReadView中的creator_trx_id相同，就意味着当前版本就是由当前事务创建的，可以读出来
2. 如果被访问版本的`trx_id`属性值小于m_ids列表中最小的事务id，表明生成该版本的事务在生成ReadView前已经提交，所以该版本可以被当前事务访问。
3. 如果被访问版本的`trx_id`属性值大于m_ids列表中最大的事务id，表明生成该版本的事务在生成ReadView后才生成，所以该版本不可以被当前事务访问。
4. 如果被访问版本的`trx_id`属性值在m_ids列表中最大的事务id和最小事务id之间，那就需要判断一下`trx_id`属性值是不是在m_ids列表中，如果在，说明创建ReadView 时生成该版本的事务还是活跃的，该版本不可以被访问；如果不在，说明创建 ReadView 时生成该版本的事务已经被提交，该版本可以被访问。

### 2.3 MVCC工作的流程

我们以一个例子来解释MVCC的工作原理，假设当前待操作的行记录如下所示：

![mvcc-record](https://eripe.oss-cn-shanghai.aliyuncs.com/img/mvcc..imagesmvcc-undo-log-part-i.drawio.svg.svg)


数据库开启了事务A、B、C，D，事务C将上述记录的`age`字段修改为18，事务D将上述记录的`name`字段修改为tom，执行动作的时刻如下所示：

| 时刻 | 事务A | 事务B | 事务C | 事务D |
| :-----| ----: | :----: | ----: | ----: |
| t1 | 开启事务 |  | 开启事务 | 开启事务 |
| t2 |  |  | 执行update | |
| t3 |  |  |  | 执行update |
| t4 |  | 开启事务 |  |  |
| t5 | 执行select |  | | |
| t6 |  | 执行update | | |
| t7 |  | 提交事务 | | |
| t8 |  |  | | |

假设给事务A、C、D分配的事务ID分别为1、2、3，那么在t4时刻，undo log的形式应如下所示：
![mvcc-readview-ii](https://eripe.oss-cn-shanghai.aliyuncs.com/img/mvcc.mvcc-undo-log-part-ii.drawio.svg)

t5时刻事务A执行select前，会生成ReadView，生成的四个参数如下所示：
| 参数 | m_ids | min_trx_id |  max_trx_id&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | creator_trx_id |
| :-----| ----: | :----: | ----: | ----: |
|  | \[1,2,3]| 1 |4=3+1（当前最大事务ID+1） | 1&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; |

因为事务B还未被分配事务ID（分配时机详见上文），所以活跃的事务只有A、C、D。在事务A生成ReadView后读之前，事务B欲将该记录的`age`字段从25改为18，步骤包括：

1. 对该行加排他锁
2. 将该行的原始数据创建快照，存入undo log
3. 执行修改操作后，并将修改后的`DB_ROLL_PTR`指向undo log最新的一行，如下所示：
![mvcc-readview-iii](https://eripe.oss-cn-shanghai.aliyuncs.com/img/mvcc.mvcc-undo-log-part-iii.drawio.svg)

在修改完成后，轮到事务A执行读取操作，那么事务A会根据undo log以及可见性算法来抉择到底读取哪一版本的数据：

1. 首先读取到undo log中第一个记录的trx_id为3，有`min_trx_id<=trx_id<max_trx_id`，并且处于活跃的事务列表中，那么当前版本的记录事务A是无权查看
2. 通过`DB_ROLL_PTR`查找到下一版本的行记录，重新开始执行可见性算法，读取到的事务id为2，有`2<min_trx_id`，则说明当前版本是在事务A活跃之前提交的，事务A有权查看，所以事务A读取到数据为`name=tom and age=25`。

通过上述例子想必已经大概理解了MVCC的工作原理，那么MVCC和RC、RR两种隔离机制有什么关系？

## RC和RR的实现原理

有了MVCC，我们能够读到哪一版本的数据完全取决于MVCC的生成时机，因为可见性算法工作于MVCC的四个参数之上。而RC与RR的区别仅仅是ReadView的生成时间点不同。

**RC的ReadView会在每一次select都生成，而RR只会在第一个select执行时生成。** 对于RR，既然MVCC的参数不变，那么读取到的版本肯定是固定的，自然达到了可重复读的效果。

## 参考文章

1. [正确的理解MySQL的MVCC及实现原理](https://www.cnblogs.com/xuwc/p/13873611.html)
2. [MySQL中的事务和MVCC](https://www.cnblogs.com/CodeBear/p/12710670.html)