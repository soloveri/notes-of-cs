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

在了解了docker的基本原理后，是时候了解以下Dockerfile是怎么写的了。


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

## 参考文献

1. [docker挂载volume的用户权限问题,理解docker容器的uid](https://www.cnblogs.com/woshimrf/p/understand-docker-uid.html)
2. [docker的中文手册](https://yeasy.gitbook.io/docker_practice/image/dockerfile/workdir)
3. [MySQL的Docker镜像制作详解](http://ghoulich.xninja.org/2018/03/27/how-to-build-and-use-mysql-docker-image/)