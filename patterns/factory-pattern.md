---
title: 工厂模式扫盲
index_img: 
date: 2021-06-09 19:51:05
intro: 本文将对网上几种常见的工厂模式进行简单总结，最后阐述了工厂方法与抽象工厂的区别。
tags:
- factory
categories:
- design patterns
---


工厂模式基本上可分为四种种：静态工厂模式、简单工厂模式、工厂方法模式以及抽线工厂模式。本文将对这四种设计模式进行了简单介绍。

## 1. 为什么需要工厂模式

这个问题的答案很容易想到，工厂模式是为了将对象的使用与创建这两个步骤分开，实现代码的解耦，不然一个很明显的问题就是如果我们修改了对象的创建方法，那么需要修改的地方将无法想象。工厂模式避免了这一窘境。

## 2. 静态工厂模式

静态工厂模式比较简单，基本定义为：一个类中的方法根据不同的参数返回不同的实例，不过一般是一个单独的类来定义这个唯一的方法，demo代码如下：

``` java
class UserFactory {
    public static function create(String type) {
        switch (type) {
            case 'user': return new User();
            case 'customer': return new Customer();
            case 'admin': return new Admin();
            default:
                throw new Exception('Wrong user type passed.');
        }
    }
}
```

但是该模式的缺点就是如果产品类非常多，那么条件判断是一件非常麻烦的事，而且代码十分臃肿。我认为该模式适用于产品类较少的情况。

## 3. 工厂方法模式

根据我的探索，工厂方法有两种版本：

1. 经典版本，由GOF定义
2. 无名氏版本

