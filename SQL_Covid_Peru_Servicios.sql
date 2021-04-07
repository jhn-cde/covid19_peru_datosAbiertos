-----------------------------------------------------------------------------
-------------------------------- Servicios ----------------------------------
-----------------------------------------------------------------------------

use BDCovid_Peru
go
SET Language 'Spanish';
---------------
-- 1. Número de casos positivos por cada provincia de un determinado departamento. R (Provincia, NroCasos)
drop function if exists dbo.fnPostivosPorProvincia
go
create function fnPostivosPorProvincia(@Departamento varchar (50))
returns table
as
return (
	select Provincia = U.PROVINCIA, NroCasos = sum(case when isnull(TP.UUID,'null')='null'then 0 else 1 end)
	from TPositivo TP right join TUbigeo U
			on TP.UBIGEO = U.UBIGEO
		where isnull(U.PROVINCIA,'null') != 'null'
			and U.DEPARTAMENTO = @Departamento
		group by U.PROVINCIA
)
go
--select * from fnPostivosPorProvincia('HUANUCO') order by NroCasos desc

-- 2. Número de casos positivos por tipo de prueba y departamento entre dos fechas. R(Departamento, Tipo1, Tipo2...)
drop function if exists dbo.fnPostivosPorPruebaDepartamento
go
create function fnPostivosPorPruebaDepartamento(@fechaIn date, @fechaFi date)
returns @taRespuesta table (Departamento varchar(50),
                      PR int, PCR int, AG int)
as
begin
	declare @taPositvos_Prueba_Departemento table(Metodox varchar(10),
	                                              Departamento varchar(50),
												  NroCasos int)
	insert into @taPositvos_Prueba_Departemento
	select TP.METODOX, U.DEPARTAMENTO, NroCasos = sum(case when isnull(TP.UUID,'null')='null'then 0 else 1 end)
	from TPositivo TP inner join TUbigeo U
			on TP.UBIGEO = U.UBIGEO
		where year(TP.FECHA_RESULTADO) >= year(@fechaIn) and year(TP.FECHA_RESULTADO) <= year(@fechaFi)
			and month(TP.FECHA_RESULTADO) >= month(@fechaIn) and month(TP.FECHA_RESULTADO) <= month(@fechaFi)
			and day(TP.FECHA_RESULTADO) >= day(@fechaIn) and day(TP.FECHA_RESULTADO) <= day(@fechaFi)
		group by TP.METODOX, U.DEPARTAMENTO

	insert into @taRespuesta
	select Departamento, PR = isnull([PR],0), PCR = isnull([PCR], 0), AG = isnull([AG],0)
	from @taPositvos_Prueba_Departemento
		pivot (sum(NroCasos)
				for Metodox in ([PR],[PCR],[AG])
				) as pvtTable
	return
end
go
--select * from fnPostivosPorPruebaDepartamento('2020-04-01', '2020-08-31')

-- 3. Número y porcentaje de fallecidos por sexo en los distritos de una provincia determinada
-- R(Distrito, PositivosVarones, %Varones, PositivosMujeres, %Mujeres)
drop function if exists dbo.fnFallecidosProvinciaSexo
go
create function fnFallecidosProvinciaSexo (@Provincia varchar(50))
returns @taRespuesta table (Distrito varchar(50),
                            FallecidosVarones int, PorcentVarones float,
							FallecidosMujeres int, PorcentMujeres float)
as
begin
	-- Crear variables
	declare @taFallecidosPorDistrito table(Distrito varchar (50),
	                                    NroFallecidos int,
										FallecidosVarones int,
										FallecidosMujeres int)
	-- Obtener datos
	insert into @taFallecidosPorDistrito
	select Distrito = U.DISTRITO,
				NroFallecidos = sum(case when isnull(F.UUID,'null') = 'null' then 0 else 1 end),
				FallecidosVarones = sum(case when isnull(PF.SEXO,'null') = 'null' or
								PF.SEXO = 'FEMENINO' then 0 else 1 end),
				FallecidosMujeres = sum(case when isnull(PF.SEXO,'null') = 'null' or
								PF.SEXO = 'MASCULINO' then 0 else 1 end)
	from TUbigeo U left join TFallecido F on U.UBIGEO = F.UBIGEO
			left join TPersona_Fallecido PF on F.UUID = PF.UUID
		where U.PROVINCIA = @Provincia
		group by U.DISTRITO
	insert into @taRespuesta
	select Distrito, FallecidosVarones, case when NroFallecidos = 0 then 0 else FallecidosVarones*100/NroFallecidos end,
			FallecidosMujeres, case when NroFallecidos = 0 then 0 else FallecidosMujeres*100/NroFallecidos end
	from @taFallecidosPorDistrito
