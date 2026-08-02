-- A signup table where "we don't know" has been spelled four different ways,
-- because every column is nullable and nothing has a default.
IF OBJECT_ID('SignupImport') IS NOT NULL DROP TABLE SignupImport;

CREATE TABLE SignupImport (
    RowId        int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Email        nvarchar(200) NULL,
    DisplayName  nvarchar(100) NULL,
    Country      char(2)       NULL,
    -- "unknown" appears here as NULL, as '', and as 0
    ReferralCode nvarchar(20)  NULL,
    LoginCount   int           NULL,
    CreatedOn    datetime2     NULL,
    IsActive     bit           NULL
);
GO

INSERT INTO SignupImport (Email, DisplayName, Country, ReferralCode, LoginCount, CreatedOn, IsActive)
VALUES
    ('thandi@example.co.za', 'Thandi',  'ZA', 'SPRING24', 14,   '2026-01-04', 1),
    ('pieter@example.co.za', 'Pieter',  'ZA', '',        0,    '2026-01-19', 1),
    ('ayanda@example.co.za', NULL,      NULL, NULL,      NULL, NULL,         NULL),
    ('nadia@example.co.za',  'Nadia',   'ZA', NULL,      3,    '2026-02-02', 0),
    (NULL,                   'Unknown', '',   'SPRING24', NULL, '2026-02-11', NULL);
GO
