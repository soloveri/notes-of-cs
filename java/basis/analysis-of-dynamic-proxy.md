---
title: 动态代理的原理
mathjax: true
data: 2021-03-13 19:45:18
updated:
tags:
- dynamic proxy
categories:
- java
---

## 1. 前言

代理分为静态代理和动态代理。静态代理就是我们手动地将代理类写出来，而动态代理就是由虚拟机在运行时自动地将代理类构造出来。下面我就简单地阐述静态代理的用法以及缺点。

首先在下面声明需要代理的类：

``` java
//实体类实现的接口
public interface UserDao {
    public void add();

    public void delete();

    public void update();

    public void search();
}

//实体类
public class UserDaoImpl implements UserDao{
    @Override
    public void add() {
        System.out.println("call the add method.");
    }

    @Override
    public void delete() {
        System.out.println("call the delete method");
    }

    @Override
    public void update() {
        System.out.println("call the update method");
    }

    @Override
    public void search() {
        System.out.println("call the search method");
    }
}
```

被代理的类`UserDaoImpl`实现了接口`UserDao`。

## 2. 静态代理

所谓的静态代理就是手动地构造一个类，并实现被代理类的所有接口，在代理类调用被代理类的目标方法，下面我们构造一个实现`UserDao`接口的方法：

``` java
package com.learn.proxy;

import com.learn.dao.UserDao;

public class staticProxy implements UserDao{
    private UserDao user;

    public void setUser(UserDao user) {
        this.user = user;
    }

    @Override
    public void add() {
        System.out.println("call the method:add");
        user.add();
    }

    @Override
    public void delete() {
        System.out.println("call the method:delete");
        user.delete();
    }

    @Override
    public void update() {
        System.out.println("call the method:update");
        user.update();
    }

    @Override
    public void search() {
        System.out.println("call the method:search");
        user.search();
    }
}
```

可以看到，如果被代理的类方法过多，在每个代理类的方法都得写上同样的代码，太冗余，而且容易出错，是个体力活。所谓为了解决这个缺点，产生了动态代理。

## 3. 动态代理

动态代理有两种实现方式：

- 使用Java原生API：Proxy+InvocationHandler
- 使用cglib

这里先讲讲Java原生API是怎么用的，有什么缺点。

### 3.1 基于原生API的动态代理

原生API要求被代理的类必须实现接口，动态代理由`Proxy`类的静态方法`newProxyInstance`生成，并且要求用于生成动态代理的类必须实现接口`InvocationHandler`，如下所示：

``` java
public class UserDaoProxy implements InvocationHandler {
    private UserDao user;

    public void setUser(UserDao user) {
        this.user = user;
    }

    public Object getProxyObject(){
        System.getProperties().put("sun.misc.ProxyGenerator.saveGeneratedFiles", "true");
        return Proxy.newProxyInstance(this.getClass().getClassLoader(), user.getClass().getInterfaces(),this);
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        System.out.println("using "+method.getName());
        //去user对象中查找有没有method对应的方法
        Object result=method.invoke(user, args);
        return result;
    }
}
```

其中`public static Object newProxyInstance(ClassLoader loader,Class<?>[] interfaces,InvocationHandler h)`需要我们提供四个参数：

1. loader：用于定义动态代理类的ClassLoader
2. interfaces：被代理的类已经实现的接口
3. h：InvocationHandler对象

这三个参数没有什么难理解的，我们需要主要关注`invoke`方法的构成。我们需要在方法调用前执行的操作以及在方法调用后执行的操作都需要在书写在`invoke`函数。其中最重要就是不能忘记调用`method.invoke`，这一句完成了实际方法的调用。

那么为什么要这么写，动态生成的代理类到底长什么样？我们来瞅瞅（如果没有找到动态代理类，一般是因为没有保存至磁盘，只需要添加虚拟机启动参数`-Dsun.misc.ProxyGenerator.saveGeneratedFiles=true`即可）。

