---
title: Java日志库扫盲
mathjax: true
hide: true
intro: # abstract for file
data: 2021-06-07 16:57:55
updated:
tags: 
- logging
categories:
- tools
---

## 1. 基本概念

slf4j：simple logging facade for Java，可以看作用来管理各个日志库的调度器，我们只需要通过配置slf4j后端具体的使用的日志库就可以完成日志操作，对用户隐藏了后端真正使用的日志库
log4j：一个日志库
Logback：日志库

## 2. 如何结合slf4j使用log4j

其实结合slf4j使用log4j并不难，但是因为不了解各个库的作用，浪费了一些时间。

在最初，我以为只用引入log4j为slf4j提供的适配器即可使用，因为我在maven仓库中看到适配器有三个依赖库：
![log-system-for-Java-abstract.log4j-slf4j-impl-dependencies](https://eripe.oss-cn-shanghai.aliyuncs.com/img/log-system-for-Java-abstract.log4j-slf4j-impl-dependencies.png)

但是会爆错：
>log4j-slf4j java.lang.ClassNotFoundException: org.slf4j.LoggerFactory

到官网仔细一看，发现正常引用log4j只需要引入`log4j-core`、`log4j-api`，如下所示：

![log-system-for-Java-abstract.log4j](https://eripe.oss-cn-shanghai.aliyuncs.com/img/log-system-for-Java-abstract.log4j.png)

但是我想配合`slf4j`使用，所以继续往下寻找，发现了一句至关重要的话：

![log-system-for-Java-abstract.slf-bridge](https://eripe.oss-cn-shanghai.aliyuncs.com/img/log-system-for-Java-abstract.slf-bridge.png)

不要移出任何原有的`slf4j`依赖，所以恍然大悟，不仅要在`pom.xml`文件中引入`log4j-api`、`log4j-core`，想要结合`slf4j`,需要同时引入log4j提供的适配器`log4j-slf4j-impl`。

所以完整的依赖如下所示：

``` xml
<!-- https://mvnrepository.com/artifact/org.slf4j/slf4j-api -->
<!-- slf4j library-->
<dependency>
    <groupId>org.slf4j</groupId>
    <artifactId>slf4j-api</artifactId>
    <version>1.7.30</version>
</dependency>
<!-- https://mvnrepository.com/artifact/org.apache.logging.log4j/log4j-slf4j18-impl -->
<!--log4j为slf4j提供的适配器-->
<dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-slf4j-impl</artifactId>
    <version>2.14.1</version>
</dependency>
<!-- https://mvnrepository.com/artifact/org.apache.logging.log4j/log4j-core -->
<!--log4j library-->
<dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-core</artifactId>
    <version>2.14.1</version>
</dependency>

<!-- https://mvnrepository.com/artifact/org.apache.logging.log4j/log4j-api -->
<dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-api</artifactId>
    <version>2.14.1</version>
</dependency>
```

## 3. 可能存在的问题

从官方maven仓库中拷贝的`log4j-slf4j-impl`依赖时带有`<scope>test</scope>`，我们需要将其改为`complie`或删除，才能使适配器生效。

## 参考文章

1. [Maven,Ivy,Gradle,and SBT Artifacts](https://logging.apache.org/log4j/2.x/maven-artifacts.html)
2. [Introduction to the Denpendency Mechanism](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html)