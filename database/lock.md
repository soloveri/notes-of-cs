---
title: MySQL的锁
mathjax: true
hide: true
date: 2021-08-06 22:09:09
updated: 
tags:
- lock
categories:
- MySQL
---

## 1. 锁的类别

MySQL中的锁比较复杂，可以按照是否共享、锁的粒度、锁的状态划分为三类锁。

- 是否共享：共享锁（share lock，S lock）以及排他锁（exclusive lock，X lock）
- 粒度；表锁、行锁
- 状态：意向锁（intention lock），分为意向共享锁、意向排他锁、意向插入锁

其中表锁、行锁、意向锁都具备是否共享的特性。

## 2. 是否共享

对于“排他”的含义，我认为[MySQL中的锁（表锁、行锁，共享锁，排它锁，间隙锁）](https://blog.csdn.net/soonfly/article/details/70238902
)中讲的很好，我在此引用过来：
>值得注意的是，所谓的“排他”锁，并不是排他锁锁住一行数据后，其他事务就不能读取和修改该行数据，其实不是这样的。排他锁指的是一个事务在一行数据加上排他锁后，其他事务不能再在其上加其他的锁。

## 2. 表锁

表锁显而易见就是锁的是整张表，加锁的语句如下所示：

## 3. 行锁

行锁根据不同的实现算法，可以分为`record lock`、`gap lock`、`next-key lock`以及`insert intention lock`。其中`record lock`就是针对每一行加的锁，`gap lock`是指针对行与行之间的间隙加的锁，**专门用来在RR级别解决幻读**；`next-key lock`是将`record lock`和`gap lock`结合起来，而`insert intention lock`则是一种特殊的间隙锁，并不具备是否共享的属性。

对于InnoDB，默认加的都是行锁，只有行锁失效时才会升级为表锁。其中对于对于update类型（update或delete）的操作，会**自动**加排他行锁；对于select，**不会自动**加行锁，但是可以通过如下语句选择加共享锁、排他锁。

### 3.1 行锁的使用方式

对于InnoDB引擎默认的修改数据语句：update,delete,insert都会**自动**给涉及到的数据加上**行级排他锁**；select语句默认不会加任何锁类型。如果加排他锁可以使用select …for update语句，加共享锁可以使用select … lock in share mode语句，如下所示:

>共享锁(S)：SELECT * FROM table_name WHERE ... LOCK IN SHARE MODE
排他锁(X)：SELECT * FROM table_name WHERE ... FOR UPDATE

### 3.1 行锁的优缺点

优点：高并发场景下表现更突出，毕竟锁的粒度小
缺点：由于需要请求大量的锁资源，所以速度慢，内存消耗大。

### 3.2 行锁的兼容性

因为行锁种的`record lock`、`gap lock`、`next-key lock`可以分为S锁和X锁，只有S锁和S锁之间才会兼容，所以是否可以认为当这三种锁都作为S锁时互相兼容？那么如果这三种锁都作为X锁，它们之间的兼容性是怎么样的？可能如下表所示（因为我认为这是可能的答案）：

|  表头   | record  | gap  | next-key |
|  ----  | ----  | ----  | ----  |
| record  | 冲突 | 兼容 | 冲突 |
| gap  | 兼容 | 兼容 | 兼容 |
| next-key  | 冲突 | 兼容 | 冲突 |

每一行的第一列表示已经对某一数据行施加的锁，剩余列表示其他事务想要在同一数据行施加的锁，看似很复杂，只要理解了原理，就很简单了。

对于某数据行A，如果已经有了排他record lock，其他事务自然无法成功加锁，发生冲突很自然。但是为什么其他事务能够对数据行A加gap lock呢？我们想想gap lock是什么，是一个间隙锁啊，间隙里肯定不包含数据行A，自然不会冲突。同理next-key lock就是将record lock和gap lock结合起来，对数据行A加next-key lock，就相当于对A加了一个record lock，自然也会发生冲突。

