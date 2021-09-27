---
title: Java中的类型系统
mathjax: true
date: 2020-08-07 21:36:24
updated:
excerpt: 本文简要介绍了Java中反射使用的类型系统，包括一些基本概念
tags:
- 类型
categories: Java
---

## 前言

java的类型系统在1.5之后就变的很复杂了。但是又极其重要因为java中的反射基于此。所以想要深入理解反射还需要简单地学习一下java的类型系统。首先我们简要说明一下在逻辑上java的type分类。然后再在实现层次上简要了解一下java到底是如何实现的。

首先java是一个强类型语言,其任何一个变量、任何一个表达式都有类型。在Java中,总的分为~~两类~~三类(还有一个特殊的`null type`):

- primitive types:原始类型,分类`boolean type`和`numeric type`,后者又可以分为`integral types`和`floating-point types`。
  - integral types:包括`byte`、`short`、`int`、`long`、`float`、`char`
  - floating-point type:包括`float`和`double`
- reference types:包括`class types`、`interface types`、`array type`以及`type virables`
- special type:`null type`

>在java中,对象是类的实例或者是动态创建的数组,[参考文献](https://docs.oracle.com/javase/specs/jls/se8/html/jls-4.html#jls-4.3)

是的,数组也是一个对象。

---

**Extension：**

这里额外说一下`null type`,关键字`null`不是一个类型而是一个特殊的值,可以简答的认为null指向一个特殊的内存区域。我们不能声明一个为`null type`的引用,也不能将`null type`声明为类型参数,例如`List<null>`([参考](https://stackoverflow.com/questions/26632104/java-kinds-of-type-and-null-reference))。但是`null`却可以强转为任何类型的引用,转换结果为目标类型的空引用,[参考](https://docs.oracle.com/javase/specs/jls/se7/html/jls-5.html#jls-5.2)。

>A value of the null type (the null reference is the only such value) may be assigned to any reference type, resulting in a null reference of that type.

最后,`null type`不是一个引用类型。

---

### Reference Types

下面的一段代码使用了四种引用类型(摘自[jse8规范](https://docs.oracle.com/javase/specs/jls/se8/html/jls-4.html#jls-4.3)):

``` java
class Point<T> {
    int[] metrics;
    T variables;
}
interface Move { void move(int deltax, int deltay); }
```

其中,`Point`是一个`class type`(翻译成类类型好难受...),`int[]`是一个`array type`,`Move`是一个`interface type`,`T`是一个`type variable`。前三种都很好理解,最后一个`type variable`值得一提。

在jse8规范中,`type variable`被定义为一个唯一的符号在类、接口、方法、构造函数中作为一个type。所以这个`type variable`只能在上面四个地方使用。引入`type variable`的原因是因为在泛型类、泛型接口、泛型构造函数、泛型方法中定义了类型参数。

所以,很好理解,`type variable`就是泛型中`<T>`中的T。注意，`Type`接口是java中type信息的顶级接口。主要有五种type,分别是:

- `raw types`:原始类型,使用对应类型的Class对象表示
- `primitive types`:基本类型,使用对应原始类型的Class对象表示
- `parameterized types`:参数类型,基于接口`ParameterizedTypes`,对应实现类为`ParameterizedTypesImpl`
- `array types`:泛型数组类型,基于接口`GenericArrayType`,对应实现类为`GenericArrayTypeImpl`
- `type variables`:类型变量,基于接口`TypeVariable`,对应实现类为`TypeVariableImpl`
- `WildcardType`:通配符类型,基于接口`WildcardType`,对应实现类为`WildcardTypeImpl`

其中`ParameterizedTypes`、`GenericArrayType`、`TypeVariable`、`WildcardType`这四个接口是`Type`接口的子接口。继承图如下所示:![Type继承图](https://eripe.oss-cn-shanghai.aliyuncs.com/img/type-system-of-java.Type.png)

可以看到,`Class`类是`Type`接口的子类。下面来一一解释一下四种子接口的含义。

## 1. ParameterizedType

`ParameterizedType`翻译过来就是参数化类型,emm。应该就是将类型参数化,这是引入泛型(Generic)的必然结果。例如我们常用的`List<Integer>`,这一个完整的带`<>`的类型就叫做参数化类型。下面解释了raw type于parameterized type之间的关系。

- genric type:`List<T>`
- parameterized type:`List<Integer>`
- raw type:`List`
- type parameter:`Integer`

**有如下常用方法**:

- `Type getRawType()`: 返回承载该泛型信息的对象, 如上面那个Map<String, String>承载范型信息的对象是Map
- `Type[] getActualTypeArguments()`: 返回实际泛型类型列表, 如上面那个Map<String, String>实际范型列表中有两个元素, 都是String
- `Type getOwnerType()`: 返回当前成员的属主,例如`Map.Entry`属于`Map`

以具体的参数化类型, 如`Map<String, String>`为例:

``` java
public class TestType {
    Map<String, String> map;
    public static void main(String[] args) throws Exception {
        Field f = TestType.class.getDeclaredField("map");
        System.out.println(f.getGenericType());                               // java.util.Map<java.lang.String, java.lang.String>
        System.out.println(f.getGenericType() instanceof ParameterizedType);  // true
        ParameterizedType pType = (ParameterizedType) f.getGenericType();
        System.out.println(pType.getRawType());                               // interface java.util.Map
        for (Type type : pType.getActualTypeArguments()) {
            System.out.println(type);                                         // 打印两遍: class java.lang.String
        }
        System.out.println(pType.getOwnerType());                             // null
    }
}

```

## 2. TypeVariable

类型变量, 范型信息在编译时会被转换为一个特定的类型, 而TypeVariable就是用来反映在JVM编译该泛型前的信息.

**常用方法:**

- `Type[] getBounds()`: 获取类型变量的上边界, 若未明确声明上边界则默认为Object
- `D getGenericDeclaration()`: 获取声明该类型变量实体,其中`D`是泛型类型的声明,也就是所在的类全限定名
- `String getName()`: 获取在源码中定义时的名字

注意:
类型变量在定义的时候只能使用extends进行(多)边界限定, 不能用super;为什么边界是一个数组? 因为类型变量可以通过&进行多个上边界限定，因此上边界有多个

``` java
public class TestType <K extends Comparable & Serializable, V> {
    K key;
    V value;
    public static void main(String[] args) throws Exception {
        // 获取字段的类型
        Field fk = TestType.class.getDeclaredField("key");
        Field fv = TestType.class.getDeclaredField("value");
        Assert.that(fk.getGenericType() instanceof TypeVariable, "必须为TypeVariable类型");
        Assert.that(fv.getGenericType() instanceof TypeVariable, "必须为TypeVariable类型");
        TypeVariable keyType = (TypeVariable)fk.getGenericType();
        TypeVariable valueType = (TypeVariable)fv.getGenericType();
        // getName 方法
        System.out.println(keyType.getName());                 // K
        System.out.println(valueType.getName());               // V
        // getGenericDeclaration 方法
        System.out.println(keyType.getGenericDeclaration());   // class com.test.TestType
        System.out.println(valueType.getGenericDeclaration()); // class com.test.TestType
        // getBounds 方法
        System.out.println("K 的上界:");                        // 有两个
        for (Type type : keyType.getBounds()) {                // interface java.lang.Comparable
            System.out.println(type);                          // interface java.io.Serializable
        }
        System.out.println("V 的上界:");                        // 没明确声明上界的, 默认上界是 Object
        for (Type type : valueType.getBounds()) {              // class java.lang.Object
            System.out.println(type);
        }
    }
}
```

## 3. GenericArrayType

我们仍然记得,不能创建泛型数组,那么这个`GenericArrayType`是啥意思?

虽然不能泛型数组,但是能够创建泛型数组引用啊,`T[] nums=null`是合法的,见下方代码:

``` java
public class TestType <T> {
    public static void main(String[] args) throws Exception {
        Method method = Test.class.getDeclaredMethods()[0];
        // public void com.test.Test.show(java.util.List[],java.lang.Object[],java.util.List,java.lang.String[],int[])
        System.out.println(method);
        Type[] types = method.getGenericParameterTypes();  // 这是 Method 中的方法
        for (Type type : types) {
            System.out.println(type instanceof GenericArrayType);
        }
    }
}
class Test<T> {
    public void show(List<String>[] pTypeArray, T[] vTypeArray, List<String> list, String[] strings, int[] ints) {
    }
}
```

声明一个泛型数组引用还是没有问题的,运行结果如下:

- 第一个参数List<String>[]的组成元素List<String>是ParameterizedType类型, 打印结果为true
- 第二个参数T[]的组成元素T是TypeVariable类型, 打印结果为true
- 第三个参数List<String>不是数组, 打印结果为false
- 第四个参数String[]的组成元素String是普通对象, 没有范型, 打印结果为false
- 第五个参数int[] pTypeArray的组成元素int是原生类型, 也没有范型, 打印结果为false

所以数组元素是`ParameterizedType`或`TypeVariable`的数组类型才是`GenericArrayType`。

## 4. WildcardType

该接口表示通配符泛型, 比如? extends Number 和 ? super Integer 它有如下方法:

- Type[] getUpperBounds(): 获取范型变量的上界
- Type[] getLowerBounds(): 获取范型变量的下界
注意:

现阶段通配符只接受一个上边界或下边界, 返回数组是为了以后的扩展, 实际上现在返回的数组的大小是1。

``` java
public class TestType {
    private List<? extends Number> a;  // // a没有下界, 取下界会抛出ArrayIndexOutOfBoundsException
    private List<? super String> b;
    public static void main(String[] args) throws Exception {
        Field fieldA = TestType.class.getDeclaredField("a");
        Field fieldB = TestType.class.getDeclaredField("b");
        // 先拿到范型类型
        Assert.that(fieldA.getGenericType() instanceof ParameterizedType, "");
        Assert.that(fieldB.getGenericType() instanceof ParameterizedType, "");
        ParameterizedType pTypeA = (ParameterizedType) fieldA.getGenericType();
        ParameterizedType pTypeB = (ParameterizedType) fieldB.getGenericType();
        // 再从范型里拿到通配符类型
        Assert.that(pTypeA.getActualTypeArguments()[0] instanceof WildcardType, "");
        Assert.that(pTypeB.getActualTypeArguments()[0] instanceof WildcardType, "");
        WildcardType wTypeA = (WildcardType) pTypeA.getActualTypeArguments()[0];
        WildcardType wTypeB = (WildcardType) pTypeB.getActualTypeArguments()[0];
        // 方法测试
        System.out.println(wTypeA.getUpperBounds()[0]);   // class java.lang.Number
        System.out.println(wTypeB.getLowerBounds()[0]);   // class java.lang.String
        // 看看通配符类型到底是什么, 打印结果为: ? extends java.lang.Number
        System.out.println(wTypeA);
    }
}

```

## 参考文献

转载自[Java中的Type详解](http://loveshisong.cn/%E7%BC%96%E7%A8%8B%E6%8A%80%E6%9C%AF/2016-02-16-Type%E8%AF%A6%E8%A7%A3.html)。
