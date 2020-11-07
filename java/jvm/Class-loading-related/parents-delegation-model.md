---
title: 双亲委派模型
mathjax: true
data: 2020-11-05 21:11:27
updated:
tags: 类加载
categories: jvm
---

## 前言

首先在了解双亲委派模型前，我们有必要了解它的英文名字：`parents delegation model`。其实在具体的模型中，并没有所谓的“双亲”，只有一个逻辑意义上的父类，详情见下文。

## 1. 类加载器

在《深入理解java虚拟机》一书中写道：
>java团队有意将类加载阶段中的“通过一个类的全限定名来获取该类的二进制字节流”这个动作放到java虚拟机外部去实现
完成这个动作的代码就称为类加载器，以前不理解放到虚拟机外部是什么意思，现在我的理解是我们能够在编写程序时就能够编写目标类的加载过程，这也就是所谓的在虚拟机外部。这样如此，我们自定义的类加载器就能够处理我们自定义的字节码。

值得一提的是：类加载器与类共同确定了该类在虚拟机中是否唯一。也就是说，在虚拟机要比较两个类是否相同，比较的前提是**待比较的两个类是由同一个类加载器加载到虚拟机中的**，才有比较的意义。

这里的比较包括：`instanceof`、Class对象的`equals()`、`isAssignableForm()`、`isInstance()`方法。

## 2. 双亲委派模型

在了解双亲委派模型前，我们需要知道，jvm中有三类自带的类加载器：

- `bootstrap class loader`，启动类加载器
- `extension class loader`，扩展类加载器
- `Application class laoder`，应用程序类加载器

**启动类加载器**
启动类加载器由cpp编写，在java代码中无法直接引用。该加载器负责加载java的核心库，包括`<JAVA_HOME>/lib/`下的库，例如rt.jar、tools.jar；或者由`-Xbootclasspath`指定的，并且存放在lib目录下的符合规则的库，这里的规则是库的名字由jvm指定，不符合名字要求的即使由参数指定，也不会被加载。

前面说到，该加载器由cpp编写时，所以在编写代码时如果我们需要使用到该加载器，我们可以用null指代启动类加载器，这一规则由java团队约定。

**扩展类加载器**

扩展类加载器由java编写，负责加载`<JAVA_HOME>/lib/ext/`目录下的库，或者由环境变量`java.extdirs`指定目录下的库。

**应用程序加载器**

应用程序类加载器通用由java编写，在代码中可以直接引用。该加载器是我们接触最多的加载器了，默认情况下，我们编写的class都由其加载至jvm中。它负责加载由`classpath`参数指定路径下的类库。

>应用程序类加载器由`sun.misc.Launcher$AppClassLoader`实现。并且应用程序类加载器是ClassLoader中的getSystemClassLoader()方法的返回值

``` java
public Launcher() {
    Launcher.ExtClassLoader var1;
    try {
        var1 = Launcher.ExtClassLoader.getExtClassLoader();
    } catch (IOException var10) {
        throw new InternalError("Could not create extension class loader", var10);
    }

    try {
        this.loader = Launcher.AppClassLoader.getAppClassLoader(var1);
    } catch (IOException var9) {
        throw new InternalError("Could not create application class loader", var9);
    }

    Thread.currentThread().setContextClassLoader(this.loader);
    String var2 = System.getProperty("java.security.manager");
    if (var2 != null) {
        SecurityManager var3 = null;
        if (!"".equals(var2) && !"default".equals(var2)) {
            try {
                var3 = (SecurityManager)this.loader.loadClass(var2).newInstance();
            } catch (IllegalAccessException var5) {
            } catch (InstantiationException var6) {
            } catch (ClassNotFoundException var7) {
            } catch (ClassCastException var8) {
            }
        } else {
            var3 = new SecurityManager();
        }

        if (var3 == null) {
            throw new InternalError("Could not create SecurityManager: " + var2);
        }

        System.setSecurityManager(var3);
    }

}

```


