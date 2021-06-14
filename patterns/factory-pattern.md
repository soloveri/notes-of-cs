---
title: 工厂模式扫盲
index_img: 
date: 2021-06-09 19:51:05
hide: true
intro: 
tags:
- factory
categories:
- design patterns
---

工厂模式可以分为三种：简单工厂模式、工厂方法模式以及抽线工厂模式。本文对这三种设计模式进行了简单介绍。

## 1. 为什么需要工厂模式

## 2. 静态工厂模式

## 3. 工厂方法模式

每生产一种新的对象，不仅要构建对应的类，还要构造对应的工厂类。也就是说，增加一种新的生产目标，至少要增加两个类，同时不能组合生产各种已有的对象。

## 4. 抽象工厂模式

工厂方法与抽象工厂

{% note info %}
First, we must note that neither Java nor C# existed when the GoF wrote their book. The GoF use of the term interface is unrelated to the interface types introduced by particular languages. Therefore, the concrete creator can be created from any API. **The important point in the pattern is that the API consumes its own Factory Method**, so an interface with only one method cannot be a Factory Method any more than it can be an Abstract Factory.
{% endnote %}

1. [](https://stackoverflow.com/questions/4209791/design-patterns-abstract-factory-vs-factory-method#comment119542960_4209791)

2. [](https://stackoverflow.com/a/38668246/12893742)
