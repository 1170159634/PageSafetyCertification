# 基于Nginx+Lua实现的Token鉴权认证

## 一、Openresty模块：

OpenResty 是一个基于 Nginx的可伸缩的 Web 平台，同时也是一个强大的 Web 应用服务器，Web 开发人员可以使用 Lua 脚本语言调动 Nginx 支持的各种 C 以及 Lua 模块,更主要的是在性能方面，OpenResty可以 快速构造出足以胜任 10K 以上并发连接响应的超高性能 Web 应用系统。

OpenResty 的目标是让Web 服务直接跑在 Nginx 服务内部，充分利用 Nginx 的非阻塞 I/O 模型，不仅仅对 HTTP 客户端请求，甚至于对远程后端诸如 MySQL、PostgreSQL、Memcached 以及 Redis 等都进行一致的高性能响应。

## 二、如何安装？

我所安装的是1.15.8.1rc2版本

yum install pcre-devel openssl-devel gcc curl postgresql-devel
yum -y install libxml2 libxml2-dev
yum -y install libxslt-devel
cd /usr/local/
wget -c https://www.openssl.org/source/openssl-1.1.1d.tar.gz
tar -zxvf openssl-1.1.1d.tar.gz

wget -c https://openresty.org/download/openresty-1.15.8.1rc2.tar.gz
tar -zxvf openresty-1.15.8.1rc2.tar.gz
cd openresty-1.15.8.1rc2


./configure --prefix=/usr/local/openresty  --with-http_drizzle_module --with-luajit --without-http_redis2_module --with-http_iconv_module --with-stream --with-http_stub_status_module --with-http_xslt_module --with-stream_ssl_module --with-http_realip_module --with-http_ssl_module --with-openssl=/usr/local/openssl-1.1.1d

gmake &&gmake install



vim /etc/profile

export PATH=/usr/local/openresty/nginx/sbin:$PATH

yum install yum-utils

yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo

yum install openresty

**默认已经安装好了nginx,在目录：/usr/local/openresty/nginx** 

#### 安装http.lua和http_headers.lua库 （方便lua脚本发送请求和接受回调参数）


git clone https://github.com/ledgetech/lua-resty-http.git

cd /lua-resty-http/lib/resty/

直接拷贝文件到 openresty 的 lualib

cp ./http_headers.lua /usr/local/openresty/lualib/resty/

cp ./http.lua /usr/local/openresty/lualib/resty/



##### Openresty入门案例可以参考博客：<https://www.cnblogs.com/digdeep/p/4859575.html>

##### Lua收发GET POST请求可以参考博客：https://www.pianshen.com/article/3771132928



## 三、Openresty架构：

Nginx的请求处理阶段有11个，其中最重要的也是最常见的3个阶段依次为`rewrite`, `access`,`content`

