CREATE TABLE EbeveynEgitimi (
    EgitimID INT PRIMARY KEY IDENTITY(1,1),
    Aciklama NVARCHAR(50)
);

CREATE TABLE YemekDurumu (
    YemekID INT PRIMARY KEY IDENTITY(1,1),
    Tip NVARCHAR(30)
);

CREATE TABLE HazirlikKursu (
    KursID INT PRIMARY KEY IDENTITY(1,1),
    Durum NVARCHAR(30)
);

CREATE TABLE Ogrenciler (
    OgrenciID INT PRIMARY KEY IDENTITY(1,1),
    Cinsiyet NVARCHAR(10),
    EtnikGrup NVARCHAR(20),
    EgitimID INT FOREIGN KEY REFERENCES EbeveynEgitimi(EgitimID),
    YemekID INT FOREIGN KEY REFERENCES YemekDurumu(YemekID),
    KursID INT FOREIGN KEY REFERENCES HazirlikKursu(KursID)
);

CREATE TABLE SinavSonuclari (
    SonucID INT PRIMARY KEY IDENTITY(1,1),
    OgrenciID INT FOREIGN KEY REFERENCES Ogrenciler(OgrenciID),
    Matematik INT CHECK (Matematik BETWEEN 0 AND 100),
    Okuma INT CHECK (Okuma BETWEEN 0 AND 100),
    Yazma INT CHECK (Yazma BETWEEN 0 AND 100)
);

-- 1. Ebeveyn eðitim türlerini ekle
INSERT INTO EbeveynEgitimi (Aciklama)
SELECT DISTINCT ["parental level of education"]
FROM StudentsPerformance;

-- 2. Yemek tiplerini ekle
INSERT INTO YemekDurumu (Tip)
SELECT DISTINCT ["lunch"]
FROM StudentsPerformance;

-- 3. Hazýrlýk kursu bilgilerini ekle
INSERT INTO HazirlikKursu (Durum)
SELECT DISTINCT ["test preparation course"]
FROM StudentsPerformance;

-- 4. Ogrenciler tablosunu StudentsPerformance verisinden doldur (ID’leri eþleþtirerek)
INSERT INTO Ogrenciler (Cinsiyet, EtnikGrup, EgitimID, YemekID, KursID)
SELECT
    ["gender"],
    ["race ethnicity"],
    (SELECT EgitimID FROM EbeveynEgitimi WHERE Aciklama = ["parental level of education"]),
    (SELECT YemekID FROM YemekDurumu WHERE Tip = ["lunch"]),
    (SELECT KursID FROM HazirlikKursu WHERE Durum = ["test preparation course"])
FROM StudentsPerformance;


-- 5. SinavSonuclari tablosunu Ogrenciler sýrasýna göre doldur
WITH OgrenciSirali AS (
    SELECT OgrenciID, ROW_NUMBER() OVER (ORDER BY OgrenciID) AS Sira
    FROM Ogrenciler
),
NotlarHazir AS (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Sira,
        TRY_CAST(REPLACE(["math score"], '"', '') AS INT) AS Matematik,
        TRY_CAST(REPLACE(["reading score"], '"', '') AS INT) AS Okuma,
        TRY_CAST(REPLACE(["writing score"], '"', '') AS INT) AS Yazma
    FROM StudentsPerformance
)
INSERT INTO SinavSonuclari (OgrenciID, Matematik, Okuma, Yazma)
SELECT 
    o.OgrenciID, 
    n.Matematik, 
    n.Okuma, 
    n.Yazma
FROM NotlarHazir n
JOIN OgrenciSirali o ON n.Sira = o.Sira
WHERE n.Matematik IS NOT NULL AND n.Okuma IS NOT NULL AND n.Yazma IS NOT NULL;


-- Örnek 1: Öðrenci Ekleme (INSERT)
SET IDENTITY_INSERT Ogrenciler ON;
INSERT INTO Ogrenciler (OgrenciID, Cinsiyet, EtnikGrup, EgitimID, YemekID, KursID)
VALUES (1001,'female', 'group B', 1, 1, 1);

SELECT * FROM Ogrenciler WHERE OgrenciID = 1001;

-- Örnek 2: Öðrenci Kurs Durumu Güncelleme (UPDATE)
UPDATE Ogrenciler
SET KursID = 2
WHERE OgrenciID = 1;

-- Örnek 3:  Bir öðrencinin sýnav kaydýný silme (DELETE)
DELETE FROM SinavSonuclari
WHERE OgrenciID = 1;

-- Örnek 4: Hazýrlýk Kursu Durumu (INSERT)
INSERT INTO HazirlikKursu (Durum)
VALUES ('none'), ('completed');


-- 1. En yüksek matematik notunu alan öðrenciyi getir
SELECT TOP 1 o.OgrenciID, ss.Matematik
FROM SinavSonuclari ss
JOIN Ogrenciler o ON ss.OgrenciID = o.OgrenciID
ORDER BY ss.Matematik DESC;

-- 2. Hazýrlýk kursuna katýlan öðrencilerin ortalama notlarý
SELECT 
    AVG(Matematik) AS OrtalamaMatematik, 
    AVG(Okuma) AS OrtalamaOkuma, 
    AVG(Yazma) AS OrtalamaYazma
FROM SinavSonuclari ss
JOIN Ogrenciler o ON ss.OgrenciID = o.OgrenciID
JOIN HazirlikKursu hk ON o.KursID = hk.KursID
WHERE REPLACE(hk.Durum, '"', '') = 'completed';


-- 3. Ebeveyn eðitim düzeyine göre ortalama baþarý puaný
SELECT 
    ee.Aciklama AS EbeveynEgitimi,
    AVG((ss.Matematik + ss.Okuma + ss.Yazma) / 3.0) AS OrtalamaBasari
