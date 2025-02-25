use DBPrestamo

go
--- CONFIGURACION ---

create FUNCTION [dbo].[SplitString]  ( 
	@string NVARCHAR(MAX), 
	@delimiter CHAR(1)  
)
RETURNS
@output TABLE(valor NVARCHAR(MAX)  ) 
BEGIN 
	DECLARE @start INT, @end INT 
	SELECT @start = 1, @end = CHARINDEX(@delimiter, @string) 
	WHILE @start < LEN(@string) + 1
	BEGIN 
		IF @end = 0  
        SET @end = LEN(@string) + 1 

		INSERT INTO @output (valor)  
		VALUES(SUBSTRING(@string, @start, @end - @start)) 
		SET @start = @end + 1 
		SET @end = CHARINDEX(@delimiter, @string, @start) 
	END 
	RETURN
END

go

CREATE PROCEDURE [dbo].[sp_crearUsuario]
    @NombreCompleto NVARCHAR(100),
    @Correo NVARCHAR(100),
    @Clave NVARCHAR(60),
    @Rol NVARCHAR(50)
AS
BEGIN
    INSERT INTO Usuario (NombreCompleto, Correo, Clave, FechaCreacion, Rol)
    VALUES (@NombreCompleto, @Correo, @Clave, GETDATE(), @Rol)
END
GO

create procedure sp_obtenerUsuario(
@Correo varchar(50),
@Clave varchar(50)
)
as
begin
	select IdUsuario,NombreCompleto,Correo from Usuario where 
	Correo = @Correo COLLATE SQL_Latin1_General_CP1_CS_AS and
	Clave = @Clave COLLATE SQL_Latin1_General_CP1_CS_AS
end

go

-- PROCEDMIENTOS PARA MONEDA 

create procedure sp_listaMoneda
as
begin
	select IdMoneda,Nombre,Simbolo,convert(char(10),FechaCreacion,103)[FechaCreacion] from Moneda
end

go

create procedure sp_crearMoneda(
@Nombre varchar(50),
@Simbolo varchar(50),
@msgError varchar(100) OUTPUT
)
as
begin

	set @msgError = ''
	if(not exists(select * from Moneda where 
		Nombre = @Nombre COLLATE SQL_Latin1_General_CP1_CS_AS
	))
		insert into Moneda(Nombre,Simbolo) values(@Nombre,@Simbolo)
	else
		set @msgError = 'La moneda ya existe'
end

go

create procedure sp_editarMoneda(
@IdMoneda int,
@Nombre varchar(50),
@Simbolo varchar(50),
@msgError varchar(100) OUTPUT
)
as
begin

	set @msgError = ''
	if(not exists(select * from Moneda where 
		Nombre = @Nombre COLLATE SQL_Latin1_General_CP1_CS_AS and
		IdMoneda != @IdMoneda
	))
		update Moneda set Nombre = @Nombre ,Simbolo = @Simbolo where IdMoneda = @IdMoneda
	else
		set @msgError = 'La moneda ya existe'
end

go

create procedure sp_eliminarMoneda(
@IdMoneda int,
@msgError varchar(100) OUTPUT
)
as
begin

	set @msgError = ''
	if(not exists(select IdPrestamo from Prestamo where IdMoneda = @IdMoneda))
		delete from Moneda where IdMoneda = @IdMoneda
	else
		set @msgError = 'La moneda esta utilizada en un prestamo, no se puede eliminar'
end

go

-- PROCEDMIENTOS PARA CLIENTE

create procedure sp_listaCliente
as
begin
	select IdCliente,NroDocumento,Nombre,Apellido,Correo,Telefono,convert(char(10),FechaCreacion,103)[FechaCreacion] from Cliente
end

go

create procedure sp_obtenerCliente(
@NroDocumento varchar(50)
)
as
begin
	select IdCliente,NroDocumento,Nombre,Apellido,Correo,Telefono,convert(char(10),FechaCreacion,103)[FechaCreacion] from Cliente
	where NroDocumento = @NroDocumento
end

go

CREATE PROCEDURE sp_crearCliente(
    @NroDocumento VARCHAR(50),
    @Nombre VARCHAR(50),
    @Apellido VARCHAR(50),
    @Correo VARCHAR(50),
    @Telefono VARCHAR(50),
    @IdCliente INT OUTPUT,
    @msgError VARCHAR(100) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET @msgError = '';

    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM Cliente WHERE NroDocumento = @NroDocumento)
        BEGIN
            INSERT INTO Cliente (NroDocumento, Nombre, Apellido, Correo, Telefono, FechaCreacion)
            VALUES (@NroDocumento, @Nombre, @Apellido, @Correo, @Telefono, GETDATE());

            -- Obtener el IdCliente generado
            SET @IdCliente = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            SET @msgError = 'El cliente ya existe';
        END
    END TRY
    BEGIN CATCH
        SET @msgError = ERROR_MESSAGE();
    END CATCH
