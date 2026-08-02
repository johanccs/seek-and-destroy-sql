-- Each column now says whether it can be unknown, and the required ones fill
-- themselves in rather than burdening every INSERT.

CREATE TABLE Signups (
    SignupId     int           NOT NULL IDENTITY(1,1),
    Email        nvarchar(200) NOT NULL,
    DisplayName  nvarchar(100) NULL,           -- genuinely optional
    Country      char(2)       NULL,           -- genuinely optional
    ReferralCode nvarchar(20)  NULL,           -- this is what NULL is for
    LoginCount   int           NOT NULL CONSTRAINT DF_Signups_LoginCount DEFAULT (0),
    CreatedOn    datetime2     NOT NULL CONSTRAINT DF_Signups_CreatedOn  DEFAULT (SYSUTCDATETIME()),
    IsActive     bit           NOT NULL CONSTRAINT DF_Signups_IsActive   DEFAULT (1),
    CONSTRAINT PK_Signups PRIMARY KEY (SignupId),
    CONSTRAINT UQ_Signups_Email UNIQUE (Email)
);

-- Moving the import across is where the four spellings of "unknown" get resolved
-- into one. NULLIF turns '' back into a real NULL; ISNULL supplies the defaults.
INSERT INTO Signups (Email, DisplayName, Country, ReferralCode, LoginCount, CreatedOn, IsActive)
SELECT
    Email,
    NULLIF(DisplayName, 'Unknown'),
    NULLIF(Country, ''),
    NULLIF(ReferralCode, ''),
    ISNULL(LoginCount, 0),
    ISNULL(CreatedOn, SYSUTCDATETIME()),
    ISNULL(IsActive, 1)
FROM SignupImport
WHERE Email IS NOT NULL;   -- the row with no email cannot be a signup at all

-- The question from the scenario, asked correctly this time:
--   SELECT COUNT(*) FROM Signups WHERE ReferralCode IS NULL;
-- and the one that silently returns 0 no matter what the data says:
--   SELECT COUNT(*) FROM Signups WHERE ReferralCode = NULL;
