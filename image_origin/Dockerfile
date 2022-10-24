FROM cassandra:4.1

RUN sed -i 's/authenticator: AllowAllAuthenticator/authenticator: PasswordAuthenticator/' /etc/cassandra/cassandra.yaml

EXPOSE 7000 7001 7199 9042 9160
CMD ["cassandra", "-f"]