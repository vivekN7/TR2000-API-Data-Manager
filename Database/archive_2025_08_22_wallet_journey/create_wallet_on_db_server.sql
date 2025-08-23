-- Create wallet on database server using DBMS_SCHEDULER
SET SERVEROUTPUT ON SIZE UNLIMITED

-- Switch to PDB
ALTER SESSION SET CONTAINER = XEPDB1;

PROMPT ========================================
PROMPT Creating Wallet on Database Server
PROMPT ========================================

-- Create a job to run OS commands on database server
BEGIN
    -- First, check Oracle home
    DBMS_OUTPUT.PUT_LINE('Checking Oracle installation...');
    
    -- Create directory for wallet
    DBMS_SCHEDULER.CREATE_JOB (
        job_name => 'CREATE_WALLET_DIR',
        job_type => 'EXECUTABLE',
        job_action => '/bin/mkdir',
        number_of_arguments => 2,
        auto_drop => TRUE,
        enabled => FALSE
    );
    
    DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('CREATE_WALLET_DIR', 1, '-p');
    DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('CREATE_WALLET_DIR', 2, '/opt/oracle/admin/wallet');
    
    DBMS_SCHEDULER.ENABLE('CREATE_WALLET_DIR');
    
    -- Wait for job to complete
    DBMS_LOCK.SLEEP(2);
    
    DBMS_OUTPUT.PUT_LINE('Directory created');
    
    -- Now create wallet using orapki (if it exists on server)
    DBMS_SCHEDULER.CREATE_JOB (
        job_name => 'CREATE_ORACLE_WALLET',
        job_type => 'EXECUTABLE', 
        job_action => '/opt/oracle/product/21c/dbhomeXE/bin/orapki',
        number_of_arguments => 6,
        auto_drop => TRUE,
        enabled => FALSE
    );
    
    DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('CREATE_ORACLE_WALLET', 1, 'wallet');
    DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('CREATE_ORACLE_WALLET', 2, 'create');
    DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('CREATE_ORACLE_WALLET', 3, '-wallet');
    DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('CREATE_ORACLE_WALLET', 4, '/opt/oracle/admin/wallet');
    DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('CREATE_ORACLE_WALLET', 5, '-auto_login');
    DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('CREATE_ORACLE_WALLET', 6, '-pwd');
    DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE('CREATE_ORACLE_WALLET', 7, 'WalletPass123');
    
    DBMS_SCHEDULER.ENABLE('CREATE_ORACLE_WALLET');
    
    DBMS_LOCK.SLEEP(3);
    
    DBMS_OUTPUT.PUT_LINE('Wallet creation attempted');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        -- Clean up jobs if they exist
        BEGIN
            DBMS_SCHEDULER.DROP_JOB('CREATE_WALLET_DIR', TRUE);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        BEGIN
            DBMS_SCHEDULER.DROP_JOB('CREATE_ORACLE_WALLET', TRUE);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
END;
/

-- Check job results
SELECT job_name, state, error#, additional_info
FROM user_scheduler_job_run_details
WHERE job_name IN ('CREATE_WALLET_DIR', 'CREATE_ORACLE_WALLET')
ORDER BY log_date DESC;

PROMPT ========================================