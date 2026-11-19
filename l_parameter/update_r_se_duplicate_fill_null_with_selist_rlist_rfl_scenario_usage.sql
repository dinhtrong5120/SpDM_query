-- Compare normalized fields directly (no concatenated/JSON key); NULL and empty strings are equivalent.
-- Includes blank/null parameter names; uniqueness covers ALL active masters.
-- MySQL 8.0+, run in a dedicated session with the intended default database selected.
-- Default: PREVIEW ONLY. No master data changes until @execute=1 AND exact confirmation matches.
-- Requires CREATE ROUTINE privilege; the helper procedure is removed at the end.
-- Only se_parameter.parameter_name_2 and r_parameter.design_item_3 are updated.
-- Scope: all active masters, including blank/null fields; inactive records are unchanged.
-- Source: QUERY 3 in check_r_se_duplicate_fill_null_with_selist_rlist_rfl_scenario_usage.sql.
-- Same active-master comparison, including hierarchy; usage flags are informational, NOT filters.
-- Lowest ID stays unchanged. Higher IDs, ascending: suffix repeated 1, 2, 3, ... times.
-- Selected SQL NULL first tries '-'; on collision it becomes '-_', '-__', ... .
-- Empty strings still get the suffix; selection rules from the source duplicate query are unchanged.
-- Trailing whitespace is removed before appending to non-NULL values.
-- Example: A, A, A -> A, A_, A__. NULL, NULL, NULL -> NULL, '-', '-_' (if available).
-- Compare each field directly after NULL -> '', trim and lower; hierarchy participates.
-- Default suffix '_' follows the request examples; use '*' below if asterisks are intended.
-- Scenario/project IDs, links and their cached text are NOT changed or synchronized.
-- Preview returns all planned old/new values and usage flags; export the grid to Excel before execute.
-- Execution verifies the proposed state has no duplicate signatures and checks both UPDATE counts.
-- Errors roll back BOTH master UPDATEs. Rerunning after success finds no duplicates and is a no-op.
-- Existing A_ is reserved: the algorithm tries additional underscores until the entire tuple is unique.

SET @execute = 0;
SET @suffix_character = '_';
SET @confirmation = NULL; -- Copy expected_confirmation from preview; then set @execute=1 and rerun.

