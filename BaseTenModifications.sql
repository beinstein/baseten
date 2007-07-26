--
-- BaseTenModifications.sql
-- BaseTen
--
-- Copyright (C) 2006 Marko Karppinen & Co. LLC.
--
-- Before using this software, please review the available licensing options
-- by visiting http://www.karppinen.fi/baseten/licensing/ or by contacting
-- us at sales@karppinen.fi. Without an additional license, this software
-- may be distributed only in compliance with the GNU General Public License.
--
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License, version 2.0,
-- as published by the Free Software Foundation.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
--
-- $Id$
--


BEGIN;
CREATE LANGUAGE plpgsql;
COMMIT;


DROP SCHEMA IF EXISTS "baseten" CASCADE;


-- Groups for BaseTen users
BEGIN;
DROP ROLE IF EXISTS basetenread;
DROP ROLE IF EXISTS basetenuser;
CREATE ROLE basetenread WITH
	INHERIT
	NOSUPERUSER
	NOCREATEDB
	NOCREATEROLE
	NOLOGIN;
CREATE ROLE basetenuser WITH
	INHERIT
	NOSUPERUSER
	NOCREATEDB
	NOCREATEROLE
	NOLOGIN;
COMMENT ON ROLE basetenread IS 'Read-only rights for BaseTen relations';
COMMENT ON ROLE basetenuser IS 'Read and write access to BaseTen relations';
COMMIT;


BEGIN; -- Schema, helper functions and classes

CREATE SCHEMA "baseten";
COMMENT ON SCHEMA "baseten" IS 'Schema used by BaseTen. Please use the provided functions to edit.';
REVOKE ALL PRIVILEGES ON SCHEMA "baseten" FROM PUBLIC;
GRANT USAGE ON SCHEMA "baseten" TO basetenread;

CREATE TEMPORARY SEQUENCE "basetenlocksequence";
REVOKE ALL PRIVILEGES ON SEQUENCE "basetenlocksequence" FROM PUBLIC;


-- Helper functions

CREATE FUNCTION "baseten".array_cat (anyarray, anyarray) 
	RETURNS anyarray AS $$
	SELECT $1 || $2;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".array_cat (anyarray, anyarray) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".array_cat (anyarray, anyarray) TO basetenread;


-- From the manual
CREATE AGGREGATE "baseten".array_accum
( 
    sfunc = array_append, 
    basetype = anyelement, 
    stype = anyarray, 
    initcond = '{}' 
);
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".array_accum (anyelement) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".array_accum (anyelement) TO basetenread;


CREATE AGGREGATE "baseten".array_cat
( 
	sfunc = "baseten".array_cat, 
	basetype = anyarray, 
	stype = anyarray, 
	initcond = '{}' 
);
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".array_cat (anyarray) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".array_cat (anyarray) TO basetenread;


-- Takes two one-dimensional arrays the first one of which is smaller or equal in size to the other.
-- Returns an array where each corresponding element is concatenated so that the third paramter 
-- comes in the middle
CREATE FUNCTION "baseten".array_cat_each (TEXT [], TEXT [], TEXT) 
    RETURNS TEXT [] AS $$
DECLARE
    source1 ALIAS FOR $1;
    source2 ALIAS FOR $2;
    delim ALIAS FOR $3;
    destination TEXT [];
BEGIN
    FOR i IN array_lower (source1, 1)..array_upper (source1, 1) LOOP
        destination [i] = source1 [i] || delim || source2 [i];
    END LOOP;
    RETURN destination;
END;
$$ IMMUTABLE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES 
	ON FUNCTION "baseten".array_cat_each (TEXT [], TEXT [], TEXT) FROM PUBLIC;


-- Prepends each element of an array with the first parameter
CREATE FUNCTION "baseten".array_prepend_each (TEXT, TEXT []) 
    RETURNS TEXT [] AS $$
DECLARE
    prefix ALIAS FOR $1;
    source ALIAS FOR $2;
    destination TEXT [];
BEGIN
    FOR i IN array_lower (source, 1)..array_upper (source, 1) LOOP
        destination [i] = prefix || source [i];
    END LOOP;
    RETURN destination;
END;
$$ IMMUTABLE LANGUAGE PLPGSQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES 
	ON FUNCTION "baseten".array_prepend_each (TEXT, TEXT [])  FROM PUBLIC;


CREATE FUNCTION "baseten".running_backend_pids () 
RETURNS SETOF INTEGER AS $$
    SELECT 
        pg_stat_get_backend_pid (idset.id) AS pid 
    FROM pg_stat_get_backend_idset () AS idset (id);
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".running_backend_pids () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".running_backend_pids () TO basetenread;


CREATE FUNCTION "baseten".LockNextId () RETURNS BIGINT AS $$
    SELECT nextval ('basetenlocksequence');
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON  FUNCTION "baseten".LockNextId () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".LockNextId () TO basetenuser;


-- No privileges on types
CREATE TYPE "baseten".TableType AS (
    oid OID,
    description TEXT
);


CREATE TYPE "baseten".viewtype AS (
	oid OID,
	parent OID,
	root OID,
	generation SMALLINT
);


CREATE FUNCTION "baseten".TableType (OID, TEXT) RETURNS "baseten".TableType AS $$
    SELECT $1, $2;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".TableType (OID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".TableType (OID, TEXT) TO basetenread;


-- Debugging helper
CREATE FUNCTION "baseten".oidof (TEXT, TEXT) RETURNS "baseten".tabletype AS $$
	SELECT c.oid, c.relname::TEXT
	FROM pg_class c
	INNER JOIN pg_namespace n ON (c.relnamespace = n.oid)
	WHERE c.relname = $2 AND n.nspname = $1;
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".oidof (TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".oidof (TEXT, TEXT) TO basetenread;


CREATE TABLE "baseten".ViewPrimaryKey (
    nspname NAME NOT NULL DEFAULT 'public',
    relname NAME NOT NULL,
    attname NAME NOT NULL,
    PRIMARY KEY (nspname, relname, attname)
);
COMMENT ON TABLE "baseten".ViewPrimaryKey IS 'Primary keys for views. This table may be modified by hand.';
COMMENT ON COLUMN "baseten".ViewPrimaryKey.nspname IS 'Namespace name';
COMMENT ON COLUMN "baseten".ViewPrimaryKey.relname IS 'View name';
COMMENT ON COLUMN "baseten".ViewPrimaryKey.attname IS 'Column name';
-- FIXME: privileges?
GRANT SELECT ON TABLE "baseten".ViewPrimaryKey TO basetenread;


CREATE VIEW "baseten".PrimaryKey AS
    SELECT * FROM (
        SELECT a.attrelid AS oid, cl.relkind, n.nspname, cl.relname, a.attnum, a.attname AS attname, t.typname AS type
            FROM pg_attribute a, pg_constraint co, pg_type t, pg_class cl, pg_namespace n
            WHERE co.conrelid = a.attrelid 
                AND a.attnum = ANY (co.conkey)
                AND a.atttypid = t.oid
                AND co.contype = 'p'
                AND cl.oid = a.attrelid
                AND n.oid = cl.relnamespace
                AND cl.relkind = 'r'
        UNION
        SELECT c.oid AS oid, c.relkind, n.nspname, c.relname, a.attnum, vpkey.attname AS fieldname, t.typname AS type
            FROM "baseten".ViewPrimaryKey vpkey, pg_attribute a, pg_type t, pg_namespace n, pg_class c
            WHERE vpkey.nspname = n.nspname
                AND vpkey.relname = c.relname
                AND c.relnamespace = n.oid
                AND a.attname = vpkey.attname
                AND a.attrelid = c.oid
                AND a.atttypid = t.oid
                AND c.relkind = 'v'
    ) r
    ORDER BY oid ASC, attnum ASC;
