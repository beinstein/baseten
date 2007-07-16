BEGIN;


DROP TYPE IF EXISTS "baseten".viewtype CASCADE;
CREATE TYPE "baseten".viewtype AS (
	oid OID,
	root OID,
	generation SMALLINT
);
-- No privileges on types


CREATE OR REPLACE FUNCTION "baseten".viewhierarchy (OID) RETURNS SETOF "baseten".viewtype AS $$
DECLARE
	tableoid ALIAS FOR $1;
	view "baseten".viewtype;
BEGIN
	-- Fetch dependant views.
	FOR view IN SELECT * FROM "baseten".viewhierarchy (tableoid, tableoid, 1) LOOP
		RETURN NEXT view;
	END LOOP;
	RETURN;
END;
$$ STABLE LANGUAGE PLPGSQL EXTERNAL SECURITY DEFINER;


CREATE OR REPLACE FUNCTION "baseten".viewhierarchy (OID, OID, INTEGER) 
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
	retval.generation = generation::SMALLINT;

	-- Fetch dependant views
	-- FIXME: this could be optimized by a factor of ~1000 (sic) by first selecting the contents
	-- of baseten.viewdependencies into a (temporary) table and then selecting from it.
	FOR currentoid IN SELECT viewoid FROM "baseten".viewdependencies WHERE reloid = parent LOOP
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
$$ STABLE LANGUAGE PLPGSQL EXTERNAL SECURITY DEFINER;


CREATE VIEW "baseten".viewhiearchy AS
SELECT
	
	

COMMIT;