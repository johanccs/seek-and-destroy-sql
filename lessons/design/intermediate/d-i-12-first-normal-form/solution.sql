-- Both repeating groups become child tables. The numbered columns and the CSV
-- column are the same mistake, so they get the same fix.

IF OBJECT_ID('StudentPhone') IS NOT NULL DROP TABLE StudentPhone;
GO

CREATE TABLE StudentPhone (
    StudentId int          NOT NULL,
    Phone     nvarchar(30) NOT NULL,
    -- The key is the pair: one student may have many numbers, but not the same
    -- number twice. Phone1/Phone2/Phone3 could never express that.
    CONSTRAINT PK_StudentPhone PRIMARY KEY (StudentId, Phone)
);
GO

-- Unpivot the three columns. The WHERE drops the empty slots, which is the
-- other thing the old shape got wrong: a missing phone was a NULL taking up a
-- column rather than simply a row that does not exist.
INSERT INTO StudentPhone (StudentId, Phone)
SELECT DISTINCT StudentId, Phone
FROM (
    SELECT StudentId, Phone1 AS Phone FROM EnrolmentSheet
    UNION ALL SELECT StudentId, Phone2 FROM EnrolmentSheet
    UNION ALL SELECT StudentId, Phone3 FROM EnrolmentSheet
) AS Unpivoted
WHERE Phone IS NOT NULL;
GO

IF OBJECT_ID('StudentSkill') IS NOT NULL DROP TABLE StudentSkill;
GO

CREATE TABLE StudentSkill (
    StudentId int          NOT NULL,
    Skill     nvarchar(60) NOT NULL,
    CONSTRAINT PK_StudentSkill PRIMARY KEY (StudentId, Skill)
);
GO

-- STRING_SPLIT is how you undo a CSV column. That such a function is needed at
-- all is the argument against ever creating one.
INSERT INTO StudentSkill (StudentId, Skill)
SELECT DISTINCT e.StudentId, LTRIM(RTRIM(s.value))
FROM EnrolmentSheet AS e
CROSS APPLY STRING_SPLIT(e.Skills, ',') AS s
WHERE e.Skills IS NOT NULL AND LTRIM(RTRIM(s.value)) <> '';
GO

ALTER TABLE EnrolmentSheet DROP COLUMN Phone1;
ALTER TABLE EnrolmentSheet DROP COLUMN Phone2;
ALTER TABLE EnrolmentSheet DROP COLUMN Phone3;
ALTER TABLE EnrolmentSheet DROP COLUMN Skills;
GO
