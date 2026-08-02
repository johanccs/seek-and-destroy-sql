-- The answer is not "surrogate instead of natural". It is both, doing different
-- jobs: a stable identifier to point at, and an enforced business rule.

CREATE TABLE Members (
    MemberId int           NOT NULL IDENTITY(1,1),
    Email    nvarchar(200) NOT NULL,
    FullName nvarchar(100) NOT NULL,
    JoinedOn date          NOT NULL,
    -- The surrogate: meaningless, and therefore never needs to change.
    CONSTRAINT PK_Members PRIMARY KEY (MemberId),
    -- The natural key is still a rule. It just is not the identifier.
    CONSTRAINT UQ_Members_Email UNIQUE (Email)
);

CREATE TABLE MemberActions (
    ActionId   int          NOT NULL IDENTITY(1,1),
    MemberId   int          NOT NULL,
    Action     nvarchar(50) NOT NULL,
    HappenedOn date         NOT NULL,
    CONSTRAINT PK_MemberActions PRIMARY KEY (ActionId)
);

ALTER TABLE MemberActions ADD CONSTRAINT FK_MemberActions_Members
    FOREIGN KEY (MemberId) REFERENCES Members (MemberId);

CREATE INDEX IX_MemberActions_MemberId ON MemberActions (MemberId);

-- Move the data across, resolving each audit row's email to a member id once.
INSERT INTO Members (Email, FullName, JoinedOn)
SELECT Email, FullName, JoinedOn FROM MemberImport;

INSERT INTO MemberActions (MemberId, Action, HappenedOn)
SELECT m.MemberId, a.Action, a.HappenedOn
FROM MemberAudit a
JOIN Members m ON m.Email = a.MemberEmail;

-- The whole point, in one statement. Thandi changes her email address:
--   UPDATE Members SET Email = 'thandi.m@example.co.za' WHERE MemberId = 1;
-- Her two audit rows still point at her, because they never referred to her
-- email in the first place. Under the old design this update either broke the
-- link or had to cascade through every table that had copied the address.
