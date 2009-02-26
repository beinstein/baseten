--
-- BaseTenModifications.sql.m4
-- BaseTen
--
-- Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
--
-- Before using this software, please review the available licensing options
-- by visiting http://basetenframework.org/licensing/ or by contacting
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
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
--
-- $Id$
--

changequote(`{{', `}}')
-- ' -- Fix for syntax coloring in SQL mode.
define({{_bx_version_}}, {{0.922}})dnl
define({{_bx_compat_version_}}, {{0.18}})dnl


\unset ON_ERROR_ROLLBACK
\set ON_ERROR_STOP


BEGIN; -- Schema, helper functions and classes

DROP SCHEMA IF EXISTS "baseten" CASCADE;
CREATE SCHEMA "baseten";
COMMENT ON SCHEMA "baseten" IS 'Schema used by BaseTen. Please use the provided functions to edit.';
-- Privileges are set a bit later.

CREATE FUNCTION "baseten".create_plpgsql () RETURNS VOID AS $$
	CREATE LANGUAGE plpgsql;
$$ VOLATILE LANGUAGE SQL;

SELECT "baseten".create_plpgsql () 
FROM (
	SELECT EXISTS (
		SELECT lanname
		FROM pg_language 
		WHERE lanname = 'plpgsql'
	) AS exists
) AS plpgsql 
WHERE plpgsql.exists = false;

DROP FUNCTION "baseten".create_plpgsql ();

CREATE FUNCTION "baseten".prepare () RETURNS VOID AS $$
	BEGIN		
		PERFORM rolname FROM pg_roles WHERE rolname = 'basetenread';
		IF NOT FOUND THEN
			CREATE ROLE basetenread WITH
				INHERIT
				NOSUPERUSER
				NOCREATEDB
				NOCREATEROLE
				NOLOGIN;
		END IF;
			
		PERFORM rolname FROM pg_roles WHERE rolname = 'basetenuser';
		IF NOT FOUND THEN
			CREATE ROLE basetenuser WITH
				INHERIT
				NOSUPERUSER
				NOCREATEDB
				NOCREATEROLE
				NOLOGIN;
		END IF;
	END;
$$ VOLATILE LANGUAGE plpgsql;
SELECT "baseten".prepare ();
DROP FUNCTION "baseten".prepare ();


REVOKE ALL PRIVILEGES ON SCHEMA "baseten" FROM PUBLIC;
GRANT USAGE ON SCHEMA "baseten" TO basetenread;

CREATE TEMPORARY SEQUENCE "baseten_lock_seq";
REVOKE ALL PRIVILEGES ON SEQUENCE "baseten_lock_seq" FROM PUBLIC;


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
GRANT EXECUTE ON FUNCTION "baseten".array_cat_each (TEXT [], TEXT [], TEXT) TO basetenread;


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
GRANT EXECUTE ON FUNCTION "baseten".array_prepend_each (TEXT, TEXT []) TO basetenread;


-- Appends each element of an array with the first parameter
CREATE FUNCTION "baseten".array_append_each (TEXT, TEXT [])
	RETURNS TEXT [] AS $$
DECLARE
	suffix ALIAS FOR $1;
	source ALIAS FOR $2;
	destination TEXT [];
BEGIN
	FOR i IN array_lower (source, 1)..array_upper (source, 1) LOOP
		destination [i] = source [i] || suffix;
	END LOOP;
	RETURN destination;
END;
$$ IMMUTABLE LANGUAGE PLPGSQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES 
	ON FUNCTION "baseten".array_append_each (TEXT, TEXT [])	 FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".array_append_each (TEXT, TEXT []) TO basetenread;


CREATE FUNCTION "baseten".running_backend_pids () 
RETURNS SETOF INTEGER AS $$
	SELECT 
		pg_stat_get_backend_pid (idset.id) AS pid 
	FROM pg_stat_get_backend_idset () AS idset (id);
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".running_backend_pids () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".running_backend_pids () TO basetenread;


CREATE FUNCTION "baseten".lock_next_id () RETURNS BIGINT AS $$
	SELECT nextval ('baseten_lock_seq');
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON  FUNCTION "baseten".lock_next_id () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_next_id () TO basetenuser;


define({{between_operator}}, {{
CREATE FUNCTION "baseten".between ($1 [2], $1) RETURNS BOOLEAN AS $$
	SELECT ${{}}1[1] <= ${{}}2 AND ${{}}2 <= ${{}}1[2];
$$ IMMUTABLE STRICT LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON  FUNCTION "baseten".between ($1 [2], $1) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".between ($1 [2], $1) TO basetenread;

CREATE OPERATOR "baseten".<<>> (
	PROCEDURE = "baseten".between,
	LEFTARG = $1[2],
	RIGHTARG = $1,
	HASHES
)}})dnl
between_operator({{SMALLINT}});
between_operator({{INTEGER}});
between_operator({{BIGINT}});
between_operator({{NUMERIC}});
between_operator({{REAL}});
between_operator({{DOUBLE PRECISION}});
between_operator({{TIMESTAMP WITHOUT TIME ZONE}});
between_operator({{TIMESTAMP WITH TIME ZONE}});
between_operator({{INTERVAL}});
between_operator({{DATE}});
between_operator({{TIME WITHOUT TIME ZONE}});
between_operator({{TIME WITH TIME ZONE}});


-- No privileges on types
CREATE TYPE "baseten".reltype AS (
	oid OID,
	nspname NAME,
	relname NAME
);


CREATE TYPE "baseten".viewtype AS (
	oid OID,
	parent OID,
	root OID,
	generation SMALLINT
);


CREATE TYPE "baseten".observation_type AS (
	oid OID,
	notification_name TEXT,
	function_name TEXT,
	table_name TEXT
);