``` java

//动态代理类继承了Proxy类，并且实现了我们传递的接口参数
public final class $Proxy0 extends Proxy implements UserDao {
    private static Method m1;
    private static Method m2;
    private static Method m3;
    private static Method m5;
    private static Method m6;
    private static Method m0;
    private static Method m4;

    public $Proxy0(InvocationHandler var1) throws  {
        super(var1);
    }

    public final boolean equals(Object var1) throws  {
        try {
            return (Boolean)super.h.invoke(this, m1, new Object[]{var1});
        } catch (RuntimeException | Error var3) {
            throw var3;
        } catch (Throwable var4) {
            throw new UndeclaredThrowableException(var4);
        }
    }

    public final String toString() throws  {
        try {
            return (String)super.h.invoke(this, m2, (Object[])null);
        } catch (RuntimeException | Error var2) {
            throw var2;
        } catch (Throwable var3) {
            throw new UndeclaredThrowableException(var3);
        }
    }

    public final int hashCode() throws  {
        try {
            return (Integer)super.h.invoke(this, m0, (Object[])null);
        } catch (RuntimeException | Error var2) {
            throw var2;
        } catch (Throwable var3) {
            throw new UndeclaredThrowableException(var3);
        }
    }
    ...

     public final void add() throws  {
        try {
            super.h.invoke(this, m3, (Object[])null);
        } catch (RuntimeException | Error var2) {
            throw var2;
        } catch (Throwable var3) {
            throw new UndeclaredThrowableException(var3);
        }
    }
    

    static {
        try {
            m1 = Class.forName("java.lang.Object").getMethod("equals", Class.forName("java.lang.Object"));
            m2 = Class.forName("java.lang.Object").getMethod("toString");
            m3 = Class.forName("com.learn.dao.UserDao").getMethod("add");
            m5 = Class.forName("com.learn.dao.UserDao").getMethod("delete");
            m6 = Class.forName("com.learn.dao.UserDao").getMethod("search");
            m0 = Class.forName("java.lang.Object").getMethod("hashCode");
            m4 = Class.forName("com.learn.dao.UserDao").getMethod("update");
        } catch (NoSuchMethodException var2) {
            throw new NoSuchMethodError(var2.getMessage());
        } catch (ClassNotFoundException var3) {
            throw new NoClassDefFoundError(var3.getMessage());
        }
    }
}
```

可以看出，动态代理类继承了`Proxy`类，并且实现了我们传递的接口，也就是被代理类实现的接口`UserDao`。所以也就实现了该接口的所有方法。对于`add`方法，仅仅只有一句代码：`super.h.invoke(this, m3, (Object[])null);`，调用了父类属性`InvocationHandler`的`invoke`方法。而这个`InvocationHandler`就是我们在调用`newProxyInstance`时传递进去的参数`this`。所以其`invoke`的方法就是我们`UserDaoProxy`类中实现的`invoke`方法。

上述就是基于JDK的动态代理原理。可以看到，我们在生成代理对象时，必须传递被代理类实现的接口。如果我们想代理一个没有实现接口的参数怎么办？cglib解决了这个问题。

### 3.2 基于cglib的代理

cglib是基于ASM框架的一个高性能代码生成库，而ASM是一个Java字节码操控框架。它能被用来动态生成类或者增强现有类的功能。那么cglib到底是如何使用的呢？

第一步当然是导入对应的jar包，很简单，在maven respo中搜索即可：

``` xml
<dependency>
    <groupId>cglib</groupId>
    <artifactId>cglib</artifactId>
    <version>3.3.0</version>
</dependency>
```

在cglib中，想要实现代理最重要的一步就是设置回调函数（callback），所谓的回调函数就是在调用目标方法之前或者之后设置需要实现的代理操作。并且在callback中调用真正的目标方法。cglib的callback有很多种类型，最常用的就是实现callback的子接口`MethodInterceptor`，这个接口会拦截被代理的所有方法，如下面的代码所示：

``` java
public class Proxy implements MethodInterceptor {
    @Override
    public Object intercept(Object o, Method method, Object[] objects, MethodProxy methodProxy) throws Throwable {
        System.out.println("call the method before:" + method.getName());
        //调用被代理类的方法
        Object o1 = methodProxy.invokeSuper(o, objects);
        System.out.println("call the method after:" + method.getName());
        return o1;
    }

    @Override
    public String toString() {
        return "Proxy{}";
    }
}

```

然后构造一个代理类，这需要借助工具类`Enhancer`（意为增强，比较好理解），cglib实现代理的原理是继承被代理类，所以需要完成的操作包括：

1. 生成工具类Enhancer
2. 设置父类
3. 设置回调函数callback
4. 生成被代理类

如下所示：

``` java
public class testCG {
    public static void main(String[] args) {
        System.setProperty(DebuggingClassWriter.DEBUG_LOCATION_PROPERTY, "D:\\cglib");
        Enhancer enhancer=new Enhancer();
        //设置父类
        enhancer.setSuperclass(DaoImpl.class);
        //设置回调函数callback
        enhancer.setCallback(new Proxy());
        //生成被代理类
        DaoImpl en = (DaoImpl)enhancer.create();
        en.add();
        en.toString();
    }
}
```

cglib代理的实现原理较复杂，目前没有时间深究，列出两篇原理的讲解，以后有时间在学习。

1. [CGLIB入门系列三，CGLIB生成的代理类详解](https://blog.csdn.net/P19777/article/details/103998918)

## 参考文章

1.[CREATE PROXIES DYNAMICALLY USING CGLIB LIBRARY](https://objectcomputing.com/resources/publications/sett/november-2005-create-proxies-dynamically-using-cglib-library)

2. [Cglib及其基本使用](https://www.cnblogs.com/xrq730/p/6661692.html)