# 自我介绍

面试官您好，我叫高宇航，目前是武汉大学国家网络安全学院的硕士二年级研究生，本科也就读于武汉大学网络安全学院。

在个人技术方面：
我对Java的基础比较熟悉，包括Java语言本身以及一些jvm的相关原理，在安全方面，我对二进制安全比较了解，能够熟练阅读调试汇编，使用常见的恶意代码分析工具，比如ollydbg、IDA，对于web安全，我了解一些基本的攻击漏洞，例如xss和CSRF

在项目经验方面，主要分为两部分：

第一部分是因为我想深入了解一下web服务器到底是如何工作的，所以我自己完成了一个具备servlet容器功能的web服务器，对于一个servlet容器的核心功能都进行了实现，包括servlet的完整生命周期、重定向与内部转发、cookie与session，调用用户servlet处理的http的请求

第二部分是参与了实验室的一个大课题，跟另外一个组员完成了一些APT组织恶意样本分析，我主要负责DarkHotel、GreenSpot，并对一些通用的木马功能函数（包括字符串加解密、程序自启动、手机信息这三个类别）进行了代码重构与复用，并编译成静态库供病毒开发使用，最后为整个项目开发了一个恶意文件上下载的原型系统

## 1.tomcat

### 为什么要参考tomcat？

### 为什么要实现一个servlet的容器？

### 基本功能

web服务器实现了servlet的完整声明周期，同时包含用于处理http请求的核心功能，包括cookie与session、http的重定向与内部跳转，自定义类加载器、过滤器，支持多端口多应用部署。

### 整体架构

servlet容器总共由六个组件构成，分别是：server、service、connector、engine、host、context这6个核心组件

1. Server元素在最顶层，代表整个Tomcat容器，因此它必须是server.xml中唯一一个最外层的元素。一个Server元素中可以有一个或多个Service元素。

2. **Service的作用是把Connector和Engine组装在一起对外提供服务。**一个Service可以包含多个Connector，但是只能包含一个Engine；

3. **Connector的主要功能是接收连接请求**，创建Request和Response对象用于和请求端交换数据；然后分配线程让Engine来处理这个请求，并把产生的Request和Response对象传给Engine。

4. Engine组件在Service组件中**有且只有一个**；Engine是Service组件中的请求处理组件。Engine组件从一个或多个Connector中接收请求并处理，并将完成的响应返回给Connector，最终传递给客户端。

5. 虚拟主机Host是Engine的子容器。Engine组件中可以内嵌1个或多个Host组件，每个Host组件代表Engine中的一个虚拟主机。Host组件至少有一个，**且其中一个的name必须与Engine组件的defaultHost属性相匹配**。**Host虚拟主机的作用是运行多个Web应用**（一个Context代表一个Web应用），并负责安装、展开、启动和结束每个Web应用。

6. **Context元素代表在特定虚拟主机上运行的一个Web应用**。在后文中，提到Context、应用或Web应用，它们指代的都是Web应用。每个Web应用基于WAR文件，或WAR文件解压后对应的目录（这里称为应用目录）。

### 核心类

核心类包括：

1. Context类，为当前web应用提供上下文
2. request类，必须实现HttpServletRequest接口，因为这样才能够传递给用户的servlet进行处理
3. response类，实现了HttpServletResponse接口

功能类包括：

1. ServletContext，用于负责当前web应用所有servlet的上下文
2. RequestDispatcher，负责内部转发
3. ServletConfig，负责servlet的参数初始化
4. HttpSession，用于解决http无状态的问题
5. Filter，用于拦截用户请求

难点主要是系统的初始化工作：

### 系统启动时的初始化工作

根据servlet容器的配置文件`server.xml`初始化容器的各个组件，

初始化需要的注意点：

