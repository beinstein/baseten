\unset ON_ERROR_ROLLBACK
\set ON_ERROR_STOP


DROP DATABASE IF EXISTS basetentest;
CREATE DATABASE basetentest ENCODING 'UNICODE';
\connect basetentest


\i ../BaseTenModifications.sql


BEGIN TRANSACTION;

CREATE FUNCTION prepare () RETURNS VOID AS $$
    BEGIN
        PERFORM rolname FROM pg_roles WHERE rolname = 'baseten_test_user';
        IF FOUND THEN
            DROP ROLE baseten_test_user;
        END IF;

        PERFORM rolname FROM pg_roles WHERE rolname = 'baseten_test_owner';
        IF FOUND THEN
            DROP ROLE baseten_test_owner;
        END IF;

        CREATE ROLE baseten_test_user WITH 
            NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN IN ROLE basetenuser;
        REVOKE ALL PRIVILEGES ON DATABASE basetentest FROM baseten_test_user;
        CREATE ROLE baseten_test_owner WITH 
            NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN IN ROLE basetenowner;
    END;
$$ VOLATILE LANGUAGE plpgsql;
SELECT prepare ();
DROP FUNCTION prepare ();


-- Type tests

CREATE TABLE point_test (
    value point
);
INSERT INTO point_test VALUES ('(2.005, 10.0)');
GRANT SELECT, INSERT, UPDATE, DELETE ON point_test TO baseten_test_user;


CREATE TABLE float4_test (
    value float4
);
INSERT INTO float4_test VALUES (2.71828);
GRANT SELECT, INSERT, UPDATE, DELETE ON float4_test TO baseten_test_user;


CREATE TABLE float8_test (
    value float8
);
INSERT INTO float8_test VALUES (2.71828);
GRANT SELECT, INSERT, UPDATE, DELETE ON float8_test TO baseten_test_user;


CREATE TABLE text_test (
    value TEXT
);
INSERT INTO text_test VALUES ('aàáâäå');
GRANT SELECT, INSERT, UPDATE, DELETE ON text_test TO baseten_test_user;


CREATE TABLE int2_test (
    value int2
);
INSERT INTO int2_test VALUES (12);
GRANT SELECT, INSERT, UPDATE, DELETE ON int2_test TO baseten_test_user;


CREATE TABLE int4_test (
    value int4
);
INSERT INTO int4_test VALUES (14);
GRANT SELECT, INSERT, UPDATE, DELETE ON int4_test TO baseten_test_user;


CREATE TABLE int8_test (
    value int8
);
INSERT INTO int8_test VALUES (16);
GRANT SELECT, INSERT, UPDATE, DELETE ON int8_test TO baseten_test_user;

-- BaseTen tests

CREATE TABLE test (
    id SERIAL PRIMARY KEY,
    value VARCHAR (255)
);
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'test' AND n.nspname = 'public' AND c.relnamespace = n.oid;

CREATE VIEW test_v AS SELECT * FROM test;
INSERT INTO baseten.view_pkey (nspname, relname, attname) VALUES ('public', 'test_v', 'id');
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'test_v' AND n.nspname = 'public' AND c.relnamespace = n.oid;

CREATE TABLE "Pkeytest" (
    "Id" INTEGER PRIMARY KEY,
    value VARCHAR (255)
);
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'Pkeytest' AND n.nspname = 'public' AND c.relnamespace = n.oid;

GRANT SELECT, INSERT, UPDATE, DELETE ON test TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON test_v TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON "Pkeytest" TO baseten_test_user;
GRANT UPDATE, SELECT ON test_id_seq TO baseten_test_user;

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
    value VARCHAR (255)
);
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'test1' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

CREATE VIEW test1_v AS SELECT * FROM test1;
INSERT INTO baseten.view_pkey (nspname, relname, attname) VALUES ('Fkeytest', 'test1_v', 'id');
CREATE RULE "insert_test1" AS ON INSERT TO test1_v DO INSTEAD 
    INSERT INTO test1 (value) VALUES (NEW.value) RETURNING *;
