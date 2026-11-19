WITH bad_maps AS (
    SELECT _utf8mb4'【DCDC】Convert Effciency_240V_onpre_001' AS map_name
    UNION ALL SELECT _utf8mb4'【FR MOT】GB_Loss_001'
    UNION ALL SELECT _utf8mb4'【FR MOT】GB_Loss_onpre_002'
    UNION ALL SELECT _utf8mb4'【GEN】N-T第2象限_onpre_001'
    UNION ALL SELECT _utf8mb4'5secDCR(Cell)_Charge_onpre_001'
    UNION ALL SELECT _utf8mb4'aaa_002'
    UNION ALL SELECT _utf8mb4'aaa_onpre_002'
    UNION ALL SELECT _utf8mb4'ENG始動MAP_onpre_001'
    UNION ALL SELECT _utf8mb4'fe_001'
    UNION ALL SELECT _utf8mb4'fe_onpre_002'
    UNION ALL SELECT _utf8mb4'test_001'
)
SELECT
    bm.map_name,
    CASE
        WHEN pp.project_id IS NULL THEN 'Không có tham chiếu trong SE List'
        ELSE 'Có tham chiếu trong SE List'
    END AS reference_status,

    COUNT(pp.project_id) OVER (
        PARTITION BY bm.map_name
    ) AS total_se_list_references,

    pp.project_id,
    pi.project_code,
    pi.lot_id,
    lo.lot,
    pi.setup_id,

    pp.phase_id,
    ph.phase,

    pp.variation_id,
    va.variation,

    pp.se_parameter_id,
    se.parameter_name_1,
    se.parameter_name_2,
    se.is_active AS se_parameter_is_active,

    pp.value AS stored_map_name,
    pp.update_day

FROM bad_maps bm
LEFT JOIN project_parameter pp
    ON pp.value COLLATE utf8mb4_0900_as_cs
     = bm.map_name COLLATE utf8mb4_0900_as_cs
LEFT JOIN project_info pi
    ON pi.id = pp.project_id
LEFT JOIN lot lo
    ON lo.id = pi.lot_id
LEFT JOIN phase ph
    ON ph.id = pp.phase_id
LEFT JOIN variation va
    ON va.id = pp.variation_id
LEFT JOIN se_parameter se
    ON se.id = pp.se_parameter_id
ORDER BY
    bm.map_name,
    pi.project_code,
    pp.project_id,
    pp.phase_id,
    pp.variation_id,
    pp.se_parameter_id;