CREATE FUNCTION "baseten".reltype (OID, NAME, NAME) RETURNS "baseten".reltype AS $$
	SELECT $1, $2, $3;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".reltype (OID, NAME, NAME) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".reltype (OID, NAME, NAME) TO basetenread;


CREATE FUNCTION "baseten".reltype (OID) RETURNS "baseten".reltype AS $$
DECLARE
	retval "baseten".reltype;
BEGIN
	SELECT $1, n.nspname, c.relname
		FROM pg_class c
		INNER JOIN pg_namespace n ON (c.relnamespace = n.oid)
		WHERE c.oid = $1
		INTO STRICT retval;
	RETURN retval;
END;
$$ STABLE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".reltype (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".reltype (OID) TO basetenread;


-- Debugging helpers
CREATE FUNCTION "baseten".oidof (TEXT, TEXT) RETURNS "baseten".reltype AS $$
	SELECT c.oid, n.nspname, c.relname
	FROM pg_class c
	INNER JOIN pg_namespace n ON (c.relnamespace = n.oid)
	WHERE c.relname = $2 AND n.nspname = $1;
$$ STABLE LANGUAGE SQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".oidof (TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".oidof (TEXT, TEXT) TO basetenread;


CREATE FUNCTION "baseten".oidof (TEXT) RETURNS "baseten".reltype AS $$
	SELECT "baseten".oidof ('public', $1);
$$ STABLE LANGUAGE SQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".oidof (TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".oidof (TEXT) TO basetenread;


-- Views' primary keys
CREATE TABLE "baseten".view_pkey (
	nspname NAME NOT NULL DEFAULT 'public',
	relname NAME NOT NULL,
	attname NAME NOT NULL,
	PRIMARY KEY (nspname, relname, attname)
);
COMMENT ON TABLE "baseten".view_pkey IS 'Primary keys for views. This table may be modified by hand.';
COMMENT ON COLUMN "baseten".view_pkey.nspname IS 'Namespace name';
COMMENT ON COLUMN "baseten".view_pkey.relname IS 'View name';
COMMENT ON COLUMN "baseten".view_pkey.attname IS 'Column name';
-- FIXME: privileges?
GRANT SELECT ON TABLE "baseten".view_pkey TO basetenread;


CREATE TABLE "baseten".enabled_relation (
	relid oid PRIMARY KEY
);
-- FIXME: privileges?
GRANT SELECT ON TABLE "baseten".enabled_relation TO basetenread;


-- FIXME: schema qualification of type name.
CREATE VIEW "baseten".primary_key_v AS
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
			FROM "baseten".view_pkey vpkey, pg_attribute a, pg_type t, pg_namespace n, pg_class c
			WHERE vpkey.nspname = n.nspname
				AND vpkey.relname = c.relname
				AND c.relnamespace = n.oid
				AND a.attname = vpkey.attname
				AND a.attrelid = c.oid
				AND a.atttypid = t.oid
				AND c.relkind = 'v'
	) r
	ORDER BY oid ASC, attnum ASC;
REVOKE ALL PRIVILEGES ON "baseten".primary_key_v FROM PUBLIC;
GRANT SELECT ON "baseten".primary_key_v TO basetenread;


CREATE TABLE "baseten".primary_key AS SELECT * FROM "baseten".primary_key_v LIMIT 0;
REVOKE ALL PRIVILEGES ON "baseten".primary_key FROM PUBLIC;
GRANT SELECT ON "baseten".primary_key TO basetenread;


-- Note that system views aren't correctly listed.
CREATE VIEW "baseten".viewdependency_v AS 
	SELECT DISTINCT 
		d1.refobjid AS viewoid, 
		n1.oid		AS viewnamespace, 
		n1.nspname	AS viewnspname, 
		c1.relname	AS viewrelname, 
		d2.refobjid AS reloid, 
		c2.relkind	AS relkind, 
		n2.oid		AS relnamespace, 
		n2.nspname	AS relnspname, 
		c2.relname	AS relname 
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


CREATE TABLE "baseten".ignored_fkey (
	schemaname NAME,
	relname NAME,
	fkeyname NAME,
	PRIMARY KEY (schemaname, relname, fkeyname)
);
REVOKE ALL PRIVILEGES ON "baseten".ignored_fkey FROM PUBLIC;
-- FIXME: privileges?
GRANT SELECT ON "baseten".ignored_fkey TO basetenread;


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
	n.fkeynames			AS dstfnames,
	c2.oid IS NOT NULL	AS srcisunique,
	c1.confdeltype		AS deltype
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
WHERE c1.contype = 'f' AND
	ROW (ns1.nspname, cl1.relname, c1.conname) NOT IN (SELECT * FROM "baseten".ignored_fkey);
REVOKE ALL PRIVILEGES ON "baseten".foreignkey FROM PUBLIC;
GRANT SELECT ON "baseten".foreignkey TO basetenread;


-- Fkeys in pkeys
CREATE VIEW "baseten".mtmcandidates AS
-- In the sub-select we search for all primary keys and their columns.
-- Then we count the foreign keys the columns of which are contained
-- in those of the primary keys'. Finally we filter out anything irrelevant.
SELECT srcoid AS oid
FROM (
	SELECT
		f.srcoid,
		COUNT (f.conoid) AS fkeycount,
		"baseten".array_cat (f.srcfnames) AS fkeyattnames
	FROM "baseten".foreignkey f
	GROUP BY f.srcoid
) f1 INNER JOIN (
	SELECT
		p.oid,
		baseten.array_accum (p.attname) AS pkeyattnames
	FROM "baseten".primary_key p
	WHERE relkind = 'r'
	GROUP BY p.oid
) p1 ON f1.srcoid = p1.oid
WHERE 2 = fkeycount AND p1.pkeyattnames @> f1.fkeyattnames;
REVOKE ALL PRIVILEGES ON "baseten".mtmcandidates FROM PUBLIC;
GRANT SELECT ON "baseten".mtmcandidates TO basetenread;


