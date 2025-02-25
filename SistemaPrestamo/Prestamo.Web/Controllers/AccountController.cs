﻿using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Prestamo.Data;
using Prestamo.Web.Models;
using System.Security.Claims;

namespace Prestamo.Web.Controllers
{
    [Authorize]
    [ApiController]
    [Route("[controller]")]
    public class AccountController : Controller
    {
        private readonly UsuarioData _usuarioData;
        private readonly EmailService _emailService;

        public AccountController(UsuarioData usuarioData, EmailService emailService)
        {
            _usuarioData = usuarioData;
            _emailService = emailService;
        }

        [HttpGet]
        public IActionResult ChangePassword()
        {
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> SolicitarCodigoVerificacion([FromBody] ChangePasswordViewModel model)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null)
            {
                return Json(new { success = false, message = "Usuario no autenticado" });
            }

            var usuario = await _usuarioData.ObtenerPorId(int.Parse(userId));
            if (usuario == null)
            {
                return Json(new { success = false, message = "Usuario no encontrado" });
            }

            bool isPasswordValid = BCrypt.Net.BCrypt.Verify(model.CurrentPassword, usuario.Clave);
            if (!isPasswordValid)
            {
                return Json(new { success = false, message = "La contraseña actual es incorrecta" });
            }

            // Generar código de verificación
            var codigoVerificacion = new Random().Next(100000, 999999).ToString();
            HttpContext.Session.SetString("CodigoVerificacion", codigoVerificacion);

            // Enviar código de verificación por correo
            string asunto = "Código de verificación para cambio de contraseña";
            string mensaje = $"Tu código de verificación es: {codigoVerificacion}";
            await _emailService.EnviarCorreoAsync(usuario.Correo, asunto, mensaje);

            return Json(new { success = true });
        }

        [HttpPost]
        public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordViewModel model)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null)
            {
                return Json(new { success = false, message = "Usuario no autenticado" });
            }

            var usuario = await _usuarioData.ObtenerPorId(int.Parse(userId));
            if (usuario == null)
            {
                return Json(new { success = false, message = "Usuario no encontrado" });
            }

            var codigoVerificacion = HttpContext.Session.GetString("CodigoVerificacion");
            if (model.VerificationCode != codigoVerificacion)
            {
                return Json(new { success = false, message = "El código de verificación es incorrecto" });
            }

            usuario.Clave = BCrypt.Net.BCrypt.HashPassword(model.NewPassword);
            await _usuarioData.Actualizar(usuario);

            return Json(new { success = true });
        }
    }
}