1. 这里采用的是由外到内的初始化各个组件：
    - service启动各个connector，这里采用的方法是将connector包装成一个线程，一直监听目标端口
    - 其中Engine要负责维护一个defaultHost，用来处理没有找到合适host的请求
    - host需要扫描默认目录下（也就是webapps）的所有war包以及文件夹，为每一个应用初始化context
    - 其中context的初始化是核心，通过加载当前web应用的web.xml文件（与tomcat类似，为web应用设置了一个默认的web.xml相对路径（context.xml），一般就是/WEB-INF/web.xml，在配置context，都会配置web应用的虚拟路径和绝对路径映射，只需要将web应用的绝对路径和xml的相对路径拼接起来即可）要负责检查servlet配置（主要是检查url的映射是否重复）、初始化过滤器、初始化所有servlet的初始参数、**初始化当前应用的webappClassLoader**、servletContext以及监听器listener

2. 各个组件必须不能添加到AppClassLoader的classpath中，因为这些组件是需要通过CommonClassLoader来加载的，所以这里的解决办法与tomcat类似，写了个脚本，将这些组件打包成一个jar包，然后让commonCLassLoader负责加载容器的所有jar包，包括自己的和引用的，具体实现是将lib下的所有包都加入CommonClassLoader的classpath路径下。仅让AppClassLoader负责加载启动类和CommonClassLoader

### 启动后基本的工作流程

对于tomcat，一个可以配置多个service，一个service可以配置多个host，一个host可以配置多个context。那么容器定位一个context的流程是：

1. 先通过端口号和协议确定目标service，这样engine也确定了，端口号和协议在connector中配置
2. 再通过host域确定目标主机
3. 最后根据contextpath唯一地确定一个context，也就是一个web应用

那么我对应的具体流程就是：

1. Connector一直监听指定的端口，当socket接受请求后，Connector负责为本次请求分配线程，线程的任务包括：

- 为本次请求构造request与response对象
- 将这两个对象交由HttpProcessor（代理engine）处理，engine的操作包括：
    + 为当前请求准备session、准备过滤器，准备能够处理当前请求的servlet
    + 调用过滤链，最后执行目标servlet
    + 最后根据状态响应码调用对应的处理response对象方法

构造request对象是处理请求的重要一个步骤，包括：

- 读取socket，解析uri、解析请求类型、解析请求参数
- 解析应用上下文context（这里直接通过engine的defaultHost获取当前应用名对应的context），通过当前host维护的contextMap匹配uri
- 解析http头部的信息，例如content-type、压缩类型等等
- 解析cookie

### servlet的声明周期

servlet的完整声明周期包括：初始化单例servlet，servlet提供服务，销毁servlet
首先每个web应用的context池会维护一个servlet池，servlet默认采用懒加载的模式，在使用时不存在对应的servlet对象时，才会利用反射使用初始化参数`ServletConfig`生成对应的实例（初始化）。如果web应用目录下有对应的文件发生修改，那么host会重新加载当前context。在卸载WebappClassLoader时会销毁所有对应的Servlet。

单例Servlet是逻辑上的，仅仅依靠servlet池实现

### cookie与session

对于cookie，我实现的方法是，对于一个response对象，其维护了一个cookie列表，当用户的servlet想添加cookie时，只需往response对象的list中添加即可，最后在生成响应报文时，只需要将cookie添加到响应头中，
一个cookie占一行，对于每一个cookie的格式是：Set-Cookie: name=value;Expires=;Path=;

对于session，engine，首先会查找当前request对象中的cookie有没有对应的session name，我这里维护了一个全局sessionMap，如果map中存在，那么将session提取出来，并重新设置为session服务的cookie过期时间。

对于sessionMap，我提供了一个守护线程负责清除map中过期的session。逻辑很简单，就是判断最后一次访问的时间与当前时间的间隔。对于sessionMap过期的时长，可以在配置文件中设置

### 解析http

仅实现了简单的http请求，首先请求包的布局是：\[请求方法类型] \[请求路径uri] \[http协议版本]，然后接下来每一行都是请求头的一些参数信息，直到出现空白行，空白行之后就是请求体

