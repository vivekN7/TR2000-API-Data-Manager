-- ===============================================================================
-- PKG_UPSERT_VDS - Upsert VDS Data from Staging to Core Tables
-- Session 18: VDS Details Implementation
-- Purpose: Move VDS data from staging to core tables with batch processing
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_upsert_vds AS
    
    -- Process VDS list from staging to core (44k records)
    PROCEDURE upsert_vds_list(
        p_batch_size    IN NUMBER DEFAULT 1000
    );
    
    -- Process VDS details from staging to core
    PROCEDURE upsert_vds_details(
        p_vds_name      IN VARCHAR2 DEFAULT NULL,
        p_revision      IN VARCHAR2 DEFAULT NULL
    );
    
    -- Mark invalid VDS not in latest load
    PROCEDURE invalidate_missing_vds;
    
    -- Get statistics
    FUNCTION get_vds_stats RETURN VARCHAR2;
    
END pkg_upsert_vds;
/

CREATE OR REPLACE PACKAGE BODY pkg_upsert_vds AS

    -- =========================================================================
    -- Process VDS list with batch processing for 44k+ records
    -- =========================================================================
    PROCEDURE upsert_vds_list(
        p_batch_size    IN NUMBER DEFAULT 1000
    ) IS
        v_processed     NUMBER := 0;
        v_total         NUMBER := 0;
        v_batch_count   NUMBER := 0;
        v_start_time    TIMESTAMP := SYSTIMESTAMP;
        
        CURSOR c_vds_batch IS
            SELECT 
                vds_name,
                revision,
                status,
                TO_DATE(rev_date, 'DD.MM.YYYY') as rev_date,
                TO_DATE(last_update, 'DD.MM.YYYY') as last_update,
                last_update_by,
                description,
                notepad,
                TO_NUMBER(special_req_id) as special_req_id,
                TO_NUMBER(valve_type_id) as valve_type_id,
                TO_NUMBER(rating_class_id) as rating_class_id,
                TO_NUMBER(material_group_id) as material_group_id,
                TO_NUMBER(end_connection_id) as end_connection_id,
                TO_NUMBER(bore_id) as bore_id,
                TO_NUMBER(vds_size_id) as vds_size_id,
                size_range,
                custom_name,
                subsegment_list,
                api_correlation_id
            FROM STG_VDS_LIST;
            
        TYPE t_vds_batch IS TABLE OF c_vds_batch%ROWTYPE;
        l_batch t_vds_batch;
        
    BEGIN
        -- Get total count
        SELECT COUNT(*) INTO v_total FROM STG_VDS_LIST;
        
        DBMS_OUTPUT.PUT_LINE('Starting VDS list upsert: ' || v_total || ' records to process');
        
        OPEN c_vds_batch;
        LOOP
            FETCH c_vds_batch BULK COLLECT INTO l_batch LIMIT p_batch_size;
            EXIT WHEN l_batch.COUNT = 0;
            
            v_batch_count := v_batch_count + 1;
            
            -- Process batch using MERGE
            FORALL i IN 1..l_batch.COUNT
                MERGE INTO VDS_LIST tgt
                USING (
                    SELECT 
                        l_batch(i).vds_name as vds_name,
                        l_batch(i).revision as revision,
                        l_batch(i).status as status,
                        l_batch(i).rev_date as rev_date,
                        l_batch(i).last_update as last_update,
                        l_batch(i).last_update_by as last_update_by,
                        l_batch(i).description as description,
                        l_batch(i).notepad as notepad,
                        l_batch(i).special_req_id as special_req_id,
                        l_batch(i).valve_type_id as valve_type_id,
                        l_batch(i).rating_class_id as rating_class_id,
                        l_batch(i).material_group_id as material_group_id,
                        l_batch(i).end_connection_id as end_connection_id,
                        l_batch(i).bore_id as bore_id,
                        l_batch(i).vds_size_id as vds_size_id,
                        l_batch(i).size_range as size_range,
                        l_batch(i).custom_name as custom_name,
                        l_batch(i).subsegment_list as subsegment_list,
                        l_batch(i).api_correlation_id as api_correlation_id
                    FROM DUAL
                ) src
                ON (tgt.vds_name = src.vds_name AND NVL(tgt.revision, 'NULL') = NVL(src.revision, 'NULL'))
                WHEN MATCHED THEN
                    UPDATE SET
                        tgt.status = src.status,
                        tgt.rev_date = src.rev_date,
                        tgt.last_update = src.last_update,
                        tgt.last_update_by = src.last_update_by,
                        tgt.description = src.description,
                        tgt.notepad = src.notepad,
                        tgt.special_req_id = src.special_req_id,
                        tgt.valve_type_id = src.valve_type_id,
                        tgt.rating_class_id = src.rating_class_id,
                        tgt.material_group_id = src.material_group_id,
                        tgt.end_connection_id = src.end_connection_id,
                        tgt.bore_id = src.bore_id,
                        tgt.vds_size_id = src.vds_size_id,
                        tgt.size_range = src.size_range,
                        tgt.custom_name = src.custom_name,
                        tgt.subsegment_list = src.subsegment_list,
                        tgt.is_valid = 'Y',
                        tgt.last_modified_date = SYSDATE,
                        tgt.last_api_sync = SYSTIMESTAMP,
                        tgt.api_correlation_id = src.api_correlation_id
                WHEN NOT MATCHED THEN
                    INSERT (
                        vds_guid,
                        vds_name,
                        revision,
                        status,
                        rev_date,
                        last_update,
                        last_update_by,
                        description,
                        notepad,
                        special_req_id,
                        valve_type_id,
                        rating_class_id,
                        material_group_id,
                        end_connection_id,
                        bore_id,
                        vds_size_id,
                        size_range,
                        custom_name,
                        subsegment_list,
                        is_valid,
                        created_date,
                        last_modified_date,
                        last_api_sync,
                        api_correlation_id
                    ) VALUES (
                        SYS_GUID(),
                        src.vds_name,
                        src.revision,
                        src.status,
                        src.rev_date,
                        src.last_update,
                        src.last_update_by,
                        src.description,
                        src.notepad,
                        src.special_req_id,
                        src.valve_type_id,
                        src.rating_class_id,
                        src.material_group_id,
                        src.end_connection_id,
                        src.bore_id,
                        src.vds_size_id,
                        src.size_range,
                        src.custom_name,
                        src.subsegment_list,
                        'Y',
                        SYSDATE,
                        SYSDATE,
                        SYSTIMESTAMP,
                        src.api_correlation_id
                    );
            
            v_processed := v_processed + l_batch.COUNT;
            
            -- Commit every batch to avoid large rollback segments
            COMMIT;
            
            -- Log progress every 10 batches
            IF MOD(v_batch_count, 10) = 0 THEN
                DBMS_OUTPUT.PUT_LINE('Processed ' || v_processed || '/' || v_total || 
                    ' records (' || ROUND(v_processed * 100 / v_total) || '%)');
            END IF;
        END LOOP;
        CLOSE c_vds_batch;
        
        -- Final statistics
        DBMS_OUTPUT.PUT_LINE('VDS list upsert complete: ' || v_processed || ' records in ' ||
            ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)), 2) || ' seconds');
        
    EXCEPTION
        WHEN OTHERS THEN
            IF c_vds_batch%ISOPEN THEN
                CLOSE c_vds_batch;
            END IF;
            DBMS_OUTPUT.PUT_LINE('Error in upsert_vds_list: ' || SQLERRM);
            RAISE;
    END upsert_vds_list;

    -- =========================================================================
    -- Process VDS details from staging to core
    -- =========================================================================
    PROCEDURE upsert_vds_details(
        p_vds_name      IN VARCHAR2 DEFAULT NULL,
        p_revision      IN VARCHAR2 DEFAULT NULL
    ) IS
        v_vds_guid      RAW(16);
        v_count         NUMBER := 0;
    BEGIN
        -- If specific VDS provided, get its GUID
        IF p_vds_name IS NOT NULL THEN
            BEGIN
                SELECT vds_guid INTO v_vds_guid
                FROM VDS_LIST
                WHERE vds_name = p_vds_name
                  AND NVL(revision, 'NULL') = NVL(p_revision, 'NULL')
                  AND is_valid = 'Y';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    DBMS_OUTPUT.PUT_LINE('VDS not found in VDS_LIST: ' || p_vds_name || '/' || p_revision);
                    RETURN;
            END;
        END IF;
        
        -- Process details
        MERGE INTO VDS_DETAILS tgt
        USING (
            SELECT 
                vl.vds_guid,
                stg.vds_name,
                stg.revision,
                TO_NUMBER(stg.valve_type_id) as valve_type_id,
                TO_NUMBER(stg.rating_class_id) as rating_class_id,
                TO_NUMBER(stg.material_type_id) as material_type_id,
                TO_NUMBER(stg.end_connection_id) as end_connection_id,
                stg.full_reduced_bore_indicator,
                TO_NUMBER(stg.bore_id) as bore_id,
                TO_NUMBER(stg.vds_size_id) as vds_size_id,
                stg.housing_design_indicator,
                TO_NUMBER(stg.housing_design_id) as housing_design_id,
                TO_NUMBER(stg.special_req_id) as special_req_id,
                TO_NUMBER(stg.min_operating_temperature) as min_operating_temperature,
                TO_NUMBER(stg.max_operating_temperature) as max_operating_temperature,
                stg.vds_description,
                stg.notepad,
                TO_DATE(stg.rev_date, 'DD.MM.YYYY') as rev_date,
                TO_DATE(stg.last_update, 'DD.MM.YYYY') as last_update,
                stg.last_update_by,
                TO_NUMBER(stg.subsegment_id) as subsegment_id,
                stg.subsegment_name,
                TO_NUMBER(stg.sequence_num) as sequence_num,
                stg.api_correlation_id
            FROM STG_VDS_DETAILS stg
            JOIN VDS_LIST vl ON vl.vds_name = stg.vds_name 
                AND NVL(vl.revision, 'NULL') = NVL(stg.revision, 'NULL')
                AND vl.is_valid = 'Y'
            WHERE (p_vds_name IS NULL OR stg.vds_name = p_vds_name)
              AND (p_revision IS NULL OR stg.revision = p_revision)
        ) src
        ON (tgt.vds_name = src.vds_name 
            AND NVL(tgt.revision, 'NULL') = NVL(src.revision, 'NULL')
            AND NVL(tgt.subsegment_id, -1) = NVL(src.subsegment_id, -1))
        WHEN MATCHED THEN
            UPDATE SET
                tgt.valve_type_id = src.valve_type_id,
                tgt.rating_class_id = src.rating_class_id,
                tgt.material_type_id = src.material_type_id,
                tgt.end_connection_id = src.end_connection_id,
                tgt.full_reduced_bore_indicator = src.full_reduced_bore_indicator,
                tgt.bore_id = src.bore_id,
                tgt.vds_size_id = src.vds_size_id,
                tgt.housing_design_indicator = src.housing_design_indicator,
                tgt.housing_design_id = src.housing_design_id,
                tgt.special_req_id = src.special_req_id,
                tgt.min_operating_temperature = src.min_operating_temperature,
                tgt.max_operating_temperature = src.max_operating_temperature,
                tgt.vds_description = src.vds_description,
                tgt.notepad = src.notepad,
                tgt.rev_date = src.rev_date,
                tgt.last_update = src.last_update,
                tgt.last_update_by = src.last_update_by,
                tgt.subsegment_name = src.subsegment_name,
                tgt.sequence_num = src.sequence_num,
                tgt.is_valid = 'Y',
                tgt.last_modified_date = SYSDATE,
                tgt.last_api_sync = SYSTIMESTAMP,
                tgt.api_correlation_id = src.api_correlation_id
        WHEN NOT MATCHED THEN
            INSERT (
                detail_guid,
                vds_guid,
                vds_name,
                revision,
                valve_type_id,
                rating_class_id,
                material_type_id,
                end_connection_id,
                full_reduced_bore_indicator,
                bore_id,
                vds_size_id,
                housing_design_indicator,
                housing_design_id,
                special_req_id,
                min_operating_temperature,
                max_operating_temperature,
                vds_description,
                notepad,
                rev_date,
                last_update,
                last_update_by,
                subsegment_id,
                subsegment_name,
                sequence_num,
                is_valid,
                created_date,
                last_modified_date,
                last_api_sync,
                api_correlation_id
            ) VALUES (
                SYS_GUID(),
                src.vds_guid,
                src.vds_name,
                src.revision,
                src.valve_type_id,
                src.rating_class_id,
                src.material_type_id,
                src.end_connection_id,
                src.full_reduced_bore_indicator,
                src.bore_id,
                src.vds_size_id,
                src.housing_design_indicator,
                src.housing_design_id,
                src.special_req_id,
                src.min_operating_temperature,
                src.max_operating_temperature,
                src.vds_description,
                src.notepad,
                src.rev_date,
                src.last_update,
                src.last_update_by,
                src.subsegment_id,
                src.subsegment_name,
                src.sequence_num,
                'Y',
                SYSDATE,
                SYSDATE,
                SYSTIMESTAMP,
                src.api_correlation_id
            );
        
        v_count := SQL%ROWCOUNT;
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('Upserted ' || v_count || ' VDS detail records');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error in upsert_vds_details: ' || SQLERRM);
            ROLLBACK;
            RAISE;
    END upsert_vds_details;

    -- =========================================================================
    -- Mark VDS not in latest load as invalid
    -- =========================================================================
    PROCEDURE invalidate_missing_vds IS
        v_count NUMBER;
    BEGIN
        -- Mark VDS not in staging as invalid
        UPDATE VDS_LIST
        SET is_valid = 'N',
            last_modified_date = SYSDATE
        WHERE is_valid = 'Y'
          AND (vds_name, NVL(revision, 'NULL')) NOT IN (
              SELECT vds_name, NVL(revision, 'NULL')
              FROM STG_VDS_LIST
          );
        
        v_count := SQL%ROWCOUNT;
        
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Marked ' || v_count || ' VDS records as invalid (not in latest load)');
        END IF;
        
        COMMIT;
    END invalidate_missing_vds;

    -- =========================================================================
    -- Get statistics
    -- =========================================================================
    FUNCTION get_vds_stats RETURN VARCHAR2 IS
        v_total_vds     NUMBER;
        v_valid_vds     NUMBER;
        v_details       NUMBER;
        v_official      NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_total_vds FROM VDS_LIST;
        SELECT COUNT(*) INTO v_valid_vds FROM VDS_LIST WHERE is_valid = 'Y';
        SELECT COUNT(*) INTO v_details FROM VDS_DETAILS WHERE is_valid = 'Y';
        SELECT COUNT(*) INTO v_official FROM VDS_LIST WHERE is_valid = 'Y' AND status = 'O';
        
        RETURN 'VDS Stats: Total=' || v_total_vds || 
               ', Valid=' || v_valid_vds || 
               ', Official=' || v_official ||
               ', Details=' || v_details;
    END get_vds_stats;

END pkg_upsert_vds;
/

-- Grant necessary permissions
GRANT EXECUTE ON pkg_upsert_vds TO TR2000_STAGING;
/