REVOKE ALL PRIVILEGES ON "baseten".PrimaryKey FROM PUBLIC;
GRANT SELECT ON "baseten".PrimaryKey TO basetenread;


-- Note that system views aren't correctly listed.
CREATE VIEW "baseten".viewdependency_v AS 
	SELECT DISTINCT 
		d1.refobjid	AS viewoid, 
		n1.oid		AS viewnamespace, 
		n1.nspname 	AS viewnspname, 
		c1.relname 	AS viewrelname, 
		d2.refobjid AS reloid, 
		c2.relkind 	AS relkind, 
		n2.oid 		AS relnamespace, 
		n2.nspname 	AS relnspname, 
		c2.relname 	AS relname 
	FROM pg_depend d1
	INNER JOIN pg_rewrite r ON r.oid = d1.objid AND r.ev_class = d1.refobjid AND rulename = '_RETURN'
	INNER JOIN pg_depend d2 ON r.oid = d2.objid AND d2.refobjid <> d1.refobjid AND d2.deptype = 'n'
	INNER JOIN pg_class c1 ON c1.oid = d1.refobjid AND c1.relkind = 'v'
	INNER JOIN pg_class c2 ON c2.oid = d2.refobjid
	INNER JOIN pg_namespace n1 ON n1.oid = c1.relnamespace
	INNER JOIN pg_namespace n2 ON n2.oid = c2.relnamespace
	INNER JOIN pg_class c3 ON c3.oid = d1.classid AND c3.relname = 'pg_rewrite'
	INNER JOIN pg_class c4 ON c4.oid = d1.refclassid AND c4.relname = 'pg_class'
	WHERE d1.deptype = 'n';
REVOKE ALL PRIVILEGES ON "baseten".viewdependency_v FROM PUBLIC;
GRANT SELECT ON "baseten".viewdependency_v TO basetenread;


-- SELECT * FROM viewdependency_v can take ~300 ms.
CREATE TABLE "baseten".viewdependency AS SELECT * FROM "baseten".viewdependency_v LIMIT 0;
REVOKE ALL PRIVILEGES ON "baseten".viewdependency FROM PUBLIC;
GRANT SELECT ON "baseten".viewdependency TO basetenread;


CREATE FUNCTION "baseten".viewhierarchy (OID) RETURNS SETOF "baseten".viewtype AS $$
DECLARE
	tableoid ALIAS FOR $1;
	retval "baseten".viewtype;
BEGIN
	-- First return the table itself.
	retval.root = tableoid;
	retval.parent = NULL;
	retval.generation = 0::SMALLINT;
	retval.oid = tableoid;
	RETURN NEXT retval;

	-- Fetch dependant views.
	FOR retval IN SELECT * FROM "baseten".viewhierarchy (tableoid, tableoid, 1) 
	LOOP
		RETURN NEXT retval;
	END LOOP;
	RETURN;
END;
$$ STABLE LANGUAGE PLPGSQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".viewhierarchy (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".viewhierarchy (OID) TO basetenread;


CREATE FUNCTION "baseten".viewhierarchy (OID, OID, INTEGER) 
	RETURNS SETOF "baseten".viewtype AS $$
DECLARE
	parent ALIAS FOR $1;
	root ALIAS FOR $2;
	generation ALIAS FOR $3;
	currentoid OID;
	retval "baseten".viewtype;
	subview "baseten".viewtype;
BEGIN
	retval.root = root;
	retval.parent = parent;
	retval.generation = generation::SMALLINT;

	-- Fetch dependant views
	FOR currentoid IN SELECT viewoid FROM "baseten".viewdependency WHERE reloid = parent 
	LOOP
		retval.oid := currentoid;
		RETURN NEXT retval;

		-- Recursion to subviews
		FOR subview IN SELECT * 
		FROM "baseten".viewhierarchy (currentoid, root, generation + 1) LOOP
			RETURN NEXT subview;
		END LOOP;
	END LOOP;
	RETURN;
END;
$$ STABLE LANGUAGE PLPGSQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".viewhierarchy (OID, OID, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".viewhierarchy (OID, OID, INTEGER) TO basetenread;


CREATE FUNCTION "baseten".matchingviews (OID, NAME [])
	RETURNS SETOF OID AS $$
	SELECT v.oid FROM "baseten".viewhierarchy ($1) v
	INNER JOIN (
		SELECT 
			attrelid, 
			"baseten".array_accum (attname) AS fnames
		FROM pg_attribute
		GROUP BY attrelid
	) a1 ON (a1.attrelid = v.oid)
	LEFT JOIN (
		SELECT
			attrelid,
			"baseten".array_accum (attname) AS fnames
		FROM pg_attribute
		GROUP BY attrelid
	) a2 ON (a2.attrelid = v.parent)
	WHERE (
		v.parent IS NULL OR 
		(
			a1.fnames @> $2 AND
			a2.fnames @> $2
		)
	)
$$ STABLE LANGUAGE SQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".matchingviews (OID, NAME []) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".matchingviews (OID, NAME []) TO basetenread;


-- Constraint names
-- Helps joining to queries on pg_constraint
CREATE VIEW "baseten".conname AS
SELECT 
    c.oid,
	"baseten".array_accum (a1.attnum) AS key,
	"baseten".array_accum (a2.attnum) AS fkey,
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
REVOKE ALL PRIVILEGES ON "baseten".conname FROM PUBLIC;
GRANT SELECT ON "baseten".conname TO basetenread;


-- Fkeys in pkeys
CREATE VIEW "baseten".fkeypkeycount AS
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
REVOKE ALL PRIVILEGES ON "baseten".fkeypkeycount FROM PUBLIC;
GRANT SELECT ON "baseten".fkeypkeycount TO basetenread;


CREATE VIEW "baseten".foreignkey AS
SELECT
	c1.oid				AS conoid,
	c1.conname			AS name,
	c1.conrelid			AS srcoid,
	ns1.oid				AS srcnsp,
	ns1.nspname			AS srcnspname,
	cl1.relname			AS srcrelname,
	n.keynames			AS srcfnames,
	c1.confrelid		AS dstoid,
	ns2.oid				AS dstnsp,
	ns2.nspname			AS dstnspname,
	cl2.relname			AS dstrelname,
	n.fkeynames 		AS dstfnames,
	c2.oid IS NOT NULL	AS srcisunique
FROM pg_constraint c1
-- Constrained fields' names
INNER JOIN "baseten".conname n ON (c1.oid = n.oid)
-- Is src key also unique?
LEFT JOIN pg_constraint c2 ON (
	c2.conrelid = c1.conrelid AND
	c2.contype = 'u' AND
	c2.conkey = n.key
)
-- Relation names
INNER JOIN pg_class cl1 ON (cl1.oid = c1.conrelid)
INNER JOIN pg_class cl2 ON (cl2.oid = c1.confrelid)
-- Namespace names
INNER JOIN pg_namespace ns1 ON (ns1.oid = cl1.relnamespace)
INNER JOIN pg_namespace ns2 ON (ns2.oid = cl2.relnamespace)
-- Only select foreign keys
WHERE c1.contype = 'f';
REVOKE ALL PRIVILEGES ON "baseten".foreignkey FROM PUBLIC;
GRANT SELECT ON "baseten".foreignkey TO basetenread;


CREATE VIEW "baseten".oneto_fk AS
SELECT
	conoid,
	name						AS name,
	srcrelname || '_' || name	AS inversename,
	srcoid,
	srcnsp,
	srcnspname,
	srcrelname,
	srcfnames,
	dstoid,
	dstnsp,
	dstnspname,
	dstrelname,
	dstfnames,
	true 		AS isinverse,
	srcisunique	AS istoone
