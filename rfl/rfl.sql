SELECT
    p.*,
    r.requirement_s_id AS r_setup_id,
    rp.id              AS r_parameter_id,
    rp.design_item_1   AS r_item_1,
    rp.design_item_2   AS r_item_2,
    rp.design_item_3   AS r_item_3,
    ruc.usecase        AS r_usecase,

    rp.wp_id           AS r_wp_id,
    rw.wp              AS r_wp,
    rp.hierarchy_id    AS r_hierarchy_id,
    rh.hierarchy       AS r_hierarchy,

    r.function_id      AS f_parameter_id,
    fp.design_item     AS f_item,

    r.logic_s_id       AS l_setup_id,
    lp.id              AS l_parameter_id,
    lp.design_item     AS l_item,
    luc.usecase        AS l_usecase
FROM prj_rfl AS p
LEFT JOIN rfl AS r
    ON r.id = p.rfl_id
LEFT JOIN setup_r_relation AS sr
    ON sr.id = r.requirement_s_id
LEFT JOIN r_parameter AS rp
    ON rp.id = sr.r_parameter_id
LEFT JOIN wp AS rw
    ON rw.id = rp.wp_id
LEFT JOIN hierarchy AS rh
    ON rh.id = rp.hierarchy_id
LEFT JOIN usecase AS ruc
    ON ruc.id = sr.usecase_id
LEFT JOIN f_parameter AS fp
    ON fp.id = r.function_id
LEFT JOIN setup_l_relation AS sl
    ON sl.id = r.logic_s_id
LEFT JOIN l_parameter AS lp
    ON lp.id = sl.l_parameter_id
LEFT JOIN usecase AS luc
    ON luc.id = sl.usecase_id
WHERE p.project_info_id = 1000
  AND p.phase_id = 36
ORDER BY p.rfl_id;


SELECT
    lr.*,
    lp.id           AS l_parameter_id,
    lp.design_item  AS l_item,
    luc.usecase     AS l_usecase,

    rp.id           AS r_parameter_id,
    rp.design_item_1 AS r_item_1,
    rp.design_item_2 AS r_item_2,
    rp.design_item_3 AS r_item_3,
    ruc.usecase     AS r_usecase
FROM l_r_relation AS lr
LEFT JOIN setup_l_relation AS sl
    ON sl.id = lr.l_s_id
LEFT JOIN l_parameter AS lp
    ON lp.id = sl.l_parameter_id
LEFT JOIN usecase AS luc
    ON luc.id = sl.usecase_id
LEFT JOIN setup_r_relation AS sr
    ON sr.id = lr.r_s_id
LEFT JOIN r_parameter AS rp
    ON rp.id = sr.r_parameter_id
LEFT JOIN usecase AS ruc
    ON ruc.id = sr.usecase_id
WHERE EXISTS (
    SELECT 1
    FROM prj_rfl AS p
    INNER JOIN rfl AS r
        ON r.id = p.rfl_id
    WHERE p.project_info_id = 1000
      AND p.phase_id = 36
      AND r.logic_s_id = lr.l_s_id
)
ORDER BY lr.l_s_id, lr.r_s_id, lr.id;