﻿using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Prestamo.Data;
using Prestamo.Entidades;
using System.Security.Claims;

namespace Prestamo.Web.Controllers
{
    [Authorize]
    public class SolicitudPrestamoController : Controller
    {
        private readonly PrestamoData _prestamoData;
        private readonly ClienteData _clienteData;
        private readonly ResumenClienteData _resumenClienteData;
        private readonly EmailService _emailService;

        public IActionResult Index()
        {
            return View();
        }
        public SolicitudPrestamoController(PrestamoData prestamoData, ClienteData clienteData, ResumenClienteData resumenClienteData, EmailService emailService)
        {
            _prestamoData = prestamoData;
            _clienteData = clienteData;
            _resumenClienteData = resumenClienteData;
            _emailService = emailService;
        }

        [HttpPost]
        public async Task<IActionResult> CrearSolicitud([FromBody] SolicitudPrestamo solicitud)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null)
            {
                return Json(new { success = false, message = "Usuario no autenticado" });
            }

            solicitud.IdUsuario = int.Parse(userId);
            solicitud.Estado = "Pendiente";
            solicitud.FechaSolicitud = DateTime.Now;

            // Verificar historial crediticio
            var historial = await _prestamoData.ObtenerHistorialCrediticio(solicitud.IdUsuario);
            if (historial == null)
            {
                historial = new Entidades.HistorialCrediticio { IdUsuario = solicitud.IdUsuario, EstadoCrediticio = 7 };
                await _prestamoData.CrearHistorialCrediticio(historial);
            }
            else if (historial.EstadoCrediticio < 7)
            {
                return Json(new { success = false, message = "Solicitud rechazada debido a historial crediticio negativo" });
            }

            //Verificar si el cliente tiene un préstamo pendiente
            var correo = User.FindFirst(ClaimTypes.Email)?.Value;
            var cliente = await _clienteData.ObtenerPorCorreo(correo);
            var prestamo = await _prestamoData.ObtenerIdPrestamoPorCliente(cliente.IdCliente);
            var resumen = await _resumenClienteData.ObtenerResumen(cliente.IdCliente, prestamo);
            Console.WriteLine(resumen.PagosClientePendientes);
            if (resumen.PagosClientePendientes != "0")
            {
                return Json(new { success = false, message = "Solicitud rechazada debido a préstamos pendientes" });
            }
            // Verificar si el monto del préstamo es mayor a 10 veces el sueldo
            if (solicitud.Monto > solicitud.Sueldo * 5)
            {
                return Json(new { success = false, message = "Solicitud rechazada debido a que el monto del préstamo es mayor a 5 veces el sueldo" });
            }

            bool resultado = await _prestamoData.CrearSolicitudPrestamo(solicitud);
            return Json(new { success = resultado });
        }

        [Authorize(Roles = "Administrador")]
        public IActionResult GestionarSolicitudes()
        {
            return View();
        }

        [Authorize(Roles = "Administrador")]
        [HttpGet]
        public async Task<IActionResult> ObtenerSolicitudesPendientes()
        {
            var solicitudes = await _prestamoData.ObtenerSolicitudesPendientes();
            return Json(new { data = solicitudes });
        }

        [Authorize(Roles = "Administrador")]
        [HttpGet]
        public async Task<IActionResult> ObtenerSolicitud(int id)
        {
            var solicitud = await _prestamoData.ObtenerSolicitudPorId(id);
            if (solicitud == null)
            {
                return Json(new { success = false, message = "Solicitud no encontrada" });
            }
            return Json(new { success = true, data = solicitud });
        }

        [Authorize(Roles = "Administrador")]
        [HttpPost]
        public async Task<IActionResult> ActualizarEstadoSolicitud([FromBody] SolicitudEstadoUpdateRequest request)
        {
            try
            {
                bool resultado = await _prestamoData.ActualizarEstadoSolicitud(request.Id, request.Estado);
                if (resultado)
                {
                    var solicitud = await _prestamoData.ObtenerSolicitudPorId(request.Id);
                    if (solicitud == null)
                    {
                        return Json(new { success = false, message = "Solicitud no encontrada" });
                    }

                    var cliente = await _clienteData.ObtenerPorCedula(solicitud.Cedula);
                    if (cliente == null)
                    {
                        return Json(new { success = false, message = "Cliente no encontrado" });
                    }

                    if (request.Estado == "Rechazado")
                    {
                        string asunto = "Solicitud de Préstamo Rechazada";
                        string mensaje = $"Estimado {cliente.Nombre + " " + cliente.Apellido},<br/><br/>Lamentamos informarle que su solicitud de préstamo ha sido rechazada.<br/><br/>Atentamente,<br/>   El equipo de Préstamos";
                        await _emailService.EnviarCorreoAsync(cliente.Correo, asunto, mensaje);
                    }
                    else if (request.Estado == "Aprobado")
                    {
                        // Actualizar historial crediticio
                        var historial = await _prestamoData.ObtenerHistorialCrediticio(solicitud.IdUsuario);
                        if (historial != null)
                        {
                            await _prestamoData.ActualizarHistorialCrediticio(historial.IdUsuario, true);
                        }

                        string asunto = "Solicitud de Préstamo Aceptada";
                        string mensaje = $"Estimado {cliente.Nombre + " " + cliente.Apellido},<br/><br/>Le informamos que su solicitud de préstamo ha sido aceptada.<br/><br/>Atentamente,<br/>   El equipo de Préstamos";
                        await _emailService.EnviarCorreoAsync(cliente.Correo, asunto, mensaje);

                        // Incluir historial crediticio en la respuesta
                        return Json(new { success = true, redirectUrl = "/Prestamo/Nuevo", historial });
                    }
                }
                return Json(new { success = resultado });
            }
            catch (Exception ex)
            {
                // Log the exception (you can use a logging framework)
                Console.WriteLine(ex.Message);
                return StatusCode(StatusCodes.Status500InternalServerError, new { success = false, message = "Error al actualizar el estado de la solicitud" });
            }
        }

        public class SolicitudEstadoUpdateRequest
        {
            public int Id { get; set; }
            public string Estado { get; set; }
        }
    }
}
