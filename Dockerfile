FROM openjdk:8-jre-slim
FROM ubuntu
FROM tomcat
#copy war file on the container
COPY **/*.war /usr/local/tomcat/webapps
WORKDIR  /usr/local/tomcat/webapps
RUN apt update -y && apt install curl -y
RUN curl -O https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip && \
    apt-get install unzip -y  && \
    unzip newrelic-java.zip -d  /usr/local/tomcat/webapps
WORKDIR /usr/local/tomcat/webapps
COPY newrelic.yml /usr/local/tomcat/webapps/newrelic/newrelic.yml
ENTRYPOINT [ "java", "-javaagent:/usr/local/tomcat/webapps/newrelic/newrelic.jar", "-jar", "spring-petclinic-2.4.2.war", "--server.port=8080"]





# # Use an appropriate base image
# FROM tomcat:9.0-jdk8-openjdk-slim

# # Copy the WAR file to the webapps directory in Tomcat
# COPY **/*.war /usr/local/tomcat/webapps/

# # Set the working directory
# WORKDIR /usr/local/tomcat/webapps

# # Update and install any necessary packages
# RUN apt-get update -y && apt-get install -y curl

# # Expose the port the application will run on
# EXPOSE 8080

# # Set the entrypoint to run the Tomcat server
# ENTRYPOINT ["catalina.sh", "run"]



# FROM openjdk:8-jre-slim
# FROM ubuntu
# FROM tomcat
# #copy war file on the container
# COPY **/*.war /usr/local/tomcat/webapps
# WORKDIR  /usr/local/tomcat/webapps
# RUN apt update -y && apt install curl -y
# RUN curl -O https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip && \
#     apt-get install unzip -y  && \
#     unzip newrelic-java.zip -d  /usr/local/tomcat/webapps
# ENV JAVA_OPTS="$JAVA_OPTS -javaagent:app/newrelic.jar"
# ENV NEW_RELIC_APP_NAME="petclinicapps"
# ENV NEW_RELIC_LOG_FILE_NAME=STDOUT
# ENV NEW_RELIC_LICENCE_KEY="eu01xx2761148396df10a82ea5423bb031e1NRAL"
# WORKDIR /usr/local/tomcat/webapps
# ADD ./newrelic.yml /usr/local/tomcat/webapps/newrelic/newrelic.yml
# ENTRYPOINT [ "java", "-javaagent:/usr/local/tomcat/webapps/newrelic/newrelic.jar", "-jar", "spring-petclinic-2.4.2.war", "--server.port=8080"]
