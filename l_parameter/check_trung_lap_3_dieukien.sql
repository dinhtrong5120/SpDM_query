SELECT
    COALESCE(TRIM(lp.design_item), '') AS design_item,
    COALESCE(TRIM(u.unit), '') AS unit,
    COALESCE(TRIM(w.wp), '') AS wp,
    COUNT(*) AS duplicate_count
FROM l_parameter lp
LEFT JOIN units u
    ON lp.unit_id = u.id
LEFT JOIN wp w
    ON lp.wp_id = w.id
GROUP BY
    COALESCE(TRIM(lp.design_item), ''),
    COALESCE(TRIM(u.unit), ''),
    COALESCE(TRIM(w.wp), '')
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;