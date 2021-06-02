---
title: 计网热门问题
mathjax: true
data: 2021-01-16 15:06:05
updated: 2021-01-25 21:12:50
tags:
categories: network
---

本篇不为别的，只为记录面试过程中关于计网的热门问题。

[TOC]

---

## 1. 点击一个链接后，发生了什么

首先，我们需要有一个总的概念：在点击一个链接后，网卡首先会将http请求使用http协议封装，接着将数据包经由tcp/udp协议封装，最后使用ip协议将数据包在各个网段之间传输直至到达目的地。http协议的封装这里不作详细介绍。tcp连接的建立和ip数据包的转发才是重点。

1. tcp连接建立的基础是使用ip协议将数据包转发到目标主机
2. 使用ip的前提是知道目标主机的ip地址
3. 而ip地址的获取需要靠dns解析

所以点击链接后发生的事，主要分为域名解析、ip数据包转发、tcp连接，我们依次分析这三小部分。

**I. 域名解析**

dns解析的流程比较简单，查询步骤如下：

1. 首先查询浏**览器缓存**，如若失败则执行2，否则执行6

2. 查询本机**host文件**，如若失败则执行3，则执行6

3. 查询**本地dns服务器**（一般是指由用户设置的dns服务器），如果失败，如果采用迭代模式，则执行4；如果采用递归模式，则执行5

4. 本地dns服务器采用递归模式的查询流程如下所示：

![top-questions-for-network.dns-recursion](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.dns-recursion.png)

5. 本地dns采用迭代模式的查询流程如下所示：

![top-questions-for-network.dns-iteration](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.dns-iteration.png)

6. 返回域名对应的ip地址

上图中所谓的根服务器的概念与域名的级别有关系，根服务器负责管理13个顶级域名服务器，如下图所示：

![top-questions-for-network.root](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.root.png)

---

延申问题：

**Q1. 域名解析是通过dns映射完成的，那么这个映射是如何建立？**

<details>
<summary>展开</summary>

映射一般需要我们手动建立，建立的类型一般就是两种：A类和CNAME类。

- A类可以简单理解为域名到ip地址的直接映射。

- CNAME类（Canonical Name）就是域名到域名的映射。