CREATE RULE "update_test1" AS ON UPDATE TO test1_v DO INSTEAD 
    UPDATE test1 SET id = NEW.id, value = NEW.value WHERE id = OLD.id;
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'test1_v' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

CREATE TABLE test2 (
    id SERIAL PRIMARY KEY,
    value VARCHAR (255),
    fkt1id INTEGER CONSTRAINT fkt1 REFERENCES test1 (id) ON UPDATE CASCADE ON DELETE SET NULL
);
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'test2' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

CREATE VIEW test2_v AS SELECT * FROM test2;
INSERT INTO baseten.view_pkey (nspname, relname, attname) VALUES ('Fkeytest', 'test2_v', 'id');
CREATE RULE "insert_test2" AS ON INSERT TO test2_v DO INSTEAD
    INSERT INTO test2 (value, fkt1id) VALUES (NEW.value, NEW.fkt1id) RETURNING *;
CREATE RULE "update_test2" AS ON UPDATE TO test2_v DO INSTEAD 
    UPDATE test2 SET id = NEW.id, value = NEW.value, fkt1id = NEW.fkt1id WHERE id = OLD.id RETURNING *;
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'test2_v' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

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
    r1 INTEGER UNIQUE CONSTRAINT foo REFERENCES ototest1 (id)
);
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname IN ('ototest1', 'ototest2') AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

CREATE VIEW ototest1_v AS SELECT * FROM ototest1;
CREATE VIEW ototest2_v AS SELECT * FROM ototest2;
INSERT INTO baseten.view_pkey (nspname, relname, attname) VALUES ('Fkeytest', 'ototest1_v', 'id');
INSERT INTO baseten.view_pkey (nspname, relname, attname) VALUES ('Fkeytest', 'ototest2_v', 'id');
CREATE RULE "insert_ototest1" AS ON INSERT TO ototest1_v DO INSTEAD
    INSERT INTO ototest1 DEFAULT VALUES RETURNING *;
CREATE RULE "insert_ototest2" AS ON INSERT TO ototest2_v DO INSTEAD
    INSERT INTO ototest2 (r1) VALUES (NEW.r1) RETURNING *;
CREATE RULE "update_ototest1" AS ON UPDATE TO ototest1_v DO INSTEAD 
    UPDATE ototest1 SET id = NEW.id WHERE id = OLD.id RETURNING *;
CREATE RULE "update_ototest2" AS ON UPDATE TO ototest2_v DO INSTEAD 
    UPDATE ototest2 SET id = NEW.id, r1 = NEW.r1 WHERE id = OLD.id RETURNING *;
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'ototest1_v' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'ototest2_v' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

GRANT SELECT, INSERT, UPDATE, DELETE ON ototest1 TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ototest1_v TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ototest2 TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ototest2_v TO baseten_test_user;

INSERT INTO ototest1 (id) VALUES (1);
INSERT INTO ototest1 (id) VALUES (2);
INSERT INTO ototest2 (id, r1) VALUES (1, 2);
INSERT INTO ototest2 (id, r1) VALUES (2, 1);
INSERT INTO ototest2 (id, r1) VALUES (3, null);


-- Many-to-many
CREATE TABLE mtmtest1 (
    id SERIAL PRIMARY KEY,
    value1 VARCHAR (255)
);
GRANT USAGE ON SEQUENCE mtmtest1_id_seq TO PUBLIC;
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'mtmtest1' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

CREATE VIEW mtmtest1_v AS SELECT * FROM mtmtest1;
INSERT INTO baseten.view_pkey (nspname, relname, attname) VALUES ('Fkeytest', 'mtmtest1_v', 'id');
CREATE RULE "insert_mtmtest1" AS ON INSERT TO mtmtest1_v DO INSTEAD
    INSERT INTO mtmtest1 (value1) VALUES (NEW.value1) RETURNING *;
CREATE RULE "update_mtmtest1" AS ON UPDATE TO mtmtest1_v DO INSTEAD 
    UPDATE mtmtest1 SET id = NEW.id, value1 = NEW.value1 WHERE id = OLD.id;
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'mtmtest1_v' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