- `init_by_lua``init_by_lua_block`: 运行在Nginx loading-config 阶段，注册Nginx Lua全局变量，和一些预加载模块。是Nginx master进程在加载Nginx配置时执行。
- `init_worker_by_lua`: 在Nginx starting-worker阶段，即每个nginx worker启动时会调用，通常用来hook worker进程，并创建worker进行的计时器，用来健康检查，或者设置熔断记时窗口等等。
- `access_by_lua`: 在`access tail`阶段，用来对每次请求做访问控制，权限校验等等，能拿到很多相关变量。例如：请求体中的值，header中的值，可以将值添加到`ngx.ctx`, 在其他模块进行相应的控制
- `balancer_by_lua`: 通过Lua设置不同的负载均衡策略, 具体可以参考[lua-resty-balancer](https://link.zhihu.com/?target=https%3A//github.com/openresty/lua-resty-balancer)
- `content_by_lua`: 在content阶段，即`content handler`的角色，即对于每个api请求进行处理，注意不能与proxy_pass放在同一个location下
- `proxy_pass`: 真正发送请求的一部分, 通常介于`access_by_lua`和`log_by_lua`之间
- `header_filter_by_lua`:在`output-header-filter`阶段，通常用来重新响应头部，设置cookie等，也可以用来作熔断触发标记
- `body_filter_by_lua`:对于响应体的content进行过滤处理
- `log_by_lua`:记录日志即，记录一下整个请求的耗时，状态码等





## 四、为什么要使用Nginx+Lua?(项目开发中遇到哪些难题？)  

#### 1、管理员发布页面流程：

<img src="https://raw.githubusercontent.com/1170159634/PageSafetyCertification/master/images/framework-1.png">

#### 2、用户访问页面流程：

<img src="https://raw.githubusercontent.com/1170159634/PageSafetyCertification/master/images/framework-2.png">

#### 3、遇到了哪些难题？

<img src="https://raw.githubusercontent.com/1170159634/PageSafetyCertification/master/images/framework-3.png">

根据图片描述，管理员要发布一个公告，在前台发送post请求，携带需要发布的json数据，调用后台api服务，通过需要发布的数据，利用Freemaker模板，生成一个静态页，保存到服务器指定目录。

所以，一个静态页面，无论非登录用户还是已登录但是没有授予查看该稿件权限的用户，页面能够做的是利用JS判断他们的用户类型，是否具有查看稿件角色权限，如果没有则隐藏静态数据，提示相关信息，拒绝他们查看。

这对于非法用户来说，相当危险，他们可以通过查看网页源代码，找到当前隐藏的Input标签，从而获取数据。

另外，通过爬虫也可以直接爬取所有包含敏感信息的页面的数据。

所以，需要思考该怎么样，在页面访问之前，拦截到非法用户，直接拒绝他们访问，跳转到相关页面，不让他们窃取数据。

## 五、解决思路及方案？

### 解决方案：

利用Nginx+Lua，做一个Token鉴权模块，拦截访问以.shtml结尾的页面，根据用户类型调用后台鉴权接口，的带返回类型后，再跳转到当前用户可以查看的页面。

### 实现思路：

（1）用户在访问页面时，首先经过Nginx，我们可以在Nginx设置location匹配值，.shtml结尾的页面走指定Lua脚本。

（2）在Lua脚本中，获取到用户访问的地址，截取.shtml结尾前的字符串，有可能为空（首页），index，list,或者具体某个稿件(UUID), 如 http://localhost:8080/jdgg/jdqx/1216721652781.shtml ，我们截取到具体稿件id

1216721652781 然后利用Lua脚本HTTP模块整理成一个请求http://127.0.0.1:8282/api/front/jurisdiction/content?contentId=1216721652781 ,发送到后台进行鉴权。

（3）如果后台鉴权没有调用成功（服务器崩了，或者状态码非200），利用Lua跳转到503页面，给用户提示：内部服务器错误。

（4）如果后台鉴权接口调用成功，则根据返回的参数决定跳转到哪个页面。

### 好处:

无需修改静态页面，无论什么样的用户访问，都可以根据用户类型跳转到指定页面，防止非法用户爬取数据，或者通过查看网页源代码查看敏感数据。



## 六、目前该模块所做到的事情有哪些?

分为向所有人员公开的网站，及内部人员才可以访问的网站。

### 公开网站(hlw_nginx.conf && hlw_dev.lua):

访问地址： http://120.27.21.6:82/  (向全社会人员公开的全军武器装备采购信息网)
后台鉴权地址返回值： true or false
安全模块需求：
(1)允许所有用户访问：首页,及各个子栏目列表页 (军队需求列表页，军工需求列表页等等)，及一些通用模块(footer.shtml ->{用来点击下一页，上一页等等})
(2)允许部分用户访问(在调用后台鉴权接口成功后)：
返回false：跳转到401(未授权页面)
返回true： 表示允许用户访问
(3)调用后台鉴权接口失败：
返回值状态码非200：      跳转到503页面(内部服务器错误)
请求超时(可能服务器挂了) 跳转到503页面



### 涉密网站（sm_nginx.conf && sm_dev.lua):

访问地址： http://219.147.99.163:81/    (向部分人员公开的全军武器装备采购信息网)
安全模块需求：
(1)当用户访问任意一个页面时，如果未登录，直接跳转到登录页
(2)如果用户已登录，在访问任意一个页面时，会将参数(稿件Id + Token)传递并调用后台鉴权接口判断
   如果返回3-> 未授权，则跳转到401页面
   如果返回2-> 用户未登录，跳转到登录页
   如果返回1-> 允许用户访问
(3)调用后台鉴权接口失败：
返回值状态码非200：      跳转到503页面(内部服务器错误)
请求超时(可能服务器挂了) 跳转到503页面



### 

