create database posts;

CREATE TABLE postdata (id INT AUTO_INCREMENT NOT NULL, userid VARCHAR(1024) NOT NULL, body VARCHAR(65535) NOT NULL, extradata MEDIUMBLOB, PRIMARY KEY (`id`));

