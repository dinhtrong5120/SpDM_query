-- MySQL 8.0+. READ ONLY: one SELECT, no data/schema writes.
-- Source: QUERY 3 in check_r_se_duplicate_fill_null_with_selist_rlist_rfl_scenario_usage.sql.
-- Return active duplicate parameter IDs unused in ALL applicable usage categories:
-- R: project R-list + project RFL (Requirement/Allocation) + Scenario Master.
-- SE: project SE-list + project RFL (via Logic) + Scenario Master.
-- The irrelevant SE-list/R-list flag remains N/A; it does not exclude that parameter type.
-- Usage is global for the exact ID across projects/phases/variations.
-- Project usages require an existing project_info link; Scenario includes inactive rows.
-- Duplicate grouping is computed BEFORE the unused filter. A used peer may be hidden.
-- duplicate_count/group_id describe the full active group, not just the returned unused IDs.
-- Duplicate comparison includes hierarchy, as in the updated source QUERY 3:
-- comparison treats NULL and empty alike; output shows NULL as 'null', preserves empty strings.
-- hierarchy participates in SE/R duplicate keys; units come from units.unit via unit_id.
-- NO flags do NOT prove safe deletion: other master/history/reference tables are not checked.

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
    SELECT normalized.*,
           CASE WHEN parameter_type='SE'
                THEN CONCAT_WS('___',wp_key,category_key,parameter_name_key,unit_key,hierarchy_key)
                ELSE CONCAT_WS('___',wp_key,performance_key,design_item_1_key,
                               design_item_2_key,design_item_3_key,unit_key,hierarchy_key)
           END COLLATE utf8mb4_0900_bin AS duplicate_key
    FROM normalized
    WHERE (parameter_type='SE' AND parameter_name_key<>'')
       OR (parameter_type='R' AND (performance_key<>'' OR design_item_1_key<>''
                                  OR design_item_2_key<>'' OR design_item_3_key<>''))
), ranked AS (
    SELECT signatures.*,
           COUNT(*) OVER (PARTITION BY parameter_type,duplicate_key) AS duplicate_count,
           MIN(parameter_id) OVER (PARTITION BY parameter_type,duplicate_key) AS duplicate_group_id
    FROM signatures
), duplicates AS (
    SELECT * FROM ranked WHERE duplicate_count>1
), parameter_usage AS (
SELECT d.parameter_type, d.duplicate_group_id, d.duplicate_count, d.parameter_id,
       COALESCE(d.wp, 'null') AS wp, COALESCE(d.category, 'null') AS category, COALESCE(d.parameter_name, 'null') AS parameter_name, COALESCE(d.performance, 'null') AS performance,
       COALESCE(d.design_item_1, 'null') AS design_item_1, COALESCE(d.design_item_2, 'null') AS design_item_2, COALESCE(d.design_item_3, 'null') AS design_item_3, COALESCE(d.unit, 'null') AS unit, COALESCE(d.hierarchy, 'null') AS hierarchy,
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
)
SELECT *
FROM parameter_usage
WHERE is_used_in_project_rfl = 'NO'
  AND is_used_in_scenario_master = 'NO'
  AND (
      (parameter_type = 'R' AND is_used_in_project_rlist = 'NO')
      OR (parameter_type = 'SE' AND is_used_in_project_selist = 'NO')
  )
ORDER BY parameter_type, duplicate_group_id, parameter_id;
