-- VDS Details Tables
-- Session 18: VDS Details Implementation
-- Based on API Section 4.2: vds/{vdsname}/rev/{revision}

-- ============================================
-- VDS_LIST: Master list of ALL VDS from API
-- ============================================
-- Drop existing table if exists
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE VDS_LIST CASCADE CONSTRAINTS';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE VDS_LIST (
    vds_guid RAW(16) DEFAULT SYS_GUID() NOT NULL,
    vds_name VARCHAR2(100) NOT NULL,
    revision VARCHAR2(50),
    status VARCHAR2(50),
    rev_date DATE,
    last_update DATE,
    last_update_by VARCHAR2(100),
    description VARCHAR2(4000),
    notepad VARCHAR2(4000),
    special_req_id NUMBER,
    valve_type_id NUMBER,
    rating_class_id NUMBER,
    material_group_id NUMBER,
    end_connection_id NUMBER,
    bore_id NUMBER,
    vds_size_id NUMBER,
    size_range VARCHAR2(100),
    custom_name VARCHAR2(200),
    subsegment_list VARCHAR2(4000),
    -- Metadata
    is_valid CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y','N')),
    created_date DATE DEFAULT SYSDATE,
    last_modified_date DATE DEFAULT SYSDATE,
    last_api_sync TIMESTAMP DEFAULT SYSTIMESTAMP,
    api_correlation_id VARCHAR2(36),
    CONSTRAINT pk_vds_list PRIMARY KEY (vds_guid),
    CONSTRAINT uk_vds_list_name_rev UNIQUE (vds_name, revision)
);

-- Indexes for performance
CREATE INDEX idx_vds_list_name ON VDS_LIST(vds_name);
CREATE INDEX idx_vds_list_status ON VDS_LIST(status);
CREATE INDEX idx_vds_list_valid ON VDS_LIST(is_valid);

-- Comments
COMMENT ON TABLE VDS_LIST IS 'Master list of all VDS from API /vds endpoint (44,000+ records)';
COMMENT ON COLUMN VDS_LIST.vds_guid IS 'Primary key GUID for VDS record';
COMMENT ON COLUMN VDS_LIST.vds_name IS 'VDS identifier name';
COMMENT ON COLUMN VDS_LIST.revision IS 'VDS revision';
COMMENT ON COLUMN VDS_LIST.status IS 'VDS status (Official, Review, etc.)';

-- ============================================
-- STG_VDS_LIST: Staging for VDS master list
-- ============================================
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE STG_VDS_LIST CASCADE CONSTRAINTS';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE STG_VDS_LIST (
    -- VDS fields from API
    vds_name VARCHAR2(100),
    revision VARCHAR2(50),
    status VARCHAR2(50),
    rev_date VARCHAR2(100),
    last_update VARCHAR2(100),
    last_update_by VARCHAR2(100),
    description VARCHAR2(4000),
    notepad VARCHAR2(4000),
    special_req_id VARCHAR2(50),
    valve_type_id VARCHAR2(50),
    rating_class_id VARCHAR2(50),
    material_group_id VARCHAR2(50),
    end_connection_id VARCHAR2(50),
    bore_id VARCHAR2(50),
    vds_size_id VARCHAR2(50),
    size_range VARCHAR2(100),
    custom_name VARCHAR2(200),
    subsegment_list VARCHAR2(4000),
    -- Raw JSON for debugging
    raw_json CLOB,
    -- Metadata
    created_date DATE DEFAULT SYSDATE,
    api_correlation_id VARCHAR2(36)
);

-- ============================================
-- STG_VDS_DETAILS: Staging for VDS details
-- ============================================
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE STG_VDS_DETAILS CASCADE CONSTRAINTS';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE STG_VDS_DETAILS (
    -- Reference to VDS
    vds_name VARCHAR2(100),
    revision VARCHAR2(50),
    -- API Response fields from Section 4.2
    valve_type_id VARCHAR2(50),
    rating_class_id VARCHAR2(50),
    material_type_id VARCHAR2(50),
    end_connection_id VARCHAR2(50),
    full_reduced_bore_indicator VARCHAR2(50),
    bore_id VARCHAR2(50),
    vds_size_id VARCHAR2(50),
    housing_design_indicator VARCHAR2(50),
    housing_design_id VARCHAR2(50),
    special_req_id VARCHAR2(50),
    min_operating_temperature VARCHAR2(50),
    max_operating_temperature VARCHAR2(50),
    vds_description VARCHAR2(4000),
    notepad VARCHAR2(4000),
    rev_date VARCHAR2(100),
    last_update VARCHAR2(100),
    last_update_by VARCHAR2(100),
    subsegment_id VARCHAR2(50),
    subsegment_name VARCHAR2(200),
    sequence_num VARCHAR2(50),
    -- Raw JSON for debugging
    raw_json CLOB,
    -- Metadata
    created_date DATE DEFAULT SYSDATE,
    api_correlation_id VARCHAR2(36)
);

