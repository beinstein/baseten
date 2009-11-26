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
define({{_bx_version_}}, {{0.933}})dnl
define({{_bx_compat_version_}}, {{0.19}})dnl


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
		
		PERFORM rolname FROM pg_roles WHERE rolname = 'basetenowner';
		IF NOT FOUND THEN
			CREATE ROLE basetenowner WITH
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
$$ IMMUTABLE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".array_prepend_each (TEXT, TEXT [])  FROM PUBLIC;
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
$$ IMMUTABLE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".array_append_each (TEXT, TEXT [])	 FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".array_append_each (TEXT, TEXT []) TO basetenread;


CREATE FUNCTION "baseten".split_part (string TEXT, delimiter TEXT, field INTEGER) RETURNS TEXT AS $$
DECLARE
	retval TEXT;
BEGIN
	SELECT split_part ($1, $2, $3) INTO retval;
	IF 0 = length (retval) THEN
		retval := null;
	END IF;
	RETURN retval;
END;
$$ IMMUTABLE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".split_part (TEXT, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".split_part (TEXT, TEXT, INTEGER) TO basetenread;


CREATE FUNCTION "baseten".running_backend_pids () 
RETURNS SETOF INTEGER AS $$
	SELECT 
		pg_stat_get_backend_pid (idset.id) AS pid 
	FROM pg_stat_get_backend_idset () AS idset (id);
$$ VOLATILE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".running_backend_pids () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".running_backend_pids () TO basetenread;


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


CREATE TYPE "baseten".view_type AS (
	oid OID,
	parent OID,
	root OID,
	generation SMALLINT
);


