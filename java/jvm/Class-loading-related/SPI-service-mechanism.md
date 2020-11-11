---
title: 通过MySQL驱动的加载学习SPI机制
mathjax: true
data: 2020-11-11 22:19:25
updated:
tags: 
- SPI机制
- 数据库驱动加载
categories: 类加载
---

## 什么是SPI

SPI机制（Service Provider Interface)简而言之，就是java规定了一组服务的接口，但是没有具体的实现类。那么具体的实现类肯定由不同的厂商实现，那么客户在使用时是仅依赖于接口的。

在讲解双亲委派模型时，我们知道，SPI接口是通过`bootstrap ClassLoader`加载至jvm中的。而具体的驱动实现类是通过线程上下文类加载器加载至jvm中的。下面我们就来看看我们常用的驱动到底是怎么被加载的。


## 获得数据库连接实例的方式

在JDBC4.0之前，驱动加载还没有引入SPI，所以加载驱动的代码一般是如下所示：

``` java
Class.forName("xxxx");
Connection c=DriverManager.getConnection("url");
```

在JDBC4.0之后，我们只需要使用`DriverManager.getConnection(url)`就可以获得连接对象。这是因为在`getConnection()`内部会自己调用`Class.forName()`。这里包含了一层嵌套关系。所以内部的`Class.forName()`得使用外部的`Bootstrap ClassLoader`加载实现类，而在JDBC4.0之前没有这层嵌套关系。

下面我们来看看我们到底是如何获得驱动的。在初次使用`DriverManager`时，首先会执行静态代码块中`loadInitialDrivers()`函数。

``` java
static {
    loadInitialDrivers();
    println("JDBC DriverManager initialized");
}
```

初始化函数如下：

``` java
private static void loadInitialDrivers() {
    String drivers;
    try {
        drivers = AccessController.doPrivileged(new PrivilegedAction<String>() {
            public String run() {
                return System.getProperty("jdbc.drivers");
            }
        });
    } catch (Exception ex) {
        drivers = null;
    }

    AccessController.doPrivileged(new PrivilegedAction<Void>() {
        public Void run() {

            ServiceLoader<Driver> loadedDrivers = ServiceLoader.load(Driver.class);
            Iterator<Driver> driversIterator = loadedDrivers.iterator();
            try{
                while(driversIterator.hasNext()) {
                    driversIterator.next();
                }
            } catch(Throwable t) {
            // Do nothing
            }
            return null;
        }
    });

    println("DriverManager.initialize: jdbc.drivers = " + drivers);

    if (drivers == null || drivers.equals("")) {
        return;
    }
    String[] driversList = drivers.split(":");
    println("number of Drivers:" + driversList.length);
    for (String aDriver : driversList) {
        try {
            println("DriverManager.Initialize: loading " + aDriver);
            Class.forName(aDriver, true,
                    ClassLoader.getSystemClassLoader());
        } catch (Exception ex) {
            println("DriverManager.Initialize: load failed: " + ex);
        }
    }
}
```

可以看到，初始化分为两种情况

``` java
@CallerSensitive
public static Connection getConnection(String url,
    String user, String password) throws SQLException {
    java.util.Properties info = new java.util.Properties();

    if (user != null) {
        info.put("user", user);
    }
    if (password != null) {
        info.put("password", password);
    }
    return (getConnection(url, info, Reflection.getCallerClass()));
}

@CallerSensitive
public static Connection getConnection(String url,
    java.util.Properties info) throws SQLException {
    return (getConnection(url, info, Reflection.getCallerClass()));
}
```