---
title: volatile关键字
mathjax: true
data: 2020-12-06 13:13:19
updated:
tags: 
- volatile
categories:
- 多线程基础
---



volatile是什么

所谓的禁止指令重排也是为了保证内存的可见性

volatile如何实现的

volatile真的禁止重排序了吗

volatile是怎么用的



DCL中，执行构造函数也会进行内存读写，volatile保证前面这些读写一定发生在volatile前面

## 参考文献

1. [What is the point of making the singleton instance volatile while using double lock?](https://stackoverflow.com/questions/11639746/what-is-the-point-of-making-the-singleton-instance-volatile-while-using-double-l/11640026#11640026)