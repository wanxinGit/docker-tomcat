# Base image to use, this must be set as the first line
FROM ubuntu:14.04

# Maintainer: docker_user <docker_user at email.com> (@docker_user)
MAINTAINER wanxin <wanxin@yufex.com>

# 清空ubuntu更新包
RUN rm -rf /var/lib/apt/lists/*

# 安装需要的软件包
RUN apt-get update && apt-get install -y zip vim wget curl openssh-server supervisor

# 配置允许root用户ssh登录
RUN mkdir -p /var/run/sshd
RUN echo "root:123456" | chpasswd
RUN sed -ri "s/^PermitRootLogin\s+.*/PermitRootLogin yes/" /etc/ssh/sshd_config
RUN sed -ri "s/UsePAM yes/#UsePAM yes/g" /etc/ssh/sshd_config

# 配置supervisor
RUN mkdir -p /var/log/supervisor
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# 拷贝jdk和tomcat压缩包
COPY env /opt/package
# 合并分卷压缩包并解压
RUN cat /opt/package/jdk1.7.0_79.tar.gz.a* > /opt/package/jdk1.7.0_79.tar.gz && \
mkdir -p /opt/jdk && \
tar -xf /opt/package/jdk1.7.0_79.tar.gz -C /opt/jdk
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
RUN unzip -q /opt/package/apache-tomcat-7.0.77.zip -d /opt/server
ENV TOMCAT_HOME /opt/server/apache-tomcat-7.0.77
WORKDIR ${TOMCAT_HOME}
RUN chmod 777 bin/*.sh

# put web package(将这个步骤移到-v挂载卷来处理)
RUN rm -rf webapps/*
COPY war webapps

# set jvm options
ENV JAVA_OPTS="\
-server \
-Xms1024m \
-Xmx1024m \
-XX:PermSize=256M \
-XX:MaxNewSize=512m \
-XX:MaxPermSize=512m"

EXPOSE 22 8080

# 用supervisor启动相关服务
CMD ["/usr/bin/supervisord"]