# One Key Make A Blog

以debian 9树莓派环境为例，其他linux发行版也差不多   
这是对脚本的一些解释和安装过程中的一些坑和解决方法   
注意不要用sudo运行脚本，因为一些路径使用了\$USER、\$HOME等系统变量

## 内网穿透部分

内网穿透简单来说就是让外网能访问到你局域网内的服务(比如你的电脑，你的树梅派)  

我们使用花生壳内网穿透功能   
详细操作可以参考花生壳的官网   
先到官网下载最新版的客户端 <https://hsk.oray.com/download/> 选择合适的版本下载后安装

```bash
sudo dpkg -i phddns_xxx.deb
```

然后会得到类似下列的一个SN账号

```sh
 +--------------------------------------------------+
 |            Oray PeanutHull Linux 3.0             |
 +--------------------------------------------------+
 |              Runstatus: OFFLINE                  |
 +--------------------------------------------------+
 |              SN: ORAYb810bxxxxxxx                |
 +--------------------------------------------------+
 |    Remote Management Address http://b.oray.com   |
 +--------------------------------------------------+
```

然后使用这个账号登录 <http://b.oray.com> \
然后申请内网穿透 \
会分配一个域名带端口号 \
填写映射端口号后如果成功就可以访问到内网的机子上

## 树莓派换源问题

更换过清华源、中科大和阿里等多个源，但好像一直有问题，apt update没问题但是软件列表一共只有几千个(远远小于没换源的5万+个)，于是最后选择不换源，慢慢的更新(也不会太慢)。

```sh
sudo apt update
sudo apt upgrade
```

## 安装docker

首先是下载docker，docker官网给出了脚本，下载的时候确保网络通畅，否则可能会出现问题。如果安装过docker还会人性化的询问是否重新安装。\
docker-ce需要先添加下载源

```sh
# 下载需要的工具
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

# 添加信任证书和公钥
sudo curl -fsSL https://download.docker.com/linux/$(. /etc/os-release;echo "$ID")/gpg | sudo apt-key add -

# 添加docker-ce下载预源
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release;echo"$ID") $(lsb_release -cs) stable"

# 获取docker官方安装脚本
sudo wget https://get.docker.com -O $HOME/get_docker.sh

# 使用阿里云镜像
sudo sh get_docker.sh --mirror Aliyun
```

## 安装docker-compose

两种方法

1. 官方安装方法

   ```sh
   sudo curl -L https://github.com/docker/compose/releases/download/1.25.0-rc1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

2. 推荐pip安装

   ```sh
   sudo apt-get update
   sudo apt-get install -y python python-pip
   sudo pip install docker-compose
   ```

检查安装是否成功

```sh
docker-compose -v
```

## docker的配置

```sh
# docker 换源
sudo tee /etc/docker/daemon.json <<-'EOF'
{
   "registry-mirrors" : ["https://docker.mirrors.ustc.edu.cn"]
}
EOF

# 重启服务
sudo systemctl daemon-reload
sudo systemctl restart docker

# 将用户加入docker的组，可以运行docker不加sudo，但是要注意重启系统后才生效
sudo usermod -aG docker $USER

```

## 获取ghost镜像失败

一开始第一次拉取时，一直卡在一个点，然后自动重新拉取报了个ERROR就停止了，没有其他提示 \
尝试拉取了自己上传的镜像才报出了一个是因为docker所在的文件空间不足 \
解决方法就只能移动文件夹，并修改相关文件

```sh
docker stop $(docker ps -q -f status=running)
systemctl stop docker
mv /var/lib/docker /DIR
# DIR 是你想要移动到的位置
# 查找修改docker.service
sudo vim /lib/systemd/system/docker.service
```

修改Execstart那行为

```sh
ExecStart=/usr/bin/dockerd -g 新目录
```

重新运行并查看现在的目录信息

```sh
systemctl daemon-reload
systemctl start docker
docker info | grep "Docker Root Dir"
```

如果docker info 报了Warning:

```sh
vim /etc/default/grub
```

找到 GRUB_CMDLINE_LINUX="" \
在双引号里面输入 cgroup_enable=memory swapaccount=1 \
然后执行

```sh
sudo update-grub
reboot
```

到这里大坑基本踩完

## 配置镜像和容器(docker-compose.yaml)

### docker-compose.yaml

```yaml
version: '3.0'
services:
  ghost:
    image: ghost
    restart: always
    container_name: ghost
    volumes:
     - ~/ghost/config.production.json:/var/lib/ghost/config.production.json # 配置文件
     - ~/ghost/content:/var/lib/ghost/content      # 博客数据
    environment:
      URL: http://$HOST
  nginx:
    image: nginx
    restart: always
    container_name: nginx_ghost
    ports:                                         # 开放端口号，用到的端口都该映射到宿主机
      - 80:80
      - 443:443
    links:                                         # 链接到ghost容器
      - ghost
    volumes:
      - ~/nginx/conf.d:/etc/nginx/conf.d           # 配置文件
      - ~/nginx/log:/var/log/nginx                 # 日志
      - ~/nginx/www:/var/www                       # 默认
      - ~/nginx/letsencrypt:/etc/letsencrypt       # ssl 配置文件
```

### ghost.conf

可以自行添加ssl证书开启https访问

```conf
server {
    listen 80; # 监听80端口
    server_name  $HOST;
    # 定义首页索引目录和名称
    location / {
       proxy_pass http://ghost:2368;  # 代理到ghost容器的2368端口
    }
}
```

### config.production.json

可以自己更改配置，如添加邮箱配置等等

```json
{
  "url": "http://$HOST",
  "database":{
     "client" :"sqlite3",
     "connection": {
       "filename": "/var/lib/ghost/content/data/ghost.db"
     }
   },
    "admin":{
      "url":"http://$HOST"
    },
    "server":{
      "host":"0.0.0.0",
      "port": 2368
    },
    "paths":{
      "contentPath" : "/var/lib/ghost/content/"
    },
    "logging": {
      "path": "/var/lib/ghost/content/logs/",
      "transports": ["stdout", "file"]
    }
}
```

