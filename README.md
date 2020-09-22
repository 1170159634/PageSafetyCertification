基于Nginx+Lua实现的Token鉴权认证

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

Nginx的请求处理阶段有11，其中最重要的也是最常见的3个阶段依次为`rewrite`, `access`,`content`

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

  首先了解下系统基本架构：

1、管理员发布页面流程：

<img src="<https://raw.githubusercontent.com/1170159634/PageSafetyCertification/master/images/framework-1.png>">

2、用户访问页面流程：

<img src="<https://raw.githubusercontent.com/1170159634/PageSafetyCertification/master/images/framework-2.png>">

3、遇到了哪些难题？

<img src="<https://raw.githubusercontent.com/1170159634/PageSafetyCertification/master/images/framework-3.png>">

## 五、解决思路及方案？



## 六、目前该模块所做到的事情有哪些?



