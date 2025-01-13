FROM openeuler/openeuler:22.03-lts-sp1 as BUILDER

RUN yum -y update && yum -y install wget rpm \
    && wget https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.rpm \
    && rpm -ivh jdk-21_linux-x64_bin.rpm \
    && wget https://repo.huaweicloud.com/apache/maven/maven-3/3.8.1/binaries/apache-maven-3.8.1-bin.tar.gz \
    && tar -zxvf apache-maven-3.8.1-bin.tar.gz

COPY . /opt/dataease

ENV MAVEN_HOME=/apache-maven-3.8.1
ENV PATH=${MAVEN_HOME}/bin:$PATH

RUN cd /opt/dataease && mvn clean install \
    && cd core && mvn clean package -Pstandalone -U -Dmaven.test.skip=true

FROM registry.cn-qingdao.aliyuncs.com/dataease/alpine-openjdk21-jre
STOPSIGNAL SIGTERM

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

WORKDIR /opt/apps

COPY --from=Builder /opt/dataease/core/core-backend/target/CoreApplication.jar ${WORKSPACE}/app.jar

ENV JAVA_APP_JAR=/opt/apps/app.jar
ENV RUNNING_PORT=8100
ENV JAVA_OPTIONS="-Dfile.encoding=utf-8 -Dloader.path=/opt/apps -Dspring.config.additional-location=/opt/apps/config/"

HEALTHCHECK --interval=15s --timeout=5s --retries=20 --start-period=30s CMD nc -zv 127.0.0.1 $RUNNING_PORT

CMD ["/deployments/run-java.sh"]