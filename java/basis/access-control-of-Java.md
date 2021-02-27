---
title: 思考java中的访问控制
mathjax: true
data: 2020-04-10 01:08:14
updated:
tags:
- 访问控制
categories:
- java
---

java中权限修饰符作用于两个地方，一个是类，另一个是类的成员。下面将分别详细讲解。

## java中的类权限修饰符

在讲解类的权限的修饰符前，我们需要明确一个概念。在java中，任何可执行的语句都必须**放在一个类中的方法**，比如调用方法。不像c++，在类外也能定义函数，在java中，我们say no。不管你是创建别的类的对象，还是创建方法，成员，等等，这都必须放在一个类中。

java中的类只能有两种权限修饰符：`public`和默认的包权限，即什么都不写。

这里的类的访问控制是指在包A中能否使用导入的包B中的类。对于public类，就是放开了，只要导入public class所在的包，就能使用该类。而包权限的类是只能在所定义的包中使用，也就是所谓的包权限，例如class A所在的包为A。在包B中导入了包A，也就是把A中的所有类导入了包B然后使用，这里注意使用的地方是在包B，包A的包权限类只能在所定义的包A中使用。**这里的使用指的是能够解析类名**，至于能不能创建具体的对象是另外一回事。

## java中的成员权限修饰符

能修饰成员的权限描述符为：`public`、`private`、`protected`和包权限。这里有一个前提：
访问类的成员和方法的前提是能够访问该类！所以不同包下的包权限类中的成员设置成什么权限都无所谓。使用权限修饰符成员是为了隔离同一包下的类和不同包的public类。

成员修饰符的存在是为了什么？是为了阻止在**不同类**下访问不该访问的东西。什么意思？也就是说，即使类把自己的数据成员私有化，在自己类中创建自己的对象时仍能够访问类的私有数据成员。l例如下面的代码：

``` java
public class Cat {
	private String name;
	private int age;
    //protected static int c;
	public static void main(String[] args) {
		show();
        //输出为10tim
	}
	public Cat(String name, int age) {
	super();
	this.name = name;
	this.age = age;
    }
	static void show() {
		Cat cat=new Cat("tim",10);
		System.out.println(cat.age+cat.name);
	}

}
```

上述代码仍能够正常运行，即使Cat类的`name`、`age`都是私有化的，但是对象`cat`仍能访问。所以我们可以得出一个结论：能否访问类的成员关键在于我们是在哪访问。在类本身中我们可以访问一切属于该类的资源。比如上述代码中的`cat`对象。

所以接下来理解成员的四种访问权限修饰符就很容易了。

**private**

对于private成员，只要出了成员被定义的类，那么我们就不能访问。

**包权限**

对于包权限的成员，只要在同一包下，无论是在成员被定义的类中，还是在同一包下的其他类都可以访问。

**public**

在任何类下都可随意访问，但是前提是：能否访问public成员所在的类，否则一切都是白搭。

**protected**

对于`protected`，这个是包权限的增强版。被`protected`修饰的成员，只要在同一包下就能访问，不管是不是在成员被定义的类中。这一点与包权限相同。增强是增强在在不同包下的子类。

当在不同包下时：如果是非子类，只能访问public成员。如果是子类，则能访问protected成员。这里的能访问指的是什么？

对于protected的成员函数，指的是**在子类中**子类有资格去访问、重写这个父类的protected函数。注意访问、重写是在**子类**中,而不能在别的类中。在别的类中，不管是通过子类对象，还是父类对象，都不能访问protected成员。下面的代码给出了一个很好的栗子。

``` java
public class Dog extends Cat {
	public void show3() {
		Dog d=new Dog();
        //编译成功，因为是在子类本身中，这里的父类指的Object类
		d.clone();
	}
}
class lion{
	public void show5() throws CloneNotSupportedException {
		Dog d=new Dog();
        //编译失败，在其他类中就不能访问Dog类中的protected成员了
		d.clone();
	}
}

```

如果在子类中重写了父类的protected函数，在其他类中又可以通过子类的对象来访问，这是为什么？

因为你一旦在子类中重写了父类的protected成员函数，在子类中就显示有了自己的protected函数，那么在一个包下的其他类当然可以访问本包内的所有protected成员。对应的如果类B与子类又不在同一包内，仍然不能访问子类的proteced函数。

简而言之，记住一句话，就可以通杀这些问题：

> 权限修饰符是**针对类的、针对类的、针对类的**！而不是针对对象的。重要的话说三遍。