-- Remove only this script's helper if an earlier failed call left it behind.
DROP PROCEDURE IF EXISTS spdm_apply_duplicate_parameter_suffix_20261119;
DELIMITER $$
CREATE PROCEDURE spdm_apply_duplicate_parameter_suffix_20261119(
    IN p_execute BOOLEAN, IN p_suffix VARCHAR(1), IN p_confirmation LONGTEXT
)
SQL SECURITY INVOKER
main: BEGIN
    DECLARE v_expected LONGTEXT;
    DECLARE v_ids LONGTEXT;
    DECLARE v_id_length BIGINT DEFAULT 0;
    DECLARE v_collisions BIGINT DEFAULT 0;
    DECLARE v_rounds BIGINT DEFAULT 0;
    DECLARE v_after_collisions BIGINT DEFAULT 0;
    DECLARE v_se BIGINT DEFAULT 0;
    DECLARE v_r BIGINT DEFAULT 0;
    DECLARE v_changed_se BIGINT DEFAULT 0;
    DECLARE v_changed_r BIGINT DEFAULT 0;
    DECLARE v_group_concat_max_len BIGINT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET SESSION group_concat_max_len = v_group_concat_max_len;
        SELECT 'ROLLED_BACK' AS status, DATABASE() AS database_name, 0 AS committed_updates;
        RESIGNAL;
    END;
    SET v_group_concat_max_len = @@session.group_concat_max_len;
    IF DATABASE() IS NULL OR p_suffix IS NULL OR p_suffix NOT IN ('_', '*') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Select a database and choose suffix _ or *.';
    END IF;
    IF p_execute IS NULL OR p_execute NOT IN (0, 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='execute must be 0 or 1.';
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tmp_spdm_duplicate_suffix_plan;
    DROP TEMPORARY TABLE IF EXISTS tmp_spdm_suffix_collisions;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    START TRANSACTION;
    CREATE TEMPORARY TABLE tmp_spdm_duplicate_suffix_plan ENGINE=InnoDB AS
WITH parameter_master AS (
    SELECT 'SE' AS parameter_type, m.id AS parameter_id,
           wp.wp, m.parameter_name_1 AS category, m.parameter_name_2 AS parameter_name,
           NULL AS performance, NULL AS design_item_1, NULL AS design_item_2,
           NULL AS design_item_3, u.unit, h.hierarchy
    FROM se_parameter m
    LEFT JOIN wp ON wp.id=m.wp_id
    LEFT JOIN units u ON u.id=m.unit_id
    LEFT JOIN hierarchy h ON h.id=m.hierarchy_id
    WHERE m.is_active=1
    UNION ALL
    SELECT 'R', m.id, wp.wp, NULL, NULL, m.performance,
           m.design_item_1, m.design_item_2, m.design_item_3, u.unit, h.hierarchy
    FROM r_parameter m
    LEFT JOIN wp ON wp.id=m.wp_id
    LEFT JOIN units u ON u.id=m.unit_id
    LEFT JOIN hierarchy h ON h.id=m.hierarchy_id
    WHERE m.is_active=1
), normalized AS (
    SELECT parameter_master.*,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(wp, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS wp_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(category, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS category_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(parameter_name, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS parameter_name_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(performance, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS performance_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(design_item_1, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS design_item_1_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(design_item_2, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS design_item_2_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(design_item_3, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS design_item_3_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(unit, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS unit_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(hierarchy, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS hierarchy_key
    FROM parameter_master
), signatures AS (
    SELECT normalized.*
    FROM normalized
), ranked AS (
    SELECT signatures.*,
           ROW_NUMBER() OVER (PARTITION BY parameter_type,wp_key,category_key,parameter_name_key,performance_key,design_item_1_key,design_item_2_key,design_item_3_key,unit_key,hierarchy_key ORDER BY parameter_id) AS duplicate_rank,
           COUNT(*) OVER (PARTITION BY parameter_type,wp_key,category_key,parameter_name_key,performance_key,design_item_1_key,design_item_2_key,design_item_3_key,unit_key,hierarchy_key) AS duplicate_count,
           MIN(parameter_id) OVER (PARTITION BY parameter_type,wp_key,category_key,parameter_name_key,performance_key,design_item_1_key,design_item_2_key,design_item_3_key,unit_key,hierarchy_key) AS duplicate_group_id
    FROM signatures
), duplicates AS (
    SELECT * FROM ranked WHERE duplicate_count>1
)
SELECT d.parameter_type, d.duplicate_group_id, d.duplicate_count, d.parameter_id,
       CASE WHEN (d.parameter_type='SE' AND d.parameter_name IS NULL)
                      OR (d.parameter_type='R' AND d.design_item_3 IS NULL) THEN 0
            ELSE d.duplicate_rank - 1 END AS suffix_count,
       CASE WHEN d.parameter_type='SE' THEN d.parameter_name ELSE d.design_item_3 END AS old_value,
       CASE WHEN (d.parameter_type='SE' AND d.parameter_name IS NULL)
                      OR (d.parameter_type='R' AND d.design_item_3 IS NULL) THEN '-'
            ELSE CONCAT(
                REGEXP_REPLACE(COALESCE(CASE WHEN d.parameter_type='SE' THEN d.parameter_name ELSE d.design_item_3 END, ''), '[[:space:]]+$', ''),
                REPEAT(p_suffix, d.duplicate_rank - 1)
            )
       END AS new_value,
       COALESCE(d.wp, '-') AS wp, COALESCE(d.category, '-') AS category, COALESCE(d.parameter_name, '-') AS parameter_name, COALESCE(d.performance, '-') AS performance,
       COALESCE(d.design_item_1, '-') AS design_item_1, COALESCE(d.design_item_2, '-') AS design_item_2, COALESCE(d.design_item_3, '-') AS design_item_3, COALESCE(d.unit, '-') AS unit, COALESCE(d.hierarchy, '-') AS hierarchy,
       CASE WHEN d.parameter_type='R' THEN
           CASE WHEN EXISTS (
               SELECT 1 FROM setup_r_relation sr
               JOIN rfl rf ON rf.requirement_s_id=sr.id
               JOIN prj_rfl pr ON pr.rfl_id=rf.id
               JOIN project_info pi_rfl ON pi_rfl.id=pr.project_info_id
               WHERE sr.r_parameter_id=d.parameter_id
           ) OR EXISTS (
               SELECT 1 FROM setup_r_relation sr
               JOIN l_r_relation lr ON lr.r_s_id=sr.id
               JOIN rfl rf ON rf.logic_s_id=lr.l_s_id
               JOIN prj_rfl pr ON pr.rfl_id=rf.id
               JOIN project_info pi_rfl ON pi_rfl.id=pr.project_info_id
               WHERE sr.r_parameter_id=d.parameter_id
           ) THEN 'YES' ELSE 'NO' END
       ELSE
           CASE WHEN EXISTS (
               SELECT 1 FROM l_parameter lp
               JOIN setup_l_relation sl ON sl.l_parameter_id=lp.id
               JOIN rfl rf ON rf.logic_s_id=sl.id
               JOIN prj_rfl pr ON pr.rfl_id=rf.id
               JOIN project_info pi_rfl ON pi_rfl.id=pr.project_info_id
               WHERE lp.related_se_parameter_id=d.parameter_id
           ) THEN 'YES' ELSE 'NO' END
       END AS is_used_in_project_rfl,
       CASE WHEN d.parameter_type='R' THEN
           CASE WHEN EXISTS (
               SELECT 1 FROM test_senario_list_parameter sc
               WHERE sc.rflcategory='R' AND sc.rflid=d.parameter_id
           ) THEN 'YES' ELSE 'NO' END
       ELSE
           CASE WHEN EXISTS (
               SELECT 1 FROM test_senario_list_parameter sc
               WHERE sc.category='SE' AND sc.parent_id=d.parameter_id
           ) THEN 'YES' ELSE 'NO' END
       END AS is_used_in_scenario_master,
       CASE WHEN d.parameter_type='SE' THEN 'N/A'
            WHEN EXISTS (
                SELECT 1 FROM project_r_parameter rp
                JOIN project_info pi_rlist ON pi_rlist.id=rp.project_id
                WHERE rp.r_parameter_id=d.parameter_id
            ) THEN 'YES' ELSE 'NO'
       END AS is_used_in_project_rlist,
       CASE WHEN d.parameter_type='R' THEN 'N/A'
            WHEN EXISTS (
                SELECT 1 FROM project_parameter sp
                JOIN project_info pi_selist ON pi_selist.id=sp.project_id
                WHERE sp.se_parameter_id=d.parameter_id
            ) THEN 'YES' ELSE 'NO'
       END AS is_used_in_project_selist
FROM duplicates d
WHERE d.duplicate_rank > 1
ORDER BY d.parameter_type,d.duplicate_group_id,d.parameter_id;

    CREATE TEMPORARY TABLE tmp_spdm_suffix_collisions (
        parameter_type VARCHAR(2) NOT NULL,
        parameter_id BIGINT NOT NULL,
        PRIMARY KEY(parameter_type, parameter_id)
    ) ENGINE=InnoDB;
    resolve_collisions: LOOP
        DELETE FROM tmp_spdm_suffix_collisions;
        INSERT INTO tmp_spdm_suffix_collisions (parameter_type, parameter_id)



WITH parameter_master AS (
    SELECT 'SE' AS parameter_type, m.id AS parameter_id,
           wp.wp, m.parameter_name_1 AS category, m.parameter_name_2 AS parameter_name,
           NULL AS performance, NULL AS design_item_1, NULL AS design_item_2,
           NULL AS design_item_3, u.unit, h.hierarchy
    FROM se_parameter m
    LEFT JOIN wp ON wp.id=m.wp_id
    LEFT JOIN units u ON u.id=m.unit_id
    LEFT JOIN hierarchy h ON h.id=m.hierarchy_id
    WHERE m.is_active=1
    UNION ALL
    SELECT 'R', m.id, wp.wp, NULL, NULL, m.performance,
           m.design_item_1, m.design_item_2, m.design_item_3, u.unit, h.hierarchy
    FROM r_parameter m
    LEFT JOIN wp ON wp.id=m.wp_id
    LEFT JOIN units u ON u.id=m.unit_id
    LEFT JOIN hierarchy h ON h.id=m.hierarchy_id
    WHERE m.is_active=1
), prospective_master AS (
    SELECT m.*, p.parameter_id AS planned_id,
           CASE WHEN m.parameter_type='SE' AND p.parameter_id IS NOT NULL THEN p.new_value ELSE m.parameter_name END AS final_parameter_name,
           CASE WHEN m.parameter_type='R' AND p.parameter_id IS NOT NULL THEN p.new_value ELSE m.design_item_3 END AS final_design_item_3
    FROM parameter_master m
    LEFT JOIN tmp_spdm_duplicate_suffix_plan p
      ON p.parameter_type=m.parameter_type AND p.parameter_id=m.parameter_id
), normalized AS (
    SELECT prospective_master.*,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(wp, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS wp_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(category, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS category_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(performance, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS performance_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(design_item_1, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS design_item_1_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(design_item_2, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS design_item_2_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(unit, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS unit_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(hierarchy, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS hierarchy_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(final_parameter_name, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS parameter_name_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(final_design_item_3, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS design_item_3_key
    FROM prospective_master
), signatures AS (
    SELECT normalized.*
    FROM normalized
)
, prospective_ranked AS (
    SELECT signatures.*,
           ROW_NUMBER() OVER (PARTITION BY parameter_type,wp_key,category_key,parameter_name_key,performance_key,design_item_1_key,design_item_2_key,design_item_3_key,unit_key,hierarchy_key ORDER BY (planned_id IS NOT NULL), parameter_id) AS collision_rank
    FROM signatures
)
SELECT parameter_type, parameter_id
FROM prospective_ranked
WHERE planned_id IS NOT NULL AND collision_rank > 1;

        SELECT COUNT(*) INTO v_collisions FROM tmp_spdm_suffix_collisions;
        IF v_collisions=0 THEN
            LEAVE resolve_collisions;
        END IF;
        SET v_rounds=v_rounds+1;
        IF v_rounds>65535 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cannot resolve suffixes within TEXT length limits.';
        END IF;
        -- Preserve untouched rows first; among planned collisions keep the smaller ID.
        UPDATE tmp_spdm_duplicate_suffix_plan p
        JOIN tmp_spdm_suffix_collisions c
          ON c.parameter_type=p.parameter_type AND c.parameter_id=p.parameter_id
        SET p.new_value=CONCAT(p.new_value,p_suffix), p.suffix_count=p.suffix_count+1;
    END LOOP;
    IF EXISTS (SELECT 1 FROM tmp_spdm_duplicate_suffix_plan WHERE OCTET_LENGTH(new_value)>65535) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A proposed name exceeds the target TEXT column length.';
    END IF;
    SELECT COUNT(*) INTO v_se FROM tmp_spdm_duplicate_suffix_plan WHERE parameter_type='SE';
    SELECT COUNT(*) INTO v_r FROM tmp_spdm_duplicate_suffix_plan WHERE parameter_type='R';
    SET SESSION group_concat_max_len = 1048576;
    SELECT GROUP_CONCAT(CONCAT(parameter_type, ':', parameter_id) ORDER BY parameter_type, parameter_id SEPARATOR ','),
           COALESCE(SUM(CHAR_LENGTH(CONCAT(parameter_type, ':', parameter_id))),0)+GREATEST(COUNT(*)-1,0)
    INTO v_ids, v_id_length FROM tmp_spdm_duplicate_suffix_plan;
    IF CHAR_LENGTH(COALESCE(v_ids,'')) <> v_id_length THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Confirmation ID list exceeds supported length.';
    END IF;
    SET v_expected = CONCAT('UPDATE_DUPLICATES ', DATABASE(), ' ', COALESCE(v_ids,''));
    SELECT DATABASE() AS database_name, @@hostname AS host,
           IF(p_execute, 'EXECUTE_REQUESTED', 'PREVIEW') AS mode,
           v_se AS planned_se_updates, v_r AS planned_r_updates,
           v_collisions AS proposed_duplicate_groups, v_expected AS expected_confirmation;
    SELECT * FROM tmp_spdm_duplicate_suffix_plan ORDER BY parameter_type, duplicate_group_id, parameter_id;
    IF NOT p_execute THEN
        ROLLBACK;
        SELECT 'PREVIEW_ONLY' AS status, 0 AS committed_updates;
        SET SESSION group_concat_max_len = v_group_concat_max_len;
        DROP TEMPORARY TABLE tmp_spdm_duplicate_suffix_plan;
        DROP TEMPORARY TABLE tmp_spdm_suffix_collisions;
        LEAVE main;
    END IF;
    IF v_se+v_r=0 THEN
        ROLLBACK;
        SELECT 'NO_CHANGES' AS status, 0 AS committed_updates;
        SET SESSION group_concat_max_len = v_group_concat_max_len;
        DROP TEMPORARY TABLE tmp_spdm_duplicate_suffix_plan;
        DROP TEMPORARY TABLE tmp_spdm_suffix_collisions;
        LEAVE main;
    END IF;
    IF p_confirmation IS NULL OR NOT (BINARY p_confirmation = BINARY v_expected) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Confirmation mismatch; no master data changed.';
    END IF;
    IF v_collisions>0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Suffix resolution did not produce a unique final state.';
    END IF;
    UPDATE se_parameter m JOIN tmp_spdm_duplicate_suffix_plan p
      ON p.parameter_type='SE' AND p.parameter_id=m.id
    SET m.parameter_name_2=p.new_value
    WHERE m.is_active=1 AND (BINARY m.parameter_name_2 <=> BINARY p.old_value);
    SET v_changed_se=ROW_COUNT();
    IF v_changed_se<>v_se THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unexpected SE update count; rolling back both master tables.';
    END IF;
    UPDATE r_parameter m JOIN tmp_spdm_duplicate_suffix_plan p
      ON p.parameter_type='R' AND p.parameter_id=m.id
    SET m.design_item_3=p.new_value
    WHERE m.is_active=1 AND (BINARY m.design_item_3 <=> BINARY p.old_value);
    SET v_changed_r=ROW_COUNT();
    IF v_changed_r<>v_r THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unexpected R update count; rolling back both master tables.';
    END IF;

WITH parameter_master AS (
    SELECT 'SE' AS parameter_type, m.id AS parameter_id,
           wp.wp, m.parameter_name_1 AS category, m.parameter_name_2 AS parameter_name,
           NULL AS performance, NULL AS design_item_1, NULL AS design_item_2,
           NULL AS design_item_3, u.unit, h.hierarchy
    FROM se_parameter m
    LEFT JOIN wp ON wp.id=m.wp_id
    LEFT JOIN units u ON u.id=m.unit_id
    LEFT JOIN hierarchy h ON h.id=m.hierarchy_id
    WHERE m.is_active=1
    UNION ALL
    SELECT 'R', m.id, wp.wp, NULL, NULL, m.performance,
           m.design_item_1, m.design_item_2, m.design_item_3, u.unit, h.hierarchy
    FROM r_parameter m
    LEFT JOIN wp ON wp.id=m.wp_id
    LEFT JOIN units u ON u.id=m.unit_id
    LEFT JOIN hierarchy h ON h.id=m.hierarchy_id
    WHERE m.is_active=1
), normalized AS (
    SELECT parameter_master.*,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(wp, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS wp_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(category, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS category_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(parameter_name, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS parameter_name_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(performance, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS performance_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(design_item_1, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS design_item_1_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(design_item_2, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS design_item_2_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(design_item_3, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS design_item_3_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(unit, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS unit_key,
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(hierarchy, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS hierarchy_key
    FROM parameter_master
), signatures AS (
    SELECT normalized.*
    FROM normalized
)
SELECT COUNT(*) INTO v_after_collisions
FROM (
    SELECT parameter_type,wp_key,category_key,parameter_name_key,performance_key,design_item_1_key,design_item_2_key,design_item_3_key,unit_key,hierarchy_key
    FROM signatures
    GROUP BY parameter_type,wp_key,category_key,parameter_name_key,performance_key,design_item_1_key,design_item_2_key,design_item_3_key,unit_key,hierarchy_key
    HAVING COUNT(*)>1
) remaining_duplicates;
    IF v_after_collisions>0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Post-update uniqueness verification failed; rolling back both masters.';
    END IF;
    COMMIT;
    SELECT 'COMMITTED' AS status, v_changed_se AS committed_se_updates, v_changed_r AS committed_r_updates;
    SET SESSION group_concat_max_len = v_group_concat_max_len;
    DROP TEMPORARY TABLE tmp_spdm_duplicate_suffix_plan;
        DROP TEMPORARY TABLE tmp_spdm_suffix_collisions;
END$$
DELIMITER ;

CALL spdm_apply_duplicate_parameter_suffix_20261119(@execute, @suffix_character, @confirmation);
DROP PROCEDURE spdm_apply_duplicate_parameter_suffix_20261119;
