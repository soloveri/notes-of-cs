---
title: 双亲委派模型
mathjax: true
data: 2020-11-05 21:11:27
updated:
tags: 类加载
categories: jvm
---

## 前言

首先在了解双亲委派模型前，我们有必要了解它的英文名字：`parents delegation model`。其实在具体的模型中，并没有所谓的“双亲”，只有一个逻辑意义上的父类，详情见下文。

## 1. 类加载器

在《深入理解java虚拟机》一书中写道：
>java团队有意将类加载阶段中的“通过一个类的全限定名来获取该类的二进制字节流”这个动作放到java虚拟机外部去实现
完成这个动作的代码就称为类加载器，以前不理解放到虚拟机外部是什么意思，现在我的理解是我们能够在编写程序时就能够编写目标类的加载过程，这也就是所谓的在虚拟机外部。这样如此，我们自定义的类加载器就能够处理我们自定义的字节码。

值得一提的是：类加载器与类共同确定了该类在虚拟机中是否唯一。也就是说，在虚拟机要比较两个类是否相同，比较的前提是**待比较的两个类是由同一个类加载器加载到虚拟机中的**，才有比较的意义。

这里的比较包括：`instanceof`、Class对象的`equals()`、`isAssignableForm()`、`isInstance()`方法。

## 2. 双亲委派模型

在了解双亲委派模型前，我们需要知道，jvm中有三类自带的类加载器：

- `bootstrap class loader`，启动类加载器
- `extension class loader`，扩展类加载器
- `Application class laoder`，应用程序类加载器

**启动类加载器**
启动类加载器由cpp编写，在java代码中无法直接引用。该加载器负责加载java的核心库，包括`<JAVA_HOME>/lib/`下的库，例如rt.jar、tools.jar；或者由`-Xbootclasspath`指定的，并且存放在lib目录下的符合规则的库，这里的规则是库的名字由jvm指定，不符合名字要求的即使由参数指定，也不会被加载。

前面说到，该加载器由cpp编写时，所以在编写代码时如果我们需要使用到该加载器，我们可以用null指代启动类加载器，这以规则由java团队约定。

**扩展类加载器**

扩展类加载器由java编写，负责加载`<JAVA_HOME>/lib/ext/`目录下的库，或者由环境变量`java.extdirs`指定目录下的库。

**应用程序加载器**

应用程序类加载器通用由java编写，在代码中可以直接引用。该加载器是我们接触最多的加载器了，默认情况下，我们编写的class都由其加载至jvm中。它负责加载由`classpath`参数指定路径下的类库。

>应用程序类加载器由`sun.misc.Launcher$AppClassLoader`实现。并且应用程序类加载器是ClassLoader中的getSystemClassLoader()方法的返回值


**参考文献**

https://greenhathg.github.io/2019/06/02/Java%E8%99%9A%E6%8B%9F%E6%9C%BA%E7%AC%94%E8%AE%B0-Launcher%E7%B1%BB/

https://juejin.im/post/6844903837472423944

https://segmentfault.com/a/1190000021869536