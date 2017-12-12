# docker-tomcat
此镜像构造文件用于jenkins持续构建，在代码提交后自动生成war包，并拉起一个新的容器供测试所用

※镜像构建大体步骤
1、基于ubuntu:14.04基础镜像
2、拷贝jdk1.7包解压并配置环境变量（因为jdk1.7安全问题修改了java.security）
3、拷贝tomcat运行环境并解压
4、通过ENV指定jvm启动参数
5、webapp下删除多余的包，只放置一个hello world的项目


基础启动脚本(测试用)
docker run -d \
-p 8888:8080 \
-p 2222:22 \
-v /etc/localtime:/etc/localtime:ro \
-e TZ="Asia/Shanghai" \
wanxin/docker-tomcat

####################################20171212更新内容###############################################
1、减掉java环境变量的配置，java环境变量在Dockerfile中设置了
所以特别需要注意，在容器中重新启动tomcat不能直接启动（这样会没有JAVA_HOME、JRE_HOME、JAVA_OPTS等环境变量）
需要用以下方式来启停
supervisorctl stop tomcat
supervisorctl start tomcat

2、优化web测试页的提示
####################################20170523更新内容###############################################
1、增加ssh远程管理支持
2、使用supervisor管理服务


※利用此镜像搭建持续集成环境的大体步骤
1、在jenkins上配置一个maven项目，需要自动感知代码库的变化，并自动触发构建
2、svn服务器上配置钩子方法，在代码提交时自动触发jenkins构建任务执行
3、构建成功后，利用Publish Over SSH（jenkins插件）完成远程ssh指令连接docker机器（可能是宿主机或者外部机器）
4、执行如下指令，在docker机上完成如下几个步骤
	1）尝试从docker hub上去拉最新的镜像（由于没指定tag，默认latest，所以可多次重复拉去，只是要定时清空tag为none的镜像，避免占空间过多）
	2）删除存在的容器
	3）启动新容器（通过挂载卷的形式挂载新的war包）

################################jenkins实例配置 yufex-wtms##################################################
Source files：yufex-wtms/target/yufex-wtms.war
Remove prefix：yufex-wtms/target/
Remote /opt/docker/storage/tomcat/yufex-wtms/temp
Exec command：

PROJECT_NAME=yufex-wtms
PROJECT_PORT=8090
SSH_PORT=2022

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
-p ${SSH_PORT}:22 \
--link mysql:local_mysql \
-v /etc/localtime:/etc/localtime:ro \
-v /opt/docker/storage/tomcat/${PROJECT_NAME}/trunk:/opt/server/apache-tomcat-7.0.77/webapps \
-v /opt/docker/storage/tomcat/${PROJECT_NAME}/logs/tomcat:/opt/server/apache-tomcat-7.0.77/logs \
-v /opt/docker/storage/tomcat/${PROJECT_NAME}/logs/app:/opt/server/logs \
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
SSH_PORT=2122

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
-p ${SSH_PORT}:22 \
--link mysql:local_mysql \
--link yufex-wtms:yufex-wtms \
-v /etc/localtime:/etc/localtime:ro \
-v /opt/docker/storage/tomcat/${PROJECT_NAME}/trunk:/opt/server/apache-tomcat-7.0.77/webapps \
-v /opt/docker/storage/tomcat/${PROJECT_NAME}/logs/tomcat:/opt/server/apache-tomcat-7.0.77/logs \
-v /opt/docker/storage/tomcat/${PROJECT_NAME}/logs/app:/opt/server/logs \
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
之前是改tomcat压缩包，在catalina.sh中增加如下配置
JAVA_OPTS='-server -Xms1024m -Xmx1024m -XX:PermSize=256M -XX:MaxNewSize=512m -XX:MaxPermSize=512m'
后来觉得这样不合理，不仅写死了，以后针对不同的web项目修改参数不便，而且容易使用镜像的人误会。不知道这个压缩包被动过了。
现在通过在Dockerfile中增加ENV来配置jvm启动参数；
如果需要修改，也可以在启动脚本中增加
-e JAVA_OPTS='-server -Xms1024m -Xmx1024m -XX:PermSize=256M -XX:MaxNewSize=512m -XX:MaxPermSize=512m'


3、自动监听版本库变化，然后出发构建
通过svn hooks机制解决（git上处理更为方便）

4、时区问题
通过挂载localtime和设置TZ参数解决

5、减少重复构建次数
由于镜像构建极其费时（apt-get安装工具），所以采用先构建好镜像，然后每次只是删除旧容器，启动新容器的方式。

6、日志处理（待解决）

7、容器中杀掉tomcat进程会被supervisor自动重新拉起来
需要在supervisor中停止或者启动进程
supervisorctl stop tomcat
supervisorctl start tomcat

--直接startup.sh启动tomcat还有一个问题就是JAVA_OPTS不会设置，所以建议启停都通过supervisor来！