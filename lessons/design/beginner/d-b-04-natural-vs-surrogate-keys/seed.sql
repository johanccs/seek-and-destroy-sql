-- A member list keyed on email address, which is a natural key that seemed
-- perfectly stable right up until someone changed theirs.
IF OBJECT_ID('MemberAudit') IS NOT NULL DROP TABLE MemberAudit;
IF OBJECT_ID('MemberImport') IS NOT NULL DROP TABLE MemberImport;

CREATE TABLE MemberImport (
    Email     nvarchar(200) NOT NULL PRIMARY KEY,   -- the natural key, doing double duty
    FullName  nvarchar(100) NOT NULL,
    JoinedOn  date          NOT NULL
);
GO

-- A second table that refers to members the only way it can: by email.
CREATE TABLE MemberAudit (
    AuditId      int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    MemberEmail  nvarchar(200) NOT NULL,
    Action       nvarchar(50)  NOT NULL,
    HappenedOn   date          NOT NULL
);
GO

INSERT INTO MemberImport (Email, FullName, JoinedOn)
VALUES
    ('thandi@example.co.za', 'Thandi Mokoena', '2024-04-11'),
    ('pieter@example.co.za', 'Pieter van Wyk', '2024-07-02'),
    ('ayanda@example.co.za', 'Ayanda Dlamini', '2025-01-19'),
    ('nadia@example.co.za',  'Nadia Petersen', '2025-06-30');
GO

INSERT INTO MemberAudit (MemberEmail, Action, HappenedOn)
VALUES
    ('thandi@example.co.za', 'renewed',        '2025-04-11'),
    ('thandi@example.co.za', 'changed-address','2025-09-02'),
    ('pieter@example.co.za', 'renewed',        '2025-07-02'),
    ('ayanda@example.co.za', 'renewed',        '2026-01-19');
GO
