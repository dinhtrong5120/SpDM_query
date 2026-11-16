-- MySQL 8.0+. READ ONLY: two independent SELECT queries, no schema/data writes.
-- Run Query 1 to export duplicate parameter IDs and fields.
-- Run Query 2 to export duplicate IDs plus project/phase usage.
-- SE and R are grouped separately, active parameters only.
-- Compare display units via units.unit, not se.parameter_unit / r.unit.
-- duplicate_count counts distinct master parameter IDs, NOT parameter/variation rows.
-- Scope: all active master parameters, including unused master IDs.
-- hierarchy is display-only and is NOT part of the duplicate comparison key.

-- QUERY 1: DUPLICATE PARAMETERS
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
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(unit, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS unit_key
    FROM parameter_master
), signatures AS (
    SELECT normalized.*,
           CASE WHEN parameter_type='SE'
                THEN CONCAT_WS('___',wp_key,category_key,parameter_name_key,unit_key)
                ELSE CONCAT_WS('___',wp_key,performance_key,design_item_1_key,
                               design_item_2_key,design_item_3_key,unit_key)
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
)
SELECT d.parameter_type, d.duplicate_group_id, d.duplicate_count, d.parameter_id,
       d.wp, d.category, d.parameter_name, d.performance,
       d.design_item_1, d.design_item_2, d.design_item_3, d.unit, d.hierarchy
FROM duplicates d
ORDER BY d.parameter_type,d.duplicate_group_id,d.parameter_id;

-- QUERY 2: PROJECT/PHASE USAGE
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
           LOWER(REGEXP_REPLACE(CONVERT(COALESCE(unit, '') USING utf8mb4), '^[[:space:]]+|[[:space:]]+$', '')) COLLATE utf8mb4_0900_bin AS unit_key
    FROM parameter_master
), signatures AS (
    SELECT normalized.*,
           CASE WHEN parameter_type='SE'
                THEN CONCAT_WS('___',wp_key,category_key,parameter_name_key,unit_key)
                ELSE CONCAT_WS('___',wp_key,performance_key,design_item_1_key,
                               design_item_2_key,design_item_3_key,unit_key)
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
)
, usage_scopes AS (
    SELECT 'SE' AS parameter_type,p.se_parameter_id AS parameter_id,
           p.project_id,p.phase_id,COUNT(DISTINCT p.variation_id) AS variation_count
    FROM project_parameter p
    GROUP BY p.se_parameter_id,p.project_id,p.phase_id
    UNION ALL
    SELECT 'R',p.r_parameter_id,p.project_id,p.phase_id,COUNT(DISTINCT p.variation_id)
    FROM project_r_parameter p
    GROUP BY p.r_parameter_id,p.project_id,p.phase_id
)
SELECT d.parameter_type, d.duplicate_group_id, d.duplicate_count, d.parameter_id,
       d.wp, d.category, d.parameter_name, d.performance,
       d.design_item_1, d.design_item_2, d.design_item_3, d.unit, d.hierarchy,
       x.project_id,pi.project_code,dest.destination,dt.drivetrain,
       a.architecturename AS powertrain,l.lot,bt.body_type,
       x.phase_id,ph.phase,x.variation_count
FROM duplicates d
LEFT JOIN usage_scopes x ON x.parameter_type=d.parameter_type AND x.parameter_id=d.parameter_id
LEFT JOIN project_info pi ON pi.id=x.project_id
LEFT JOIN setup s ON s.id=pi.setup_id
LEFT JOIN destination dest ON dest.id=s.destination_id
LEFT JOIN drivetrain dt ON dt.id=s.drivetrain_id
LEFT JOIN architecture a ON a.id=s.architecture_id
LEFT JOIN lot l ON l.id=pi.lot_id
LEFT JOIN body_type bt ON bt.id=s.body_type_id
LEFT JOIN phase ph ON ph.id=x.phase_id
ORDER BY d.parameter_type,d.duplicate_group_id,d.parameter_id,x.project_id,x.phase_id;
