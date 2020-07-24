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


#### overlayFS的挂载

overlayFS的基本用法可以参考[官网](https://wiki.archlinux.org/index.php/Overlay_filesystem)。下面是我参照[overlayFS的基本使用](https://blog.csdn.net/luckyapple1028/article/details/78075358)做的一个复现。

首先需要创建lower、upper、work、merge这四类目录,文件树如下所示:

![work tree](images/worktree.png)

首先对各个dir下的文件写入标记:

![write-content-1](images/write-content-1.png)

然后对各个foo文件写入标记:

![write-content-2](images/write-content-2.png)

最后执行挂载命令:

> sudo mount -t overlay overlay -o lowerdir=lower1:lower2,upperdir=upper,workdir=work merge

注意`workdir`和`merge`之间是没有`,`的。`lowerdir`后面的目录是有顺序的,排在前面的lower dir在lower这个层次中的排名就较前,也就是如上面第一张图所示:

![overlayFS](images/overlayFs.jfif)

挂载后merge目录下的结构如下:

![merge-tree](images/merge-tree.png)

最后在merge目录中的`aa`文件来自`lower1`,`bb`文件来自`upper`。`foo`文件来自`lower`与`upper`。如下图所示：

<div align=center>![result](images/result.png)</div>

可以看到确实将同名的底层文件都隐藏了起来。

#### overlayFS的写入操作

upper dir是一个可读可写层,而lower dir是只读层。所以如果我们想要写入的文件来自upper dir,那就是直接写入,在此就不举例说明了;如果来自lower dir,就会先将文件复制到upper再写入。这就是所谓的copy-up特性。

下图是在上述文件挂载完成后向来自`lower1/dir/`的`aa`写入文件:

![write-to-lower](images/write-to-lower.png)

可以看到,我们在挂载点向lower层的文件写入内容后,upper层直接复制了了`lower1/dir/aa`,并直接追加写入的内容。而`lower1/dir/aa`本身的内容的却没有改变。

#### overlayFS的删除操作

overlayFS中的删除并不是真正的删除,它只是使用了一个障眼法-**whiteout**文件来覆盖同名文件,让用户以为已经把文件删除了。

>whiteout文件并非普通文件，而是主次设备号都为0的字符设备（可以通过"mknod <name> c 0 0"命令手动创建）

>并且whiteout文件再merge层不可见。达到了隐藏文件的目的

删除操作分为三个场景：

- 要删除的文件/文件夹没有覆盖,仅来自upper层,那么直接删除就好
- 删除的文件/文件来自lower层,upper层中不存在,那么会在merge层和upper中生成同名的**whiteout**文件,用于屏蔽底层文件

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如下图所示,其中upper在进行删除操作前为空目录：

![delete-from-lower](images/delete-from-merge.png)


- 要删除的文件来自lower层,upper中存在覆盖,那么会在merge层和upper层生成同名的**whiteout**文件,用于屏蔽底层文件。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;原始文件结构如下:

![file-struct](images/worktree.png)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;删除后的upper目录如下:

![delete-from-upper](images/delete-from-upper.png)

这也就是docker中,虽然在container layer(upper)中删除了许多东西,但是image layer(lower)还是没有变小的原因。


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
