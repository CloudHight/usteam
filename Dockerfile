FROM openjdk:8-jre-slim
FROM ubuntu
FROM tomcat
#copy war file on the container
COPY **/*.war /usr/local/tomcat/webapps
WORKDIR  /usr/local/tomcat/webapps
RUN apt update -y && apt install curl unzip -y

# New Relic Java APM agent. NEW_RELIC_LICENSE_KEY and NEW_RELIC_APP_NAME are
# supplied at `docker run` time (see the infra repo's Ansible/userdata) -
# never bake real credentials into this image or newrelic.yml.
RUN curl -o newrelic-java.zip https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip && \
    unzip newrelic-java.zip -d /usr/local/tomcat/webapps && \
    rm newrelic-java.zip
COPY newrelic.yml /usr/local/tomcat/webapps/newrelic/newrelic.yml

WORKDIR /usr/local/tomcat/webapps
ENTRYPOINT [ "java", "-javaagent:/usr/local/tomcat/webapps/newrelic/newrelic.jar", "-jar", "spring-petclinic-2.4.2.war", "--server.port=8080"]