对于某间隙 B，如果已经加了gap lock，那么因为这个间隙里是不包含数据A的，自然不会与record lock和next-key lock发生冲突，这里值得注意的是**对于同一间隙，不同事务加间隙锁不会发生冲突。

对于某数据行A，如果已经加了next-key lock，因为其中包含了gap lock，另一事务对于同一间隙加间隙锁时也不会发生冲突，原因同上。

上面曾说到，gap lock是为了解决幻读，也就是在读取的时候其他事务不能插入数据，那么这是怎么实现的呢？答案是通过特殊的间隙锁：insert intention lock，插入意向锁。对于一条insert语句，有如下规则（摘自参考文章.2）：

>1.执行 insert 语句，对要操作的页加 RW-X-LATCH，然后判断是否有和插入意向锁冲突的锁，如果有，加插入意向锁，进入锁等待；如果没有，直接写数据，不加任何锁，结束后释放 RW-X-LATCH( Latch，一般也把它翻译成 “锁”，但它和我们之前接触的行锁表锁（Lock）是有区别的。这是一种轻量级的锁，锁定时间一般非常短，它是用来保证并发线程可以安全的操作临界资源)；

>2.执行 select ... lock in share mode 语句，对要操作的页加 RW-S-LATCH，如果页面上存在 RW-X-LATCH 会被阻塞，没有的话则判断记录上是否存在活跃的事务，如果存在，则为 insert 事务创建一个排他记录锁，并将自己加入到锁等待队列，最后也会释放 RW-S-LATCH；

那么`ii lock`有啥用啊？直接插入不行嘛？网上都说是为了加快查找效率，真的是这样吗？

ii lock和上述三种行锁的兼容性如下所示：

|  表头   | record  | gap  | next-key | ii lock |
|  ----  | ----  | ----  | ----  | ---- |
| record  | 冲突 | 兼容 | 冲突 | 兼容 |
| gap  | 兼容 | 兼容 | 兼容 | 冲突 |
| next-key  | 冲突 | 兼容 | 冲突 | 冲突 |
| ii lock  | 冲突 | 兼容 | 冲突 | 兼容 |

由上表可知：

- 对于某一间隙，如果已经加了ii lock，是不影响其他事务加任何锁的
- 对于某一间隙，**如果已经加了gap lock或者next-key lock，是不允许插入ii lock的**，这一条阻止了幻读的发生，想一想，在读的时候禁止插入不就是能阻止幻读发生嘛。

### 3.3 行锁的生效条件

对于不同的隔离级别，使用的行锁算法不同，如果是在RC级别，只会存在record lock。如果在RR级别，存在record lock、gap lock以及next-key lock，后两者用来在RR级别解决幻读的问题。

不过行锁的生效条件比较特别：**只有通过索引条件检索数据，InnoDB才使用行级锁；如果没有使用索引列作为筛选条件，或者MySQL认为使用索引不如全表扫描，InnoDB会使用表锁。** 所以行锁锁定的内容就是索引。但是基于是否共享，锁定的索引内容不同。

- 共享锁只锁使用到的非主键索引树上符合条件的索引项。也就是说如果索引为非主键索引，只锁其对应的B+树中的内容，不会锁定非主键索引对应的主键索引。
- 排他锁会锁定使用到的索引以及对应的主键索引，因为执行 for update时，mysql会认为你接下来要更新数据，故对涉及到的索引都会加锁

在RR级别下，**行锁**的加锁以及退化规则比较复杂，包含了两个“原则”、两个“优化”和一个“BUG”：

- 原则1: 加锁的基本单位是Next-Key Lock。它是一个前开后闭的半开区间
- 原则2: 查找过程中访问到的对象才会加锁
- 优化1: 索引上的等值查询，给唯一索引加锁的时候，Next-Key Lock会退化为行锁
- 优化2: 索引上的等值查询，向右遍历时且最后一个值不满足等值条件的时候，Next-Key Lock会退化为间隙锁
- BUG: 唯一索引上的范围查询会访问到不满足条件的第一个值为止

