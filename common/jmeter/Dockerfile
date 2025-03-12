FROM eclipse-temurin:11

# Install OpenJDK and JMeter
RUN wget https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-5.6.3.tgz \
    && tar -xzf apache-jmeter-5.6.3.tgz \
    && rm apache-jmeter-5.6.3.tgz \
    && mv apache-jmeter-5.6.3 /opt/apache-jmeter

# Set JMeter Home
ENV JMETER_HOME=/opt/apache-jmeter

# Add JMeter to the PATH
ENV PATH=$JMETER_HOME/bin:$PATH

WORKDIR /

# Simple entrypoint with no default command
ENTRYPOINT ["jmeter"] 