首先工厂方法模式（factory method）的[经典定义](https://en.wikipedia.org/wiki/Factory_method_pattern)如下（GOF版本）：

{% note info %}
"Define an interface for creating an object, but let subclasses decide which class to **instantiate**. The Factory method lets a class defer instantiation it uses to subclasses."
{% endnote %}

大意是指通过“接口”创建对象，但是具体的创建过程交由继承的子类来实现。定义很抽象，我们通过[jaco0646](https://stackoverflow.com/a/50786084)提供的demo来了解一下：

``` java "factory method"
public abstract class Creator {
    public void anOperation() {
        Product p = factoryMethod();
        p.whatever();
    }
    //factory method
    protected abstract Product factoryMethod();
}

public class ConcreteCreator extends Creator {
    @Override
    protected Product factoryMethod() {
        return new ConcreteProduct();
    }
}
```

上述代码中，抽象类“Creator”调用了自己的定义的工厂方法“factoryMethod”，但是方法具体的实现交给了子类“ConcreteCreator”，子类实现的工厂方法返回的是一个具体产品，很标准地实现了上述定义，但是美中不足是没有使用“interface”。[jaco0646](https://stackoverflow.com/a/38668246)给出了回答：

{% note info %}
First, we must note that neither Java nor C# existed when the GoF wrote their book. The GoF use of the term interface is unrelated to the interface types introduced by particular languages. Therefore, the concrete creator can be created from any API. The important point in the pattern is that **the API consumes its own Factory Method**, so an interface with only one method cannot be a Factory Method any more than it can be an Abstract Factory.
{% endnote %}

大意是指因为时代原因，GOF中的“interface”和具体语言中“interface”完全不同，我们可以通过任何形式的API使用工厂方法，但是需要注意该API必须消费自己的工厂方法。可能熟悉设计模式的同学发现，这就是模板方法啊，你到底懂不懂啊？很巧，我在[jaco0646](https://stackoverflow.com/a/50786084)的回答中又发现了答案：

{% note info %}
The Factory Method Pattern is nothing more than a specialization of the Template Method Pattern. The two patterns share an identical structure. They only differ in purpose. Factory Method is creational (it builds something) whereas Template Method is behavioral (it computes something).
{% endnote %}

大意是说工厂方法与模板方法的区别很微妙，前者是创建型方法（指创建具体的实例），而后者是行为型方法（指完成逻辑功能）。

上述是我了解的经典工厂方法，而无名氏版本是由抽象工厂、具体工厂、抽象产品、具体产品四类元素组成组成，demo如下所示：

``` java
//抽象产品
public interface Product{
    public void shape();
}
//具体产品
public class ConcreteProduct implements Product{
    @Override
    public void shape(){
        ...
    }
}
//抽象工厂
public interface Creator{
    public factoryMethod();
}
//具体工厂
public class ConcreteCreator implements Creator {
    @Override
    protected Product factoryMethod() {
        return new ConcreteProduct();
    }
}
```

其实这种版本应该没啥问题，但是当我学习抽象工厂模式时，我陷入了疑惑。

## 4. 抽象工厂模式

抽象工厂模式的[GOF定义](https://en.wikipedia.org/wiki/Abstract_factory_pattern#Definition)如下所示：

{% note info %}
The essence of the Abstract Factory Pattern is to "Provide an interface for creating families of related or dependent objects without specifying their concrete classes."（通过“接口”创建相关的系列产品，但是并不声明如何创建）
{% endnote %}

这里还是拿来主义，[jaco0646](https://stackoverflow.com/a/50786084)提供的demo如下所示：

``` java
public class Client {
    private final AbstractFactory_MessageQueue factory;

    public Client(AbstractFactory_MessageQueue factory) {
        // The factory creates message queues either for Azure or MSMQ.
        // The client does not know which technology is used.
        
        // inject AbstractFactory to Client 
        this.factory = factory;
    }

    public void sendMessage() {
        //The client doesn't know whether the OutboundQueue is Azure or MSMQ.
        OutboundQueue out = factory.createProductA();
        out.sendMessage("Hello Abstract Factory!");
    }

    public String receiveMessage() {
        //The client doesn't know whether the ReplyQueue is Azure or MSMQ.
        ReplyQueue in = factory.createProductB();
        return in.receiveMessage();
    }
}

public interface AbstractFactory_MessageQueue {
    OutboundQueue createProductA();
    ReplyQueue createProductB();
}

public class ConcreteFactory_Azure implements AbstractFactory_MessageQueue {
    @Override
    public OutboundQueue createProductA() {
        return new AzureMessageQueue();
    }

    @Override
    public ReplyQueue createProductB() {
        return new AzureResponseMessageQueue();
    }
}

public class ConcreteFactory_Msmq implements AbstractFactory_MessageQueue {
    @Override
    public OutboundQueue createProductA() {
        return new MsmqMessageQueue();
    }

    @Override
    public ReplyQueue createProductB() {
        return new MsmqResponseMessageQueue();
    }
}
```

其中“AbstractFactory_MessageQueue”作为抽象工厂，定义了两个创建产品的方法“createProductA()”、“createProductB()”。具体的实现交给抽象工厂的“继承者”具体工厂。该模式单独很好理解，但是与无名氏版工厂方法模式放在一块，就非常迷惑了？不免提出几个问题：

1. 工厂方法模式到底哪一版才是对的？
2. 无名氏版工厂方法模式算是一种设计模式吗？
3. 经典工厂方法与抽象工厂的区别到底是什么？

对于第一个问题，我暂时还没有找到答案，我目前比较认同第一种版本，即GOF版本，因为我认为无名氏版本实质与抽象工厂没有区别。

对于第二个问题，我貌似找到了一个答案：

{% note info %}
an interface with only one method cannot be a Factory Method any more than it can be an Abstract Factory, what do we call a creational interface with only one method?

**Answer:**
If the method is static, it is commonly called a Static Factory. If the method is non-static, it is commonly called a Simple Factory. Neither of these is a GoF pattern, but in practice they are far more commonly used!
{% endnote %}

对于第三个问题，网上有了比较明确的回答，我这里仅作简单摘要，因为内容较长，单独成为一节。

## 5. 传统工厂方法与抽象工厂的区别

针对[jaco0646](https://stackoverflow.com/a/50786084) demo中的代码，他提出以下内容：

对于抽象工厂，我们需要知道：

（1）抽象工厂最重要的一点是它会被注入“Client”代码，这也就是为什么我们说抽象工厂是由组合实现，例如demo中“AbstractFactory”被注入了“Client”的代码，这也就是抽象方法被称由组合实现的原因。
{% note info %}
The most important point to grasp here is that the abstract factory is injected into the client. This is why we say that Abstract Factory is implemented by Composition. Often, a dependency injection framework would perform that task; but a framework is not required for DI.
{% endnote %}

（2）抽象工厂的实现类并不是所谓的工厂方法。

（3）抽象工厂中的家族产品是指各个产品间在逻辑上具备关联，而不是指代码实现中具备继承关系。

对于工厂方法模式，我们需要知道：

（1）在demo中，工厂方法模式中的“Client”是指“ConcreteCreator”，“Client”的父类定义了工厂方法，这就是我们称工厂方法是由继承实现的原因。
{% note info %}
The most important point to grasp here is that the ConcreteCreator is the client. In other words, the client is a subclass whose parent defines the factoryMethod(). This is why we say that Factory Method is implemented by Inheritance.)
{% endnote %}

（2）工厂方法模式与模板方法模式并无太大区别，前者是创建型方法，后者是行为型方法。

（3）我认为这点是传统工厂方法模式与抽象工厂最大的区别。在demo代码中父类“Creator”消费了自己的工厂方法“factoryMethod()”，如果将代码中的“anOperation()”删除，那么就不再是一个传统的工厂方法。
{%note info %}
And finally, the third point to note is that the Creator (parent) class invokes its own factoryMethod(). If we remove anOperation() from the parent class, leaving only a single method behind, it is no longer the Factory Method pattern. In other words, Factory Method cannot be implemented with less than two methods in the parent class; and one must invoke the other.
{% endnote %}

如果仔细阅读了上面的内容，相信大家已经知道了GOF版本的工厂方法与抽象工厂的区别。核心就是**工厂方法模式主要通过继承来实现，会消费自己定义的工厂方法。而抽象工厂模式主要通过组合与代码注入来实现**。

## 6. 各种工厂模式的适用场景

1. 对于简单工厂，一般适用于产品类较少，各个产品构造简单时适用。
2. 对于传统工厂方法模式，如果不知道子类是如何创建对象或者需要子类客制化创建过程，那么使用它
3. 对于抽象工厂模式，一般用来创建一系列配套的产品共同使用

## 参考文章

1. [Design Patterns: Abstract Factory vs Factory Method](https://stackoverflow.com/a/38668246/12893742)

2. [Factory Pattern. When to use factory methods?](https://stackoverflow.com/a/30465141/12893742)
