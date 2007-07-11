BEGIN;

DROP VIEW IF EXISTS "baseten".relationships CASCADE;

-- Constraint names
-- Helps joining to queries on pg_constraint
CREATE OR REPLACE VIEW "baseten".conname AS
SELECT 
    c.oid,
    "baseten".array_accum (a1.attname) AS keynames,
    "baseten".array_accum (a2.attname) AS fkeynames
FROM pg_constraint c
INNER JOIN pg_attribute a1 ON (
    c.conrelid = a1.attrelid AND
    a1.attnum = ANY (c.conkey)
)
INNER JOIN pg_attribute a2 ON (
    c.confrelid = a2.attrelid AND
    a2.attnum = ANY (c.confkey)
)
GROUP BY c.oid;
COMMENT ON VIEW "baseten".conname IS 'Constraint names';
COMMENT ON COLUMN "baseten".conname.oid IS 'Constraint oid';
COMMENT ON COLUMN "baseten".conname.keynames IS 'Column names';
COMMENT ON COLUMN "baseten".conname.fkeynames IS 'Foreign column names';
REVOKE ALL PRIVILEGES ON "baseten".conname FROM PUBLIC;
GRANT SELECT ON "baseten".conname TO basetenread;


-- Fkeys in pkeys
CREATE OR REPLACE VIEW "baseten".fkeypkeycount AS
-- In the sub-select we search for all primary keys and their columns.
-- Then we count the foreign keys the columns of which are contained
-- in those of the primary keys'. Finally we filter out anything irrelevant.
SELECT
	p1.conrelid,
	COUNT (p1.oid) AS count
FROM pg_constraint p1
INNER JOIN (
	SELECT
		conrelid,
		conkey
	FROM pg_constraint
	WHERE contype = 'p'
) AS p2 ON (
	p1.conrelid = p2.conrelid AND 
	p2.conkey @> p1.conkey
)
WHERE (p1.contype = 'f')
GROUP BY p1.conrelid;
COMMENT ON VIEW "baseten".fkeypkeycount IS 'Number of foreign key constraints included in primary keys';
COMMENT ON COLUMN "baseten".fkeypkeycount.conrelid IS 'Primary key constraint oid';
COMMENT ON COLUMN "baseten".fkeypkeycount.count IS 'Foreign key constraint count';
REVOKE ALL PRIVILEGES ON "baseten".fkeypkeycount FROM PUBLIC;
GRANT SELECT ON "baseten".fkeypkeycount TO basetenread;


CREATE OR REPLACE VIEW "baseten".foreignkey AS
SELECT
	c.oid		AS conoid,
	c.conname	AS name,
	c.conrelid	AS srcoid,
	ns1.nspname	AS srcnspname,
	cl1.relname	AS srcrelname,
	n.keynames	AS srcfnames,
	c.confrelid	AS dstoid,
	ns2.nspname	AS dstnspname,
	cl2.relname	AS dstrelname,
	n.fkeynames AS dstfnames
FROM pg_constraint c
-- Check whether dst is a primary key
LEFT JOIN pg_constraint p ON (
    c.confrelid = p.conrelid AND 
    p.contype = 'p' AND
    p.conkey = c.confkey
)
-- Constrained fields' names
INNER JOIN "baseten".conname n ON (c.oid = n.oid)
-- Relation names
INNER JOIN pg_class cl1 ON (cl1.oid = c.conrelid)
INNER JOIN pg_class cl2 ON (cl2.oid = c.confrelid)
-- Namespace names
INNER JOIN pg_namespace ns1 ON (ns1.oid = cl1.relnamespace)
INNER JOIN pg_namespace ns2 ON (ns2.oid = cl2.relnamespace)
-- Only select foreign keys
WHERE c.contype = 'f';
COMMENT ON VIEW "baseten".foreignkey IS 'Foreign keys';
COMMENT ON COLUMN "baseten".foreignkey.conoid IS 'Constraint oid';
COMMENT ON COLUMN "baseten".foreignkey.srcoid IS 'Referencing table''s oid';
COMMENT ON COLUMN "baseten".foreignkey.srcnspname IS 'Referencing namespace''s name';
COMMENT ON COLUMN "baseten".foreignkey.srcrelname IS 'Referencing table''s name';
COMMENT ON COLUMN "baseten".foreignkey.srcfnames IS 'Referencing columns'' names';
COMMENT ON COLUMN "baseten".foreignkey.dstoid IS 'Referenced table''s oid';
COMMENT ON COLUMN "baseten".foreignkey.dstnspname IS 'Referenced namespace''s name';
COMMENT ON COLUMN "baseten".foreignkey.dstrelname IS 'Referenced table''s name';
COMMENT ON COLUMN "baseten".foreignkey.dstfnames IS 'Referenced columns'' names';
REVOKE ALL PRIVILEGES ON "baseten".foreignkey FROM PUBLIC;
GRANT SELECT ON "baseten".foreignkey TO basetenread;


