//
// PGTSMetadataTests.h
// BaseTen
//
// Copyright (C) 2010 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
// us at sales@karppinen.fi. Without an additional license, this software
// may be distributed only in compliance with the GNU General Public License.
//
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License, version 2.0,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

#import "PGTSPgBouncerTests.h"
#import "PGTSTypeTests.h"
#import "MKCSenTestCaseAdditions.h"
#import "libpq-fe.h"


@implementation PGTSPgBouncerTests


- (void) test1
{
	PGresult* res;
	char str[64];
	char sessionid[64];
	char txid[64];
	
	PGconn* conn1 = PQconnectdb("port=6432");
	PGconn* conn2 = PQconnectdb("port=6432");
	
	MKCAssertTrue(PQstatus(conn1) == CONNECTION_OK);
	MKCAssertTrue(PQstatus(conn2) == CONNECTION_OK);
	
	/* Don't allow commands when there is no open session. */
	res = PQexec(conn1, "SELECT 1");
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_FATAL_ERROR);
	MKCAssertTrue(strcmp(PQresultErrorField(res, PG_DIAG_SQLSTATE), "PO051") == 0);
	PQclear(res);
	
	/* Start a new session. */
	res = PQexec(conn1, "START SESSION");
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_TUPLES_OK);
	
	strncpy(sessionid, PQgetvalue(res, 0, 0), sizeof(sessionid));
	PQclear(res);
	
	size_t length = strlen(sessionid);
	STAssertTrue(32 == length,
				 @"Expected sessionID's length to be 32 bytes; got %u (%s) instead.",
				 length, sessionid);
	
	/* Begin a transansaction and memorize its txid. */
	res = PQexec(conn1, "BEGIN");
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_COMMAND_OK);
	PQclear(res);
	res = PQexec(conn1, "SELECT txid_current()");
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_TUPLES_OK);
	
	strncpy(txid, PQgetvalue(res, 0, 0), sizeof(txid));
	PQclear(res);
	
	/*
	 * Now restore the session in conn2.  This should invalidate the
	 * session in conn1.
	 */
	sprintf(str, "RESTORE SESSION %s", sessionid);
	
	res = PQexec(conn2, str);
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_COMMAND_OK);
	PQclear(res);
	
	/* Check that the transaction status is reported correctly. */
	MKCAssertTrue(PQtransactionStatus(conn2) == PQTRANS_INTRANS);
	
	/*
	 * Check that this is indeed the same transaction left open by the
	 * previous connection.
	 */
	res = PQexec(conn2, "SELECT txid_current()");
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_TUPLES_OK);
	MKCAssertTrue(strcmp(txid, PQgetvalue(res, 0, 0)) == 0);
	PQclear(res);
	
	/* Now try issuing a query on the old connection.  This should fail. */
	res = PQexec(conn1, "SELECT 1");
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_FATAL_ERROR);
	MKCAssertTrue(strcmp(PQresultErrorField(res, PG_DIAG_SQLSTATE), "PO053") == 0);
	PQclear(res);
	PQfinish(conn1);
	
	/* End this session. */
	res = PQexec(conn2, "END SESSION");
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_COMMAND_OK);
	PQclear(res);

	PQfinish(conn2);
}

/*
 * Make sure our changes to runtime parameters are reported back from
 * pgbouncer when a session is restored.  The way we do this currently
 * is a bit ugly: we check the default client_encoding for LATIN1 and
 * use either that or LATIN2, depending on the default encoding.  This
 * could be done much more cleanly with the application_name parameter
 * but that's currently only in PostgreSQL 9.0.
 */
- (void) testRuntimeParams
{
	PGresult* res;
	PGconn* conn;
	char sessionid[64];
	char str[64];
	const char* encoding;
	
	conn = PQconnectdb("port=6432");
	MKCAssertTrue(PQstatus(conn) == CONNECTION_OK);
	
	res = PQexec(conn, "START SESSION");
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_TUPLES_OK);
	
	strncpy(sessionid, PQgetvalue(res, 0, 0), sizeof(sessionid));
	PQclear(res);
	
	res = PQexec(conn, "BEGIN");
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_COMMAND_OK);
	PQclear(res);
	
	res = PQexec(conn, "SHOW client_encoding");
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_TUPLES_OK);
	
	if (strcmp(PQgetvalue(res, 0, 0), "LATIN1") == 0)
		encoding = "LATIN2";
	else
		encoding = "LATIN1";
	PQclear(res);
	
	sprintf(str, "SET LOCAL client_encoding TO '%s'", encoding);
	
	res = PQexec(conn, str);
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_COMMAND_OK);
	PQclear(res);
	
	MKCAssertTrue(strcmp(PQparameterStatus(conn, "client_encoding"), encoding) == 0);
	PQfinish(conn);
	
	/* Now reconnect and check PQparameterStatus. */
	
	conn = PQconnectdb("port=6432");
	MKCAssertTrue(PQstatus(conn) == CONNECTION_OK);

	sprintf(str, "RESTORE SESSION %s", sessionid);
	
	res = PQexec(conn, str);
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_COMMAND_OK);
	PQclear(res);
	
	/* PgBouncer should report the params to us after RESTORE SESSION. */
	MKCAssertTrue(strcmp(PQparameterStatus(conn, "client_encoding"), encoding) == 0);
	
	/* End this session. */
	res = PQexec(conn, "END SESSION");
	MKCAssertTrue(res && PQresultStatus(res) == PGRES_COMMAND_OK);
	PQclear(res);
	
	PQfinish(conn);
}

@end
