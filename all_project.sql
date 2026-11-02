SELECT DISTINCT pjf.id                    AS project_id,
                pjf.setup_id,
                pjf.project_code          AS project_code,
                lt.lot                    AS lot,
                archi.architecturename    AS architecture_name,
                dest.destination          AS destination,
                dt.drivetrain             AS drivetrain,
                bt.body_type              AS body_type,
                ph.id                     AS phase_id,
                ph.phase                  AS phase,
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
         LEFT JOIN operational_state ON lt.id = operational_state.lot_id and bt.id = operational_state.body_type_id and
                                        ph.id = operational_state.phase_id and pjf.id = operational_state.project_id and
                                        archi.id = operational_state.architecture_id and
                                        dest.id = operational_state.destination_id and
                                        dt.id = operational_state.drivetrain_id
WHERE
    (operational_state.status IS NULL
   OR operational_state.status != 'suspended')
ORDER BY pjf.id DESC, phase_id;