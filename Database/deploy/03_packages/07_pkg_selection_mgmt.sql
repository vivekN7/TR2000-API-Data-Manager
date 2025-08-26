-- ===============================================================================
-- Package: PKG_SELECTION_MGMT
-- Purpose: Manages user selections for plants and issues
-- ===============================================================================

-- Package Specification
CREATE OR REPLACE PACKAGE pkg_selection_mgmt AS
    -- Add/update plant selection
    PROCEDURE save_plant_selection(
        p_plant_ids    VARCHAR2,  -- Comma-separated plant IDs
        p_user         VARCHAR2 DEFAULT USER,
        p_status       OUT VARCHAR2,
        p_message      OUT VARCHAR2
    );

    -- Remove plant selection (with cascade)
    PROCEDURE remove_plant_selection(
        p_plant_id     VARCHAR2,
        p_status       OUT VARCHAR2,
        p_message      OUT VARCHAR2
    );

    -- Add/update issue selection for a plant
    PROCEDURE save_issue_selection(
        p_plant_id     VARCHAR2,
        p_issue_revs   VARCHAR2,  -- Comma-separated issue revisions
        p_user         VARCHAR2 DEFAULT USER,
        p_status       OUT VARCHAR2,
        p_message      OUT VARCHAR2
    );

    -- Clear all selections
    PROCEDURE clear_all_selections(
        p_status       OUT VARCHAR2,
        p_message      OUT VARCHAR2
    );

    -- Get active plant selections
    FUNCTION get_active_plants RETURN VARCHAR2;

    -- Get active issues for a plant
    FUNCTION get_active_issues(p_plant_id VARCHAR2) RETURN VARCHAR2;

END pkg_selection_mgmt;
/