CREATE OR REPLACE VIEW "baseten".onetomany AS
SELECT
	conoid,
	NULL::OID	AS inverseconoid,
	name,
	srcoid,
	srcnspname,
	srcrelname,
	srcfnames,
	dstoid,
	dstnspname,
	dstrelname,
	dstfnames,
	true 		AS isinverse
FROM "baseten".foreignkey
UNION
SELECT
	NULL::OID	AS conoid,
	conoid		AS inverseconoid,
	srcrelname	AS name,
	dstoid		AS srcoid,
	dstnspname	AS srcnspname,
	dstrelname	AS srcrelname,
	dstfnames	AS srcfnames,
	srcoid		AS dstoid,
	srcnspname	AS dstnspname,
	srcrelname	AS dstrelname,
	srcfnames	AS dstfnames,
	false		AS isinverse
FROM "baseten".foreignkey;
COMMENT ON VIEW "baseten".onetomany IS 'One-to-many relationships';
COMMENT ON COLUMN "baseten".onetomany.isinverse IS 'If true, current relationship is many-to-one.';
REVOKE ALL PRIVILEGES ON "baseten".onetomany FROM PUBLIC;
GRANT SELECT ON "baseten".onetomany TO basetenread;


CREATE OR REPLACE VIEW "baseten".onetoone AS
SELECT
	f1.conoid,
	f2.conoid		AS inverseconoid,
	f1.name,
	f1.srcoid,
	f1.srcnspname,
	f1.srcrelname,
	f1.srcfnames,
	f1.dstoid,
	f1.dstnspname,
	f1.dstrelname,
	f1.dstfnames
FROM "baseten".foreignkey f1
INNER JOIN "baseten".foreignkey f2 ON (
	f1.srcoid = f2.dstoid AND
	f2.srcoid = f1.dstoid
);
COMMENT ON VIEW "baseten".onetoone IS 'One-to-one relationships';
REVOKE ALL PRIVILEGES ON "baseten".onetomany FROM PUBLIC;
GRANT SELECT ON "baseten".onetomany TO basetenread;


CREATE OR REPLACE VIEW "baseten".manytomany AS
SELECT
	f1.conoid		AS conoid,
	f2.conoid		AS inverseconoid,
	f1.dstrelname	AS name,
	f1.dstoid 		AS srcoid,
	f1.dstnspname 	AS srcnspname,
	f1.dstrelname 	AS srcrelname,
	f1.dstfnames 	AS srcfnames,
	f2.dstoid,
	f2.dstnspname,
	f2.dstrelname,
	f2.dstfnames,
	f1.srcoid		AS helperoid,
	f1.srcnspname	AS helpernspname,
	f1.srcrelname	AS helperrelname,
	array_cat (f1.srcfnames, f2.srcfnames) AS helperfnames
FROM "baseten".foreignkey f1
INNER JOIN "baseten".foreignkey f2 ON (
	f1.srcoid = f2.srcoid AND
	f1.dstoid <> f2.dstoid
)
-- Primary key needs to include exactly two foreign keys and possibly other columns.
INNER JOIN "baseten".fkeypkeycount r ON (
	r.conrelid = f1.srcoid AND
	r.count = 2
);
COMMENT ON VIEW "baseten".manytomany IS 'Many-to-many relationships';
REVOKE ALL PRIVILEGES ON "baseten".manytomany FROM PUBLIC;
GRANT SELECT ON "baseten".manytomany TO basetenread;


COMMIT;