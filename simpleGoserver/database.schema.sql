create database posts;

CREATE TABLE postdata (id INT AUTO_INCREMENT NOT NULL, userid VARCHAR(1024) NOT NULL, body VARCHAR(65535) NOT NULL, extradata MEDIUMBLOB, PRIMARY KEY (`id`));

CREATE TABLE sessions (
	token CHAR(43) PRIMARY KEY,
	data BLOB NOT NULL,
	expiry TIMESTAMP(6) NOT NULL
);

CREATE INDEX sessions_expiry_idx ON sessions (expiry);