-----------------------------------------------------------------------------
---------------------------Crear Base de Datos-------------------------------
-----------------------------------------------------------------------------

use master
go

-- creación de la base de datos de ventas
-- verificar existencia, si bd existe entonces borrar
if exists (select * from sysdatabases where name = 'BDCovid_Peru')
begin
	drop database BDCovid_Peru
end
go

-- Crear bdVentas
create database BDCovid_Peru
on
	(
	NAME = BDCovid_Peru,					-- archivo primario
	FILENAME = 'D:\Data\BDCovid_Peru.mdf',		-- nombre del archivo
	SIZE = 5MB,								-- tamaño inicial
	FILEGROWTH = 2MB						-- factor de crecimiento
	)
	LOG ON
	(
	NAME = BDCovid_Peru_Log,
	FILENAME = 'D:\Data\BDCovid_Peru.ldf',
	SIZE = 2MB,
	FILEGROWTH = 1MB
	)
go

-- Creación de las tablas
use BDCovid_Peru
go

-- Crear tipos de datos
create type tyUUID from varchar (32) not null
go
create type tyUBIGEO from int not null
go
create type tyEdad from int not null
go
create type tySexo from varchar (10) not null
go
create type tyFecha from date not null
go


-- tablas con solo codigos primarios
create table TUbigeo
(	-- Lista de atributos
	UBIGEO tyUBIGEO,
	DISTRITO varchar (50),
	PROVINCIA varchar (50),
	DEPARTAMENTO varchar (50) not null,
	POBLACION int,
	SUPERFICIE varchar (20),
	-- Determinar las claves
	primary key (UBIGEO)
)
go

-- tablas con codigos foraneos
-- drop table TResultado_Positivo
create table TPositivo
(	-- Lista de atributos
	UUID tyUUID,
	UBIGEO tyUBIGEO,
	FECHA_CORTE date not null,
	FECHA_RESULTADO date not null,
	METODOX varchar (10) not null,
	-- Determinar las claves
	primary key (UUID),
	foreign key (UBIGEO) references TUbigeo
)
go

create table TFallecido
(	-- Lista de atributos
	UUID tyUUID,
	UBIGEO tyUBIGEO,
	FECHA_CORTE date not null,
	FECHA_FALLECIMIENTO date not null,
	-- Determinar las claves
	primary key (UUID),
	foreign key (UBIGEO) references TUbigeo
)
go

create table TPersona_Positivo
(	-- Lista de atributos
	UUID tyUUID,
	EDAD int,
	SEXO varchar (10) not null,
	-- Determinar las claves
	primary key (UUID),
	foreign key (UUID) references TPositivo,
)
go

create table TPersona_Fallecido
(	-- Lista de atributos
	UUID tyUUID,
	EDAD_DECLARADA int,
	SEXO varchar (10) not null,
	FECHA_NAC date,
	-- Determinar las claves
	primary key (UUID),
	foreign key (UUID) references TFallecido,
)
go

-----------------------------------------------------------------------------
-------------------------------Migrar datos----------------------------------
-----------------------------------------------------------------------------

USE BDCovid_Peru
go

-- Tabla temporal para guardar datos ubigeo
DROP TABLE IF EXISTS dbo.#TempUbigeo
go
CREATE TABLE #TempUbigeo
(	-- Lista de atributos
	UBIGEO	int not null,
	DISTRITO varchar (50) not null,
	PROVINCIA varchar (50) not null,
	DEPARTAMENTO varchar (50) not null,
	POBLACION int not null,
	SUPERFICIE varchar (20),
	Y varchar (20) not null,
	X varchar (20) not null
)
go
BULK INSERT #TempUbigeo
   FROM 'C:\Users\jhno\Desktop\geodir-ubigeo-inei.csv'
   WITH
	(	CODEPAGE = 'ACP'
		,FIRSTROW=2
		,FIELDTERMINATOR = ';'
		,ROWTERMINATOR = '\n' 
      );