CREATE VIEW "baseten".oneto_fk AS
SELECT
	conoid,
	name		AS name,
	srcnspname || '_' || srcrelname || '_' || name AS inversename,
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
	true		AS isinverse,
	srcisunique AS istoone
FROM "baseten".foreignkey
UNION ALL
SELECT
	conoid,
	srcnspname || '_' || srcrelname || '_' || name AS name,
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
	f1.dstoid		AS srcoid,
	f1.dstnsp		AS srcnsp,
	f1.dstnspname	AS srcnspname,
	f1.dstrelname	AS srcrelname,
	f1.dstfnames	AS srcfnames,
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
INNER JOIN "baseten".mtmcandidates c ON (
	c.oid = f1.srcoid
);
REVOKE ALL PRIVILEGES ON "baseten".manytomany_fk FROM PUBLIC;
GRANT SELECT ON "baseten".manytomany_fk TO basetenread;


CREATE VIEW "baseten".relationship_fk AS
	SELECT
		-- These three are sort of a primary key.
		conoid,
		NULL::OID AS dstconoid,
		(CASE WHEN true = istoone THEN 'o' ELSE 't' END)::char AS kind,
		
		srcoid, 
		dstoid,
		NULL::OID AS helperoid,
		srcfnames, 
		dstfnames,
		NULL::NAME [] AS helperfnames,
		isinverse
	FROM baseten.oneto_fk
	UNION ALL
	SELECT
		conoid,
		dstconoid,
		'm'::char AS kind,
		
		srcoid, 
		dstoid, 
		helperoid,
		srcfnames, 
		dstfnames,
		helperfnames,
		false AS isinverse
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
	ARRAY [name]				AS relationship_names
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


CREATE VIEW "baseten".view_relationship AS
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
REVOKE ALL PRIVILEGES ON "baseten".view_relationship FROM PUBLIC;
GRANT SELECT ON "baseten".view_relationship TO basetenread;


CREATE VIEW "baseten".relationship_v AS
	SELECT
		o.conoid,
		null::OID AS dstconoid,
		o.name,
		o.inversename,
		(CASE WHEN true = istoone THEN 'o' ELSE 't' END)::char AS kind,
		o.isinverse,
		o.srcoid,
		o.srcnspname,
		o.srcrelname,
		o.srcfnames,
		o.dstoid,
		o.dstnspname,
		o.dstrelname,
		o.dstfnames,
		null::OID AS helperoid,
		null::name AS helpernspname,
		null::name AS helperrelname,
		null::name[] AS helperfnames
	FROM "baseten".oneto_ o
	UNION ALL
	SELECT
		m.conoid,
		m.dstconoid,
		m.name,
		m.inversename,
		'm'::char AS kind,
		false AS isinverse,
		m.srcoid,
		m.srcnspname,
		m.srcrelname,
		m.srcfnames,
		m.dstoid,
		m.dstnspname,
		m.dstrelname,
		m.dstfnames,
		m.helperoid,
		m.helpernspname,
		m.helperrelname,
		m.helperfnames
	FROM "baseten".manytomany m
	UNION ALL
	SELECT
		v.conoid,
		v.dstconoid,
		v.name,
		v.inversename,
		v.kind,
		v.isinverse,
		v.srcoid,
		v.srcnspname,
		v.srcrelname,
		v.srcfnames,
		v.dstoid,
		v.dstnspname,
		v.dstrelname,
		v.dstfnames,
		v.helperoid,
		v.helpernspname,
		v.helperrelname,
		v.helperfnames
	FROM "baseten".view_relationship v;
REVOKE ALL PRIVILEGES ON "baseten".relationship_v FROM PUBLIC;
GRANT SELECT ON "baseten".relationship_v TO basetenread;


CREATE TABLE "baseten".relationship AS SELECT * FROM "baseten".relationship_v LIMIT 0;
REVOKE ALL PRIVILEGES ON "baseten".relationship FROM PUBLIC;
GRANT SELECT ON "baseten".relationship TO basetenread;


-- For modification tracking
CREATE TABLE "baseten".modification (
	"baseten_modification_id" INTEGER PRIMARY KEY,
	"baseten_modification_relid" OID NOT NULL,
	"baseten_modification_timestamp" TIMESTAMP (6) WITHOUT TIME ZONE NULL DEFAULT NULL,
	"baseten_modification_insert_timestamp" TIMESTAMP (6) WITHOUT TIME ZONE NOT NULL DEFAULT clock_timestamp (),
	"baseten_modification_type" CHAR NOT NULL,
	"baseten_modification_backend_pid" INT4 NOT NULL DEFAULT pg_backend_pid ()
);
CREATE SEQUENCE "baseten".modification_id_seq CYCLE OWNED BY "baseten".modification."baseten_modification_id";
CREATE FUNCTION "baseten".set_mod_id () RETURNS TRIGGER AS $$
BEGIN
	NEW."baseten_modification_id" = nextval ('"baseten"."modification_id_seq"');
	RETURN NEW;
END;
$$ VOLATILE LANGUAGE PLPGSQL EXTERNAL SECURITY DEFINER;
CREATE TRIGGER "set_mod_id" BEFORE INSERT ON "baseten".modification 
	FOR EACH ROW EXECUTE PROCEDURE "baseten".set_mod_id ();
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".set_mod_id () FROM PUBLIC;
REVOKE ALL PRIVILEGES ON SEQUENCE "baseten".modification_id_seq FROM PUBLIC;
REVOKE ALL PRIVILEGES ON "baseten".modification FROM PUBLIC;
GRANT SELECT ON "baseten".modification TO basetenread;


