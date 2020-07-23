---
title: Docker使用方法(二)-文件系统架构
mathjax: true
data: 2020-07-22 09:48:28
updated:
tags:
categories:
- Docker
---

## 前言

一定要将登录用户切换为root才能查看Docker的文件架构！！！

## 0x1 基本文件布局

Docker的文件主要都存储在`/var/lib/docker`目录下,文件目录如下所示:

![filesys-layout](images/filesys.png)

其中`containers`存储的是容器,`images`存储的是镜像。


https://blog.51cto.com/haoyonghui/2457915

https://blog.csdn.net/luckyapple1028/article/details/77916194

https://gowa.club/Docker/Docker%E7%9A%84overlay2%E7%AE%80%E8%BF%B0.html

https://www.codenong.com/js95e91aa62d46/

https://www.cnblogs.com/sammyliu/p/5877964.html

https://www.jianshu.com/p/3826859a6d6e