FROM "baseten".foreignkey
UNION ALL
SELECT
    conoid,
	srcrelname || '_' || name	AS name,
	name						AS inversename,
	dstoid						AS srcoid,
	dstnsp						AS srcnsp,
	dstnspname					AS srcnspname,
	dstrelname					AS srcrelname,
	dstfnames					AS srcfnames,
	srcoid						AS dstoid,
	srcnsp						AS dstnsp,
	srcnspname					AS dstnspname,
	srcrelname					AS dstrelname,
	srcfnames					AS dstfnames,
	false						AS isinverse,
	srcisunique					AS istoone
FROM "baseten".foreignkey;
REVOKE ALL PRIVILEGES ON "baseten".oneto_fk FROM PUBLIC;
GRANT SELECT ON "baseten".oneto_fk TO basetenread;


CREATE VIEW "baseten".manytomany_fk AS
SELECT
	f1.conoid,
	f2.conoid		AS dstconoid,
	f1.name			AS name,
	f2.name			AS inversename,
	f1.dstoid 		AS srcoid,
	f1.dstnsp		AS srcnsp,
	f1.dstnspname 	AS srcnspname,
	f1.dstrelname 	AS srcrelname,
	f1.dstfnames 	AS srcfnames,
	f2.dstoid,
	f2.dstnsp,
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
INNER JOIN "baseten".fkeypkeycount c ON (
	c.conrelid = f1.srcoid AND
	c.count = 2
);
REVOKE ALL PRIVILEGES ON "baseten".manytomany_fk FROM PUBLIC;
GRANT SELECT ON "baseten".manytomany_fk TO basetenread;


CREATE VIEW "baseten".relationship_fk AS
	SELECT
		-- These three are sort of a primary key.
		conoid,
		NULL::OID AS dstconoid,
		false AS ismanytomany,
		
		srcoid, 
		dstoid,
		NULL::OID AS helperoid,
		srcfnames, 
		dstfnames,
		NULL::NAME [] AS helperfnames,
		isinverse,
		istoone
	FROM baseten.oneto_fk
	UNION ALL
	SELECT
		conoid,
		dstconoid,
		true AS ismanytomany,
		
		srcoid, 
		dstoid, 
		helperoid,
		srcfnames, 
		dstfnames,
		helperfnames,
		false AS isinverse,
		false AS istoone
	FROM baseten.manytomany_fk;
REVOKE ALL PRIVILEGES ON "baseten".relationship_fk FROM PUBLIC;
GRANT SELECT ON "baseten".relationship_fk TO basetenread;


CREATE VIEW "baseten".nameconflict1 AS
SELECT
	srcoid,
	dstoid,
	srcnsp,
	dstnsp,
	srcnspname,
	srcrelname,
	dstnspname,
	dstrelname,
	ARRAY [name] 				AS relationship_names
FROM "baseten".oneto_fk
WHERE srcnsp = dstnsp
UNION ALL
SELECT
	srcoid,
	dstoid,
	srcnsp,
	dstnsp,
	srcnspname,
	srcrelname,
	dstnspname,
	dstrelname,
	ARRAY [name, inversename]	AS relationship_names
FROM "baseten".manytomany_fk
WHERE srcnsp = dstnsp;
REVOKE ALL PRIVILEGES ON "baseten".nameconflict1 FROM PUBLIC;
GRANT SELECT ON "baseten".nameconflict1 TO basetenread;

 
-- Name conflicts for table relationships
CREATE VIEW "baseten".nameconflict AS
SELECT
	srcoid,
	dstoid,
	srcnspname,
	srcrelname,
	dstnspname,
	dstrelname,
	(1 < count (dstoid)) AS conflicts,
	"baseten".array_cat (relationship_names) AS relationship_names
FROM "baseten".nameconflict1
GROUP BY 
	srcoid, 
	dstoid, 
	srcnspname, 
	srcrelname, 
	dstnspname, 
	dstrelname;
REVOKE ALL PRIVILEGES ON "baseten".nameconflict FROM PUBLIC;
GRANT SELECT ON "baseten".nameconflict TO basetenread;


CREATE VIEW "baseten".oneto_ AS
SELECT
	conoid,
	name,
	inversename,
	srcoid,
	srcnspname,
	srcrelname,
	srcfnames,
	dstoid,
	dstnspname,
	dstrelname,
	dstfnames,
	isinverse,
	istoone
FROM "baseten".oneto_fk
UNION ALL
SELECT
	fk.conoid,
	n1.dstrelname,
	COALESCE (n2.dstrelname, fk.inversename),
	fk.srcoid,
	fk.srcnspname,
	fk.srcrelname,
	fk.srcfnames,
	fk.dstoid,
	fk.dstnspname,
	fk.dstrelname,
	fk.dstfnames,
	fk.isinverse,
	fk.istoone
FROM "baseten".oneto_fk fk
INNER JOIN "baseten".nameconflict n1 ON (
	fk.srcoid = n1.srcoid AND
	fk.dstoid = n1.dstoid AND
	n1.conflicts = false
)
LEFT JOIN "baseten".nameconflict n2 ON (
	fk.srcoid = n2.dstoid AND
	fk.dstoid = n2.srcoid AND
	n2.conflicts = false
);
REVOKE ALL PRIVILEGES ON "baseten".oneto_ FROM PUBLIC;
GRANT SELECT ON "baseten".oneto_ TO basetenread;


CREATE VIEW "baseten".onetoone AS
SELECT *
FROM "baseten".oneto_
WHERE istoone = true;
REVOKE ALL PRIVILEGES ON "baseten".onetoone FROM PUBLIC;
GRANT SELECT ON "baseten".onetoone TO basetenread;


CREATE VIEW "baseten".onetomany AS
SELECT *
FROM "baseten".oneto_
WHERE istoone = false;
REVOKE ALL PRIVILEGES ON "baseten".onetomany FROM PUBLIC;
GRANT SELECT ON "baseten".onetomany TO basetenread;


CREATE VIEW "baseten".manytomany AS
SELECT
	conoid,
	dstconoid,
	name,
	inversename,
	srcoid,
	srcnspname,
	srcrelname,
	srcfnames,
	dstoid,
	dstnspname,
	dstrelname,
	dstfnames,
	helperoid,
	helpernspname,
	helperrelname,
	helperfnames
FROM "baseten".manytomany_fk
UNION ALL
SELECT
	fk.conoid,
	fk.dstconoid,
	n1.dstrelname AS name,
	COALESCE (n2.dstrelname, fk.inversename) AS inversename,
	fk.srcoid,
	fk.srcnspname,
	fk.srcrelname,
	fk.srcfnames,
	fk.dstoid,
	fk.dstnspname,
	fk.dstrelname,
	fk.dstfnames,
	fk.helperoid,
	fk.helpernspname,
	fk.helperrelname,
	fk.helperfnames
FROM "baseten".manytomany_fk fk
INNER JOIN "baseten".nameconflict n1 ON (
	fk.srcoid = n1.srcoid AND
	fk.dstoid = n1.dstoid AND
	n1.conflicts = false
)
LEFT JOIN "baseten".nameconflict n2 ON (
	fk.srcoid = n2.dstoid AND
	fk.dstoid = n2.srcoid AND
	n2.conflicts = false
);
REVOKE ALL PRIVILEGES ON "baseten".manytomany FROM PUBLIC;
GRANT SELECT ON "baseten".manytomany TO basetenread;


CREATE FUNCTION "baseten".srcdstview ()
	RETURNS SETOF "baseten".relationship_fk AS $$
