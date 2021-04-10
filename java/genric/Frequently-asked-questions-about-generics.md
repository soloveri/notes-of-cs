---
title: 关于泛型的常见问题
mathjax: true
data: 2020-08-14 20:59:33
updated:
tags:
- 泛型
categories: 基础
---

## 前言

这里罗列一些关于泛型的常见问题,并给出解答。其中本篇大多数问题来自[Java Generics FAQs - Generic And Parameterized Types](http://www.angelikalanger.com/GenericsFAQ/FAQSections/ParameterizedTypes.html),我这里仅翻译一些我认为比较容易糊涂的问题。

当然,在解答这些问题时,我们需要牢记一个概念,通配符`?`表示的是不知道是什么类型,而不是任意类型。

- 泛型类型:`class test<T>{}`
- 具体参数类型:`class test<String> t1=null;`
- 泛型参数类型:`test<?> t2=null;`

## 1. 使用通配符时经常出现的capture#XXX of ? 到底什么意思?

在使用通配符时,我们很有可能会遇到类似`capture#337 of ?`这样莫名奇妙的错误。其中`capture`是捕获的意思,捕获的是通配符`?`,那么`#337`又代表着什么?这一切都要从捕获转化(Capture Conversion)开始说起。

让我们思考一个问题,如果我们定义定义一个泛型类C如下(类似于List容器)如下:

``` java
class C <T extends Number>{
    ...
    T get();
    void add(T)
}

C<?> c=new C<Integer>()
```

那么通过`c`调用对象方法时,方法的签名是什么样的?像下面这样?(编译时期泛型还是存在的)

``` java
class C <? extends Number>{
    ...
    ? get();
    void add(?);
}
```

这显然是毫无意义的,但是我们知道实例化类时一定会使用一个具体的类型X\:\< Number( **:<** 表示前者继承于后者),尽管我们不知道这个X到底是什么类型的。这并不重要。那么被具体类型X实例化的类C长下面这样:

``` java
class C<X>{//X:<Number
    ...
    X get();
    void add(X);
}
```

使用一个具有名字的类型比使用通配符`?`容易多了。所以编译器也是这么做的。只不过编译器并不会使用`X`,而是随机使用一个数字,例如`#337`表示上面这个通配符。所以才会有了这句`capture#337 of ?`。即编译将遇到这个统配符`?`分配了一个名字叫做`#337`。

当一个`value`的类型是通配符类型,编译器会使用类型变量替换这个`value`种存在的通配符`?`(类型变量中的数字按序增长),这种操作名为`capture conversion`,通过这个操作,编译器只需要处理带有具体类型的对象。

对于上面的例子,`get()`方法返回一个`X`类型的引用,其中`X:<Number`,那么我们就可以执行下述操作:
>Number n= c.get();//c为类C的实例,get方法返回的是Number类型

但是我们却不能向c中添加元素。

> c.add(number)//add方法接受的参数为类型为capture#1 of ?

因为add方法接受的参数类型为x(编译器的名字可能为capture#1 of ?),而容器c中的引用至少都为Number类型,因为容器内的元素类型都有一个限制:`? extends Number`,所以编译器出于安全,将容器内的引用推断为`Number`类型肯定是不会错的。
那么一个存储`Number`类型的容器,能接受一个类型为`capture#1 of ?`的值吗?不知道,因为后者的类型编译器无法推断,所以为了保险起见,直接会产生编译错误。

只要有表达式产生了`wild type`的**value**(The compiler applies capture conversion on every expression that yields a value in wild type),`capture conversion`操作就存在。并且会为每个通配符`?`分配一个唯一ID。以下面代码为例:

``` java
List<? extends Number> foo(List<? extends Number> numberList)
{
#1  for(Number number : numberList)
#2      assert numberList.contains(number);
#3  numberList = numberList;
#4  return numberList;
}
```

上面代码有四个地方都存在`wild type`的变量,我们一个一个来分析。

对于`#1`处的`numberList`,其类型为`List <? extends Number>`,那么会将这处的`numberList`转换为`List<X1>`类型,`List<X1>`是`Iterable<X1>`的子类,所以可以使用for循环遍历,number的类型是`X1`,又因为`X1:<Number`,所以其可以向上转型为`Number`

对于`#2`处的`numberList`,编译器会将其类型转换为`List<X2>`类型,其中的`contains`方法是`List<X2>`类型下的`contains`方法,所以该方法接受一个`X2`类型的参数

对于`#3`处的右`numberList`,编译器会将其类型转换为`List<X3>`,但是！！！对于左边的`numberList`,因为其是一个variable,而不是一个value,所以编译器不会对其类型进行转换,还是`List<? extends Number>`,将`List<X3>`类型赋值给`List<? extends Number>`类型是合法的,因为`X3:<Number`。
**那么是否可以认为左侧的都是variable,而右侧的是value???** 或者是否可以这样理解:右边的变量`numberList`把它的value赋值给了左侧的`numberList`,而这个value是`wild type`？或者说用的时候实际上使用的实际上是variable的value?

对于`#4`处的`numberList`,编译器同样会转换为`List<X4>`后返回。

上面的转换规则非常重要,我们再来看一个难一点的例子。现在有一个map,类型为`Map<?,?> map`,那么如果进行如下操作是合法的:

``` java
for(Entry<?,?> entry : map.entrySet())
```

因为`map`会被转型为`Map<X1,X2>`类型,那么返回的entrySet就是`Set<Entry<X1,X2>>`,因为`X1<:?`,`X2<:?`,所以将`Entry<X1,X2>`类型赋值给`Entry<?,?>`类型是合理的。但是下面的操作就非法了

``` java
Set<Entry<?,?>> entrySet = map.entrySet(); // compile error
```

很简单,错误原因是因为泛型不是协变的,`Set<Entry<X1,X2>>`不是`Set<Entry<?,?>>`的子类。比较笨拙的办法是在定义一个`wild type`,如下所示:

``` java
Set<? extends Entry<?,?>> entrySet=map.entrySet();
```

其实还有一个比较取巧的办法,通过名为`capture helper`的操作来解决这个问题。

### 1.1 Capture Helper

因为编译器对于`wild type`的取名都是任意的,并且对我们是不可见的,所以我们在源码中无法引用,以下面的代码为例:

``` java
void bar(List<? extends Number> numberList)
{
    // numberList.add( numberList.get(0) ); // compile error,因为左numberList接受的是X2类型,而又numberList接受的是X1类型

    //假设下面的代码存在,我们将传进来的numberList转型为List<X>类型,那么该方法所有使用numberList的地方,其类型是List<X>
    //而不是见一个numberList换一个类型
    List<X> list = numberList;  // *imaginary* code

    X number = list.get(0);     // get() returns X
    list.add(number);           // add() accepts X
}
```

既然人为定义`wild type`的类型,可行,那么我把类型`X`定义出来不久好了?如下面代码所示:

``` java
<T extends Number> void bar2(List<T> list)
{
    T number = list.get(0);
    list.add(number);
}
```

然后我们就可以调用`bar(numberList)`解决上面每个`numberList`类型不一样的问题。方法`bar2`就叫做`capture helper`。

那么`capture helper`的出现有什么意义呢?
答案是为了兼容老代码,因为1.5之前的代码没有泛型,如果使用泛型的代码想要接受没有泛型的容器,就得实现`capture helper`(当然不局限于容器,这里容器比较典型)

**参考文献:**

1. [Capturing Wildcards](http://bayou.io/draft/Capturing_Wildcards.html#Capture_Everywhere)

2. [Wildcard Case Studies](http://bayou.io/draft/Wildcard_Case_Studies.html#Map&lt;?,?&gt;_Entry_Set)

## 2. \<? extends E>与\<T extends E>有什么区别?

这是容易搞混的一点,首先`T`叫做类型变量(type variable),`?`叫做通配符(wildcard)。

1. 类型变量不能使用`super`,即类型变量不能有上界,例如`T super E`,这样是非法的。至于为什么非法可以看下一个问题。但是通配符`?`却可以有上界或者下界。

2. 类型变量可以有多个限制,例如`T extends A & B`,但是通配符**至多**有一个界限。

3. 通配符不能表示一个类型变量,所以通配符不能用来定义`generic type` ,类型变量可以用来定义`generic type`

**参考文献:**

1. [What is difference between <? extends Object> and <E extends Object>?](https://stackoverflow.com/questions/18384897/what-is-difference-between-extends-object-and-e-extends-object)

## 3. \<T super E>为什么是非法的?

因为Object所有引用类型的父类。<T super E>并不会按照我们的想法工作。例如我们定义了一个容器`ArrayList<Integer> list`,思考下面的代码是否意义:

``` java

//add方法是list的对象方法
public <T super Integer> void add(T){
    list.add(T);
}

ArrayList<Integer> list=new ArrayList<>();
list.add(1);//正常,没有任何问题
lsit.add("aaa");//我们的本意是这句不该通过编译,但是却通过了
```

`add`方法的本意是接受类型是`Integer`的参数,可以是`Object`、`Number`、`Integer`,不应该接受`String`类型。

但是`Object`也是`String`的父类。很有可能给`add`传入的参数静态类型是`Object`,动态类型是`String`。虽然放进去是没有问题,但是如果把这个`String`类型的元素取出来,会出现`castException`,因为`String`根本不可能转换为`Integer`。

**参考文献:**

1. [Bounding generics with 'super' keyword](https://stackoverflow.com/questions/2800369/bounding-generics-with-super-keyword)

## 4. 为什么定义类型参数时不能使用通配符'?'?

因为通配符`?`只是用来定义`wild type`的一个语法成分,它没有任何语义,**它不能表示任何类型**。想象一下,如果下面的代码是合法的:

``` java
class List<?>{
    ? get(int index){}
    void add(? elem){}
}
```

在前面曾经说过,由于`capture conversion`的原因,编译器会把每一个类型是`wild type`的value中的通配符`?`赋一个名字,例如像下面这样:

``` java
class List<X1>{
    X2 get(int inedx){}
    void add(X3 elem){}
}
```

那么我们在实例化List的时候,像`List<String>`这样?那么`get`的返回值类型又是什么?这样就违背了我们使用`?`定义泛型类的初衷。我们的本意是`List`接受一个不知道是什么类型的类型参数(unkown type),并且想要`get`的返回值类型也是同一个`unknown type`。但是这很显然不可能。

**所以通配符`?`就不能用来定义一个类型变量(type variable),它只能用在类型声明的地方**,例如声明方法的形参类型,声明一个变量。因为 **?不是一个有效的变量名,不是一个有效的标识符**:

>You can't name a generic parameter as ?, because ? is not a valid identifier - a valid name of a variable. 
You have to give a generic parameter a valid java name so you can refer to it in the implementation.

下面是通配符常用的地方:

``` java
List<?> list;//ok,声明变量类型
void add(List<? extends Number> list);//ok,声明参数类型
```

那么所谓的定义一个泛型类型是什么?就像下面这样:

``` java
    List MyList<T>{//定义了一个泛型类型MyList<T>,T是类型变量

    public <V> void add(V num,T test){}//定义了一个类型变量V
    public <?> void get();//compile error
}
```

并且统配符`?`只能用来填充类型变量。所谓的填充是什么意思,比如我们定义了一个方法接受`MyList<T>`泛型的方法,那么我们就可以用`?`填充这个T。那么填充在哪?

- 声明方法的参数
- 声明变量

如下所示:

``` java
//定义方法时声明参数,使用?填充T
public void test(MyList<?> myList){}
//或者加个界限
public void test(MyList<? extends Number> myList){}
//定义了一个MyList<T>的变量,使用?填充T
MyList<?> myList;//
```

**参考文献:**

1. [java Generic wildcard “?”](https://stackoverflow.com/questions/24740590/java-generic-wildcard?rq=1)
2. [夯实JAVA基本之一——泛型详解(2)：高级进阶](https://blog.csdn.net/harvic880925/article/details/49883589)

## 5. 有没有不能使用泛型的地方?

几乎所有类型都可以拥有类型参数,但除了一下几种类型:

- 枚举类型:因为枚举类型不能有类型参数,所以枚举类中的值都是静态类型的,但是又因为**类型参数不能用于任何静态的上下文环境**,所以在枚举类中使用泛型是没有任何意义的
- 匿名内部类:它可以继承一个参数化类型的类或者接口,但它本身不能是，因为**匿名内部泛型类没有任何意义**。因为匿名内部类没有名字,所以在声明时就没有地方提供类型参数
- 异常类:一个泛型类不能间接或者直接继承自`Throwable`接口,因为异常处理机制是一种运行时机制,但是在运行时泛型已经被擦出了。所以对于同一个泛型类型但是类型参数不同的两个参数化类型来说,虚拟机并不能区分它们,所以异常泛型类也是无意义的。


## 6.能不能强转成参数化类型?

可以,但是这种操作是类型不安全的,且会产生"unchecked"的编译警告。

因为一个变量的类型分为静态类型与动态类型。一个类型转换操作也分为两个部分:

- 编译时期的静态类型检查
- 运行十七的动态类型检查

静态时期的类型检查去除了一些显而易见的错误,例如讲`String`转换成`Date`。而动态类型检查使用了动态类型进行检查。如果动态类型不是目标类型或者不是目标类型的子类(也就是所谓的向下转型),那么就会产生`ClassCastException`。

但是并不是所有类型转换都会动态类型检查。基本类型之间的转换仅会进行静态类型检查。并且向上转型也只会进行静态类型检查,向上转型不写也没关系,因为编译器会帮你做这件事。

**需要动态检查**的类型转换潜在是类型不安全的,尤其是当目标类型为一个参数化类型。在运行时参数化类型的类型信息不在存在,虚拟机不能区分两个是同一个泛型,但是采用不同的类型参数实例化出的参数化类型,所以在这种情况下,本不该通过动态检查的类型转换却通过了,这不是我们希望看到的。例如下面的代码,将`Object`转换为`List<String>`,但是却没有抛出`ClassCastException`.

``` java
void m1() {
  List<Date> list = new ArrayList<Date>();
  ...
  m2(list);
}
void m2(Object arg) {
  ...
  List<String> list = (List<String>) arg;    // unchecked warning
  ...
  m3(list);
  ...
}
void m3(List<String> list) {
  ...
  String s = list.get(0);      // ClassCastException
  ...
}
```

注意上面抛出异常的位置,不是在我们进行类型转换的位置,而是在我们提取元素的时候。这种没有在正确地方抛出的异常是我们非常不愿意看到的。所以为了引起我们对这种潜在的类型不安全的转换注意,编译器产生了"unchecked"警告在遇到可疑的转换时。

所以,**编译器在每一处目标类型是参数化类型并且是向下转型的地方,都会产生一个unchecked警告**。

## 7.泛型中哪里会出现的"unchecked"警告?

1. 首先就是上面一个问题所说的:向下转型为参数化类型的地方。

2. 如果方法的参数类型没有因为类型擦除而改变,那么调用这个方法就是类型安全的

3. 如果字段的类型因为类型擦除而改变,那么对该字段赋值就会产生"unchecked",但是读取该字段的值却不会产生任何问题

## 8. unbound wildcard parameterized type和raw type有什么区别?

其实这二者没有太大区别,二者都可以被视作是任何参数化类型的超级类,并且二者都是`reifiable types`。所以这两种类型可以作为数组的元素类型(注意是unbound wildcard而不是wildcard)。但是编译器对`unbound wildcard parameterized type`更严格。对于同样的操作,如果`raw type`产生了`unchecked`警告,那么`unbound wildcard parameterized type`则会产生编译错误。

## 9. 泛型真的不能使用instance of吗?

大部分都不行,只有无界通配符可以,因为只有`reifiable type`能够使用`instance of`,`reifiable types`包括且只包括:

- It refers to a non-generic class or interface type declaration.

- It is a parameterized type in which all type arguments are **unbounded** wildcards (§4.5.1).

- It is a raw type (§4.8).

- It is a primitive type (§4.2).

- It is an array type (§10.1) whose element type is reifiable.

- It is a nested type where, for each type T separated by a ".", T itself is reifiable.

## 10. 能创建数组元素是具体参数化类型的数组吗?

所谓的具体参数化类型就是类型参数是一个具体的参数,例如`String`、`Integer`等等。对于这个问题的答案是不能,因为是类型不安全的。

因为插入操作会逃过数组的动态类型检查,见如下代码:

``` java
static void test() {
  Pair<Integer,Integer>[] intPairArr = new Pair<Integer,Integer>[10] ; // error
  addElements(intPairArr); 
  Pair<Integer,Integer> pair = intPairArr[1];
  Integer i = pair.getFirst();
  pair.setSecond(i);
}
static void addElements( Object[] objArr) {
  objArr[0] = new Pair<Integer,Integer>(0,0);
  objArr[1] = new Pair<String,String>("","");      // should fail with ArrayStoreException,但是因为在运行时泛型已经不存在了
                                                  //  逃过了数组插入时的类型动态检查
}

```

## 11. 能创建数组元素类型是通配符参数化类型的数组吗?

无界通配符可以,有界通配符不行。因为有界通配符的插入操作也可以逃过数组插入时的动态类型检查,而无界通配符不会。

``` java

//非法操作
Object[] numPairArr = new Pair<? extends Number,? extends Number>[10]; // illegal
numPairArr[0] = new Pair<Long,Long>(0L,0L);     // fine
//注意,下面这句逃过了数组的动态类型检查
numPairArr[0] = new Pair<String,String>("",""); // should fail, but would succeed

//合法操作
Object[] pairArr = new Pair<?,?>[10] ;        // fine
pairArr[0] = new Pair <Long,Long>(0L,0L);     // fine
pairArr[0] = new Pair <String,String>("",""); // fine 
pairArr[0] = new ArrayList <String>();        // fails with ArrayStoreException
```

## 12. 能创建数组元素是有界通配符参数化类型的数组引用吗?

可以,但没必要。

``` java
//创建了数组元素类型是有界通配符类型的数组

Pair<? extends Number,? extends Number>[] arr = null;

class Point extends Pair<Double,Double> { ... }
Pair<? extends Number,? extends Number>[] arr = new Point[2];
arr[0] = new Point(-1.0,1.0);  // fine
//虽然能通过静态类型检查,但是无法通过数组的动态类型检查
arr[1] = new Pair<Number,Number>(-1.0,1.0); // fine (causes ArrayStoreException)
arr[2] = new Pair<Integer,Integer>(1,2); // fine (causes ArrayStoreException)
```

## 13.通配符参数化类型不能干嘛?

不能做父类。见如下代码:

``` java
class MyClass implements Comparable <?> { // error
  public int compareTo( ??? arg) { ... }
}
```

编译器无法知道`comapreTo`方法到底接受的是什么类型的参数,很奇怪。而且,如前面所说,因为有`capture conversion`操作,这样的定义是没有任何意义的。

## 15. 具体化参数类型不能做什么?

具体化参数类型(concrete parameterized type)就是使用具体类型实例化泛型类型的类型。那么它不能做:

1. 使用`instance of`
2. 不能创建数组
3. 不能用于异常处理(泛型都不行)

## 14. 泛型不能做什么?

1. 不能在静态字段中使用类型参数(type paramemter):**因为type parameter不适用于静态上下文环境**,所以泛型不能适用于静态泛型字段,例如`static T member`、`static List<T> list`
2. 不用如此使用：`obj instanceof T`，因为类型擦除的原因



**参考文献:**

若非特殊标注,问题引自[Java Generics FAQs - Generic And Parameterized Types](http://www.angelikalanger.com/GenericsFAQ/FAQSections/ParameterizedTypes.html#FAQ001)
