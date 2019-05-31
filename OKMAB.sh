echo "don't run me with sudo please, or you will get something wrong"
echo "You should make it clear that you are in good network condition or you will fail to install it."
sleep 3

version=`docker -v`
if [[ $? == 0 ]]
    then 
    version=`echo $version | cut -d \  -f 3`
    echo "NOTICE: docker already exist, version: ${version%?}"
    read -p "update docker please select y, skip download please select n. (y/n)" choose
else 
    choose="y"
fi

if [[ choose == "y" ]]
    then
    echo "+ apt-get update"
    sudo apt-get update

    echo "+ apt-get upgrade"
    sudo apt-get upgrade

    echo "> get docker"
    echo "+ install apt-transport-https ca-certificates curl gnupg2 software-properties-common"
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

    echo "+ add apt-key"
    sudo curl -fsSL https://download.docker.com/linux/$(. /etc/os-release;echo "$ID")/gpg | sudo apt-key add -

    echo "+ add docker-ce source"
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release;echo"$ID") $(lsb_release -cs) stable"

    echo "+ pull get_docker.sh"
    sudo wget https://get.docker.com -O $HOME/get_docker.sh 

    echo "+ run get_docker.sh (may cause a few time)"
    sudo sh get_docker.sh --mirror Aliyun

    sudo 	/etc/docker
fi

echo "+ move docker to /home"
sudo mv /var/lib/docker /home/docker

echo "+ edit /etc/docker/daemon.json to change docker_pull source"
sudo tee /etc/docker/daemon.json <<-'EOF'
{
   "registry-mirrors" : ["https://docker.mirrors.ustc.edu.cn"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "+ add user $USER to docker group"
sudo usermod -aG docker $USER

sudo rm get_docker.sh
echo "> get docker sucessful"

echo ">> get docker compose"
echo "+ get docker-compose "

# read -p "if you don't want to install docker-compose or install it yourself(y/n)" status
# if [[ "$status" == "y" ]]
#     then
# 	echo "+ download docker-compose (may cause a few time)"
	
# 	sudo curl -L https://github.com/docker/compose/releases/download/1.25.0-rc1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
# 	sudo chmod +x /usr/local/bin/docker-compose
# fi

version=`docker-compose -v`
# docker-compoe -v

if [[ $? == 0 ]]
    then 
    version=`echo $version | cut -d \  -f 3`
    echo "NOTICE: docker-compose already exist, version: ${version%?}!"
    read -p "re-download please select y, skip download please select n. (y/n)" choose
else 
    choose="y"
fi

if [[ $choose == "y" ]]
    then
    echo "+ pip install docker-compose"
    sudo apt-get update
    sudo apt-get install -y python python-pip
    sudo pip install docker-compose
fi

echo "+ get ghost"
mkdir -p ~/ghost
mkdir -p ~/nginx
mkdir -p ~/nginx/conf.d


echo "NOTICE: if you meet some ERROR while pulling big file, you should move docker default dir yourself"
echo "sleep 5"
sleep 5

echo "+ write ghost config file ghost/config.production.json"

tee ~/ghost/config.production.json <<-'EOF'
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
EOF

echo "+ write nginx conf.d/ghost.conf"
tee ~/nginx/conf.d/ghost.conf <<-'EOF'
server {
    listen 80;
    server_name  $HOST;
    # 定义首页索引目录和名称
    location / {
       proxy_pass http://ghost:2368;
    }
}
EOF

echo "+ write nginx docker-compose.yaml"
tee ~/docker-compose.yaml <<-'EOF'
version: '3.0'
services:
  ghost:
    image: ghost
    restart: always
    container_name: ghost
    volumes:
     - ~/ghost/config.production.json:/var/lib/ghost/config.production.json
     - ~/ghost/content:/var/lib/ghost/content
    environment:
      URL: http://$HOST
  nginx:
    image: nginx
    restart: always
    container_name: nginx_ghost
    ports:
      - 80:80
      - 443:443
    links:
      - ghost
    volumes:
      - ~/nginx/conf.d:/etc/nginx/conf.d
      - ~/nginx/log:/var/log/nginx
      - ~/nginx/www:/var/www
      - ~/nginx/letsencrypt:/etc/letsencrypt
EOF

read -p "please input your domain(as: localhost or 127.0.0.1):" HOST

DO="s/\$HOST/$HOST/g"
sed -i $DO ~/nginx/conf.d/ghost.conf
sed -i $DO ~/ghost/config.production.json
sed -i $DO ~/docker-compose.yaml

cd ~
docker-compose up -d

echo "OK! you have your own blog if you see this text! see it with http://$HOST"
