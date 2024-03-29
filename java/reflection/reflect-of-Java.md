---
title: 反射初体验
mathjax: true
date: 2020-06-18 21:14:51
updated:
excerpt: 本文为初学者描述了在Java中反射的基本使用方法
tags: 反射
categories: Java
---

## 0. 反射是什么

反射是java中非常重要的一个概念。简而言之，反射就是在程序**运行时**可以**动态**的获取一个类的对象、执行某个类的方法等等。这里采用[overflow](https://stackoverflow.com/questions/4453349/what-is-the-class-object-java-lang-class)上的一个回答。

>In order to fully understand the class object, let go back in and understand we get the class object in the first place. You see, every .java file you create, when you compile that .java file, the jvm will creates a .class file, this file contains all the information about the class, namely:

>Fully qualified name of the class
Parent of class
Method information
Variable fields
Constructor
Modifier information
Constant pool
The list you see above is what you typically see in a typical class. Now, up to this point, your .java file and .class file exists on your hard-disk, when you actually need to use the class i.e. executing code in main() method, the jvm will use that .class file in your hard drive and load it into one of 5 memory areas in jvm, which is the method area, immediately after loading the .class file into the method area, the jvm will use that information and a Class object that represents that class that exists in the heap memory area.

>Here is the top level view,
.java --compile--> .class -->when you execute your script--> .class loads into method area --jvm creates class object from method area--> a class object is born

With a class object, you are obtain information such as class name, and method names, everything about the class.

反射机制是通过一个名为Class对象的概念来实现的。在编译每个.java文件后，都会生成一个对应的.class文件。这个.class文件包含了我们所编写的类的所有信息。比如类的全限定名、属性、方法、修饰符等等。然后当我们需要使用所编写的类时（这里记为target），.class文件会被加载至方法区，并且jvm会在堆区创建一个target类对应的Class对象。然后targt类的所有实例都由这个Class对象来产生。

注意，对于一个类，jvm只会生成一个对应的Class对象。

## 1. 反射有什么用

反射最主要的作用的我认为就是提高了对未知应用的扩展能力。

试想一个场景：

项目的云服务我们最先使用的是阿里云，然后某天不爽想换成腾讯云，然后又换成什么亚马逊，七牛等等，需求不停的在变。如果我们在代码里写死了业务代码，那么每换一次，就要更新一次代码，烦不烦，你说烦不烦。

那么这是肯定有人想，写个配置文件，到时候我们在代码里判断到底用的是哪个云服务不就完事了？用什么反射，自找麻烦。

但是想过没有，我们if判断的条件只能是已知的，如果某天市场上杀出一个新的厂商，怎么办？还是得更新业务代码。得重新编译、重新运行。

所以为了处理这种未知的状况，就不得不使用使用反射了。我们把类名写在配置文件里，然后利用反射加载对应的类，这样以不变应万变。配置文件变化时只需要重新应用就行了，**无需重新编译代码!!!**

当然，这些服务应该还有统一的接口，不然不可能实现一份代码适配多种情况。

## 2. 反射怎么用

### 2.1 获取反射对象

想使用反射，我们必须得首先获得Class对象，获得Class对象的方法有三种：

- 使用Class类的静态方法forName，参数为类的全限定名
- 直接使用某个类的class属性
- 调用某个对象的getClass()方法

``` java "获取Class对象的三种方式"
//获取class对象的方法有三种
    public static void getClassObject(Employee employee){
        //第一种通过全限定名获取
        try {
            Class c1=Class.forName("ReflectionBase.Employee");
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        }
        //第二种通过类的class属性获取
        Class<ReflectionBase.Employee> c2=Employee.class;

        //第三种通过对象的getClass()方法获取
        Class<? extends ReflectionBase.Employee> c3=employee.getClass();
    }
```

### 2.2 通过Class对象创造实例

主要有两种方法：

- 调用Class对象的newInstance()方法。
- 通过Class对象获取想要的Constructor，然后通过Constructor生成实例

``` java "通过反射获取类的实例"
    //通过newInstance方法
    try {
        Employee instance = c2.newInstance();
    } catch (InstantiationException e) {
        e.printStackTrace();
    } catch (IllegalAccessException e) {
        e.printStackTrace();
    }
    //通过获取Constructor来构造实例
    //其中的参数填充要根据我们想要的构造函数
    try {
        Constructor<Employee> constructor = c2.getDeclaredConstructor(String.class, int.class, String.class, int.class, String.class, double.class);
        //取消访问检查
        constructor.setAccessible(true);
        Employee e = constructor.newInstance("bob", 23, "eat", 2, "eng", 200.2);
        e.sayHello();
    } catch (NoSuchMethodException | InstantiationException | IllegalAccessException | InvocationTargetException e) {
        e.printStackTrace();
    }
```

可以看到，第一种方法只能通过默认无参构造方法构造对象，那么如果我们的类米有无参构造函数怎么办？这也许就是它被放弃的理由吧。

第二种可以获取任意一个构造函数，无论有参无参、私有公共，不过就是参数必须一一对应。

### 2.3 获取修饰符

修饰符的信息封装在`Modifier`类中，常见的用法通过`getModifiers()`返回一个用于描述Field、Method和Constructor的修饰符的整形数值，然后再由Modifier的静态方法`toString()`转为字符串。

以及一些常用的判断是否为`static`字段。

### 2.4 获取类的属性

类的属性都由Filed类管理。常用的方法有：

- `getFields()`,获取该类所有的public属性，但不包括父类的属性。
- `getDeclaredFields()`,获取该类的所有属性，包括私有，但同样不包括父类的属性

``` java "获取类的所有属性"
private static String parseFields(Class c){
    if(c==null){
        return null;
    }
    StringBuilder sb=new StringBuilder();
    Field[] fields = c.getFields();

    for (Field elem : fields) {

        sb.append(SPLIT);
        int modifiers = elem.getModifiers();
        if (Modifier.toString(modifiers).length() > 0) {
            sb.append(Modifier.toString(modifiers)).append(SPLIT);

        }
        Class<?> type = elem.getType();
        if (type != null) {
            sb.append(type.getName()).append(SPLIT);
        }
        sb.append(elem.getName());
        sb.append(";\n");
    }
    return sb.toString();
    }
```

### 2.5 获取类的构造方法

同样，类的构造方法也会被封装在`Constructor`类中。`getDeclaredConstructors()`可以获取该类的所有构造方法。但是不包含**父类的构造方法**。

``` java
private static String parseConstructor(Class c){
    if(c==null){
        return null;
    }
    StringBuilder sb=new StringBuilder();
    //获得该类的所有共有构造方法
    Constructor[] constructors = c.getConstructors();
    for(Constructor elem:constructors){
        sb.append(SPLIT);
        int modifiers = elem.getModifiers();
        if(Modifier.toString(modifiers).length()>0){
            sb.append(Modifier.toString(modifiers)).append(SPLIT);
        }
        sb.append(elem.getName()).append("(");
        Class[] types = elem.getParameterTypes();
        for(int i=0;i<types.length;i++){
            if(i>0){
                sb.append(",");
            }
            sb.append(types[i].getName());
        }
        sb.append(");\n");
    }
    return sb.toString();
    }
```

### 2.6 获取类的所有方法

与上面类似，方法被封装在Method类中，同样，`getDeclaredMethod()`获取的方法**不包括**父类的方法。`getMethods()`获取公共的、父类或接口的所有方法。

``` java "获取类的所有方法"
private static String parseMethods(Class c){
    if(c==null){
        return null;
    }
    StringBuilder sb=new StringBuilder();
    Method[] methods = c.getDeclaredMethods();
    for(Method elem:methods){
        sb.append(SPLIT);
        int modifiers = elem.getModifiers();
        if(Modifier.toString(modifiers).length()>0){
            sb.append(Modifier.toString(modifiers)).append(SPLIT);
        }
        Class<?> returnType = elem.getReturnType();
        sb.append(returnType.getName()).append(SPLIT);
        sb.append(elem.getName()).append("(");
        Class<?>[] parameterTypes = elem.getParameterTypes();
        for(int i=0;i<parameterTypes.length;i++){
            if(i>0){
                sb.append(",");
            }
            sb.append(parameterTypes[i].getName());
        }
        sb.append(");\n");
    }
    return sb.toString();
}
```

获取了方法，我们如何使用？非常简单，调用Method类的`invoke(Object invoke(Object obj, Object... args)` 执行方法，第一个参数执行该方法的对象，如果是static修饰的类方法，则传null即可方法。

通过获取Method对象时，仍然需要通过准确的参数类型才能找到我们想要的method对象。

### 2.7 解析类的基本信息

有了上面的工具我们就可以通过class文件来解析该类的基本信息了，我们构造两个类，Person和Employee类，后者继承前者：

``` java "Person类"
public class Person {
    public String name;
    protected int age;
    private String hobby;

    public Person(String name, int age, String hobby) {
        this.name = name;
        this.age = age;
        this.hobby = hobby;
    }

    public String getHobby() {
        return hobby;
    }

    public void setHobby(String hobby) {
        this.hobby = hobby;
    }
}
```

---

``` java "Employee类"
public class Employee extends Person {

    public static int count;
    public int employeeId;
    protected String title;
    private double salary;

    private Employee(String name, int age, String hobby, int employeeId, String title, double salary) {
        super(name, age, hobby);
        this.employeeId = employeeId;
        this.title = title;
        this.salary = salary;
    }
    public void sayHello() {
        System.out.println(String.format("Hello, 我是 %s, 今年 %s 岁, 爱好是%s, 我目前的工作是%s, 月入%s元\n",
                name, age, getHobby(), title, salary));
    }
    private void work() {
        System.out.println(String.format("My name is %s, 工作中勿扰.", name));

    }
```

构造了上述类，我们就可以通过反射获取该类的字段、构造器、方法等等，代码如下：

``` java
public static void parseClass(String className){

    StringBuilder result=new StringBuilder();
    Class c= null;
    try {
        c = Class.forName(className);
        int modifiers = c.getModifiers();
        //打印类的修饰符
        result.append(Modifier.toString(modifiers));
        result.append(SPLIT);
        result.append(c.getName()).append(SPLIT);
        Class superclass = c.getSuperclass();
        if(superclass!=null && superclass!=Object.class){
            result.append("extends").append(SPLIT).append(superclass.getName());
        }
        result.append("{\n");
        //打印属性
        result.append(parseFields(c));
        //打印构造函数
        result.append(parseConstructor(c));
        //打印成员方法
        result.append(parseMethods(c));

        result.append("}");
        System.out.println(result.toString());
    } catch (ClassNotFoundException e) {
        e.getMessage();
    }
}

```

结果如下：

``` java
public ReflectionBase.Employee extends ReflectionBase.Person{
    public static int count;
    public int employeeId;
    public java.lang.String name;
    private void work();
    public void sayHello();
}

```

### 2.8 解析类的数据

上面的解析是解析类的基本结构，那么如何获取一个对象的具体数据呢？与上面类似，我们将对象的类型分为三种，字符串、数组、普通对象。采用递归的方法解析所有字段。

``` java
public static String parseObject(Object obj){

    if(obj==null){
        return "";
    }
    StringBuilder sb=new StringBuilder();

    Class<?> c = obj.getClass();
    //判断是否为字符串类
    if(c==String.class){
        return (String)obj;
    }
    //判断对象是否为数组
    if(c.isArray()){
        sb.append(c.getComponentType()).append("[]{\n");
        System.out.println(Array.getLength(obj));
        for(int i=0;i<Array.getLength(obj);i++){
            if(i>0){
                sb.append(",\n");
            }
            sb.append("\t");
            Object o = Array.get(obj, i);
            //数组元素类型为8种普通类型，直接打印即可
            if(c.getComponentType().isPrimitive()){
                sb.append(o.toString());
            }
            else{
                //数组元素类型为类，递归解析
                sb.append(parseObject(o));
            }
        }
        return sb.append("\n}").toString();
    }
    //既不是数组，也不是字符串，那就是普通对象
    while(c!=null){
        sb.append(c.getName());
        sb.append("[");
        Field[] fields = c.getDeclaredFields();
        AccessibleObject.setAccessible(fields,true);
        for(int i=0;i<fields.length;i++){
            if(!Modifier.isStatic(fields[i].getModifiers())) {
                if (!sb.toString().endsWith("[")) {
                    sb.append(",");
                }
                sb.append(fields[i].getName()).append("=");
                try {
                    //属性为8种普通类型，直接打印即可
                    if (fields[i].getType().isPrimitive()) {
                        sb.append(fields[i].get(obj));
                    } else {
                        //属性为类，继续递归解析
                        sb.append(parseObject(fields[i].get(obj)));
                    }
                } catch (IllegalAccessException e) {
                    e.printStackTrace();
                }
            }

        }
        sb.append("]");
        c=c.getSuperclass();
    }
    return sb.toString();
}

```

测试代码为：

``` java
ArrayList<Integer> list=new ArrayList<>();
    for(int i=1;i<4;i++){
        list.add(i*i);
    }

    System.out.println(ReflectionUtil.parseObject(list).toString());

```

---

结果如下：

``` java
java.util.ArrayList[elementData=class java.lang.Object[]{
    java.lang.Integer[value=1]java.lang.Number[]java.lang.Object[],
    java.lang.Integer[value=4]java.lang.Number[]java.lang.Object[],
    java.lang.Integer[value=9]java.lang.Number[]java.lang.Object[],
    ,
    ,
    ,
    ,
    ,
    ,
},size=3]java.util.AbstractList[modCount=3]java.util.AbstractCollection[]java.lang.Object[]
```

这里的空白行是为ArrayList的默认容量为10。

小结：我们通过Filed类的`getType()`的方法来获取属性的类型，通过Field类的`get(Object o)`获取该属性的值，参数为我们当前想要查看的对象。

### 3. 反射机制的优缺点

优点：

- 就是灵活，提高了对未知代码的兼容性

缺点：

- 对性能有影响，反射的性能消耗比不使用的要高很多
- 而且打破了安全限制，使用反射技术要求程序必须在一个没有安全限制的环境中运行。如果一个程序必须在有安全限制的环境中运行，如 Applet，那么这就是个问题了。
- 破坏了封装性

所以能不用反射，就不用反射。

### 参考

1. [java反射机制详解](https://mp.weixin.qq.com/s?__biz=MzI1NDU0MTE1NA==&mid=2247483785&idx=1&sn=f696c8c49cb7ecce9818247683482a1c&chksm=e9c2ed84deb564925172b2dd78d307d4dc345fa313d3e44f01e84fa22ac5561b37aec5cbd5b4&scene=0#rd)

2. [动态代理详解](https://laijianfeng.org/2018/12/Java-%E5%8A%A8%E6%80%81%E4%BB%A3%E7%90%86%E8%AF%A6%E8%A7%A3/)