CREATE TABLE mtmtest2 (
    id SERIAL PRIMARY KEY,
    value2 VARCHAR (255)
);
GRANT USAGE ON SEQUENCE mtmtest2_id_seq TO PUBLIC;
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'mtmtest2' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

CREATE VIEW mtmtest2_v AS SELECT * FROM mtmtest2;
INSERT INTO baseten.view_pkey (nspname, relname, attname) VALUES ('Fkeytest', 'mtmtest2_v', 'id');
CREATE RULE "insert_mtmtest2" AS ON INSERT TO mtmtest2_v DO INSTEAD
    INSERT INTO mtmtest2 (value2) VALUES (NEW.value2) RETURNING *;
CREATE RULE "update_mtmtest2" AS ON UPDATE TO mtmtest2_v DO INSTEAD 
    UPDATE mtmtest2 SET id = NEW.id, value2 = NEW.value2 WHERE id = OLD.id;
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'mtmtest2_v' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

CREATE TABLE mtmrel1 (
    id1 INTEGER CONSTRAINT foreignobject REFERENCES mtmtest1 (id),
    id2 INTEGER CONSTRAINT object REFERENCES mtmtest2 (id),
    PRIMARY KEY (id1, id2)
);
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'mtmrel1' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;


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
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'mtocollectiontest1' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

CREATE VIEW mtocollectiontest1_v AS SELECT * FROM mtocollectiontest1;
INSERT INTO baseten.view_pkey (nspname, relname, attname) VALUES ('Fkeytest', 'mtocollectiontest1_v', 'id');
CREATE RULE "insert_mtocollectiontest1" AS ON INSERT TO mtocollectiontest1_v DO INSTEAD
    INSERT INTO mtocollectiontest1 DEFAULT VALUES RETURNING *;
CREATE RULE "update_mtocollectiontest1" AS ON UPDATE TO mtocollectiontest1_v DO INSTEAD 
    UPDATE mtocollectiontest1 SET id = NEW.id WHERE id = OLD.id;
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'mtocollectiontest1_v' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

CREATE TABLE mtocollectiontest2 (
    id SERIAL PRIMARY KEY,
    mid INTEGER CONSTRAINT m REFERENCES mtocollectiontest1 (id)
);
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'mtocollectiontest2' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

CREATE VIEW mtocollectiontest2_v AS SELECT * FROM mtocollectiontest2;
INSERT INTO baseten.view_pkey (nspname, relname, attname) VALUES ('Fkeytest', 'mtocollectiontest2_v', 'id');
CREATE RULE "insert_mtocollectiontest2" AS ON INSERT TO mtocollectiontest2_v DO INSTEAD
    INSERT INTO mtocollectiontest2 DEFAULT VALUES RETURNING *;
CREATE RULE "update_mtocollectiontest2" AS ON UPDATE TO mtocollectiontest2_v DO INSTEAD 
    UPDATE mtocollectiontest2 SET id = NEW.id, mid = NEW.mid WHERE id = OLD.id RETURNING *;
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'mtocollectiontest2_v' AND n.nspname = 'Fkeytest' AND c.relnamespace = n.oid;

GRANT USAGE ON mtocollectiontest1_id_seq TO PUBLIC;
GRANT USAGE ON mtocollectiontest2_id_seq TO PUBLIC;

GRANT SELECT, INSERT, UPDATE, DELETE ON mtocollectiontest1 TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON mtocollectiontest2 TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON mtocollectiontest1_v TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON mtocollectiontest2_v TO baseten_test_user;

INSERT INTO mtocollectiontest1 DEFAULT VALUES;
INSERT INTO mtocollectiontest1 DEFAULT VALUES;

INSERT INTO mtocollectiontest2 DEFAULT VALUES;
INSERT INTO mtocollectiontest2 DEFAULT VALUES;
INSERT INTO mtocollectiontest2 DEFAULT VALUES;


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
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'multicolumnpkey' AND n.nspname = 'public' AND c.relnamespace = n.oid;

