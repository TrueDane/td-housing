ALTER TABLE `properties`
    ADD COLUMN IF NOT EXISTS `access_data` JSON NULL DEFAULT (JSON_ARRAY()) AFTER `has_access`,
    ADD COLUMN IF NOT EXISTS `furniture_mode` VARCHAR(16) NOT NULL DEFAULT 'player' AFTER `furnitures`,
    ADD COLUMN IF NOT EXISTS `storage_data` JSON NULL DEFAULT NULL AFTER `furniture_mode`,
    ADD COLUMN IF NOT EXISTS `wardrobe_data` JSON NULL DEFAULT NULL AFTER `storage_data`,
    ADD COLUMN IF NOT EXISTS `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- Existing `has_access` values are intentionally retained. Runtime normalization
-- treats legacy entries as `guest` access until they are explicitly promoted to
-- `resident` through the TD-Housing access API.
