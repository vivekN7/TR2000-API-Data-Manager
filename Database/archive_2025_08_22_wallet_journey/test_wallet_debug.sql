-- Debug wallet issues
SET SERVEROUTPUT ON SIZE UNLIMITED

BEGIN
    DBMS_OUTPUT.PUT_LINE('Wallet debugging...');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test different wallet path formats
    DECLARE
        TYPE t_paths IS TABLE OF VARCHAR2(500);
        v_paths t_paths := t_paths(
            'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet',
            'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet/',
            '/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet',
            'file:///workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet'
        );
        v_req UTL_HTTP.REQ;
        v_resp UTL_HTTP.RESP;
    BEGIN
        FOR i IN 1..v_paths.COUNT LOOP
            BEGIN
                DBMS_OUTPUT.PUT_LINE('Testing path: ' || v_paths(i));
                
                UTL_HTTP.SET_WALLET(v_paths(i), 'WalletPass123');
                
                v_req := UTL_HTTP.BEGIN_REQUEST('https://httpbin.org/get', 'GET');
                v_resp := UTL_HTTP.GET_RESPONSE(v_req);
                
                DBMS_OUTPUT.PUT_LINE('  ✅ SUCCESS with path format: ' || v_paths(i));
                DBMS_OUTPUT.PUT_LINE('  Status: ' || v_resp.status_code);
                
                UTL_HTTP.END_RESPONSE(v_resp);
                EXIT; -- Found working format
                
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('  ❌ Failed: ' || SUBSTR(SQLERRM, 1, 60));
                    IF v_resp.status_code IS NOT NULL THEN
                        UTL_HTTP.END_RESPONSE(v_resp);
                    END IF;
            END;
        END LOOP;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Check if this is a certificate issue
    DBMS_OUTPUT.PUT_LINE('Testing with a well-known site (Google)...');
    DECLARE
        v_req UTL_HTTP.REQ;
        v_resp UTL_HTTP.RESP;
    BEGIN
        UTL_HTTP.SET_WALLET('file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet', 'WalletPass123');
        
        v_req := UTL_HTTP.BEGIN_REQUEST('https://www.google.com', 'GET');
        v_resp := UTL_HTTP.GET_RESPONSE(v_req);
        
        DBMS_OUTPUT.PUT_LINE('✅ Google works! Status: ' || v_resp.status_code);
        UTL_HTTP.END_RESPONSE(v_resp);
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Google also fails: ' || SQLERRM);
            IF v_resp.status_code IS NOT NULL THEN
                UTL_HTTP.END_RESPONSE(v_resp);
            END IF;
    END;
END;
/