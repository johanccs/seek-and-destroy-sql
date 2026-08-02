-- A customer list that has grown a group of columns only business accounts ever
-- use. Named CustomerImport, not Customers, because the module asks you to model
-- Customers yourself. Tiny on purpose — this is about structure, not volume.
IF OBJECT_ID('CustomerImport') IS NOT NULL DROP TABLE CustomerImport;

CREATE TABLE CustomerImport (
    RowId           int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Name            nvarchar(100) NOT NULL,
    Email           nvarchar(200) NOT NULL,
    -- Only business accounts ever fill these in.
    VatNumber       nvarchar(20)  NULL,
    CompanyRegNo    nvarchar(30)  NULL,
    TaxCountryCode  char(2)       NULL,
    VatVerifiedOn   date          NULL
);
GO

INSERT INTO CustomerImport (Name, Email, VatNumber, CompanyRegNo, TaxCountryCode, VatVerifiedOn)
VALUES
    ('Thandi Mokoena',   'thandi@example.co.za',   NULL,         NULL,             NULL, NULL),
    ('Pieter van Wyk',   'pieter@example.co.za',   NULL,         NULL,             NULL, NULL),
    ('Ayanda Dlamini',   'ayanda@example.co.za',   NULL,         NULL,             NULL, NULL),
    ('Nadia Petersen',   'nadia@example.co.za',    NULL,         NULL,             NULL, NULL),
    ('Karoo Freight cc', 'accounts@karoo.example', '4310298765', '2019/123456/23', 'ZA', '2026-01-14'),
    ('Bokke Supplies',   'ap@bokke.example',       '4880114477', '2021/998877/07', 'ZA', '2026-02-02');
GO
