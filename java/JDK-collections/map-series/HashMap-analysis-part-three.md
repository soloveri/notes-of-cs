---
title: HashMap源码分析(三)-删除源码
mathjax: true
date: 2020-10-02 17:41:06
updated:
tags:
- HashMap
categories:
- 源码分析
---

HashMap的删除操作一般通过`remove`完成。在remove方法中,同样存在fast-fail机制,不了解的可以去看看[ArrayList中的fast-fail](../Collection/List/ArrayList-source-code-analysis.md)。通过fast-fail机制检查后,会调用真正的删除方法`removeNode`,如下面代码所示：

``` java
final Node<K,V> removeNode(int hash, Object key, Object value,
                            boolean matchValue, boolean movable) {
    Node<K,V>[] tab; Node<K,V> p; int n, index;
    if ((tab = table) != null && (n = tab.length) > 0 &&
            //通过hash找出一个Node p
            (p = tab[index = (n - 1) & hash]) != null) {
        Node<K,V> node = null, e; K k; V v;
        //注意,Hash相等不一定是同一个key,因为可能发生hash冲突
        if (p.hash == hash &&
                //如果是同一个对象或者使用equals返回true
                //那么p就是我们要删除的点
            ((k = p.key) == key || (key != null && key.equals(k))))
            node = p;
        //在链表中或RB树中查找目标节点
        else if ((e = p.next) != null) {
            if (p instanceof TreeNode)
                node = ((TreeNode<K,V>)p).getTreeNode(hash, key);
            else {
                do {
                    if (e.hash == hash &&
                        ((k = e.key) == key ||
                            (key != null && key.equals(k)))) {
                        node = e;
                        break;
                    }
                    p = e;
                } while ((e = e.next) != null);
            }
        }
        if (node != null && (!matchValue || (v = node.value) == value ||
                                (value != null && value.equals(v)))) {
            if (node instanceof TreeNode)
                //从RB树中删除目标节点
                ((TreeNode<K,V>)node).removeTreeNode(this, tab, movable);
            //如果目标节点在数组中
            else if (node == p)
                //直接把链表的头部去除
                tab[index] = node.next;
            else
                //如果此时HashMap仍然是以双向链表存储,那么直接链接后一个节点即可
                p.next = node.next;
            ++modCount;
            --size;
            afterNodeRemoval(node);
            return node;
        }
    }
    return null;
}
```

其中`matchValue`表示删除元素时需要value匹配才能删除,`movable`为`false`表示当移除元素时不会移动其他节点。在`HashMap`中`matchValue`默认为false。在具体阅读源码之前,我们需要了解,`HashMap`中的链表或者RB树都是hash冲突的元素。
所以这个方法的逻辑比较简单:

1. 首先通过`key`的hash找出目标桶。
2. 然后从对应的链表或者RB树找到对应的节点。注意这里对应的节点要求`key`与`value`都完全匹配,因为hash冲突。
3. 如果当前存储形式为RB树,那么调用当前节点的`removeTreeNode`方法删除自身

这里需要着重分析的是`TreeNode`的`removeTreeNode`方法,该方法非常复杂,需要耐心观看。