DECLARE
	retval "baseten".relationship_fk;
	srcoid OID;
	dstoid OID;
BEGIN
	FOR retval IN SELECT * FROM "baseten".relationship_fk r
	LOOP
		srcoid := retval.srcoid;
		dstoid := retval.dstoid;
		FOR retval.srcoid, retval.dstoid IN 
			SELECT m1.*, m2.*
			FROM "baseten".matchingviews (retval.srcoid, retval.srcfnames) m1 (oid)
			CROSS JOIN "baseten".matchingviews (retval.dstoid, retval.dstfnames) m2 (oid)
			WHERE NOT (m1.oid = srcoid AND m2.oid = dstoid)
		LOOP
			RETURN NEXT retval;
		END LOOP;
	END LOOP;
	RETURN;
END;
$$ STABLE LANGUAGE PLPGSQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".srcdstview () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".srcdstview () TO basetenread;


CREATE TABLE "baseten".srcdstview AS SELECT * FROM "baseten".srcdstview () LIMIT 0;
REVOKE ALL PRIVILEGES ON "baseten".srcdstview FROM PUBLIC;
GRANT SELECT ON "baseten".srcdstview TO basetenread;


CREATE VIEW "baseten".relationship_vv AS
	SELECT v1.*, 
		c2.relname	AS name,
		c1.relname	AS inversename,
		n1.nspname	AS srcnspname,
		c1.relname	AS srcrelname,
		n1.nspname	AS dstnspname,
		c2.relname	AS dstrelname,
		n3.nspname	AS helpernspname,
		c3.relname	AS helperrelname
	FROM "baseten".srcdstview v1
	INNER JOIN (
		SELECT srcoid, dstoid,
			COUNT (srcoid) AS count
		FROM "baseten".srcdstview
		GROUP BY srcoid, dstoid
	) v2 ON (
		v1.srcoid = v2.srcoid AND 
		v1.dstoid = v2.dstoid
	) 
	INNER JOIN pg_class c1 ON (c1.oid = v1.srcoid)
	INNER JOIN pg_class c2 ON (c2.oid = v1.dstoid)
	INNER JOIN pg_namespace n1 ON (c1.relnamespace = n1.oid)
	LEFT JOIN pg_class c3 ON (c3.oid = v1.helperoid)
	LEFT JOIN pg_namespace n3 ON (c3.relnamespace = n3.oid)
	WHERE (1 = v2.count AND c1.relnamespace = c2.relnamespace);


CREATE TABLE "baseten".relationship_v AS SELECT * FROM "baseten".relationship_vv LIMIT 0;
REVOKE ALL PRIVILEGES ON "baseten".relationship_v FROM PUBLIC;
GRANT SELECT ON "baseten".relationship_v TO basetenread;
				

CREATE VIEW "baseten".oneto_v AS
	SELECT
		conoid,
		name,
		inversename,
		srcoid,
		srcfnames,
		dstoid,
		dstfnames,
		isinverse,
		istoone
	FROM "baseten".relationship_v
	WHERE ismanytomany = false;
REVOKE ALL PRIVILEGES ON "baseten".oneto_v FROM PUBLIC;
GRANT SELECT ON "baseten".oneto_v TO basetenread;


CREATE VIEW "baseten".manytomany_v AS
	SELECT
		conoid,
		dstconoid,
		name,
		inversename,
		srcoid,
		srcfnames,
		dstoid,
		dstfnames
	FROM "baseten".relationship_v
	WHERE ismanytomany = true;
REVOKE ALL PRIVILEGES ON "baseten".manytomany_v FROM PUBLIC;
GRANT SELECT ON "baseten".manytomany_v TO basetenread;


-- For modification tracking
CREATE TABLE "baseten".Modification (
    "baseten_modification_id" INTEGER PRIMARY KEY,
    "baseten_modification_relid" OID NOT NULL,
    "baseten_modification_timestamp" TIMESTAMP (6) WITHOUT TIME ZONE NULL DEFAULT NULL,
    "baseten_modification_insert_timestamp" TIMESTAMP (6) WITHOUT TIME ZONE NOT NULL DEFAULT clock_timestamp (),
    "baseten_modification_type" CHAR NOT NULL,
    "baseten_modification_backend_pid" INT4 NOT NULL DEFAULT pg_backend_pid ()
);
CREATE SEQUENCE "baseten".modification_id_seq CYCLE OWNED BY "baseten".Modification."baseten_modification_id";
CREATE FUNCTION "baseten".SetModificationId () RETURNS TRIGGER AS $$
BEGIN
	NEW."baseten_modification_id" = nextval ('baseten.modification_id_seq');
	RETURN NEW;
END;
$$ VOLATILE LANGUAGE PLPGSQL EXTERNAL SECURITY DEFINER;
CREATE TRIGGER "setModificationId" BEFORE INSERT ON "baseten".Modification 
	FOR EACH ROW EXECUTE PROCEDURE "baseten".SetModificationId ();
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".SetModificationId () FROM PUBLIC;
REVOKE ALL PRIVILEGES ON SEQUENCE "baseten".modification_id_seq FROM PUBLIC;
REVOKE ALL PRIVILEGES ON "baseten".Modification FROM PUBLIC;
GRANT SELECT ON "baseten".Modification TO basetenread;


CREATE TABLE "baseten".lock (
    "baseten_lock_backend_pid"   INTEGER NOT NULL DEFAULT pg_backend_pid (),
    "baseten_lock_id"            BIGINT NOT NULL DEFAULT "baseten".LockNextId (),
    "baseten_lock_relid"         OID NOT NULL,
    "baseten_lock_timestamp"     TIMESTAMP (6) WITHOUT TIME ZONE NOT NULL DEFAULT clock_timestamp (),
    "baseten_lock_query_type"    CHAR (1) NOT NULL DEFAULT 'U',  -- U == UPDATE, D == DELETE
    "baseten_lock_cleared"       BOOLEAN NOT NULL DEFAULT FALSE,
    "baseten_lock_savepoint_idx" BIGINT NOT NULL,
    PRIMARY KEY ("baseten_lock_backend_pid", "baseten_lock_id")
);
REVOKE ALL PRIVILEGES ON "baseten".lock FROM PUBLIC;
GRANT SELECT ON "baseten".lock TO basetenread;

COMMIT; -- Schema and classes


BEGIN; -- Functions

CREATE FUNCTION "baseten".Version () RETURNS NUMERIC AS $$
    SELECT 0.913::NUMERIC;
$$ IMMUTABLE LANGUAGE SQL;
COMMENT ON FUNCTION "baseten".Version () IS 'Schema version';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".Version () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".Version () TO basetenread;



CREATE FUNCTION "baseten".CompatibilityVersion () RETURNS NUMERIC AS $$
    SELECT 0.13::NUMERIC;
$$ IMMUTABLE LANGUAGE SQL;
COMMENT ON FUNCTION "baseten".CompatibilityVersion () IS 'Schema compatibility version';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".CompatibilityVersion () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".CompatibilityVersion () TO basetenread;


-- Clears lock marks for this connection
CREATE FUNCTION "baseten".ClearLocks () RETURNS VOID AS $$ 
    UPDATE "baseten".Lock SET "baseten_lock_cleared" = true, "baseten_lock_timestamp" = CURRENT_TIMESTAMP 
    WHERE "baseten_lock_backend_pid" = pg_backend_pid ()
        AND "baseten_lock_timestamp" < CURRENT_TIMESTAMP;
    NOTIFY "baseten.ClearedLocks";
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".ClearLocks () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".ClearLocks () TO basetenuser;