而http响应包与请求包类似，第一行是：\[http协议版本] \[状态码] \[对状态码的描述]，接下来每一行都是请求头的信息，直到出现空白行，之后就是响应体

主要解析的就是请求方法类型、uri以及请求参数。对于get，会从url中提出请求参数、应用名称、获得uri后，engine会查找对应的servlet进行处理。这里的查找我提供了**三类单例servlet**负责提供用户访问的servlet对象并调用。三类分别是：

- 处理普通的servlet
- 处理jsp对应的servlet
- 处理静态资源

## 重定向与内部跳转

如果用户调用了sendRedirect设置重定向路径时，engine会设置状态响应码为302，最后在传输response对象时，会检查它的状态码，如果为302，会向客户端发送302的http数据包

跳转传参我实现的方法是，在request对象中维护了一个attributeMap，我们只需要将属性添加这个map，然后将request对象在不同的servlet进行传递即可。

内部跳转就是使用request生成一个RequestDispatcher对象，并在该对象中设置跳转路径，然后调用dispatcher对象forward进行内部跳转，具体的处理方法就是首先需要重新设置request对象的uri，然后直接转发给engine组件来处理请求，engine会根据uri匹配对应的servlet

## 过滤器

对于一个请求的过滤器，我们需要维护一个filterChain用来存储当前uri匹配的所有filter，依次执行chain中的所有过滤器，最后filterchain会执行我们的目标servlet

## 编译Servlet

编译servlet也比较麻烦，这也是个难点，**后续值得关注**

## 自定义类加载器

CommonClassLoader、WebappClassLoader、JspClassLoader，这里将commonCLassLoader设置为线程上下文类加载器，这样每当为web应用生成classloader时，就可以将commonclassLoader设为它的逻辑父类。

对于这些自定义类加载器，一种比较简单的实现方法就是继承URLClassLoader，

## 动静态部署

监控默认目录，如果有新的war包存在，那么将加载任务分派给host

## 可以改进的地方

1. 接受用户处理的流程可以改进，因为采用的是线程池的模式

首先socket的read是阻塞函数，write是阻塞函数

线程池的execute会抛出异常，但会直接终止线程
而submit不会抛出异常

先扫描生成ContextMap

字符串排列

## 哪些功能没有实现？

tomcat的用户权限认证没有实现，集群设置没有实现，servlet的wrapper没有实现，直接调用的servlet

## 如何理解测开？

测开其实可以分为两个部分：测试和开发

对于测试的话：就是常规意义上的功能测试，首先第一步就是需求分析阶段，了解需要测试什么；第二部是设计测试用例，这一步的目的是达到怎么测；第三步是进行具体测试，这一步是找到具体的bug；最后一步是总结修复

对于开发的话，我认为主要是完成自动化测试与测试工具的开发

## tomcat有哪些IO模型？

Tomcat支持三种接收请求的处理方式：BIO、NIO、APR 。

BIO
阻塞式I/O操作即使用的是传统 I/O操作，Tomcat7以下版本默认情况下是以BIO模式运行的，由于每个请求都要创建一个线程来处理，线程开销较大，不能处理高并发的场景，在三种模式中性能也最低。

NIO
NIO是Java 1.4 及后续版本提供的一种新的I/O操作方式，是一个基于缓冲区、并能提供非阻塞I/O操作的Java API，它拥有比传统I/O操作(BIO)更好的并发运行性能。tomcat 8版本及以上默认就是在NIO模式下允许。

APR
APR(Apache Portable Runtime/Apache可移植运行时)，是Apache HTTP服务器的支持库。你可以简单地理解为，Tomcat将以JNI的形式调用Apache HTTP服务器的核心动态链接库来处理文件读取或网络传输操作，从而大大地提高Tomcat对静态文件的处理性能。 Tomcat apr也是在Tomcat上运行高并发应用的首选模式。