select * from l_parameter
         left join units on l_parameter.unit_id = units.id
where design_item in ('Fric Map', 'Drivetrain_Transfer_Fric Map')
;