-- Step back lock marks
CREATE FUNCTION "baseten".LocksStepBack () RETURNS VOID AS $$ 
    UPDATE "baseten".Lock SET "baseten_lock_cleared" = true, "baseten_lock_timestamp" = CURRENT_TIMESTAMP 
    WHERE baseten_lock_backend_pid = pg_backend_pid () 
        AND "baseten_lock_savepoint_idx" = 
            (SELECT max ("baseten_lock_savepoint_idx") 
             FROM "baseten".Lock
             WHERE "baseten_lock_backend_pid" = pg_backend_pid ()
            );
    NOTIFY "baseten.ClearedLocks";
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".LocksStepBack () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".LocksStepBack () TO basetenuser;


-- Returns schemaname.tablename corresponding to the given oid.
-- Raises an exception, if given an invalid oid.
CREATE FUNCTION "baseten".TableName (OID) RETURNS TEXT AS $$
DECLARE
    oid ALIAS FOR $1;
    name TEXT;
BEGIN
    SELECT INTO name quote_ident (n.nspname) || '.' || quote_ident (c.relname) 
    FROM pg_catalog.pg_class c, pg_catalog.pg_namespace n 
    WHERE n.oid = c.relnamespace 
        AND c.oid = oid;
    IF name IS NULL THEN
        RAISE EXCEPTION 'Nonexistent class OID %', oid;
    END IF;
    RETURN name;
END;
$$ STABLE LANGUAGE PLPGSQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".TableName (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".TableName (OID) TO basetenread;


CREATE FUNCTION "baseten".TableName1 (OID) RETURNS TEXT AS $$
DECLARE
    oid ALIAS FOR $1;
    name TEXT;
BEGIN
    SELECT INTO name n.nspname || '.' || c.relname
    FROM pg_catalog.pg_class c, pg_catalog.pg_namespace n 
    WHERE n.oid = c.relnamespace 
        AND c.oid = oid;
    IF name IS NULL THEN
        RAISE EXCEPTION 'Nonexistent class OID %', oid;
    END IF;
    RETURN name;
END;
$$ STABLE LANGUAGE PLPGSQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".TableName1 (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".TableName1 (OID) TO basetenread;


-- Replaces each underscore with two, each period with an underscore 
-- and removes double quotes
CREATE FUNCTION "baseten".SerializedTableName (TEXT) RETURNS TEXT AS $$
    SELECT replace (replace (replace ($1, '_', '__'), '.', '_'), '"', '');
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".SerializedTableName (TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".SerializedTableName (TEXT) TO basetenread;


CREATE FUNCTION "baseten".SerializedTableName (OID) RETURNS TEXT AS $$
    SELECT "baseten".SerializedTableName ("baseten".TableName1 ($1));
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".SerializedTableName (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".SerializedTableName (OID) TO basetenread;


CREATE FUNCTION "baseten".ModificationTableName1 (TEXT) RETURNS TEXT AS $$
    SELECT 'modification_' || $1;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".ModificationTableName1 (TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".ModificationTableName1 (TEXT) TO basetenread;


CREATE FUNCTION "baseten".ModificationTableName1 (OID) RETURNS TEXT AS $$
    SELECT "baseten".ModificationTableName1 ("baseten".SerializedTableName ($1));
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".ModificationTableName1 (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".ModificationTableName1 (OID) TO basetenread;


-- Returns the corresponding table where modifications are stored
-- Expects that the given table name is serialized
CREATE FUNCTION "baseten".ModificationTableName (TEXT) RETURNS TEXT AS $$
    SELECT quote_ident ('baseten') || '.' || quote_ident ("baseten".ModificationTableName1 ($1));
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".ModificationTableName (TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".ModificationTableName (TEXT) TO basetenread;


CREATE FUNCTION "baseten".ModificationTableName (OID) RETURNS TEXT AS $$
    SELECT quote_ident ('baseten') || '.' || quote_ident ("baseten".ModificationTableName1 ($1));
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".ModificationTableName (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".ModificationTableName (OID) TO basetenread;


-- Expects that the given table name is the modification table name
CREATE FUNCTION "baseten".ModResultTableName (TEXT) RETURNS TEXT AS $$
    SELECT quote_ident ('baseten_' || "baseten".ModificationTableName1 ($1) || '_result');
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".ModResultTableName (TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".ModResultTableName (TEXT) TO basetenread;


-- Expects that the given table name is serialized
CREATE FUNCTION "baseten".LockNotifyFunctionName (TEXT) RETURNS TEXT AS $$
    SELECT quote_ident ('baseten') || '.' || quote_ident ('LockNotify_' || $1);
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".LockNotifyFunctionName (TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".LockNotifyFunctionName (TEXT) TO basetenread;


CREATE FUNCTION "baseten".LockNotifyFunctionName (OID) RETURNS TEXT AS $$
    SELECT "baseten".LockNotifyFunctionName ("baseten".SerializedTableName ($1));
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".LockNotifyFunctionName (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".LockNotifyFunctionName (OID) TO basetenread;


-- Expects that the given table name is serialized
CREATE FUNCTION "baseten".LockTableName (TEXT) RETURNS TEXT AS $$
    SELECT quote_ident ('baseten') || '.' || quote_ident ('lock_' || $1);
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".LockTableName (TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".LockTableName (TEXT) TO basetenread;


CREATE FUNCTION "baseten".LockTableName (OID) RETURNS TEXT AS $$
    SELECT "baseten".LockTableName ("baseten".SerializedTableName ($1));
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".LockTableName (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".LockTableName (OID) TO basetenread;


-- Returns the modification rule name associated with the given operation,
-- which should be one of insert, update and delete
CREATE FUNCTION "baseten".ModificationRuleName (TEXT)
RETURNS TEXT AS $$
    SELECT 'basetenModification_' || upper ($1);
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".ModificationRuleName (TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".ModificationRuleName (TEXT) TO basetenread;


-- Removes tracked modifications which are older than 5 minutes and set the modification timestamps 
-- that have been left to null values from the last commit. Since the rows that have the same 
-- backend PID as the current process might not yet be visible to other transactions. 
-- FIXME: If we knew the current transaction status, the WHERE clause could be rewritten as:
-- WHERE "baseten_modification_timestamp" IS NULL 
--     AND ("baseten_modification_backend_pid" != pg_backend_pid () OR pg_xact_status = 'IDLE');
-- Also, if the connection is not autocommitting, we might end up doing some unnecessary work.
CREATE FUNCTION "baseten".ModificationTableCleanup () RETURNS VOID AS $$
    DELETE FROM "baseten".Modification 
        WHERE "baseten_modification_timestamp" < CURRENT_TIMESTAMP - INTERVAL '5 minutes';
    UPDATE "baseten".Modification SET "baseten_modification_timestamp" = clock_timestamp ()
        WHERE "baseten_modification_timestamp" IS NULL AND "baseten_modification_backend_pid" != pg_backend_pid ();
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".ModificationTableCleanup () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".ModificationTableCleanup () TO basetenread;


-- Removes tracked locks for which a backend no longer exists
-- FIXME: add a check to the function to ensure that the connection is autocommitting
CREATE FUNCTION "baseten".LockTableCleanup () RETURNS VOID AS $$ 
    DELETE FROM "baseten".Lock
        WHERE ("baseten_lock_timestamp" < pg_postmaster_start_time ()) -- Locks cannot be older than postmaster
            OR ("baseten_lock_backend_pid" NOT IN  (SELECT pid FROM "baseten".running_backend_pids () AS r (pid))) -- Locks have to be owned by a running backend
            OR ("baseten_lock_cleared" = true AND "baseten_lock_timestamp" < CURRENT_TIMESTAMP - INTERVAL '5 minutes'); -- Cleared locks older than 5 minutes may be removed
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".LockTableCleanup () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".LockTableCleanup () TO basetenread;


