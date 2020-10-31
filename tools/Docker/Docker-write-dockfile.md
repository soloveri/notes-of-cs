---
title: Dockerfile的基本规则
mathjax: true
data: 2020-07-22 09:48:28
updated:
tags:
categories:
- Docker
---

## 前言
在了解了[docker的基本原理](Docker-filesys-layout.md)后，是时候了解以下Dockerfile是怎么写的了。首先我们需要了解`RUN`与`CMD`命令的区别。

- `RUN`命令：每执行一次，就会在原有镜像的基础上添加一个`upper dir`保存所作的改变，所以对于一类的命令我们尽量使用一条`RUN`，否则会创建过多的不必要的`upper dir`
- `CMD`命令：容器是一个进程，`CMD`命令就像是容器启动时输入的命令参数，所以只能有一条`CMD`

## Dockerfile的栗子

下面是我基于centos7.8制作的mysql5.7镜像。Dockerfile如下所示：

``` Dockerfile
FROM centos:7.8.2003

MAINTAINER sssoloveri@gmail.com
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

RUN echo "root:123456" | chpasswd \ 
&& groupadd --gid 1000 rain \
&& useradd --uid 1000 --gid rain  --shell /bin/bash --create-home rain \
&& echo "rain:123456" | chpasswd
#USER rain
RUN rpm -ivh https://mirrors.aliyun.com/epel/epel-release-latest-7.noarch.rpm \
&& rpm --rebuilddb \ 
&& yum install -y yum-utils net-tools sudo vim \
&& rpm -ivh https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm \
&& yum install -y mysql-community-server \
&& yum install -y openssh openssh-server openssh-clients \
&& mkdir -p /var/run/sshd \
#&& mkdir -p ~/.ssh \
&& yum install -y supervisor \
&& rm -rf /etc/supervisord.conf \
&& mkdir -p /etc/supervisord/conf.d \
&& mkdir -p /var/log/supervisor/ \
&& mkdir -p /var/run/supervisor/ \
&& ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key \
&& ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key
COPY authorized_keys /root/.ssh/authorized_keys
COPY supervisord.conf /etc/supervisord.conf
#COPY mysql.conf /etc/supervisord/conf.d/
#COPY sshd.conf /etc/supervisord/conf.d/
RUN yum clean all

EXPOSE 3306 22

# 挂载数据、配置和日志目录
RUN rm -rf /etc/my.cnf /var/lib/mysql /var/log/mysqld.log
VOLUME ["/var/lib/mysql", "/etc/my.cnf","/var/log/mysqld.log"]

CMD ["/usr/sbin/init"]
```

上面的内容基本上可以分为以下四个步骤：

1. 选取基础镜像，声明作者
2. 安装基础软件，这一步骤中不要写太多的`RUN`，因为这样会让镜像十分臃肿
3. 拷贝一些必要的文件，设置数据挂载目录，开放网络端口
4. 声明容器入口命令

安装基础软件没什么好说的，按照自己的需求声明就好。 **重点是数据卷映射的权限问题**。以上面的Dockerfile为例，我们当前宿主机的用户id为1000。我们容器启动时的命令为：

``` docker
docker run -d -u 1000:1000 \                       
--name mysql --hostname mysql --privileged=true \
--volume /usr/local/mysql/data/:/var/lib/mysql \
--publish 3306:3306  -v /usr/local/mysql/config/my.cnf:/etc/my.cnf -v /usr/local/mysql/log/mysqld.log:/var/log/mysqld.log mysql:latest /usr/sbin/init

```
上面我进行了三项文件或目录的映射：

1. (宿主机)/usr/local/mysql/data/----->(容器)/var/lib/mysql
2. (宿主机)/usr/local/mysql/config/my.cnf----->(容器)/etc/my.cnf
3. (宿主机)/usr/local/mysql/log/mysqld.log------>(容器)/var/log/mysqld.log

上述三个宿主机中的文件或目录的拥有者都是uid为1000的用户。那么就会产生四种情况：

1. 容器中没有uid为1000的用户，并且没有指定容器的启动用户
2. 容器中没有uid为1000的用户，并且指定了一个容器中不存在的用户作为启动用户
3. 容器有uid为1000的用户，并且指定了uid为1000的用户作为启动用户
4. 容器有uid为1000的用户，但是指定了容器中的另一个uid=1111的用户作为启动用户

面对上面的问题，我们需要树立一个总的前提：容器中被映射的目录或文件的所有权是与宿主机中映射的目录或文件相同的。所以在容器中，目录`var/lib.mysql`，文件`my.cnf`、`mysqld.log`的所有者都是uid=1000的用户。然后就是容器的启动用户是谁的问题。

1. 如果没有明确指定，那么容器的默认启动用户就是root
2. 如果指定了一个容器中不存在的用户，那么容器会显示`I have no name!`，没有username，没有home
3. 如果指定的是容器中存在的但不是uid=1000的用户，那么就会正常显示用户名，但不能操作文件，因为所有者不同
4. 如果指定了容器中存在且和宿主机uid相同的用户，那么就能正常操作文件

所以显而易见，docker是**根据uid而不是username的映射**来完成权限管理的。所以我们在创建镜像时，一般都会创建一个uid与宿主机数据卷所有者相同的用户方便在容器中操作文件。**一定要确保容器执行者的权限和挂载数据卷的所有者相对应。**


## 参考文献

1. [docker挂载volume的用户权限问题,理解docker容器的uid](https://www.cnblogs.com/woshimrf/p/understand-docker-uid.html)
2. [docker的中文手册](https://yeasy.gitbook.io/docker_practice/image/dockerfile/workdir)
3. [MySQL的Docker镜像制作详解](http://ghoulich.xninja.org/2018/03/27/how-to-build-and-use-mysql-docker-image/)