UPDATE project_parameter AS pp
JOIN se_parameter AS sp
    ON sp.id = pp.se_parameter_id
SET pp.value = CONCAT(
    LEFT(pp.value, CHAR_LENGTH(pp.value) - 8),
    '_',
    RIGHT(pp.value, 3)
)
WHERE LOWER(TRIM(sp.parameter_unit)) = 'map'
  AND pp.value REGEXP '_Ver[.][0-9]{3}$';