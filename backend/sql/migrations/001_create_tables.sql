-- ===========================================
-- Hans Dither Backend - Datenbank Migration 001
-- Erstellt die Tabellen für Nutzer und Images
-- ===========================================

-- Datenbank auswählen (wird durch deploy.sh mit --database Parameter gesetzt)
USE `hans_sync`;

-- ===========================================
-- Tabelle: users
-- Speichert die Verknüpfung zwischen Playdate-UID und PIN-Hash
-- ===========================================
CREATE TABLE IF NOT EXISTS `users` (
    `uid` VARCHAR(64) NOT NULL COMMENT 'Einzigartige Playdate-Geräte-ID',
    `pin_hash` VARCHAR(255) NOT NULL COMMENT 'bcrypt-Hash der 4-stelligen PIN',
    `failed_attempts` INT NOT NULL DEFAULT 0 COMMENT 'Zähler für Fehlversuche',
    `locked_until` DATETIME NULL COMMENT 'Zeitstempel, bis wann Account gesperrt ist',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Erstellungszeitpunkt',
    
    PRIMARY KEY (`uid`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Playdate Nutzer/Verknüpfungen';

-- ===========================================
-- Tabelle: images
-- Speichert Metadaten zu hochgeladenen Projekten
-- ===========================================
CREATE TABLE IF NOT EXISTS `images` (
    `id` VARCHAR(36) NOT NULL COMMENT 'UUID für eindeutige Identifikation',
    `uid` VARCHAR(64) NOT NULL COMMENT 'Verknüpfte Nutzer-UID',
    `pdi_path` VARCHAR(255) NOT NULL COMMENT 'Pfad zur PDI-Datei',
    `json_path` VARCHAR(255) NOT NULL COMMENT 'Pfad zur frames.json',
    `png_path` VARCHAR(255) NULL COMMENT 'Pfad zum gerenderten PNG (NULL wenn noch nicht generiert)',
    `gif_path` VARCHAR(255) NULL COMMENT 'Pfad zum gerenderten animierten GIF (NULL wenn noch nicht generiert)',
    `uploaded_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Upload-Zeitpunkt',
    
    PRIMARY KEY (`id`),
    INDEX `idx_uid` (`uid`),
    INDEX `idx_uploaded_at` (`uploaded_at`),
    FOREIGN KEY (`uid`) REFERENCES `users`(`uid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Hochgeladene Hans Dither Projekte';

-- ===========================================
-- Tabelle: sessions
-- Speichert aktive Session-Tokens
-- ===========================================
CREATE TABLE IF NOT EXISTS `sessions` (
    `token` VARCHAR(36) NOT NULL COMMENT 'Session-Token (UUID)',
    `uid` VARCHAR(64) NOT NULL COMMENT 'Verknüpfte Nutzer-UID',
    `expires_at` DATETIME NOT NULL COMMENT 'Ablaufzeitpunkt des Tokens',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Erstellungszeitpunkt',
    
    PRIMARY KEY (`token`),
    INDEX `idx_uid` (`uid`),
    INDEX `idx_expires_at` (`expires_at`),
    FOREIGN KEY (`uid`) REFERENCES `users`(`uid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Aktive Sessions';

-- ===========================================
-- Initialdaten (optional, für Tests)
-- ===========================================
-- INSERT INTO `users` (`uid`, `pin_hash`, `failed_attempts`, `locked_until`)
-- VALUES 
--     ('test-device-001', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 0, NULL);
-- ^^ Dies ist der bcrypt-Hash von "1234" - nur für lokale Tests!
