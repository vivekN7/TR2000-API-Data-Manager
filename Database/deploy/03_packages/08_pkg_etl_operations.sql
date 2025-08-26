-- ===============================================================================
-- Package: PKG_ETL_OPERATIONS
-- Purpose: Orchestrates the complete ETL pipeline
-- ===============================================================================

-- Package Specification
CREATE OR REPLACE PACKAGE pkg_etl_operations AS
    PROCEDURE run_plants_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2);
    PROCEDURE run_issues_etl_for_plant(p_plant_id VARCHAR2, p_status OUT VARCHAR2, p_message OUT VARCHAR2);
    PROCEDURE run_full_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2);
END pkg_etl_operations;
/

-- Package Body
CREATE OR REPLACE PACKAGE BODY pkg_etl_operations AS

    PROCEDURE run_plants_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2) IS
        v_run_id NUMBER;
        v_start_time TIMESTAMP;
    BEGIN
        -- Log ETL start
        v_start_time := SYSTIMESTAMP;
        INSERT INTO ETL_RUN_LOG (run_type, endpoint_key, start_time, status, initiated_by)
        VALUES ('PLANTS_ETL', 'plants', v_start_time, 'RUNNING', USER)
        RETURNING run_id INTO v_run_id;

        BEGIN
            -- Note: Raw JSON insert will be done from C# after API call
            -- Here we just process existing RAW_JSON records

            -- Get latest raw_json_id for plants
            FOR rec IN (
                SELECT raw_json_id
                FROM RAW_JSON
                WHERE endpoint_key = 'plants'
                ORDER BY api_call_timestamp DESC
                FETCH FIRST 1 ROWS ONLY
            ) LOOP
                -- Parse JSON to staging
                pkg_parse_plants.parse_plants_json(rec.raw_json_id);

                -- Upsert to core
                pkg_upsert_plants.upsert_plants;
            END LOOP;

            -- Update run log
            UPDATE ETL_RUN_LOG
            SET end_time = SYSTIMESTAMP,
                status = 'SUCCESS',
                duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
            WHERE run_id = v_run_id;

            p_status := 'SUCCESS';
            p_message := 'Plants ETL completed successfully';

        EXCEPTION
            WHEN OTHERS THEN
                DECLARE
                    v_error_code NUMBER := SQLCODE;
                    v_error_msg VARCHAR2(4000) := SQLERRM;
                    v_error_stack VARCHAR2(4000) := DBMS_UTILITY.FORMAT_ERROR_STACK();
                BEGIN
                    -- Log error
                    INSERT INTO ETL_ERROR_LOG (
                        run_id, endpoint_key, error_timestamp, error_type,
                        error_code, error_message, error_stack
                    ) VALUES (
                        v_run_id, 'plants', SYSTIMESTAMP, 'PROCEDURE_ERROR',
                        v_error_code, v_error_msg, v_error_stack
                    );

                    -- Update run log
                    UPDATE ETL_RUN_LOG
                    SET end_time = SYSTIMESTAMP,
                        status = 'FAILED',
                        duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                    WHERE run_id = v_run_id;

                    p_status := 'FAILED';
                    p_message := v_error_msg;
                    RAISE;
                END;
        END;
    END run_plants_etl;

    PROCEDURE run_issues_etl_for_plant(p_plant_id VARCHAR2, p_status OUT VARCHAR2, p_message OUT VARCHAR2) IS
        v_run_id NUMBER;
        v_start_time TIMESTAMP;
    BEGIN
        -- Log ETL start
        v_start_time := SYSTIMESTAMP;
        INSERT INTO ETL_RUN_LOG (run_type, endpoint_key, plant_id, start_time, status, initiated_by)
        VALUES ('ISSUES_ETL', 'issues', p_plant_id, v_start_time, 'RUNNING', USER)
        RETURNING run_id INTO v_run_id;

        BEGIN
            -- Get latest raw_json_id for this plant's issues
            FOR rec IN (
                SELECT raw_json_id
                FROM RAW_JSON
                WHERE endpoint_key = 'issues'
                AND plant_id = p_plant_id
                ORDER BY api_call_timestamp DESC
                FETCH FIRST 1 ROWS ONLY
            ) LOOP
                -- Parse JSON to staging
                pkg_parse_issues.parse_issues_json(rec.raw_json_id, p_plant_id);

                -- Upsert to core
                pkg_upsert_issues.upsert_issues;
            END LOOP;

            -- Update run log
            UPDATE ETL_RUN_LOG
            SET end_time = SYSTIMESTAMP,
                status = 'SUCCESS',
                duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
            WHERE run_id = v_run_id;

            p_status := 'SUCCESS';
            p_message := 'Issues ETL for plant ' || p_plant_id || ' completed successfully';

        EXCEPTION
            WHEN OTHERS THEN
                DECLARE
                    v_error_code NUMBER := SQLCODE;
                    v_error_msg VARCHAR2(4000) := SQLERRM;
                    v_error_stack VARCHAR2(4000) := DBMS_UTILITY.FORMAT_ERROR_STACK();
                BEGIN
                    -- Log error
                    INSERT INTO ETL_ERROR_LOG (
                        run_id, endpoint_key, plant_id, error_timestamp, error_type,
                        error_code, error_message, error_stack
                    ) VALUES (
                        v_run_id, 'issues', p_plant_id, SYSTIMESTAMP, 'PROCEDURE_ERROR',
                        v_error_code, v_error_msg, v_error_stack
                    );

                    -- Update run log
                    UPDATE ETL_RUN_LOG
                    SET end_time = SYSTIMESTAMP,
                        status = 'FAILED',
                        duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                    WHERE run_id = v_run_id;

                    p_status := 'FAILED';
                    p_message := v_error_msg;
                    RAISE;
                END;
        END;
    END run_issues_etl_for_plant;

    PROCEDURE run_full_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2) IS
        v_plant_status VARCHAR2(50);
        v_plant_message VARCHAR2(4000);
        v_issue_status VARCHAR2(50);
        v_issue_message VARCHAR2(4000);
        v_error_count NUMBER := 0;
    BEGIN
        -- Run Plants ETL
        run_plants_etl(v_plant_status, v_plant_message);

        IF v_plant_status != 'SUCCESS' THEN
            v_error_count := v_error_count + 1;
        END IF;

        -- Run Issues ETL for each active plant in selection
        FOR plant_rec IN (
            SELECT DISTINCT plant_id
            FROM SELECTION_LOADER
            WHERE is_active = 'Y'
        ) LOOP
            run_issues_etl_for_plant(plant_rec.plant_id, v_issue_status, v_issue_message);

            IF v_issue_status != 'SUCCESS' THEN
                v_error_count := v_error_count + 1;
            END IF;
        END LOOP;

        IF v_error_count = 0 THEN
            p_status := 'SUCCESS';
            p_message := 'Full ETL completed successfully';
        ELSE
            p_status := 'PARTIAL';
            p_message := 'ETL completed with ' || v_error_count || ' errors';
        END IF;
    END run_full_etl;

END pkg_etl_operations;
/