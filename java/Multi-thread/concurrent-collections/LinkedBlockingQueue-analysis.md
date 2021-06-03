---
title: LinkedBlockingQueue与ArrayBlockingQueue分析
mathjax: true
hide: true
data: 2021-04-10 18:25:26
updated:
tags:
- concurrent collections
categories:
- java basic
---

`LinkedBlockingQueue`使用两个锁的原因是为了实现读写分离，聊率更高。如果只有一个锁，生产者和消费者只能有一个角色在工作。

ArrayBlockingQueue为何不适合锁分离
这个主要是循环队列的原因，主要是数组和链表不同，链表队列的添加和头部的删除，都是只和一个节点相关，添加只往后加就可以，删除只从头部去掉就好。为了防止head和tail相互影响出现问题，这里就需要原子性的计数器，头部要移除，首先得看计数器是否大于0，每个添加操作，都是先加入队列，然后计数器加1，这样保证了，队列在移除的时候，长度是大于等于计数器的，通过原子性的计数器，双锁才能互不干扰。数组的一个问题就是位置的选择没有办法原子化，因为位置会循环，走到最后一个位置后就返回到第一个位置，这样的操作无法原子化，所以只能是加锁来解决。