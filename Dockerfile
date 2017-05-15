# Base image to use, this must be set as the first line
FROM ubuntu:14.04

# Maintainer: docker_user <docker_user at email.com> (@docker_user)
MAINTAINER wanxin <wanxin@yufex.com>


# 拷贝jdk和tomcat压缩包
COPY env /opt/package
# 合并分卷压缩包并解压
RUN cat /opt/package/jdk1.7.0_79.tar.gz.a* > /opt/package/jdk1.7.0_79.tar.gz && \
mkdir -p /opt/jdk && \
tar -xvf /opt/package/jdk1.7.0_79.tar.gz -C /opt/jdk
#设置jdk环境变量
ENV JAVA_HOME /opt/jdk/jdk1.7.0_79
ENV JRE_HOME ${JAVA_HOME}/jre
RUN echo "#set java environment" >> /etc/profile && \
	echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/profile && \
	echo "export JRE_HOME=${JAVA_HOME}/jre" >> /etc/profile && \
	echo "export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib" >> /etc/profile && \
	echo "export PATH=${JAVA_HOME}/bin:$PATH" >> /etc/profile

#由于jdk7的一个安全问题,导致tomcat7启动卡在deploy阶段,通过下边修改来解决
RUN sed -i 's/file:\/dev\/urandom/file:\/dev\/.\/urandom/g' ${JRE_HOME}/lib/security/java.security

#处理tomcat环境
RUN apt-get update && apt-get install -y zip
RUN unzip /opt/package/apache-tomcat-7.0.77.zip -d /opt/server
ENV TOMCAT_HOME /opt/server/apache-tomcat-7.0.77
WORKDIR ${TOMCAT_HOME}
RUN chmod 777 bin/*.sh

# put web package(将这个步骤移到-v挂载卷来处理)
RUN rm -rf webapps/*
COPY war webapps

# copy run.sh
COPY script /opt/script
RUN chmod 777 /opt/script/run.sh

# set jvm options
ENV JAVA_OPTS="\
-server \
-Xms1024m \
-Xmx1024m \
-XX:PermSize=256M \
-XX:MaxNewSize=512m \
-XX:MaxPermSize=512m"

# Commands when creating a new container
EXPOSE 8080
ENTRYPOINT ["/opt/script/run.sh"]