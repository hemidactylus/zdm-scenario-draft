-- Prepare target schema (it is Astra DB, so the keyspace will be already generated through the Astra UI at this point)

USE my_application_ks;

CREATE TABLE user_status (
  user    TEXT,
  when    TIMESTAMP,
  status  TEXT,
  PRIMARY KEY ((user), when)
) WITH CLUSTERING ORDER BY (when DESC);