-- TEXT parameter needs to be the serialized table name
CREATE FUNCTION "baseten".ModifyInsertFunctionName (OID)
RETURNS TEXT AS $$
    SELECT quote_ident ('baseten') || '.' || quote_ident ('ModifyInsert_' || "baseten".SerializedTableName ($1));
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".ModifyInsertFunctionName (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".ModifyInsertFunctionName (OID) TO basetenread;


-- A trigger function for notifying the front ends and removing old tracked modifications
CREATE FUNCTION "baseten".NotifyForModification () RETURNS TRIGGER AS $$
BEGIN
    EXECUTE 'NOTIFY ' || quote_ident (baseten.ModificationTableName (TG_ARGV [0]));
    RETURN NEW;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".NotifyForModification () FROM PUBLIC;


-- A trigger function for notifying the front ends and removing old tracked locks
CREATE FUNCTION "baseten".NotifyForLock () RETURNS TRIGGER AS $$
BEGIN
    PERFORM "baseten".LockTableCleanup ();
    EXECUTE 'NOTIFY ' || quote_ident (baseten.LockTableName (TG_ARGV [0]));
    RETURN NEW;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".NotifyForLock () FROM PUBLIC;


CREATE FUNCTION "baseten".IsObservingCompatible (OID) RETURNS boolean AS $$
    SELECT EXISTS (SELECT c.oid FROM pg_class c, pg_namespace n 
        WHERE c.relnamespace = n.oid 
            AND c.relname = "baseten".ModificationTableName1 ($1)
            AND n.nspname = 'baseten');
$$ STABLE LANGUAGE SQL EXTERNAL SECURITY INVOKER;
COMMENT ON FUNCTION "baseten".IsObservingCompatible (OID) IS 'Checks for observing compatibility. Returns a boolean.';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".IsObservingCompatible (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".IsObservingCompatible (OID) TO basetenread;


CREATE FUNCTION "baseten".VerifyObservingCompatibility (OID) RETURNS VOID AS $$
DECLARE
    tableoid ALIAS FOR $1;
BEGIN
    IF NOT ("baseten".IsObservingCompatible (tableoid)) THEN
        RAISE EXCEPTION 'Table with OID % has not been prepared for modification observing', tableoid;
    END IF;
    RETURN;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".VerifyObservingCompatibility (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".VerifyObservingCompatibility (OID) TO basetenread;


-- A convenience function for observing modifications
-- Subscribes the caller to receive the approppriate notification
CREATE FUNCTION "baseten".ObserveModifications (OID) RETURNS TEXT AS $$
DECLARE
    tableoid ALIAS FOR $1;
    nname TEXT;
BEGIN
    PERFORM "baseten".VerifyObservingCompatibility (tableoid);
    nname := "baseten".ModificationTableName (tableoid);
    RAISE NOTICE 'Observing: %', nname;
    EXECUTE 'LISTEN ' || quote_ident (nname);
    RETURN nname;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".ObserveModifications (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".ObserveModifications (OID) TO basetenread;


CREATE FUNCTION "baseten".StopObservingModifications (OID) RETURNS VOID AS $$
DECLARE 
    tableoid ALIAS FOR $1;
BEGIN
    EXECUTE 'UNLISTEN ' || quote_ident ("baseten".ModificationTableName (tableoid));
    -- Should we drop?
    --DROP SEQUENCE "basetenlocksequence";
    RETURN;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".StopObservingModifications (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".StopObservingModifications (OID) TO basetenread;


-- A convenience function for observing locks
-- Subscribes the caller to receive the approppriate notification
CREATE FUNCTION "baseten".ObserveLocks (OID) RETURNS TEXT AS $$
DECLARE
    tableoid ALIAS FOR $1;
    nname TEXT;
BEGIN
    PERFORM "baseten".VerifyObservingCompatibility (tableoid);

    -- Don't create if exists
    BEGIN
        CREATE TEMPORARY SEQUENCE "basetenlocksequence";
    EXCEPTION WHEN OTHERS THEN
    END;

    nname := "baseten".LockTableName (tableoid);
    RAISE NOTICE 'Observing: %', nname;
    EXECUTE 'LISTEN ' || quote_ident (nname);
    RETURN nname;
END;
$$ VOLATILE LANGUAGE PLPGSQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".ObserveLocks (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".ObserveLocks (OID) TO basetenuser;


CREATE FUNCTION "baseten".StopObservingLocks (OID) RETURNS VOID AS $$
DECLARE 
    tableoid ALIAS FOR $1;
BEGIN
    EXECUTE 'UNLISTEN ' || quote_ident ("baseten".LockTableName (tableoid));
    RETURN;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".StopObservingLocks (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".StopObservingLocks (OID) TO basetenuser;


-- Remove the modification tracking table, rules and the trigger
CREATE FUNCTION "baseten".CancelModificationObserving (OID) RETURNS "baseten".TableType AS $$
DECLARE
    tableoid ALIAS FOR $1;
    tablename TEXT;
    mtablename TEXT;
    rval "baseten".TableType;
BEGIN    
    mtablename := "baseten".ModificationTableName (tableoid);
    EXECUTE 'DROP FUNCTION IF EXISTS ' || "baseten".ModifyInsertFunctionName (tableoid) || ' () CASCADE';
    EXECUTE 'DROP FUNCTION IF EXISTS ' || mtablename || ' (bool, timestamp) CASCADE';
    -- Cascades to rules and triggers
    EXECUTE 'DROP TABLE IF EXISTS ' || "baseten".LockTableName (tableoid) || ' CASCADE';
    EXECUTE 'DROP TABLE IF EXISTS ' || mtablename || ' CASCADE';
    -- This might not exist
    EXECUTE 'DROP TABLE IF EXISTS ' || "baseten".ModResultTableName (tableoid) || ' CASCADE';
    rval := ROW (tableoid, tablename)::"baseten".TableType;
    RETURN rval;
--EXCEPTION WHEN OTHERS THEN
--    RETURN;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
COMMENT ON FUNCTION "baseten".CancelModificationObserving (OID) IS 'Removes BaseTen tables for a specific relation';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".CancelModificationObserving (OID) FROM PUBLIC;


-- A helper function
CREATE FUNCTION "baseten".PrepareForModificationObserving1 (TEXT, OID, NAME, NAME [], BOOLEAN) 
RETURNS VOID AS $marker$
DECLARE
    querytype   TEXT DEFAULT $1;
    tableoid    ALIAS FOR $2;
    tablename   ALIAS FOR $3;
    fieldnames  NAME [] DEFAULT $4;
    isview      ALIAS FOR $5;
    referencename TEXT DEFAULT 'NEW.';
    query TEXT;
    mtablename TEXT;
    funcname TEXT;
    fdecl TEXT;
