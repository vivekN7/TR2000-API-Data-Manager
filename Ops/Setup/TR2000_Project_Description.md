# Project Handling --- Refined v2 (hand‑off to Claude Code)

## Objective

Build a clean, auditable ETL from Equinor TR2000 API → Oracle
`TR2000_STAGING` schema using a **RAW_JSON → STG\_\* → CORE** pattern
with **minimal API calls**, **database‑centric logic**, and **simple
operations** suitable for POC→production.


We will start a project in @TR2000/TR2K/. There is list of endpoints listed in @TR2K/Ops/Setup/TR2000_API_Endpoints_Documentation.md. These are TR2000 information from Equinor. All of these endpoints are succesfully tested in the page "Direct API Calls" webpage in this project.
The eventual goal of the project is to setup an industry standard ETL process to transfer all relevant data from these API endpoints for specific plants and issue revisions only to tables in the "TR2000_Staging" schema in an oracle database.

We will develop this project step by step. 
1) Start with loading all plants directly from the endpoint "Get Plants" and show the plants in a dropdown list.
2) User selects the plants they want only into a "Selection_Loader" table.
3) Load all issue revisions for these plants and populate a dropdown.
4) User selects the issue revisions they need for each of the selected plants, which are updated into the "Selection_Loader" table.
5) All data and API calls hereforth should be loaded only for these selected plants and issue revisions. This minimises API calls significantly to only what is needed.
6) Once the issues are loaded succesfully, we will start by loading each reference tables one by one by using the relevant revision from the Issues table.
7) Any changes to the selected Plants and Issue revisions will automatically update the "Selection_Loader" table. And all changes will cascade down with the appropriate dropdowns updated. The tables will also be updated accordingly to ensure only the relevant api calls are made. Example - If user has initially selected 5 issues and 3 plants total, and all downstream data has been loaded - and now user removes 1 plant, then the issues for that removed plant and all relavent references data for that issue will also have their status set accordingly.

## Golden Rules

1)  **All DDL by owner only**: Maintain a single `Master_DDL.sql` in
    Git. Only Vivek runs it; AI/tools must never auto‑apply DDL.\
2)  **Logic lives in Oracle**: Keep C# to orchestration + logging +
    lightweight UI.\
3)  **Simplicity over overengineering**: We already have the TR2000 API;
    keep storage/flows lean and auditable.\
4)  **No DBA‑only features**: Everything must be runnable by
    `TR2000_STAGING` (no sys jobs/ILM/policies).\
5)  **Set‑based ops only**: No row‑by‑row loops for data processing.

------------------------------------------------------------------------

## Architecture (kept simple)

    API → RAW_JSON (immutable) → STG_* (parsed, varchar2) → CORE (typed, current-state with is_valid)

### RAW_JSON (first landing zone)

-   Store full API response + metadata:
    -   `raw_json_id` (surrogate key), `endpoint_key`, `plant`,
        `issue_rev`, `response_sha256`, `inserted_at`, `processed_flag`,
        `http_status`, `source_url`, `page/continuation_token` (if any).
-   **Dedup**: skip insert if `response_sha256` already exists for same
    `endpoint_key` + selection context.
-   **Indexes**: on (`endpoint_key`, `plant`, `issue_rev`,
    `processed_flag`), JSON search index on payload for ad‑hoc triage.
