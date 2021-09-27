---
title: Docker使用方法(一)-基本安装
mathjax: true
date: 2020-07-22 09:39:40
updated: 2021-06-03 16:50:37
index_img: /img/docker.png
excerpt: 简要介绍了docker的基本使用与配置
tags: Docker
categories:
- tools
---

## 前言

1. 实验主机:虚拟机ubuntu-18.04 LTS

2. docker版本:19.03

3. 能google

因为如果在安装vm的主机上直接安装docker for windows是基本不可能成功的,要么卸载vm,要么在把vm升级到15.5以上,再或者在vm将docker配置为虚拟机使用。所以我选择在虚拟机中安装docker。所以基本架构为:windows->vm->docker->containers,老套娃了。

## 基本安装

在ubuntu中安装我也是直接copy网上的指令就完事了。建议使用DaoCloud的[一键安装脚本](http://get.daocloud.io/)就完事了。

## 镜像配置

新版的配置采用json文件的方式,首次使用时需要在`/etc/Docker/`目录下新建`daemon.json`。然后填入以下内容:

>{
  "registry-mirrors": ["your mirror url"]
}
中科大的镜像源为`https://docker.mirrors.ustc.edu.cn`。

镜像源的选择一般有以下三种:

- [DaoCloud](https://www.daocloud.io/mirror#accelerator-doc)
- [阿里云](https://developer.aliyun.com/article/29941)
- [中科大镜像源](https://lug.ustc.edu.cn/wiki/mirrors/help/docker)

最后重启docker:
> service docker restart

完事。

## Docker初体验

使用`Docker pull hello-world`拉取镜像看看Docker是否能正常工作。

使用`Docker run hello-world`运行镜像。

ps:

如果你使用DaoCloud的脚本安装Docker,那么运行镜像的话会产生权限问题，如下所示:

>docker: Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: Post http://%2Fvar%2Frun%2Fdocker.sock/v1.26/containers/create: dial unix /var/run/docker.sock: connect: permission denied.
See 'docker run --help'.

意思就是我们没有权限访问unix socket,从而导致无法与Docker Engine通信。

- 临时办法:使用`sudo`运行
- 一劳永逸:`sudo usermod -a -G docker $USER`,记得重启或者重录当前用户,配置才能生效。

## 参考文献

1. [Docker的安装](https://www.jianshu.com/p/34d3b4568059)

2. [权限问题的解决方法](https://medium.com/@dhananjay4058/solving-docker-permission-denied-while-trying-to-connect-to-the-docker-daemon-socket-2e53cccffbaa)

