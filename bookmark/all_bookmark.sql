WITH bookmarks AS (
    SELECT
        employee_number AS username,
        bookmark_number,
        MAX(CASE WHEN category = 0 THEN value END) AS powertrain,
        MAX(CASE WHEN category = 1 THEN value END) AS project_code,
        MAX(CASE WHEN category = 2 THEN value END) AS destination_id,
        MAX(CASE WHEN category = 3 THEN value END) AS drivetrain_id,
        MAX(CASE WHEN category = 4 THEN value END) AS lot_id,
        MAX(CASE WHEN category = 5 THEN value END) AS phase_id
    FROM bookmark
    -- WHERE employee_number = 'admin'
    GROUP BY employee_number, bookmark_number
),
projects AS (
    SELECT
        pjf.id AS project_id,
        pjf.project_code,
        stp.destination_id,
        stp.drivetrain_id,
        pjf.lot_id,
        archi.architecturename AS powertrain,
        dest.destination,
        dt.drivetrain,
        bt.body_type,
        lt.lot,
        fam.family_code
    FROM project_info AS pjf
    JOIN setup AS stp
        ON stp.id = pjf.setup_id
    JOIN architecture AS archi
        ON archi.id = stp.architecture_id
    JOIN destination AS dest
        ON dest.id = stp.destination_id
    JOIN drivetrain AS dt
        ON dt.id = stp.drivetrain_id
    JOIN body_type AS bt
        ON bt.id = stp.body_type_id
    JOIN lot AS lt
        ON lt.id = pjf.lot_id
    LEFT JOIN family AS fam
        ON fam.id = pjf.family_id
)
SELECT
    b.username       AS `Username`,
    p.project_code   AS `Project`,
    p.destination    AS `Destination`,
    p.drivetrain     AS `Drivetrain`,
    p.powertrain     AS `Powertrain`,
    p.body_type      AS `Body type`,
    p.lot            AS `Lot`,
    ph.phase         AS `Phase`,
    p.family_code    AS `Family`
FROM bookmarks AS b
JOIN projects AS p
    ON p.project_code = b.project_code
   AND p.powertrain = b.powertrain
   AND CAST(p.destination_id AS CHAR) = b.destination_id
   AND CAST(p.drivetrain_id AS CHAR) = b.drivetrain_id
   AND CAST(p.lot_id AS CHAR) = b.lot_id
LEFT JOIN phase AS ph
    ON CAST(ph.id AS CHAR) = b.phase_id
ORDER BY b.username, b.bookmark_number, p.project_id;