-   **Retention without DBA**:
    -   Provide a **user‑owned purge procedure**
        `pr_purge_raw_json(p_older_than_days IN NUMBER DEFAULT 30)` that
        deletes old, **processed** rows only.\
    -   Purge can be executed:
        -   Manually, or
        -   By an optional app‑side scheduler (C# service, APEX job)
            **owned by TR2000_STAGING**, not SYS.
    -   Make the default 30 days configurable in a `CONTROL_SETTINGS`
        table.

### STG\_\* (parsed, schema‑drift tolerant)

-   One table per endpoint (e.g., `STG_PLANTS`), **all VARCHAR2** for
    payload columns.
-   `raw_json_id` foreign key for lineage.
-   Load using `JSON_TABLE` (set‑based); **no business transforms**.
-   Minimal indices needed for join keys to CORE.

### CORE (typed, current‑state tables)

-   Example: `PLANTS`, `ISSUES`, etc.\
-   Strongly typed columns (DATE/NUMBER/VARCHAR2).\
-   **Current‑state model with soft validity**:
    -   `is_valid` (Y/N), `valid_from`, `valid_to`, `last_seen_at`,
        `last_changed_at`.
    -   **No SCD2 duplication**: one row per business key; updates in
        place.\
    -   If a record disappears from source for a selection scope → set
        `is_valid='N'`, stamp `valid_to`/`last_seen_at`.\
    -   If it returns → update fields + set `is_valid='Y'`, refresh
        `valid_from/last_changed_at`.
-   **Exposed views**: provide `V_PLANTS_CURRENT` etc. with
    `is_valid='Y'` to keep consumers simple.

------------------------------------------------------------------------

## Selection & API Scoping

-   `SELECTION_LOADER` holds the active **plants** and **issue
    revisions** chosen for processing.
-   **Dev phase**: dropdown UI in C# to populate `SELECTION_LOADER`.\
-   **Prod phase**: admins populate `SELECTION_LOADER` directly (APEX
    mini‑UI or SQL), and scheduled runs read from it.
-   All downstream loads **must filter** by the current contents of
    `SELECTION_LOADER`.

------------------------------------------------------------------------

## Error Handling & Monitoring (lightweight, no DBA)

-   Tables:
    -   `ETL_RUN_LOG` --- one row per run: run_id, component, start/end,
        status, counts, message.
    -   `ETL_ERROR_LOG` --- run‑scoped errors: run_id, component, stage
        (RAW/STG/CORE), error_code, message, context (endpoint_key,
        plant, issue_rev, raw_json_id), occurred_at.
    -   `ETL_KPI_SNAPSHOTS` --- optional daily counts per table: loaded,
        updated, invalidated, deduped, API failures.
-   Procedures **must** log start/finish + counts
    (inserted/updated/invalidated/deduped) and any exceptions.
-   Viewing/Alerting:
    -   Simple APEX page or a C# dashboard page that lists last N runs
        and errors.\
    -   Optional email/slack webhook from app‑side if `status='FAILED'`.
        (No DBMS_SCHEDULER privileges needed.)

------------------------------------------------------------------------

## Incremental Loading Strategy (no SCD2)

-   **Core principle**: minimize API calls using selection scope and
    last‑seen timestamps where available.
-   For endpoints with timestamps/versions → fetch only changed pages
    (if supported).
-   For endpoints without deltas → fetch scoped full snapshot, then
    **upsert** in CORE:
    -   `MERGE` logic sets `is_valid='Y'` and updates changed fields.
    -   Anything not seen in this run but previously valid within the
        same selection scope is soft‑invalidated.
-   Maintain `last_successful_run` per endpoint/selection in
    `CONTROL_ENDPOINT_STATE`.

------------------------------------------------------------------------

## Data Validation / Quality Checks (lean)

-   **Pre‑load sanity** (STG):
    -   Non‑null checks for required keys (record to `ETL_ERROR_LOG`,
        quarantine row with `stg_validation_flag='E'`).
    -   Simple domain checks (e.g., enumerations) when cheap.
-   **Cross‑table integrity** (CORE):
    -   Foreign key existence checks (e.g., issue belongs to plant).
    -   Row count reconciliation per run (expected vs loaded). Record in
        `ETL_RUN_LOG`.
-   **Performance note**: keep checks set‑based; avoid heavy regex or
    deep JSON scans beyond STG load.

------------------------------------------------------------------------

## Metadata‑Driven ETL (keep it simple)

-   `CONTROL_ENDPOINTS`:
    -   `endpoint_key`, `url_template`, `primary_keys (csv)`,
        `has_paging (Y/N)`, `delta_field`, `active (Y/N)`, `stg_table`,
        `core_table`, `parser_proc`, `upsert_proc`.
-   `CONTROL_SETTINGS`: key/value for tunables (purge_days, batch_sizes,
    api_timeout, retry_count).
-   `CONTROL_ENDPOINT_STATE`: endpoint_key + selection context,
    `last_run_at`, `last_delta_value`, run status.
-   Rationale: lets us add endpoints without code churn; procedures can
    iterate `CONTROL_ENDPOINTS`.

------------------------------------------------------------------------

## Testing Strategy

-   **PL/SQL unit tests** via `utPLSQL` (or a minimal homegrown
    framework if you want ultra‑light):
    -   Parsing correctness (JSON→STG), dedup, merge/upsert correctness,
        invalidation/reactivation.
-   **API mocks**:
    -   Provide small, versioned JSON fixtures per endpoint for
        repeatable tests.
-   **C# smoke tests**:
    -   Endpoint reachability, dropdown population, selection write/read
        round trip, trigger‑run → check `ETL_RUN_LOG`.
-   **Data diff checks**:
    -   For a known golden dataset, compare CORE tables post‑run against
        expected (counts + key fields).

------------------------------------------------------------------------

## Deployment & CI/CD (no overengineering)

-   **Git repo layout**:

        /db
          /ddl   -> Master_DDL.sql (idempotent as far as practical)
          /dml   -> procs/packages (versioned)
          /tests -> utPLSQL scripts + JSON fixtures
        /app
          /csharp -> Blazor UI + orchestrator
        /ops
          /docs -> Runbooks, PRD, DADR, checklists

-   **Process**:

    1)  Dev change → PR with review (include updated `Master_DDL.sql`
        and/or procs).\
    2)  CI validation: SQL lint/syntax check; run utPLSQL against a
        containerized XE/Test DB if available.\
    3)  **Manual apply**: Only Vivek runs `Master_DDL.sql` and proc
        scripts on target. Commit tags the release.\