BEGIN
    mtablename := "baseten".ModificationTableName (tableoid);
    querytype := upper (querytype);
    
    -- With views, triggers cannot be used.
    -- Instead, rules may be used, since values corresponding to the primary key have to be
    -- specified on insert and sequences are not used.
    IF querytype = 'INSERT' AND false = isview THEN
        funcname := "baseten".ModifyInsertFunctionName (tableoid);
        -- Trigger functions cannot be written in SQL
        fdecl :=
            'CREATE OR REPLACE FUNCTION  ' || funcname || ' () RETURNS TRIGGER AS $$             ' ||
            'BEGIN                                                                               ' ||
            '    INSERT INTO ' || mtablename                                                       ||
            '        ("baseten_modification_type", ' || array_to_string (fieldnames, ', ') || ') ' ||
            '       VALUES (''I'', ' || array_to_string (
                        "baseten".array_prepend_each ('NEW.', fieldnames), ', ') || ');          ' || -- f. values
            '    RETURN NEW;                                                                     ' ||
            'END;                                                                                ' ||
            '$$ VOLATILE LANGUAGE PLPGSQL EXTERNAL SECURITY DEFINER';
        query := 
            'CREATE TRIGGER ' || "baseten".ModificationRuleName ('INSERT')                         ||
            '    AFTER INSERT ON ' || tablename || ' FOR EACH ROW EXECUTE PROCEDURE              ' || 
                 funcname || ' ()'; 
        EXECUTE fdecl;
        EXECUTE query;
        EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION ' || funcname || ' () FROM PUBLIC';
    ELSE
        IF querytype = 'DELETE' THEN
            referencename = 'OLD.';
        END IF;
        
        query := 
            'CREATE RULE ' || "baseten".ModificationRuleName (querytype) || ' AS ON ' || querytype ||
            '   TO ' || tablename || ' DO ALSO INSERT '                                            ||
            '   INTO ' || "baseten".ModificationTableName (tableoid)                               ||
            '   ("baseten_modification_type", ' || array_to_string (fieldnames, ', ') || ')'       ||
            '   VALUES (''' || substring (querytype from 1 for 1) || ''','                         ||
                array_to_string ("baseten".array_prepend_each (referencename, fieldnames), ', ')   || ')';
        EXECUTE query;
    END IF;
    RETURN;
END;
$marker$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION
	"baseten".PrepareForModificationObserving1 (TEXT, OID, NAME, NAME [], BOOLEAN) FROM PUBLIC;


-- Another helper function
-- Create a function that retrieves only significant rows from the modification table
CREATE FUNCTION "baseten".PrepareForModificationObserving2 (OID, TEXT) 
RETURNS VOID AS $marker$
DECLARE
    fdecl       TEXT;           -- Function declaration
    tableoid    ALIAS FOR $1;   -- Serialized table name
    pkeyfnames  ALIAS FOR $2;   -- Primary key field names
    ntname      TEXT;           -- Notification table name
    restname    TEXT;           -- Result table name
BEGIN
    ntname      := "baseten".ModificationTableName (tableoid);
    restname    := "baseten".ModResultTableName (tableoid);
    fdecl       := 
        'CREATE OR REPLACE FUNCTION ' || ntname || ' (BOOLEAN, TIMESTAMP, INTEGER)                   ' ||
        'RETURNS SETOF ' || ntname || ' AS $$                                                        ' ||
        'DECLARE                                                                                     ' ||
        '   should_clean ALIAS FOR $1;                                                               ' ||
        '   earliest_date ALIAS FOR $2;                                                              ' ||        
        '   ignored_be_pid ALIAS FOR $3;                                                             ' ||
        '   row ' || ntname || '%ROWTYPE;                                                            ' ||
        'BEGIN                                                                                       ' ||
        '    BEGIN                                                                                   ' ||
        '        CREATE TEMPORARY TABLE ' || restname || '                                           ' ||
        '            (LIKE ' || ntname || ' EXCLUDING DEFAULTS) ON COMMIT DELETE ROWS;               ' ||
        '    EXCEPTION WHEN OTHERS THEN                                                              ' ||
        '    END;                                                                                    ' ||
        '    DELETE FROM ' || restname || ';                                                         ' ||
        
        -- Remove unneeded rows
        '    IF true = should_clean THEN                                                             ' ||
        '        PERFORM "baseten".ModificationTableCleanup ();                                      ' ||
        '    END IF;                                                                                 ' ||
        
        -- Only add rows that have been deleted
        '    INSERT INTO ' || restname || ' SELECT DISTINCT ON (' || pkeyfnames || ') * FROM         ' ||
        '    (                                                                                       ' ||
        '        SELECT * FROM ' || ntname || '                                                      ' ||
        '            WHERE "baseten_modification_type" = ''D'' AND                                   ' ||
        '                baseten_modification_backend_pid != ignored_be_pid AND                      ' ||
        '                ("baseten_modification_timestamp" > COALESCE ($2, ''-infinity''::timestamp) ' ||
        '                 OR "baseten_modification_timestamp" IS NULL                                ' ||
        '                )                                                                           ' ||
        '            ORDER BY "baseten_modification_timestamp" DESC,                                 ' ||
        '                "baseten_modification_insert_timestamp" DESC                                ' ||
        '    ) AS sd;                                                                                ' ||
        
        -- DEBUG
        --'RAISE NOTICE ''k'';' ||
        --'INSERT INTO k SELECT * FROM ' || restname || ';' ||
        -- Use with tables like these:
        --CREATE TABLE k (LIKE "baseten.modification_public_test");
        --CREATE TABLE l (LIKE "baseten.modification_public_test");
    
        -- Only add rows that have not been deleted    
        '   INSERT INTO ' || restname || ' SELECT DISTINCT ON (' || pkeyfnames || ') * FROM          ' ||
        '   (                                                                                        ' ||
        '       SELECT m.* FROM ' || ntname || ' m                                                   ' ||
        '           LEFT JOIN ' || restname || ' r USING (' || pkeyfnames || ')                      ' ||
        '           WHERE m."baseten_modification_type" = ''I'' AND                                  ' ||
        '              m."baseten_modification_backend_pid" != ignored_be_pid AND                    ' ||
        '              (r."baseten_modification_id" IS NULL OR                                       ' ||
        '                   m."baseten_modification_timestamp" > r."baseten_modification_timestamp"  ' ||
        '              ) AND                                                                         ' ||
        '              (m."baseten_modification_timestamp" > COALESCE ($2, ''-infinity''::timestamp) ' ||
        '               OR m."baseten_modification_timestamp" IS NULL                                ' ||
        '              )                                                                             ' ||
        '           ORDER BY "baseten_modification_timestamp" DESC,                                  ' ||
        '                "baseten_modification_insert_timestamp" DESC                                ' ||
        '   ) AS si;                                                                                 ' ||

        -- DEBUG
        --'RAISE NOTICE ''l'';' ||
        --'INSERT INTO l SELECT * FROM ' || restname || ';' ||
        
        -- Only add rows that haven't got an entry already
        '   INSERT INTO ' || restname || ' SELECT DISTINCT ON (' || pkeyfnames || ') * FROM          ' ||
        '   (                                                                                        ' ||
        '       SELECT m.* FROM ' || ntname || ' m                                                   ' ||
        '           LEFT JOIN ' || restname || ' r USING (' || pkeyfnames || ')                      ' ||
        '           WHERE m."baseten_modification_type" = ''U'' AND                                  ' ||
        '              m."baseten_modification_backend_pid" != ignored_be_pid AND                    ' ||
        '              r."baseten_modification_id" IS NULL AND                                       ' ||
        '              (m."baseten_modification_timestamp" > COALESCE ($2, ''-infinity''::timestamp) ' ||
        '               OR m."baseten_modification_timestamp" IS NULL                                ' ||
        '              )                                                                             ' ||
        '           ORDER BY "baseten_modification_timestamp" DESC,                                  ' ||
        '               "baseten_modification_insert_timestamp" DESC                                 ' ||
        '   ) AS su;                                                                                 ' ||
    
        -- Now there should be only one modification per id
        '   FOR row IN SELECT * from ' || restname || ' ORDER BY                                     ' ||
        '       "baseten_modification_type" ASC,                                                     ' ||
        '       "baseten_modification_timestamp" ASC,                                                ' ||
        '       "baseten_modification_insert_timestamp" ASC LOOP                                     ' ||
        '       RETURN NEXT row;                                                                     ' ||
        '   END LOOP;                                                                                ' ||
        '   RETURN;                                                                                  ' ||
        'END;                                                                                        ' ||
        '$$ VOLATILE LANGUAGE PLPGSQL EXTERNAL SECURITY DEFINER;                                     ' ;
    EXECUTE fdecl;
    fdecl :=
        'CREATE OR REPLACE FUNCTION ' || ntname || ' (TIMESTAMP, INTEGER)                            ' ||
        'RETURNS SETOF ' || ntname || ' AS $$                                                        ' ||
        '    SELECT * FROM ' || ntname || '(true, $1, $2);                                           ' ||
        '$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;                                         ';
    EXECUTE fdecl;
    EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION ' || ntname || ' (BOOLEAN, TIMESTAMP, INTEGER) FROM PUBLIC';
    EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION ' || ntname || ' (TIMESTAMP, INTEGER) FROM PUBLIC';
    EXECUTE 'GRANT EXECUTE ON FUNCTION ' || ntname || ' (BOOLEAN, TIMESTAMP, INTEGER) TO basetenread';
    EXECUTE 'GRANT EXECUTE ON FUNCTION ' || ntname || ' (TIMESTAMP, INTEGER) TO basetenread';
        
    RETURN;
END;
$marker$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".PrepareForModificationObserving2 (OID, TEXT) FROM PUBLIC;


-- Creates a table for tracking modifications to the given table.
-- The table inherits "baseten".Modification.
-- Also, rules and a trigger are created to track the changes.
CREATE FUNCTION "baseten".PrepareForModificationObserving (OID) RETURNS "baseten".TableType AS $marker$
DECLARE
    toid        ALIAS FOR $1;   -- Relation OID
    pkeyfields  RECORD;
    pkey_decl   TEXT;           -- Declaration for creating fields corresponding to the primary key
    query       TEXT;
    tkind       CHAR;           -- Relation kind
    tname       TEXT;           -- Relation name
    stablename  TEXT;           -- Serialized relation name
    mtablename  TEXT;           -- Modification table name
    ltablename  TEXT;           -- Lock table name
    pkeyfnames  TEXT;
    lfname      TEXT;
    fcode       TEXT;
    fargs       TEXT;
    iitems      TEXT [];
    i           INTEGER;
    isview      BOOLEAN;        -- Is the object a view?
    rval        "baseten".TableType;
BEGIN
    tname       := "baseten".TableName (toid);
    stablename  := "baseten".SerializedTableName (toid);
    mtablename  := "baseten".ModificationTableName (toid);
    ltablename  := "baseten".LockTableName (toid);
    lfname      := "baseten".LockNotifyFunctionName (toid);
    SELECT INTO isview 'v' = relkind FROM pg_class WHERE oid = toid;
    
    SELECT INTO pkeyfields "baseten".array_accum (
        quote_ident (attname)) AS fname, 
        "baseten".array_accum (quote_ident (type)) AS type,
        relkind
        FROM "baseten".PrimaryKey WHERE oid = toid GROUP BY oid, relkind;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Primary key is required for relation %', tname;
    END IF;

    tkind = pkeyfields.relkind;
    pkeyfnames = array_to_string (pkeyfields.fname, ', ');
    pkey_decl = array_to_string (
        "baseten".array_cat_each (pkeyfields.fname, pkeyfields.type, ' '), ', ');

    -- Locking
    EXECUTE 'CREATE TABLE '
        || ltablename
        || ' ("baseten_lock_relid" OID NOT NULL DEFAULT ' || toid || ', '
        || pkey_decl || ')'
        || ' INHERITS ("baseten".Lock)';
    EXECUTE 'REVOKE ALL PRIVILEGES ON ' || ltablename || ' FROM PUBLIC';
    EXECUTE 'GRANT SELECT ON ' || ltablename || ' TO basetenread';
    EXECUTE 'GRANT INSERT ON ' || ltablename || ' TO basetenuser';

    -- Trigger for the _lock_ table
    EXECUTE 'CREATE TRIGGER "basetenLockRow" AFTER INSERT ON ' || ltablename
        || ' FOR EACH STATEMENT EXECUTE PROCEDURE "baseten".NotifyForLock (''' || stablename || ''')';
        
    -- Locking function
    -- First argument is the modification type
    FOR i IN 1..(2 + array_upper (pkeyfields.fname, 1)) LOOP
        iitems [i] := '$' || i;
    END LOOP;
    fcode := 'INSERT INTO ' || ltablename
        || ' ("baseten_lock_query_type", "baseten_lock_savepoint_idx", ' || pkeyfnames || ') '
        || ' VALUES (' || array_to_string (iitems, ', ') || ');'
        || ' NOTIFY ' || quote_ident (ltablename) || ';';
    -- FIXME: add a check to the function to ensure that the connection is autocommitting
    fargs := ' (CHAR (1), BIGINT, ' || array_to_string (pkeyfields.type, ', ') || ')';
    EXECUTE 'CREATE OR REPLACE FUNCTION ' || lfname || fargs || ' '
        || ' RETURNS VOID AS $$ ' || fcode || ' $$ VOLATILE LANGUAGE SQL';
    EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION ' || lfname || fargs || ' FROM PUBLIC';
    EXECUTE 'GRANT EXECUTE ON FUNCTION '         || lfname || fargs || ' TO basetenuser';
        
    -- Modifications
    EXECUTE 'CREATE TABLE ' 
        || mtablename
        || ' ("baseten_modification_relid" OID NOT NULL DEFAULT ' || toid || ', '
        || pkey_decl || ')'
        || ' INHERITS ("baseten".Modification)';
    EXECUTE 'REVOKE ALL PRIVILEGES ON ' || mtablename || ' FROM PUBLIC';
    EXECUTE 'GRANT SELECT ON ' || mtablename || ' TO basetenread';
    
    -- Triggers for the _modification_ table
    EXECUTE 
        'CREATE TRIGGER "basetenModifyTable" AFTER INSERT ON ' || mtablename ||
        '   FOR EACH STATEMENT EXECUTE PROCEDURE ' ||
        '   "baseten".NotifyForModification (''' || stablename || ''')';
    EXECUTE
    	'CREATE TRIGGER "setModificationID" BEFORE INSERT ON ' || mtablename ||
		'   FOR EACH ROW EXECUTE PROCEDURE "baseten".SetModificationID ()';


    PERFORM "baseten".PrepareForModificationObserving1 ('insert', toid, tname, pkeyfields.fname, isview);
    PERFORM "baseten".PrepareForModificationObserving1 ('update', toid, tname, pkeyfields.fname, isview);
    PERFORM "baseten".PrepareForModificationObserving1 ('delete', toid, tname, pkeyfields.fname, isview);
    PERFORM "baseten".PrepareForModificationObserving2 (toid, pkeyfnames);

    rval := ROW (toid, tname)::"baseten".TableType;
    RETURN rval;
END;
$marker$ VOLATILE LANGUAGE PLPGSQL;
COMMENT ON FUNCTION "baseten".PrepareForModificationObserving (OID) IS 'BaseTen-enables a relation';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".PrepareForModificationObserving (OID) FROM PUBLIC;
	

CREATE FUNCTION "baseten".refreshcaches () RETURNS void AS $$
	TRUNCATE "baseten".viewdependency, "baseten".srcdstview, "baseten".relationship_v;
	INSERT INTO "baseten".viewdependency SELECT * from "baseten".viewdependency_v;
	INSERT INTO "baseten".srcdstview SELECT * FROM "baseten".srcdstview ();
	INSERT INTO "baseten".relationship_v SELECT * FROM "baseten".relationship_vv;
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".refreshcaches () FROM PUBLIC;
-- Only owner for now.


GRANT basetenread TO basetenuser;
COMMIT; -- Functions
