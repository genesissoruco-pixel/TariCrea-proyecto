package com.optativa.backend.dto.request;

import jakarta.validation.constraints.*;
import com.optativa.backend.validation.ContrasenaValida;

public record RegistroRequest(
        @NotBlank @Size(max = 120) String nombre,
        @NotBlank @Size(max = 100) String apellidoPaterno,
        @NotBlank @Size(max = 100) String apellidoMaterno,
        @NotBlank @Size(max = 20) String telefono,
        @NotBlank @Email @Size(max = 254) String correo,
        @NotNull @ContrasenaValida String contrasena) {}