go
--- Insertar datos en tabla TUbigeo
delete from TUbigeo
insert into TUbigeo
select UBIGEO, DISTRITO, PROVINCIA, DEPARTAMENTO, POBLACION, SUPERFICIE
	from #TempUbigeo

--- Insertar codigo y departamentos ej: (1 - Amazonas)
DROP TABLE IF EXISTS dbo.#TempUbigeo2
go
CREATE TABLE #TempUbigeo2
(	-- Lista de atributos
	UBIGEO	int not null,
	DEPARTAMENTO varchar (50) not null
)
go
insert into #TempUbigeo2 values ('1','Amazonas')
insert into #TempUbigeo2 values ('2','Ancash')
insert into #TempUbigeo2 values ('3','Apurimac')
insert into #TempUbigeo2 values ('4','Arequipa')
insert into #TempUbigeo2 values ('5','Ayacucho')
insert into #TempUbigeo2 values ('6','Cajamarca')
insert into #TempUbigeo2 values ('7','Callao')
insert into #TempUbigeo2 values ('8','Cusco')
insert into #TempUbigeo2 values ('9','Huancavelica')
insert into #TempUbigeo2 values ('10','Huanuco')
insert into #TempUbigeo2 values ('11','Ica')
insert into #TempUbigeo2 values ('12','Junin')
insert into #TempUbigeo2 values ('13','La Libertad')
insert into #TempUbigeo2 values ('14','Lambayeque')
insert into #TempUbigeo2 values ('15','Lima')
insert into #TempUbigeo2 values ('16','Loreto')
insert into #TempUbigeo2 values ('17','Madre de Dios')
insert into #TempUbigeo2 values ('18','Moquegua')
insert into #TempUbigeo2 values ('19','Pasco')
insert into #TempUbigeo2 values ('20','Piura')
insert into #TempUbigeo2 values ('21','Puno')
insert into #TempUbigeo2 values ('22','San Martin')
insert into #TempUbigeo2 values ('23','Tacna')
insert into #TempUbigeo2 values ('24','Tumbes')
insert into #TempUbigeo2 values ('25','Ucayali')
go
insert into TUbigeo
select UBIGEO, DISTRITO = null, PROVINCIA = null, DEPARTAMENTO, POBLACION = null, SUPERFICIE = null
from #TempUbigeo2
--select * from TUbigeo
-----------------------------------------------------------------------
------------------------ fin Ubigeo------------------------------------
-----------------------------------------------------------------------

--Tabla temporal para guardar datos de positivos_covid
DROP TABLE IF EXISTS dbo.#TempPositivos
go
CREATE TABLE #TempPositivos
(	-- Lista de atributos
	FECHA_CORTE varchar(8) not null,
	UUID varchar(32) not null,
	DEPARTAMENTO varchar(20) not null,
	PROVINCIA varchar(50),
	DISTRITO varchar(50),
	METODOX varchar (10) not null,
	EDAD int,
	SEXO varchar(10) not null,
	FECHA_RESULTADO	varchar(8) not null
)
BULK INSERT #TempPositivos
   FROM 'C:\Users\jhno\Desktop\positivos_covid.csv'
   WITH
	(	  CODEPAGE = '65001' 
		, FIRSTROW=2
		, FIELDTERMINATOR = ';'
      );
go
--- TPositivo
delete from TPositivo
insert into TPositivo
select TP.UUID, TU.UBIGEO, TP.FECHA_CORTE, TP.FECHA_RESULTADO, TP.METODOX
	from #TempPositivos TP left join #TempUbigeo TU
		on (TP.PROVINCIA = TU.PROVINCIA and TP.DISTRITO=TU.DISTRITO)
	where NOT TP.PROVINCIA = 'EN INVESTIGACIÓN'
		and NOT TP.DISTRITO = 'EN INVESTIGACIÓN'
