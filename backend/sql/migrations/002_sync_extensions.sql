-- ===========================================
-- Hans Dither Backend - Datenbank Migration 002
-- Additive Erweiterungen für Spec 004 (Playdate-Sync):
--   1. client_image_id für Update-in-place bei Re-Sync (research.md R9)
--   2. confirmed_at für Re-Pairing bei falsch übertragener PIN (research.md R12)
-- ===========================================

USE `hans_sync`;

ALTER TABLE `images`
    ADD COLUMN `client_image_id` VARCHAR(64) NULL COMMENT 'Lokale, stabile Bild-ID vom Playdate (sanitizeName-Format)' AFTER `uid`,
    ADD UNIQUE KEY `uniq_uid_client_image_id` (`uid`, `client_image_id`);

ALTER TABLE `users`
    ADD COLUMN `confirmed_at` DATETIME NULL COMMENT 'Zeitpunkt des ersten erfolgreichen Logins (device-PIN == website-PIN bestätigt). NULL = unbestätigte Verknüpfung, darf per /pair überschrieben werden.' AFTER `locked_until`;