``` java
/**
     * Returns the system class loader for delegation.  This is the default
     * delegation parent for new <tt>ClassLoader</tt> instances, and is
     * typically the class loader used to start the application.
     *
     * <p> This method is first invoked early in the runtime's startup
     * sequence, at which point it creates the system class loader and sets it
     * as the context class loader of the invoking <tt>Thread</tt>.
     *
     * <p> The default system class loader is an implementation-dependent
     * instance of this class.
     *
     * <p> If the system property "<tt>java.system.class.loader</tt>" is defined
     * when this method is first invoked then the value of that property is
     * taken to be the name of a class that will be returned as the system
     * class loader.  The class is loaded using the default system class loader
     * and must define a public constructor that takes a single parameter of
     * type <tt>ClassLoader</tt> which is used as the delegation parent.  An
     * instance is then created using this constructor with the default system
     * class loader as the parameter.  The resulting class loader is defined
     * to be the system class loader.
     *
     * <p> If a security manager is present, and the invoker's class loader is
     * not <tt>null</tt> and the invoker's class loader is not the same as or
     * an ancestor of the system class loader, then this method invokes the
     * security manager's {@link
     * SecurityManager#checkPermission(java.security.Permission)
     * <tt>checkPermission</tt>} method with a {@link
     * RuntimePermission#RuntimePermission(String)
     * <tt>RuntimePermission("getClassLoader")</tt>} permission to verify
     * access to the system class loader.  If not, a
     * <tt>SecurityException</tt> will be thrown.  </p>
     *
     * @return  The system <tt>ClassLoader</tt> for delegation, or
     *          <tt>null</tt> if none
     *
     * @throws  SecurityException
     *          If a security manager exists and its <tt>checkPermission</tt>
     *          method doesn't allow access to the system class loader.
     *
     * @throws  IllegalStateException
     *          If invoked recursively during the construction of the class
     *          loader specified by the "<tt>java.system.class.loader</tt>"
     *          property.
     *
     * @throws  Error
     *          If the system property "<tt>java.system.class.loader</tt>"
     *          is defined but the named class could not be loaded, the
     *          provider class does not define the required constructor, or an
     *          exception is thrown by that constructor when it is invoked. The
     *          underlying cause of the error can be retrieved via the
     *          {@link Throwable#getCause()} method.
     *
     * @revised  1.4
     */
    @CallerSensitive
    public static ClassLoader getSystemClassLoader() {
        initSystemClassLoader();
        if (scl == null) {
            return null;
        }
        SecurityManager sm = System.getSecurityManager();
        if (sm != null) {
            checkClassLoaderPermission(scl, Reflection.getCallerClass());
        }
        return scl;
    }

```

``` java

private static synchronized void initSystemClassLoader() {
        if (!sclSet) {//如果系统类加载器还没有被设置
            if (scl != null)
                throw new IllegalStateException("recursive invocation");
            sun.misc.Launcher l = sun.misc.Launcher.getLauncher();
            if (l != null) {
                Throwable oops = null;
                scl = l.getClassLoader();//获得ApplicationClassLoader
                try {
                    scl = AccessController.doPrivileged(
                        new SystemClassLoaderAction(scl));//设置系统类加载器
                } catch (PrivilegedActionException pae) {
                    oops = pae.getCause();
                    if (oops instanceof InvocationTargetException) {
                        oops = oops.getCause();
                    }
                }
                if (oops != null) {
                    if (oops instanceof Error) {
                        throw (Error) oops;
                    } else {
                        // wrap the exception
                        throw new Error(oops);
                    }
                }
            }
            sclSet = true;
        }
    }
```


``` java
class SystemClassLoaderAction
    implements PrivilegedExceptionAction<ClassLoader> {
    private ClassLoader parent;

    SystemClassLoaderAction(ClassLoader parent) {
        this.parent = parent;
    }

    public ClassLoader run() throws Exception {
        String cls = System.getProperty("java.system.class.loader");
        if (cls == null) {
            return parent;
        }

        Constructor<?> ctor = Class.forName(cls, true, parent)
            .getDeclaredConstructor(new Class<?>[] { ClassLoader.class });
        ClassLoader sys = (ClassLoader) ctor.newInstance(
            new Object[] { parent });
        Thread.currentThread().setContextClassLoader(sys);
        return sys;
    }
}

```


**参考文献**

https://greenhathg.github.io/2019/06/02/Java%E8%99%9A%E6%8B%9F%E6%9C%BA%E7%AC%94%E8%AE%B0-Launcher%E7%B1%BB/

https://juejin.im/post/6844903837472423944

https://segmentfault.com/a/1190000021869536