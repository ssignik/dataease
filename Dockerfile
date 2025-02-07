FROM centos:7.9.2009 as BUILDER

RUN cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup

COPY CentOS-Base.repo /etc/yum.repos.d

RUN yum clean all && yum makecache

RUN yum -y update && yum -y install wget \
    && wget https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.rpm \
    && yum -y install jdk-21_linux-x64_bin.rpm

RUN yum install -y git

RUN wget https://dlcdn.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz \
    && tar zxvf apache-maven-3.9.6-bin.tar.gz \
    && mv apache-maven-3.9.6 /opt \
    && rm -f apache-maven-3.9.6-bin.tar.gz

ENV M2_HOME=/opt/apache-maven-3.9.6
ENV PATH=$PATH:$M2_HOME/bin

RUN wget https://nodejs.org/dist/v16.15.0/node-v16.15.0-linux-x64.tar.xz \
    && tar xvf node-v16.15.0-linux-x64.tar.xz \
    && mv node-v16.15.0-linux-x64 /opt \
    && rm -f node-v16.15.0-linux-x64.tar.xz

ENV NODE_HOME=/opt/node-v16.15.0-linux-x64
ENV PATH=$PATH:$NODE_HOME/bin

COPY . /opt/dataease

RUN cd /opt/dataease && ls && mvn clean install

RUN cd /opt/dataease/core && mvn clean package -Pstandalone -U -Dmaven.test.skip=true

FROM registry.cn-qingdao.aliyuncs.com/dataease/alpine-openjdk21-jre
STOPSIGNAL SIGTERM

RUN apk update && apk add --no-cache \
    shadow \
    util-linux \
    bash && \
    ln -s /bin/false /sbin/nologin

RUN groupadd -g 1000 dataease \
    && useradd -u 1000 -g dataease -s /bin/bash -m dataease \

RUN mkdir -p /opt/apps/config \
    /opt/dataease2.0/drivers/ \
    /opt/dataease2.0/cache/ \
    /opt/dataease2.0/data/map \
    /opt/dataease2.0/data/static-resource/ \
    /opt/dataease2.0/data/appearance/ \
    /opt/dataease2.0/data/exportData/ \
    /opt/dataease2.0/data/i8n/ \
    /opt/dataease2.0/data/plugin/

ADD drivers/* /opt/dataease2.0/drivers/
ADD mapFiles/ /opt/dataease2.0/data/map/
ADD staticResource/ /opt/dataease2.0/data/static-resource/

RUN chown -R dataease:dataease /opt/dataease2.0 /opt/apps

WORKDIR /opt/apps

COPY --chown=dataease --from=Builder /opt/dataease/core/core-backend/target/CoreApplication.jar /opt/apps/app.jar

ENV JAVA_APP_JAR=/opt/apps/app.jar
ENV RUNNING_PORT=8100
ENV JAVA_OPTIONS="-Dfile.encoding=utf-8 -Dloader.path=/opt/apps -Dspring.config.additional-location=/opt/apps/config/"

HEALTHCHECK --interval=15s --timeout=5s --retries=20 --start-period=30s CMD nc -zv 127.0.0.1 $RUNNING_PORT

USER dataease

CMD ["/deployments/run-java.sh"]