``` java
final void removeTreeNode(HashMap<K,V> map, Node<K,V>[] tab,
                                  boolean movable) {
    int n;
    if (tab == null || (n = tab.length) == 0)
        return;
    int index = (n - 1) & hash;
    TreeNode<K,V> first = (TreeNode<K,V>)tab[index], root = first, rl;
    TreeNode<K,V> succ = (TreeNode<K,V>)next, pred = prev;
    //删除节点有两种视角,分别是链表视角和红黑树视角
    //能这样操作是因为TreeNode既可以作为红黑树的节点，也可以作为链表节点
    //这里先将hashmap作为链表处理，如果删除完毕节点个数不多于6个,那么直接就将RB树转为链表即可
    //如果想要删除的节点就是根节点
    if (pred == null)
        //那么直接使用后继节点补上
        tab[index] = first = succ;
    else
        pred.next = succ;
    if (succ != null)
        succ.prev = pred;
    if (first == null)
        return;
    if (root.parent != null)
        root = root.root();
    if (root == null
        || (movable
            && (root.right == null
                || (rl = root.left) == null
                || rl.left == null))) {
        tab[index] = first.untreeify(map);  // too small
        return;
    }
    /******以RB树的视角删除节点************
    下面的代码目标是找到替换p的节点replacement然后将p进行真正的删除
    */
        TreeNode<K,V> p = this, pl = left, pr = right, replacement;
    //如果当前节点的左右子树都不为空
    if (pl != null && pr != null) {
        TreeNode<K,V> s = pr, sl;
        //那么就找到右子树的最左节点
        while ((sl = s.left) != null) // find successor
            s = sl;
        //交换待删除节点p和p的右子树最左节点的颜色
        boolean c = s.red; s.red = p.red; p.red = c; // swap colors
        //此时的s是没有左子树的
        TreeNode<K,V> sr = s.right;
        TreeNode<K,V> pp = p.parent;
        /***********接下来的操作就是交换s节点和p节点************
            * s是p右子树的最左节点
            * 总要要设置的就是s和p的left、right、parent三类指针
            * pp的left或right指针
            * sr的parent指针、pl和pr的parent指针***/
        //如果s是p的右节点,那么就将p设置为s的右节点
        if (s == pr) { // p was s's direct parent
            p.parent = s;
            s.right = p;
        }
        else {
            TreeNode<K,V> sp = s.parent;
            //设置p的parent指针,如果s的父节点不为空,将s的父节点设置为p的父节点
            if ((p.parent = sp) != null) {
                if (s == sp.left)
                    sp.left = p;
                else
                    sp.right = p;
            }
            //设置s的right指针,如果p的右子树不空,那么把p的右子树接到s的右边
            if ((s.right = pr) != null)
                //设置pr的parent指针
                pr.parent = s;
        }
        //设置p的left指针,因为s就是没有左子树的,所以交换后p的left指向null
        p.left = null;
        //设置p的right指针,将s的右子树接到p的右边
        if ((p.right = sr) != null)
            sr.parent = p;
        //设置s的left指针,将p的左子树接到s的左边
        if ((s.left = pl) != null)
            //设置pl的parent指针
            pl.parent = s;
        //设置s的parent指针,设置s的父节点为p的父节点
        if ((s.parent = pp) == null)
            root = s;
        //设置pp的left指针或者right指针
        else if (p == pp.left)
            pp.left = s;
        else
            pp.right = s;
        /**
            * sr还是原来s的右子节点,这里并没有产生变化
            */
        if (sr != null)
            replacement = sr;
        else
            replacement = p;
    }
    //只有左子树,那么直接使用左子树的根节点替换
    else if (pl != null)
        replacement = pl;
    //只有右子树,那么直接使用右子树的根节点替换
    else if (pr != null)
        replacement = pr;
    else
        //当左右子树都为空时,当前节点就是被替换的节点
        replacement = p;
    //如果replacement和p不是同一个节点,那么将二者交换
    /**
        * 这里仅仅是简单的将pp变成replacement的父节点
        * 将p的所有指针都置空,方便垃圾回收
        */
    if (replacement != p) {
        TreeNode<K,V> pp = replacement.parent = p.parent;
        if (pp == null)
            root = replacement;
        else if (p == pp.left)
            pp.left = replacement;
        else
            pp.right = replacement;
        p.left = p.right = p.parent = null;
    }
    /**如果p是红色,那么可以直接删除红节点
        * 否则从replacement开始调整颜色,此时p可以说是已经完全脱离RB树了
        */
        TreeNode<K,V> r = p.red ? root : balanceDeletion(root, replacement);
    //只有p的左右子树都为空才会走下面的if分支
    if (replacement == p) {  // detach
        TreeNode<K,V> pp = p.parent;
        p.parent = null;
        if (pp != null) {
            if (p == pp.left)
                pp.left = null;
            else if (p == pp.right)
                pp.right = null;
        }
    }
    if (movable)
        moveRootToFront(tab, r);
}
```
该方法的`this`指针就指向当前待删除的节点。在代码中我也写了,该方法删除节点有两种视角,因为`TreeNode`既可以作为RB树的节点,也可以作为双链表的节点。该方法的思路如下:

1. 首先以双链表的视角,删除当前节点,如果删除后RB树的节点不多于6个,那么就会执行`untreeify`方法,将RB树退化为单链表
2. 当前剩余节点多于6,那么以RB树的视角删除当前节点,这里的核心思想是找到一个节点`s`替换当前待删除节点`p`。
3. 如果节点`p`是红的,那么直接删除就好,因为删除红节点不会影响平衡性
4. 如果节点`p`是黑的,删除节点`p`后,我们需要从从`replacement`节点开始调整RB树的颜色,这里的`replacement`是`p`的左或者右孩子,或者是`s`交换前的右孩子,或者是p本身

经过上述四步,已经完成删除节点操作了,当然其中调整RB树平衡性的方法`balanceDeletion`是重中之重,但是记下来非常困难,看懂理解就好了。该方法的代码如下:

``` java
    /**
    * 如果能进入到这个函数,那么删除的必是黑节点
    * 并且从x开始调整RB树的颜色
    * 返回的是RB树的根节点
    */
static <K,V> TreeNode<K,V>  balanceDeletion(TreeNode<K,V> root,
                                            TreeNode<K,V> x) {
    for (TreeNode<K,V> xp, xpl, xpr;;) {
        //如果x是根节点,那么不用调整
        //直接返回root
        if (x == null || x == root)
            return root;
        //如果x的父节点为空,那么x就是新的父节点
        //直接返回x
        else if ((xp = x.parent) == null) {
            x.red = false;
            return x;
        }
        //如果x是红节点,因为删除了一个黑节点,需要补上一个黑节点,否则破坏了RB树的完美黑平衡
        else if (x.red) {
            x.red = false;
            return root;
        }
        /**
            * 到这里为止,x必是黑色,因为从x到叶子节点的路径中
            * 少了一个黑节点,所有必须想办法把这个黑节点从别的地方补回来
            * 我们需要关注的节点就是x
            * 下面的代码就是在不断地变换x的指针
            * 下面的case1的四种情况图示可以参考:http://jackhuang.online/2019/08/09/red-black-tree%E7%AE%80%E4%BB%8B/
            *  case2为镜像分布
            */

        //case1
        //如果x是其父节点的左孩子
        else if ((xpl = xp.left) == x) {
            //如果x有右兄弟并且右兄弟是红的,那么就把这个红色移到左边来
            //因为x是xp的左孩子
            //case1-1:
            if ((xpr = xp.right) != null && xpr.red) {
                xpr.red = false;
                xp.red = true;
                root = rotateLeft(root, xp);
                xpr = (xp = x.parent) == null ? null : xp.right;
            }
            //向左旋转后,x没有兄弟,重新设置x为xp
            if (xpr == null)
                x = xp;
            else {
                /**到此为止,x必有右兄弟,至于黑红目前还不知道
                */
                TreeNode<K,V> sl = xpr.left, sr = xpr.right;
                //如果右兄弟孩子双全并且都是黑孩子
                //或者有一个孩子并且孩子是黑的
                //case1-2:
                if ((sr == null || !sr.red) &&
                    (sl == null || !sl.red)) {
                    xpr.red = true;
                    x = xp;
                }
                else {
                    //走到这x的右兄弟必有孩子,因为如果没有孩子不会进入这个else分支
                    //如果有一个孩子,那么该孩子必是红的
                    //如果有两个孩子,必然是一个黑色,一个红色,或者两个都是红色
                    /**
                        * 在这我们关注的都是xpr的右孩子
                        */


                    //case1-3:如果xpr没有右孩子或者右孩子是黑的
                    if (sr == null || !sr.red) {
                        if (sl != null)
                            sl.red = false;
                        xpr.red = true;
                        root = rotateRight(root, xpr);
                        xpr = (xp = x.parent) == null ?
                            null : xp.right;
                    }
                    //走到这,xpr的必有右孩子且右孩子是红的


                    //case1-4
                    if (xpr != null) {
                        xpr.red = (xp == null) ? false : xp.red;
                        if ((sr = xpr.right) != null)
                            sr.red = false;
                    }
                    if (xp != null) {
                        xp.red = false;
                        root = rotateLeft(root, xp);
                    }
                    x = root;
                }
            }
        }
        //case2
        //如果x是其父节点的右孩子,这根上面是镜像的
        else { // symmetric
            if (xpl != null && xpl.red) {
                xpl.red = false;
                xp.red = true;
                //与上面相似,这里将红色往右边移,因为x是xp的右节点
                root = rotateRight(root, xp);
                xpl = (xp = x.parent) == null ? null : xp.left;
            }
            if (xpl == null)
                x = xp;
            else {
                TreeNode<K,V> sl = xpl.left, sr = xpl.right;
                if ((sl == null || !sl.red) &&
                    (sr == null || !sr.red)) {
                    xpl.red = true;
                    x = xp;
                }
                else {
                    if (sl == null || !sl.red) {
                        if (sr != null)
                            sr.red = false;
                        xpl.red = true;
                        root = rotateLeft(root, xpl);
                        xpl = (xp = x.parent) == null ?
                            null : xp.left;
                    }
                    if (xpl != null) {
                        xpl.red = (xp == null) ? false : xp.red;
                        if ((sl = xpl.left) != null)
                            sl.red = false;
                    }
                    if (xp != null) {
                        xp.red = false;
                        root = rotateRight(root, xp);
                    }
                    x = root;
                }
            }
        }
    }
}

```

在该方法中,`x`就是我们一直需要关注的节点,主要思想就是从x开始不断地由下向上调整整颗RB树的颜色,其主要逻辑如下:

1. 如果`x`没有父节点或者其本身就是root节点,表示并不需要调整什么
2. 如果`x`是红节点,那么把`x`变黑即可,因为原来从根节点到叶节点包含`x`的这条路径,少了一个黑节点,这里补上的话就没有什么问题了
3. 如果`x`是黑节点,那么比较惨,调整操作就比较复杂了,这里分成了两个大case,每个case里面有四种小case,具体见代码注释,并且这四种小case的图解可以[参考](http://jackhuang.online/2019/08/09/red-black-tree%E7%AE%80%E4%BB%8B/),就像图片的作者所说,我也认为这里不要去怀疑这些移动策略的正确性,仅作了解,看懂了即可。