-   Tools: plain SQL\*Plus/SQLcl scripts are fine; Flyway/Liquibase
    optional later if you want migrations. For now, keep it manual and
    simple per your requirement.

------------------------------------------------------------------------

## Orchestration & Scheduling

-   **POC**: C# Blazor page triggers a run for selected endpoints (dev
    dropdowns).\
-   **Later**: Move orchestration to **Oracle APEX** (as requested by
    DBA) using `TR2000_STAGING` privileges only, or keep a tiny C#
    service that runs on a weekly schedule. Both read
    `SELECTION_LOADER` + `CONTROL_ENDPOINTS`.

------------------------------------------------------------------------

## Security (defer)

-   Internal network only for POC. Later, store secrets in Oracle Wallet
    or Key Vault; least‑privilege roles.

------------------------------------------------------------------------

## C# App Notes

-   Use **Dapper** for all data viewing (queries against `V_*_CURRENT`
    views).\
-   Keep API invocations minimal and logged; batch writes to DB via
    array binds.

------------------------------------------------------------------------

## What's intentionally excluded

-   Full SCD2 dimensions everywhere (not needed).\
-   DBA‑managed ILM, scheduler, or system jobs.\
-   Reject tables (we use `ETL_ERROR_LOG`).\
-   Complex crosswalks (unless a specific business need arises).

------------------------------------------------------------------------

## Purge Plan (RAW_JSON) without DBA

-   `pr_purge_raw_json(p_days IN NUMBER DEFAULT (SELECT setting_value FROM CONTROL_SETTINGS WHERE setting_key='PURGE_DAYS'))`\
-   Deletes rows where `processed_flag='Y'` and
    `inserted_at < SYSDATE - p_days`.\
-   Trigger via:
    -   Button in APEX/C# admin page, or
    -   App‑side timer (Windows/Linux service) running under app creds,
        or
    -   Manual SQL call in runbook.\
-   Add a safety guard: **dry‑run mode** returning counts before delete.

------------------------------------------------------------------------

## Minimal task list for Claude Code to start

1)  **Scaffold DDL (in `Master_DDL.sql`)**: RAW_JSON base table,
    STG_PLANTS, PLANTS (CORE), SELECTION_LOADER, ETL\_\* tables,
    CONTROL\_\* tables.\
2)  **PL/SQL packages**:
    -   `pkg_raw_ingest`: insert RAW_JSON with dedup + metadata.\
    -   `pkg_parse_plants`: JSON_TABLE → STG_PLANTS.\
    -   `pkg_upsert_plants`: MERGE into PLANTS + validity handling.\
    -   `pkg_run_plants`: orchestrates ingest→parse→upsert for Plants.\
    -   `pkg_ops`: `pr_purge_raw_json`, run logging helpers.\
3)  **C# POC**:
    -   Dropdowns to manage `SELECTION_LOADER`.\
    -   Buttons to "Run Plants" / "Run Issues" and show `ETL_RUN_LOG` &
        `ETL_ERROR_LOG`.\
    -   Dapper data views for `V_*_CURRENT`.\
4)  **Tests**:
    -   Add utPLSQL tests + JSON fixtures for Plants.\
    -   CI job that lint‑checks SQL and runs unit tests (optional if you
        want ultra‑lean now).