## 4. 意向锁

意向锁可以分为`意向共享锁`、`意向排他锁`、`意向插入锁`。意向锁可以理解为一种表粒度的锁。如果一个事务视图对某数据行添加行锁，那么必须要先获得对应的意向锁。例如想要加排他锁，则要获得该表对应的意向排他锁。

## 4.1 意向锁的作用

意向锁主要作用是为了加快事务获得表锁的效率。因为InnoDB是支持多粒度锁的，想象如下一个场景：如果事务A优先对表T某一数据行加了排他锁，此后事务B想要对表T添加排他锁，那么事务B必须保证表T内的每一行都没有被上任何一种类型的锁。

此时如果没有意向锁，那么事务B需要做全表扫描，判断每一行是否有锁。如果存在意向锁，那么事务B只需要判断表T是否存在意向排他锁即可，加快了事务B上表锁的效率。

### 4.2 意向锁的使用方式

意向锁的加锁与释放由InnoDB负责，用户无需惯性。

### 4.3 意向锁的兼容性

意向锁各自相互兼容，与行锁兼容，但是与表锁会产生冲突。下表展示了意向锁与表锁之间的兼容性：

|  表头   | X  | S  | IX | IS  |
|  ----  | ----  | ----  | ----  | ----  |
| X  | 冲突 | 冲突 | 冲突 | 冲突 |
| S  | 冲突 | 兼容 | 冲突 | 兼容 |
ffdfd| IS  | 冲突 | 兼容 | 兼容 | 兼容 |
| IX  | 冲突 | 冲突 | 兼容 | 兼容 |

这个的X锁与S锁指的是表粒度的锁。

## 总结

在了解InnoDB锁特性后，用户可以通过设计和SQL调整等措施减少锁冲突和死锁，包括：

- 尽量使用**较低的隔离级别**； 精心设计索引，并尽量使用索引访问数据，使加锁更精确，从而减少锁冲突的机会；
- 选择合理的事务大小，小事务发生锁冲突的几率也更小；给记录集显式加锁时，最好一次性请求足够级别的锁。比如要修改数据的话，最好直接申请排他锁，而不是先申请共享锁，修改时再请求排他锁，这样容易产生死锁；
- 不同的程序访问一组表时，应尽量约定以相同的顺序访问各表，对一个表而言，尽可能以固定的顺序存取表中的行。这样可以大大减少死锁的机会；
- 尽量用相等条件访问数据，这样可以避免间隙锁对并发插入的影响； 不要申请超过实际需要的锁级别；除非必须，查询时不要显示加锁；
- 对于一些特定的事务，可以使用表锁来提高处理速度或减少死锁的可能

## 参考文章

1. [MySQL中的锁（表锁、行锁，共享锁，排它锁，间隙锁）](https://blog.csdn.net/soonfly/article/details/70238902)

2. [读 MySQL 源码再看 INSERT 加锁流程](https://www.aneasystone.com/archives/2018/06/insert-locks-via-mysql-source-code.html)

3. [解决死锁之路 - 常见 SQL 语句的加锁分析](https://www.aneasystone.com/archives/2017/12/solving-dead-locks-three.html)
————————————————
版权声明：本文为CSDN博主「WSYW126」的原创文章，遵循CC 4.0 BY-SA版权协议，转载请附上原文出处链接及本声明。
原文链接：https://blog.csdn.net/WSYW126/article/details/105324239
作者: 奚新灿
链接: https://xixincan.github.io/2020/08/20/MySQL/MySQL%E7%B3%BB%E5%88%97-08%E5%86%8D%E8%B0%88%E9%94%81%E8%A7%84%E5%88%99/
来源: 奚新灿的博客-Chronos
著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。