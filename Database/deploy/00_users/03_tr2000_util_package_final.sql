-- ===============================================================================
-- TR2000_UTIL Package - Final Version with Simple Hashing
-- Date: 2025-08-27
-- Purpose: DBA's centralized API utility package with basic Oracle functions
-- ===============================================================================

-- Run as SYSTEM user

-- Package Specification
CREATE OR REPLACE PACKAGE tr2000_util AUTHID DEFINER AS
  FUNCTION hash_json(p_json IN CLOB) RETURN VARCHAR2;
  PROCEDURE log_event(
    p_endpoint      IN VARCHAR2,
    p_query_params  IN VARCHAR2,
    p_status        IN NUMBER,
    p_rows          IN NUMBER,
    p_batch_id      IN VARCHAR2,
    p_error_msg     IN VARCHAR2   DEFAULT NULL,
    p_payload       IN CLOB       DEFAULT NULL
  );
  FUNCTION http_get(
    p_url_base   IN VARCHAR2,
    p_path       IN VARCHAR2,
    p_qs         IN VARCHAR2,
    p_batch_id   IN VARCHAR2,
    p_cred_id    IN VARCHAR2 DEFAULT 'TR2000_CRED'
  ) RETURN CLOB;
END tr2000_util;
/

-- Package Body
CREATE OR REPLACE PACKAGE BODY tr2000_util AS

  FUNCTION hash_json(p_json IN CLOB) RETURN VARCHAR2 IS
  BEGIN
    -- Use DBMS_UTILITY.GET_HASH_VALUE for simple hashing
    RETURN TO_CHAR(DBMS_UTILITY.GET_HASH_VALUE(
      SUBSTR(p_json, 1, 4000),  -- Hash first 4000 chars
      1,                         -- Base
      1073741824                 -- Hash table size (2^30)
    ));
  END hash_json;

  PROCEDURE log_event(
    p_endpoint      IN VARCHAR2,
    p_query_params  IN VARCHAR2,
    p_status        IN NUMBER,
    p_rows          IN NUMBER,
    p_batch_id      IN VARCHAR2,
    p_error_msg     IN VARCHAR2   DEFAULT NULL,
    p_payload       IN CLOB       DEFAULT NULL
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    -- Insert into TR2000_STAGING's ETL_LOG table
    INSERT INTO TR2000_STAGING.ETL_LOG (endpoint, query_params, http_status, rows_ingested, batch_id, error_msg)
    VALUES (
      p_endpoint,
      p_query_params,
      p_status,
      p_rows,
      p_batch_id,
      CASE WHEN p_error_msg IS NOT NULL
           THEN SUBSTR(p_error_msg, 1, 4000)
           END
    );

    IF p_payload IS NOT NULL THEN
      -- Insert into TR2000_STAGING's RAW_JSON table
      INSERT INTO TR2000_STAGING.RAW_JSON (endpoint, key_fingerprint, payload, batch_id)
      VALUES (
        p_endpoint,
        SUBSTR(TO_CHAR(DBMS_UTILITY.GET_HASH_VALUE(
          NVL(p_query_params,'-')||'|'||p_endpoint,
          1,
          1073741824
        )),1,64),
        p_payload,
        p_batch_id
      );
    END IF;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      -- Silent failure for logging (don't break main transaction)
      NULL;
  END log_event;

  FUNCTION http_get(
    p_url_base   IN VARCHAR2,
    p_path       IN VARCHAR2,
    p_qs         IN VARCHAR2,
    p_batch_id   IN VARCHAR2,
    p_cred_id    IN VARCHAR2
  ) RETURN CLOB
  IS
    l_url   VARCHAR2(4000);
    l_resp  CLOB;
    l_code  PLS_INTEGER;
  BEGIN
    l_url := p_url_base || p_path ||
             CASE WHEN p_qs IS NOT NULL AND p_qs <> '' THEN '?'||p_qs END;

    apex_web_service.g_request_headers.delete;
    apex_web_service.set_request_headers(
      p_name_01 => 'Accept',       p_value_01 => 'application/json',
      p_name_02 => 'Content-Type', p_value_02 => 'application/json'
    );

    -- Make the REST request using APEX credentials
    -- TR2000_CRED must be created in APEX workspace for production
    l_resp := apex_web_service.make_rest_request(
      p_url         => l_url,
      p_http_method => 'GET',
      p_credential_static_id => p_cred_id  -- Using APEX credential for secure authentication
    );

    l_code := apex_web_service.g_status_code;

    IF l_code BETWEEN 200 AND 299 THEN
      tr2000_util.log_event(p_path, p_qs, l_code, NULL, p_batch_id, NULL, l_resp);
      RETURN l_resp;
    ELSE
      tr2000_util.log_event(
        p_endpoint     => p_path,
        p_query_params => p_qs,
        p_status       => l_code,
        p_rows         => 0,
        p_batch_id     => p_batch_id,
        p_error_msg    => 'HTTP error '||l_code,
        p_payload      => l_resp
      );
      RAISE_APPLICATION_ERROR(-20001, 'HTTP_GET failed '||l_code||' for '||p_path);
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      tr2000_util.log_event(
        p_endpoint     => p_path,
        p_query_params => p_qs,
        p_status       => NVL(apex_web_service.g_status_code, -1),
        p_rows         => 0,
        p_batch_id     => p_batch_id,
        p_error_msg    => SUBSTR(SQLERRM||CHR(10)||DBMS_UTILITY.format_error_backtrace,1,4000),
        p_payload      => NULL
      );
      RAISE;
  END http_get;

END tr2000_util;
/

PROMPT ===============================================================================
PROMPT TR2000_UTIL Package Created
PROMPT ===============================================================================
PROMPT 
PROMPT Next steps:
PROMPT 1. Grant execute on tr2000_util to TR2000_STAGING
PROMPT 2. Create APEX credential 'TR2000_CRED' for API authentication (optional)
PROMPT 3. Grant network ACLs to SYSTEM user for API access
PROMPT ===============================================================================