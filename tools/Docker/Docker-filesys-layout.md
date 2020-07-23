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

其中`containers`存储的是容器,`images`存储的是镜像。在深入了解Docker的原理之前,我们需要了解两个基本名词:

- overlayFS
- overlay2

### overlayFS

其中overlayFS是一种类似于aufs的文件堆叠系统,但是比aufs更快。本质上来说,overlayFS是属于linux内核驱动的一部分。

overlayFS依赖于已有的底层文件系统,它并不实际参与硬盘的分区。而是将一些底层文件系统的文件合并,给不同的用户呈现不同的文件,实现了相同文件复用的功能,提高了空间使用率。下面一张图很好的解释了overlayFS的[基本工作原理](https://blog.csdn.net/luckyapple1028/article/details/77916194):

![overlayFS](images/overlayFs.jfif)

overlayFS分为四个部分:

- lower dir
- upper dir
- merge dir
- work dir

其中的lower dir和upper dir来自底层文件系统,可以由用户自行指定。其中merge dir就是overlayFS的挂载点。并且overlayFS有如下特点:

- 如果lower和upper中有同名的目录,会在merge中合并为同一个文件夹。
- 如果如果lower和upper中有同名的目录,只会使用来自upper的同名文件
- 如果有多个lower存在同名文件,那么使用层次较高的lower dir的同名文件
- lower dir是只读的
- upper dir是可读可写的
- overlayFS具有copyup的特性。也就是如果想对lower dir中的文件进行写入,只能将文件拷贝至upper dir,然后再进行写入。

### overlayFS的写入操作




### overlayFS的删除操作

这就是所谓的堆叠文件系统。详细介绍请移步:

- [overlayFS的基本介绍](https://blog.csdn.net/luckyapple1028/article/details/77916194)
- [overlayFS的基本使用](https://blog.csdn.net/luckyapple1028/article/details/78075358)

### overlay2

docker为overlayFS提供了了两个存储驱动,一个是原始的overlay,另外一个就是现在新版的overlay2。所以docker自然也采用了堆叠的方式存储镜像。

其中images layer相当于lower dir,containers layer相当于upper dir,最后挂载到容器指定的挂载点(merged目录)


https://blog.51cto.com/haoyonghui/2457915

https://blog.csdn.net/luckyapple1028/article/details/77916194

https://gowa.club/Docker/Docker%E7%9A%84overlay2%E7%AE%80%E8%BF%B0.html

https://www.codenong.com/js95e91aa62d46/

https://www.cnblogs.com/sammyliu/p/5877964.html

https://www.jianshu.com/p/3826859a6d6e