insert into TPositivo
select TP.UUID, TU.UBIGEO, TP.FECHA_CORTE, TP.FECHA_RESULTADO, TP.METODOX
	from #TempPositivos TP left join #TempUbigeo2 TU
		on replace(TP.DEPARTAMENTO,'LIMA REGION', 'LIMA') = TU.DEPARTAMENTO
	where (TP.PROVINCIA = 'EN INVESTIGACIÓN'
		or TP.DISTRITO = 'EN INVESTIGACIÓN')
--select * from TPositivo
--- TPersona_Positivo
delete from TPersona_Positivo
insert into TPersona_Positivo
select TP.UUID, TP.EDAD, TP.SEXO
	from #TempPositivos TP
--select * from TPersona_Positivo
-----------------------------------------------------------------------------
---------------------------fin positivos-------------------------------------
-----------------------------------------------------------------------------

--TaBla temporal de datos de personas fallecidas a causa del covid 2019
DROP TABLE IF EXISTS dbo.#TempFallecidos
go
CREATE TABLE #TempFallecidos
(	-- Lista de atributos
	FECHA_CORTE varchar(8) not null,
	UUID varchar(32) not null,
	FECHA_FALLECIMIENTO	varchar(8),
	EDAD_DECLARADA int,
	SEXO varchar(10),
	FECHA_NAC	varchar(8),
	DEPARTAMENTO varchar(20) not null,
	PROVINCIA varchar(50),
	DISTRITO varchar(50),
)
go
BULK INSERT #TempFallecidos
   FROM 'C:\Users\jhno\Desktop\fallecidos_covid.csv'
   WITH	(
		CODEPAGE = '1252'
		,FIRSTROW=2
		, FIELDTERMINATOR = ';'
      );
go
-- Tabla TFallecido
delete from TFallecido
insert into TFallecido
select TP.UUID, TU.UBIGEO, TP.FECHA_CORTE, TP.FECHA_FALLECIMIENTO
	from #TempFallecidos TP left join #TempUbigeo TU
		on (TP.PROVINCIA = TU.PROVINCIA and TP.DISTRITO=TU.DISTRITO)
	where isnull(TU.DEPARTAMENTO,'null') != 'null'

insert into TFallecido
select TP.UUID, TUb.UBIGEO, TP.FECHA_CORTE, TP.FECHA_FALLECIMIENTO
	from (#TempFallecidos TP left join #TempUbigeo TU
		on (TP.PROVINCIA = TU.PROVINCIA and TP.DISTRITO=TU.DISTRITO)) left join #TempUbigeo2 TUb
		on (TP.DEPARTAMENTO = TUb.DEPARTAMENTO)
	where isnull(TU.DEPARTAMENTO,'null') = 'null'
--select * from TFallecido
--- Tabla TPersona_Fallecido
delete from TPersona_Fallecido
insert into TPersona_Fallecido
select TP.UUID, TP.EDAD_DECLARADA, TP.SEXO, TP.FECHA_NAC
	from #TempFallecidos TP
--select * from TPersona_Fallecido
-----------------------------------------------------------------------------
-----------------------------------fin fallecidos----------------------------
-----------------------------------------------------------------------------
--VEIFICACION
-- Ubigeo: 1875 + 24 = 1899
--select count(*) from TUbigeo
-- fallecidos: 41181
--select count(*) from TFallecido
--select * from TFallecido F left join TUbigeo U on F.UBIGEO = U.UBIGEO where U.UBIGEO is null
--select * from TPersona_Fallecido PF left join TFallecido F on Pf.UUID = F.UUID where F.UUID is null
-- fallecidos: 1142716
--select count(*) from TPositivo
--select * from TPositivo P left join TUbigeo U on P.UBIGEO = U.UBIGEO where U.UBIGEO is null
--select * from TPersona_Positivo PP left join TPositivo P on PP.UUID = P.UUID where P.UUID is null