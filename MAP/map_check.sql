WITH axis_rows AS (
    SELECT
        ms.map_name,
        ms.map_variable_id,
        mv.variable_name,
        mv.axis,
        -- So sánh đúng chữ hoa/thường như backend Python.
        CAST(mv.axis AS BINARY) AS axis_key,
        mv.id IS NULL AS is_orphan
    FROM map_structure ms
    LEFT JOIN map_variable mv ON mv.id = ms.map_variable_id
),
counts AS (
    SELECT
        map_name,
        COUNT(*) AS total_rows,
        SUM(COALESCE(axis_key = 'X', 0)) AS nx,
        SUM(COALESCE(axis_key = 'Y', 0)) AS ny,
        SUM(COALESCE(axis_key = 'Z', 0)) AS nz,
        SUM(COALESCE(axis_key = 'TABLE', 0)) AS nt,
        SUM(COALESCE(axis_key = 'MAP', 0)) AS nm,
        SUM(COALESCE(axis_key = 'CUBE', 0)) AS nc,
        SUM(COALESCE(axis_key = 'OVERLAY_1D', 0)) AS noverlay,
        SUM(is_orphan) AS orphan_count,
        SUM(
            CASE
                WHEN is_orphan = 0
                 AND (
                     axis_key IS NULL
                     OR axis_key NOT IN (
                         'X', 'Y', 'Z', 'TABLE', 'MAP',
                         'CUBE', 'OVERLAY_1D'
                     )
                 )
                THEN 1 ELSE 0
            END
        ) AS invalid_axis_count,
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'map_variable_id', map_variable_id,
                'variable_name', variable_name,
                'axis', axis,
                'orphan', is_orphan
            )
        ) AS variable_details
    FROM axis_rows
    GROUP BY map_name
),
classified AS (
    SELECT
        counts.*,
        -- Suy ra loại từ trục dữ liệu; nhiều loại cùng xuất hiện
        -- thì không tự chọn một loại làm chuẩn.
        CASE
            WHEN (nt > 0) + (nm > 0) + (nc > 0) + (noverlay > 0) > 1
                THEN 'MIXED'
            WHEN nc > 0 THEN 'CUBE'
            WHEN nm > 0 THEN 'MAP'
            WHEN nt > 0 THEN 'TABLE'
            WHEN noverlay > 0 THEN 'OVERLAY_1D'
            ELSE 'UNKNOWN'
        END AS inferred_mode
    FROM counts
),
diagnosed AS (
    SELECT
        classified.*,
        CONCAT_WS(
            '; ',
            IF(nx = 0, 'Thiếu X', NULL),
            IF((nm > 0 OR nc > 0) AND ny = 0, 'Thiếu Y', NULL),
            IF(nc > 0 AND nz = 0, 'Thiếu Z', NULL),

            IF(nx > 1, CONCAT('Thừa/trùng X: ', nx, ' dòng'), NULL),
            IF(ny > 1, CONCAT('Thừa/trùng Y: ', ny, ' dòng'), NULL),
            IF(nz > 1, CONCAT('Thừa/trùng Z: ', nz, ' dòng'), NULL),
            IF(nm > 1, CONCAT('Thừa/trùng MAP: ', nm, ' dòng'), NULL),
            IF(nc > 1, CONCAT('Thừa/trùng CUBE: ', nc, ' dòng'), NULL),
            IF(
                noverlay > 1,
                CONCAT('Thừa/trùng OVERLAY_1D: ', noverlay, ' dòng'),
                NULL
            ),

            IF(
                inferred_mode IN ('TABLE', 'OVERLAY_1D') AND ny > 0,
                'Thừa Y so với loại suy ra', NULL
            ),
            IF(
                inferred_mode IN ('TABLE', 'MAP', 'OVERLAY_1D') AND nz > 0,
                'Thừa Z so với loại suy ra', NULL
            ),

            IF(
                inferred_mode = 'MIXED',
                'Lẫn nhiều loại TABLE/MAP/CUBE/OVERLAY_1D',
                NULL
            ),
            IF(
                inferred_mode = 'UNKNOWN',
                'Thiếu trục dữ liệu TABLE/MAP/CUBE/OVERLAY_1D; chưa xác định được loại',
                NULL
            ),
            IF(
                orphan_count > 0,
                CONCAT(
                    'Có ', orphan_count,
                    ' dòng tham chiếu map_variable không tồn tại'
                ),
                NULL
            ),
            IF(
                invalid_axis_count > 0,
                CONCAT(
                    'Có ', invalid_axis_count,
                    ' dòng axis NULL hoặc ngoài danh sách hợp lệ'
                ),
                NULL
            )
        ) AS issues
    FROM classified
)
SELECT
    map_name,
    inferred_mode,
    issues,
    total_rows,
    nx AS x_count,
    ny AS y_count,
    nz AS z_count,
    nt AS table_count,
    nm AS map_count,
    nc AS cube_count,
    noverlay AS overlay_count,
    variable_details
FROM diagnosed
WHERE issues <> ''
ORDER BY map_name;