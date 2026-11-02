WITH t AS ((SELECT pjf.id                 AS project_id,
                   pjf.project_code       AS project_code,
                   lt.lot                 AS lot,
                   archi.architecturename AS architecture_name,
                   dest.destination       AS destination,
                   dt.drivetrain          AS drivetrain,
                   bt.body_type           AS body_type,
                   ph.id                  AS phase_id,
                   ph.phase               AS phase,
                   map_structure.map_name COLLATE utf8mb4_0900_ai_ci AS map_name,
                   map_structure.value    AS map_value,
                   map_structure.overlay_template,
                   map_variable.axis,
                   map_structure.map_variable_id,
                   prp.se_parameter_id,
                   prp.variation_id,
                   variation.variation,
                   map_folder_url.url,
                   operational_state.status
            FROM project_info AS pjf
                     JOIN setup AS stp ON pjf.setup_id = stp.id
                     JOIN architecture AS archi ON stp.architecture_id = archi.id
                     JOIN destination AS dest ON dest.id = stp.destination_id
                     JOIN drivetrain AS dt ON stp.drivetrain_id = dt.id
                     JOIN lot AS lt ON pjf.lot_id = lt.id
                     JOIN body_type AS bt ON stp.body_type_id = bt.id
                     JOIN project_parameter prp ON prp.project_id = pjf.id
                     JOIN phase ph ON ph.id = prp.phase_id
                     LEFT JOIN operational_state
                               ON lt.id = operational_state.lot_id
                                   AND bt.id = operational_state.body_type_id
                                   AND ph.id = operational_state.phase_id
                                   AND pjf.id = operational_state.project_id
                                   AND archi.id = operational_state.architecture_id
                                   AND dest.id = operational_state.destination_id
                                   AND dt.id = operational_state.drivetrain_id
                     JOIN map_structure
                        ON prp.value COLLATE utf8mb4_0900_ai_ci
                         = map_structure.map_name COLLATE utf8mb4_0900_ai_ci
                     JOIN map_variable ON map_structure.map_variable_id = map_variable.id
                     LEFT JOIN map_folder_url
                               ON prp.project_id = map_folder_url.project_id
                                   AND prp.phase_id = map_folder_url.phase_id
                                   AND prp.se_parameter_id = map_folder_url.se_parameter_id
                     LEFT JOIN variation ON prp.variation_id = variation.id
            WHERE operational_state.status IS NULL
               OR operational_state.status != 'suspended')
           UNION ALL
           (SELECT pjf.id                 AS project_id,
                   pjf.project_code       AS project_code,
                   lt.lot                 AS lot,
                   archi.architecturename AS architecture_name,
                   dest.destination       AS destination,
                   dt.drivetrain          AS drivetrain,
                   bt.body_type           AS body_type,
                   ph.id                  AS phase_id,
                   ph.phase               AS phase,
                   prp.value COLLATE utf8mb4_0900_ai_ci AS map_name,
                   pmr.value              AS map_value,
                   NULL                   AS overlay_template,
                   map_variable.axis,
                   map_variable.id        AS map_variable_id,
                   prp.se_parameter_id,
                   prp.variation_id,
                   variation.variation,
                   map_folder_url.url,
                   operational_state.status
            FROM project_info AS pjf
                     JOIN setup AS stp ON pjf.setup_id = stp.id
                     JOIN architecture AS archi ON stp.architecture_id = archi.id
                     JOIN destination AS dest ON dest.id = stp.destination_id
                     JOIN drivetrain AS dt ON stp.drivetrain_id = dt.id
                     JOIN lot AS lt ON pjf.lot_id = lt.id
                     JOIN body_type AS bt ON stp.body_type_id = bt.id
                     JOIN project_parameter prp
                          ON prp.project_id = pjf.id
                              AND prp.value IS NOT NULL
                              AND prp.value <> ' '
                     JOIN phase ph ON ph.id = prp.phase_id
                     LEFT JOIN operational_state
                               ON lt.id = operational_state.lot_id
                                   AND bt.id = operational_state.body_type_id
                                   AND ph.id = operational_state.phase_id
                                   AND pjf.id = operational_state.project_id
                                   AND archi.id = operational_state.architecture_id
                                   AND dest.id = operational_state.destination_id
                                   AND dt.id = operational_state.drivetrain_id
                     JOIN parameter_map_relation pmr
                          ON pmr.project_id = prp.project_id
                              AND pmr.se_parameter_id = prp.se_parameter_id
                              AND pmr.phase_id = prp.phase_id
                              AND pmr.variation_id = prp.variation_id
                              AND pmr.value IS NOT NULL
                     JOIN map_variable ON pmr.map_variable_id = map_variable.id
                     LEFT JOIN map_folder_url
                               ON prp.project_id = map_folder_url.project_id
                                   AND prp.phase_id = map_folder_url.phase_id
                                   AND prp.se_parameter_id = map_folder_url.se_parameter_id
                     LEFT JOIN variation ON prp.variation_id = variation.id
            WHERE operational_state.status IS NULL
               OR operational_state.status != 'suspended')
           UNION ALL
           (SELECT pjf.id                 AS project_id,
                   pjf.project_code       AS project_code,
                   lt.lot                 AS lot,
                   archi.architecturename AS architecture_name,
                   dest.destination       AS destination,
                   dt.drivetrain          AS drivetrain,
                   bt.body_type           AS body_type,
                   ph.id                  AS phase_id,
                   ph.phase               AS phase,
                   map_structure.map_name COLLATE utf8mb4_0900_ai_ci AS map_name,
                   map_structure.value    AS map_value,
                   NULL                   AS overlay_template,
                   map_variable.axis,
                   map_structure.map_variable_id,
                   tpsp.senario_parameter_id AS se_parameter_id,
                   tpsp.variation_id,
                   variation.variation,
                   NULL                   AS url,
                   operational_state.status
            FROM project_info AS pjf
                     JOIN setup AS stp ON pjf.setup_id = stp.id
                     JOIN architecture AS archi ON stp.architecture_id = archi.id
                     JOIN destination AS dest ON dest.id = stp.destination_id
                     JOIN drivetrain AS dt ON stp.drivetrain_id = dt.id
                     JOIN lot AS lt ON pjf.lot_id = lt.id
                     JOIN body_type AS bt ON stp.body_type_id = bt.id
                     JOIN test_project_senario_parameter tpsp
                          ON tpsp.project_id = pjf.id
                              AND tpsp.updated_value IS NOT NULL
                              AND tpsp.updated_value <> ''
                     JOIN phase ph ON ph.id = tpsp.phase_id
                     LEFT JOIN operational_state
                                ON lt.id = operational_state.lot_id
                                    AND bt.id = operational_state.body_type_id
                                    AND ph.id = operational_state.phase_id
                                    AND pjf.id = operational_state.project_id
                                    AND archi.id = operational_state.architecture_id
                                    AND dest.id = operational_state.destination_id
                                    AND dt.id = operational_state.drivetrain_id
                     JOIN map_structure
                        ON (tpsp.updated_value COLLATE utf8mb4_0900_ai_ci = map_structure.map_name COLLATE utf8mb4_0900_ai_ci
                            OR REPLACE(tpsp.updated_value, 'Ver.', '') COLLATE utf8mb4_0900_ai_ci = map_structure.map_name COLLATE utf8mb4_0900_ai_ci)
                     JOIN map_variable ON map_structure.map_variable_id = map_variable.id
                     LEFT JOIN variation ON tpsp.variation_id = variation.id
            WHERE operational_state.status IS NULL
               OR operational_state.status != 'suspended'))
            SELECT DISTINCT project_id,
                            se_parameter_id,
                            phase_id,
                            variation_id,
                            variation,
                            project_code,
                            lot,
                            architecture_name,
                            destination,
                            drivetrain,
                            body_type,
                            phase,
                            CASE
                                WHEN TRIM(SUBSTRING_INDEX(REPLACE(map_name, 'Ver.', ''), '_', -1)) IN
                                     ('001', '002', '003', '004', '005', '006', '007', '008', '009', '010')
                                    THEN SUBSTRING(REPLACE(map_name, 'Ver.', ''), 1, CHAR_LENGTH(REPLACE(map_name, 'Ver.', '')) - 4)
                                ELSE map_name
                                END AS z_request_median,
                            CASE
                                WHEN TRIM(SUBSTRING_INDEX(REPLACE(map_name, 'Ver.', ''), '_', -1)) IN
                                     ('001', '002', '003', '004', '005', '006', '007', '008', '009', '010')
                                    THEN TRIM(SUBSTRING_INDEX(REPLACE(map_name, 'Ver.', ''), '_', -1))
                                ELSE NULL
                                END AS ver,
                            axis,
                            map_variable_id,
                            map_value,
                            overlay_template,
                            url
            FROM t
            WHERE (project_id, se_parameter_id, phase_id, variation_id) IN (SELECT DISTINCT project_id, se_parameter_id, phase_id, variation_id
                                      FROM t
                                      WHERE axis = 'MAP'
                                      );