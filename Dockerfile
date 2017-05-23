# Base image to use, this must be set as the first line
FROM ubuntu:14.04

# Maintainer: docker_user <docker_user at email.com> (@docker_user)
MAINTAINER wanxin <wanxin@yufex.com>

# ���ubuntu���°�
RUN rm -rf /var/lib/apt/lists/*

# ��װ��Ҫ�������
RUN apt-get update && apt-get install -y zip vim wget curl openssh-server supervisor

# ��������root�û�ssh��¼
RUN mkdir -p /var/run/sshd
RUN echo "root:123456" | chpasswd
RUN sed -ri "s/^PermitRootLogin\s+.*/PermitRootLogin yes/" /etc/ssh/sshd_config
RUN sed -ri "s/UsePAM yes/#UsePAM yes/g" /etc/ssh/sshd_config

# ����supervisor
RUN mkdir -p /var/log/supervisor
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# ����jdk��tomcatѹ����
COPY env /opt/package
# �ϲ��־�ѹ��������ѹ
RUN cat /opt/package/jdk1.7.0_79.tar.gz.a* > /opt/package/jdk1.7.0_79.tar.gz && \
mkdir -p /opt/jdk && \
tar -xf /opt/package/jdk1.7.0_79.tar.gz -C /opt/jdk
#����jdk��������
ENV JAVA_HOME /opt/jdk/jdk1.7.0_79
ENV JRE_HOME ${JAVA_HOME}/jre
RUN echo "#set java environment" >> /etc/profile && \
	echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/profile && \
	echo "export JRE_HOME=${JAVA_HOME}/jre" >> /etc/profile && \
	echo "export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib" >> /etc/profile && \
	echo "export PATH=${JAVA_HOME}/bin:$PATH" >> /etc/profile

#����jdk7��һ����ȫ����,����tomcat7��������deploy�׶�,ͨ���±��޸������
RUN sed -i 's/file:\/dev\/urandom/file:\/dev\/.\/urandom/g' ${JRE_HOME}/lib/security/java.security

#����tomcat����
RUN unzip -q /opt/package/apache-tomcat-7.0.77.zip -d /opt/server
ENV TOMCAT_HOME /opt/server/apache-tomcat-7.0.77
WORKDIR ${TOMCAT_HOME}
RUN chmod 777 bin/*.sh

# put web package(����������Ƶ�-v���ؾ�������)
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

# ��supervisor������ط���
CMD ["/usr/bin/supervisord"]