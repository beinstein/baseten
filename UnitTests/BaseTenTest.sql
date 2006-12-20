DROP DATABASE basetentest;
CREATE DATABASE basetentest ENCODING 'UNICODE';
\connect basetentest

\i ../BaseTenModifications.sql


BEGIN TRANSACTION;
DROP ROLE baseten_test_user;
COMMIT;

BEGIN TRANSACTION;
CREATE ROLE baseten_test_user WITH 
    NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN IN ROLE basetenuser;
COMMIT;


BEGIN TRANSACTION;
REVOKE ALL PRIVILEGES ON DATABASE basetentest FROM baseten_test_user;
COMMIT;


BEGIN TRANSACTION;

CREATE TABLE test (
    id SERIAL PRIMARY KEY,
    value VARCHAR (255) NULL
);

CREATE VIEW test_v AS SELECT * FROM test;

CREATE TABLE "Pkeytest" (
    "Id" INTEGER PRIMARY KEY,
    value VARCHAR (255) NULL
);

GRANT SELECT, INSERT, UPDATE, DELETE ON test TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON test_v TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON "Pkeytest" TO baseten_test_user;
GRANT UPDATE, SELECT ON test_id_seq TO baseten_test_user;

SELECT baseten.PrepareForModificationObserving (c.oid) FROM pg_class c, pg_namespace n
    WHERE c.relname IN ('test', 'Pkeytest') AND n.nspname = 'public' AND c.relnamespace = n.oid;

INSERT INTO public.test DEFAULT VALUES;
INSERT INTO public.test DEFAULT VALUES;
INSERT INTO public.test DEFAULT VALUES;
INSERT INTO public.test DEFAULT VALUES;

INSERT INTO "Pkeytest" VALUES (1, 'a');
INSERT INTO "Pkeytest" VALUES (2, 'b');
INSERT INTO "Pkeytest" VALUES (3, 'c');


CREATE SCHEMA "Fkeytest";
GRANT USAGE ON SCHEMA "Fkeytest" TO PUBLIC;
SET search_path TO "Fkeytest";

-- A simple many-to-one relationship
CREATE TABLE test1 (
    id SERIAL PRIMARY KEY,
    value VARCHAR (255) NULL
);
CREATE VIEW test1_v AS SELECT * FROM test1;
CREATE RULE "insert_test1" AS ON INSERT TO test1_v DO INSTEAD 
    INSERT INTO test1 (value) VALUES (NEW.value) RETURNING *;
CREATE RULE "update_test1" AS ON UPDATE TO test1_v DO INSTEAD 
    UPDATE test1 SET id = NEW.id, value = NEW.value WHERE id = OLD.id;

CREATE TABLE test2 (
    id SERIAL PRIMARY KEY,
    value VARCHAR (255) NULL,
    fkt1id INTEGER CONSTRAINT fkt1 REFERENCES test1 (id)
);
CREATE VIEW test2_v AS SELECT * FROM test2;
CREATE RULE "insert_test2" AS ON INSERT TO test2_v DO INSTEAD
    INSERT INTO test2 (value, fkt1id) VALUES (NEW.value, NEW.fkt1id) RETURNING *;
CREATE RULE "update_test2" AS ON UPDATE TO test2_v DO INSTEAD 
    UPDATE test2 SET id = NEW.id, value = NEW.value, fkt1id = NEW.fkt1id WHERE id = OLD.id;

GRANT USAGE ON SEQUENCE test1_id_seq TO PUBLIC;
GRANT USAGE ON SEQUENCE test2_id_seq TO PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON test1 TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON test1_v TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON test2 TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON test2_v TO baseten_test_user;

INSERT INTO test1 (value) VALUES ('11');
INSERT INTO test1 (value) VALUES ('12');
INSERT INTO test2 (value, fkt1id) VALUES ('21', 1);
INSERT INTO test2 (value, fkt1id) VALUES ('22', 1);
INSERT INTO test2 (value, fkt1id) VALUES ('23', null);


-- One-to-one
CREATE TABLE ototest1 (
    id INTEGER PRIMARY KEY
);

CREATE TABLE ototest2 (
    id INTEGER PRIMARY KEY,
    r1 INTEGER CONSTRAINT foo REFERENCES ototest1 (id)
);
ALTER TABLE ototest1 ADD COLUMN r2 INTEGER CONSTRAINT bar REFERENCES ototest2 (id);
CREATE VIEW ototest1_v AS SELECT * FROM ototest1;
CREATE VIEW ototest2_v AS SELECT * FROM ototest2;
CREATE RULE "insert_ototest1" AS ON INSERT TO ototest1_v DO INSTEAD
    INSERT INTO ototest1 DEFAULT VALUES RETURNING *;
