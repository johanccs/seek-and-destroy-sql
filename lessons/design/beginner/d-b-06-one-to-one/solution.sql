-- Customers holds what every customer has; CustomerTaxDetails holds the group
-- only business accounts have. CustomerId is BOTH the child's primary key and
-- its foreign key: that shared key is what makes this one-to-one, not one-to-many.

CREATE TABLE Customers (
    CustomerId int           NOT NULL IDENTITY(1,1),
    Name       nvarchar(100) NOT NULL,
    Email      nvarchar(200) NOT NULL,
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerId)
);

CREATE TABLE CustomerTaxDetails (
    CustomerId     int          NOT NULL,
    VatNumber      nvarchar(20) NOT NULL,
    CompanyRegNo   nvarchar(30) NOT NULL,
    TaxCountryCode char(2)      NOT NULL,
    VatVerifiedOn  date         NULL,
    CONSTRAINT PK_CustomerTaxDetails PRIMARY KEY (CustomerId)
);

ALTER TABLE CustomerTaxDetails ADD CONSTRAINT FK_CustomerTaxDetails_Customers
    FOREIGN KEY (CustomerId) REFERENCES Customers (CustomerId);

-- Move the import across: every row becomes a customer, and only the business
-- accounts get a tax record.
INSERT INTO Customers (Name, Email)
SELECT Name, Email FROM CustomerImport;

INSERT INTO CustomerTaxDetails (CustomerId, VatNumber, CompanyRegNo, TaxCountryCode, VatVerifiedOn)
SELECT c.CustomerId, i.VatNumber, i.CompanyRegNo, i.TaxCountryCode, i.VatVerifiedOn
FROM CustomerImport i
JOIN Customers c ON c.Email = i.Email
WHERE i.VatNumber IS NOT NULL;

-- Note what the new table can now say that the old columns could not: every one
-- of these is NOT NULL. A tax record either exists in full or does not exist.
