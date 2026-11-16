UPDATE se_parameter
SET parameter_name_2 = CASE id
    WHEN 783 THEN 'ACC_Performance_Vmax_'
    WHEN 818 THEN 'A0_OBD_'
    WHEN 819 THEN 'A1_OBD_'
    WHEN 820 THEN 'A2_OBD_'
    WHEN 1451 THEN '性能保証電圧_下限_0.5秒_'
    WHEN 1159 THEN '許容トルク_'
    WHEN 1449 THEN '性能保証電圧_下限_5秒_'
    WHEN 1450 THEN '性能保証電圧_下限_2秒_'
END
WHERE id IN (783, 818, 819, 820, 1451,1159,1449,1450);