CREATE RULE "insert_ototest2" AS ON INSERT TO ototest2_v DO INSTEAD
    INSERT INTO ototest2 (r1) VALUES (NEW.r1) RETURNING *;
CREATE RULE "update_ototest1" AS ON UPDATE TO ototest1_v DO INSTEAD 
    UPDATE ototest1 SET id = NEW.id, r2 = NEW.r2 WHERE id = OLD.id;
CREATE RULE "update_ototest2" AS ON UPDATE TO ototest2_v DO INSTEAD 
    UPDATE ototest2 SET id = NEW.id, r1 = NEW.r1 WHERE id = OLD.id;

GRANT SELECT, INSERT, UPDATE, DELETE ON ototest1 TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ototest1_v TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ototest2 TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ototest2_v TO baseten_test_user;

INSERT INTO ototest1 (id) VALUES (1);
INSERT INTO ototest1 (id) VALUES (2);
INSERT INTO ototest2 (id, r1) VALUES (1, 2);
INSERT INTO ototest2 (id, r1) VALUES (2, 1);
INSERT INTO ototest2 (id, r1) VALUES (3, null);
UPDATE ototest1 SET r2 = 2 WHERE id = 1;
UPDATE ototest1 SET r2 = 1 WHERE id = 2;


-- Many-to-many
CREATE TABLE mtmtest1 (
    id SERIAL PRIMARY KEY,
    value1 VARCHAR (255)
);
GRANT USAGE ON SEQUENCE mtmtest1_id_seq TO PUBLIC;

CREATE VIEW mtmtest1_v AS SELECT * FROM mtmtest1;
CREATE RULE "insert_mtmtest1" AS ON INSERT TO mtmtest1_v DO INSTEAD
    INSERT INTO mtmtest1 (value1) VALUES (NEW.value1) RETURNING *;
CREATE RULE "update_mtmtest1" AS ON UPDATE TO mtmtest1_v DO INSTEAD 
    UPDATE mtmtest1 SET id = NEW.id, value1 = NEW.value1 WHERE id = OLD.id;

CREATE TABLE mtmtest2 (
    id SERIAL PRIMARY KEY,
    value2 VARCHAR (255)
);
GRANT USAGE ON SEQUENCE mtmtest2_id_seq TO PUBLIC;

CREATE VIEW mtmtest2_v AS SELECT * FROM mtmtest2;
CREATE RULE "insert_mtmtest2" AS ON INSERT TO mtmtest2_v DO INSTEAD
    INSERT INTO mtmtest2 (value2) VALUES (NEW.value2) RETURNING *;
CREATE RULE "update_mtmtest2" AS ON UPDATE TO mtmtest2_v DO INSTEAD 
    UPDATE mtmtest2 SET id = NEW.id, value2 = NEW.value2 WHERE id = OLD.id;

