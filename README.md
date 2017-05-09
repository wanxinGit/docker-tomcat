# docker-tomcat
此镜像构造文件用于jenkins持续构建，在代码提交后自动生成war包，并拉起一个新的容器供测试所用

大体步骤
1、先用Dockerfile构建一个tomcat镜像
--包含jdk1.7
--tomcat运行环境
--默认webapps下一个只有hello world的war包

2、在jenkins上配置一个maven项目，需要自动感知代码库的变化，并自动触发构建

3、构建成功后，利用Publish Over SSH（jenkins插件）完成远程ssh指令连接docker机器（可能是宿主机或者外部机器）

4、执行如下指令，在docker机上完成如下几个步骤
	1）删除存在的容器
	2）启动新容器（通过挂载卷的形式挂载新的war包）

################################jenkins实例配置 yufex-wtms##################################################
Source files：yufex-wtms/target/yufex-wtms.war
Remove prefix：yufex-wtms/target/
Remote /opt/docker/storage/tomcat/yufex-wtms/temp
Exec command：

PROJECT_NAME=yufex-wtms
PROJECT_PORT=8090

#remove exits container
if docker ps -a | grep -i ${PROJECT_NAME}; then
	docker rm -f ${PROJECT_NAME}
fi

#备份上一次war包并移动新包到trunk目录
cd /opt/docker/storage/tomcat/yufex-wtms
rm -rf bak
mv trunk bak
mkdir trunk
mv temp/${PROJECT_NAME}.war trunk/ROOT.war
rm -rf temp

#run new container
docker run -d \
-p ${PROJECT_PORT}:8080 \
--link mysql:local_mysql \
-v /etc/localtime:/etc/localtime:ro \
-v /opt/docker/storage/tomcat/${PROJECT_NAME}/trunk:/opt/server/apache-tomcat-7.0.77/webapps \
-e TZ="Asia/Shanghai" \
--name ${PROJECT_NAME} \
--restart always \
wanxin/docker-tomcat

###########################################################################################

################################jenkins实例配置 yufex-wtweb##################################################
Source files：yufex-wtweb/target/yufex-wtweb.war
Remove prefix：yufex-wtweb/target/
Remote directory：/opt/docker/storage/tomcat/yufex-wtweb/temp
Exec command：

PROJECT_NAME=yufex-wtweb
PROJECT_PORT=8080

#remove exits container
if docker ps -a | grep -i ${PROJECT_NAME}; then
	docker rm -f ${PROJECT_NAME}
fi

#备份上一次war包并移动新包到trunk目录
cd /opt/docker/storage/tomcat/${PROJECT_NAME}
rm -rf bak
mv trunk bak
mkdir trunk
mv temp/${PROJECT_NAME}.war trunk/ROOT.war
rm -rf temp

#run new container
docker run -d \
-p ${PROJECT_PORT}:8080 \
--link mysql:local_mysql \
-v /etc/localtime:/etc/localtime:ro \
-v /opt/docker/storage/tomcat/${PROJECT_NAME}/trunk:/opt/server/apache-tomcat-7.0.77/webapps \
-e TZ="Asia/Shanghai" \
--name ${PROJECT_NAME} \
--restart always \
wanxin/docker-tomcat

###########################################################################################

遇到的问题：
1、启动后访问不了
经过查看tomcat启动日志发现，卡在了deploy阶段
百度得知，因为centos7本身安全性原因，需要修改jre下的文件jre/lib/security/java.security
将securerandom.source=file:/dev/urandom 改为 securerandom.source=file:/dev/./urandom即可

2、tomcat启动参数配置问题
本来想在Dockerfile里配置替换catalina.sh，后来觉得没必要，不如直接tomcat的压缩包里的文件
JAVA_OPTS='-Xms1024m -Xmx1024m -XX:PermSize=256M -XX:MaxNewSize=512m -XX:MaxPermSize=512m'

3、自动监听版本库变化，然后出发构建
通过svn hooks机制解决（git上处理更为方便）

4、时区问题
通过挂载localtime和设置TZ参数解决

5、减少重复构建次数
由于镜像构建极其费时（apt-get安装工具），所以采用先构建好镜像，然后每次只是删除旧容器，启动新容器的方式。

6、日志处理（待解决）