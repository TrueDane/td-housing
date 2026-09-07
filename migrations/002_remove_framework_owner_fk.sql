SET @td_housing_owner_fk = (
    SELECT `CONSTRAINT_NAME`
    FROM `information_schema`.`KEY_COLUMN_USAGE`
    WHERE `TABLE_SCHEMA` = DATABASE()
        AND `TABLE_NAME` = 'properties'
        AND `COLUMN_NAME` = 'owner_citizenid'
        AND `REFERENCED_TABLE_NAME` = 'players'
    LIMIT 1
);

SET @td_housing_drop_owner_fk = IF(
    @td_housing_owner_fk IS NULL,
    'SELECT 1',
    CONCAT(
        'ALTER TABLE `properties` DROP FOREIGN KEY `',
        REPLACE(@td_housing_owner_fk, '`', '``'),
        '`'
    )
);

PREPARE td_housing_drop_owner_fk_stmt FROM @td_housing_drop_owner_fk;
EXECUTE td_housing_drop_owner_fk_stmt;
DEALLOCATE PREPARE td_housing_drop_owner_fk_stmt;

SET @td_housing_owner_fk = NULL;
SET @td_housing_drop_owner_fk = NULL;
