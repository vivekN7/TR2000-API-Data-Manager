SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE 
    v_resp VARCHAR2(32767);
BEGIN 
    v_resp := SYS.fetch_https_url('https://equinor.pipespec-api.presight.com/plants');
    DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(v_resp));
    IF LENGTH(v_resp) > 0 THEN
        DBMS_OUTPUT.PUT_LINE('First 500 chars: ' || SUBSTR(v_resp, 1, 500));
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('SUCCESS! Java HTTPS bypass works!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Empty response or error');
    END IF;
END;
/