CNAME类解析的用处多多，我们可以像使用环境变量一样设置CNAME[<sup>[1]</sup>](#refer-anchor-1)。例如如果我们在域名`test.com`下有三个子域名`a.test.com`、`b.test.com`、`c.test.com`。现在我们想把这三个子域名解析到我们的ip`10.10.1.11`，当然我们可以为每个子域名设置一个A类解析，但是如果更改了ip地址，那么需要更改的地方是非常多的。
反之，我们将这三个子域名都是用CNAME解析到域名`test.com`，那么解析时就把问题转化为`test.com`的ip地址是多少。当ip地址改变时，只需要更改`test.com`的A记录

 主机名 | 记录类型 | 目标 |
| :-----| ----: | :----: |
| test.com |A     | 10.10.1.11 |
| a.test.com | CNAME | test.com |
| b.test.com | CNAME | test.com |
| c.test.com | CNAME | test.com |

那么CNAME这么好用，它有什么缺陷呢？

1. CNAME只能解析到另一个域名，不能解析ip
2. 增加一次解析的负担，一般可以使用cdn加速

</details>

**Q2. 多个域名绑定到同一ip怎么区分？**

<details>
<summary>展开</summary>

如上所述，我们可以将多个子域名绑定到同一ip，一般我们需要根据端口来区分针对不同域名发起的请求。但是为了用户体验，我们希望多个域名都访问80端口，这时一般使用nginx实现反向代理[<sup>[13]</sup>](#refer-anchor-9)来区分不同域名。nginx为什么能够区分？因为http请求头中都会包含请求的域名。

或者使用虚拟主机，直接将子域名映射到二级目录就行。

</details>

**Q3. 上面提到的子域名是什么？**

<details>
<summary>展开</summary>
正如前文所述，域名是有等级的。根据[维基百科](https://en.wikipedia.org/wiki/Domain_name)，一级域名是13个顶级域名。一级域名左侧为二级域名，二级域名左侧为三级域名，以此类推。

例如域名`lol.qq.com`，一级域名为`com`、二级域名为`qq`、三级域名为`lol`。域名所有者可以任意配置所有域名下的子域名[<sup>[2]</sup>](#refer-anchor-2)。

但是站在使用者的角度，我们一般称`qq.com`为一级域名，因为单单使用`com`什么都不是。
</details>

---

**II. ip数据包的转发**

请求到目标域名的ip后，ip数据包首先需要传输到网关，然后再经过层层路由转发至目标主机[<sup>[3-5]</sup>](#refer-anchor-3)。而ip数据包的转发实际还要依靠链路层，而链路层的转发依靠的是mac地址。所以需要完成ip地址到mac地址之间的映射，这个工作交由arp协议来完成,由上可知**arp工作在链路层**。

**arp的请求是广播，而响应是单播**，因为在一个局域网中，主机A只知道路由器B的ip地址，而不知道路由器B的mac地址是多少，必须发起广播，并且只有路由器B才会响应这个arp请求。那么为什么主机能够知道需要将数据包转发至路由器B呢？这里我们可以将这个路由器B看作**默认网关**，这一般都会自动获取，而网关之后的转发流程就是网关的事了。

完成ip到mac的映射后，数据包会从主机A转发到路由器B。路由器B解析ip数据包后，发现目的ip为`111.222.333.444`。那么接下来怎么转发才能到这个地址呢？这就需要以来路由器中的路由表。而路由表的生成有专门的协议来负责，后面将会介绍。查询路由表后，一般都会知道下一跳路由器的ip地址，这时再使用arp协议请求mac地址，重复上面的操作就会层层路由到ip为`111.222.333.444`的主机了。

---

延申问题

**Q1：路由表是如何生成的？**

<details>
<summary>展开</summary>

首先我们需要知道根据不同的网络服务商，会组成不同的、各自的超大局域网，一般将超大局域网成为自治系统(autonomous system)。AS内部之间的路由协议称为**内部网关协议**( interior gateway protocol )，而AS之间的路由协议称为**外部网关协议**(Exterior gateway protocol)。

需要注意的是：参考[维基百科](https://en.wikipedia.org/wiki/Exterior_gateway_protocol)，IGP是内部网关协议的总称，并不是一个具体的协议。而EGP既是外部网关协议的总称，而且确实有一种外部网关协议叫做EGP。

具体来说，IGP主要有两种类型：距离矢量类型和链路状态类型，所谓的距离矢量就是靠源地址与目标地址之间的路由跳数来决定路由路径。而距离矢量类型是指通过路径长度、可靠性、延迟、带宽、负载和通信开销来决定路由路径。距离适量类型的代表路由协议是**路由信息协议RIP**、**内部网络路由协议IGRP**。链路状态类型的代表路由协议有开放式最短路由协议**OSPF**、**IS-IS**。

EGP运行于AS之间，代表协议主要包括EGP、BGP（EGP的升级版）、EBGP等。

</details>

---

**III. 建立tcp连接**

tcp连接的建立需要经过三次握手，如下图所示：

![top-questions-for-network.tcp-three-handshake](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.tcp-three-handshake.png)

1. 客户发送的第一个段是 SYN 段。这个段仅有 SYN 标志被置位，它用于序号同步。**它占用一个序号，不能携带数据**。当数据传输开始时，客户**随机**选择一个数字作为初始序号(ISN)。注意，这个段不包含确认号。它也没有定义窗口大小；窗口大小的定义只有当段包含确认号时才有意义。
&nbsp;
2. 服务器发送第二个段，两个标志位SYN和ACK置位的段，即 SYN  +ACK 段。这个段有两个目的。首先，它是另一方向通信的 SYN 段。服务器使用这个段来**随机**初始化序号，这个序号用来给从服务器发向客户的字节编号。服务器也通过给 ACK 置位并展示下一个序号来确认已经接收到来自客户的SYN，这里的下一个序号是服务器预期从客户接收的序号。因为它包含确认，它也需要定义接收窗口，即 rwnd（供客户参考使用）。因为这个段起到 SYN段的作用，它需要被确认。因此，**它占用一个序号。但SYN + ACK 段不携带数据**。
&nbsp;
3. 客户发送第三个段。这个段仅仅是一个 ACK 段。它使用 ACK 标志和确认序号字段来确认收到了第二个段。**该段可携带或者不携带数据**。注意，如果不携带数据，ACK段没有占用任何序号，但是一些实现允许这第三个段在连接阶段从客户端携带第一块数据，在这种情况下，段消耗的序号与数据字节数相同。

标志位小结：

SYN：可以理解为谁需要同步序号，谁就要设置SYN标志位
ACK：谁收到了数据包，谁就要设置ACK标志位

---

扩展问题：

**Q1: 为什么需要三次握手？**

<details>
<summary>展开</summary>
相信大家都知道，tcp连接的建立需要三次握手，但是想要明白为什么需要三次握手，我们首先就需要知道tcp的连接[<sup>[4]</sup>](#refer-anchor-4)和握手到底是什么意思。

根据[RFC 793 - Transmission Control Protocol ](https://tools.ietf.org/html/rfc793)的规定，tcp的连接定义如下：

>The reliability and flow control mechanisms described above require that TCPs initialize and maintain certain status information for each data stream. The combination of this information, including sockets, sequence numbers, and window sizes, is called a connection.

大致是说，为了防止网络的不确定性可能会导致数据包的缺失和顺序颠倒等问题，需要为每一个数据流初始化和保持确定的状态信息，包括socket、数据包序号、窗口大小。这些状态信息叫做一个连接。

那么握手到底是啥意思？我认为所谓的握手是指：对于一个**数据包**来说，它经历了一组收发的过程，就叫一次握手。如下图所示：

![what-is-a-handshake](https://eripe.oss-cn-shanghai.aliyuncs.com/img/tcp-handshake.drawio.svg)

明白了**连接**和**握手**的概念，我们再来讨论握手的次数。因为tcp是双工的，收方和发方都是可以发送信息的，所以就需要为收发两端同步上述的状态信息，而**两次握手都不能完成同步信息(主要是序列号ISN)的任务**。如何理解？

[RFC 793 - Transmission Control Protocol ](https://tools.ietf.org/html/rfc793)指出使用三次连接原因主要是为了防止重复的连接初始化信息出现，导致连接错乱：

>The principle reason for the three-way handshake is to prevent old duplicate connection initiations from causing confusion.

试想如下一个场景：
因为网络延迟较高，发送方A发出连接请求后，如果这个请求经过了很长时间才到达收方B。那么B无法判断这个请求是正常还是超时的。如果B采用两次握手，贸然建立连接，那么对A发出响应信息后，A是不会作出响应的，因为这个连接已经过时了。那么B建立连接的资源就一直无法释放。这是一个非常严重的问题。

那么为什么三次握手就能解决这个问题呢？其实我们可以把三次握手退化成四次握手，如下图所示：

![four-handshake](https://eripe.oss-cn-shanghai.aliyuncs.com/img/tcp-four-handshake.drawio.svg)

经过四次握手后，主机A和主机B都确认对方能够收到数据，就会建立tcp连接。如果此时再出现A发送的连接请求超时到达，B不会建立连接，而是向A发送应答请求，并且试图同步序列号，如果同步失败，连接就不会建立，主机A和B都能很快的释放资源。但是其中数据包2、3是可以一起发送的。四次就退化成三次握手，如下所示：

![top-questions-for-network.tcp-three-handshake](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.tcp-three-handshake.png)

图中三次握手的重点就是**同步序列号**，序列号之所以如此重要，是因为它能够防止以下情况出现：

1. 数据包丢失、超时到达
2. 数据包重发
3. 数据包乱序

</details>

**Q2: 为什么ISN是随机的？**

<details>
<summary>展开</summary>

简单来说，随机ISN防止了一些历史数据包和新数据包的冲突以及ISN欺骗攻击。

**数据包冲突问题**
如果ISN每次开始都是固定的、静止的起始值。想象如下一个场景：如果初始ISN固定为0，旧连接已经断开，因为网络问题旧数据包1-10仍残存于网络中。如果某时刻复用此旧链接，ISN又从0开始，那么新的数据包1-10和旧的数据包1-10有可能发生冲突。所以解决办法就是动态地随着时间增长生成ISN。但是这样同样存在下面的安全问题。

**ISN欺骗攻击**
如果ISN是根据当前时间计算，那么服务器生成的ISN有可能被破解，这就有可能发生ISN猜测攻击。下面是一个攻击场景[<sup>[9]</sup>](#refer-anchor-5)：现在我们有三台主机A、B、C

HOST A <----> HOST B
^
|
|
HOST C

在这里，主机A和主机B是受信任的主机。主机A接受来自主机B的连接，因为它是受信任的源。此处的识别参数只是ip地址（示例是rlogin应用程序，网络中的主机受信任并允许执行命令。请参阅rlogin以查看其工作原理）

现在，HOST C想要欺骗主机B并与A建立连接。步骤如下：

1. C（欺骗B）---->将SYN数据包发送给A，序列号为ISN_C。欺骗手段C发送以IP地址B作为源IP的数据包。
2. A用具有自己的序列号的SYN（ISN_A）+ ACK（ISN_C + 1）数据包响应SYN。但这不会达到C。这是因为B是受信任的源，并且A可以直接向B发送数据。A向B发送一个SYN + ACK数据包。但是B对此一无所知，并且可以选择重置连接。在这一阶段，我们必须通过使B充满垃圾数据包来使B保持忙碌，以便它不会响应A
3. 现在，C知道ISN_C，但不知道ISN_A，因为它没有收到数据包。如果**C可以预测ISN_A**，则可以发送具有确认号ISN_A + 1的第三个ACK数据包。这样，我们与A建立了3种方式的握手。（通过具有可预测的序列号，我们可以建立连接。）

现在我们可以将命令从C发送到A，它将执行该命令，因为我们正在欺骗可信任的源。这是一个严重的安全问题。同样，我们可以重置连接或将数据注入流中。

当然，上述攻击方式是有限制的：
1.如果C与A＆B在同一个网络中，并且可以嗅探数据包，则只需嗅探数据包就可以轻松看到ISN。随机序列号不会阻止这种情况。如果您与A和B位于不同的网络上，则可以防止受到攻击。

2.由于存在可信源（rlogin，rsh等）的概念且未进行任何加密，因此可能会发生这种攻击。如果具有任何类型的加密，则这种欺骗将不起作用。

**ISN计算公式**
[RFC1948 Defending Against Sequence Number Attacks](https://www.ietf.org/rfc/rfc1948.txt)提出的ISN计算方法如下：

>ISN = M + F(localhost, localport, remotehost, remoteport).

其中M是一个4微妙计时器，F是一个秘密的hash算法。这防止了一部分ISN猜测攻击

</details>

**Q3：SYN泛洪攻击是什么？如何防范？**

<details>
<summary>展开</summary>

SYN泛洪攻击时大量tcp连接发送到服务器，但是只进行前两次握手，导致服务器的资源无法释放。

解决策略： 当服务器接受到 SYN 报文段时，不直接为该 TCP 分配资源，而只是打开一个半开的套接字。接着会使用 SYN 报文段的源Id，目的Id，端口号以及只有服务器自己知道的一个秘密函数生成一个 cookie，并把 cookie 作为序列号响应给客户端。

如果客户端是正常建立连接，将会返回一个确认字段为 cookie + 1 的报文段。接下来服务器会根据确认报文的源Id，目的Id，端口号以及秘密函数计算出一个结果，如果结果的值 + 1等于确认字段的值，则证明是刚刚请求连接的客户端，这时候才为该 TCP 分配资源

这样一来就不会为恶意攻击的 SYN 报文段分配资源空间，避免了攻击。

</details>

---

## 2. https的是什么？原理是什么？

https全称为Hyper Text Transfer Protocol over Secure Socket Layer，也就是对http数据包使用tls/ssl协议加密。那么https的原理就是tls协议是如何工作的。

tls协议简单来说就是将http的明文数据包加密后再发送，那么如何同步客户端与服务端的加密套件、密钥呢？这些前提工作都会在tls握手的时候完成，这是我们需要重点理解的。

对于加密套件，我们都知道对称密钥算法的强度高，难破解。所以我们只需要为客户端和服务端同步一个对称加密算法。但是对称密钥在网络中的同步是十分困难的。所以对称密钥的同步是tls握手的重点，这一操作又称为密钥协商算法。常用的密钥协商算法分为基于RSA和基于DH两种类型。

**I. 基于RSA的密钥协商算法**

基于RSA的协商算法较为简单：客户端首先生成一个随机数，并使用服务端的公钥加密生成密文发送给服务端，服务端利用自己的私钥解密即可获得服务端生成的随机数。

但是**RSA密钥交换的简单性是它最大的弱点**。用于加密pre master key的服务器公钥，一般会保持多年不变。任何能够接触到对应私钥的人都可以解密第三个随机数，并构建相同的master key，从而危害到会话安全性。只要密钥泄露，就可以解密之前记录的所有流量了。

**基于DH的协商算法**

DH密钥协商基于一个数学难题，这个不详细介绍。我们只需要知道，对于求模公式`b = a^x mod p`：已知a计算b很容易，但是已知b计算a却很困难[<sup>[10]</sup>](#refer-anchor-6)，其中参数a、p均公开。

使用DH协商密钥的流程如下：

1. 服务器决定a、p两个参数，同时服务器首先生成一个随机数Xs，计算Ys=a^Xs mod p，将参数a、p和Ys发送给客户端，Xs保密

2. 客户端生成随机数Xc，计算Yc=a^Xc mod p，发送给服务器，Xc保密

3. 客户端利用公式Kc = Ys^Xc mod p计算公钥，服务器利用公式Ks = Yc^Xs mod p计算密钥，最终Kc和Ks一定相同，证明见[<sup>[10]</sup>](#refer-anchor-6)。

现在比较流程的基于DH的协商算法有ECDH（elliptic curve Diffie-Hellman），ECDH仅仅将基于求模的数学难题替换为基于椭圆曲线的数学难题，后者同样会选择合适的参数a和p。

tls将密钥分为了三个部分：

1. 客户端生成的随机数
2. 服务端生成的随机数
3. pre master key

tls最终会基于这三个部分计算最终的master key。其中前两个随机数的协商较为简单，明文传输即可；对于pre master key的协商则会应用上述基于RSA或DH的协商算法。
**II. tls流程分析**

tls的握手流程如下所示：

![tls-workflow](https://eripe.oss-cn-shanghai.aliyuncs.com/img/tls-workflow.drawio.svg)

接下来我们根据抓取访问淘宝的数据包来分析上图的各个阶段，我访问的ip地址为`140.205.94.189`，实际的握手数据包如下所示：

![top-questions-for-network.taobao-tls](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.taobao-tls.png)

**A. Client Hello**

该阶段就是客户端向服务器发起tls认证，向客户端发送了第一个随机数，,并声明客户端支持的算法套件。内容如下图所示：

![top-questions-for-network.client-hello](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.client-hello.png)

**B. Server hello**

该阶段确定了密钥算法，并向客户端发送了第二个随机数，如下图所示：

![top-questions-for-network.server-hello](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.server-hello.png)
**C. Certificate**

该阶段将服务器的证书发送给客户端验证，如下图所示：

![top-questions-for-network.certificate](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.certificate.png)

**D. Server key Exchange**

该阶段服务器会选择好a、p两个参数（这里的协商算法基于ECDH），并计算出Ys发送给客户端，如下图所示：

![top-questions-for-network.server-key-exchange](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.server-key-exchange.png)

**E. client key Excnahge**

该阶段客户端将自己的Yc发送给服务端，如下图所示：

![top-questions-for-network.client-key-exchange](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.client-key-exchange.png)

**F. Change Chiper Spec**

客户端和服务端都会存在该阶段，这一阶段表示握手需要的信息发送完毕了，下面就可以使用生成的master key加密数据传输了。

**G. New Session Ticket**

该阶段的工作就是服务器传递给客户端一个Session用以维持https连接，不然每次都像上面这么连接是十分浪费资源的，此次传递的session如下图所示：

![top-questions-for-network.session-ticket](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.session-ticket.png)

至此，同步了session后，客户端和服务端的握手流程结束，可以使用协商好的master key进行加密与解密了。

---
扩展问题：

**Q1：tls为什么要使用两个随机数？**

<details>
<summary>展开</summary>

以下答案摘自[https运行原理解析笔记](https://coolcao.com/2018/08/06/https/)：

>前两个随机数采用明文传输，存在被拦截的风险，最终对话密钥安全性只和第三个随机数有关，那么前两个随机数有没有必要？
“不管是客户端还是服务器，都需要随机数，这样生成的密钥才不会每次都一样。由于SSL协议中证书是静态的，因此十分有必要引入一种随机因素来**保证协商出来的密钥的随机性*8。

>对于RSA密钥交换算法来说，pre-master-key本身就是一个随机数，再加上hello消息中的随机，三个随机数通过一个密钥导出器最终导出一个对称密钥。

>pre master的存在在于SSL协议不信任每个主机都能产生完全随机的随机数，如果随机数不随机，那么pre master secret就有可能被猜出来，那么仅适用pre master secret作为密钥就不合适了，因此必须引入新的随机因素，那么客户端和服务器加上pre master secret三个随机数一同生成的密钥就不容易被猜出了，一个伪随机可能完全不随机，可是是三个伪随机就十分接近随机了，每增加一个自由度，随机性增加的可不是一。”

所以简单来说，采用三个随机数是为了是最终的对话密钥更“随机”。

</details>

**Q2：tls使用的证书了解吗**

<details>
<summary>展开</summary>

证书按照认证等级可以划分为DV、OV、IV、EV，从左到右，安全性依次增强，当然价格也依次增高。

数字证书的作用就相当于我们的身份证。对于一个网站A来说，它没办法向客户端证明它是A，就好像我们证明自己身份时需要借助身份证一样。所以这时一般需要借助一个权威的机构来做信用背书，这个权威的机构向客户端证明网站A的真实性。我们是可以完全相信这些权威机构的，所以间接的，我们就相信网站A真的是它自己了。这里的权威机构就是CA（Certificate Authority）。

那么这里存在一个问题，CA证明我们的网站是真的，那么谁来证明这些CA是真的？答案很简单：因为CA是有等级的，会构成一条形如：网站A->普通CA->中等CA->顶级CA的信用链。顶级CA没有理由作假，因为没有必要砸自己的饭碗。所以顶级CA证明自己的方法就是在给自己颁发的证书上自签名，这一类自己给自己证明的证书叫**自签证书**，又称**根证书**。浏览器和操作系统一般都会将可信度的根证书内置，方便认证。

那么CA机构颁发数字证书的一般流程是怎么样的呢？

1. 首先向CA机构提供CSR(certificate signing request),CSR大致个人信息和公钥
2. CA验证我们提交的信息，主要是验证我们是否对域名有真正的控制权。如果验证通过，则会使用我们提交的CSR和公钥生成对应的CA证书，并使用自己的私钥对CA进行签名

上述的认证过程肯定是要花钱的，那么是不是我们一定要花钱才能获得数字证书呢？当然不，因为上面曾提到顶级CA会发布自签证书，我们也可以利用开源软件，比如[openssl发布自定义自签证书](https://www.gokuweb.com/operation/d95eae05.html)，再用自定义自签证书发布普通的CA证书。哎，那么那些花钱的人是不是傻？有免费的不用？

天下没有免费的午餐，自签证书虽然不花钱，但是它最大的缺点就是自签证书**非常**容易被伪造。并且浏览器一般无法认证由自定义自签证书签署的CA证书，会出现下面这种情况：

![self-signed](images/self-signed.png)

这时因为自签根证书没有内置，信用链的顶部没有可信度。当然我们可以把自定义自签证书安装在浏览器中，就不会出现这种问题。当然，这可能会遭受中间人攻击。

自签名根证书可能被伪造，如果在主机中安装了伪造的根证书，这时中间人使用了伪造的自签名证书，就不会出现错误提示，劫持了正常流量，这样中间人和主机之间使用自签名的伪造证书建立了https链接，而中间人又和目标网站使用网站正规的CA证书建立了https链接，那么流量对于中间人来说，完全是明文的

</details>

**Q3：https一定安全吗？**

<details>
<summary>展开</summary>

**只要我们不信任不安全的CA的证书，https就是安全的。**

因为权威CA签署的证书不容易被篡改。如果篡改了证书内容，新的摘要无法使用CA机构的私钥加密。那么当客户端使用CA机构的公钥解密摘要时，明文和客户端自己计算的证书摘要对不上号，导致证书不被信任，拒绝连接。

当然仍然有办法攻破https，我发现了两个可能成功的办法：

**方法1：DNS欺骗+安装自定义根证书**

但是上面曾说道，我们可以发布自定义自签根证书，我们使用[dns劫持+伪造证书](https://blog.cuiyongjian.com/safe/https-attack/)开展中间人攻击，https将不再安全。攻击方法如下图所示：

![https-hijack](https://eripe.oss-cn-shanghai.aliyuncs.com/img/https-hijack.drawio.svg)

攻击前提是攻击者已经预先在主机中安装了自签名的根证书A，然后基本的攻击场景如下：

1. 首先主机对目标网站发起https连接，这时通过**dns劫持**将流量定向到攻击者的机器上
2. 攻击者返回使用自定义根证书A签名的CA证书，这时由于根证书已经预先安装到主机上，浏览器不会发出警告。所以主机与攻击者之间建立了https连接，主机发送的数据对攻击者来说完全是可见的
3. 攻击者再与真正的目标网站建立https连接，将主机发送给自己的数据完全转发到目标网站，同理网站的响应数据也将由攻击者转发到主机上

经过上述的步骤，主机似乎与网站建立了安全的https连接，但是数据完全被中间人窃听了。

**方法2：sslStrip**

SSLStrip[<sup>[15]</sup>](#refer-anchor-11)方法也是中间人攻击一种。攻击前提时用户使用http发起第一次连接，因为用户一般只会写域名，而不会声明特定的协议。

该方法的核心操作是利用arp欺骗或dns欺骗将主机流量定向到攻击者机器上并建立http连接，而攻击者与目标网站建立真正的https连接。

那么如何防范上述攻击呢？这要从客户端和服务端两个方面防范：

- 服务端：开启HSTS，拒绝http连接等等
- 客户端：不要相信不安全的证书、不要使用http连接

</details>

**Q4：http如何升级为https？**

<details>
<summary>展开</summary>

将http升级为https的方法一般以下两种方法：

1. 302重定向
2. 服务端开启HSTS(HTTP Strict Transport Security)[<sup>[12]</sup>](#refer-anchor-8)

重定向的方法很简单，简单让浏览器重定向访问即可，但是非常不安全。因为第一次连接使用http协议的，这有可能被劫持实施SSLStrip。而且即便当前连接是https，页内的连接仍有可能是http的，又给了黑客一次机会。所以这种方法很不安全。

上面的缺陷可以总结为两点：

- 用户书签是http或者手动输入了http
- https连接的页面内可能有http连接

而HSTS能够在一定程度上解决上面的缺陷。因为开启HSTS后，浏览器内部会将http使用307重定向为https，并且HSTS还能够完全拒绝危险的证书。因为上面曾说过，浏览器虽然会对自签证书发出警告，但是用户可以选择忽略警告，继续访问，如下图所示：

![hsts](images/HSTS.png)

HSTS则不会显示此选项，用户不能忽略警告。

**HSTS开启的方法**

只需要在http添加以下内容即可：

>Strict-Transport-Security: max-age=31536000; includeSubDomains

其中`max-age`表示HSTS有效的时间。

**HSTS的缺陷**

HSTS虽然厉害，但仍然有缺点：用户首次访问某网站是不受HSTS保护的。这是因为首次访问时，浏览器还未收到HSTS，所以仍有可能通过明文HTTP来访问。解决这个问题的方法有两点[<sup>[14]</sup>](#refer-anchor-10)：

一是浏览器预置HSTS域名列表，Google Chrome、Firefox、Internet Explorer和Spartan实现了这一方案。google坚持维护了一个“HSTS preload list”的站点域名和子域名，并通过[https://hstspreload.appspot.com/](https://hstspreload.appspot.com/)提交其域名。该域名列表被分发和硬编码到主流的web浏览器。客户端访问此列表中的域名将主动的使用HTTPS，并拒绝使用HTTP访问该站点。

二是将HSTS信息加入到域名系统记录中。但这需要保证DNS的安全性，也就是需要部署域名系统安全扩展。截至2014年这一方案没有大规模部署。

</details>

---

## 3. tcp的断开机制？

tcp的断开有两种情况：理想情况下的三次握手，或者**半关闭**的四次握手。

因为tcp是双工的，所以当tcp断开来接时，收发两端都需要确定对方收到了自己准备要断开连接的信息。所以与tcp建立连接的三次握手类似，在理想情况下，三次握手就能够保证收发两端收到足够的信息断开连接。过程如下图所示：

![top-questions-for-network.tcp-remove-three-handshake](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.tcp-remove-three-handshake.png)

而所谓的半关闭，是指在一方断开了连接的请款下，另一方仍能够发送剩余的信息。半关闭就需要四次握手才能传递足够的信息,这是因为理想情况下的第二次握手被拆分成了两次。如下图所示：

![top-questions-for-network.tcp-remove-four-handshake](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.tcp-remove-four-handshake.png)

---

扩展问题

**Q1：TIME_WAIT状态了解吗？**

tcp连接与释放的过程中，会形成11种状态，如下图所示：

![top-questions-for-network.11-status](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.11-status.png)

而`TIME_WAIT`状态是**断开**连接时**主动方独有**的状态。当主动方进入该状态时，等待2MSL后，才会完全释放当前资源。

我们以半关闭四次握手的状态转化为例，了解什么时候会进入该状态：

![top-questions-for-network.time-wait-status-in-four](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.time-wait-status-in-four.png)

从上图中看出，当主动方发出FIN后，会经历FIN-WAIT-1 --> FIN-WAIT-2 --> TIME-WAIT  --> CLOSED的状态转化。

而被动方第一次收到主动方的FIN后，会经历CLOSE-WAIT --> LAST-ACK --> CLOSED状态。

**Q2：TIME_WAIT为什么被设置为2MSL？**

有两点原因[<sup>[17]</sup>](#refer-anchor-13)：

1. 防止复用旧链接的ip、端口建立新链接时，旧链接的数据包还存活
2. 保证tcp正确的被关闭，即被动关闭一方收到ACK

首先MSL（maximum segment lifetime）是segment能够在网络中存活的最长时间。那么为什么2MSL就能保证旧链接的数据包不会存活呢？

在进入TIME-WAIT状态后，主动方会发送ACK，这个ACK最坏在刚好经过1MSL时，到达了被动收方。而被动收方在ACK到达前一直在重发FIN。如果在0.9999MSL时，被动收方发送了最后一个FIN，它最多在网络中存活1MSL。那么主动收方等待2MSL后，主动方发送的最后一个ACK、被动方发送的最后一个FIN都会在网络中消失。
那么旧链接的普通数据包肯定会在最后一个ACK和FIN之前发出，所以普通数据包也肯定会在网络中消失。

当主动方每次收到FIN,会重设2MSL的等待时间。

如果Server在长时间收不到ACK，重传FIN的次数达到某一设定值时，会向Client发送RESET报文段，表明“异常终止”，然后完全结束本次TCP连接（它不再操心客户是否收到RESET报文段），避免无限占用资源。（对应上图中的Stop Sending FIN)

---

## 4. tcp是如何保证可靠性的？

保障可靠性主要有三个方面：流量控制、差错控制（校验和、确认机制、超时机制）、拥塞控制。

流量控制仅仅是考虑两台机器之间的传输能力，而拥塞控制则考虑了网络传输的能力。

## 5. tcp的流量控制？

流量控制通过滑动窗口来实现，并且发送方的窗口通过接收方来控制。接收方会维护一个名为`rwind`的滑动窗口。还需更新

一般有一个要求：
新的ackNo+新rwnd>=旧的ackNo+旧rwnd，也就是说滑动窗口的右沿一般不移动

---

**Q1：糊涂窗口综合症是什么？如何避免？**

糊涂窗口综合症有两种：发方糊涂和收方糊涂。

**发方糊涂**是指发送方每次发送的数据很少，极端情况下有效数据仅有一个字节，而tcp头部达到四十字节，极大降低效率。解决办法是nagle算法：

1. nagle算法定义是任意时刻，最多只能有一个未被确认的小段。 所谓“小段”，指的是小于MSS尺寸的数据块，所谓“未被确认”，是指一个数据块发送出去后，没有收到对方发送的ACK确认该数据已收到。流程如下图所示：

![top-questions-for-network.nagle](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.nagle.png)

**收方糊涂**是指收方处理数据很慢，每次都只能处理一个字节，而发送方一次也只能发送一个字节。处理的方法一般有以下两种：

1. 延迟确认，这表示当一个报文段到达时并不立即发送确认。接收端在确认收到的报文段之前一直等待，直到缓存有足够的空间为止。

2. Clark解决方法，这表示只要有数据到达就发送确认，但宣布的窗口大小为零，直到或者缓存空间已能放入具有最大长度的报文段，或者缓存空间的一半已经空了。

---

## 6. tcp的拥塞控制？

tcp提出了四种拥塞策略：慢启动，拥塞避免，快速重传，快恢复。而实际的拥塞算法可以按照判断拥塞的标准分为基于丢包的拥塞算法和基于网络延迟的拥塞算法[<sup>[18]</sup>](#refer-anchor-14)：

![top-questions-for-network.base-packet-loss](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.base-packet-loss.png)
![top-questions-for-network.base-time](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.base-time.png)

而上述四种拥塞策略主要应用在传统的基于丢包的拥塞算法上：

- taho：采用慢启动和拥塞避免策略。并且用相同的拥塞策略对待超时和三次ACk
- reno：采用慢启动、拥塞避免、快速恢复策略
- new reno：采用慢启动、拥塞避免、快速恢复策略


以下内容详细介绍了这四种策略的步骤，以及在三种算法中的应用。引自[TCP拥塞控制算法](https://www.cnblogs.com/fll/archive/2008/06/10/1217013.html)：

最初由V. Jacobson在1988年的论文中提出的TCP的拥塞控制由“慢启动(Slow start)”和“拥塞避免(Congestion avoidance)”组成，后来TCP Reno版本中又针对性的加入了“快速重传(Fast retransmit)”、“快速恢复(Fast Recovery)”算法，再后来在TCP NewReno中又对“快速恢复”算法进行了改进，近些年又出现了选择性应答( selective acknowledgement,SACK)算法。

TCP的拥塞控制主要原理依赖于一个拥塞窗口(cwnd)来控制，在之前我们还讨论过TCP还有一个对端通告的接收窗口(rwnd)用于流量控制。TCP的拥塞控制算法就是要在这两者之间权衡，选取最好的cwnd值，从而使得网络吞吐量最大化且不产生拥塞，一般来说选择min(cwind,rwind)。

关于cwnd的单位，在TCP中是以**字节**来做单位的，我们假设TCP每次传输都是按照MSS大小来发送数据的，因此你可以认为cwnd按照数据包个数来做单位也可以理解，所以有时我们说cwnd增加1也就是相当于字节数增加1个MSS大小。

**I. 慢启动**

最初的TCP在连接建立成功后会向网络中发送大量的数据包，这样很容易导致网络中路由器缓存空间耗尽，从而发生拥塞。因此新建立的连接不能够一开始就大量发送数据包，而只能根据网络情况逐步增加每次发送的数据量，以避免上述现象的发生。具体来说，当新建连接时，cwnd初始化为1个最大报文段(MSS)大小，发送端开始按照拥塞窗口大小发送数据，每当有一个报文段被确认，cwnd就增加1个MSS大小。这样cwnd的值就随着网络往返时间(Round Trip Time,RTT)呈指数级增长，事实上，慢启动的速度一点也不慢，只是它的起点比较低一点而已。我们可以简单计算下：

1. 开始           --->     cwnd = 1

2. 经过1个RTT后   --->     cwnd = 2*1 = 2

3. 经过2个RTT后   --->     cwnd = 2*2= 4

4. 经过3个RTT后   --->     cwnd = 4*2 = 8

如果带宽为W，那么经过RTT*log2W时间就可以占满带宽。

**II. 拥塞避免**

从慢启动可以看到，cwnd可以很快的增长上来，从而最大程度利用网络带宽资源，但是cwnd不能一直这样无限增长下去，一定需要某个限制。TCP使用了一个叫慢启动门限(ssthresh)的变量，当cwnd超过该值后，慢启动过程结束，进入拥塞避免阶段。对于大多数TCP实现来说，ssthresh的值是65536(同样以字节计算)。**拥塞避免的主要思想是加法增大，也就是cwnd的值不再指数级往上升，开始加法增加**。此时当窗口中所有的报文段都被确认时，cwnd的大小加1，cwnd的值就随着RTT开始线性增加，这样就可以避免增长过快导致网络拥塞，慢慢的增加调整到网络的最佳值。

上面讨论的两个机制都是没有检测到拥塞的情况下的行为，那么当发现拥塞了cwnd又该怎样去调整呢？

首先来看TCP是如何确定网络进入了拥塞状态的，**TCP认为网络拥塞的主要依据是它重传了一个报文段**。上面提到过，TCP对每一个报文段都有一个定时器，称为重传定时器(RTO)，当RTO超时且还没有得到数据确认，那么TCP就会对该报文段进行重传，当发生超时时，那么出现拥塞的可能性就很大，某个报文段可能在网络中某处丢失，并且后续的报文段也没有了消息，在这种情况下，TCP反应比较“强烈”：

1. 把ssthresh降低为cwnd值的一半

2. 把cwnd重新设置为1

3. 重新进入慢启动过程。

从整体上来讲，TCP拥塞控制窗口变化的原则是AIMD原则，即加法增大、乘法减小。可以看出TCP的该原则可以较好地保证流之间的公平性，因为一旦出现丢包，那么立即减半退避，可以给其他新建的流留有足够的空间，从而保证整个的公平性。

其实TCP还有一种情况会进行重传：那就是收到3个相同的ACK。TCP在收到乱序到达包时就会立即发送ACK，TCP利用3个相同的ACK来判定数据包的丢失，此时进行**快速重传**，快速重传做的事情有：

1. 把ssthresh设置为cwnd的一半

2. 把cwnd再设置为ssthresh的值(具体实现有些为ssthresh+3)

3. 重新进入拥塞避免阶段。

**III. 快速恢复**

后来的快速恢复算法是在上述的“快速重传”算法后添加的，当收到3个重复ACK时，TCP最后进入的不是拥塞避免阶段，而是快速恢复阶段。快速重传和快速恢复算法一般同时使用。快速恢复的思想是“数据包守恒”原则，即同一个时刻在网络中的数据包数量是恒定的，只有当“老”数据包离开了网络后，才能向网络中发送一个“新”的数据包，如果发送方收到一个重复的ACK，那么根据TCP的ACK机制就表明有一个数据包离开了网络，于是cwnd加1。如果能够严格按照该原则那么网络中很少会发生拥塞，事实上拥塞控制的目的也就在修正违反该原则的地方。

具体来说快速恢复的流程如下所示：

![top-questions-for-network.reno](https://eripe.oss-cn-shanghai.aliyuncs.com/img/top-questions-for-network.reno.png)

1. 当收到3个重复ACK时，把ssthresh设置为cwnd的一半，把cwnd设置为ssthresh的值加3，然后重传丢失的报文段，加3的原因是因为收到3个重复的ACK，表明有3个“老”的数据包离开了网络。 

2. 再收到重复的ACK时，拥塞窗口增加1。

3. 当收到新的数据包的ACK时，把cwnd设置为第一步中的ssthresh的值。原因是因为该ACK确认了新的数据，说明从重复ACK时的数据都已收到，该恢复过程已经结束，可以回到恢复之前的状态了，也即再次进入拥塞避免状态。

快速重传算法首次出现在4.3BSD的Tahoe版本，快速恢复首次出现在4.3BSD的Reno版本，也称之为Reno版的TCP拥塞控制算法。

可以看出Reno的快速重传算法是针对一个包的重传情况的，然而在实际中，一个重传超时可能导致许多的数据包的重传，因此当多个数据包从一个数据窗口中丢失时并且触发快速重传和快速恢复算法时，问题就产生了。因此NewReno出现了，它在Reno快速恢复的基础上稍加了修改，可以恢复一个窗口内多个包丢失的情况。具体来讲就是：Reno在收到一个新的数据的ACK时就退出了快速恢复状态了，而NewReno需要收到该窗口内所有数据包的确认后才会退出快速恢复状态，从而更一步提高吞吐量。

SACK就是改变TCP的确认机制，最初的TCP只确认当前已连续收到的数据，SACK则把乱序等信息会全部告诉对方，从而减少数据发送方重传的盲目性。比如说序号1，2，3，5，7的数据收到了，那么普通的ACK只会确认序列号4，而SACK会把当前的5，7已经收到的信息在SACK选项里面告知对端，从而提高性能，当使用SACK的时候，NewReno算法可以不使用，因为SACK本身携带的信息就可以使得发送方有足够的信息来知道需要重传哪些包，而不需要重传哪些包。

## 7. 加不加www有什么区别？

其实是因为早期服务器资源有限，一个服务器往往要承担多项任务，所以在主域名前面加子域名`www`表示万维网服务[<sup>[16]</sup>](#refer-anchor-12)，例如`www.example.com`表示互联网，`mail.example.com`表示邮件服务。

而后来资源丰富，仍然加上www仅仅是为了纪念万维网的建立，

## 8. http常用的状态码有哪些？

1. 2xx状态码：操作成功。200 OK
2. 3xx状态码：重定向。301 永久重定向；302暂时重定向
3. 4xx状态码：客户端错误。400 Bad Request；401 Unauthorized；403 Forbidden；404 Not Found；
4. 5xx状态码：服务端错误。500服务器内部错误；501服务不可用

## 9. 既然IP层已经分片了，TCP为什么还要分段？

因为ip是没有重传机制的，如果tcp不分段，那么如果ip层丢失了某个报文片，就需要重传整个报文。

## 10. GET和POST的区别？

1. POST与相比GET，A通常在请求主体中具有相关信息。（一个GET不应该有主体，因此除了cookie之外，唯一可以传递信息的地方就是URL。）除了保持URL相对整洁之外，POST还可以让您发送更多的信息（由于URL的长度受到限制，因此在实际操作中用途），并让您几乎可以发送任何类型的数据（例如，文件上传表单不能使用GET-它们必须使用，还要POST加上特殊的内容类型/编码）。

2. 除此之外，POST表示请求将更改某些内容，并且不应随意重做。这就是为什么您有时会在单击“后退”按钮时看到浏览器询问您是否要重新提交表单数据的原因。

3. GET另一方面，它应该是幂等的，这意味着您可以做一百万次，并且服务器每次都会做相同的事情（并且基本上显示出相同的结果）

4. 最后，在使用AJAX发送GET请求时，一个重要的考虑因素是某些浏览器（尤其是IE）会缓存GET请求的结果。因此，例如，如果您使用相同的GET请求进行轮询，即使您正在查询的数据正在服务器端更新，您也将始终获得相同的结果。缓解此问题的一种方法是，通过附加时间戳使每个请求的URL唯一。

## 参考文章

<div id="refer-anchor-1"></div>

[1] [什么是CNAME记录？CNAME记录如何使用](https://www.pythonthree.com/what-is-cname/)

<div id="refer-anchor-1"></div>

[2] [顶级域名 一级域名 二级域名 三级域名什么区别?](https://www.zhihu.com/question/29998374)

<div id="refer-anchor-3"></div>

[3] [一步一步学习IP路由流程](https://blog.csdn.net/lnboxue/article/details/52220928)

[4] [转发表(MAC表)、ARP表、路由表总结](https://cloud.tencent.com/developer/article/1173761)

[5] [数据包的通信过程](https://www.cnblogs.com/michael9/p/13345911.html)

[6] [浅谈路由协议](https://zhuanlan.zhihu.com/p/21392419)

<div id="refer-anchor-4"></div>

[7] [为什么 TCP 建立连接需要三次握手](https://draveness.me/whys-the-design-tcp-three-way-handshake/)

[8] [阿里面试官： HTTP、HTTPS、TCP/IP、Socket通信、三次握手四次挥手过程？（附全网最具深度的三次握手、四次挥手讲解）](https://developer.aliyun.com/article/742739)

<div id="refer-anchor-5"></div>

[9] [Why in a TCP sequence, is a number taken as a random number and what is the actual number at the start?](https://www.quora.com/Why-in-a-TCP-sequence-is-a-number-taken-as-a-random-number-and-what-is-the-actual-number-at-the-start)

<div id="refer-anchor-6"></div>

[10] [理解 Deffie-Hellman 密钥交换算法](http://wsfdl.com/algorithm/2016/02/04/%E7%90%86%E8%A7%A3Diffie-Hellman%E5%AF%86%E9%92%A5%E4%BA%A4%E6%8D%A2%E7%AE%97%E6%B3%95.html)

<div id="refer-anchor-7"></div>

[11] [HTTPS篇之SSL握手过程详解](https://razeencheng.com/post/ssl-handshake-detail)

<div id="refer-anchor-8"></div>

[12] [What Is HSTS and Why Should I Use It?](https://www.acunetix.com/blog/articles/what-is-hsts-why-use-it/)

<div id="refer-anchor-9"></div>

[13] [Understanding Nginx HTTP Proxying, Load Balancing, Buffering, and Caching](https://www.digitalocean.com/community/tutorials/understanding-nginx-http-proxying-load-balancing-buffering-and-caching)

<div id="refer-anchor-10"></div>

[14] [nginx启用HSTS以支持从http到https不通过服务端而自动跳转](https://blog.csdn.net/weixin_44316575/article/details/103698819)

<div id="refer-anchor-11"></div>

[15] [HSTS学习笔记](https://jjayyyyyyy.github.io/2017/04/27/HSTS.html)

<div id="refer-anchor-12"></div>

[16] [为什么有些网址前面没有www？](https://www.zhihu.com/question/20064691)

<div id="refer-anchor-13"></div>

[17] [为什么TCP4次挥手时等待为2MSL？](https://www.zhihu.com/question/67013338)

<div id="refer-anchor-14"></div>

[18] [万字长文|全网最强 TCP/IP 拥塞控制总结...](https://my.oschina.net/u/3872630/blog/4434563)