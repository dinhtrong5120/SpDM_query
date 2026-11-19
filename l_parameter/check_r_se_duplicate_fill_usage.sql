-- Compare normalized fields directly (no concatenated/JSON key); NULL and empty strings are equivalent.
-- Includes blank/null parameter names; uniqueness covers ALL active masters.
-- MySQL 8.0+. READ ONLY: two independent SELECT queries, no schema/data writes.
-- Run Query 1 to export duplicate parameter IDs and fields.
-- Run Query 2 to export duplicate IDs plus project/phase usage.
-- SE and R are grouped separately, active parameters only.
-- Compare display units via units.unit, not se.parameter_unit / r.unit.
-- Comparison: SQL NULL becomes ''. Exported text: SQL NULL becomes '-'; empty strings stay empty.
-- NULL and empty strings are equivalent in duplicate comparison.
-- Nullable numeric export columns are text to support the literal '-'.
-- duplicate_count counts distinct master parameter IDs, NOT parameter/variation rows.
-- Scope: active master parameters linked to existing projects only.
-- Filter unused IDs BEFORE grouping; each duplicate group needs at least two used IDs.
-- hierarchy participates in both SE and R duplicate keys (NULL -> '', trim/lower).

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
      AND EXISTS (
          SELECT 1 FROM project_parameter p
          JOIN project_info pi ON pi.id=p.project_id
          WHERE p.se_parameter_id=m.id
      )
    UNION ALL
    SELECT 'R', m.id, wp.wp, NULL, NULL, m.performance,
           m.design_item_1, m.design_item_2, m.design_item_3, u.unit, h.hierarchy
    FROM r_parameter m
    LEFT JOIN wp ON wp.id=m.wp_id
    LEFT JOIN units u ON u.id=m.unit_id
    LEFT JOIN hierarchy h ON h.id=m.hierarchy_id
    WHERE m.is_active=1
      AND EXISTS (
          SELECT 1 FROM project_r_parameter p
          JOIN project_info pi ON pi.id=p.project_id
          WHERE p.r_parameter_id=m.id
      )
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
           COUNT(*) OVER (PARTITION BY parameter_type,wp_key,category_key,parameter_name_key,performance_key,design_item_1_key,design_item_2_key,design_item_3_key,unit_key,hierarchy_key) AS duplicate_count,
           MIN(parameter_id) OVER (PARTITION BY parameter_type,wp_key,category_key,parameter_name_key,performance_key,design_item_1_key,design_item_2_key,design_item_3_key,unit_key,hierarchy_key) AS duplicate_group_id
    FROM signatures
), duplicates AS (
    SELECT * FROM ranked WHERE duplicate_count>1
)
SELECT d.parameter_type, d.duplicate_group_id, d.duplicate_count, d.parameter_id,
       COALESCE(d.wp, '-') AS wp, COALESCE(d.category, '-') AS category, COALESCE(d.parameter_name, '-') AS parameter_name, COALESCE(d.performance, '-') AS performance,
       COALESCE(d.design_item_1, '-') AS design_item_1, COALESCE(d.design_item_2, '-') AS design_item_2, COALESCE(d.design_item_3, '-') AS design_item_3, COALESCE(d.unit, '-') AS unit, COALESCE(d.hierarchy, '-') AS hierarchy
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
      AND EXISTS (
          SELECT 1 FROM project_parameter p
          JOIN project_info pi ON pi.id=p.project_id
          WHERE p.se_parameter_id=m.id
      )
    UNION ALL
    SELECT 'R', m.id, wp.wp, NULL, NULL, m.performance,
           m.design_item_1, m.design_item_2, m.design_item_3, u.unit, h.hierarchy
    FROM r_parameter m
    LEFT JOIN wp ON wp.id=m.wp_id
    LEFT JOIN units u ON u.id=m.unit_id
    LEFT JOIN hierarchy h ON h.id=m.hierarchy_id
    WHERE m.is_active=1
      AND EXISTS (
          SELECT 1 FROM project_r_parameter p
          JOIN project_info pi ON pi.id=p.project_id
          WHERE p.r_parameter_id=m.id
      )
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
           COUNT(*) OVER (PARTITION BY parameter_type,wp_key,category_key,parameter_name_key,performance_key,design_item_1_key,design_item_2_key,design_item_3_key,unit_key,hierarchy_key) AS duplicate_count,
           MIN(parameter_id) OVER (PARTITION BY parameter_type,wp_key,category_key,parameter_name_key,performance_key,design_item_1_key,design_item_2_key,design_item_3_key,unit_key,hierarchy_key) AS duplicate_group_id
    FROM signatures
), duplicates AS (
    SELECT * FROM ranked WHERE duplicate_count>1
)
, usage_scopes AS (
    SELECT 'SE' AS parameter_type,p.se_parameter_id AS parameter_id,
           p.project_id,p.phase_id,COUNT(DISTINCT p.variation_id) AS variation_count
    FROM project_parameter p
    JOIN project_info pi ON pi.id=p.project_id
    GROUP BY p.se_parameter_id,p.project_id,p.phase_id
    UNION ALL
    SELECT 'R',p.r_parameter_id,p.project_id,p.phase_id,COUNT(DISTINCT p.variation_id)
    FROM project_r_parameter p
    JOIN project_info pi ON pi.id=p.project_id
    GROUP BY p.r_parameter_id,p.project_id,p.phase_id
)
SELECT d.parameter_type, d.duplicate_group_id, d.duplicate_count, d.parameter_id,
       COALESCE(d.wp, '-') AS wp, COALESCE(d.category, '-') AS category, COALESCE(d.parameter_name, '-') AS parameter_name, COALESCE(d.performance, '-') AS performance,
       COALESCE(d.design_item_1, '-') AS design_item_1, COALESCE(d.design_item_2, '-') AS design_item_2, COALESCE(d.design_item_3, '-') AS design_item_3, COALESCE(d.unit, '-') AS unit, COALESCE(d.hierarchy, '-') AS hierarchy,
       COALESCE(CAST(x.project_id AS CHAR), '-') AS project_id,COALESCE(pi.project_code, '-') AS project_code,COALESCE(dest.destination, '-') AS destination,COALESCE(dt.drivetrain, '-') AS drivetrain,
       COALESCE(a.architecturename, '-') AS powertrain,COALESCE(l.lot, '-') AS lot,COALESCE(bt.body_type, '-') AS body_type,
       COALESCE(CAST(x.phase_id AS CHAR), '-') AS phase_id,COALESCE(ph.phase, '-') AS phase,COALESCE(CAST(x.variation_count AS CHAR), '-') AS variation_count
FROM duplicates d
JOIN usage_scopes x ON x.parameter_type=d.parameter_type AND x.parameter_id=d.parameter_id
LEFT JOIN project_info pi ON pi.id=x.project_id
LEFT JOIN setup s ON s.id=pi.setup_id
LEFT JOIN destination dest ON dest.id=s.destination_id
LEFT JOIN drivetrain dt ON dt.id=s.drivetrain_id
LEFT JOIN architecture a ON a.id=s.architecture_id
LEFT JOIN lot l ON l.id=pi.lot_id
LEFT JOIN body_type bt ON bt.id=s.body_type_id
LEFT JOIN phase ph ON ph.id=x.phase_id
ORDER BY d.parameter_type,d.duplicate_group_id,d.parameter_id,x.project_id,x.phase_id;