END
go


create procedure sp_editarCliente(
@IdCliente int,
@NroDocumento varchar(50),
@Nombre varchar(50),
@Apellido varchar(50),
@Correo varchar(50),
@Telefono varchar(50),
@msgError varchar(100) OUTPUT
)
as
begin

	set @msgError = ''
	if(not exists(select * from Cliente where 
		NroDocumento = @NroDocumento and IdCliente != @IdCliente
	))
		update Cliente set NroDocumento = @NroDocumento,Nombre = @Nombre,Apellido = @Apellido,Correo = @Correo,Telefono = @Telefono 
		where IdCliente = @IdCliente
	else
		set @msgError = 'El cliente ya existe'
end

go

create procedure sp_eliminarCliente(
@IdCliente int,
@msgError varchar(100) OUTPUT
)
as
begin

	set @msgError = ''
	if(not exists(select IdPrestamo from Prestamo where IdCliente = @IdCliente))
		delete from Cliente where IdCliente = @IdCliente
	else
		set @msgError = 'El cliente tiene historial de prestamo, no se puede eliminar'
end

go


-- PROCEDIMIENTOS PARA PRESTAMOS

create procedure sp_crearPrestamo(
@IdCliente int,
@NroDocumento varchar(50),
@Nombre varchar(50),
@Apellido varchar(50),
@Correo varchar(50),
@Telefono varchar(50),
@IdMoneda int,
@FechaInicio varchar(50),
@MontoPrestamo varchar(50),
@InteresPorcentaje varchar(50),
@NroCuotas int,
@FormaDePago varchar(50),
@ValorPorCuota varchar(50),
@ValorInteres varchar(50),
@ValorTotal varchar(50),
@msgError varchar(100) OUTPUT
)
as
begin
	set dateformat dmy
	set @msgError = ''

	begin try

		declare @FecInicio date = convert(date,@FechaInicio)
		declare @MontPrestamo decimal(10,2) = convert(decimal(10,2),@MontoPrestamo)
		declare @IntPorcentaje decimal(10,2) = convert(decimal(10,2),@InteresPorcentaje)
		declare @VlrPorCuota decimal(10,2) = convert(decimal(10,2),@ValorPorCuota)
		declare @VlrInteres decimal(10,2) = convert(decimal(10,2),@ValorInteres)
		declare @VlrTotal decimal(10,2) = convert(decimal(10,2),@ValorTotal)
		create table #TempIdentity(Id int,Nombre varchar(10))

		begin transaction

		if(@IdCliente = 0)
		begin
			insert into Cliente(NroDocumento,Nombre,Apellido,Correo,Telefono)
			OUTPUT INSERTED.IdCliente,'Cliente' INTO #TempIdentity(Id,Nombre)
			values
			(@NroDocumento,@Nombre,@Apellido,@Correo,@Telefono)

			set @IdCliente = (select Id from #TempIdentity where Nombre = 'Cliente')
		end
		else
		begin
			if(exists(select * from Prestamo where IdCliente = @IdCliente and Estado = 'Pendiente'))
				set @msgError = 'El cliente tiene un prestamo pendiente, debe cancelar el anterior'
		end

		if(@msgError ='')
		begin

			insert into Prestamo(IdCliente,IdMoneda,FechaInicioPago,MontoPrestamo,InteresPorcentaje,NroCuotas,FormaDePago,ValorPorCuota,ValorInteres,ValorTotal,Estado)
			OUTPUT INSERTED.IdPrestamo,'Prestamo' INTO #TempIdentity(Id,Nombre)
			values
			(@IdCliente,@IdMoneda,@FecInicio,@MontPrestamo,@IntPorcentaje,@NroCuotas,@FormaDePago,@VlrPorCuota,@VlrInteres,@VlrTotal,'Pendiente')

			;with detalle(IdPrestamo,FechaPago,NroCuota,MontoCuota,Estado) as
			(
				select (select Id from #TempIdentity where Nombre = 'Prestamo'),@FecInicio,0,@VlrPorCuota,'Pendiente'
				union all
				select IdPrestamo,
				case @FormaDePago 
					when 'Diario' then DATEADD(day,1,FechaPago)
					when 'Semanal' then DATEADD(WEEK,1,FechaPago)
					when 'Quincenal' then DATEADD(day,15,FechaPago)
					when 'Mensual' then DATEADD(MONTH,1,FechaPago)
				end,
				NroCuota + 1,MontoCuota,Estado from detalle
				where NroCuota < @NroCuotas
			)
			select IdPrestamo,FechaPago,NroCuota,MontoCuota,Estado into #tempDetalle from detalle where NroCuota > 0
	
			insert into PrestamoDetalle(IdPrestamo,FechaPago,NroCuota,MontoCuota,Estado)
			select IdPrestamo,FechaPago,NroCuota,MontoCuota,Estado from #tempDetalle

		end

		commit transaction
	end try
	begin catch
		rollback transaction
		set @msgError = ERROR_MESSAGE()
	end catch
	
end

go

create procedure sp_obtenerPrestamos(
@IdPrestamo int = 0,
@NroDocumento varchar(50) = ''
)as
begin
	select p.IdPrestamo,
	c.IdCliente,c.NroDocumento,c.Nombre,c.Apellido,c.Correo,c.Telefono,
	m.IdMoneda,m.Nombre[NombreMoneda],m.Simbolo,
	CONVERT(char(10),p.FechaInicioPago, 103) [FechaInicioPago],
	CONVERT(VARCHAR,p.MontoPrestamo)[MontoPrestamo],
	CONVERT(VARCHAR,p.InteresPorcentaje)[InteresPorcentaje],
	p.NroCuotas,
	p.FormaDePago,
	CONVERT(VARCHAR,p.ValorPorCuota)[ValorPorCuota],
	CONVERT(VARCHAR,p.ValorInteres)[ValorInteres],
	CONVERT(VARCHAR,p.ValorTotal)[ValorTotal],
	p.Estado,
	CONVERT(char(10),p.FechaCreacion, 103) [FechaCreacion],
	(
		select pd.IdPrestamoDetalle,CONVERT(char(10),pd.FechaPago, 103) [FechaPago],
		CONVERT(VARCHAR,pd.MontoCuota)[MontoCuota],
		pd.NroCuota,pd.Estado,isnull(CONVERT(varchar(10),pd.FechaPagado, 103),'')[FechaPagado]
		from PrestamoDetalle pd
		where pd.IdPrestamo = p.IdPrestamo
		FOR XML PATH('Detalle'), TYPE, ROOT('PrestamoDetalle')
	)
	from Prestamo p
	inner join Cliente c on c.IdCliente = p.IdCliente
	inner join Moneda m on m.IdMoneda = p.IdMoneda
	where p.IdPrestamo = iif(@IdPrestamo = 0,p.idprestamo,@IdPrestamo) and
	c.NroDocumento = iif(@NroDocumento = '',c.NroDocumento,@NroDocumento)
	FOR XML PATH('Prestamo'), ROOT('Prestamos'), TYPE;
end


go
  

create procedure [dbo].[sp_obtenerUsuario](
@Correo varchar(50),
@Clave varchar(50)
)
as
begin
	select IdUsuario,NombreCompleto,Correo from Usuario where 
	Correo = @Correo COLLATE SQL_Latin1_General_CP1_CS_AS and
	Clave = @Clave COLLATE SQL_Latin1_General_CP1_CS_AS
end


GO
/****** Object:  StoredProcedure [dbo].[sp_obtenerUsuarioPorCorreo]    Script Date: 13/02/2025 23:11:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Crear el procedimiento almacenado con los par�metros correctos
CREATE PROCEDURE [dbo].[sp_obtenerUsuarioPorCorreo]
    @Correo NVARCHAR(100)
AS
BEGIN
    SELECT IdUsuario, NombreCompleto, Correo, Clave, Rol
    FROM Usuario
    WHERE Correo = @Correo
END
GO
/****** Object:  StoredProcedure [dbo].[sp_pagarCuotas]    Script Date: 13/02/2025 23:11:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_pagarCuotas')
    DROP PROCEDURE sp_pagarCuotas;
GO

CREATE PROCEDURE sp_pagarCuotas
(
    @IdPrestamo INT,
    @NroCuotasPagadas VARCHAR(100),
    @NumeroTarjeta VARCHAR(16),
    @msgError VARCHAR(100) OUTPUT
)
AS
BEGIN
    SET DATEFORMAT dmy;
    SET @msgError = '';

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IdCliente INT;
        DECLARE @TotalPagar DECIMAL(18, 2);

        -- Obtener el IdCliente y el total a pagar
        SELECT @IdCliente = p.IdCliente,
               @TotalPagar = SUM(pd.MontoCuota)
        FROM Prestamo p
        INNER JOIN PrestamoDetalle pd ON p.IdPrestamo = pd.IdPrestamo
        INNER JOIN dbo.SplitString(@NroCuotasPagadas, ',') ss ON ss.valor = pd.NroCuota
        WHERE p.IdPrestamo = @IdPrestamo
        GROUP BY p.IdCliente;

        -- Verificar el saldo de la cuenta
        DECLARE @SaldoCuenta DECIMAL(18, 2);
        DECLARE @Tarjeta NVARCHAR(16);

        SELECT @SaldoCuenta = c.Monto, @Tarjeta = c.Tarjeta
        FROM Cuenta c
        WHERE c.IdCliente = @IdCliente;

        IF @Tarjeta != @NumeroTarjeta
        BEGIN
            SET @msgError = 'N�mero de tarjeta incorrecto';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @SaldoCuenta < @TotalPagar
        BEGIN
            SET @msgError = 'Fondos insuficientes';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Actualizar el saldo de la cuenta
        UPDATE Cuenta
        SET Monto = Monto - @TotalPagar
        WHERE IdCliente = @IdCliente;

        -- Actualizar el estado de las cuotas
        UPDATE pd
        SET pd.Estado = 'Cancelado', FechaPagado = GETDATE()
        FROM PrestamoDetalle pd
        INNER JOIN dbo.SplitString(@NroCuotasPagadas, ',') ss ON ss.valor = pd.NroCuota
        WHERE IdPrestamo = @IdPrestamo;

        -- Actualizar el estado del pr�stamo si todas las cuotas est�n pagadas
        IF (SELECT COUNT(IdPrestamoDetalle) FROM PrestamoDetalle WHERE IdPrestamo = @IdPrestamo AND Estado = 'Pendiente') = 0
        BEGIN
            UPDATE Prestamo
            SET Estado = 'Cancelado'
            WHERE IdPrestamo = @IdPrestamo;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
		SET @msgError = 'Error en sp_pagarCuotas: ' + ERROR_MESSAGE() + ' | IdPrestamo: ' + CAST(@IdPrestamo AS VARCHAR) + ' | NroCuotasPagadas: ' + @NroCuotasPagadas + ' | NumeroTarjeta: ' + @NumeroTarjeta;
    END CATCH;
END;



-- PROCEDIMIENTO PARA RESUMEN

GO

create PROCEDURE sp_obtenerResumen
as
begin
select 
(select convert(varchar,count(*)) from Cliente) [TotalClientes],
(select convert(varchar,count(*)) from Prestamo where Estado = 'Pendiente')[PrestamosPendientes],
(select convert(varchar,count(*)) from Prestamo where Estado = 'Cancelado')[PrestamosCancelados],
(select convert(varchar,isnull(sum(ValorInteres),0)) from Prestamo where Estado = 'Cancelado')[InteresAcumulado]
end

GO

-- Procedimiento para obtener cuenta
CREATE PROCEDURE sp_obtenerCuenta
    @IdCliente INT
AS
BEGIN
    SELECT IdCuenta, IdCliente, Tarjeta, Monto
    FROM Cuenta
    WHERE IdCliente = @IdCliente
END
GO

-- Procedimiento para depositar
CREATE PROCEDURE sp_depositarCuenta
    @IdCliente INT,
    @Monto DECIMAL(18,2),
    @msgError VARCHAR(100) OUTPUT
AS
BEGIN
    SET @msgError = ''
    
    BEGIN TRY
        BEGIN TRANSACTION
            
            IF NOT EXISTS (SELECT 1 FROM Cuenta WHERE IdCliente = @IdCliente)
            BEGIN
                SET @msgError = 'No se encontr� la cuenta del cliente'
                ROLLBACK
                RETURN
            END
            
            IF @Monto <= 0
            BEGIN
                SET @msgError = 'El monto debe ser mayor a 0'
                ROLLBACK
                RETURN
            END
            
            UPDATE Cuenta
            SET Monto = Monto + @Monto
            WHERE IdCliente = @IdCliente
            
        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        SET @msgError = ERROR_MESSAGE()
        ROLLBACK TRANSACTION
    END CATCH
END

CREATE PROCEDURE sp_crearCuenta
    @IdCliente INT,
    @Tarjeta VARCHAR(16),
    @Monto DECIMAL(18, 2),
    @msgError NVARCHAR(100) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Insertar la nueva cuenta en la tabla Cuenta
        INSERT INTO Cuenta (IdCliente, Tarjeta, Monto, FechaCreacion)
        VALUES (@IdCliente, @Tarjeta, @Monto, GETDATE());

        -- Establecer el mensaje de error a vac�o si la operaci�n es exitosa
        SET @msgError = '';
    END TRY
    BEGIN CATCH
        -- Capturar el error y establecer el mensaje de error
        SET @msgError = ERROR_MESSAGE();
    END CATCH
END

CREATE PROCEDURE sp_obtenerClientePorCorreo
    @Correo NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        IdCliente,
        NroDocumento,
        Nombre,
        Apellido,
        Correo,
        Telefono,
        FechaCreacion
    FROM 
        Cliente
    WHERE 
        Correo = @Correo;
END