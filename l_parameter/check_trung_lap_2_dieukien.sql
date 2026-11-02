SELECT
    COALESCE(TRIM(lp.design_item), '') AS design_item,
    COALESCE(TRIM(u.unit), '') AS unit,
    COUNT(*) AS duplicate_count
FROM l_parameter lp
LEFT JOIN units u
    ON lp.unit_id = u.id
GROUP BY
    COALESCE(TRIM(lp.design_item), ''),
    COALESCE(TRIM(u.unit), '')
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;