-- Package Body
CREATE OR REPLACE PACKAGE BODY pkg_selection_mgmt AS

    -- Save plant selection
    PROCEDURE save_plant_selection(
        p_plant_ids    VARCHAR2,
        p_user         VARCHAR2 DEFAULT USER,
        p_status       OUT VARCHAR2,
        p_message      OUT VARCHAR2
    ) IS
        v_plant_id VARCHAR2(50);
        v_count    NUMBER := 0;
    BEGIN
        -- First, deactivate all current plant selections
        UPDATE SELECTION_LOADER
        SET is_active = 'N'
        WHERE issue_revision IS NULL  -- Plants have no issue_revision
        AND is_active = 'Y';

        -- Parse comma-separated plant IDs and activate them
        FOR i IN (
            SELECT TRIM(REGEXP_SUBSTR(p_plant_ids, '[^,]+', 1, LEVEL)) as plant_id
            FROM DUAL
            CONNECT BY REGEXP_SUBSTR(p_plant_ids, '[^,]+', 1, LEVEL) IS NOT NULL
        ) LOOP
            v_plant_id := i.plant_id;

            -- Skip empty values
            IF v_plant_id IS NOT NULL THEN
                -- Insert or update selection
                MERGE INTO SELECTION_LOADER sl
                USING (SELECT v_plant_id as pid FROM DUAL) src
                ON (sl.plant_id = src.pid AND sl.issue_revision IS NULL)
                WHEN MATCHED THEN
                    UPDATE SET
                        is_active = 'Y',
                        selected_by = p_user,
                        selection_date = SYSDATE
                WHEN NOT MATCHED THEN
                    INSERT (plant_id, issue_revision, is_active,
                           selected_by, selection_date)
                    VALUES (v_plant_id, NULL, 'Y', p_user, SYSDATE);

                v_count := v_count + 1;
            END IF;
        END LOOP;

        COMMIT;
        p_status := 'SUCCESS';
        p_message := v_count || ' plant(s) selected';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_status := 'ERROR';
            p_message := SQLERRM;
    END save_plant_selection;

    -- Remove plant selection with cascade
    PROCEDURE remove_plant_selection(
        p_plant_id     VARCHAR2,
        p_status       OUT VARCHAR2,
        p_message      OUT VARCHAR2
    ) IS
        v_issue_count NUMBER;
    BEGIN
        -- Count dependent issues
        SELECT COUNT(*)
        INTO v_issue_count
        FROM SELECTION_LOADER
        WHERE plant_id = p_plant_id
        AND issue_revision IS NOT NULL
        AND is_active = 'Y';

        -- Cascade delete - deactivate issues first
        UPDATE SELECTION_LOADER
        SET is_active = 'N'
        WHERE plant_id = p_plant_id
        AND issue_revision IS NOT NULL
        AND is_active = 'Y';

        -- Deactivate plant
        UPDATE SELECTION_LOADER
        SET is_active = 'N'
        WHERE plant_id = p_plant_id
        AND issue_revision IS NULL
        AND is_active = 'Y';

        COMMIT;
        p_status := 'SUCCESS';
        p_message := 'Plant removed. ' || v_issue_count || ' related issues also removed.';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_status := 'ERROR';
            p_message := SQLERRM;
    END remove_plant_selection;

    -- Save issue selection
    PROCEDURE save_issue_selection(
        p_plant_id     VARCHAR2,
        p_issue_revs   VARCHAR2,
        p_user         VARCHAR2 DEFAULT USER,
        p_status       OUT VARCHAR2,
        p_message      OUT VARCHAR2
    ) IS
        v_issue_rev VARCHAR2(50);
        v_count     NUMBER := 0;
        v_plant_selected NUMBER;
    BEGIN
        -- First check if plant is selected
        SELECT COUNT(*)
        INTO v_plant_selected
        FROM SELECTION_LOADER
        WHERE plant_id = p_plant_id
        AND issue_revision IS NULL
        AND is_active = 'Y';

        IF v_plant_selected = 0 THEN
            p_status := 'ERROR';
            p_message := 'Plant ' || p_plant_id || ' must be selected first';
            RETURN;
        END IF;

        -- Deactivate current issues for this plant
        UPDATE SELECTION_LOADER
        SET is_active = 'N'
        WHERE plant_id = p_plant_id
        AND issue_revision IS NOT NULL
        AND is_active = 'Y';

        -- Parse and save issue selections
        FOR i IN (
            SELECT TRIM(REGEXP_SUBSTR(p_issue_revs, '[^,]+', 1, LEVEL)) as issue_rev
            FROM DUAL
            CONNECT BY REGEXP_SUBSTR(p_issue_revs, '[^,]+', 1, LEVEL) IS NOT NULL
        ) LOOP
            v_issue_rev := i.issue_rev;

            IF v_issue_rev IS NOT NULL THEN
                MERGE INTO SELECTION_LOADER sl
                USING (SELECT v_issue_rev as irev FROM DUAL) src
                ON (sl.plant_id = p_plant_id
                    AND sl.issue_revision = src.irev)
                WHEN MATCHED THEN
                    UPDATE SET
                        is_active = 'Y',
                        selected_by = p_user,
                        selection_date = SYSDATE
                WHEN NOT MATCHED THEN
                    INSERT (plant_id, issue_revision,
                           is_active, selected_by, selection_date)
                    VALUES (p_plant_id, v_issue_rev, 'Y', p_user, SYSDATE);

                v_count := v_count + 1;
            END IF;
        END LOOP;

        COMMIT;
        p_status := 'SUCCESS';
        p_message := v_count || ' issue(s) selected for plant ' || p_plant_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_status := 'ERROR';
            p_message := SQLERRM;
    END save_issue_selection;

    -- Clear all selections
    PROCEDURE clear_all_selections(
        p_status       OUT VARCHAR2,
        p_message      OUT VARCHAR2
    ) IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM SELECTION_LOADER
        WHERE is_active = 'Y';

        UPDATE SELECTION_LOADER
        SET is_active = 'N'
        WHERE is_active = 'Y';

        COMMIT;
        p_status := 'SUCCESS';
        p_message := v_count || ' selection(s) cleared';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_status := 'ERROR';
            p_message := SQLERRM;
    END clear_all_selections;

    -- Get active plants as comma-separated list
    FUNCTION get_active_plants RETURN VARCHAR2 IS
        v_result VARCHAR2(4000);
    BEGIN
        SELECT LISTAGG(plant_id, ',') WITHIN GROUP (ORDER BY plant_id)
        INTO v_result
        FROM SELECTION_LOADER
        WHERE issue_revision IS NULL  -- Plants only
        AND is_active = 'Y';

        RETURN v_result;
    END get_active_plants;

    -- Get active issues for a plant
    FUNCTION get_active_issues(p_plant_id VARCHAR2) RETURN VARCHAR2 IS
        v_result VARCHAR2(4000);
    BEGIN
        SELECT LISTAGG(issue_revision, ',') WITHIN GROUP (ORDER BY issue_revision)
        INTO v_result
        FROM SELECTION_LOADER
        WHERE plant_id = p_plant_id
        AND issue_revision IS NOT NULL  -- Issues only
        AND is_active = 'Y';

        RETURN v_result;
    END get_active_issues;

END pkg_selection_mgmt;
/