-- ============================================
-- VDS_DETAILS: Core VDS details table
-- ============================================
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE VDS_DETAILS CASCADE CONSTRAINTS';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE VDS_DETAILS (
    detail_guid RAW(16) DEFAULT SYS_GUID() NOT NULL,
    -- Link to VDS_LIST (not VDS_REFERENCES)
    vds_guid RAW(16) NOT NULL,
    vds_name VARCHAR2(100) NOT NULL,
    revision VARCHAR2(50),
    -- Core VDS properties
    valve_type_id NUMBER,
    rating_class_id NUMBER,
    material_type_id NUMBER,
    end_connection_id NUMBER,
    full_reduced_bore_indicator VARCHAR2(10),
    bore_id NUMBER,
    vds_size_id NUMBER,
    housing_design_indicator VARCHAR2(10),
    housing_design_id NUMBER,
    special_req_id NUMBER,
    min_operating_temperature NUMBER,
    max_operating_temperature NUMBER,
    vds_description VARCHAR2(4000),
    notepad VARCHAR2(4000),
    rev_date DATE,
    last_update DATE,
    last_update_by VARCHAR2(100),
    -- Subsegment information
    subsegment_id NUMBER,
    subsegment_name VARCHAR2(200),
    sequence_num NUMBER,
    -- Metadata
    is_valid CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y','N')),
    created_date DATE DEFAULT SYSDATE,
    last_modified_date DATE DEFAULT SYSDATE,
    last_api_sync TIMESTAMP DEFAULT SYSTIMESTAMP,
    api_correlation_id VARCHAR2(36),
    CONSTRAINT pk_vds_details PRIMARY KEY (detail_guid),
    CONSTRAINT fk_vds_details_list FOREIGN KEY (vds_guid) 
        REFERENCES VDS_LIST(vds_guid) ON DELETE CASCADE,
    CONSTRAINT uk_vds_details UNIQUE (vds_name, revision, subsegment_id)
);

-- Indexes for performance
CREATE INDEX idx_vds_details_vds ON VDS_DETAILS(vds_guid);
CREATE INDEX idx_vds_details_name ON VDS_DETAILS(vds_name);
CREATE INDEX idx_vds_details_valid ON VDS_DETAILS(is_valid);
CREATE INDEX idx_vds_details_subseg ON VDS_DETAILS(subsegment_id);

-- Comments
COMMENT ON TABLE VDS_DETAILS IS 'Detailed VDS information from /vds/{name}/rev/{revision} endpoint';
COMMENT ON COLUMN VDS_DETAILS.detail_guid IS 'Primary key GUID';
COMMENT ON COLUMN VDS_DETAILS.vds_guid IS 'Foreign key to VDS_LIST';
COMMENT ON COLUMN VDS_DETAILS.subsegment_id IS 'Subsegment identifier within VDS';
COMMENT ON COLUMN VDS_DETAILS.sequence_num IS 'Order sequence for subsegments';

-- Create trigger to cascade invalidation
CREATE OR REPLACE TRIGGER trg_vds_list_cascade
AFTER UPDATE OF is_valid ON VDS_LIST
FOR EACH ROW
WHEN (NEW.is_valid = 'N' AND OLD.is_valid = 'Y')
BEGIN
    -- Mark related details as invalid
    UPDATE VDS_DETAILS
    SET is_valid = 'N',
        last_modified_date = SYSDATE
    WHERE vds_guid = :NEW.vds_guid
      AND is_valid = 'Y';
END;
/

-- Add VDS loading mode to control settings if not exists
MERGE INTO CONTROL_SETTINGS cs
USING (
    SELECT 'VDS_LOADING_MODE' as setting_key,
           'OFFICIAL_ONLY' as setting_value,
           'Controls VDS detail loading: OFFICIAL_ONLY or ALL_REVISIONS' as description
    FROM DUAL
) src
ON (cs.setting_key = src.setting_key)
WHEN NOT MATCHED THEN
    INSERT (setting_key, setting_value, description, created_date, modified_date)
    VALUES (src.setting_key, src.setting_value, src.description, SYSDATE, SYSDATE);

COMMIT;
/