return
end
go
--select * from fnFallecidosProvinciaSexo('Cusco')

-- 4. Número de positivos y fallecidos por departamento, mes a mes durante el año 2020
-- R(Departamento, Condición, Enero, Febrero, Marzo.......)
-- Condición = {“Positivos”, “Fallecidos”}
drop function if exists dbo.fnPositivosFallecidosDepartamento
go
create function fnPositivosFallecidosDepartamento (@Anio int)
returns @taRespuesta table (Departamento varchar(50),
                            Condicion varchar (20),
							Enero int, Febrero int, Marzo int, Abril int, Mayo int,
							Junio int, Julio int, Agosto int, Septiembre int,
							Octubre int, Noviembre int, Diciembre int)
as
begin
	-- declarar variables
	declare @PositivosResumen1 table (Departemento varchar(50),
	                         Mes varchar(20), Conteo int)
	declare @FallecidosResumen1 table (Departemento varchar(50),
	                         Mes varchar(20), Conteo int)
	--Obtencion de datos
	insert into @PositivosResumen1
	select U.DEPARTAMENTO, Mes = month(P.FECHA_RESULTADO),
				Conteo = count(P.UUID)
	from TUbigeo U inner join TPositivo P on U.UBIGEO = P.UBIGEO
	where @Anio = year(P.FECHA_RESULTADO)
	group by U.DEPARTAMENTO, month(P.FECHA_RESULTADO)

	insert into @FallecidosResumen1
	select U.DEPARTAMENTO, Mes = month(F.FECHA_FALLECIMIENTO),
				Conteo = count(F.UUID)
	from TUbigeo U inner join TFallecido F on U.UBIGEO = F.UBIGEO
	where @Anio = year(F.FECHA_FALLECIMIENTO)
	group by U.DEPARTAMENTO, month(F.FECHA_FALLECIMIENTO)
	
	-- Union
	insert into @taRespuesta
	select Departemento, Condicion = 'Positivos',
			Enero = isnull([1], 0), Febrero = isnull([2], 0), Marzo = isnull([3], 0),
			Abril = isnull([4], 0), Mayo = isnull([5], 0), Junio = isnull([6], 0),
			Julio = isnull([7], 0), Agosto = isnull([8], 0), Septiembre = isnull([9], 0),
			Octubre = isnull([10], 0), Noviembre = isnull([11], 0), Diciembre = isnull([12], 0)
	from @PositivosResumen1
		pivot (sum(Conteo)
				for Mes in ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])
				) as pvtTable
	union
	select Departemento, Condicion = 'Fallecidos',
			Enero = isnull([1], 0), Febrero = isnull([2], 0), Marzo = isnull([3], 0),
			Abril = isnull([4], 0), Mayo = isnull([5], 0), Junio = isnull([6], 0),
			Julio = isnull([7], 0), Agosto = isnull([8], 0), Septiembre = isnull([9], 0),
			Octubre = isnull([10], 0), Noviembre = isnull([11], 0), Diciembre = isnull([12], 0)
	from @FallecidosResumen1
		pivot (sum(Conteo)
				for Mes in ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])
				) as pvtTable
return
end
go
--select * from fnPositivosFallecidosDepartamento(2020)

--------------------------------------------------------------------------------------------------
---------------------------------------- Servicios adicionales -----------------------------------
--------------------------------------------------------------------------------------------------

--1 Nro de contagiados y fallecidos por miles en cada departamento
drop function if exists dbo.fnResumenPorcentajePorDepartamentos
go
create function fnResumenPorcentajePorDepartamentos (@Anio int)
returns @taRespuesta table (Departamento varchar(50),
							Condicion varchar(15),
							Conteo int,
							Poblacion int,
							Porcentaje decimal(10,2))
