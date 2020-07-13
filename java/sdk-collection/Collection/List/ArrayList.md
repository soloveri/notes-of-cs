## 前言

分析源码初体验，第一次分析个比较简单的集合类ArrayList。我们首先来看看ArrayList中的继承图。

![ArrayList继承图](images/arrayList-hierarchy.png)

`ArrayList`继承自抽象类`AbstractList`,并且实现了接口`RandomAccess`、`Cloneable`、`Seriablizable`、`List`(虽然AbstractList也实现了List接口)