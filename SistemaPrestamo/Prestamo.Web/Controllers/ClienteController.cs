﻿using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Prestamo.Data;
using Prestamo.Entidades;
using System.Security.Claims;

namespace Prestamo.Web.Controllers
{
    [Authorize]
    public class ClienteController : Controller
    {
        private readonly ClienteData _clienteData;
        private readonly CuentaData _cuentaData;

        public ClienteController(ClienteData clienteData, CuentaData cuentaData)
        {
            _clienteData = clienteData;
            _cuentaData = cuentaData;
        }

        public IActionResult Index()
        {
            return View();
        }

        [HttpGet]
        public async Task<IActionResult> Lista()
        {
            List<Cliente> lista = await _clienteData.Lista();
            return StatusCode(StatusCodes.Status200OK, new { data = lista });
        }

        [HttpPost]
        public async Task<IActionResult> Crear([FromBody] Cliente objeto)
        {
            string respuesta = await _clienteData.Crear(objeto);
            return StatusCode(StatusCodes.Status200OK, new { data = respuesta });
        }

        [HttpPut]
        public async Task<IActionResult> Editar([FromBody] Cliente objeto)
        {
            string respuesta = await _clienteData.Editar(objeto);
            return StatusCode(StatusCodes.Status200OK, new { data = respuesta });
        }

        [HttpDelete]
        public async Task<IActionResult> Eliminar(int Id)
        {
            string respuesta = await _clienteData.Eliminar(Id);
            return StatusCode(StatusCodes.Status200OK, new { data = respuesta });
        }

        [Authorize(Roles = "Cliente")]
        public async Task<IActionResult> Cuenta()
        {
            var correo = User.FindFirst(ClaimTypes.Email)?.Value;
            Console.WriteLine(correo);
            if (string.IsNullOrEmpty(correo))
            {
                return RedirectToAction("Index", "Home");
            }

            var cliente = await _clienteData.ObtenerPorCorreo(correo);
            if (cliente == null)
            {
                return RedirectToAction("Index", "Home");
            }

            return RedirectToAction("Index", "Cuenta", new { idCliente = cliente.IdCliente });
        }


        [HttpPost]
        [Authorize(Roles = "Cliente")]
        public async Task<IActionResult> Depositar([FromBody] DepositoRequest request)
        {
            try
            {
                var resultado = await _cuentaData.Depositar(request.IdCliente, request.Monto);
                if (string.IsNullOrEmpty(resultado))
                {
                    return Json(new { success = true });
                }
                else
                {
                    return Json(new { success = false, error = resultado });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, error = ex.Message });
            }
        }
    }

    public class DepositoRequest
    {
        public int IdCliente { get; set; }
        public decimal Monto { get; set; }
    }
}