CREATE TABLE "baseten".lock (
	"baseten_lock_backend_pid"	 INTEGER NOT NULL DEFAULT pg_backend_pid (),
	"baseten_lock_id"			 BIGINT NOT NULL DEFAULT "baseten".lock_next_id (),
	"baseten_lock_relid"		 OID NOT NULL,
	"baseten_lock_timestamp"	 TIMESTAMP (6) WITHOUT TIME ZONE NOT NULL DEFAULT clock_timestamp (),
	"baseten_lock_query_type"	 CHAR (1) NOT NULL DEFAULT 'U',	 -- U == UPDATE, D == DELETE
	"baseten_lock_cleared"		 BOOLEAN NOT NULL DEFAULT FALSE,
	"baseten_lock_savepoint_idx" BIGINT NOT NULL,
	PRIMARY KEY ("baseten_lock_backend_pid", "baseten_lock_id")
);
REVOKE ALL PRIVILEGES ON "baseten".lock FROM PUBLIC;
GRANT SELECT ON "baseten".lock TO basetenread;


-- Functions

CREATE FUNCTION "baseten".version () RETURNS NUMERIC AS $$
	SELECT _bx_version_::NUMERIC;
$$ IMMUTABLE LANGUAGE SQL;
COMMENT ON FUNCTION "baseten".version () IS 'Schema version';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".version () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".version () TO basetenread;


CREATE FUNCTION "baseten".compatibilityversion () RETURNS NUMERIC AS $$
	SELECT _bx_compat_version_::NUMERIC;
$$ IMMUTABLE LANGUAGE SQL;
COMMENT ON FUNCTION "baseten".compatibilityversion () IS 'Schema compatibility version';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".compatibilityversion () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".compatibilityversion () TO basetenread;


CREATE FUNCTION "baseten".mod_notification (OID) RETURNS TEXT AS $$
	SELECT 'baseten_mod__' || $1;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".mod_notification (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".mod_notification (OID) TO basetenread;


CREATE FUNCTION "baseten".mod_table (OID) RETURNS TEXT AS $$
	SELECT 'mod__' || $1;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".mod_table (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".mod_table (OID) TO basetenread;


-- Returns the modification rule or trigger name associated with the given operation.
CREATE FUNCTION "baseten".mod_rule (TEXT)
RETURNS TEXT AS $$
	SELECT '~baseten_modification_' || upper ($1);
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".mod_rule (TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".mod_rule (TEXT) TO basetenread;


CREATE FUNCTION "baseten".mod_insert_fn (OID)
RETURNS TEXT AS $$
	SELECT 'mod_insert_fn__' || $1;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".mod_insert_fn (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".mod_insert_fn (OID) TO basetenread;