FROM SinavSonuclari ss
JOIN Ogrenciler o ON ss.OgrenciID = o.OgrenciID
JOIN EbeveynEgitimi ee ON o.EgitimID = ee.EgitimID
GROUP BY ee.Aciklama;

-- 4. En düþük yazma notuna sahip öðrenciler
SELECT o.OgrenciID, ss.Yazma
FROM SinavSonuclari ss
JOIN Ogrenciler o ON ss.OgrenciID = o.OgrenciID
WHERE ss.Yazma = (SELECT MIN(Yazma) FROM SinavSonuclari);

-- 5. Kadýn öðrencilerin ortalama sýnav sonuçlarý
SELECT 
    AVG(Matematik) AS OrtMat,
    AVG(Okuma) AS OrtOku,
    AVG(Yazma) AS OrtYaz
FROM SinavSonuclari ss
JOIN Ogrenciler o ON ss.OgrenciID = o.OgrenciID
WHERE o.Cinsiyet = '"female"';

-- 6. Her öðrencinin toplam puaný ve baþarý durumu
SELECT 
    o.OgrenciID,
    ss.Matematik + ss.Okuma + ss.Yazma AS ToplamPuan,
    CASE 
        WHEN (ss.Matematik + ss.Okuma + ss.Yazma)/3.0 >= 60 THEN 'Baþarýlý'
        ELSE 'Baþarýsýz'
    END AS Durum
FROM SinavSonuclari ss
JOIN Ogrenciler o ON ss.OgrenciID = o.OgrenciID;

-- 7. Ücretsiz yemek alan öðrencilerin ortalama baþarý puaný
SELECT 
    AVG((ss.Matematik + ss.Okuma + ss.Yazma)/3.0) AS Ortalama
FROM SinavSonuclari ss
JOIN Ogrenciler o ON ss.OgrenciID = o.OgrenciID
JOIN YemekDurumu yd ON o.YemekID = yd.YemekID
WHERE yd.Tip = '"free/reduced"';

-- 8. Kursa katýlan erkek öðrenci sayýsý
SELECT COUNT(*) AS KatilanErkekSayisi
FROM Ogrenciler o
JOIN HazirlikKursu hk ON o.KursID = hk.KursID
WHERE o.Cinsiyet = '"male"' AND hk.Durum = '"completed"';

-- 9. Ortalama sýnav puaný en yüksek 3 öðrenciyi listele
SELECT TOP 3 
    o.OgrenciID,
    (ss.Matematik + ss.Okuma + ss.Yazma)/3.0 AS Ortalama
FROM SinavSonuclari ss
JOIN Ogrenciler o ON ss.OgrenciID = o.OgrenciID
ORDER BY Ortalama DESC;

-- 10. 80 üstü matematik puaný alan öðrenci sayýsý
SELECT COUNT(*) AS SeksenUstuOgrenciSayisi
FROM SinavSonuclari
WHERE Matematik > 80;


CREATE VIEW HazirlikBasariliOgrenciler AS
SELECT 
    o.Cinsiyet,
    o.EtnikGrup AS Grup,
    (ss.Matematik + ss.Okuma + ss.Yazma) / 3.0 AS OrtalamaPuan
FROM SinavSonuclari ss
JOIN Ogrenciler o ON ss.OgrenciID = o.OgrenciID
JOIN HazirlikKursu hk ON o.KursID = hk.KursID
WHERE LTRIM(RTRIM(LOWER(REPLACE(hk.Durum, '"', '')))) = 'completed';


DELIMITER //

CREATE PROCEDURE OgrenciFiltrele(IN min_ortalama FLOAT)
BEGIN
    SELECT 
        o.Cinsiyet AS Cinsiyet,
        o.EtnikGrup AS Grup,
        (s.Matematik + s.Okuma + s.Yazma) / 3.0 AS OrtalamaPuan
    FROM Ogrenciler o
    JOIN SinavSonuclari s ON o.OgrenciID = s.OgrenciID
    WHERE (s.Matematik + s.Okuma + s.Yazma) / 3.0 >= min_ortalama;
END //

DELIMITER ;


CREATE PROCEDURE OgrenciFiltrele
    @min_ortalama FLOAT
AS
BEGIN
    SELECT 
        o.Cinsiyet AS Cinsiyet,
        o.EtnikGrup AS Grup,
        (s.Matematik + s.Okuma + s.Yazma) / 3.0 AS OrtalamaPuan
    FROM Ogrenciler o
    INNER JOIN SinavSonuclari s ON o.OgrenciID = s.OgrenciID
    WHERE (s.Matematik + s.Okuma + s.Yazma) / 3.0 >= @min_ortalama;
END;

EXEC OgrenciFiltrele @min_ortalama = 85;

EXEC sp_helptext 'OgrenciFiltrele';


DROP PROCEDURE IF EXISTS OgrenciFiltrele;


IF OBJECT_ID('dbo.OgrenciFiltrele', 'P') IS NOT NULL
    DROP PROCEDURE dbo.OgrenciFiltrele;
GO

CREATE PROCEDURE dbo.OgrenciFiltrele
    @min_ortalama FLOAT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        o.Cinsiyet AS Cinsiyet,
        o.EtnikGrup AS Grup,
        CAST((s.Matematik + s.Okuma + s.Yazma) / 3.0 AS DECIMAL(5,2)) AS OrtalamaPuan
    FROM Ogrenciler o
    INNER JOIN SinavSonuclari s ON o.OgrenciID = s.OgrenciID
    WHERE (s.Matematik + s.Okuma + s.Yazma) / 3.0 >= @min_ortalama;
END;
GO

EXEC dbo.OgrenciFiltrele @min_ortalama = 85;