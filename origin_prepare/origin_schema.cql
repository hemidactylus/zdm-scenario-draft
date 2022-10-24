-- Prepare origin schema

CREATE KEYSPACE my_application_ks WITH REPLICATION = {'class': 'SimpleStrategy', 'replication_factor': 3};

USE my_application_ks;

CREATE TABLE user_status (
  user    TEXT,
  when    TIMESTAMP,
  status  TEXT,
  PRIMARY KEY ((user), when)
) WITH CLUSTERING ORDER BY (when DESC);