CREATE TYPE "baseten".observation_type AS (
	oid OID,
	identifier INTEGER,
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
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".oidof (TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".oidof (TEXT, TEXT) TO basetenread;


CREATE FUNCTION "baseten".oidof (TEXT) RETURNS "baseten".reltype AS $$
	SELECT "baseten".oidof ('public', $1);
$$ STABLE LANGUAGE SQL;
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
GRANT SELECT ON TABLE "baseten".view_pkey TO basetenread;


CREATE TABLE "baseten".relation (
	id SERIAL PRIMARY KEY,
	nspname NAME NOT NULL,
	relname NAME NOT NULL,
	relkind CHAR (1) NOT NULL,
	enabled BOOLEAN NOT NULL DEFAULT false,
	UNIQUE (nspname, relname)
);
REVOKE ALL PRIVILEGES ON TABLE "baseten".relation FROM PUBLIC;
GRANT SELECT ON TABLE "baseten".relation TO basetenread;


CREATE TABLE "baseten".foreign_key (
	conid SERIAL PRIMARY KEY,
	conname NAME NOT NULL,
	conrelid INTEGER NOT NULL REFERENCES "baseten".relation (id) ON UPDATE CASCADE ON DELETE CASCADE,
	confrelid INTEGER NOT NULL REFERENCES "baseten".relation (id) ON UPDATE CASCADE ON DELETE CASCADE,
	conkey NAME[] NOT NULL,
	confkey NAME[] NOT NULL,
	confdeltype CHAR NOT NULL,
	conkey_is_unique BOOLEAN NOT NULL,
	UNIQUE (conrelid, conname)
);
REVOKE ALL PRIVILEGES ON TABLE "baseten".foreign_key FROM PUBLIC;
GRANT SELECT ON TABLE "baseten".foreign_key TO basetenread;


-- We can do all sorts of joins here because this view isn't cached.
CREATE VIEW "baseten"._primary_key AS
	SELECT 
		r.id,
		c.oid,
		r.relkind,
		r.nspname,
		r.relname,
		a.attnum,
		a.attname,
		n2.nspname AS typnspname,
		t.typname
	FROM baseten.relation r
	INNER JOIN pg_class c ON (c.relname = r.relname)
	INNER JOIN pg_namespace n1 ON (n1.nspname = r.nspname AND n1.oid = c.relnamespace)
	LEFT OUTER JOIN pg_constraint co ON (r.relkind = 'r' AND co.conrelid = c.oid AND co.contype = 'p') -- Tables
	LEFT OUTER JOIN "baseten".view_pkey vp ON (r.relkind = 'v' AND vp.nspname = n1.nspname AND vp.relname = c.relname) -- Views
	INNER JOIN pg_attribute a ON (a.attrelid = c.oid AND (
		(r.relkind = 'r' AND a.attnum = ANY (co.conkey)) OR
		(r.relkind = 'v' AND vp.attname = a.attname)
	))
	INNER JOIN pg_type t ON (t.oid = a.atttypid)
	INNER JOIN pg_namespace n2 ON (n2.oid = t.typnamespace)
	ORDER BY r.id, a.attnum;
REVOKE ALL PRIVILEGES ON "baseten"._primary_key FROM PUBLIC;
GRANT SELECT ON "baseten"._primary_key TO basetenread;


CREATE FUNCTION "baseten"._fkey_columns_max () RETURNS INTEGER AS $$
	SELECT max (array_upper (conkey, 1)) FROM pg_constraint c WHERE c.contype = 'f';
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._fkey_columns_max () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._fkey_columns_max () TO basetenread;


CREATE VIEW "baseten"._fkey_column_names AS
SELECT 
	c.oid, 
	"baseten".array_accum (a1.attname) AS conkey,
	"baseten".array_accum (a2.attname) AS confkey
FROM pg_constraint c 
INNER JOIN generate_series (1, "baseten"._fkey_columns_max ()) AS s (idx) ON (s.idx <= array_upper (c.conkey, 1))
INNER JOIN pg_attribute a1 ON (a1.attrelid = c.conrelid  AND a1.attnum = c.conkey [s.idx])
INNER JOIN pg_attribute a2 ON (a2.attrelid = c.confrelid AND a2.attnum = c.confkey [s.idx])
GROUP BY c.oid;
REVOKE ALL PRIVILEGES ON "baseten"._fkey_column_names FROM PUBLIC;
GRANT SELECT ON "baseten"._fkey_column_names TO basetenread;


CREATE TABLE "baseten".ignored_fkey (
	nspname NAME,
	relname NAME,
	fkeyname NAME,
	PRIMARY KEY (nspname, relname, fkeyname)
);
REVOKE ALL PRIVILEGES ON "baseten".ignored_fkey FROM PUBLIC;
GRANT SELECT ON "baseten".ignored_fkey TO basetenread;


CREATE TABLE "baseten".relationship (
	conid			INTEGER NOT NULL REFERENCES "baseten".foreign_key (conid),
	dstconid		INTEGER REFERENCES "baseten".foreign_key (conid), -- Only used for mtm.
	name			VARCHAR (255) NOT NULL,
	inversename		VARCHAR (255) NOT NULL, --Inverse relationships are currently mandatory.
	kind			CHAR (1) NOT NULL,
	is_inverse		BOOLEAN NOT NULL,
	is_deprecated	BOOLEAN NOT NULL DEFAULT false,
	has_rel_names	BOOLEAN NOT NULL,
	has_views		BOOLEAN NOT NULL DEFAULT false,
	srcid			INTEGER NOT NULL REFERENCES "baseten".relation (id),
	srcnspname		TEXT NOT NULL,
	srcrelname		TEXT NOT NULL,
	dstid			INTEGER NOT NULL REFERENCES "baseten".relation (id),
	dstnspname		TEXT NOT NULL,
	dstrelname		TEXT NOT NULL,
	helperid		INTEGER REFERENCES "baseten".relation (id),
	helpernspname	TEXT,
	helperrelname	TEXT
);
REVOKE ALL PRIVILEGES ON "baseten".relationship FROM PUBLIC;
GRANT SELECT ON "baseten".relationship TO basetenread;


CREATE TABLE "baseten"._deprecated_relationship_name (
	LIKE "baseten".relationship INCLUDING DEFAUlTS INCLUDING CONSTRAINTS INCLUDING INDEXES,
	is_ambiguous BOOLEAN NOT NULL DEFAULT false
);
REVOKE ALL PRIVILEGES ON "baseten"._deprecated_relationship_name FROM PUBLIC;
GRANT SELECT ON "baseten"._deprecated_relationship_name TO basetenread;


-- For modification tracking
CREATE SEQUENCE "baseten".modification_id_seq MAXVALUE 2147483647 CYCLE;
CREATE TABLE "baseten".modification (
	"baseten_modification_id"				INTEGER PRIMARY KEY DEFAULT nextval ('"baseten"."modification_id_seq"'),
	"baseten_modification_relid"			INTEGER NOT NULL REFERENCES "baseten".relation (id),
	"baseten_modification_timestamp"		TIMESTAMP (6) WITHOUT TIME ZONE NULL DEFAULT NULL,
	"baseten_modification_insert_timestamp" TIMESTAMP (6) WITHOUT TIME ZONE NOT NULL DEFAULT clock_timestamp (),
	"baseten_modification_type"				CHAR NOT NULL,
	"baseten_modification_backend_pid"		INTEGER NOT NULL DEFAULT pg_backend_pid ()
);
ALTER SEQUENCE "baseten".modification_id_seq OWNED BY "baseten".modification."baseten_modification_id";
REVOKE ALL PRIVILEGES ON SEQUENCE "baseten".modification_id_seq FROM PUBLIC;
REVOKE ALL PRIVILEGES ON "baseten".modification FROM PUBLIC;
GRANT SELECT ON "baseten".modification TO basetenread;
GRANT USAGE ON SEQUENCE "baseten".modification_id_seq TO basetenuser;


CREATE SEQUENCE "baseten".lock_id_seq MAXVALUE 2147483647 CYCLE;
CREATE TABLE "baseten".lock (
	"baseten_lock_id"				INTEGER PRIMARY KEY DEFAULT nextval ('"baseten"."lock_id_seq"'),
	"baseten_lock_relid"			INTEGER NOT NULL REFERENCES "baseten".relation (id),
	"baseten_lock_timestamp"		TIMESTAMP (6) WITHOUT TIME ZONE NOT NULL DEFAULT clock_timestamp (),
	"baseten_lock_query_type"		CHAR (1) NOT NULL DEFAULT 'U',	 -- U == UPDATE, D == DELETE
	"baseten_lock_cleared"			BOOLEAN NOT NULL DEFAULT FALSE,
	"baseten_lock_savepoint_idx"	BIGINT NOT NULL,
	"baseten_lock_backend_pid"		INTEGER NOT NULL DEFAULT pg_backend_pid ()
);
ALTER SEQUENCE "baseten".lock_id_seq OWNED BY "baseten".lock."baseten_lock_id";
REVOKE ALL PRIVILEGES ON SEQUENCE "baseten".lock_id_seq FROM PUBLIC;
REVOKE ALL PRIVILEGES ON "baseten".lock FROM PUBLIC;
GRANT SELECT ON "baseten".lock TO basetenread;
GRANT USAGE ON SEQUENCE "baseten".lock_id_seq TO basetenuser;


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


CREATE FUNCTION "baseten".relation_id (OID) RETURNS INTEGER AS $$
	SELECT r.id
	FROM pg_class c
	INNER JOIN pg_namespace n ON (n.oid = c.relnamespace)
	INNER JOIN "baseten".relation r USING (relname, nspname)
	WHERE c.oid = $1;
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".relation_id (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".relation_id (OID) TO basetenread;


CREATE FUNCTION "baseten".relation_id_ex (OID) RETURNS INTEGER AS $$
DECLARE
	relid ALIAS FOR $1;
	retval INTEGER;
BEGIN
	SELECT "baseten".relation_id (relid) INTO STRICT retval;
	IF retval IS NULL THEN
		RAISE EXCEPTION 'Relation with OID % was not found', relid;
	END IF;
	RETURN retval;
END;
$$ STABLE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".relation_id_ex (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".relation_id_ex (OID) TO basetenread;


CREATE FUNCTION "baseten"._view_hierarchy (OID, OID, INTEGER) 
	RETURNS SETOF "baseten".view_type AS $$
DECLARE
	parent ALIAS FOR $1;
	root ALIAS FOR $2;
	generation ALIAS FOR $3;
	currentoid OID;
	retval "baseten".view_type;
	subview "baseten".view_type;
BEGIN
	retval.root = root;
	retval.parent = parent;
	retval.generation = generation::SMALLINT;

	-- Fetch dependent views
	FOR currentoid IN SELECT viewoid FROM "baseten"._view_dependency WHERE reloid = parent
	LOOP
		retval.oid := currentoid;
		RETURN NEXT retval;

		-- Recursion to subviews
		FOR subview IN SELECT * 
		FROM "baseten"._view_hierarchy (currentoid, root, generation + 1) LOOP
			RETURN NEXT subview;
		END LOOP;
	END LOOP;
	RETURN;
END;
$$ STABLE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._view_hierarchy (OID, OID, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._view_hierarchy (OID, OID, INTEGER) TO basetenread;


CREATE FUNCTION "baseten"._view_hierarchy (OID) RETURNS SETOF "baseten".view_type AS $$
DECLARE
	relid ALIAS FOR $1;
	retval "baseten".view_type;
BEGIN
	-- First return the table itself.
	retval.root = relid;
	retval.parent = NULL;
	retval.generation = 0::SMALLINT;
	retval.oid = relid;
	RETURN NEXT retval;

	-- Fetch dependent views.
	FOR retval IN SELECT * FROM "baseten"._view_hierarchy (relid, relid, 1) 
	LOOP
		RETURN NEXT retval;
	END LOOP;
	RETURN;
END;
$$ STABLE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._view_hierarchy (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._view_hierarchy (OID) TO basetenread;


CREATE FUNCTION "baseten"._rel_view_hierarchy () RETURNS SETOF "baseten".view_type AS $$
DECLARE
	reloid OID;
	retval "baseten".view_type;
BEGIN
	FOR reloid IN 
		SELECT DISTINCT ON (rs.srcid) 
			c.oid 
		FROM "baseten".relationship rs
		INNER JOIN "baseten".relation r ON (r.id = rs.srcid)
		INNER JOIN pg_class c ON (r.relname = c.relname)
		INNER JOIN pg_namespace n ON (r.nspname = n.nspname AND c.relnamespace = n.oid)
	LOOP
		FOR retval IN SELECT * FROM "baseten"._view_hierarchy (reloid)
		LOOP
			RETURN NEXT retval;
		END LOOP;
	END LOOP;
	RETURN;
END;
$$ STABLE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._rel_view_hierarchy () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._rel_view_hierarchy () TO basetenread;


-- Note that system views aren't correctly listed.
CREATE VIEW "baseten"._view_dependency_v AS 
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
REVOKE ALL PRIVILEGES ON "baseten"._view_dependency_v FROM PUBLIC;
GRANT SELECT ON "baseten"._view_dependency_v TO basetenread;


CREATE TABLE "baseten"._view_dependency AS SELECT * FROM "baseten"._view_dependency_v LIMIT 0;
REVOKE ALL PRIVILEGES ON "baseten"._view_dependency FROM PUBLIC;
GRANT SELECT ON "baseten"._view_dependency TO basetenread;


CREATE VIEW "baseten"._rel_view_hierarchy_v AS
	SELECT
		r1.id,
		r2.id AS root,
		r1.nspname,
		r1.relname,
		r2.nspname AS rootnspname,
		r2.relname AS rootrelname,
		"baseten".array_accum (a.attname) AS attributes
	FROM "baseten"._rel_view_hierarchy () h
	INNER JOIN pg_attribute a ON (a.attrelid = h.oid)
	INNER JOIN pg_class c1 ON (c1.oid = h.oid)
	INNER JOIN pg_class c2 ON (c2.oid = h.root)
	INNER JOIN pg_namespace n1 ON (n1.oid = c1.relnamespace)
	INNER JOIN pg_namespace n2 ON (n2.oid = c2.relnamespace)
	INNER JOIN "baseten".relation r1 ON (n1.nspname = r1.nspname AND c1.relname = r1.relname)
	INNER JOIN "baseten".relation r2 ON (n2.nspname = r2.nspname AND c2.relname = r2.relname)
	GROUP BY r1.id, r2.id, r1.nspname, r1.relname, r2.nspname, r2.relname;
	
	
CREATE TABLE "baseten"._rel_view_hierarchy AS SELECT * FROM "baseten"._rel_view_hierarchy_v LIMIT 0;
REVOKE ALL PRIVILEGES ON "baseten"._rel_view_hierarchy FROM PUBLIC;
GRANT SELECT ON "baseten"._rel_view_hierarchy TO basetenread;


CREATE VIEW "baseten"._rel_view_oneto_v AS
	SELECT
		r.conid,
		COALESCE (h1.id, srcid) AS srcid,
		COALESCE (h2.id, dstid) AS dstid,
		r.kind,
		r.is_inverse
	FROM
		(
			SELECT DISTINCT
				conid,
				srcid,
				dstid,
				kind,
				is_inverse
			FROM "baseten".relationship
			WHERE kind IN ('t', 'o')
		) r
	INNER JOIN "baseten".foreign_key f ON (f.conid = r.conid)
	INNER JOIN "baseten"._rel_view_hierarchy h1 ON (h1.root = r.srcid AND h1.attributes @> (CASE WHEN r.is_inverse THEN f.conkey ELSE f.confkey END))
	INNER JOIN "baseten"._rel_view_hierarchy h2 ON (h2.root = r.dstid AND h2.attributes @> (CASE WHEN r.is_inverse THEN f.confkey ELSE f.conkey END))
	WHERE NOT (h1.id = h1.root AND h2.id = h2.root);


CREATE TABLE "baseten"._rel_view_oneto AS SELECT * FROM "baseten"._rel_view_oneto_v LIMIT 0;
REVOKE ALL PRIVILEGES ON "baseten"._rel_view_oneto FROM PUBLIC;
GRANT SELECT ON "baseten"._rel_view_oneto TO basetenread;


CREATE VIEW "baseten"._rel_view_manytomany_v AS
	SELECT
		r.conid,
		r.dstconid,
		COALESCE (h1.id, r.srcid) AS srcid,
		COALESCE (h2.id, r.dstid) AS dstid,
		r.helperid
	FROM
		(
			SELECT DISTINCT ON (conid, dstconid, srcid, dstid) 
				conid,
				dstconid,
				srcid,
				dstid,
				helperid
			FROM "baseten".relationship
			WHERE kind = 'm'
		) r
	INNER JOIN "baseten".foreign_key f1 ON (f1.conid = r.conid)
	INNER JOIN "baseten".foreign_key f2 ON (f2.conid = r.dstconid)
	INNER JOIN "baseten"._rel_view_hierarchy h1 ON (h1.root = r.srcid AND h1.attributes @> f1.confkey)
	INNER JOIN "baseten"._rel_view_hierarchy h2 ON (h2.root = r.dstid AND h2.attributes @> f2.confkey)
	WHERE NOT (h1.id = h1.root AND h2.id = h2.root);


CREATE TABLE "baseten"._rel_view_manytomany AS SELECT * FROM "baseten"._rel_view_manytomany_v LIMIT 0;
REVOKE ALL PRIVILEGES ON "baseten"._rel_view_manytomany FROM PUBLIC;
GRANT SELECT ON "baseten"._rel_view_manytomany TO basetenread;


CREATE FUNCTION "baseten"._assign_relation_ids () RETURNS VOID AS $$
	DELETE FROM "baseten".relation r 
	WHERE ROW (r.relname, r.nspname, r.relkind) NOT IN (
		SELECT c.relname, n.nspname, c.relkind
		FROM pg_class c
		INNER JOIN pg_namespace n ON (c.relnamespace = n.oid)
		WHERE c.relkind IN ('r', 'v')
	);

	INSERT INTO "baseten".relation (relname, nspname, relkind)
		SELECT c.relname, n.nspname, c.relkind
		FROM pg_class c
		INNER JOIN pg_namespace n ON (c.relnamespace = n.oid)
		WHERE 
			c.relkind IN ('r', 'v') AND
			NOT (
				n.nspname = 'baseten' OR
				n.nspname = 'information_schema' OR
				n.nspname LIKE 'pg_%' OR
				ROW (c.relname, n.nspname) IN (
					SELECT r.relname, r.nspname FROM "baseten".relation r
				) 
			);
$$ VOLATILE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._assign_relation_ids () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._assign_relation_ids () TO basetenowner;


CREATE FUNCTION "baseten"._assign_foreign_key_ids () RETURNS VOID AS $$
	DELETE FROM "baseten".foreign_key f
	USING "baseten".relation r
	WHERE (
		r.id = f.conrelid AND
		ROW (r.nspname, r.relname, f.conname) NOT IN (
			SELECT
				n.nspname,
				cl.relname,
				co.conname
			FROM pg_constraint co
			INNER JOIN pg_class cl ON (cl.oid = co.conrelid)
			INNER JOIN pg_namespace n ON (n.oid = cl.relnamespace)
			WHERE co.contype = 'f'
		)
	);
	
	INSERT INTO "baseten".foreign_key 
		(
			conname,
			conrelid,
			confrelid,
			conkey,
			confkey,
			confdeltype,
			conkey_is_unique
		)
		SELECT
			c.conname,
			r1.id,
			r2.id,
			f.conkey,
			f.confkey,
			c.confdeltype,
			c2.oid IS NOT NULL
		FROM pg_constraint c
		INNER JOIN "baseten"._fkey_column_names f ON (f.oid = c.oid)
		INNER JOIN pg_class cl1 ON (cl1.oid = c.conrelid)
		INNER JOIN pg_class cl2 ON (cl2.oid = c.confrelid)
		INNER JOIN pg_namespace n1 ON (n1.oid = cl1.relnamespace)
		INNER JOIN pg_namespace n2 ON (n2.oid = cl2.relnamespace)
		INNER JOIN "baseten".relation r1 ON (r1.nspname = n1.nspname AND r1.relname = cl1.relname)
		INNER JOIN "baseten".relation r2 ON (r2.nspname = n2.nspname AND r2.relname = cl2.relname)
		LEFT OUTER JOIN pg_constraint c2 ON (
			c2.conrelid = c.conrelid AND
			c2.conkey = c.conkey AND
			c2.contype = 'u'
		)
		WHERE (
			c.contype = 'f' AND
			ROW (n1.nspname, cl1.relname, c.conname) NOT IN (SELECT * FROM "baseten".ignored_fkey) AND
			ROW (n1.nspname, cl1.relname, c.conname) NOT IN (
				SELECT
					r.nspname,
					r.relname,
					f.conname
				FROM "baseten".foreign_key f
				INNER JOIN "baseten".relation r ON (r.id = f.conrelid)
			)
		);
$$ VOLATILE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._assign_foreign_key_ids () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._assign_foreign_key_ids () TO basetenowner;


CREATE FUNCTION "baseten".assign_internal_ids () RETURNS VOID AS $$
	SELECT "baseten"._assign_relation_ids ();
	SELECT "baseten"._assign_foreign_key_ids ();
$$ VOLATILE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".assign_internal_ids () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".assign_internal_ids () TO basetenowner;


CREATE FUNCTION "baseten".refresh_view_caches () RETURNS void AS $$
	TRUNCATE 
		"baseten"._view_dependency, 
		"baseten"._rel_view_hierarchy, 
		"baseten"._rel_view_oneto, 
		"baseten"._rel_view_manytomany;
	INSERT INTO "baseten"._view_dependency		SELECT * from "baseten"._view_dependency_v;
	INSERT INTO "baseten"._rel_view_hierarchy	SELECT * from "baseten"._rel_view_hierarchy_v;
	INSERT INTO "baseten"._rel_view_oneto		SELECT * from "baseten"._rel_view_oneto_v;
	INSERT INTO "baseten"._rel_view_manytomany	SELECT * from "baseten"._rel_view_manytomany_v;
$$ VOLATILE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".refresh_view_caches () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".refresh_view_caches () TO basetenowner;


CREATE FUNCTION "baseten"._insert_relationships () RETURNS VOID AS $$
	SELECT "baseten".assign_internal_ids ();

	-- OTO, OTM
	INSERT INTO "baseten".relationship
		(
			conid,
			name,
			inversename,
			kind,
			is_inverse,
			has_rel_names,
			srcid,
			srcnspname,
			srcrelname,
			dstid,
			dstnspname,
			dstrelname
		)
		SELECT -- MTO
			f.conid,
			CASE WHEN 1 = COALESCE (g.idx, 1) THEN 
				COALESCE ("baseten".split_part (f.conname, '__', 1), r1.nspname || '_' || r1.relname || '_' || f.conname)
			ELSE 
				r2.relname::TEXT
			END,
			CASE WHEN 1 = COALESCE (g.idx, 1) THEN 
				COALESCE ("baseten".split_part (f.conname, '__', 2), r1.nspname || '_' || r1.relname || '_' || f.conname)
			ELSE 
				r1.relname::TEXT || CASE WHEN f.conkey_is_unique THEN '' ELSE 'Set' END
			END,
			CASE WHEN true = f.conkey_is_unique THEN 'o' ELSE 't' END,
			true,
			2 = COALESCE (g.idx, 1),
			f.conrelid,
			r1.nspname,
			r1.relname,
			f.confrelid,
			r2.nspname,
			r2.relname
		FROM "baseten".foreign_key f
		INNER JOIN "baseten".relation r1 ON (r1.id = f.conrelid)
		INNER JOIN "baseten".relation r2 ON (r2.id = f.confrelid)
		LEFT JOIN generate_series (1, 2) g (idx) ON (NOT (r2.relname = split_part (f.conname, '__', 1) OR r1.relname = split_part (f.conname, '__', 2)))
		WHERE r1.enabled = true AND r2.enabled = true
		UNION ALL
		SELECT -- OTM
			f.conid,
			CASE WHEN 1 = COALESCE (g.idx, 1) THEN 
				COALESCE ("baseten".split_part (f.conname, '__', 2), r1.nspname || '_' || r1.relname || '_' || f.conname)
			ELSE 
				r1.relname::TEXT || CASE WHEN f.conkey_is_unique THEN '' ELSE 'Set' END
			END,
			CASE WHEN 1 = COALESCE (g.idx, 1) THEN 
				COALESCE ("baseten".split_part (f.conname, '__', 1), r1.nspname || '_' || r1.relname || '_' || f.conname)
			ELSE 
				r2.relname::TEXT
			END,
			CASE WHEN true = f.conkey_is_unique THEN 'o' ELSE 't' END,
			false,
			2 = COALESCE (g.idx, 1),
			f.confrelid,
			r2.nspname,
			r2.relname,
			f.conrelid,
			r1.nspname,
			r1.relname
		FROM "baseten".foreign_key f
		INNER JOIN "baseten".relation r1 ON (r1.id = f.conrelid)
		INNER JOIN "baseten".relation r2 ON (r2.id = f.confrelid)
		LEFT JOIN generate_series (1, 2) g (idx) ON (NOT (r2.relname = split_part (f.conname, '__', 1) OR r1.relname = split_part (f.conname, '__', 2)))
		WHERE r1.enabled = true AND r2.enabled = true;
		
	-- MTM
	INSERT INTO "baseten".relationship
		(
			conid,
            dstconid,
            name,
            inversename,
            kind,
            is_inverse,
			has_rel_names,
            srcid,
            srcnspname,
            srcrelname,
            dstid,
            dstnspname,
            dstrelname,
			helperid,
            helpernspname,
            helperrelname
		)
		SELECT
			f1.conid,
			f2.conid,
			CASE WHEN 1 = COALESCE (g.idx, 1) THEN f1.conname ELSE r2.relname || 'Set' END,
			CASE WHEN 1 = COALESCE (g.idx, 1) THEN f2.conname ELSE r1.relname || 'Set' END,
			'm',
			false,
			2 = COALESCE (g.idx, 1),
			f1.confrelid,
			r1.nspname,
			r1.relname,
			f2.confrelid,
			r2.nspname,
			r2.relname,
			f1.conrelid,
			rh.nspname,
			rh.relname
		FROM "baseten".foreign_key f1
		INNER JOIN "baseten".foreign_key f2 ON (f1.conrelid = f2.conrelid AND f1.confrelid <> f2.confrelid)
		INNER JOIN (
			SELECT 
				conrelid,
				COUNT (conid) AS count
			FROM "baseten".foreign_key
			GROUP BY conrelid
		) c ON (c.conrelid = f1.conrelid AND 2 = c.count)
		INNER JOIN "baseten".relation rh ON (rh.id = f1.conrelid)
		INNER JOIN pg_class ch ON (ch.relname = rh.relname)
		INNER JOIN pg_namespace nh ON (nh.oid = ch.relnamespace AND nh.nspname = rh.nspname)
		INNER JOIN (
			SELECT
				c.conrelid AS reloid,
				"baseten".array_accum (a.attname) AS attnames
			FROM pg_constraint c
			INNER JOIN pg_attribute a ON (a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey))
			WHERE c.contype = 'p'
			GROUP BY c.conrelid
		) p ON (p.reloid = ch.oid AND p.attnames @> (f1.conkey || f2.conkey))
		INNER JOIN "baseten".relation r1 ON (r1.id = f1.confrelid)
		INNER JOIN "baseten".relation r2 ON (r2.id = f2.confrelid)
		LEFT JOIN generate_series (1, 2) g (idx) ON (NOT (r2.relname = f1.conname OR r1.relname = f2.conname))
		WHERE r1.enabled = true AND r2.enabled = true;
    
	-- Views
	SELECT "baseten".refresh_view_caches ();
	INSERT INTO "baseten".relationship
		(
			conid,
			dstconid,
			name,
			inversename,
			kind,
			is_inverse,
			has_rel_names,
			has_views,
			srcid,
			srcnspname,
			srcrelname,
			dstid,
			dstnspname,
			dstrelname,
			helperid,
			helpernspname,
			helperrelname
		)
		SELECT
			rel.conid,
			rel.dstconid,
			r2.relname || CASE WHEN 'm' = rel.kind OR ('t' = rel.kind AND rel.is_inverse = false) THEN 'Set' ELSE '' END,
			r1.relname || CASE WHEN 'm' = rel.kind OR ('t' = rel.kind AND rel.is_inverse = true)  THEN 'Set' ELSE '' END,
			rel.kind,
			rel.is_inverse,
			true,
			true,
			rel.srcid,
			r1.nspname,
			r1.relname,
			rel.dstid,
			r2.nspname,
			r2.relname,
			rel.helperid,
			r3.nspname,
			r3.relname
		FROM
			(
				SELECT 
					conid,
					null::INTEGER AS dstconid,
					kind,
					is_inverse,
					srcid,
					dstid,
					null::INTEGER AS helperid
				FROM "baseten"._rel_view_oneto
				UNION ALL
				SELECT
					conid,
					dstconid,
					'm' AS kind,
					false AS is_inverse,
					srcid,
					dstid,
					helperid
				FROM "baseten"._rel_view_manytomany
			) rel
		INNER JOIN "baseten".relation r1 ON (r1.id = rel.srcid)
		INNER JOIN "baseten".relation r2 ON (r2.id = rel.dstid)
		LEFT OUTER JOIN "baseten".relation r3 ON (r3.id = rel.helperid)
		WHERE r1.enabled = true AND r2.enabled = true AND (
            r3.id IS NULL OR r3.enabled = true
        );
$$ VOLATILE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._insert_relationships () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._insert_relationships () TO basetenowner;


CREATE FUNCTION "baseten"._insert_deprecated_relationships () RETURNS VOID AS $$
	-- Deprecated names
	INSERT INTO "baseten"._deprecated_relationship_name
		SELECT
			conid,
			dstconid,
			substring (name from 1 for length (name) - 3) AS name, -- Remove 'Set'
			substring (inversename from 1 for length (inversename) - 3) AS inversename, -- Remove 'Set'
			kind,
			is_inverse,
			true AS is_deprecated,
			has_rel_names,
			has_views,
			srcid,
			srcnspname,
			srcrelname,
			dstid,
			dstnspname,
			dstrelname,
			helperid,
			helpernspname,
			helperrelname,
			false AS is_ambiguous
		FROM "baseten".relationship
		WHERE kind = 'm' AND has_rel_names = true
		UNION ALL
		SELECT
			conid,
			dstconid,
			name || '__deprecation_placeholder' AS name,
			substring (inversename from 1 for length (inversename) - 3) AS inversename, -- Remove 'Set'
			kind,
			is_inverse,
			true AS is_deprecated,
			has_rel_names,
			has_views,
			srcid,
			srcnspname,
			srcrelname,
			dstid,
			dstnspname,
			dstrelname,
			helperid,
			helpernspname,
			helperrelname,
			false AS is_ambiguous
		FROM "baseten".relationship
		WHERE kind = 't' AND has_rel_names = true AND is_inverse = true
		UNION ALL
		SELECT
			conid,
			dstconid,
			substring (name from 1 for length (name) - 3) AS name, -- Remove 'Set'
			inversename || '__deprecation_placeholder' AS inversename,
			kind,
			is_inverse,
			true AS is_deprecated,
			has_rel_names,
			has_views,
			srcid,
			srcnspname,
			srcrelname,
			dstid,
			dstnspname,
			dstrelname,
			helperid,
			helpernspname,
			helperrelname,
			false AS is_ambiguous
		FROM "baseten".relationship
		WHERE kind = 't' AND has_rel_names = true AND is_inverse = false;
	
	-- Mark relationships that have to-one duplicates.
	UPDATE "baseten"._deprecated_relationship_name d
		SET is_ambiguous = true
		FROM "baseten".relationship r
		WHERE 
			d.name = r.name AND
			d.srcnspname = r.srcnspname AND
			d.srcrelname = r.srcrelname;
	
	-- Mark duplicates' inverse relationships.
	UPDATE "baseten"._deprecated_relationship_name d1
		SET is_ambiguous = true
		FROM "baseten"._deprecated_relationship_name d2
		WHERE 
			d1.conid = d2.conid AND
			d1.kind = d2.kind AND
			d1.kind IN ('t', 'o') AND
			d2.is_ambiguous = true;
	UPDATE "baseten"._deprecated_relationship_name d1
		SET is_ambiguous = true
		FROM "baseten"._deprecated_relationship_name d2
		WHERE
			d1.conid = d2.conid AND
			d1.dstconid = d2.dstconid AND
			d1.kind = d2.kind AND
			d1.kind = 'm' AND
			d2.is_ambiguous = true;
$$ VOLATILE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._insert_deprecated_relationships () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._insert_deprecated_relationships () TO basetenowner;


CREATE FUNCTION "baseten"._remove_ambiguous_relationships () RETURNS VOID AS $$
	DELETE FROM "baseten".relationship r1
	USING (
		SELECT name, srcid 
		FROM (
			SELECT 
				count (name), 
				name, 
				srcid 
			FROM baseten.relationship 
			GROUP BY name, srcid
		) r
		WHERE r.count = 2
	) r2
	WHERE r1.name = r2.name AND r1.srcid = r2.srcid;
	
	DELETE FROM "baseten".relationship r1
	USING (
		SELECT 
			r1.name, 
			r1.srcid 
		FROM baseten.relationship r1 
		LEFT OUTER JOIN baseten.relationship r2 ON (
			r1.inversename = r2.name AND
			r1.name = r2.inversename AND
			r1.dstid = r2.srcid AND 
			r1.srcid = r2.dstid 
		)
		WHERE r2.conid IS NULL
	) r2
	WHERE r1.name = r2.name AND r1.srcid = r2.srcid;
$$ VOLATILE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._remove_ambiguous_relationships () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._remove_ambiguous_relationships () TO basetenowner;


CREATE FUNCTION "baseten"._mod_notification (OID) RETURNS TEXT AS $$
	SELECT 'baseten_mod__' || "baseten".relation_id_ex ($1);
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._mod_notification (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._mod_notification (OID) TO basetenread;


CREATE FUNCTION "baseten"._mod_table (INTEGER) RETURNS TEXT AS $$
	SELECT 'mod__' || $1;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._mod_table (INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._mod_table (INTEGER) TO basetenread;


CREATE FUNCTION "baseten"._mod_table (OID) RETURNS TEXT AS $$
	SELECT 'mod__' || "baseten".relation_id_ex ($1);
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._mod_table (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._mod_table (OID) TO basetenread;


-- Returns the modification rule or trigger name associated with the given operation.
CREATE FUNCTION "baseten"._mod_rule (TEXT)
RETURNS TEXT AS $$
	SELECT '~baseten_modification_' || upper ($1);
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._mod_rule (TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._mod_rule (TEXT) TO basetenread;


CREATE FUNCTION "baseten"._mod_insert_fn (OID)
RETURNS TEXT AS $$
	SELECT 'mod_insert_fn__' || "baseten".relation_id_ex ($1);
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._mod_insert_fn (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._mod_insert_fn (OID) TO basetenread;


CREATE FUNCTION "baseten"._lock_fn (INTEGER) RETURNS TEXT AS $$
	SELECT 'lock_fn__' || $1;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._lock_fn (INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._lock_fn (INTEGER) TO basetenread;


CREATE FUNCTION "baseten"._lock_fn (OID) RETURNS TEXT AS $$
	SELECT 'lock_fn__' || "baseten".relation_id_ex ($1);
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._lock_fn (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._lock_fn (OID) TO basetenread;


CREATE FUNCTION "baseten"._lock_table (INTEGER) RETURNS TEXT AS $$
	SELECT 'lock__' || $1;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._lock_table (INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._lock_table (INTEGER) TO basetenread;


CREATE FUNCTION "baseten"._lock_table (OID) RETURNS TEXT AS $$
	SELECT 'lock__' || "baseten".relation_id_ex ($1);
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._lock_table (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._lock_table (OID) TO basetenread;


CREATE FUNCTION "baseten"._lock_notification (INTEGER) RETURNS TEXT AS $$
	SELECT 'baseten_lock__' || $1;
$$ IMMUTABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._lock_notification (INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._lock_notification (INTEGER) TO basetenread;


CREATE FUNCTION "baseten"._lock_notification (OID) RETURNS TEXT AS $$
	SELECT 'baseten_lock__' || "baseten".relation_id_ex ($1);
$$ STABLE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten"._lock_notification (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten"._lock_notification (OID) TO basetenread;


CREATE VIEW "baseten".pending_locks AS
	SELECT 
		baseten_lock_relid AS relid, 
		max (baseten_lock_timestamp) AS last_date, 
		"baseten"._lock_table (baseten_lock_relid) AS lock_table_name 
	FROM "baseten".lock 
	WHERE baseten_lock_cleared = true AND baseten_lock_backend_pid != pg_backend_pid ()
	GROUP BY relid, lock_table_name;
REVOKE ALL PRIVILEGES ON "baseten".pending_locks FROM PUBLIC;
GRANT SELECT ON "baseten".pending_locks TO basetenread;


-- Removes tracked modifications which are older than 5 minutes and set the modification timestamps 
-- that have been left to null values from the last commit. Since the rows that have the same 
-- backend PID as the current process might not yet be visible to other transactions. 
-- FIXME: If we knew the current transaction status, the WHERE clause could be rewritten as follows:
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
$$ VOLATILE LANGUAGE SQL SECURITY DEFINER;
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
$$ VOLATILE LANGUAGE SQL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_cleanup () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_cleanup () TO basetenread;


-- Unlock for this connection.
CREATE FUNCTION "baseten".lock_unlock () RETURNS VOID AS $$ 
	UPDATE "baseten".lock 
	SET "baseten_lock_cleared" = true, "baseten_lock_timestamp" = CURRENT_TIMESTAMP 
	WHERE "baseten_lock_backend_pid" = pg_backend_pid ()
		AND "baseten_lock_timestamp" < CURRENT_TIMESTAMP;
	NOTIFY "baseten_unlocked_locks";
$$ VOLATILE LANGUAGE SQL SECURITY DEFINER;
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
$$ VOLATILE LANGUAGE SQL SECURITY DEFINER;
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


CREATE FUNCTION "baseten".is_enabled (INTEGER) RETURNS boolean AS $$
	SELECT CASE WHEN 1 = COUNT (r.id) THEN true ELSE false END
	FROM "baseten".relation r
	WHERE r.id = $1 AND r.enabled = true;
$$ STABLE LANGUAGE SQL;
COMMENT ON FUNCTION "baseten".is_enabled (INTEGER) IS 'Checks for observing compatibility. Returns a boolean.';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".is_enabled (INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".is_enabled (INTEGER) TO basetenread;


CREATE FUNCTION "baseten".is_enabled (OID) RETURNS boolean AS $$
	SELECT "baseten".is_enabled ("baseten".relation_id ($1));
$$ STABLE LANGUAGE SQL;
COMMENT ON FUNCTION "baseten".is_enabled (OID) IS 'Checks for observing compatibility. Returns a boolean.';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".is_enabled (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".is_enabled (OID) TO basetenread;


CREATE FUNCTION "baseten".is_enabled_ex (INTEGER) RETURNS VOID AS $$
BEGIN
	IF NOT ("baseten".is_enabled ($1)) THEN
		RAISE EXCEPTION 'Relation with ID % has not been enabled', $1;
	END IF;
	RETURN;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".is_enabled_ex (INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".is_enabled_ex (INTEGER) TO basetenread;


CREATE FUNCTION "baseten".is_enabled_ex (OID) RETURNS VOID AS $$
BEGIN
	IF NOT ("baseten".is_enabled ($1)) THEN
		RAISE EXCEPTION 'Relation with OID % has not been enabled', $1;
	END IF;
	RETURN;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".is_enabled_ex (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".is_enabled_ex (OID) TO basetenread;


-- A convenience function for observing modifications
-- Subscribes the caller to receive the approppriate notification
CREATE FUNCTION "baseten".mod_observe (OID) RETURNS "baseten".observation_type AS $$
DECLARE
	reloid ALIAS FOR $1;
	relid INTEGER;
	nname TEXT;
	retval "baseten".observation_type;
BEGIN
	PERFORM "baseten".is_enabled_ex (reloid);
	SELECT "baseten".relation_id_ex (reloid) INTO STRICT relid;
	nname := "baseten"._mod_notification (reloid);
	--RAISE NOTICE 'Observing: %', nname;
	EXECUTE 'LISTEN ' || quote_ident (nname);

	retval := (reloid, relid, nname, null::TEXT, null::TEXT);
	RETURN retval;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".mod_observe (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".mod_observe (OID) TO basetenread;


CREATE FUNCTION "baseten".mod_observe_stop (OID) RETURNS VOID AS $$
DECLARE 
	relid ALIAS FOR $1;
BEGIN
	EXECUTE 'UNLISTEN ' || quote_ident ("baseten"._mod_notification (relid));
	RETURN;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".mod_observe_stop (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".mod_observe_stop (OID) TO basetenread;


-- A convenience function for observing locks
-- Subscribes the caller to receive the approppriate notification
CREATE FUNCTION "baseten".lock_observe (OID) RETURNS "baseten".observation_type AS $$
DECLARE
	reloid ALIAS FOR $1;
	relid INTEGER;
	nname TEXT;
	retval "baseten".observation_type;
BEGIN
	PERFORM "baseten".is_enabled_ex (reloid);
	SELECT "baseten".relation_id_ex (reloid) INTO STRICT relid;
	nname := "baseten"._lock_notification (relid);
	--RAISE NOTICE 'Observing: %', nname;
	EXECUTE 'LISTEN ' || quote_ident (nname);

	retval := (reloid, relid, nname, "baseten"._lock_fn (relid), "baseten"._lock_table (relid));
	RETURN retval;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_observe (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_observe (OID) TO basetenuser;


CREATE FUNCTION "baseten".lock_observe_stop (OID) RETURNS VOID AS $$
DECLARE 
	relid ALIAS FOR $1;
BEGIN
	EXECUTE 'UNLISTEN ' || quote_ident ("baseten"._lock_notification (relid));
	RETURN;
END;
$$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".lock_observe_stop (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".lock_observe_stop (OID) TO basetenuser;


-- Remove the modification tracking table, rules and the trigger
CREATE FUNCTION "baseten".disable (OID) RETURNS "baseten".reltype AS $$
DECLARE
	retval "baseten"."reltype";
BEGIN	 
	EXECUTE 'DROP FUNCTION IF EXISTS "baseten".' || "baseten"._mod_insert_fn ($1) || ' () CASCADE';
	EXECUTE 'DROP TABLE IF EXISTS "baseten".' || "baseten"._lock_table ($1) || ' CASCADE';
	EXECUTE 'DROP TABLE IF EXISTS "baseten".' || "baseten"._mod_table ($1) || ' CASCADE';
	UPDATE "baseten".relation r SET enabled = false WHERE r.id = "baseten".relation_id_ex ($1);
	retval := "baseten".reltype ($1);
	RETURN retval;
END;
$$ VOLATILE LANGUAGE PLPGSQL SECURITY DEFINER;
COMMENT ON FUNCTION "baseten".disable (OID) IS 'Removes BaseTen tables for a specific relation';
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".disable (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".disable (OID) TO basetenowner;


-- A helper function
CREATE FUNCTION "baseten".enable_table_insert (OID, TEXT []) 
RETURNS VOID AS $marker$
DECLARE
	relid	ALIAS FOR $1;
	pkey	TEXT [] DEFAULT $2;
	rel		"baseten".reltype;
	query	TEXT;
	mtable	TEXT;
	fname	TEXT;
	fdecl	TEXT;
BEGIN
	SELECT "baseten"._mod_table (relid) INTO STRICT mtable;
	SELECT "baseten"._mod_insert_fn (relid) INTO STRICT fname;
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
		'$$ VOLATILE LANGUAGE PLPGSQL SECURITY DEFINER';
	query := 
		'CREATE TRIGGER ' || quote_ident ("baseten"._mod_rule ('INSERT')) || ' ' ||
			'AFTER INSERT ON ' || quote_ident (rel.nspname) || '.' || quote_ident (rel.relname) || ' ' || 
			'FOR EACH ROW EXECUTE PROCEDURE "baseten".' || quote_ident (fname) || ' ()'; 
	EXECUTE fdecl;
	EXECUTE query;
	EXECUTE 'REVOKE ALL PRIVILEGES ON FUNCTION "baseten".' || quote_ident (fname) || ' () FROM PUBLIC';
	RETURN;
END;
$marker$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".enable_table_insert (OID, TEXT []) FROM PUBLIC;


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
		'INSERT INTO "baseten".' || quote_ident ("baseten"._mod_table (relid)) || ' ' ||
			'("baseten_modification_type", id) ' || 
			'VALUES ' || 
			'(''I'', ' || default_value || ')';
	query := 
		'CREATE RULE ' || quote_ident ("baseten"._mod_rule ('INSERT')) || ' ' ||
			'AS ON INSERT TO ' || quote_ident (rel.nspname) || '.' || quote_ident (rel.relname) || ' ' ||
			'DO ALSO (' || insertion || ');';
	EXECUTE query;
	RETURN;
END;
$marker$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".enable_view_insert (OID, TEXT) FROM PUBLIC;


-- Another helper function
CREATE FUNCTION "baseten".enable_other (TEXT, OID, TEXT []) 
RETURNS VOID AS $marker$
DECLARE
	querytype		TEXT DEFAULT $1;
	relid			ALIAS FOR $2;
	pkey			TEXT [] DEFAULT $3;
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
		'CREATE RULE ' || quote_ident ("baseten"._mod_rule ($1)) || ' AS ON ' || querytype ||
		' TO ' || quote_ident (rel.nspname) || '.' || quote_ident (rel.relname) ||
		whereclause || ' DO ALSO (' || insertion || ')';
	EXECUTE query;
	RETURN;
END;
$marker$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".enable_other (TEXT, OID, TEXT []) FROM PUBLIC;


-- Another helper function
CREATE FUNCTION "baseten".enable_insert_query (OID, CHAR, TEXT, TEXT [])
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
		'INSERT INTO "baseten".' || quote_ident ("baseten"._mod_table (relid)) || ' ' ||
			'("baseten_modification_type", ' || pkey || ') ' ||
			'VALUES ' || 
			'(''' || operation || ''',' || pkey_values || ')';
END;
$$ STABLE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".enable_insert_query (OID, CHAR, TEXT, TEXT []) FROM PUBLIC;


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
	pkey							TEXT [];
	pkey_types						TEXT [];
BEGIN
	SELECT "baseten"._lock_table (relid) INTO STRICT lock_table;
	SELECT "baseten"._lock_fn (relid) INTO STRICT lock_fn;
	SELECT "baseten"._lock_notification (relid) INTO STRICT lock_notification;
	SELECT
		"baseten".array_accum (quote_ident (p.attname)),
		"baseten".array_accum (quote_ident (p.typnspname) || '.' || quote_ident (p.typname))
		FROM "baseten"._primary_key p
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
	reloid							ALIAS FOR $1;
	handle_view_serial_id_column	ALIAS FOR $2;
	view_id_default_value			ALIAS FOR $3;
	is_view							BOOL;
	query							TEXT;
	
	relid_							INTEGER;
	mod_table						TEXT;
	lock_table						TEXT;
	
	pkey							TEXT [];
	pkey_decl						TEXT;
	rel								"baseten"."reltype";
	retval							"baseten"."reltype";
BEGIN
	PERFORM "baseten".assign_internal_ids ();
	UPDATE "baseten".relation SET enabled = true WHERE id = "baseten".relation_id_ex (reloid);
	SELECT "baseten"._mod_table (reloid) INTO STRICT mod_table;
	SELECT "baseten"._lock_table (reloid) INTO STRICT lock_table;
	SELECT 'v' = c.relkind FROM pg_class c WHERE c.oid = reloid INTO STRICT is_view;
	relid_ := "baseten".relation_id_ex (reloid);
	rel := "baseten".reltype (reloid);
	
	SELECT
		"baseten".array_accum (quote_ident (p.attname)),
		array_to_string ("baseten".array_accum (quote_ident (p.attname) || ' ' || quote_ident (p.typnspname) || '.' || quote_ident (p.typname) || ' NOT NULL'), ', ')
		FROM "baseten"._primary_key p
		WHERE p.oid = reloid
		GROUP BY p.oid
		INTO STRICT pkey, pkey_decl;

	-- Locking
	query := 
		'CREATE TABLE "baseten".' || quote_ident (lock_table) || ' (' ||
			'"baseten_lock_relid" INTEGER NOT NULL DEFAULT ' || relid_ || ', ' ||
			pkey_decl ||
		') INHERITS ("baseten".lock)';
	EXECUTE query;
	EXECUTE 'REVOKE ALL PRIVILEGES ON "baseten".' || quote_ident (lock_table) || ' FROM PUBLIC';
	EXECUTE 'GRANT SELECT ON "baseten".' || quote_ident (lock_table) || ' TO basetenread';
	EXECUTE 'GRANT INSERT ON "baseten".' || quote_ident (lock_table) || ' TO basetenuser';
	EXECUTE 'COMMENT ON TABLE "baseten".' || quote_ident (lock_table) || ' IS ''' || rel.nspname || '.' || rel.relname || '''';

	-- Trigger for the _lock_ table
	query :=
		'CREATE TRIGGER "lock_row" ' ||
		'AFTER INSERT ON "baseten".' || quote_ident (lock_table) || ' ' ||
		'FOR EACH STATEMENT EXECUTE PROCEDURE "baseten".lock_notify (''' || "baseten"._lock_notification (reloid) || ''')';
	EXECUTE query;

	-- Locking function
	PERFORM "baseten".enable_lock_fn (reloid);

	-- Modifications
	query :=
		'CREATE TABLE "baseten".' || quote_ident (mod_table) || ' (' ||
			'"baseten_modification_relid" INTEGER NOT NULL DEFAULT ' || relid_ || ', ' ||
			pkey_decl ||
		') INHERITS ("baseten".modification)';
	EXECUTE query;
	EXECUTE 'REVOKE ALL PRIVILEGES ON "baseten".' || quote_ident (mod_table) || ' FROM PUBLIC';
	EXECUTE 'GRANT INSERT ON "baseten".' || quote_ident (mod_table) || ' TO basetenuser';
	EXECUTE 'GRANT SELECT ON "baseten".' || quote_ident (mod_table) || ' TO basetenread';
	EXECUTE 'COMMENT ON TABLE "baseten".' || quote_ident (mod_table) || ' IS ''' || rel.nspname || '.' || rel.relname || '''';
	
	-- Triggers for the _modification_ table
	query :=
		'CREATE TRIGGER "modify_table" ' ||
		'AFTER INSERT ON "baseten".' || quote_ident (mod_table) || ' ' ||
		'FOR EACH STATEMENT EXECUTE PROCEDURE "baseten".mod_notify (''' || "baseten"._mod_notification (reloid) || ''')';
	EXECUTE query;
	
	-- Triggers for the enabled relation.
	IF is_view THEN
		IF handle_view_serial_id_column THEN
			PERFORM "baseten".enable_view_insert (reloid, view_id_default_value);
		ELSE
			PERFORM "baseten".enable_other ('insert', reloid, pkey);
		END IF;
	ELSE
		PERFORM "baseten".enable_table_insert (reloid, pkey) ;
	END IF;
	PERFORM "baseten".enable_other ('delete', reloid, pkey);
	PERFORM "baseten".enable_other ('update', reloid, pkey);
	PERFORM "baseten".enable_other ('update_pk', reloid, pkey);

	retval := "baseten".reltype (reloid);
	RETURN retval;
END;
$marker$ VOLATILE LANGUAGE PLPGSQL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".enable (OID, BOOLEAN, TEXT) FROM PUBLIC;	
GRANT EXECUTE ON FUNCTION "baseten".enable (OID, BOOLEAN, TEXT) TO basetenowner;


CREATE FUNCTION "baseten".enable (OID) RETURNS "baseten".reltype AS $$
	SELECT "baseten".enable ($1, false, null);
$$ VOLATILE LANGUAGE SQL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".enable (OID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".enable (OID) TO basetenowner;
COMMENT ON FUNCTION "baseten".enable (OID) IS 'BaseTen-enables a relation';


CREATE FUNCTION "baseten".modification (INTEGER, BOOL, TIMESTAMP, INTEGER)
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
	SELECT "baseten"._mod_table (relid) INTO STRICT mtable;
	SELECT 
		array_to_string ("baseten".array_accum (quote_ident (p.attname)), ', '),
		array_to_string ("baseten".array_append_each (' ASC', "baseten".array_accum (quote_ident (p.attname))), ', ')
		FROM "baseten"._primary_key p
		WHERE p.id = relid
		GROUP BY p.id
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
	--RAISE NOTICE 'Modifications: %', query;
	
	FOR retval IN EXECUTE query
	LOOP
		RETURN NEXT retval;
	END LOOP;
	RETURN;
END;		 
$marker$ VOLATILE LANGUAGE PLPGSQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".modification (INTEGER, BOOL, TIMESTAMP, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".modification (INTEGER, BOOL, TIMESTAMP, INTEGER) TO basetenread;


CREATE FUNCTION "baseten".prune () RETURNS VOID AS $$
	DELETE FROM "baseten".modification;
	DELETE FROM "baseten".lock;
	TRUNCATE 
		"baseten"._view_dependency, 
		"baseten"._rel_view_hierarchy, 
		"baseten"._rel_view_oneto, 
		"baseten"._rel_view_manytomany,
		"baseten"._deprecated_relationship_name;
$$ VOLATILE LANGUAGE SQL SECURITY DEFINER;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".prune () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".prune () TO basetenowner;


CREATE FUNCTION "baseten".refresh_caches () RETURNS VOID AS $$
	TRUNCATE "baseten".relationship, "baseten"._deprecated_relationship_name;
	SELECT "baseten"._insert_relationships ();
	
	-- Deprecated names.
	SELECT "baseten"._insert_deprecated_relationships ();
	INSERT INTO "baseten".relationship
		SELECT
			conid,
		    dstconid,
		    name,
		    inversename,
		    kind,
		    is_inverse,
		    is_deprecated,
		    has_rel_names,
		    has_views,
		    srcid,
		    srcnspname,
		    srcrelname,
		    dstid,
		    dstnspname,
		    dstrelname,
		    helperid,
		    helpernspname,
		    helperrelname
		FROM "baseten"._deprecated_relationship_name
		WHERE is_ambiguous = false;
	
	SELECT "baseten"._remove_ambiguous_relationships ();
$$ VOLATILE LANGUAGE SQL;
REVOKE ALL PRIVILEGES ON FUNCTION "baseten".refresh_caches () FROM PUBLIC;
GRANT EXECUTE ON FUNCTION "baseten".refresh_caches () TO basetenowner;


GRANT basetenread TO basetenuser;
GRANT basetenuser TO basetenowner;
COMMIT; -- Functions