-- Update and delete by entity & predicate
CREATE TABLE updatetest (
    id SERIAL PRIMARY KEY,
    value1 INTEGER
);
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname = 'updatetest' AND n.nspname = 'public' AND c.relnamespace = n.oid;
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
ALTER TABLE ONLY person ADD CONSTRAINT person_pkey PRIMARY KEY (id);
ALTER TABLE ONLY person_address ADD CONSTRAINT person_address_pkey PRIMARY KEY (id);
ALTER TABLE ONLY person ADD CONSTRAINT person_address_fkey FOREIGN KEY (address) REFERENCES person_address(id);
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n WHERE c.relname IN ('person', 'person_address') 
    AND n.nspname = 'public' AND c.relnamespace = n.oid;
GRANT SELECT, INSERT, UPDATE, DELETE ON person TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON person_address TO baseten_test_user;
GRANT USAGE ON SEQUENCE person_id_seq TO baseten_test_user;
GRANT USAGE ON SEQUENCE person_soulmate_seq TO baseten_test_user;
GRANT USAGE ON SEQUENCE person_address_id_seq TO baseten_test_user;

INSERT INTO person_address VALUES (1, 'Mannerheimintie 1');
INSERT INTO person VALUES (1, 'nzhuk', 1, 1);


-- Test a non-ASCII name.
CREATE TABLE ♨ (id SERIAL PRIMARY KEY, value VARCHAR (255));
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n
	WHERE c.relnamespace = n.oid AND n.nspname = 'public' AND c.relname = '♨';

GRANT SELECT, INSERT, UPDATE, DELETE ON ♨ TO baseten_test_user;
GRANT USAGE ON SEQUENCE ♨_id_seq TO baseten_test_user;
INSERT INTO ♨ (value) VALUES ('test1');
INSERT INTO ♨ (value) VALUES ('test2');
INSERT INTO ♨ (value) VALUES ('test3');


-- Test an astral character name.
CREATE TABLE 𐄤𐄧𐄪𐄷 (id SERIAL PRIMARY KEY, value VARCHAR (255));
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n
	WHERE c.relnamespace = n.oid AND n.nspname = 'public' AND c.relname = '𐄤𐄧𐄪𐄷';

GRANT SELECT, INSERT, UPDATE, DELETE ON 𐄤𐄧𐄪𐄷 TO baseten_test_user;
GRANT USAGE ON SEQUENCE 𐄤𐄧𐄪𐄷_id_seq TO baseten_test_user;
INSERT INTO 𐄤𐄧𐄪𐄷 (value) VALUES ('test1');
INSERT INTO 𐄤𐄧𐄪𐄷 (value) VALUES ('test2');
INSERT INTO 𐄤𐄧𐄪𐄷 (value) VALUES ('test3');


CREATE TABLE datetest (
    id SERIAL PRIMARY KEY, 
    d1 date DEFAULT CURRENT_TIMESTAMP::date, 
    d2 TIMESTAMP (6) WITH TIME ZONE DEFAULT clock_timestamp ()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON datetest TO baseten_test_user;
GRANT USAGE ON SEQUENCE datetest_id_seq TO baseten_test_user;
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n
	WHERE c.relnamespace = n.oid AND n.nspname = 'public' AND c.relname = 'datetest';
INSERT INTO datetest DEFAULT VALUES;
INSERT INTO datetest DEFAULT VALUES;
INSERT INTO datetest DEFAULT VALUES;


CREATE TABLE fkeytest_add (
    id INTEGER PRIMARY KEY,
    value VARCHAR (255)
);
CREATE TABLE fkeytest_add_rel (
    id INTEGER PRIMARY KEY,
    fid INTEGER NOT NULL REFERENCES fkeytest_add (id),
    value VARCHAR (255)
);
SELECT baseten.enable (c.oid) FROM pg_class c, pg_namespace n
	WHERE c.relnamespace = n.oid AND n.nspname = 'public' AND c.relname IN ('fkeytest_add', 'fkeytest_add_rel');
INSERT INTO fkeytest_add (id, value) VALUES (1, 'fkeytest_add');
GRANT SELECT, INSERT, UPDATE, DELETE ON fkeytest_add TO baseten_test_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON fkeytest_add_rel TO baseten_test_user;

SELECT baseten.refresh_caches ();

COMMIT;

VACUUM FULL ANALYZE;