as
begin
	-- declarar variables
	declare @PositivosResumen table (Departemento varchar(50), Conteo int)
	declare @FallecidosResumen table (Departemento varchar(50), Conteo int)
	declare @HabitantesDepartamento table (Departamento varchar(50), Poblacion int)
	--Obtencion de datos
	insert into @HabitantesDepartamento
	select Departamento, sum(cast(Poblacion as int))
	  from TUbigeo
	  where isnull(PROVINCIA,'null')!='null'
	  group by DEPARTAMENTO

	insert into @PositivosResumen
	select U.DEPARTAMENTO, count(P.UUID)
	  from TUbigeo U inner join TPositivo P on U.UBIGEO = P.UBIGEO
	  where @Anio = year(P.FECHA_RESULTADO)
	  group by U.DEPARTAMENTO

	insert into @FallecidosResumen
	select U.DEPARTAMENTO, count(F.UUID)
	  from TUbigeo U inner join TFallecido F on U.UBIGEO = F.UBIGEO
	  where @Anio = year(F.FECHA_FALLECIMIENTO)
	  group by U.DEPARTAMENTO
	
	-- Union
	insert into @taRespuesta
	select PR.Departemento, Condicion = 'Positivos', Conteo, Poblacion,
			--(1000/cast(Poblacion as decimal(10,2)))*Conteo,
			(100/cast(Poblacion as decimal(10,2)))*Conteo
	from @PositivosResumen PR inner join @HabitantesDepartamento HD
			on PR.Departemento = HD.Departamento
	union
	select Fr.Departemento, Condicion = 'Fallecidos', Conteo, Poblacion,
			--(1000/cast(Poblacion as decimal(10,2)))*Conteo,
			(100/cast(Poblacion as decimal(10,2)))*Conteo
	from @FallecidosResumen FR inner join @HabitantesDepartamento HD
			on FR.Departemento = HD.Departamento
return
end
go
-- select * from fnResumenPorcentajePorDepartamentos(2020) where Condicion = 'Positivos' order by Porcentaje desc
-- 2 Contagiados organizados por mes R(Mes, 0-19,20-39, 40-59, 60-79, 79-...)
drop function if exists dbo.fnResumenEdadesMesPorDepartamento
go
create function fnResumenEdadesMesPorDepartamento (@departamento varchar(50), @anio int)
returns @taRespuesta table (Mes int, MesNombre varchar(20), Condicion varchar(15),
                            Conteo0_19 float, Conteo20_39 float,
                            Conteo40_59 float, Conteo60_79 float,
							Conteo80_Mas float)
as
begin
	-- declarar variables
	declare @Temporal1 table (Mes int, MesNombre varchar(20),Condicion varchar (20), Conteo0_19 float, Conteo20_39 float,
	             Conteo40_59 float, Conteo60_79 float, Conteo79_Mas float)
	declare @Temporal2 table (Mes int, MesNombre varchar(20),Condicion varchar (20), Conteo0_19 float, Conteo20_39 float,
	             Conteo40_59 float, Conteo60_79 float, Conteo79_Mas float)
	--Obtencion de datos
	insert into @Temporal1
	select Mes = month(P.FECHA_RESULTADO),
	       dateName(month, DateAdd(month, month(P.FECHA_RESULTADO) , -1 )),
		   'Positivo',
	       sum(case when Edad < 20 then 1 else 0 end),
		   sum(case when Edad > 19 and Edad < 40 then 1 else 0 end),
		   sum(case when Edad > 39 and Edad < 60 then 1 else 0 end),
		   sum(case when Edad > 59 and Edad < 80 then 1 else 0 end),
		   sum(case when Edad > 79 then 1 else 0 end)
	  from TPositivo P inner join TUbigeo u on P.UBIGEO = U.UBIGEO
	          inner join TPersona_Positivo PP on P.UUID = PP.UUID
	  where year(P.FECHA_RESULTADO)=2020 and PP.EDAD != 0
	      and U.DEPARTAMENTO = @departamento
	  group by month(P.FECHA_RESULTADO)

	insert into @Temporal2
	select month(F.FECHA_FALLECIMIENTO),
	       dateName(month, DateAdd(month, month(F.FECHA_FALLECIMIENTO) , -1 )),
		   'Fallecido',
	       sum(case when EDAD_DECLARADA < 20 then 1 else 0 end),
		   sum(case when EDAD_DECLARADA > 19 and EDAD_DECLARADA < 40 then 1 else 0 end),
		   sum(case when EDAD_DECLARADA > 39 and EDAD_DECLARADA < 60 then 1 else 0 end),
		   sum(case when EDAD_DECLARADA > 59 and EDAD_DECLARADA < 80 then 1 else 0 end),
		   sum(case when EDAD_DECLARADA > 79 then 1 else 0 end)
	  from TFallecido F inner join TUbigeo u on F.UBIGEO = U.UBIGEO
	          inner join TPersona_Fallecido PF on F.UUID = PF.UUID
	  where year(F.FECHA_FALLECIMIENTO)=2020 and PF.EDAD_DECLARADA != 0
	      and U.DEPARTAMENTO = @departamento
	  group by month(F.FECHA_FALLECIMIENTO)

	insert into @taRespuesta
	select * from @Temporal1
	union
	select * from @Temporal2
return
end
go

--select *
--  from fnResumenEdadesMesPorDepartamento('Cusco', 2020)
--  order by Mes, Condicion