CREATE TABLE mtmrel1 (
    id1 INTEGER REFERENCES mtmtest1 (id),
    id2 INTEGER REFERENCES mtmtest2 (id),
    PRIMARY KEY (id1, id2)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON mtmtest1 TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON mtmtest1_v TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON mtmtest2 TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON mtmtest2_v TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON mtmrel1 TO baseten_test_user;

INSERT INTO mtmtest1 (value1) VALUES ('a1');
INSERT INTO mtmtest2 (value2) VALUES ('a2');
INSERT INTO mtmtest1 (value1) VALUES ('b1');
INSERT INTO mtmtest2 (value2) VALUES ('b2');
INSERT INTO mtmtest1 (value1) VALUES ('c1');
INSERT INTO mtmtest2 (value2) VALUES ('c2');
INSERT INTO mtmtest1 (value1) VALUES ('d1');
INSERT INTO mtmtest2 (value2) VALUES ('d2');

INSERT INTO mtmrel1 (id1, id2) VALUES (1, 1);
INSERT INTO mtmrel1 (id1, id2) VALUES (1, 2);
INSERT INTO mtmrel1 (id1, id2) VALUES (1, 3);
INSERT INTO mtmrel1 (id1, id2) VALUES (2, 1);
INSERT INTO mtmrel1 (id1, id2) VALUES (2, 2);
INSERT INTO mtmrel1 (id1, id2) VALUES (2, 3);
INSERT INTO mtmrel1 (id1, id2) VALUES (3, 1);
INSERT INTO mtmrel1 (id1, id2) VALUES (3, 2);
INSERT INTO mtmrel1 (id1, id2) VALUES (3, 3);
INSERT INTO mtmrel1 (id1, id2) VALUES (4, 4);

-- Collection testing
CREATE TABLE mtocollectiontest1 (
    id SERIAL PRIMARY KEY
);
GRANT USAGE ON mtocollectiontest1_id_seq TO PUBLIC;

CREATE TABLE mtocollectiontest2 (
    id SERIAL PRIMARY KEY,
    mid INTEGER CONSTRAINT m REFERENCES mtocollectiontest1 (id)
);
GRANT USAGE ON mtocollectiontest2_id_seq TO PUBLIC;

GRANT SELECT, INSERT, UPDATE, DELETE ON mtocollectiontest1 TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON mtocollectiontest2 TO baseten_test_user;

INSERT INTO mtocollectiontest1 DEFAULT VALUES;
INSERT INTO mtocollectiontest1 DEFAULT VALUES;

INSERT INTO mtocollectiontest2 DEFAULT VALUES;
INSERT INTO mtocollectiontest2 DEFAULT VALUES;
INSERT INTO mtocollectiontest2 DEFAULT VALUES;

SELECT baseten.PrepareForModificationObserving (c.oid) FROM pg_class c, pg_namespace n
    WHERE c.relname IN (
            'test1', 'test2', 'ototest1', 'ototest2', 'mtmtest1', 'mtmtest2', 'mtmrel1',
            'mtocollectiontest1', 'mtocollectiontest2'
        ) AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;


SET search_path TO public;

-- Multi-column primary keys
CREATE TABLE multicolumnpkey (
    id1 INTEGER NOT NULL,
    id2 INTEGER NOT NULL,
    value1 VARCHAR(255)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON multicolumnpkey TO baseten_test_user;

INSERT INTO multicolumnpkey (id1, id2, value1) VALUES (1, 1, 'thevalue1');
INSERT INTO multicolumnpkey (id1, id2, value1) VALUES (1, 2, 'thevalue2');
INSERT INTO multicolumnpkey (id1, id2, value1) VALUES (2, 3, 'thevalue3');
ALTER TABLE ONLY multicolumnpkey ADD CONSTRAINT multicolumnpkey_pkey PRIMARY KEY (id1, id2);

-- Update and delete by entity & predicate
CREATE TABLE updatetest (
    id SERIAL PRIMARY KEY,
    value1 INTEGER
);
GRANT SELECT, INSERT, UPDATE, DELETE ON updatetest TO baseten_test_user;
GRANT USAGE ON SEQUENCE updatetest_id_seq TO baseten_test_user;
INSERT INTO updatetest (value1) VALUES (3);
INSERT INTO updatetest (value1) VALUES (4);
INSERT INTO updatetest (value1) VALUES (5);
INSERT INTO updatetest (value1) VALUES (6);
INSERT INTO updatetest (value1) VALUES (7);

CREATE TABLE person (
    id SERIAL NOT NULL,
    name TEXT,
    soulmate SERIAL NOT NULL,
    address INTEGER
);

CREATE TABLE person_address (
    id SERIAL NOT NULL,
    address TEXT
);

GRANT SELECT, INSERT, UPDATE, DELETE ON person TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON person_address TO baseten_test_user;
GRANT USAGE ON SEQUENCE person_id_seq TO baseten_test_user;
GRANT USAGE ON SEQUENCE person_soulmate_seq TO baseten_test_user;
GRANT USAGE ON SEQUENCE person_address_id_seq TO baseten_test_user;

INSERT INTO person VALUES (1, 'nzhuk', 1, 1);
INSERT INTO person_address VALUES (1, 'Hämeentie 94');

ALTER TABLE ONLY person ADD CONSTRAINT person_pkey PRIMARY KEY (id);
ALTER TABLE ONLY person_address ADD CONSTRAINT person_address_pkey PRIMARY KEY (id);
ALTER TABLE ONLY person ADD CONSTRAINT person_address_fkey FOREIGN KEY (address) REFERENCES person_address(id);


SELECT baseten.PrepareForModificationObserving (c.oid) FROM pg_class c, pg_namespace n
    WHERE c.relname IN ('multicolumnpkey', 'updatetest', 'person', 'person_address') 
        AND n.nspname = 'public' AND c.relnamespace = n.oid;

COMMIT;

