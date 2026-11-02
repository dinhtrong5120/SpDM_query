DROP PROCEDURE IF EXISTS check_all_orphan_foreign_keys;

DELIMITER $$

CREATE PROCEDURE check_all_orphan_foreign_keys()
BEGIN
    DECLARE done INT DEFAULT 0;

    DECLARE v_constraint_name VARCHAR(255);
    DECLARE v_child_table VARCHAR(255);
    DECLARE v_child_column VARCHAR(255);
    DECLARE v_parent_table VARCHAR(255);
    DECLARE v_parent_column VARCHAR(255);

    DECLARE fk_cursor CURSOR FOR
        SELECT DISTINCT
            kcu.CONSTRAINT_NAME,
            kcu.TABLE_NAME,
            kcu.COLUMN_NAME,
            kcu.REFERENCED_TABLE_NAME,
            kcu.REFERENCED_COLUMN_NAME
        FROM information_schema.KEY_COLUMN_USAGE AS kcu
        WHERE kcu.TABLE_SCHEMA = DATABASE()
          AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
          AND kcu.REFERENCED_COLUMN_NAME IS NOT NULL
        ORDER BY
            kcu.TABLE_NAME,
            kcu.CONSTRAINT_NAME,
            kcu.COLUMN_NAME;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    DROP TEMPORARY TABLE IF EXISTS orphan_fk_result;

    CREATE TEMPORARY TABLE orphan_fk_result (
        id BIGINT NOT NULL AUTO_INCREMENT,
        constraint_name VARCHAR(255),
        child_table VARCHAR(255),
        child_column VARCHAR(255),
        parent_table VARCHAR(255),
        parent_column VARCHAR(255),
        orphan_rows BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
    );

    OPEN fk_cursor;

    read_loop: LOOP
        FETCH fk_cursor
        INTO
            v_constraint_name,
            v_child_table,
            v_child_column,
            v_parent_table,
            v_parent_column;

        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        SET @sql_check = CONCAT(
            'INSERT INTO orphan_fk_result (',
                'constraint_name, ',
                'child_table, ',
                'child_column, ',
                'parent_table, ',
                'parent_column, ',
                'orphan_rows',
            ') ',
            'SELECT ',
                QUOTE(v_constraint_name), ', ',
                QUOTE(v_child_table), ', ',
                QUOTE(v_child_column), ', ',
                QUOTE(v_parent_table), ', ',
                QUOTE(v_parent_column), ', ',
                'COUNT(*) ',
            'FROM `',
                REPLACE(v_child_table, '`', '``'),
            '` AS c ',
            'LEFT JOIN `',
                REPLACE(v_parent_table, '`', '``'),
            '` AS p ON c.`',
                REPLACE(v_child_column, '`', '``'),
            '` = p.`',
                REPLACE(v_parent_column, '`', '``'),
            '` ',
            'WHERE c.`',
                REPLACE(v_child_column, '`', '``'),
            '` IS NOT NULL ',
            'AND p.`',
                REPLACE(v_parent_column, '`', '``'),
            '` IS NULL'
        );

        PREPARE stmt FROM @sql_check;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;

    CLOSE fk_cursor;

    SELECT
        constraint_name,
        child_table,
        child_column,
        parent_table,
        parent_column,
        orphan_rows
    FROM orphan_fk_result
    WHERE orphan_rows > 0
    ORDER BY
        orphan_rows DESC,
        child_table,
        child_column;
END$$

DELIMITER ;

CALL check_all_orphan_foreign_keys();