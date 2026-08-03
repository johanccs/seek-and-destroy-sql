-- Module 2 needs a table the learner did NOT create, so the catalog views have
-- something to show besides their own work -- and so the two-part naming
-- demonstration has a second object to point at.
IF OBJECT_ID('SignupSource') IS NOT NULL DROP TABLE SignupSource;

CREATE TABLE SignupSource (
    SignupSourceId int          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Name           nvarchar(40) NOT NULL,
    IsPaid         bit          NOT NULL
);
GO

INSERT INTO SignupSource (Name, IsPaid) VALUES
    ('Organic search', 0),
    ('Referral',       0),
    ('Paid social',    1);
GO