CREATE FUNCTION "baseten".lock_fn (OID) RETURNS TEXT AS $$
	SELECT 'lock_fn__' || $1;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_fn (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_fn (OID) TO basetenread;


CREATE FUNCTION "baseten".lock_table (OID) RETURNS TEXT AS $$
	SELECT 'lock__' || $1;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_table (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_table (OID) TO basetenread;


CREATE FUNCTION "baseten".lock_notification (OID) RETURNS TEXT AS $$
	SELECT 'baseten_lock__' || $1;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_notification (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_notification (OID) TO basetenread;


-- Removes tracked modifications which are older than 5 minutes and set the modification timestamps 
-- that have been left to null values from the last commit. Since the rows that have the same 
-- backend PID as the current process might not yet be visible to other transactions. 
-- FIXME: If we knew the current transaction status, the WHERE clause could be rewritten as:
-- WHERE "baseten_modification_timestamp" IS NULL 
--	   AND ("baseten_modification_backend_pid" != pg_backend_pid () OR pg_xact_status = 'IDLE');
-- Also, if the connection is not autocommitting, we might end up doing some unnecessary work.
-- For now, we trust the user to set the function parameter if the performing connection isn't in the
-- middle of a transaction.
CREATE FUNCTION "baseten".mod_cleanup (BOOLEAN) RETURNS VOID AS $$
	DELETE FROM "baseten".modification 
		WHERE "baseten_modification_timestamp" < CURRENT_TIMESTAMP - INTERVAL '5 minutes';
	UPDATE "baseten".modification SET "baseten_modification_timestamp" = clock_timestamp ()
		WHERE "baseten_modification_timestamp" IS NULL AND ($1 OR "baseten_modification_backend_pid" != pg_backend_pid ());
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".mod_cleanup (BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".mod_cleanup (BOOLEAN) TO basetenread;


-- A trigger function for notifying the front ends and removing old tracked modifications
CREATE FUNCTION "baseten".mod_notify () RETURNS TRIGGER AS $$
BEGIN
	EXECUTE 'NOTIFY ' || TG_ARGV [0];
	RETURN NEW;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".mod_notify () FROM PUBLIC;


-- Removes tracked locks for which a backend no longer exists
-- FIXME: add a check to the function to ensure that the connection is autocommitting
CREATE FUNCTION "baseten".lock_cleanup () RETURNS VOID AS $$ 
	DELETE FROM "baseten".lock
		WHERE ("baseten_lock_timestamp" < pg_postmaster_start_time ()) -- Locks cannot be older than postmaster
			OR ("baseten_lock_backend_pid" NOT IN  (SELECT pid FROM "baseten".running_backend_pids () AS r (pid))) -- Locks have to be owned by a running backend
			OR ("baseten_lock_cleared" = true AND "baseten_lock_timestamp" < CURRENT_TIMESTAMP - INTERVAL '5 minutes'); -- Cleared locks older than 5 minutes may be removed
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_cleanup () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_cleanup () TO basetenread;


-- Unlock for this connection.
CREATE FUNCTION "baseten".lock_unlock () RETURNS VOID AS $$ 
	UPDATE "baseten".lock 
	SET "baseten_lock_cleared" = true, "baseten_lock_timestamp" = CURRENT_TIMESTAMP 
	WHERE "baseten_lock_backend_pid" = pg_backend_pid ()
		AND "baseten_lock_timestamp" < CURRENT_TIMESTAMP;
	NOTIFY "baseten_unlocked_locks";
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_unlock () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_unlock () TO basetenuser;


-- Step back lock marks
CREATE FUNCTION "baseten".lock_step_back () RETURNS VOID AS $$ 
	UPDATE "baseten".lock 
	SET "baseten_lock_cleared" = true, "baseten_lock_timestamp" = CURRENT_TIMESTAMP 
	WHERE baseten_lock_backend_pid = pg_backend_pid () 
		AND "baseten_lock_savepoint_idx" = 
			(SELECT max ("baseten_lock_savepoint_idx") 
			 FROM "baseten".lock
			 WHERE "baseten_lock_backend_pid" = pg_backend_pid ()
			);
	NOTIFY "baseten_unlocked_locks";
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_step_back () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_step_back () TO basetenuser;


-- A trigger function for notifying the front ends and removing old tracked locks
CREATE FUNCTION "baseten".lock_notify () RETURNS TRIGGER AS $$
BEGIN
	PERFORM "baseten".lock_cleanup ();
	EXECUTE 'NOTIFY ' || TG_ARGV [0];
	RETURN NEW;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_notify () FROM PUBLIC;


CREATE FUNCTION "baseten".observing_compatible (OID) RETURNS boolean AS $$
	SELECT EXISTS (SELECT relid FROM "baseten".enabled_relation WHERE relid = $1);
$$ STABLE LANGUAGE SQL EXTERNAL SECURITY INVOKER;
COMMENT ON FUNCTION "baseten".observing_compatible (OID) IS 'Checks for observing compatibility. Returns a boolean.';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".observing_compatible (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".observing_compatible (OID) TO basetenread;


CREATE FUNCTION "baseten".observing_compatible_ex (OID) RETURNS VOID AS $$
DECLARE
	relid ALIAS FOR $1;
BEGIN
	IF NOT ("baseten".observing_compatible (relid)) THEN
		RAISE EXCEPTION 'Relation with OID % has not been enabled', relid;
	END IF;
	RETURN;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".observing_compatible_ex (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".observing_compatible_ex (OID) TO basetenread;


-- A convenience function for observing modifications
-- Subscribes the caller to receive the approppriate notification
CREATE FUNCTION "baseten".mod_observe (OID) RETURNS "baseten".observation_type AS $$
DECLARE
	relid ALIAS FOR $1;
	nname TEXT;
	retval "baseten".observation_type;
BEGIN
	PERFORM "baseten".observing_compatible_ex (relid);
	nname := "baseten".mod_notification (relid);
	RAISE NOTICE 'Observing: %', nname;
	EXECUTE 'LISTEN ' || quote_ident (nname);

	retval := (relid, nname, null::TEXT, null::TEXT);
	RETURN retval;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".mod_observe (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".mod_observe (OID) TO basetenread;


CREATE FUNCTION "baseten".mod_observe_stop (OID) RETURNS VOID AS $$
DECLARE 
	relid ALIAS FOR $1;
BEGIN
	EXECUTE 'UNLISTEN ' || quote_ident ("baseten".mod_notification (relid));
	RETURN;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".mod_observe_stop (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".mod_observe_stop (OID) TO basetenread;


-- A convenience function for observing locks
-- Subscribes the caller to receive the approppriate notification
CREATE FUNCTION "baseten".lock_observe (OID) RETURNS "baseten".observation_type AS $$
DECLARE
	relid ALIAS FOR $1;
	nname TEXT;
	retval "baseten".observation_type;
BEGIN
	PERFORM "baseten".observing_compatible_ex (relid);

	-- Don't create if exists.
	-- Using PERFORM & checking FOUND might cause a race condition.
	BEGIN
		CREATE TEMPORARY SEQUENCE "baseten_lock_seq";
	EXCEPTION WHEN OTHERS THEN
	END;

	nname := "baseten".lock_notification (relid);
	RAISE NOTICE 'Observing: %', nname;
	EXECUTE 'LISTEN ' || quote_ident (nname);

	retval := (relid, nname, "baseten".lock_fn (relid), "baseten".lock_table (relid));
	RETURN retval;
END;
$$ VOLATILE LANGUAGE PLPGSQL EXTERNAL SECURITY INVOKER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_observe (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_observe (OID) TO basetenuser;


CREATE FUNCTION "baseten".lock_observe_stop (OID) RETURNS VOID AS $$
DECLARE 
	relid ALIAS FOR $1;
BEGIN
	EXECUTE 'UNLISTEN ' || quote_ident ("baseten".lock_notification (relid));
	RETURN;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_observe_stop (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_observe_stop (OID) TO basetenuser;


-- Remove the modification tracking table, rules and the trigger
CREATE FUNCTION "baseten".disable (OID) RETURNS "baseten".reltype AS $$
DECLARE
	relid ALIAS FOR $1;
	retval "baseten"."reltype";
BEGIN	 
	EXECUTE 'DROP FUNCTION IF EXISTS ' || "baseten".mod_insert_fn (relid) || ' () CASCADE';
	EXECUTE 'DROP TABLE IF EXISTS ' || "baseten".lock_table (relid) || ' CASCADE';
	EXECUTE 'DROP TABLE IF EXISTS ' || "baseten".mod_table (relid) || ' CASCADE';
	DELETE FROM "baseten".enabled_relation r WHERE r.relid = relid;
	retval := "baseten".reltype (relid);
	RETURN retval;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
COMMENT ON FUNCTION "baseten".disable (OID) IS 'Removes BaseTen tables for a specific relation';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".disable (OID) FROM PUBLIC;


-- A helper function
CREATE FUNCTION "baseten".enable_table_insert (OID, NAME []) 
RETURNS VOID AS $marker$
DECLARE
	relid	ALIAS FOR $1;
	pkey	NAME [] DEFAULT $2;
	rel		"baseten".reltype;
	query	TEXT;
	mtable	TEXT;
	fname	TEXT;
	fdecl	TEXT;
BEGIN
	SELECT "baseten".mod_table (relid) INTO STRICT mtable;
	SELECT "baseten".mod_insert_fn (relid) INTO STRICT fname;
	rel := "baseten".reltype (relid);
	-- Trigger functions cannot be written in SQL
	fdecl :=
		'CREATE OR REPLACE FUNCTION "baseten".' || quote_ident (fname) || ' () RETURNS TRIGGER AS $$ ' ||
		'BEGIN ' ||
			'INSERT INTO "baseten".' || quote_ident (mtable) || ' ' ||
				'("baseten_modification_type", ' || array_to_string (pkey, ', ') || ') ' ||
				'VALUES ' || 
				'(''I'', ' || array_to_string ("baseten".array_prepend_each ('NEW.', pkey), ', ') || '); ' ||
			'RETURN NEW; ' ||
		'END; ' ||
		'$$ VOLATILE LANGUAGE PLPGSQL EXTERNAL SECURITY DEFINER';
	query := 
		'CREATE TRIGGER ' || quote_ident ("baseten".mod_rule ('INSERT')) || ' ' ||
			'AFTER INSERT ON ' || quote_ident (rel.nspname) || '.' || quote_ident (rel.relname) || ' ' || 
			'FOR EACH ROW EXECUTE PROCEDURE "baseten".' || quote_ident (fname) || ' ()'; 
	EXECUTE fdecl;
	EXECUTE query;
	EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION "baseten".' || quote_ident (fname) || ' () FROM PUBLIC';
	RETURN;
END;
$marker$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION
	"baseten".enable_table_insert (OID, NAME []) 
	FROM PUBLIC;


-- Another helper function
CREATE FUNCTION "baseten".enable_view_insert (OID, TEXT) 
RETURNS VOID AS $marker$
DECLARE
	relid			ALIAS FOR $1;
	default_value	ALIAS FOR $2;
	rel				"baseten".reltype;
	query			TEXT;
	insertion		TEXT;
BEGIN
	rel := "baseten".reltype (relid);
	insertion := 
		'INSERT INTO "baseten".' || quote_ident ("baseten".mod_table (relid)) || ' ' ||
			'("baseten_modification_type", id) ' || 
			'VALUES ' || 
			'(''I'', ' || default_value || ')';
	query := 
		'CREATE RULE ' || quote_ident ("baseten".mod_rule ('INSERT')) || ' ' ||
			'AS ON INSERT TO ' || quote_ident (rel.nspname) || '.' || quote_ident (rel.relname) || ' ' ||
			'DO ALSO (' || insertion || ');';
	EXECUTE query;
	RETURN;
END;
$marker$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION
	"baseten".enable_view_insert (OID, TEXT)
	FROM PUBLIC;


-- Another helper function
CREATE FUNCTION "baseten".enable_other (TEXT, OID, NAME []) 
RETURNS VOID AS $marker$
DECLARE
	querytype		TEXT DEFAULT $1;
	relid			ALIAS FOR $2;
	pkey			NAME [] DEFAULT $3;
	rel				"baseten".reltype;
	query			TEXT;
	insertion		TEXT;
	whereclause		TEXT DEFAULT '';
BEGIN
	querytype	:= upper (querytype);
	rel := "baseten".reltype (relid);

	IF querytype = 'INSERT' THEN
		insertion := "baseten".enable_insert_query (relid, 'I', 'NEW.', pkey);
	ELSIF querytype = 'DELETE' THEN
		insertion := "baseten".enable_insert_query (relid, 'D', 'OLD.', pkey);
	ELSE -- UPDATE, UPDATE_PK
		whereclause := array_to_string (
			"baseten".array_cat_each (
				"baseten".array_prepend_each ('OLD.', pkey),
				"baseten".array_prepend_each ('NEW.', pkey),
				' = '
			), ' AND '
		);
		IF querytype = 'UPDATE' THEN
			insertion := "baseten".enable_insert_query (relid, 'U', 'NEW.', pkey);
		ELSIF querytype = 'UPDATE_PK' THEN
			querytype := 'UPDATE';
			insertion := 
				"baseten".enable_insert_query (relid, 'D', 'OLD.', pkey) || '; ' ||
				"baseten".enable_insert_query (relid, 'I', 'NEW.', pkey);
			whereclause := 'NOT (' || whereclause || ')';
		END IF;
		whereclause := ' WHERE ' || whereclause;
	END IF;

	query := 
		'CREATE RULE ' || quote_ident ("baseten".mod_rule ($1)) || ' AS ON ' || querytype ||
		' TO ' || quote_ident (rel.nspname) || '.' || quote_ident (rel.relname) ||
		whereclause || ' DO ALSO (' || insertion || ')';
	EXECUTE query;
	RETURN;
END;
$marker$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION
	"baseten".enable_other (TEXT, OID, NAME [])
	FROM PUBLIC;


-- Another helper function
CREATE FUNCTION "baseten".enable_insert_query (OID, CHAR, TEXT, NAME [])
RETURNS TEXT AS $$
DECLARE
	relid		ALIAS FOR $1;
	operation	ALIAS FOR $2;
	refname		ALIAS FOR $3;
	pkey		TEXT;
	pkey_values TEXT;
BEGIN
	pkey := array_to_string ($4, ', ');
	pkey_values := array_to_string ("baseten".array_prepend_each (refname, $4), ', ');

	RETURN
		'INSERT INTO "baseten".' || quote_ident ("baseten".mod_table (relid)) || ' ' ||
			'("baseten_modification_type", ' || pkey || ') ' ||
			'VALUES ' || 
			'(''' || operation || ''',' || pkey_values || ')';
END;
$$ STABLE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION
	"baseten".enable_insert_query (OID, CHAR, TEXT, NAME [])
	FROM PUBLIC;


CREATE FUNCTION "baseten".enable_lock_fn (OID) 
RETURNS VOID AS $marker$
DECLARE
	relid							ALIAS FOR $1;
	lock_table						TEXT;
	lock_fn							TEXT;
	lock_notification				TEXT;
	i_args							TEXT [];
	fn_args							TEXT;
	fn_code							TEXT;
	query							TEXT;
	pkey							NAME [];
	pkey_types						NAME [];
BEGIN
	SELECT "baseten".lock_table (relid) INTO STRICT lock_table;
	SELECT "baseten".lock_fn (relid) INTO STRICT lock_fn;
	SELECT "baseten".lock_notification (relid) INTO STRICT lock_notification;
	SELECT
		"baseten".array_accum (quote_ident (p.attname)),
		"baseten".array_accum (quote_ident (p.type))
		FROM "baseten".primary_key_v p
		WHERE p.oid = relid
		GROUP BY p.oid
		INTO STRICT pkey, pkey_types;

	-- First argument is the modification type, second one the savepoint number.
	FOR i IN 1..(2 + array_upper (pkey_types, 1)) LOOP
		i_args [i] := '$' || i;
	END LOOP;
	fn_code := 
		'INSERT INTO "baseten".' || lock_table || ' ' ||
		'("baseten_lock_query_type", "baseten_lock_savepoint_idx", ' || array_to_string (pkey, ', ') || ') ' ||
		'VALUES' ||
		'(' || array_to_string (i_args, ', ') || ');' ||
		'NOTIFY ' || quote_ident (lock_notification) || ';';
	-- FIXME: add a check to the function to ensure that the connection is autocommitting
	fn_args := '(CHAR (1), BIGINT, ' || array_to_string (pkey_types, ', ') || ')';
	query := 
		'CREATE OR REPLACE FUNCTION "baseten".' || quote_ident (lock_fn) || ' ' || fn_args || ' ' ||
		'RETURNS VOID AS $$ ' || fn_code || ' $$ VOLATILE LANGUAGE SQL';
	EXECUTE query;
	EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION "baseten".' || quote_ident (lock_fn) || ' ' || fn_args || ' FROM PUBLIC';
	EXECUTE 'GRANT EXECUTE ON FUNCTION "baseten".' || quote_ident (lock_fn) || ' ' || fn_args || ' TO basetenuser';
END;
$marker$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".enable_lock_fn (OID) FROM PUBLIC;


CREATE FUNCTION "baseten".enable (OID, BOOLEAN, TEXT) 
RETURNS "baseten".reltype AS $marker$
DECLARE
	relid_							ALIAS FOR $1;
	handle_view_serial_id_column	ALIAS FOR $2;
	view_id_default_value			ALIAS FOR $3;
	is_view							BOOL;
	query							TEXT;
	
	mod_table						TEXT;
	lock_table						TEXT;
	
	pkey							NAME [];
	pkey_decl						TEXT;
	retval							"baseten"."reltype";
BEGIN
	SELECT "baseten".mod_table (relid_) INTO STRICT mod_table;
	SELECT "baseten".lock_table (relid_) INTO STRICT lock_table;
	SELECT 'v' = c.relkind FROM pg_class c WHERE c.oid = relid_ INTO STRICT is_view;
	
	SELECT
		"baseten".array_accum (quote_ident (p.attname)),
		array_to_string ("baseten".array_accum (quote_ident (p.attname) || ' ' || p.type || ' NOT NULL'), ', ')
		FROM "baseten".primary_key_v p
		WHERE p.oid = relid_
		GROUP BY p.oid
		INTO STRICT pkey, pkey_decl;

	-- Locking
	query := 
		'CREATE TABLE "baseten".' || quote_ident (lock_table) || ' (' ||
			'"baseten_lock_relid" OID NOT NULL DEFAULT ' || relid_ || ', ' ||
			pkey_decl ||
		') INHERITS ("baseten".lock)';
	EXECUTE query;
	EXECUTE 'REVOKE ALL PRIVILEGES ON "baseten".' || quote_ident (lock_table) || ' FROM PUBLIC';
	EXECUTE 'GRANT SELECT ON "baseten".' || quote_ident (lock_table) || ' TO basetenread';
	EXECUTE 'GRANT INSERT ON "baseten".' || quote_ident (lock_table) || ' TO basetenuser';

	-- Trigger for the _lock_ table
	query :=
		'CREATE TRIGGER "lock_row" ' ||
		'AFTER INSERT ON "baseten".' || quote_ident (lock_table) || ' ' ||
		'FOR EACH STATEMENT EXECUTE PROCEDURE "baseten".lock_notify (''' || "baseten".lock_notification (relid_) || ''')';
	EXECUTE query;

	-- Locking function
	PERFORM "baseten".enable_lock_fn (relid_);

	-- Modifications
	query :=
		'CREATE TABLE "baseten".' || quote_ident (mod_table) || ' (' ||
			'"baseten_modification_relid" OID NOT NULL DEFAULT ' || relid_ || ', ' ||
			pkey_decl ||
		') INHERITS ("baseten".modification)';
	EXECUTE query;
	EXECUTE 'REVOKE ALL PRIVILEGES ON "baseten".' || quote_ident (mod_table) || ' FROM PUBLIC';
	EXECUTE 'GRANT INSERT ON "baseten".' || quote_ident (mod_table) || ' TO basetenuser';
	EXECUTE 'GRANT SELECT ON "baseten".' || quote_ident (mod_table) || ' TO basetenread';
	
	-- Triggers for the _modification_ table
	query :=
		'CREATE TRIGGER "modify_table" ' ||
		'AFTER INSERT ON "baseten".' || quote_ident (mod_table) || ' ' ||
		'FOR EACH STATEMENT EXECUTE PROCEDURE "baseten".mod_notify (''' || "baseten".mod_notification (relid_) || ''')';
	EXECUTE query;
	query :=
		'CREATE TRIGGER "set_mod_id" ' ||
		'BEFORE INSERT ON "baseten".' || quote_ident (mod_table) || ' ' ||
		'FOR EACH ROW EXECUTE PROCEDURE "baseten".set_mod_id ()';
	EXECUTE query;
	
	-- Triggers for the enabled relation.
	IF is_view THEN
		IF handle_view_serial_id_column THEN
			PERFORM "baseten".enable_view_insert (relid_, view_id_default_value);
		ELSE
			PERFORM "baseten".enable_other ('insert', relid_, pkey);
		END IF;
	ELSE
		PERFORM "baseten".enable_table_insert (relid_, pkey) ;
	END IF;
	PERFORM "baseten".enable_other ('delete', relid_, pkey);
	PERFORM "baseten".enable_other ('update', relid_, pkey);
	PERFORM "baseten".enable_other ('update_pk', relid_, pkey);
	INSERT INTO "baseten".enabled_relation (relid) VALUES (relid_);

	retval := "baseten".reltype (relid_);
	RETURN retval;
END;
$marker$ VOLATILE LANGUAGE PLPGSQL;
	

CREATE FUNCTION "baseten".enable (OID) RETURNS "baseten".reltype AS $$
	SELECT "baseten".enable ($1, false, null);
$$ VOLATILE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".enable (OID) FROM PUBLIC;
COMMENT ON FUNCTION "baseten".enable (OID) IS 'BaseTen-enables a relation';


CREATE FUNCTION "baseten".modification (OID, BOOL, TIMESTAMP, INTEGER)
RETURNS SETOF RECORD AS $marker$
DECLARE
	relid			ALIAS FOR $1;
	idle_xact		ALIAS FOR $2;
	earliest_date	ALIAS FOR $3;
	ignored_be_pid	INTEGER DEFAULT $4;
	query			TEXT;
	mtable			TEXT;
	pkey			TEXT;
	columns			TEXT;
	date_str		TEXT;
	order_by		TEXT;
	retval			RECORD;
BEGIN
	SELECT "baseten".mod_table (relid) INTO STRICT mtable;
	SELECT 
		array_to_string ("baseten".array_accum (quote_ident (p.attname)), ', '),
		array_to_string ("baseten".array_append_each (' ASC', "baseten".array_accum (quote_ident (p.attname))), ', ')
		FROM "baseten".primary_key p
		WHERE p.oid = relid
		GROUP BY p.oid
		INTO STRICT pkey, order_by;
	date_str := COALESCE (earliest_date, '-infinity');
	ignored_be_pid := COALESCE (ignored_be_pid, 0);
	columns := '"baseten_modification_type", "baseten_modification_timestamp", "baseten_modification_insert_timestamp", ' || pkey;
	
	PERFORM "baseten".mod_cleanup (idle_xact);
	query :=
		'SELECT ' || columns || ' FROM (' ||
			'SELECT DISTINCT ON (' || pkey || ') ' || columns || ' ' ||
			'FROM "baseten".' || quote_ident (mtable) || ' ' ||
			'WHERE ("baseten_modification_timestamp" > ''' || date_str || '''::timestamp OR "baseten_modification_timestamp" IS NULL) AND ' ||
				'baseten_modification_backend_pid != ' || ignored_be_pid || ' ' ||
			'ORDER BY ' || order_by || ', "baseten_modification_type" ASC' ||
		') a ' ||
		'UNION ' || -- Not UNION ALL
		'SELECT ' || columns || ' FROM (' ||
			'SELECT DISTINCT ON (' || pkey || ') ' || columns || ' ' ||
			'FROM "baseten".' || quote_ident (mtable) || ' ' ||
			'WHERE ("baseten_modification_type" = ''D'' OR "baseten_modification_type" = ''I'') AND ' ||
				'("baseten_modification_timestamp" > ''' || date_str || '''::timestamp OR "baseten_modification_timestamp" IS NULL) AND ' ||
				'baseten_modification_backend_pid != ' || ignored_be_pid || ' ' ||
			'ORDER BY ' || order_by || ', "baseten_modification_timestamp" DESC, "baseten_modification_insert_timestamp" DESC' ||
		') b ' ||
		'ORDER BY "baseten_modification_timestamp" DESC, "baseten_modification_insert_timestamp" DESC';
	
	-- FIXME: for debugging
	RAISE NOTICE 'Modifications: %', query;
	
	FOR retval IN EXECUTE query
	LOOP
		RETURN NEXT retval;
	END LOOP;
	RETURN;
END;		 
$marker$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".modification (OID, BOOL, TIMESTAMP, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".modification (OID, BOOL, TIMESTAMP, INTEGER) TO basetenread;


CREATE FUNCTION "baseten".refresh_caches () RETURNS void AS $$
	TRUNCATE "baseten".primary_key, "baseten".viewdependency, "baseten".srcdstview, "baseten".relationship;
	INSERT INTO "baseten".primary_key SELECT * from "baseten".primary_key_v;
	INSERT INTO "baseten".viewdependency SELECT * from "baseten".viewdependency_v;
	INSERT INTO "baseten".srcdstview SELECT * FROM "baseten".srcdstview ();
	INSERT INTO "baseten".relationship SELECT * FROM "baseten".relationship_v;
$$ VOLATILE LANGUAGE SQL EXTERNAL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".refresh_caches () FROM PUBLIC;
-- Only owner for now.


GRANT basetenread TO basetenuser;
COMMIT; -- Functions
